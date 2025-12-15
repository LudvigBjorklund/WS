import os
import sys
import queue
from PyQt6.QtWidgets import QApplication, QMessageBox,QWidget
from PyQt6.QtCore import QThread, pyqtSignal
import threading
import serial
import time
from datetime import datetime

def write_to_fpga(serial_connection, data):
    """Write data to the FPGA via serial connection."""
    if serial_connection:
        try:
            # Convert the integer to 4 bytes (32 bits)
            data_bytes = data.to_bytes(4, byteorder='big')
            serial_connection.write(data_bytes)
            serial_connection.flush()  # Ensure all data is sent
            time.sleep(0.1)  # Add a small delay (100ms) to ensure the buffer is processed
            return True
        except Exception as e:
            raise RuntimeError(f"Error writing to serial port: {e}")
    else:
        raise RuntimeError("Not connected to serial port")

class SerialReaderThread(QThread):
    """Thread for high-speed reading from serial port with minimal CPU usage."""
    update_signal = pyqtSignal(str)
    finished_signal = pyqtSignal(int)

    def __init__(self, serial_connection=None, port=None, baud_rate=None, output_file=None, read_time=None, buffer_size=8192):
        super().__init__()
        self.serial_connection = serial_connection
        self.port = port
        self.baud_rate = baud_rate
        self.output_file = output_file
        self.read_time = read_time
        self.buffer_size = buffer_size
        self.stop_event = threading.Event()
        self.data_queue = queue.Queue(maxsize=buffer_size)
        self.bytes_read = 0
        self.lines_written = 0

    def run(self):
        try:
            # Use the existing serial connection if provided
            if self.serial_connection is None:
                self.serial_connection = serial.Serial(
                    port=self.port,
                    baudrate=self.baud_rate,
                    timeout=0,  # Non-blocking mode
                    write_timeout=0,  # Non-blocking writes
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE,
                    bytesize=serial.EIGHTBITS
                )
        except Exception as e:
            self.update_signal.emit(f"Error opening serial port: {e}")
            self.finished_signal.emit(0)
            return

        # Ensure the output directory exists
        os.makedirs(os.path.dirname(os.path.abspath(self.output_file)) or '.', exist_ok=True)

        # Writer thread function - continuously writes data from queue to text file
        def save_thread():
            with open(self.output_file, 'w', buffering=self.buffer_size) as f:
                while not self.stop_event.is_set() or not self.data_queue.empty():
                    try:
                        # Get data from queue with timeout to check stop event periodically
                        item = self.data_queue.get(timeout=0.1)
                        if item is None:  # Special sentinel value
                            break

                        timestamp, chunk = item
                        # Convert bytes to hex string with timestamp
                        hex_str = ' '.join(f'{b:02X}' for b in chunk)
                        f.write(f"{timestamp:.6f}: {hex_str}\n")
                        self.lines_written += 1
                        self.data_queue.task_done()
                        self.update_signal.emit(f"Lines written: {self.lines_written}")

                    except queue.Empty:
                        continue
                    except Exception as e:
                        self.update_signal.emit(f"Error in writer thread: {e}")
                        break

            self.update_signal.emit(f"Writer thread completed. Total lines written: {self.lines_written}")

        # Start writer thread
        writer = threading.Thread(target=save_thread)
        writer.daemon = True
        writer.start()

        # Calculate end time if read_time is specified
        end_time = None
        if self.read_time is not None:
            end_time = time.time() + self.read_time

        # Reset buffers to clear any existing data
        self.serial_connection.reset_input_buffer()
        start_time = time.time()

        try:
            while not self.stop_event.is_set():
                # Check if we've reached the time limit
                if end_time and time.time() >= end_time:
                    break

                # Read all available bytes in one chunk
                if self.serial_connection.in_waiting:
                    chunk = self.serial_connection.read(self.serial_connection.in_waiting)
                    if chunk:
                        # Put data in queue for writer thread with timestamp
                        timestamp = time.time()
                        self.data_queue.put((timestamp, chunk))
                        self.bytes_read += len(chunk)
                        self.update_signal.emit(f"Bytes read: {self.bytes_read}")
                else:
                    # Tiny sleep to prevent CPU hogging
                    time.sleep(0.0001)

        except Exception as e:
            self.update_signal.emit(f"Error in reader thread: {e}")
        finally:
            # Signal saving thread that we're done
            self.data_queue.put(None)
            self.update_signal.emit(f"Reader thread completed. Total bytes read: {self.bytes_read}")

            # Wait for writer to finish
            writer.join(timeout=2.0)

            # Close serial port if it was created by this thread
            if self.serial_connection and self.port:
                self.serial_connection.close()

            # Calculate stats
            elapsed = time.time() - start_time
            self.update_signal.emit(f"\nSummary:")
            self.update_signal.emit(f"Read completed in {elapsed:.2f} seconds")
            self.update_signal.emit(f"Total bytes read: {self.bytes_read}")
            if elapsed > 0:
                self.update_signal.emit(f"Average read rate: {self.bytes_read/elapsed:.2f} bytes/second")
            self.update_signal.emit(f"Total lines written: {self.lines_written}")
            self.update_signal.emit(f"Data saved to: {os.path.abspath(self.output_file)}")

            self.finished_signal.emit(self.bytes_read)

    def stop(self):
        self.stop_event.set()
def table_verification_threaded(port, baud_rate, output_file="fpga_data.txt", c_ID_RX_TBL="03"):
    """
    Enhanced four-thread approach for FPGA verification with stuck detection:
    1. Writer thread: Writes commands to FPGA over serial port
    2. Reader thread: Continuously reads raw data from serial
    3. Logger thread: Stores received hex data to a text file
    4. Processor thread: Processes stored data looking for valid packets
       and detects if FPGA is stuck (repeated data patterns)
    
    Args:
        port (str): Serial port name
        baud_rate (int): Baud rate for serial communication
        output_file (str): Path to save raw data
        c_ID_RX_TBL (str): Command ID for receiving table data, default "03"
        
    Returns:
        Dict mapping coordinates to payload data
    """
    # FPGA configuration values
    SOC_FPGA = [67108864, 67113984, 67119104, 67124224, 67129344, 67134464,
                67139584, 67144704, 67149824, 67154944, 67160064, 67165184,
                67170304, 67175424, 67180544, 67185664]
    
    I_FPGA = [33554432, 33556480, 33558528, 33560576, 33562624, 33564672,
              33566720, 33568768, 33570816, 33572864, 33574912, 33576960,
              33579008, 33581056, 33583104, 33585152]
    
    # State commands
    s_init = "00000001" + 21 * '0' + '001'  # State no INIT
    s_verification = "00000001" + 21 * '0' + '010'  # State no VERIFICATION
    s_reset = "00000001" + 21 * '0' + '110' # State HARDWARE RESET

    # Thread synchronization
    stop_event = threading.Event()
    write_complete = threading.Event()
    fpga_stuck_event = threading.Event()  # Detect if FPGA is not correctly receiving data
    
    # Queues for inter-thread communication
    raw_data_queue = queue.Queue(maxsize=1000)  # Queue for raw serial data
    processed_results = {}  # Thread-safe dict to store results
    processed_results_lock = threading.Lock()  # Lock for the results dict
    
    # Configuration parameters
    write_sleep = 0.05  # Sleep between writes
    read_sleep = 0.01  # Sleep between reads if no data
    
    # Stuck detection parameters
    repeat_threshold = 500  # Number of identical packets to consider FPGA stuck
    
    # Open serial port
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baud_rate,
            timeout=0,  # Non-blocking mode
            write_timeout=1,  # Allow 1 second for writes
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS
        )
        ser.reset_input_buffer()
        ser.reset_output_buffer()
    except Exception as e:
        print(f"Error opening serial port: {e}")
        return {}
    
    # Create output directory if needed
    os.makedirs(os.path.dirname(os.path.abspath(output_file)) or '.', exist_ok=True)
    
    # Initialize QT application for alert dialog
    app = None
    if not QApplication.instance():
        app = QApplication(sys.argv)
    
    # Helper function to write to FPGA
    def write_to_fpga(value):
        """Write a value to the FPGA via serial port"""
        # Convert value to bytes (implementation depends on your protocol)
        try:
            # Example implementation - adjust based on your actual protocol
            value_bytes = value.to_bytes(4, byteorder='big')
            ser.write(value_bytes)
            ser.flush()
            return True
        except Exception as e:
            print(f"Error writing to FPGA: {e}")
            return False
    
    def show_fpga_stuck_alert():
        """Display a Qt alert box with instructions and wait for user acknowledgment."""
        alert = QMessageBox()
        alert.setWindowTitle("FPGA Alert")
        alert.setText("FPGA is stuck!")
        alert.setInformativeText("Move to state 6 and then set switch 8 to high. Click OK when done.")
        alert.setIcon(QMessageBox.Icon.Warning)
        alert.setStandardButtons(QMessageBox.StandardButton.Ok)
        alert.exec()  # This will block until the user clicks OK
    # Thread 1: Writer - sends commands to FPGA
    def writer_thread():
        print("Writer thread started")
        try:
            # Initialize FPGA
            print("Initializing FPGA...")
            write_to_fpga(int(s_init, 2))
            time.sleep(0.25)  # Longer delay for initialization
            write_to_fpga(int(s_verification, 2))
            time.sleep(0.25)  # Longer delay for state change
            
            # Loop through all rows and columns
            for row in range(16):
                for col in range(11):
                    if stop_event.is_set() or fpga_stuck_event.is_set():
                        return
                    
                    # Write row and column values
                    print(f"Writing coordinates ({row},{col})")
                    write_to_fpga(I_FPGA[row])
                    time.sleep(write_sleep)
                    write_to_fpga(SOC_FPGA[col])
                    time.sleep(write_sleep)
        except Exception as e:
            print(f"Writer thread error: {e}")
        finally:
            print("Writer thread finished")
            write_complete.set()
    
    # Thread 2: Reader - continuously reads data from serial port
    def reader_thread():
        print("Reader thread started")
        buffer = bytearray()
        
        try:
            while not stop_event.is_set():
                if fpga_stuck_event.is_set():
                    time.sleep(0.5)  # Wait while FPGA is stuck
                    continue
                    
                # Check if there's data to read
                if ser.in_waiting:
                    # Read all available bytes
                    chunk = ser.read(ser.in_waiting)
                    if chunk:
                        # Add to buffer and queue with timestamp
                        buffer.extend(chunk)
                        timestamp = time.time()
                        raw_data_queue.put((timestamp, bytes(chunk)))
                else:
                    # Small sleep to prevent CPU hogging
                    time.sleep(read_sleep)
        except Exception as e:
            print(f"Reader thread error: {e}")
        finally:
            print("Reader thread finished")
    
    # Thread 3: Logger - saves raw data to file
    def logger_thread():
        print("Logger thread started")
        bytes_written = 0
        lines_written = 0
        
        try:
            with open(output_file, 'w', buffering=8192) as f:
                while not (stop_event.is_set() and raw_data_queue.empty() and write_complete.is_set()):
                    if fpga_stuck_event.is_set():
                        time.sleep(0.5)  # Wait while FPGA is stuck
                        continue
                        
                    try:
                        # Get data from queue with timeout
                        timestamp, chunk = raw_data_queue.get(timeout=0.1)
                        
                        # Convert to hex and write to file
                        hex_str = ' '.join(f'{b:02X}' for b in chunk)
                        timestamp_str = datetime.fromtimestamp(timestamp).strftime('%H:%M:%S.%f')
                        f.write(f"{timestamp_str} [{timestamp:.6f}]: {hex_str}\n")
                        
                        bytes_written += len(chunk)
                        lines_written += 1
                        raw_data_queue.task_done()
                    except queue.Empty:
                        continue
                    except Exception as e:
                        print(f"Logger error: {e}")
        except Exception as e:
            print(f"Logger thread error: {e}")
        finally:
            print(f"Logger thread finished - Wrote {bytes_written} bytes, {lines_written} lines")
    
    def processor_thread():
        print("Processor thread started")
        packets_processed = 0
        last_file_size = 0
        last_check_time = time.time()
        check_interval = 0.1  # Check for new data every 0.1 seconds

        # Stuck detection variables
        recent_payloads = []
        max_recent_payloads = 5000  # Keep track of the last 50 payloads
        repeat_threshold = 5000  # Trigger stuck alert if the same payload is repeated 50 times

        try:
            while not (stop_event.is_set() and write_complete.is_set() and time.time() - last_check_time > 1):
                time.sleep(check_interval)

                # Only process if file exists and has new data
                if not os.path.exists(output_file):
                    continue

                current_size = os.path.getsize(output_file)
                if current_size <= last_file_size:
                    last_check_time = time.time()
                    continue

                # Process new data in the file
                with open(output_file, 'r') as f:
                    # Skip to last processed position
                    f.seek(0, 0)  # For simplicity, reread the whole file

                    # Read and process each line
                    buffer = ""
                    for line in f:
                        # Extract hex data (skip timestamp)
                        parts = line.strip().split(':', 1)
                        if len(parts) < 2:
                            continue

                        hex_values = parts[1].strip().split()
                        buffer += ''.join(hex_values)

                        # Look for packet pattern: FF ID ROWCOL DATA1 DATA2 FF
                        while 'FF' in buffer:
                            start = buffer.find('FF')
                            # Minimum packet length: FF + ID + ROWCOL + 2*DATA + FF = 6 bytes
                            if len(buffer) - start < 12:  # 12 hex chars = 6 bytes
                                buffer = buffer[start:]
                                break

                            # Check if we have a valid packet start
                            if start + 12 <= len(buffer) and buffer[start+10:start+12] == 'FF':
                                packet = buffer[start:start+12]
                                buffer = buffer[start+12:]  # Move past this packet

                                # Extract ID, row, col and data
                                try:
                                    packet_id = packet[2:4]
                                    row_col = packet[4:6]
                                    row = int(row_col[0], 16)
                                    col = int(row_col[1], 16)
                                    data_bytes = packet[6:10]

                                    # Check if this is a table packet we're looking for
                                    if packet_id == c_ID_RX_TBL:
                                        payload = f"FF{packet_id}{row_col}{data_bytes}FF"

                                        # Store in results
                                        with processed_results_lock:
                                            processed_results[(row, col)] = payload

                                        print(f"✓ Found valid payload for ({row},{col}): {payload}")
                                        packets_processed += 1

                                        # Add to recent payloads list for stuck detection
                                        recent_payloads.append(payload)
                                        if len(recent_payloads) > max_recent_payloads:
                                            recent_payloads.pop(0)  # Remove oldest

                                        # Check for stuck FPGA (repeated identical payloads)
                                        if recent_payloads.count(payload) >= repeat_threshold:
                                            if not fpga_stuck_event.is_set():
                                                print("WARNING: FPGA appears to be stuck (repeated data detected)")
                                                fpga_stuck_event.set()
                                                # Show alert dialog and wait for user acknowledgment
                                                show_fpga_stuck_alert()
                                                # Reset the stuck event after user acknowledgment
                                                fpga_stuck_event.clear()
                                                stop_event.set()
                                                return
                                except Exception as e:
                                    print(f"Error processing packet {packet}: {e}")
                            else:
                                # Move past the FF if no valid packet found
                                buffer = buffer[start+2:]

                    last_file_size = current_size
                    last_check_time = time.time()

                    # Report progress
                    with processed_results_lock:
                        print(f"Processed {packets_processed} packets, found {len(processed_results)} valid results")
        except Exception as e:
            print(f"Processor thread error: {e}")
        finally:
            print(f"Processor thread finished - Processed {packets_processed} packets, found {len(processed_results)} valid results")
    # Start all threads
    threads = []
    try:
        # Create and start threads
        writer = threading.Thread(target=writer_thread)
        reader = threading.Thread(target=reader_thread)
        logger = threading.Thread(target=logger_thread)
        processor = threading.Thread(target=processor_thread)
        
        threads = [writer, reader, logger, processor]
        for thread in threads:
            thread.daemon = True
            thread.start()
        
        # Wait for writer to complete
        writer.join()
        
        # Give processor time to process remaining data
        time.sleep(0.1)
        
        # Signal threads to stop
        stop_event.set()
        
        # Wait for other threads to finish (with timeout)
        for thread in threads[1:]:
            thread.join(timeout=5.0)
            
    except KeyboardInterrupt:
        print("\nOperation interrupted by user")
        stop_event.set()
    finally:
        # Ensure all threads have stopped
        stop_event.set()
        for thread in threads:
            if thread.is_alive():
                thread.join(timeout=1.0)

def run_verification(port, baud_rate=115200, output_file="fpga_data.txt"):
    """Convenience function to run the verification"""
    print(f"Starting FPGA table verification on port {port}")
    start_time = time.time()
    
    results = table_verification_threaded(port, baud_rate, output_file)
    
    elapsed = time.time() - start_time
    print(f"Verification completed in {elapsed:.2f} seconds")
    print(f"Raw data saved to: {os.path.abspath(output_file)}")
    
    return results



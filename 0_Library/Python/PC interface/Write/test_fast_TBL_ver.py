import threading
import time
import queue
import os
import sys
import serial
import copy
from datetime import datetime
import pandas as pd

# Add the path to the Preprocessing module /home/ntnu/Documents/Digital Twin/DT Version 6/PC interface/Preprocessing.py
processing_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
print("Processing path:", processing_path)
sys.path.append(processing_path)
import Preprocessing as preprocess



def table_verification_threaded(port, baud_rate, output_file="fpga_data.txt", c_ID_RX_TBL="03"):
    """
    Simplified four-thread approach for FPGA verification:
    1. Writer thread: Writes commands to FPGA over serial port
    2. Reader thread: Continuously reads raw data from serial
    3. Logger thread: Stores received hex data to a text file
    4. Processor thread: Processes stored data looking for valid packets
    
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
    
    # Thread synchronization
    stop_event = threading.Event()
    write_complete = threading.Event()
    
    # Queues for inter-thread communication
    raw_data_queue = queue.Queue(maxsize=1000)  # Queue for raw serial data
    processed_results = {}  # Thread-safe dict to store results
    processed_results_lock = threading.Lock()  # Lock for the results dict
    
    # Configuration parameters
    write_sleep = 0.1  # Sleep between writes
    read_sleep = 0.01  # Sleep between reads if no data
    
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
    
    # Thread 1: Writer - sends commands to FPGA
    def writer_thread():
        print("Writer thread started")
        try:
            # Initialize FPGA
            print("Initializing FPGA...")
            write_to_fpga(int(s_init, 2))
            time.sleep(0.25)  # Longer delay for initialization
            write_to_fpga(int(s_verification, 2))
            time.sleep(5.25)  # Longer delay for state change
            
            # Loop through all rows and columns
            for row in range(16):
                for col in range(11):
                    if stop_event.is_set():
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
    
    # Thread 4: Processor - processes the data file looking for valid packets
    def processor_thread():
        print("Processor thread started")
        packets_processed = 0
        last_file_size = 0
        last_check_time = time.time()
        check_interval = 0.1  # Check for new data every 0.5 seconds
        
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
        
        # Close serial port
        if ser.is_open:
            ser.close()
        
        # Final report
        with processed_results_lock:
            result_count = len(processed_results)
            print(f"\nVerification complete. Found {result_count} valid data points out of 176 possible coordinates.")
            
            # Report missing coordinates
            if result_count < 176:
                missing_count = 176 - result_count
                print(f"Missing {missing_count} coordinates.")
                if missing_count < 20:  # Only print details if there aren't too many
                    missing = []
                    for row in range(16):
                        for col in range(11):
                            if (row, col) not in processed_results:
                                missing.append((row, col))
                    print(f"Missing coordinates: {missing}")
        
        return processed_results

def run_verification(port, baud_rate=115200, output_file="fpga_data.txt"):
    """Convenience function to run the verification"""
    print(f"Starting FPGA table verification on port {port}")
    start_time = time.time()
    
    results = table_verification_threaded(port, baud_rate, output_file)
    
    elapsed = time.time() - start_time
    print(f"Verification completed in {elapsed:.2f} seconds")
    print(f"Raw data saved to: {os.path.abspath(output_file)}")
    
    return results

if __name__ == "__main__":
    FMT_dict = {"I": "5EN11", "R0": "8EN8", "SOC": "7EN9", "ID": "8EN0"}
    ID_dict = {"I": 2, "R0": 3, "SOC" :4}
    ID_dict_bin = {}
    for key in ID_dict.keys():
        ID_dict_bin[key] = preprocess.decimal_to_binary_string(ID_dict[key], FMT_dict["ID"])
    port = "/dev/ttyUSB2"  # Replace with your serial port
    baudrate = 115200
    # Generate the data list
   
    binary_vector = "00000001" + 21*"0"+ "010" # Go to verification /home/ntnu/Documents/Digital Twin/DT Version 6/Data Management
    # Load dataframe from 
    path_DT_DM_Sheet = "/home/ntnu/Documents/Digital Twin/DT Version 6/Data Management"
    file_name = "DT_DataManagement.xlsx"
    # Read the Excel file using preprocess 
    df_R0 = preprocess.df_from_sheet_name(os.path.join(path_DT_DM_Sheet, file_name), sheet_name="R0_2D_LUT_Values")
    # Example usage
    port = "/dev/ttyUSB2"  # Replace with your serial port
    baud_rate = 115200
    output_file = "fpga_data.txt"  # Output file for raw data
    
    results = run_verification(port, baud_rate, output_file)
    
    # Print results
    for (row, col), payload in results.items():
        # Savomg the payload to a file
        with open("payloads.txt", "a") as f:
            f.write(f"({row},{col}): {payload}\n")
        # Print the payload
        print(f"({row},{col}): {payload}")
    # Create a DataFrame from the results with rows as rows and columns as columns
    parameter_name = "R0"
    ID = ID_dict[parameter_name]
    # Make the ID with 2 char hexadecimals
    ID = preprocess.decimal_to_hexadecimal(ID, 2)

    format_string = FMT_dict[parameter_name]
    df_results = pd.DataFrame(index=range(16), columns=range(11))
    I_val  = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]  # I values for setting the row names to [ "0", "1", ...]
    # Set the row names to the I values
    row_names = [f"{val}" for val in I_val]
    SOC_val = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]  # SOC values for setting the colun names to [ "0 %, "10 %", ...]
    # Set the column names to the SOC values
    col_names = [f"{val} %" for val in SOC_val]
    # Set the row and column names of the DataFrame
    df_results.index = row_names
    df_results.columns = col_names
    for (row, col), payload in results.items():
        if payload.startswith("FF") and payload.endswith("FF"):
            if payload[2:4] == ID:
                # Extract the data from the payload skipping the first two chars (row,col)
                data = payload[6:10]
                 #Assign the data to the DataFrame at the corresponding row and column
                df_results.at[row, col] = data
            else:
                print(f"Invalid ID in payload: {payload[2:4]} (expected {ID})")
                # Convert the data to binary using the format string
    # Adjust DataFrame creation and saving logic
    df_results = pd.DataFrame(index=range(16), columns=range(11))
    I_val = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]  # Row names
    SOC_val = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]  # Column names

    # Set the row and column names
    df_results.index = [f"{val}" for val in I_val]
    df_results.columns = [f"{val}%" for val in SOC_val]

    # Populate the DataFrame with the 4 data points
    for (row, col), payload in results.items():
        if payload.startswith("FF") and payload.endswith("FF"):
            if payload[2:4] == ID:
                # Extract the data from the payload
                data = payload[6:10]
                df_results.at[row, col] = data
            else:
                print(f"Invalid ID in payload: {payload[2:4]} (expected {ID})")

    # Filter the DataFrame to include only the 4 data points
    df_filtered = df_results.dropna(how='all').loc[:, df_results.notna().any()]

    # Save the filtered DataFrame to a CSV file
    df_filtered.to_csv(f"{parameter_name}_verification_results.csv", index=True)
    print(f"Filtered verification results saved to CSV file: {parameter_name}_verification_results.csv")



def execute_scenario_file(
    filename,
    transport,
    write_queue,
):
    """
    Execute a test scenario described in a text file.

    Sleep values in { } are interpreted as REAL TIME seconds.
    """

    with open(filename, "r") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()

            # Skip empty lines and comments
            if not line or line.startswith("#"):
                continue

            # Extract optional sleep (REAL TIME seconds)
            sleep_match = SLEEP_PATTERN.search(line)
            sleep_seconds = None

            if sleep_match:
                sleep_seconds = float(sleep_match.group(1))
                line = SLEEP_PATTERN.sub("", line).strip()

            tokens = line.split()

            try:
                # ------------------------
                # State transition
                # ------------------------
                if tokens[0].startswith("s_"):
                    state = tokens[0]
                    print(f"[SCENARIO] Transition → {state}")
                    transition_state(transport, state, write_queue)

                # ------------------------
                # Current write
                # ------------------------
                elif tokens[0] == "I":
                    if len(tokens) != 2:
                        raise ValueError("I requires one argument")
                    current = float(tokens[1])
                    print(f"[SCENARIO] Set current → {current} A")
                    write_current(transport, current, write_queue)

                else:
                    raise ValueError(f"Unknown command '{tokens[0]}'")

                # ------------------------
                # REAL-TIME sleep
                # ------------------------
                if sleep_seconds is not None:
                    print(f"[SCENARIO] Sleep {sleep_seconds}s (real time)")
                    time.sleep(sleep_seconds)

            except Exception as e:
                raise RuntimeError(
                    f"Error in {filename}:{lineno}: {e}"
                ) from e


# import os
# import serial
# import sys
# import time
# import threading
# import queue
# import struct
# import signal
# import atexit
# # Add preprocessing functions from the module in the parent directory
# path_to_main_modules = os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..','..'))
# support_functions_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'SupportFunctions'))

# sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# sys.path.append(support_functions_path)
# import Preprocessing as preprocess
# import FPGA_Interface as fpga
# import Postprocessing as postprocess

# def write_to_fpga(serial_connection, data):
#     """Write data to the FPGA via serial connection."""
#     if serial_connection:
#         try:
#             # Convert the integer to 4 bytes (32 bits)
#             data_bytes = data.to_bytes(4, byteorder='big')
#             serial_connection.write(data_bytes)
#             serial_connection.flush()  # Ensure all data is sent
#             time.sleep(0.1)  # Add a small delay (100ms) to ensure the buffer is processed
#             return True
#         except Exception as e:
#             raise RuntimeError(f"Error writing to serial port: {e}")
#     else:
#         raise RuntimeError("Not connected to serial port")

# def write_worker(serial_connection, write_queue, stop_event):
#     """
#     Worker thread that continuously processes write commands from queue.
#     Runs in parallel with read/logging operations.
#     """
#     try:
#         while not stop_event.is_set():
#             try:
#                 # Get command from queue with timeout
#                 data = write_queue.get(timeout=0.1)
                
#                 # Write to FPGA
#                 data_bytes = data.to_bytes(4, byteorder='big')
#                 serial_connection.write(data_bytes)
#                 serial_connection.flush()
#                 time.sleep(0.05)  # Small delay between writes
                
#                 write_queue.task_done()
                
#             except queue.Empty:
#                 continue
                
#     except Exception as e:
#         print(f"Write thread error: {e}")
#         stop_event.set()

# def start_write_thread(serial_connection, stop_event):
#     """
#     Start a parallel write thread that processes queued write commands.
    
#     Returns:
#         write_queue: Queue to submit write commands (as integers)
#         write_thread: The thread object
    
#     Example usage:
#         write_queue, write_thread = start_write_thread(ser, stop_event)
#         write_queue.put(16777219)  # Queue a command
#         write_queue.put(0x01000000)  # Queue another command
#     """
#     write_queue = queue.Queue(maxsize=100)
    
#     write_thread = threading.Thread(
#         target=write_worker,
#         args=(serial_connection, write_queue, stop_event),
#         daemon=True
#     )
    
#     write_thread.start()
#     return write_queue, write_thread

# def read_from_fpga(serial_connection, data_queue, stop_event, buffer_size=4096):
#     """
#     Continuously read 32-bit words from FPGA and push batches to queue.
#     Groups all samples read in one batch with a single timestamp.
#     """
#     try:
#         while not stop_event.is_set():
#             # Read up to buffer_size bytes at once for efficiency
#             raw = serial_connection.read(buffer_size)
            
#             if len(raw) == 0:
#                 continue
            
#             # Timestamp once per batch
#             timestamp = time.time()
            
#             # Collect all complete 4-byte chunks from this read
#             chunks = []
#             for i in range(0, len(raw) - (len(raw) % 4), 4):
#                 chunk = raw[i:i+4]
#                 chunks.append(chunk)
            
#             if chunks:
#                 # Push entire batch with single timestamp
#                 data_queue.put((timestamp, chunks))

#     except Exception as e:
#         print(f"UART read error: {e}")
#         stop_event.set()

# def log_data(data_queue, stop_event, logfile_path, byte_separator=' ', word_separator=' '):
#     """
#     Consume data from queue and log it with grouped timestamps.
    
#     Args:
#         byte_separator: Separator between bytes (e.g., ' ' for '00 FF FF 01')
#         word_separator: Separator between 4-byte words (e.g., ' ' or '  ')
    
#     Example output with byte_separator=' ', word_separator='  ':
#         1766938881.457266,00 FF FF 01  00 00 00 FF  FF 01 00 00
#     """
#     with open(logfile_path, "w") as f:
#         f.write("timestamp,values\n")
        
#         batch = []
#         batch_size = 50  # Write in batches for better I/O performance
        
#         while not stop_event.is_set() or not data_queue.empty():
#             try:
#                 timestamp, chunks = data_queue.get(timeout=0.1)
                
#                 # Format all chunks into hex strings
#                 hex_words = []
#                 for chunk in chunks:
#                     if byte_separator:
#                         # Insert separator between bytes: '00 FF FF 01'
#                         hex_word = byte_separator.join(f'{b:02X}' for b in chunk)
#                     else:
#                         # No separator: '00FFFF01'
#                         hex_word = chunk.hex().upper()
#                     hex_words.append(hex_word)
                
#                 # Join all words with word separator
#                 values_str = word_separator.join(hex_words)
                
#                 line = f"{timestamp:.6f},{values_str}\n"
#                 batch.append(line)
                
#                 # Write batch periodically
#                 if len(batch) >= batch_size:
#                     f.writelines(batch)
#                     batch = []
#                     f.flush()
                    
#             except queue.Empty:
#                 # Flush remaining batch on timeout
#                 if batch:
#                     f.writelines(batch)
#                     batch = []
#                     f.flush()
#                 continue
        
#         # Final flush
#         if batch:
#             f.writelines(batch)
#             f.flush()

# def start_uart_logging(serial_connection, logfile_path, byte_separator=' ', word_separator='  '):
#     """
#     Start UART logging with grouped timestamps.
    
#     Args:
#         byte_separator: Separator between bytes (default: ' ')
#         word_separator: Separator between words (default: '  ' - double space)
    
#     Returns:
#         stop_event: Event to signal logging stop
    
#     Format examples:
#         byte_separator=' ', word_separator='  ':
#             1766938881.457266,00 FF FF 01  00 00 00 FF  FF 01 00 00
        
#         byte_separator='', word_separator=' ':
#             1766938881.457266,00FFFF01 000000FF FF010000
        
#         byte_separator=' ', word_separator=', ':
#             1766938881.457266,00 FF FF 01, 00 00 00 FF, FF 01 00 00
#     """
#     data_queue = queue.Queue(maxsize=1000)
#     stop_event = threading.Event()

#     reader = threading.Thread(
#         target=read_from_fpga,
#         args=(serial_connection, data_queue, stop_event),
#         daemon=True
#     )

#     logger = threading.Thread(
#         target=log_data,
#         args=(data_queue, stop_event, logfile_path, byte_separator, word_separator),
#         daemon=True
#     )

#     reader.start()
#     logger.start()

#     return stop_event

# def open_serial_port(port, baud_rate):
#     # Open serial port
#     try:
#         ser = serial.Serial(
#             port=port,
#             baudrate=baud_rate,
#             timeout=0,  # Non-blocking mode
#             write_timeout=1,  # Allow 1 second for writes
#             parity=serial.PARITY_NONE,
#             stopbits=serial.STOPBITS_ONE,
#             bytesize=serial.EIGHTBITS
#         )
#         ser.reset_input_buffer()
#         ser.reset_output_buffer()
#         if ser.is_open:
#             print(f"Serial port {port} opened successfully.")
#         else:
#             print(f"Failed to open serial port {port}.")
#             return None
#     except Exception as e:
#         print(f"Error opening serial port: {e}")
#         return None
#     return ser

# def transition_state(serial_connection, state, write_queue=None):
#     state_str_dic = {
#         's_idle': 16777216,
#         's_init': 16777217,
#         's_verification': 16777218,
#         's_simulation': 16777219,
#         's_pause' : 16777220
#     }
#     state_no_dic = {0: 16777216,
#                      1: 16777217,
#                      2: 16777218,
#                      3: 16777219,
#                      4: 16777220}
#     ID = 1 # ID for state assignment

#     if type(state) is str:
#         state_no = state_str_dic[state]
#     elif type(state) is int:
#         if state < 0 or state > 4:
#             raise ValueError("State integer must be between 0 and 4")
#         state_no = state_no_dic[state]
#     else:
#         raise ValueError("State must be a string or integer")
    
#     if serial_connection:
#         if write_queue is not None:
#             # Use parallel write thread
#             write_queue.put(state_no)
#         else:
#             # Direct write (old behavior)
#             write_to_fpga(serial_connection, state_no)

# def write_initialization_parameter(serial_connection, parameter, value, write_queue=None):
#     expected_no_of_bits = 32
#     ID_bits = 8
#     parameter_str_dic = {
#         'I' : {'ID' : "00000010", 'Name': 'Current [A]','fmt_string' : '4EN12'},
#     }
    
#     if parameter not in parameter_str_dic:
#         # Searching alternative keys for the parameter, e.g., 'current' for 'I'
#         if parameter == 'current':
#             parameter = 'I'
#             write_initialization_parameter(serial_connection, parameter, value, write_queue)
#         else:
#             raise ValueError(f"Parameter {parameter} not recognized")
#     # If recognized the parameter is correct
#     ID_bin = parameter_str_dic[parameter]['ID']
#     fmt_string = parameter_str_dic[parameter]['fmt_string']
#     # Check the n_int_bits, n_frac_bits from the fmt_string
#     n_int_bits, n_frac_bits, neg_value = preprocess.format_parse_string(fmt_string)
#     if (n_int_bits + n_frac_bits) != (expected_no_of_bits - ID_bits):
#         apppend_zeros = True
#         bits_to_add = expected_no_of_bits - ID_bits - (n_int_bits + n_frac_bits)
#         msb_add_bin = '0' * bits_to_add
#     # Preprocess the value
#     value_bin = preprocess.decimal_to_binary_string(value, fmt_string)
#     if apppend_zeros:
#         value_bin = ID_bin + msb_add_bin + value_bin
#     else:
#         value_bin = ID_bin + value_bin
#     # Convert to integer
#     value_int = int(value_bin, 2)
#     print(f"Writing Parameter {parameter_str_dic[parameter]['Name']} with value {value} as binary {value_bin} (int: {value_int}) to FPGA.")
#     # Write to FPGA
#     if serial_connection:
#         if write_queue is not None:
#             # Use parallel write thread
#             write_queue.put(value_int)
#         else:
#             # Direct write (old behavior)
#             write_to_fpga(serial_connection, value_int)
#     else:
#         print("Serial connection not established, skipping write to FPGA.")

# def safe_shutdown(serial_connection, stop_event=None, write_queue=None):
#     """
#     Safely shut down the FPGA connection.
#     - Stops logging threads
#     - Transitions FPGA to idle state
#     - Closes serial port
    
#     Args:
#         serial_connection: The serial port object
#         stop_event: Event to signal threads to stop (optional)
#         write_queue: Write queue to flush before shutdown (optional)
#     """
#     print("\n=== Initiating safe shutdown ===")
    
#     try:
#         # Stop logging threads
#         if stop_event is not None:
#             print("Stopping logging threads...")
#             stop_event.set()
#             time.sleep(0.5)  # Give threads time to finish
        
#         # Flush write queue if it exists
#         if write_queue is not None and not write_queue.empty():
#             print("Flushing write queue...")
#             write_queue.join()
#             time.sleep(0.2)
        
#         # Transition FPGA to idle state
#         if serial_connection and serial_connection.is_open:
#             print("Transitioning FPGA to idle state...")
#             try:
#                 transition_state(serial_connection, 's_idle')
#                 time.sleep(0.3)  # Give FPGA time to transition
#             except Exception as e:
#                 print(f"Warning: Could not transition to idle: {e}")
            
#             # Close serial port
#             print("Closing serial port...")
#             serial_connection.close()
#             print("Serial port closed.")
        
#         print("=== Shutdown complete ===")
        
#     except Exception as e:
#         print(f"Error during shutdown: {e}")

# def setup_signal_handlers(serial_connection, stop_event=None, write_queue=None):
#     """
#     Setup signal handlers for graceful shutdown on Ctrl+C.
    
#     Args:
#         serial_connection: The serial port object
#         stop_event: Event to signal threads to stop (optional)
#         write_queue: Write queue to flush before shutdown (optional)
#     """
#     def signal_handler(sig, frame):
#         print("\n\nCtrl+C detected!")
#         safe_shutdown(serial_connection, stop_event, write_queue)
#         sys.exit(0)
    
#     # Register signal handler for Ctrl+C
#     signal.signal(signal.SIGINT, signal_handler)
    
#     # Also register atexit handler as backup
#     atexit.register(lambda: safe_shutdown(serial_connection, stop_event, write_queue))
    
#     print("Signal handlers registered. Press Ctrl+C for safe shutdown.")

        
#     # Converting value to FPGA format (32 bit integer), so taking the preprocessing decimal to binary string, 


# if __name__ == "__main__":
    
#     # Example usage
#     port = '/dev/ttyUSB1'  # Update with your serial port
#     baud_rate = 115200

#     ser = open_serial_port(port, baud_rate)
    
#     # Start with resetting
#     transition_state(ser, 's_idle')
#     # Transition to initialization state (direct write)
#     transition_state(ser, 's_init')

#     # Set current to 4 A (example)
#     current_A = 4.0
#     write_initialization_parameter(ser, 'I', current_A)

#     time.sleep(1)  # Wait a moment
    
#     # Start logging data with grouped timestamps
#     logfile_path = "fpga_log.csv"
#     stop_event = start_uart_logging(ser, logfile_path, byte_separator=' ', word_separator='  ')
    
#     # Start parallel write thread
#     write_queue, write_thread = start_write_thread(ser, stop_event)
    
#     # Setup signal handlers for safe shutdown on Ctrl+C
#     setup_signal_handlers(ser, stop_event, write_queue)
    
#     print(f"Logging data to {logfile_path}.")
    
#     # Transition to simulation using parallel write thread
#     transition_state(ser, 's_simulation', write_queue)
    
#     # Example: Send multiple commands during logging
#     try:
#         time.sleep(5)
#         print("Changing current to 5.0 A during logging...")
#         write_initialization_parameter(ser, 'I', 5.0, write_queue)
        
#         time.sleep(5)
#         print("Changing current to 3.0 A during logging...")
#         write_initialization_parameter(ser, 'I', 3.0, write_queue)
        
#         time.sleep(5)
#         print("Pausing simulation...")
#         transition_state(ser, 's_pause', write_queue)
        
#         time.sleep(2)
#         print("Resuming simulation...")
#         transition_state(ser, 's_simulation', write_queue)
        
#         time.sleep(3)
        
#         # You can also send raw commands directly to the queue
#         print("Sending raw command 0x12345678...")
#         write_queue.put(0x12345678)
        
#         time.sleep(2)
        
#         # Normal shutdown
#         print("Normal shutdown initiated...")
#         safe_shutdown(ser, stop_event, write_queue)
        
#     except KeyboardInterrupt:
#         # This should be caught by signal handler, but just in case
#         print("\nKeyboardInterrupt caught in main loop")
#         safe_shutdown(ser, stop_event, write_queue)
#!/usr/bin/env python3


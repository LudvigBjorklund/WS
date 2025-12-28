
# import os
# import sys
# import time
# import threading
# import queue
# import signal
# import atexit
# from enum import Enum
# import serial

# import re
# import time
# # # Add preprocessing functions from the module in the parent directory
# path_to_main_modules = os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..','..'))
# support_functions_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'SupportFunctions'))

# sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# sys.path.append(support_functions_path)
# import Preprocessing as preprocess
# import FPGA_Interface as fpga
# import Postprocessing as postprocess

# SLEEP_PATTERN = re.compile(r"\{([\d\.]+)\}")
# # ==========================
# # Run mode selection
# # ==========================

# class RunMode(Enum):
#     FPGA = "fpga"
#     SIM  = "sim"   # Python-only simulation
#     GHDL = "ghdl"  # future

# RUN_MODE = RunMode.SIM   # <-- CHANGE HERE

# # ==========================
# # Optional imports (FPGA mode only)
# # ==========================

# if RUN_MODE == RunMode.SIM:
#     import serial

# # ==========================
# # Supporting function early testing
# # ==========================
# def realtime_wait_for_sim_seconds(
#     sim_seconds,
#     fpga_clk_hz=50e6,
#     timestep = 3,
#     cycles_per_sim_step=(5/32)*1e6,
# ):
#     """
#     Calculate real-time wait needed for a given amount of simulation time.

#     Args:
#         sim_seconds (float): Desired simulation time in seconds
#         fpga_clk_hz (float): FPGA clock frequency in Hz
#         sim_step_seconds (float): Simulation time increment per step
#         cycles_per_sim_step (float): FPGA cycles per simulation step

#     Returns:
#         float: Required real-time wait in seconds
#     """
#     sim_step_seconds = 2**(-timestep)
#     real_time_per_sim_step = cycles_per_sim_step / fpga_clk_hz
#     sim_steps = sim_seconds / sim_step_seconds

#     return sim_steps * real_time_per_sim_step


# SLEEP_RE = re.compile(r"\{([^}]+)\}")

# def calculate_parameter_fpga_value(parameter, value):
#    # Checking the parameter in the parameter dictionary
#     expected_no_of_bits = 32
#     ID_bits = 8
#     parameter_str_dic = {
#         'I' : {'ID' : "00000010", 'Name': 'Current [A]','fmt_string' : '4EN12'},
#     }
    
#     if parameter not in parameter_str_dic:
#         # Searching alternative keys for the parameter, e.g., 'current' for 'I'
#         if parameter == 'current':
#             parameter = 'I'
#             calculate_parameter_fpga_value(parameter, value)
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

#     return value_int



# # ==========================
# # Parse Scenario from file
# # ==========================

# def parse_scenario(filename):
#     actions = []

#     with open(filename, "r") as f:
#         for lineno, raw in enumerate(f, 1):
#             line = raw.strip()

#             if not line or line.startswith("#"):
#                 continue

#             sleep = None
#             match = SLEEP_RE.search(line)
#             if match:
#                 token = match.group(1)
#                 line = SLEEP_RE.sub("", line).strip()

#                 if ":" in token:
#                     domain, value = token.split(":")
#                 else:
#                     domain, value = "real", token

#                 sleep = {
#                     "type": "sleep",
#                     "domain": domain.strip(),
#                     "seconds": float(value),
#                 }

#             tokens = line.split()

#             if tokens[0] == "logfile":
#                 actions.append({
#                     "type": "log_config",
#                     "filename": tokens[1],
#                 })

#             elif tokens[0].startswith("s_"):
#                 actions.append({
#                     "type": "state_transition",
#                     "state": tokens[0],
#                 })

#             elif tokens[0] == "I":
#                 actions.append({
#                     "type": "set_parameter",
#                     "param": "I",
#                     "value": float(tokens[1]),
#                     "fpga_value" : calculate_parameter_fpga_value("I", float(tokens[1])), 
#                 })

#             else:
#                 raise ValueError(f"{filename}:{lineno} Unknown command")

#             if sleep:
#                 actions.append(sleep)

#     return actions



# def execute_plan(
#     actions,
#     transport,
#     write_queue,
#     read_thread_manager,
#     sim_time_to_real,
# ):
#     logging_started = False
#     log_filename = None

#     for action in actions:
#         t = action["type"]

#         if t == "log_config":
#             log_filename = action["filename"]

#         elif t == "state_transition":
#             state = action["state"]
#             transition_state(transport, state, write_queue)

#             if state == "s_sim" and not logging_started:
#                 read_thread_manager.start(log_filename)
#                 logging_started = True

#         elif t == "set_parameter":
#             write_parameter(
#                 transport,
#                 action["fpga_value"],
#                 write_queue,
#             )

#         elif t == "sleep":
#             if action["domain"] == "real":
#                 time.sleep(action["seconds"])

#             elif action["domain"] == "t_sim":
#                 real_wait = sim_time_to_real(action["seconds"])
#                 time.sleep(real_wait)

#             else:
#                 raise ValueError("Unknown sleep domain")

#         else:
#             raise RuntimeError(f"Unhandled action type {t}")
# # ==========================
# # Transport abstraction
# # ==========================

# class Transport:
#     def write_word(self, value: int):
#         raise NotImplementedError

#     def read_bytes(self, n: int) -> bytes:
#         return b""

#     def close(self):
#         pass

# # --------------------------
# # UART transport
# # --------------------------

# class SerialTransport(Transport):
#     def __init__(self, serial_connection):
#         self.ser = serial_connection

#     def write_word(self, value: int):
#         data = value.to_bytes(4, byteorder="big")
#         self.ser.write(data)
#         self.ser.flush()

#     def read_bytes(self, n: int) -> bytes:
#         return self.ser.read(n)

#     def close(self):
#         if self.ser and self.ser.is_open:
#             self.ser.close()

# # --------------------------
# # Simulation transport
# # --------------------------

# class SimulationTransport(Transport):
#     def __init__(self, decode_fn=None):
#         self.decode_fn = decode_fn

#     def write_word(self, value: int):
#         if self.decode_fn:
#             decoded = self.decode_fn(value)
#             print(f"[SIM WRITE] {decoded}")
#         else:
#             print(f"[SIM WRITE] raw=0x{value:08X}")

# # ==========================
# # FPGA word decoding
# # ==========================

# def decode_fpga_word(word: int):
#     ID = (word >> 24) & 0xFF
#     payload = word & 0x00FFFFFF

#     ID_map = {
#         1: "STATE",
#         2: "CURRENT",
#         3: "SOC",
#         4: "Q",
#     }

#     return {
#         "id": ID,
#         "name": ID_map.get(ID, f"UNKNOWN({ID})"),
#         "payload_raw": payload,
#         "payload_hex": f"0x{payload:06X}",
#         "full_word": f"0x{word:08X}"
#     }

# # ==========================
# # Write worker thread
# # ==========================

# def write_worker(transport, write_queue, stop_event):
#     while not stop_event.is_set():
#         try:
#             data = write_queue.get(timeout=0.1)
#             transport.write_word(data)
#             write_queue.task_done()
#             time.sleep(0.05)
#         except queue.Empty:
#             continue

# def start_write_thread(transport, stop_event):
#     write_queue = queue.Queue(maxsize=100)
#     t = threading.Thread(
#         target=write_worker,
#         args=(transport, write_queue, stop_event),
#         daemon=True
#     )
#     t.start()
#     return write_queue, t

# # ==========================
# # State transitions
# # ==========================

# def transition_state(transport, state, write_queue=None):
#     state_map = {
#         "s_idle":        0x01000000,
#         "s_init":        0x01000001,
#         "s_verification":0x01000002,
#         "s_simulation":  0x01000003,
#         "s_pause":       0x01000004,
#     }

#     # A

#     if state not in state_map:
#         if state == 's_sim':
#             state = 's_simulation'
#         else:
#             raise ValueError(f"Invalid state {state}")

#     value = state_map[state]

#     if write_queue:
#         write_queue.put(value)
#     else:
#         transport.write_word(value)

# # ==========================
# # Parameter write
# # ==========================

# def write_current(transport, current_A, write_queue=None):
#     ID = 0x02
#     scale = 2**12  # example fixed-point scaling
#     payload = int(current_A * scale) & 0x00FFFFFF
#     word = (ID << 24) | payload

#     print(f"Writing current {current_A} A → 0x{word:08X}")

#     if write_queue:
#         write_queue.put(word)
#     else:
#         transport.write_word(word)

# def write_parameter(transport, value, write_queue=None):
#     if write_queue:
#         write_queue.put(value)
#     else:
#         transport.write_word(value)
# # ==========================
# # Safe shutdown
# # ==========================

# def safe_shutdown(transport, stop_event=None, write_queue=None):
#     print("\n=== Safe shutdown ===")

#     if stop_event:
#         stop_event.set()
#         time.sleep(0.2)

#     if write_queue:
#         write_queue.join()

#     try:
#         transition_state(transport, "s_idle")
#     except Exception:
#         pass

#     transport.close()
#     print("Shutdown complete")

# # ==========================
# # Signal handling
# # ==========================

# def setup_signal_handlers(transport, stop_event, write_queue):
#     def handler(sig, frame):
#         print("\nCtrl+C detected")
#         safe_shutdown(transport, stop_event, write_queue)
#         sys.exit(0)

#     signal.signal(signal.SIGINT, handler)
#     atexit.register(lambda: safe_shutdown(transport, stop_event, write_queue))

# # ==========================
# # FPGA serial open
# # ==========================

# def open_serial_port(port, baud):
#     ser = serial.Serial(
#         port=port,
#         baudrate=baud,
#         timeout=0,
#         write_timeout=1
#     )
#     ser.reset_input_buffer()
#     ser.reset_output_buffer()
#     return ser

# # ==========================
# # Main
# # ==========================

# if __name__ == "__main__":

#     stop_event = threading.Event()

#     if RUN_MODE == RunMode.FPGA:
#         ser = open_serial_port("/dev/ttyUSB1", 115200)
#         transport = SerialTransport(ser)
#         print("Running in FPGA mode")

#     else:
#         transport = SimulationTransport(decode_fn=decode_fpga_word)
#         print("Running in SIMULATION mode")


#     # --------------------------
#     # Start write thread
#     # --------------------------

#     write_queue, write_thread = start_write_thread(transport, stop_event)
#     setup_signal_handlers(transport, stop_event, write_queue)

#     scenario_file = "scenario_1.txt"

#     actions = parse_scenario(scenario_file)
#     print(f"Parsed {len(actions)} actions from scenario file.")
#     print(f"Executing scenario...{actions}")

#     execute_plan(
#         actions,
#         transport,
#         write_queue,
#         read_thread_manager=None,
#         sim_time_to_real=lambda t: realtime_wait_for_sim_seconds(
#             sim_seconds=t,
#             fpga_clk_hz=50e6,
#             timestep = 3,
#             cycles_per_sim_step=(5/32)*1e6,
#         )
#     )
    
import os
import sys
import time
import threading
import queue
import signal
import atexit
from enum import Enum
import serial
import struct
import re

# # Add preprocessing functions from the module in the parent directory
path_to_main_modules = os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..','..'))
support_functions_path = os.path.abspath(os.path.join(os.path.dirname(__file__), 'SupportFunctions'))

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
sys.path.append(support_functions_path)
import Preprocessing as preprocess
import FPGA_Interface as fpga
import Postprocessing as postprocess

SLEEP_PATTERN = re.compile(r"\{([\d\.]+)\}")
# ==========================
# Run mode selection
# ==========================

class RunMode(Enum):
    FPGA = "fpga"
    SIM  = "sim"   # Python-only simulation
    GHDL = "ghdl"  # future

RUN_MODE = RunMode.FPGA   # <-- CHANGE HERE

# ==========================
# Supporting function early testing
# ==========================
def realtime_wait_for_sim_seconds(
    sim_seconds,
    fpga_clk_hz=50e6,
    timestep = 3,
    cycles_per_sim_step=(5/32)*1e6,
):
    """
    Calculate real-time wait needed for a given amount of simulation time.
    """
    sim_step_seconds = 2**(-timestep)
    real_time_per_sim_step = cycles_per_sim_step / fpga_clk_hz
    sim_steps = sim_seconds / sim_step_seconds

    return sim_steps * real_time_per_sim_step


SLEEP_RE = re.compile(r"\{([^}]+)\}")

def calculate_parameter_fpga_value(parameter, value):
    expected_no_of_bits = 32
    ID_bits = 8
    parameter_str_dic = {
        'I' : {'ID' : "00000010", 'Name': 'Current [A]','fmt_string' : '4EN12'},
    }
    
    if parameter not in parameter_str_dic:
        if parameter == 'current':
            parameter = 'I'
            return calculate_parameter_fpga_value(parameter, value)
        else:
            raise ValueError(f"Parameter {parameter} not recognized")
    
    ID_bin = parameter_str_dic[parameter]['ID']
    fmt_string = parameter_str_dic[parameter]['fmt_string']
    n_int_bits, n_frac_bits, neg_value = preprocess.format_parse_string(fmt_string)
    
    apppend_zeros = False
    if (n_int_bits + n_frac_bits) != (expected_no_of_bits - ID_bits):
        apppend_zeros = True
        bits_to_add = expected_no_of_bits - ID_bits - (n_int_bits + n_frac_bits)
        msb_add_bin = '0' * bits_to_add
    
    value_bin = preprocess.decimal_to_binary_string(value, fmt_string)
    if apppend_zeros:
        value_bin = ID_bin + msb_add_bin + value_bin
    else:
        value_bin = ID_bin + value_bin
    
    value_int = int(value_bin, 2)
    return value_int

# ==========================
# Parse Scenario from file
# ==========================

def parse_scenario(filename):
    actions = []

    with open(filename, "r") as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.strip()

            if not line or line.startswith("#"):
                continue

            sleep = None
            match = SLEEP_RE.search(line)
            if match:
                token = match.group(1)
                line = SLEEP_RE.sub("", line).strip()

                if ":" in token:
                    domain, value = token.split(":")
                else:
                    domain, value = "real", token

                sleep = {
                    "type": "sleep",
                    "domain": domain.strip(),
                    "seconds": float(value),
                }

            tokens = line.split()

            if tokens[0] == "logfile":
                actions.append({
                    "type": "log_config",
                    "filename": tokens[1],
                })

            elif tokens[0].startswith("s_"):
                actions.append({
                    "type": "state_transition",
                    "state": tokens[0],
                })

            elif tokens[0] == "I":
                actions.append({
                    "type": "set_parameter",
                    "param": "I",
                    "value": float(tokens[1]),
                    "fpga_value" : calculate_parameter_fpga_value("I", float(tokens[1])), 
                })

            else:
                raise ValueError(f"{filename}:{lineno} Unknown command")

            if sleep:
                actions.append(sleep)

    return actions

# ==========================
# Transport abstraction
# ==========================

class Transport:
    def write_word(self, value: int):
        raise NotImplementedError

    def read_bytes(self, n: int) -> bytes:
        return b""

    def close(self):
        pass

# --------------------------
# UART transport
# --------------------------

class SerialTransport(Transport):
    def __init__(self, serial_connection):
        self.ser = serial_connection

    def write_word(self, value: int):
        data = value.to_bytes(4, byteorder="big")
        self.ser.write(data)
        self.ser.flush()

    def read_bytes(self, n: int) -> bytes:
        return self.ser.read(n)

    def close(self):
        if self.ser and self.ser.is_open:
            self.ser.close()

# --------------------------
# Simulation transport
# --------------------------

class SimulationTransport(Transport):
    def __init__(self, decode_fn=None):
        self.decode_fn = decode_fn

    def write_word(self, value: int):
        if self.decode_fn:
            decoded = self.decode_fn(value)
            print(f"[SIM WRITE] {decoded}")
        else:
            print(f"[SIM WRITE] raw=0x{value:08X}")

# ==========================
# Read Thread Manager
# ==========================

class ReadThreadManager:
    def __init__(self, transport, stop_event, byte_separator=' ', word_separator='  '):
        self.transport = transport
        self.stop_event = stop_event
        self.byte_separator = byte_separator
        self.word_separator = word_separator
        self.data_queue = queue.Queue(maxsize=10000)
        self.reader_thread = None
        self.logger_thread = None
        self.is_running = False
        
    def _read_worker(self, buffer_size=4096):
        """Continuously read from transport and queue data."""
        try:
            while not self.stop_event.is_set() and self.is_running:
                raw = self.transport.read_bytes(buffer_size)
                
                if len(raw) == 0:
                    continue
                
                timestamp = time.time()
                
                # Process complete 4-byte chunks
                chunks = []
                for i in range(0, len(raw) - (len(raw) % 4), 4):
                    chunk = raw[i:i+4]
                    chunks.append(chunk)
                
                if chunks:
                    self.data_queue.put((timestamp, chunks))
                    
        except Exception as e:
            print(f"Read thread error: {e}")
            self.stop_event.set()
    
    def _log_worker(self, logfile_path):
        """Consume data from queue and log it."""
        with open(logfile_path, "w") as f:
            f.write("timestamp,values\n")
            
            batch = []
            batch_size = 50
            
            while not self.stop_event.is_set() or not self.data_queue.empty():
                try:
                    timestamp, chunks = self.data_queue.get(timeout=0.1)
                    
                    # Format all chunks into hex strings
                    hex_words = []
                    for chunk in chunks:
                        if self.byte_separator:
                            hex_word = self.byte_separator.join(f'{b:02X}' for b in chunk)
                        else:
                            hex_word = chunk.hex().upper()
                        hex_words.append(hex_word)
                    
                    values_str = self.word_separator.join(hex_words)
                    line = f"{timestamp:.6f},{values_str}\n"
                    batch.append(line)
                    
                    if len(batch) >= batch_size:
                        f.writelines(batch)
                        batch = []
                        f.flush()
                        
                except queue.Empty:
                    if batch:
                        f.writelines(batch)
                        batch = []
                        f.flush()
                    continue
            
            # Final flush
            if batch:
                f.writelines(batch)
                f.flush()
    
    def start(self, logfile_path):
        """Start reading and logging."""
        if self.is_running:
            print("Warning: Read thread already running")
            return
        
        self.is_running = True
        
        self.reader_thread = threading.Thread(
            target=self._read_worker,
            daemon=True
        )
        
        self.logger_thread = threading.Thread(
            target=self._log_worker,
            args=(logfile_path,),
            daemon=True
        )
        
        self.reader_thread.start()
        self.logger_thread.start()
        
        print(f"Started logging to {logfile_path}")
    
    def stop(self):
        """Stop reading and logging."""
        if not self.is_running:
            return
        
        self.is_running = False
        time.sleep(0.5)  # Allow threads to finish
        print("Stopped logging")

# ==========================
# FPGA word decoding
# ==========================

def decode_fpga_word(word: int):
    ID = (word >> 24) & 0xFF
    payload = word & 0x00FFFFFF

    ID_map = {
        1: "STATE",
        2: "CURRENT",
        3: "SOC",
        4: "Q",
    }

    return {
        "id": ID,
        "name": ID_map.get(ID, f"UNKNOWN({ID})"),
        "payload_raw": payload,
        "payload_hex": f"0x{payload:06X}",
        "full_word": f"0x{word:08X}"
    }

# ==========================
# Write worker thread
# ==========================

def write_worker(transport, write_queue, stop_event):
    while not stop_event.is_set():
        try:
            data = write_queue.get(timeout=0.1)
            transport.write_word(data)
            write_queue.task_done()
            time.sleep(0.05)
        except queue.Empty:
            continue

def start_write_thread(transport, stop_event):
    write_queue = queue.Queue(maxsize=100)
    t = threading.Thread(
        target=write_worker,
        args=(transport, write_queue, stop_event),
        daemon=True
    )
    t.start()
    return write_queue, t

# ==========================
# State transitions
# ==========================

def transition_state(transport, state, write_queue=None):
    state_map = {
        "s_idle":        0x01000000,
        "s_init":        0x01000001,
        "s_verification":0x01000002,
        "s_simulation":  0x01000003,
        "s_pause":       0x01000004,
    }

    if state not in state_map:
        if state == 's_sim':
            state = 's_simulation'
        else:
            raise ValueError(f"Invalid state {state}")

    value = state_map[state]

    if write_queue:
        write_queue.put(value)
    else:
        transport.write_word(value)

# ==========================
# Parameter write
# ==========================

def write_parameter(transport, value, write_queue=None):
    if write_queue:
        write_queue.put(value)
    else:
        transport.write_word(value)

# ==========================
# Execute plan
# ==========================

def execute_plan(
    actions,
    transport,
    write_queue,
    read_thread_manager,
    sim_time_to_real,
):
    logging_started = False
    log_filename = None

    for action in actions:
        t = action["type"]

        if t == "log_config":
            log_filename = action["filename"]

        elif t == "state_transition":
            state = action["state"]
            transition_state(transport, state, write_queue)

            if state in ["s_sim", "s_simulation"] and not logging_started:
                if read_thread_manager and log_filename:
                    read_thread_manager.start(log_filename)
                    logging_started = True
                else:
                    print("Warning: Cannot start logging (no manager or filename)")

        elif t == "set_parameter":
            write_parameter(
                transport,
                action["fpga_value"],
                write_queue,
            )

        elif t == "sleep":
            domain = action["domain"]
            seconds = action["seconds"]
            
            # Normalize domain names
            if domain in ["real", "t_real"]:
                print(f"Sleeping for {seconds:.3f} real seconds")
                time.sleep(seconds)

            elif domain in ["sim", "t_sim"]:
                real_wait = sim_time_to_real(seconds)
                print(f"Sleeping for {seconds:.3f} sim seconds ({real_wait:.3f} real seconds)")
                time.sleep(real_wait)

            else:
                raise ValueError(f"Unknown sleep domain '{domain}'. Use 'real', 't_real', 'sim', or 't_sim'")

        else:
            raise RuntimeError(f"Unhandled action type {t}")
# ==========================
# Safe shutdown
# ==========================

def safe_shutdown(transport, stop_event=None, write_queue=None, read_manager=None):
    print("\n=== Safe shutdown ===")

    if read_manager:
        read_manager.stop()

    if stop_event:
        stop_event.set()
        time.sleep(0.2)

    if write_queue:
        write_queue.join()

    try:
        transition_state(transport, "s_idle")
    except Exception:
        pass

    transport.close()
    print("Shutdown complete")

# ==========================
# Signal handling
# ==========================

def setup_signal_handlers(transport, stop_event, write_queue, read_manager=None):
    def handler(sig, frame):
        print("\nCtrl+C detected")
        safe_shutdown(transport, stop_event, write_queue, read_manager)
        sys.exit(0)

    signal.signal(signal.SIGINT, handler)
    atexit.register(lambda: safe_shutdown(transport, stop_event, write_queue, read_manager))

# ==========================
# FPGA serial open
# ==========================

def open_serial_port(port, baud):
    ser = serial.Serial(
        port=port,
        baudrate=baud,
        timeout=0,
        write_timeout=1
    )
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return ser

# ==========================
# Main
# ==========================

if __name__ == "__main__":

    stop_event = threading.Event()

    if RUN_MODE == RunMode.FPGA:
        ser = open_serial_port("/dev/ttyUSB1", 115200)
        transport = SerialTransport(ser)
        read_manager = ReadThreadManager(transport, stop_event)
        print("Running in FPGA mode")

    else:
        transport = SimulationTransport(decode_fn=decode_fpga_word)
        read_manager = None  # No reading in simulation mode
        print("Running in SIMULATION mode")

    # Start write thread
    write_queue, write_thread = start_write_thread(transport, stop_event)
    setup_signal_handlers(transport, stop_event, write_queue, read_manager)

    scenario_file = "scenario_1.txt"

    actions = parse_scenario(scenario_file)
    print(f"Parsed {len(actions)} actions from scenario file.")
    print(f"Executing scenario...{actions}")

    execute_plan(
        actions,
        transport,
        write_queue,
        read_thread_manager=read_manager,
        sim_time_to_real=lambda t: realtime_wait_for_sim_seconds(
            sim_seconds=t,
            fpga_clk_hz=50e6,
            timestep=3,
            cycles_per_sim_step=(5/32)*1e6,
        )
    )
    
    print("\nScenario execution complete!")
    safe_shutdown(transport, stop_event, write_queue, read_manager)
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import matplotlib.pyplot as plt  # For plotting (in stall with pip if needed)
import numpy as np

import sys
import os
# Add the library path to import FP_Conversion
sys.path.append("/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/Working Simulator/Preprocessing") # format_parse_string from
from FP_Conversion import decimal_to_binary, binary_to_decimal
sys.path.append("/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/PC interface")
from Preprocessing import format_parse_string, decimal_to_binary_string

# ============= Settings ============
clk_periods = 4
clk_time_ns = 20  # 20ns clock period

# Simulation time - can override via environment variable: SIM_TIME_US=500 make
SIM_TIME_US = int(os.environ.get("SIM_TIME_US", 800))  # Default 200 microseconds

# ============= Data Logging =============
# Lists to store signal data during simulation
time_data = []
dVR0_data = []
SOC_data = []
# Add more lists for other signals as needed





# ============= Formats =============
I_fmt = "4EN12"
SOC_fmt = "7EN17"
Q_fmt = "-8EN16"
R0_fmt = "8EN8"
a1_fmt = "-5EN16"
c1_fmt = "0EN16"
a2_fmt = "-7EN16"
c2_fmt = "-5EN16"


# ============= IDs =============
ID_SM   = 1
ID_I    = 2
ID_SOC0 = 3
ID_Q    = 4
ID_pw   = 5
ID_pri  = 6
ID_R0   = 2


    

# Helper function to send UART data (bit-bang serial transmission)
async def send_uart_byte(dut, byte: int, bit_time_ns: int = clk_periods*clk_time_ns+clk_time_ns):
    """Send a byte via UART on dut.i_rx (start bit, 8 data bits, stop bit)."""
    # Start bit (low)
    dut.i_rx.value = 0
    await Timer(bit_time_ns, unit="ns")
    # Data bits (LSB first)
    for i in range(8):
        dut.i_rx.value = (byte >> i) & 1
        await Timer(bit_time_ns, unit="ns")
    # Stop bit (high)
    dut.i_rx.value = 1
    await Timer(bit_time_ns, unit="ns")


# Helper to send a state command (based on your VHDL: ID=1, state=value)
async def send_state_cmd(dut, state: int):
    """Send UART command with bytes: 1, 0, 0, 1."""
    await send_uart_byte(dut, 1)     # ID for state command
    await send_uart_byte(dut, 0)     # 
    await send_uart_byte(dut, 0)     # 
    await send_uart_byte(dut, state)     # 

async def send32bit(dut, ID, format, value):
    """ Send a 32-bit value via UART with given ID and format."""
    # Calculate 
    # Step 1: Convert value to binary string using FP_Conversion
    # binary_str, _ = decimal_to_binary(value, format)  # Unpack tuple, ignore error
    binary_str = decimal_to_binary_string(value, format)
    int_bits, frac_bits, pos = format_parse_string(format)
    print(f"Format: {format}, Int bits: {int_bits}, Frac bits: {frac_bits}")
    # if int_bits+frac_bits < 24 append zeros to the left
    total_bits = int(int_bits) + int(frac_bits)
    if total_bits < 24:
        binary_str = '0' * (24 - total_bits) + binary_str
        print(f"Padded binary string to 24 bits: {binary_str}")
    # Step 2: Convert the ID to a byte (8 bits, integer only)
    id_byte, _ = decimal_to_binary(ID, "8EN0")  # Unpack tuple here too
    # Step 3: Concatenate ID and binary string to form 32 bit data packet 
    data_packet = id_byte + binary_str

    print(f"Sending 32-bit packet: ID={ID}, value={value}, binary={data_packet}")
    # Step 4: Send the 32 bits via UART (8 bits at a time)
    for i in range(4):
        byte_str = data_packet[i*8:(i+1)*8]
        byte_value = int(byte_str, 2)
        await send_uart_byte(dut, byte_value, bit_time_ns=clk_periods*clk_time_ns+clk_time_ns)

async def change_rx_assign_data(dut, assign_state_no : int, current_simulation_state : int):
    """ 
        The ID is 1, and the simulation state is 
            s_idle=0,  
            s_init=1, 
            s_verification=2, 
            s_simulation=3 
    """
    id_byte = "00000001" # ID = 1
   
    assign_rx_state_byte = decimal_to_binary_string(assign_state_no, "4EN0") # 4 bits ¶ LSBs
    current_sim_state_byte = decimal_to_binary_string(current_simulation_state, "4EN0") # 4 bits ¶ LSBs
    padding_bits = (32 - len(id_byte) - len(assign_rx_state_byte) - len(current_sim_state_byte)) * "0"
    data_packet = id_byte +  padding_bits + assign_rx_state_byte + current_sim_state_byte 
    print(f"Changing RX assign data packet: assign_state_no={assign_state_no}, current_simulation_state={current_simulation_state}, binary={data_packet}")
    for i in range(4):
        byte_str = data_packet[i*8:(i+1)*8]
        byte_value = int(byte_str, 2)
        await send_uart_byte(dut, byte_value, bit_time_ns=clk_periods*clk_time_ns+clk_time_ns)  

async def send32bitTableData(dut, ID: int, row: int, col: int, value: float, format_str: str):
    """ Send a 32-bit table data value via UART with given row, col and format."""
    id_byte, _ = decimal_to_binary(ID, "8EN0") 
    if row == 0 :
        row_bin = "0000"
    else:
        row_bin, _ = decimal_to_binary(row, "4EN0")
    if col == 0 :
        col_bin = "0000"
    else:
        col_bin, _ = decimal_to_binary(col, "4EN0")
    value_bin, _ = decimal_to_binary(value, format_str)
    data_packet = id_byte + row_bin + col_bin + value_bin
    print(f"Sending Table Data packet: ID={ID}, row={row}, col={col}, value={value}, binary={data_packet}")
    for i in range(4):
        byte_str = data_packet[i*8:(i+1)*8]
        byte_value = int(byte_str, 2)
        await send_uart_byte(dut, byte_value, bit_time_ns=clk_periods*clk_time_ns+clk_time_ns)  
    
async def set_capacity(dut, ID : int, capacity_ah: float, format_str: str):
    """ Set the battery capacity (in Ah) but it is inverted and multiplied by 36"""
    inverted_capacity = 1/(capacity_ah * 36)
    id_byte, _ = decimal_to_binary(ID, "8EN0")

    capacity_bin = decimal_to_binary_string(inverted_capacity, format_str)
    format_int, format_frac, isneg = format_parse_string(format_str)
    if isneg:
        print("Negative format stirng, correcting total bits calculation")
        total_bits = int(format_frac)
        data_packet = id_byte + (24-total_bits) * "0" + capacity_bin[0:total_bits]

    else:
        total_bits = int(format_int) + int(format_frac)
    
        data_packet = id_byte + capacity_bin

    print(f"Setting Capacity packet: ID={ID}, capacity_ah={capacity_ah}, inverted={inverted_capacity}, binary={data_packet} of (length {len(data_packet)})")
    for i in range(4):
        byte_str = data_packet[i*8:(i+1)*8]
        print(f"Byte {i}: {byte_str}")
        byte_value = int(byte_str, 2)
        await send_uart_byte(dut, byte_value, bit_time_ns=clk_periods*clk_time_ns+clk_time_ns)


# ============= Support Functions =============

async def log_signals(dut, sample_interval_ns=100, duration_us=None):
    """
    Coroutine to log signals at regular intervals during simulation.
    
    Args:
        dut: Device under test
        sample_interval_ns: Sampling interval in nanoseconds
        duration_us: Optional duration to log (if None, runs indefinitely)
    """
    global time_data, dVR0_data, SOC_data
    time_ns = 0
    
    while duration_us is None or time_ns < duration_us * 1000:
        await Timer(sample_interval_ns, units="ns")
        time_ns += sample_interval_ns
        
        # Sample signals - adjust signal paths based on your DUT hierarchy
        try:
            time_data.append(time_ns)
            # dV_R0 is 24-bit unsigned, format depends on your fixed-point representation
            dVR0_raw = dut.dV_R0.value.integer if hasattr(dut, 'dV_R0') else 0
            dVR0_data.append(dVR0_raw)
            
            # Add more signals as needed:
            # SOC_raw = dut.r_SOC.value.integer if hasattr(dut, 'r_SOC') else 0
            # SOC_data.append(SOC_raw)
        except Exception as e:
            cocotb.log.warning(f"Signal logging error at {time_ns}ns: {e}")


def get_numpy_vectors():
    """
    Convert logged data to numpy arrays.
    Returns dict of numpy arrays with signal data.
    """
    return {
        'time_ns': np.array(time_data),
        'dVR0': np.array(dVR0_data),
        'SOC': np.array(SOC_data),
    }


def convert_fixed_point(data, int_bits, frac_bits):
    """
    Convert raw fixed-point values to floating point.
    
    Args:
        data: numpy array of raw integer values
        int_bits: number of integer bits
        frac_bits: number of fractional bits
    
    Returns:
        numpy array of float values
    """
    return data.astype(float) / (2 ** frac_bits)



# Reusable state transition test helper
async def test_state_transition(dut, state: int, name: str = None, wait_us: int = 1):
    """Send state command and verify transition with soft assertion.
    
    Args:
        dut: Device under test
        state: Expected state number to transition to
        name: Optional descriptive name for the state (e.g., "s_init")
        wait_us: Microseconds to wait after sending command (default: 1)
    
    Returns:
        bool: True if state matched, False otherwise
    """
    state_name = name if name else f"state={state}"
    cocotb.log.info(f"Transition to {state_name}")
    
    await send_state_cmd(dut, state)
    await Timer(wait_us, unit="us")
    
    actual_state = dut.r_SM_no.value.integer
    # if actual_state != state:
    #     cocotb.log.error(f"ASSERTION FAILED: Expected {state_name} ({state}), got {actual_state}")
    #     return False
    # else:
    #     cocotb.log.info(f"State check passed: {state_name} ({actual_state})")
    #     return True

@cocotb.test()
async def test_basic_state_transitions(dut):
    """Test 1: Basic state transitions (idle -> init -> verification -> simulation -> idle)."""
    # Setup clock (20ns period for 20ns cycle)
    cocotb.start_soon(Clock(dut.i_clk, 20, units="ns").start())
    
    # Initialize
    dut.i_rx.value = 1  # UART idle high

    # 
    soc_value = 80  # SOC in percent (integer part)

    dut.r_SOC_init.value = soc_value << 17  # Shift to fixed-point format
    await Timer(400, unit="ns")  # Initial wait
    
    # Test transitions - now just one line each!
    state_no = 1
    await test_state_transition(dut, state_no, "s_init")


    #await test_state_transition(dut, 2, "s_verification")
    #await test_state_transition(dut, 3, "s_simulation")
    #await test_state_transition(dut, 0,
    #  "s_idle")
        # --- Part 2: Input injection (while in simulation state) ---
    cocotb.log.info("Injecting current value...")
    I = 2  # Example current value to inject
    await send32bit(dut, ID_I, I_fmt, I)
    await Timer(100, unit="ns")  # Wait for processing

    SOC0 = 80.0  # Example initial state of charge
    cocotb.log.info(f"Injecting initial SOC value...")
    await send32bit(dut, ID_SOC0, SOC_fmt, SOC0)
    # Sending the Table Data for R0 requires switching the RX assign data state
    await change_rx_assign_data(dut, 1, state_no)  # assign_state
    #await Timer(100, unit="ns")  # Wait for processing
    R0_value = 133.0  # R0 in mOhm
    row = 0
    col = 0
    cocotb.log.info(f"Injecting R0 value... as table data row, col = [{row}, {col}]")


    await send32bitTableData(dut, ID_R0, row, col, R0_value, R0_fmt)

    row = 1
    col = 10
    R0_val = 6
    cocotb.log.info(f"Injecting R0 value... as table data ")
    await send32bitTableData(dut, ID_R0, row, col, R0_val, R0_fmt)
    await Timer(100, unit="ns")  # Wait for processing

    ## Set capacity (Rx Assign state 0 )
    await change_rx_assign_data(dut, 0, state_no)  # assign_state

    capacity = 9.0  # Ah 
    cocotb.log.info(f"Setting battery capacity to {capacity} Ah...")
    await set_capacity(dut, ID_Q, capacity, Q_fmt)
    rx_assign_state = 1
    await change_rx_assign_data(dut, rx_assign_state, state_no)  # assign_state

    pw_clk_cycles = 30  # Example pulse width in clock cycles
    
    state_no = 3
    await test_state_transition(dut, state_no, "s_simulation")
    wait_100s = 139.2

    await send32bit(dut, ID_pw, "24EN0", pw_clk_cycles)

    # Move to simulation state and observe effects
    await Timer(wait_100s, unit="us")  # Wait for processing


    # Start signal logging coroutine (runs in background)
    log_task = cocotb.start_soon(log_signals(dut, sample_interval_ns=1000, duration_us=SIM_TIME_US))
    
    # Run for remaining time (account for time already spent ~19us)
    remaining_time = SIM_TIME_US - 20  # Subtract setup time
    if remaining_time > 0:
        cocotb.log.info(f"Running simulation for {remaining_time} us...")
        await Timer(remaining_time, unit="us")
    
    # Get numpy vectors
    vectors = get_numpy_vectors()
    cocotb.log.info(f"Logged {len(vectors['time_ns'])} samples")
    cocotb.log.info(f"dVR0 shape: {vectors['dVR0'].shape}")
    
    # Optional: Save to file for later analysis
    np.savez('simulation_data.npz', **vectors)
    cocotb.log.info("Data saved to simulation_data.npz")
    
    # Optional: Convert to real values (adjust format as needed)
    # dVR0 is 24-bit, you'll need to check the actual format in your VHDL
    # dVR0_real = convert_fixed_point(vectors['dVR0'], int_bits=12, frac_bits=12)
    
    cocotb.log.info("Simulation complete.")
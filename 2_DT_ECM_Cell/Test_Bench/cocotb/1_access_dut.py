import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import matplotlib.pyplot as plt  # For plotting (in stall with pip if needed)

import sys
import os
# Add the library path to import FP_Conversion
sys.path.append("/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/Working Simulator/Preprocessing") # format_parse_string from
from FP_Conversion import decimal_to_binary, binary_to_decimal
sys.path.append("/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/PC interface")
from Preprocessing import format_parse_string

# ============= Settings ============
clk_periods = 4
clk_time_ns = 20  # 20ns clock period

# Simulation time - can override via environment variable: SIM_TIME_US=500 make
SIM_TIME_US = int(os.environ.get("SIM_TIME_US", 200))  # Default 200 microseconds


# ============= Formats =============
I_fmt = "4EN12"
SOC_fmt = "7EN17"
R0_fmt = "8EN16"
a1_fmt = "-5EN16"
c1_fmt = "0EN16"
a2_fmt = "-7EN16"
c2_fmt = "-5EN16"

# ============= IDs =============
ID_SM = 1
ID_I  = 2
ID_SOC0 = 3

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
    binary_str, _ = decimal_to_binary(value, format)  # Unpack tuple, ignore error
    
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

# ============= Support Functions =============



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
    if actual_state != state:
        cocotb.log.error(f"ASSERTION FAILED: Expected {state_name} ({state}), got {actual_state}")
        return False
    else:
        cocotb.log.info(f"State check passed: {state_name} ({actual_state})")
        return True

@cocotb.test()
async def test_basic_state_transitions(dut):
    """Test 1: Basic state transitions (idle -> init -> verification -> simulation -> idle)."""
    # Setup clock (20ns period for 20ns cycle)
    cocotb.start_soon(Clock(dut.i_clk, 20, units="ns").start())
    
    # Initialize
    dut.i_rx.value = 1  # UART idle high
    dut.i_sw.value = 0
    soc_value = 80  # SOC in percent (integer part)
    dut.r_SOC_init.value = soc_value << 17  # Shift to fixed-point format
    await Timer(400, unit="ns")  # Initial wait
    
    # Test transitions - now just one line each!
    await test_state_transition(dut, 1, "s_init")
    #await test_state_transition(dut, 2, "s_verification")
    #await test_state_transition(dut, 3, "s_simulation")
    #await test_state_transition(dut, 0, "s_idle")
        # --- Part 2: Input injection (while in simulation state) ---
    cocotb.log.info("Injecting current value...")
    I = 2  # Example current value to inject
    await send32bit(dut, ID_I, I_fmt, I)
    await Timer(100, unit="ns")  # Wait for processing

    SOC0 = 80.0  # Example initial state of charge
    cocotb.log.info(f"Injecting initial SOC value...")
    await send32bit(dut, ID_SOC0, SOC_fmt, SOC0)
    await Timer(100, unit="ns")  # Wait for processing

    # Move to simulation state and observe effects
    await test_state_transition(dut, 3, "s_simulation")
    
    
    # Run for remaining time (account for time already spent ~19us)
    remaining_time = SIM_TIME_US - 20  # Subtract setup time
    if remaining_time > 0:
        cocotb.log.info(f"Running simulation for {remaining_time} us...")
        await Timer(remaining_time, unit="us")
    
    
    cocotb.log.info("Simulation complete.")
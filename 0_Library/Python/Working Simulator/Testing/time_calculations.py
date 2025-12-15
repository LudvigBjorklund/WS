

def calculate_sim_time(timestep):
    # dt = 2^(-timestep) seconds
    dt = 2 ** (-timestep)
    # Representing a millisecond will take 2^(-timestep) * 1000 microseconds
    print(f"With timestep {timestep}, each simulation step is {dt} seconds and in milliseconds this is {dt * 1000} ms")
    steps_per_second = 1 / dt
    print(f"With timestep {timestep}, the simulation runs at {steps_per_second} steps per second")
    # "Each clock period adds {dt} seconds"

    return

def calculate_realtime_simulation_time(timestep, clock_cycle, simulation_time_string):
    dt = 2 ** (-timestep)
    # Calculate the number of clock cycles needed for the simulation time
    time_units = {
        'h': 3600,
        'm': 60,
        's': 1,
        'ms': 1e-3,
        'us': 1e-6,
        'ns': 1e-9
    }
    # Converting the string to seconds  by splitting the string at first non-numeric character
    numeric_part = ''.join(filter(str.isdigit, simulation_time_string))
    print(f"The numeric part is: {numeric_part}")
    unit_part = simulation_time_string[len(numeric_part):]
    print(f"The unit part is: {unit_part}")
    simulation_time_in_seconds = time_units[unit_part] * int(numeric_part)
    print(f"Simulating for {simulation_time_in_seconds} secondss")

    clock_cycles_needed = simulation_time_in_seconds / dt
    print(f"With timestep {timestep}, simulating for {simulation_time_string} requires {clock_cycles_needed} clock cycles.")
    print(f"Simulating for {simulation_time_string} with timestep {timestep} ({dt}) requires {clock_cycles_needed} clock cycles.")
    real_time = clock_cycles_needed * clock_cycle
    print(f"Real time for {simulation_time_string} with timestep {timestep} is {real_time} seconds.")

def calculate_time_to_fully_discharged_battery(timestep, clock_cycle, cell_capacity, initial_soc, discharge_current):
    dt = 2 ** (-timestep)
    # Calculate the time to fully discharge the battery
    time_to_discharge = cell_capacity*3600 * initial_soc / discharge_current
    # Calculate time in hours&minutes and seconds using modulo
    hours = time_to_discharge // 3600
    remainder = time_to_discharge % 3600
    minutes = (remainder) // 60
    remainder = remainder % 60
    seconds = remainder /60
    print(f"Time to fully discharge the battery is {hours} hours, {minutes} minutes, and {seconds} seconds.")
def calculate_time_to_soc(initial_soc, target_soc, capacity_ah, discharge_current_a):
    """
    Calculate the time required to reach a target State of Charge (SOC).
    
    Args:
        initial_soc (float): Initial SOC in percentage (0-100)
        target_soc (float): Target SOC in percentage (0-100)
        capacity_ah (float): Battery capacity in Ampere-hours (Ah)
        discharge_current_a (float): Discharge current in Amperes (A)
                                   Positive for discharge, negative for charge
    
    Returns:
        str: Time in HH:MM:SS format
        float: Time in hours
    
    Raises:
        ValueError: If inputs are invalid
    """
    
    # Input validation
    if not (0 <= initial_soc <= 100):
        raise ValueError("Initial SOC must be between 0 and 100")
    if not (0 <= target_soc <= 100):
        raise ValueError("Target SOC must be between 0 and 100")
    if capacity_ah <= 0:
        raise ValueError("Capacity must be positive")
    if discharge_current_a == 0:
        raise ValueError("Discharge current cannot be zero")
    
    # Calculate SOC change needed
    soc_change = target_soc - initial_soc
    
    # Check if we can reach the target with given current direction
    if (soc_change > 0 and discharge_current_a > 0) or (soc_change < 0 and discharge_current_a < 0):
        raise ValueError("Cannot reach target SOC with given current direction")
    
    # If already at target SOC
    if abs(soc_change) < 0.001:
        return "00:00:00", 0.0
    
    # Calculate energy change needed (in Ah)
    energy_change_ah = abs(soc_change / 100) * capacity_ah
    
    # Calculate time in hours
    time_hours = energy_change_ah / abs(discharge_current_a)
    
    # Convert to hours, minutes, seconds
    hours = int(time_hours)
    minutes = int((time_hours - hours) * 60)
    seconds = int(((time_hours - hours) * 60 - minutes) * 60)
    
    # Format as HH:MM:SS
    time_string = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    return time_string, time_hours

def calculate_soc_at_time(initial_soc, capacity_ah, discharge_current_a, time_hours):
    """
    Calculate the SOC after a given time.
    
    Args:
        initial_soc (float): Initial SOC in percentage (0-100)
        capacity_ah (float): Battery capacity in Ampere-hours (Ah)
        discharge_current_a (float): Discharge current in Amperes (A)
        time_hours (float): Time in hours
    
    Returns:
        float: SOC after the given time (0-100)
    """
    
    # Calculate energy consumed/added
    energy_change_ah = discharge_current_a * time_hours
    
    # Convert to SOC change percentage
    soc_change = (energy_change_ah / capacity_ah) * 100
    
    # Calculate final SOC (subtract for discharge, add for charge)
    final_soc = initial_soc - soc_change
    
    # Clamp to valid range
    final_soc = max(0, min(100, final_soc))
    
    return final_soc

def time_string_to_hours(time_str):
    """
    Convert HH:MM:SS string to hours.
    
    Args:
        time_str (str): Time string in HH:MM:SS format
    
    Returns:
        float: Time in hours
    """
    try:
        hours, minutes, seconds = map(int, time_str.split(':'))
        return hours + minutes/60 + seconds/3600
    except:
        raise ValueError("Invalid time format. Use HH:MM:SS")



if __name__ == "__main__":
    calculate_sim_time(8)
    calculate_realtime_simulation_time(20, 1e-9, "9h")
    calculate_time_to_fully_discharged_battery(timestep=8, clock_cycle=1e-9, cell_capacity=18.0, initial_soc=1.0, discharge_current=1.995)

        # Example 1: Discharge from 100% to 50%
    SOC = 100
    target_SOC = 97
    capacity_Ah = 18
    I = 2
    try:
        time_str, time_h = calculate_time_to_soc(
            initial_soc=SOC,
            target_soc=target_SOC,
            capacity_ah=capacity_Ah,
            discharge_current_a=I
        )
        print(f"Example 1 - Discharge 100% → 50%:")
        print(f"  Battery: 10Ah, Current: 2A discharge")
        print(f"  Time needed: {time_str} ({time_h:.2f} hours)")
        print()
    except ValueError as e:
        print(f"Error: {e}")
    
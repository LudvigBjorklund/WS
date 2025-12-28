import sys
import os
import pandas as pd
import matplotlib.pyplot as plt


# Add preprocessing functions from the module in the parent directory
path_to_main_modules = os.path.abspath(os.path.join(os.path.dirname(__file__), '..','..','..'))
support_functions_path = '/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/PC interface'

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
sys.path.append(support_functions_path)
import Preprocessing as preprocess
import FPGA_Interface as fpga
import Postprocessing as postprocess

def remove_data_before_first_full_dp(filename: str) -> str:
    # ...existing code...
    """
    Remove data before the first FF FF marker (start of a valid data packet).
    
    Args:
        filename: Path to the input file
        
    Returns:
        The cleaned data as a string
    """
    with open(filename, 'r') as f:
        content = f.read()
    
    # Split into lines and process each line
    lines = content.strip().split('\n')
    cleaned_lines = []
    
    for line in lines:
        # Split timestamp from data
        if ':' not in line:
            continue
            
        parts = line.split(':', 1)
        if len(parts) != 2:
            continue
            
        timestamp = parts[0].strip()
        data = parts[1].strip()
        
        # Split data into hex bytes
        hex_bytes = data.split()
        
        # Find the first "FF FF" pattern (start of valid data packet)
        first_ff_ff_idx = None
        for i in range(len(hex_bytes) - 1):
            if hex_bytes[i] == 'FF' and hex_bytes[i + 1] == 'FF':
                first_ff_ff_idx = i
                break
        
        if first_ff_ff_idx is not None:
            # Keep data from first FF onwards (only keep one FF as packet start)
            cleaned_hex = hex_bytes[first_ff_ff_idx + 1:]  # Skip the first FF of FF FF, keep second FF as start
            cleaned_data = ' '.join(cleaned_hex)
            cleaned_lines.append(f"{timestamp}: {cleaned_data}")
        else:
            # No FF FF found, keep the line as is (or skip it)
            cleaned_lines.append(line)
    
    return '\n'.join(cleaned_lines)


def to_dataframe(filename: str) -> pd.DataFrame:
    """
    Parse the cleaned data file and extract data packets into a pandas DataFrame.
    
    Each data packet is between FF markers and contains 4 bytes.
    Format: FF <byte1> <byte2> <byte3> <byte4> FF
    
    Args:
        filename: Path to the cleaned data file
        
    Returns:
        DataFrame with columns: timestamp, byte1, byte2, byte3, byte4, raw_packet
    """
    timestep = 6  # Time step exponent for simulation time conversion
    # Mapping of ID to format string for binary_string_to_decimal
    format_map = {
        1: "6EN0",  # Simulation time, special case since 6 MSBs are minutes, next 6 bits seconds and last 12 are the steps in between
        3: "7EN17",  # SOC format
        4: "12EN12", # dV_R0 format 
        # Add other ID mappings as needed, e.g., 4: "some_other_format"
    }
    
    with open(filename, 'r') as f:
        content = f.read()
    
    rows = []
    for line in content.strip().split('\n'):
        if ':' not in line:
            continue
        
        parts = line.split(':', 1)
        if len(parts) != 2:
            continue
        
        timestamp = float(parts[0].strip())
        data = parts[1].strip()
        hex_bytes = data.split()
        
        # Find all data packets between FF markers
        # Pattern: FF <4 bytes> FF
        i = 0
        while i < len(hex_bytes)-1:
            # Look for start marker FF
            if hex_bytes[i] == 'FF' and hex_bytes[i + 1] != 'FF':
                # Check if we have enough bytes for a complete packet (FF + 4 bytes + FF)

                if i + 5 < len(hex_bytes) and hex_bytes[i + 5] == 'FF':
                    # Extract the 4 data bytes
                    byte1 = hex_bytes[i + 1]
                    byte2 = hex_bytes[i + 2]
                    byte3 = hex_bytes[i + 3]
                    byte4 = hex_bytes[i + 4]
                    
                    # Store raw packet for reference
                    raw_packet = f"FF {byte1} {byte2} {byte3} {byte4} FF"
                    # Create a binary representation of the data bytes from hex that is 24bits
                    raw_data_bin = ''.join(f"{int(b, 16):08b}" for b in [byte2, byte3, byte4])
                    
                    # Get ID
                    ID = int(byte1, 16)
                    
                    # Convert to decimal if format is known
                    decimal_value = None
                    if ID == 1:
                        dt  = 2**(-timestep)
                        t_fmt= "24EN0"
                        decimal_value = preprocess.binary_string_to_decimal(raw_data_bin, t_fmt) * dt
                    else:
                        if ID in format_map:
                            try:
                                decimal_value = preprocess.binary_string_to_decimal(raw_data_bin, format_map[ID])
                            except Exception as e:
                                print(f"Error converting binary to decimal for ID {ID}: {e}")
                                decimal_value = None
                    
                    rows.append({
                        'timestamp': timestamp,
                        'raw_packet': raw_packet,
                        'raw_data': f"{byte1}{byte2}{byte3}{byte4}",
                        'ID': ID,
                        'data_bin': raw_data_bin,
                        'decimal_value': decimal_value
                    })
                    
                    # Move past this packet (to the ending FF, which could be start of next)
                    i += 5
                else:
                    i += 1
            else:
                i += 1
   
    df = pd.DataFrame(rows)
    print(f"Extracted {len(df)} data packets from {filename}")
    return df

def transform_to_wide_format(df):
    """
    Transforms the dataframe to wide format where:
    - sim_time (from ID==1) is the first column
    - Each other ID gets its own column (ID_{id})
    - One row per unique sim_time value
    - Window is defined by first and second occurrence of each sim_time value
    
    Parameters:
    -----------
    df : pandas.DataFrame
        Original dataframe with 'ID' and 'decimal_value' columns
    
    Returns:
    --------
    pandas.DataFrame
        Transformed wide-format dataframe
    """
    # Reset index to ensure we have sequential row numbers
    df = df.reset_index(drop=True)
    print(df)
    # Get all ID==1 rows
    id1_df = df[df['ID'] == 1].copy()
    
    # Find unique sim_time values that appear exactly twice
    value_counts = id1_df['decimal_value'].value_counts()
    valid_sim_times = value_counts[value_counts == 2].index.tolist()
    
    # Get all unique IDs except ID==1
    other_ids = sorted(df[df['ID'] != 1]['ID'].unique())
    
    # Build result rows
    rows = []
    
    for sim_time in sorted(valid_sim_times):
        # Find first and second occurrence indices of this sim_time
        occurrences = id1_df[id1_df['decimal_value'] == sim_time].index.tolist()
        
        if len(occurrences) >= 2:
            start_idx = occurrences[0]
            end_idx = occurrences[1]
            
            row_data = {'sim_time': sim_time}
            
            # Get all rows between start and end (exclusive)
            window_df = df.loc[start_idx + 1:end_idx - 1]
            
            # For each other ID, get the first value found in the window
            for signal_id in other_ids:
                signal_values = window_df[window_df['ID'] == signal_id]['decimal_value']
                if len(signal_values) > 0:
                    row_data[f'ID_{signal_id}'] = signal_values.iloc[0]
                else:
                    row_data[f'ID_{signal_id}'] = pd.NA
            
            rows.append(row_data)
    
    result = pd.DataFrame(rows)
    print(f"Transformed to wide dataframe with shape {result.shape}")
    print("First 10 rows:")
    print(result.head(10))
    print("\nLast 10 rows:")
    print(result.tail(10))
    
    return result
def save_cleaned_data(cleaned_data: str, output_filename: str):
    # ...existing code...
    """
    Save the cleaned data to a file.
    
    Args:
        cleaned_data: The cleaned data string
        output_filename: Path to the output file
    """
    with open(output_filename, 'w') as f:
        f.write(cleaned_data)
    print(f"Cleaned data saved to: {output_filename}")

def get_unique_id1_indices(df):
    """
    Returns the indices of rows where ID==1 and the decimal_value appears only once.
    
    Parameters:
    -----------
    df : pandas.DataFrame
        DataFrame containing 'ID' and 'decimal_value' columns
    
    Returns:
    --------
    pandas.Index
        Indices of rows where ID==1 and decimal_value is unique
    """
    # Filter for ID==1 rows
    id1_mask = df['ID'] == 1
    id1_df = df[id1_mask]
    
    # Count occurrences of each decimal_value in ID==1 rows
    value_counts = id1_df['decimal_value'].value_counts()
    
    # Get decimal_values that appear only once
    unique_values = value_counts[value_counts == 1].index
    
    # Return indices where ID==1 AND decimal_value is unique
    result_indices = id1_df[id1_df['decimal_value'].isin(unique_values)].index
    
    return result_indices
def transform_to_wide_format(df):
    """
    Transforms the dataframe to wide format where:
    - sim_time (from ID==1) is the first column
    - Each other ID gets its own column (ID_{id})
    - One row per unique sim_time value
    - Window is defined by first and last occurrence of each sim_time value
    
    Parameters:
    -----------
    df : pandas.DataFrame
        Original dataframe with 'ID' and 'decimal_value' columns
    
    Returns:
    --------
    pandas.DataFrame
        Transformed wide-format dataframe
    """
    # Reset index to ensure we have sequential row numbers
    df = df.reset_index(drop=True)
    print(df)
    # Get all ID==1 rows
    id1_df = df[df['ID'] == 1].copy()
    
    # Find unique sim_time values that appear at least twice
    value_counts = id1_df['decimal_value'].value_counts()
    valid_sim_times = value_counts[value_counts >= 2].index.tolist()
    
    # Get all unique IDs except ID==1
    other_ids = sorted(df[df['ID'] != 1]['ID'].unique())
    
    # Build result rows
    rows = []
    
    for sim_time in sorted(valid_sim_times):
        # Find first and last occurrence indices of this sim_time
        occurrences = id1_df[id1_df['decimal_value'] == sim_time].index.tolist()
        
        if len(occurrences) >= 2:
            start_idx = occurrences[0]   # First occurrence
            end_idx = occurrences[-1]    # Last occurrence (changed from [1])
            
            row_data = {'sim_time': sim_time}
            
            # Get all rows between start and end (exclusive)
            window_df = df.loc[start_idx + 1:end_idx - 1]
            
            # For each other ID, get the first value found in the window
            for signal_id in other_ids:
                signal_values = window_df[window_df['ID'] == signal_id]['decimal_value']
                if len(signal_values) > 0:
                    row_data[f'ID_{signal_id}'] = signal_values.iloc[0]
                else:
                    row_data[f'ID_{signal_id}'] = pd.NA
            
            rows.append(row_data)
    
    result = pd.DataFrame(rows)
    print(f"Transformed to wide dataframe with shape {result.shape}")
    print("First 10 rows:")
    print(result.head(10))
    print("\nLast 10 rows:")
    print(result.tail(10))
    
    return result

def postprocess(filename: str) -> str:
    # ...existing code...
    """
    Main postprocessing function.
    
    Args:
        filename: Path to the input file
        
    Returns:
        Path to the cleaned file
    """
    # 1. Remove data before the first full data packet
    # Check first if the cleaned file already exists
    cleaned_filename = filename.replace('.txt', '_cleaned.txt')
    if os.path.exists(cleaned_filename):
        print(f"Cleaned file already exists: {cleaned_filename} skipping cleaning step.")
    else: 
        cleaned_data = remove_data_before_first_full_dp(filename)
        cleaned_filename = filename.replace('.txt', '_cleaned.txt')
        save_cleaned_data(cleaned_data, cleaned_filename)
    # 2. Parse the cleaned data into a DataFrame
    df = to_dataframe(cleaned_filename)
    # Save the DataFrame to CSV for reference
    csv_filename = cleaned_filename.replace('.txt', '_dataframe.csv')
    df.to_csv(csv_filename, index=False)
    print(f"DataFrame saved to: {csv_filename}")
    print(df.tail(20))
    print(f"\n\n\nThe shape of the DataFrame is: {df.shape}")
    
    ## Print the middle rows of the DataFrame
    mid_index = len(df) // 2
    start_index = max(0, mid_index - 10)
    end_index = min(len(df), mid_index + 10)
    print(f"\n\n\nMiddle rows of the DataFrame (rows {start_index} to {end_index}):")
    print(df.iloc[start_index:end_index])   
    # 3. Analyze the DataFrame with unique ID==1 decimal values
    unique_id1_indices = get_unique_id1_indices(df)
    print(f"Found {len(unique_id1_indices)} unique ID==1 decimal values at indices: {unique_id1_indices.tolist()}")

    wide_df = transform_to_wide_format(df)
    
    # 4. Save the wide DataFrame to CSV
    wide_csv_filename = cleaned_filename.replace('.txt', '_wide_format.csv')
    wide_df.to_csv(wide_csv_filename, index=False)
    print(f"Wide format DataFrame saved to: {wide_csv_filename}")
   
        

    return cleaned_filename


# Test/example usage
if __name__ == "__main__":

    # Default path - update this to your actual file location
    filename = '/home/ludvig/Desktop/FPGA_Synthesis/0_Library/Python/PostProcessing_data/soc_pulsed.txt'
    
    # Check if file exists
    if not os.path.exists(filename):
        print(f"Error: File not found: {filename}")
        print("Usage: python postprocess.py <path_to_file>")
        sys.exit(1)


    
    final_file = postprocess(filename)

    # Read the wide format CSV and plot some data
    wide_csv_filename = filename.replace('.txt', '_cleaned_wide_format.csv')
    if os.path.exists(wide_csv_filename):
        wide_df = pd.read_csv(wide_csv_filename)
        
        # Example plot: Plot ID_3 vs sim_time
        if 'ID_3' in wide_df.columns:
            plt.figure(figsize=(10, 6))
            plt.plot(wide_df['sim_time'], wide_df['ID_3'], marker='o', linestyle='-')
            plt.title('State of Charge vs Simulation Time')
            plt.xlabel('Simulation Time')
            plt.ylabel('State of Charge (ID_3)')
            plt.grid(True)
            plt.show()
        else:
            print("ID_3 column not found in the wide format DataFrame.")



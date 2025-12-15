

import sys
import os
import importlib.util
import pandas as pd
import matplotlib.pyplot as plt
# Define the absolute path to the Preprocessing.py file
preprocessing_path = '/home/ntnu/Documents/Digital Twin/DT_v3/PC-Host'
data_path  ='/home/ntnu/Documents/Digital Twin/DT_v3/Data Management/Results/GTK_Simulations/RC_Circuit_2025-04-24'
# Load the Preprocessing module dynamically
# spec = importlib.util.spec_from_file_location("Preprocessing", preprocessing_path)
# prep = importlib.util.module_from_spec(spec)
# Add the simulator path to sys.path
sys.path.append(data_path)
# Add the path to the Preprocessing module
sys.path.append(preprocessing_path)
# Import the Preprocessing module
import Preprocessing as prep


############################################################# SIMULATOR PROCESSING #############################################################
def read_csv_vcd(csv_file, dV_RC1_fmt):
    """
    Read a CSV file and convert binary strings to decimal values.
    
    Parameters:
    csv_file (str): Path to the CSV file.
    dV_RC1_fmt (str): Format string for conversion.
    
    Returns:
    pd.DataFrame: DataFrame with decimal values.
    """
    # Read the CSV file
    df = pd.read_csv(csv_file, dtype={'Clock Cycle': float, 'Value': str}, usecols=[0, 1]) # Binary dV_RC ()
    # Convert each binary string value to a decimal and store it in a new column
    df['Decimal Value'] = df['Value'].apply(lambda val: prep.binary_string_to_decimal(val, dV_RC1_fmt))
    
    return df
# Example usage

def plot_dataframes(dataframes, labels, y_label, colors=None):
    """
    Plot the 'Decimal Value' column of multiple DataFrames against their index.

    Parameters:
    dataframes (list of pd.DataFrame): List of DataFrames to plot.
    labels (list of str): List of labels for each DataFrame.
    y_label (str): Label for the y-axis.
    colors (list of str, optional): List of colors for each plot. Defaults to None.

    Returns:
    None
    """
    if colors is None:
        # Default colors if none are provided
        colors = ['red', 'purple', 'blue', 'orange', 'green', 'black', 'cyan']

    # Plot each DataFrame
    for i, df in enumerate(dataframes):
        plt.plot(df['Decimal Value'], label=labels[i], color=colors[i % len(colors)])

    # Set the y-axis label
    plt.ylabel(y_label)

    # Show grid and legend
    plt.grid()
    plt.legend()

    # Display the plot
    plt.show()
############################################################# SIMULATOR PROCESSING #############################################################




def process_txt_file(filepath):
    """
    Reads a text file with lines formatted as:
            (x,y): HEXVALUE
    For example:
            (6,0): FF03600000FF
            (0,0): FF03000000FF
    It creates a dictionary with keys as coordinate tuples (x, y) and values as the hex string.
    If duplicate coordinates exist, only the first occurrence is kept and the unique data is written 
    to a new file named <original_filename>_unique.txt.

    Args:
        filepath (str): Path to the input text file.
    
    Returns:
        dict: A dictionary with keys as (x, y) and values as hex strings.
    """
    data_dict = {}
    duplicates_found = False
    # This regex captures two numbers inside parentheses (with optional spaces) and the hex value after the colon.
    pattern = re.compile(r'\(\s*(\d+)\s*,\s*(\d+)\s*\):\s*([0-9A-Fa-f]+)')

    with open(filepath, 'r') as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        if not line:
            continue  # Skip blank lines.
        match = pattern.search(line)
        if match:
            x = int(match.group(1))
            y = int(match.group(2))
            hex_val = match.group(3)
            coord = (x, y)
            if coord in data_dict:
                duplicates_found = True
                # If duplicate, simply ignore this line.
                print(f"Duplicate found for coordinate {coord}. Skipping duplicate: {line}")
            else:
                data_dict[coord] = hex_val
        else:
            print("Line did not match expected pattern:", line)

    # If duplicates were found, write the unique entries to a new file.
    if duplicates_found:
        base, ext = os.path.splitext(filepath)
        new_filename = base + "_unique.txt"
        with open(new_filename, 'w') as f_out:
            for coord, hex_val in data_dict.items():
                f_out.write(f"({coord[0]},{coord[1]}): {hex_val}\n")
        print(f"Duplicates were removed. Unique data saved to '{new_filename}'.")
    
    return data_dict

def coordinate_dict_to_df(data_dict):
    """
    Converts a dictionary with keys as (row, column) tuples and values as data (e.g. hex strings)
    into a pandas DataFrame. Rows and columns are sorted in ascending order.
    
    Args:
        data_dict (dict): Dictionary with keys as (row, column) tuples and values as data.
    
    Returns:
        pd.DataFrame: DataFrame populated with the data.
    """
    # Determine all unique row and column indices from the keys
    rows = sorted(set(coord[0] for coord in data_dict.keys()))
    cols = sorted(set(coord[1] for coord in data_dict.keys()))
    
    # Create an empty DataFrame with the identified row and column indices.
    # Missing cells will be NaN by default.
    df = pd.DataFrame(index=rows, columns=cols)
    
    # Fill in the DataFrame using the data from the dictionary
    for (row, col), value in data_dict.items():
        df.at[row, col] = value
        
    return df
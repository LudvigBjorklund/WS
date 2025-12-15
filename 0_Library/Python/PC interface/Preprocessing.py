

import pandas as pd
import numpy as np
import os
import pandas as pd
import matplotlib.pyplot as plt



# Handle the Datamanametn sheet
def df_from_sheet_name(file_path, sheet_name):
    """
    Reads an xlsx file and returns a pandas dataframe.
    
    Parameters:
    file_path (str): The path to the xlsx file.
    sheet_name (str): The name of the sheet to read.
    
    Returns:
    pd.DataFrame: The dataframe containing the data from the specified sheet.
    """
    try:
        df = pd.read_excel(file_path, sheet_name=sheet_name)
        return df
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None






def format_parse_string(fmt_str):
    """
    Parse the format string of form 'XENy' or '-XENy'
    where for positive X: X is integer bits and y is fractional bits
    for negative X: |X| is number of zeros to left of fractional bits

    Args:
        fmt_str (str): Format string in the form 'XENy' or '-XENy'

    Returns:
        tuple: (number of integer/zero bits, number of fractional bits)
    """
    if fmt_str.startswith('-'):
        fmt_str = fmt_str[1:]  # Remove the minus sign
        is_negative_format = True
    else:
        is_negative_format = False

    parts = fmt_str.split('EN')
    return parts[0], parts[1], is_negative_format



def decimal_to_binary_string(decimal_number, format_string):
    """
    Convert decimal number to binary string considering the fixed-point format.
    For -iENj format, interpretation starts at 2^-(i-1).

    Args:
        decimal_number (float): Decimal number to convert
        format_string (str): Format string in 'iENj' or '-iENj' form

    Returns:
        str: Binary representation of the decimal number, padded to the full size of the format
    """
    n_int_bits, n_frac_bits, is_negative_format = format_parse_string(format_string)
    n_int_bits = int(n_int_bits)
    n_frac_bits = int(n_frac_bits)

    if is_negative_format:
        # For -iENj format, start interpretation at 2^-(i-1)
        start_power = -(n_int_bits + 1)
        total_bits = n_int_bits + n_frac_bits
        binary_vector = ''
        for i in range(total_bits):
            bit_value = 2 ** (start_power - i)
            if decimal_number >= bit_value:
                binary_vector += '1'
                decimal_number -= bit_value
            else:
                binary_vector += '0'
        return binary_vector
    else:
        # Standard iENj format
        if n_int_bits == 0:
            int_bin = ""
        else:
            # Convert the integer part to binary
            int_bin = bin(int(decimal_number))[2:].zfill(n_int_bits)  # [2:] removes '0b' prefix

        # Convert the fractional part to binary
        frac_val = decimal_number - int(decimal_number)
        frac_bin = ''
        for x in range(n_frac_bits):
            if frac_val == 0:
                break
            frac_val *= 2
            frac_bin += '1' if frac_val >= 1 else '0'
            frac_val -= int(frac_val)

        # Pad the fractional part with zeros if necessary
        frac_bin = frac_bin.ljust(n_frac_bits, '0')

        # Combine integer and fractional parts
        bin_vector = int_bin + frac_bin

        # Ensure the binary vector has the full size of the format
        total_bits = n_int_bits + n_frac_bits
        if len(bin_vector) < total_bits:
            bin_vector = bin_vector.ljust(total_bits, '0')

        return bin_vector
    
def binary_string_to_decimal(binary_vector, format_string, signed=False):
    """
    Convert binary string to decimal considering the fixed-point format. Unsigned by default.
    For -iENj format, interpretation starts at 2^-(i-1).

    Args:
        binary_vector (str): Binary string.
        format_string (str): Format string in 'iENj' or '-iENj' form.
        signed (bool): Whether the number is signed. If True, MSB indicates sign.

    Returns:
        float: Decimal representation of the binary number.
    """
    n_bits, n_frac_bits, is_negative_format = format_parse_string(format_string)
    n_bits = int(n_bits)
    n_frac_bits = int(n_frac_bits)

    if signed and binary_vector[0] == '1':
        # Handle negative numbers for signed representation
        is_negative = True

        binary_vector = binary_vector[1:]
    else:
        is_negative = False
    n_frac_bits_alt = len(binary_vector) - n_bits

    if is_negative_format:
        # For -iENj format, start interpretation at 2^-(i-1)
        start_power = -(n_bits + 1)
        decimal_value = 0
        for i, bit in enumerate(binary_vector):
            if bit == '1':
                decimal_value += 2 ** (start_power - i)
    else:
        # Standard iENj format
        if n_bits == 0:
            int_val = 0
            frac_bin = binary_vector
        else:
            int_bin = binary_vector[:n_bits]
            frac_bin = binary_vector[n_bits:]
            int_val = int(int_bin, 2)

        if n_frac_bits == 0:
            frac_val = 0
        else:
            frac_val = int(frac_bin, 2) / (2 ** n_frac_bits_alt)

        decimal_value = int_val + frac_val

    if signed and is_negative:
        # Apply sign to the final decimal value
        decimal_value = -decimal_value

    return decimal_value

def hex_to_binary(hex_string):
    """
    Convert a string of hexadecimal values to an equivalent binary string, 
    ensuring each hexadecimal value is padded to 8 bits.

    Args:
        hex_string (str): A string of hexadecimal values (e.g., "00FFAB").

    Returns:
        str: A binary string with each hexadecimal value converted to 8 bits.
    """
    # Remove any whitespace or newlines from the input string
    hex_string = hex_string.replace(" ", "").replace("\n", "")

    # Convert each hexadecimal character to its binary equivalent, padded to 8 bits
    binary_string = ''.join(f"{int(hex_char, 16):08b}" for hex_char in [hex_string[i:i+2] for i in range(0, len(hex_string), 2)])

    return binary_string

def decimal_to_hexadecimal(decimal_number, min_chars=0):
    """
    Convert a decimal number to its hexadecimal representation, ensuring the output
    is padded to a specified minimum number of characters.

    Args:
        decimal_number (int): The decimal number to convert.
        min_chars (int, optional): The minimum number of characters in the output. Defaults to 0.

    Returns:
        str: The hexadecimal representation of the decimal number, padded to the specified length.
    """
    try:
        # Convert the decimal number to hexadecimal and remove the "0x" prefix
        hex_string = hex(decimal_number)[2:].upper()

        # Pad the hexadecimal string with leading zeros to meet the minimum character requirement
        hex_string = hex_string.zfill(min_chars)

        return hex_string
    except ValueError:
        print("Invalid decimal number.")
        return None
def binary_to_hex(binary_string):
    """
    Convert a binary string to its hexadecimal representation.

    Args:
        binary_string (str): A string of binary digits (e.g., "1101").

    Returns:
        str: The hexadecimal representation of the binary string (e.g., "D").
    """
    try:
        # Ensure the binary string length is a multiple of 4 by padding with leading zeros
        padded_binary = binary_string.zfill((len(binary_string) + 3) // 4 * 4)
        
        # Convert the binary string to an integer, then to hexadecimal
        hex_string = hex(int(padded_binary, 2))[2:].upper()  # Remove "0x" prefix and convert to uppercase
        return hex_string
    except ValueError:
        print("Invalid binary string.")
        return None


def LUT_values(folder_path, LUT_file_name, parameter_dic):
    """
    Read the csv as a pandas dataframe and drop the last column.
    """
    # Read the CSV file into a DataFrame
    df = pd.read_csv(os.path.join(folder_path, LUT_file_name), header=0)
    
    # Drop the last column
    df = df.iloc[:, :-1]  # Select all rows and all columns except the last one
    
    return df


def convert_to_binary_2DLUT(df, parameter_dic, parameter_name,treshold=0.001, debug=False):
    """
    Convert the DataFrame values to binary string representations using the fixed-point format.
    """
    format_string = parameter_dic[parameter_name]['format_string']

    # Apply conversion element-wise (skiip the first column)
    # to avoid converting the index
    binary_df = df.map(lambda x: decimal_to_binary_string(x, format_string))
    # Printing the cells of both the original and binary DataFrames
    if debug:
        # Initialize with the same shape as binary_df
        df_rnd_error = pd.DataFrame(index=df.index, columns=df.columns)
        for row in range(len(df)):
            for col in range(len(df.columns)):  # Iterate over all columns in df_dropped
                original_value = df.iloc[row, col]
                binary_value = binary_df.iloc[row, col]
                converted_value = binary_string_to_decimal(binary_value, format_string)
                if original_value-converted_value > treshold:
                    print(f"Rounding error: {original_value - converted_value} at row {row}, col {col} for {parameter_name}")
                    print(f"Original: {original_value}, Binary: {binary_value} -> Converted: {converted_value} error : {original_value-converted_value}" )

                # Compute rounding error
                df_rnd_error.iloc[row, col] = converted_value - original_value
    return binary_df

def convert_to_write_ready_2D_LUT_bin(ID, value, format_string, row_idx, col_idx):
    row_idx_bin = decimal_to_binary_string(row_idx, "4EN0")
    col_idx_bin = decimal_to_binary_string(col_idx, "4EN0")

    value_bin = decimal_to_binary_string(value, format_string)
    # Converting the ID to binary
    ID_bin = decimal_to_binary_string(ID, "8EN0")
    complete_bin = ID_bin  + row_idx_bin + col_idx_bin + value_bin
    return complete_bin


# For reading the LUTs from excel
def process_excel_sheet_2DLUT(file_path, sheet_name, n_rows, n_cols, strt_col=0):
    # Load the sheet into a DataFrame
    df = pd.read_excel(file_path, sheet_name=sheet_name)
    
    # Set the first column as the index
    df.set_index(df.columns[0], inplace=True)
    
    # Slice the DataFrame to the desired dimensions
    df = df.iloc[:n_rows, :strt_col + n_cols]
    
    # Convert all values to numeric, replacing non-numeric values with 0
    df = df.apply(pd.to_numeric, errors='coerce').fillna(0)
    
    return df

def get_excel_sheet_names(file_path,print_sheet_names=False):
    xls = pd.ExcelFile(file_path)
    if print_sheet_names:
        print("Sheet names:", xls.sheet_names)
    return xls.sheet_names

def binary_to_hex(binary_string, fill_bits=None):
    """
    Convert a binary string to its hexadecimal representation, ensuring the output
    is padded to represent the specified number of bits.

    Args:
        binary_string (str): A string of binary digits (e.g., "1101").
        fill_bits (int, optional): The total number of bits to represent. If specified,
                                   the output will be padded to match the required number
                                   of hexadecimal characters.

    Returns:
        str: The hexadecimal representation of the binary string (e.g., "000D").
    """
    try:
        # Ensure the binary string length is a multiple of 4 by padding with leading zeros
        padded_binary = binary_string.zfill((len(binary_string) + 3) // 4 * 4)
        
        # Convert the binary string to an integer, then to hexadecimal
        hex_string = hex(int(padded_binary, 2))[2:].upper()  # Remove "0x" prefix and convert to uppercase
        
        # If fill_bits is specified, pad the hexadecimal string to match the required length
        if fill_bits:
            required_hex_length = (fill_bits + 3) // 4  # Calculate the number of hex characters needed
            hex_string = hex_string.zfill(required_hex_length)
        
        return hex_string
    except ValueError:
        print("Invalid binary string.")
        return None
import pandas as pd
import numpy as np
import FP_Conversion as fp
import Generate.generate_vhdl as gen_vhdl
# Read the xlsx file
file_name = '/home/ludvig/Documents/Digital Twin/Version 1/V_5_Cleaned dVRC/DT_DM.xlsx'
file_name = "/home/ludvig/Documents/Digital Twin/Synthesized FPGA Projects/0. Library/DM/DT_DM.xlsx"

sheet_name_C1= 'C1'


def read_2DLUT_data(file_name, sheet_name):
    """
    Reads a 2D LUT parameter from an Excel file.
    
    :param file_name: The name of the Excel file.
    :param sheet_name: The name of the sheet to read.
    :return: A DataFrame containing the data from the specified sheet.
    """
    df = pd.read_excel(file_name, sheet_name=sheet_name)
    df = df.loc[:, ~df.columns.str.contains('^Unnamed')]
    df = df.loc[:, ~df.columns.str.contains('kF')]
    data_matrix = df.values
    return data_matrix

def convert_to_bin_matrix(data_matrix, format_string="-16EN16", acceptable_error=0.0001):
    """
    Converts a 2D LUT data matrix to a binary representation.
    
    :param data_matrix: A 2D numpy array containing the LUT data.       
    :return: A binary representation of the data matrix.
    """
    bin_matrix = np.empty(data_matrix.shape, dtype=object)
    rel_error_matrix = np.empty(data_matrix.shape, dtype=float)
    # If -4 we will multiply by 2⁴
    #bin_matrix = np.vectorize(fp.decimal_to_binary)(data_matrix, format_string=format_string,acceptable_error=acceptable_error)
    for i in range(data_matrix.shape[0]):
        for j in range(data_matrix.shape[1]):
            value = data_matrix[i, j]
            if np.isnan(value):
                bin_matrix[i, j] = 'NaN'
                rel_error_matrix[i, j] = np.nan
            else:
                bin_matrix[i, j], rel_error_matrix[i, j] = fp.decimal_to_binary(value, format_string=format_string, acceptable_error=acceptable_error)
    return bin_matrix, rel_error_matrix

def convert_to_1D_bin_matrix(data_array, format_string="-16EN16", acceptable_error=0.0001):
    """
    Converts a 1D LUT data array to a binary representation.
    
    :param data_array: A 1D numpy array containing the LUT data.       
    :return: A binary representation of the data array.
    """
    # Drop the first column 
    bin_array = np.empty(data_array.shape[0], dtype=object)
    rel_error_array = np.empty(data_array.shape[0], dtype=float)
    for i in range(data_array.shape[0]):
        value = data_array[i][1]
        print(f"Converting value: {value}")
        if np.isnan(value):
            bin_array[i] = 'NaN'
            rel_error_array[i] = np.nan
        else:
            bin_array[i], rel_error_array[i] = fp.decimal_to_binary(value, format_string=format_string, acceptable_error=acceptable_error)
    return bin_array, rel_error_array
    

C1_matrix = read_2DLUT_data(file_name, sheet_name_C1)
# Ensure the C1 matrix is a numpy array
c1 = 1. / C1_matrix # 1/kF 
print(f"C1 matrix shape: {c1.shape}, {c1}")

c1_bin, c1_rel_error = convert_to_bin_matrix(c1, "0EN16",0.0125)
print(f"C1 binary matrix shape: {c1_bin.shape}, {c1_bin}")
print(f"C1 relative error matrix shape: {c1_rel_error.shape}, {c1_rel_error} with the maximum relative error: {np.nanmax(c1_rel_error)}")

vhdl_str = gen_vhdl.generate_flat_2DLUT(c1_bin, "r_c1")

print(vhdl_str)

# Read R2 and C2
sheet_name_C2 = 'C2'
C2_matrix = read_2DLUT_data(file_name, sheet_name_C2)
# Ensure the C2 matrix is a numpy array
c2 = 1. / C2_matrix # 1/kF
print(f"C2 matrix shape: {c2.shape}, {c2} with the maximum value: {np.nanmax(c2)} and the minimum value: {np.nanmin(c2)}")

c2_bin, c2_rel_error = convert_to_bin_matrix(c2, "-5EN16", 0.0125)
print(f"C2 binary matrix shape: {c2_bin.shape}, {c2_bin}")
print(f"C2 relative error matrix shape: {c2_rel_error.shape}, {c2_rel_error} with the maximum relative error: {np.nanmax(c2_rel_error)}")

vhdl_str = gen_vhdl.generate_flat_2DLUT(c2_bin, "r_c2")

print(vhdl_str)

# a2 = (1/(R2*C2))

sheet_name_R2 = 'R2'
R2_matrix = read_2DLUT_data(file_name, sheet_name_R2)

a2 = 1 / (R2_matrix * C2_matrix)

print(f"a2 matrix shape: {a2.shape}, {a2} with the maximum value: {np.nanmax(a2)} and the minimum value: {np.nanmin(a2)}")
a2_bin, a2_rel_error = convert_to_bin_matrix(a2, "-7EN16", 0.0125)

print(f"a2 binary matrix shape: {a2_bin.shape}, {a2_bin}")

vhdl_str = gen_vhdl.generate_flat_2DLUT(a2_bin, "r_a2")

print(vhdl_str)

sheet_name_Vocv = 'Vocv'
Vocv_matrix = read_2DLUT_data(file_name, sheet_name_Vocv)
vocv = Vocv_matrix
print(f"Vocv matrix shape: {vocv.shape}, {vocv} with the maximum value: {np.nanmax(vocv)} and the minimum value: {np.nanmin(vocv)}")
vocv_bin, vocv_rel_error = convert_to_1D_bin_matrix(vocv, "12EN8", 0.0001)
print(f"Vocv binary matrix shape: {vocv_bin.shape}, {vocv_bin}")
vhdl_str = gen_vhdl.generate_flat_1DLUT(vocv_bin, "r_vocv")
print(vhdl_str)
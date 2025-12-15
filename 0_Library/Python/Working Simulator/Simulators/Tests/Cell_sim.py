import os
import sys
import importlib.util
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

from typing import Optional, Dict, Tuple


# Read the xlsx file

# --- Added: make Preprocessing importable by adding the repo Python/ folder to sys.path ---
cwd_file = os.path.dirname(os.path.abspath(__file__))

# Walk up to find 'Digital Twin' / Python folder that contains 'Preprocessing'
cur = cwd_file
for _ in range(8):
    cand = os.path.join(cur, "Python")
    if os.path.isdir(cand) and os.path.isdir(os.path.join(cand, "Preprocessing")):
        sys.path.insert(0, cand)
        break
    nxt = os.path.dirname(cur)
    if nxt == cur:
        break
    cur = nxt

for _ in range(8):
    cand = os.path.join(cur, "Python")
    if os.path.isdir(cand) and os.path.isdir(os.path.join(cand, "Postprocessing")):
        sys.path.insert(0, cand)
        break
    nxt = os.path.dirname(cur)
    if nxt == cur:
        break
    cur = nxt
import Preprocessing.FP_Conversion as fp
import Postprocessing as pp
# Preferred absolute path (as provided by the user)
ABS_BIN_OP = "/home/ludvig/Documents/Digital Twin/Python/binary_operations.py"
ABS_BIN_SIM = "/home/ludvig/Documents/Digital Twin/Python/binary_simulator.py"

# ...existing code...
def load_bin_ops(path):
    candidates = []
    # 1) Absolute path
    candidates.append(path)
    # 2) Fallback: try to locate the 'Digital Twin' root by walking up
    cur = cwd_file
    for _ in range(6):
        if os.path.basename(cur) == "Digital Twin":
            cand = os.path.join(cur, "Python", "binary_operations.py")
            candidates.append(cand)
            break
        nxt = os.path.dirname(cur)
        if nxt == cur:
            break
        cur = nxt
    # 3) Fallback: heuristic relative climb from this test file
    rel_cand = os.path.abspath(os.path.join(
        cwd_file, "..", "..", "..", "..", "Python", "binary_operations.py"
    ))
    candidates.append(rel_cand)

    tried = []
    for path in candidates:
        if not path or path in tried:
            continue
        tried.append(path)
        if os.path.isfile(path):
            print(f"Loading module from: {path}")
            # use the file basename (without .py) as the module name
            module_name = os.path.splitext(os.path.basename(path))[0]
            spec = importlib.util.spec_from_file_location(module_name, path)
            mod = importlib.util.module_from_spec(spec)
            assert spec and spec.loader, "Invalid import spec for module"
            # ensure module is visible to normal imports during exec
            sys.modules[module_name] = mod
            spec.loader.exec_module(mod)
            # keep module in sys.modules under its module_name
            sys.modules[module_name] = mod
            return mod
        else:
            print(f"Candidate not found: {path}")

    raise FileNotFoundError(
        "binary_operations.py not found. Tried:\n" + "\n".join(tried)
    )
# ...existing code...
bin_op = load_bin_ops(ABS_BIN_OP)
bin_sim = load_bin_ops(ABS_BIN_SIM)

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

def convert_to_dec_matrix(data_matrix, format_string = "8EN8"):
    # Using bin_op.binary_string_to_decimal to convert
    dec_matrix = np.empty(data_matrix.shape, dtype=float)
    for i in range(data_matrix.shape[0]):
        for j in range(data_matrix.shape[1]):
            value = data_matrix[i, j]
 
            dec_matrix[i, j] = fp.binary_to_decimal(value, format_string=format_string)
    return dec_matrix

def read_and_convert_2DLUT(file_name, sheet_name, format_string="-16EN16", invert=False, acceptable_error=0.0001):
    if isinstance(sheet_name, list):
        print(f"Reading multiple ({len(sheet_name)}) sheets: {sheet_name} ")
        data_matrix = [read_2DLUT_data(file_name, sn) for sn in sheet_name]
        if invert:
            # Multiply each data matrix by the other and then invert 1.0/(dm1*dm2*dm3... )
            data_matrix = 1.0 / np.prod(data_matrix, axis=0)
            bin_matrix, rel_error_matrix = convert_to_bin_matrix(data_matrix, format_string=format_string, acceptable_error=acceptable_error)
    else:
        data_matrix = read_2DLUT_data(file_name, sheet_name)
        if invert:
            data_matrix = 1.0 / data_matrix
            bin_matrix, rel_error_matrix = convert_to_bin_matrix(data_matrix, format_string=format_string, acceptable_error=acceptable_error)
        else:
            bin_matrix, rel_error_matrix = convert_to_bin_matrix(data_matrix, format_string=format_string, acceptable_error=acceptable_error)
    return bin_matrix, data_matrix, rel_error_matrix

def check_binary_representation(bin_matrix, row2check, col2check,  format_string = "8EN8", name = "R0"):
    # Get the binary value at the specified row and column
    bin_value = bin_matrix[row2check, col2check]
    print(f"\nChecking binary representation for {name}: \n {25*'-'}")
    print(f"Checking binary representation at Row: {row2check}, Column: {col2check}")
    print(f"Binary Value: {bin_value}")

    # Convert the binary value back to decimal
    dec_value = fp.binary_to_decimal(bin_value, format_string=format_string)
    print(f"Reconstructed Decimal Value: {dec_value}")
    print(f"{25*'-'}\n")

    return dec_value

DM_file = "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/DT_DM.xlsx"

R0_sheet = "R0"
R0_fmt = "8EN8"
# RC circuit Parameters
R1_sheet = "R1"
C1_sheet = "C1"
R2_sheet = "R2"
C2_sheet = "C2"
# Variable format strings
I_fmt ="4EN12"
SOC_fmt = "7EN9"
dV_RC1_fmt = "11EN37"
dV_RC2_fmt = "11EN37"

# ECM Parameters Format
a1_fmt   = "-5EN16"
c1_fmt = "0EN16"
a2_fmt = "-7EN16"
c2_fmt = "-5EN16"



a1_lst  = [R1_sheet, C1_sheet]
c1_sheet = C1_sheet # Invert
a2_lst = [R2_sheet, C2_sheet]
c2_sheet = C2_sheet # Invert
R0_bin, R0_dec, R0_rel_error = read_and_convert_2DLUT(DM_file, R0_sheet, invert=False, format_string=R0_fmt, acceptable_error=0.0125)
# RC circuit Parameters
a1_bin, a1_dec, a1_rel_error = read_and_convert_2DLUT(DM_file, a1_lst, invert=True, format_string=a1_fmt, acceptable_error=0.0125)
c1_bin, c1_dec, c1_rel_error = read_and_convert_2DLUT(DM_file, C1_sheet, invert=True, format_string=c1_fmt, acceptable_error=0.0125)
a2_bin, a2_dec, a2_rel_error = read_and_convert_2DLUT(DM_file, a2_lst, invert=True, format_string=a2_fmt, acceptable_error=0.0125)
c2_bin, c2_dec, c2_rel_error = read_and_convert_2DLUT(DM_file, C2_sheet, invert=True, format_string=c2_fmt, acceptable_error=0.0125)

def total_bits_from_fmt(fmt: str) -> int:
    # e.g. "11EN37" -> 11+37=48, "-5EN16" -> 5+16=21
    i_str, f_str = fmt.split("EN")
    return abs(int(i_str)) + int(f_str)

def normalize_bin_matrix(bin_matrix: np.ndarray, width: int, nan_token: str = 'NaN') -> np.ndarray:
    """Pad all non-NaN entries with leading zeros to the exact width."""
    out = np.empty(bin_matrix.shape, dtype=object)
    for idx, val in np.ndenumerate(bin_matrix):
        if isinstance(val, str) and val != nan_token:
            out[idx] = val.zfill(width) if len(val) != width else val
        else:
            out[idx] = nan_token
    return out

def save_bin_matrix_csv(bin_matrix: np.ndarray, out_dir: str, filename: str, width: int, nan_token: str = 'NaN') -> str:
    os.makedirs(out_dir, exist_ok=True)
    
    df = pd.DataFrame(bin_matrix).astype(str)  # keep leading zeros
    out_path = os.path.join(out_dir, f"{filename}.csv")
    df.to_csv(out_path, index=False, header=False)
    print(f"Saved {filename}: shape={bin_matrix.shape}, width={width} bits -> {out_path}")
    return out_path

def save_all_ecm_binaries(
    out_dir: str = "/home/ludvig/Documents/Digital Twin/Version 1/Version 7 - SOC Calc and dVRC/Data Management"
) -> Dict[str, str]:
    outputs: Dict[str, str] = {}
    # Compute bit-widths from your format strings
    widths = {
        "a1": total_bits_from_fmt(a1_fmt),
        "c1": total_bits_from_fmt(c1_fmt),
        "a2": total_bits_from_fmt(a2_fmt),
        "c2": total_bits_from_fmt(c2_fmt),
        "R0": total_bits_from_fmt(R0_fmt),
    }
    outputs["a1"] = save_bin_matrix_csv(a1_bin, out_dir, "a1_bin", widths["a1"])
    outputs["c1"] = save_bin_matrix_csv(c1_bin, out_dir, "c1_bin", widths["c1"])
    outputs["a2"] = save_bin_matrix_csv(a2_bin, out_dir, "a2_bin", widths["a2"])
    outputs["c2"] = save_bin_matrix_csv(c2_bin, out_dir, "c2_bin", widths["c2"])
    outputs["R0"] = save_bin_matrix_csv(R0_bin, out_dir, "R0_bin", widths["R0"])
    return outputs
save_all_ecm_binaries()
print(f"a1 binary shape: {a1_bin.shape}, a1 decimal shape: {a1_dec.shape}, a1 rel error shape: {a1_rel_error.shape} \n {a1_bin}")


def csv_to_mif(path_in: str,
               file_name: str,
               folder_out: str,
               save_name: str,
               *,
               nan_token: str = 'NaN',
               fill_value: str = '0',
               width: int | None = None,
               row_major: bool = True) -> str:
    """
    Convert a CSV of binary strings (e.g., a1_bin) into a Quartus .mif file.

    - path_in: input folder containing the CSV.
    - file_name: CSV file name (with or without .csv).
    - folder_out: output folder for the .mif.
    - save_name: output mif file name (with or without .mif).
    - nan_token: token used in CSV for missing values (kept as 0's in MIF).
    - fill_value: bit used to replace missing values (default '0').
    - width: force output WIDTH; if None, inferred from the longest entry.
    - row_major: True to flatten row-wise (C order), False for column-wise.

    Returns: full path to the written .mif file.
    """
    # Resolve paths/extensions
    in_path = os.path.join(path_in, file_name)
    if os.path.splitext(in_path)[1].lower() != ".csv":
        in_path += ".csv"
    os.makedirs(folder_out, exist_ok=True)
    out_path = os.path.join(folder_out, save_name)
    if os.path.splitext(out_path)[1].lower() != ".mif":
        out_path += ".mif"

    # Read CSV strictly as strings, keep leading zeros
    df = pd.read_csv(in_path, header=None, dtype=str, keep_default_na=False)
    arr = df.values.astype(str)

    # Flatten
    order = 'C' if row_major else 'F'
    flat = arr.ravel(order=order)

    # Infer/pin width
    cleaned = [v.strip() for v in flat]
    non_empty = [v for v in cleaned if v and v != nan_token]
    if not non_empty:
        raise ValueError("CSV contains no binary data.")
    inferred_width = max(len(v) for v in non_empty)
    W = width if width is not None else inferred_width

    # Validate and normalize entries
    out_vals: list[str] = []
    for v in cleaned:
        if not v or v == nan_token:
            bits = (fill_value if fill_value in ('0', '1') else '0') * W
        else:
            if any(ch not in ('0', '1') for ch in v):
                raise ValueError(f"Non-binary entry found: '{v}'")
            if len(v) > W:
                raise ValueError(f"Entry width {len(v)} exceeds target WIDTH={W}: '{v}'")
            bits = v.zfill(W)  # preserve width with leading zeros
        out_vals.append(bits)

    DEPTH = len(out_vals)

    # Build MIF text
    header = f"""-- Copyright (C) 2025  Altera Corporation. All rights reserved.
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and any partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, the Altera Quartus Prime License Agreement,
-- the Altera IP License Agreement, or other applicable license
-- agreement, including, without limitation, that your use is for
-- the sole purpose of programming logic devices manufactured by
-- Altera and sold by Altera or its authorized distributors.  Please
-- refer to the Altera Software License Subscription Agreements 
-- on the Quartus Prime software download page.

-- Quartus Prime generated Memory Initialization File (.mif)

WIDTH={W};
DEPTH={DEPTH};

ADDRESS_RADIX=UNS;
DATA_RADIX=BIN;

CONTENT BEGIN
"""
    lines = [header]
    for idx, bits in enumerate(out_vals):
        lines.append(f"\t{idx:<4} :   {bits};\n")
    lines.append("END;\n")

    with open(out_path, "w", encoding="utf-8") as f:
        f.writelines(lines)

    print(f"Wrote MIF: {out_path} (WIDTH={W}, DEPTH={DEPTH}, order={'row' if row_major else 'column'}-major)")
    return out_path
# ...existing code...
mif_dir = "/home/ludvig/Documents/Digital Twin/Version 1/Version 7 - SOC Calc and dVRC/FPGA/Memory_Initialization_Files"
# Create the directory if it doesn't exist
os.makedirs(mif_dir, exist_ok=True)
csv_path = "/home/ludvig/Documents/Digital Twin/Version 1/Version 7 - SOC Calc and dVRC/Data Management"
a1_mif = csv_to_mif(csv_path, "a1_bin", mif_dir, "a1", width=16)
c1_mif = csv_to_mif(csv_path, "c1_bin", mif_dir, "c1", width=16)
a2_mif = csv_to_mif(csv_path, "a2_bin", mif_dir, "a2", width=16)
c2_mif = csv_to_mif(csv_path, "c2_bin", mif_dir, "c2", width=16)
R0_mif = csv_to_mif(csv_path, "R0_bin", mif_dir, "R0", width=16)



# Convert and save each binary matrix as a .mif file
# # Checking the binary representations
# ECM_par = {'a1' : {'dec': a1_dec, 'bin': a1_bin, 'fmt': a1_fmt},
#             'a2' : {'dec': a2_dec, 'bin': a2_bin, 'fmt': a2_fmt},
#             'c1' : {'dec': c1_dec, 'bin': c1_bin, 'fmt': c1_fmt},
#             'c2' : {'dec': c2_dec, 'bin': c2_bin, 'fmt': c2_fmt}}
# # Looping over the dictionary keys name=key, format_string = key[fmt]
# for key, value in ECM_par.items():
#     check_binary_representation(value['bin'], 0, 0, format_string=value['fmt'], name=key)









# def cell_sim_main(I, SOC, ECM_par, n_steps=3, timestep=4):
#     # Variable format strings
#     I_fmt ="4EN12"
#     SOC_fmt = "7EN9"
#     dV_RC1_fmt = "11EN37"
#     dV_RC2_fmt = "11EN37"

#     # ECM Parameters Format
#     a1_fmt   = "-5EN16"
#     c1_fmt = "0EN16"
#     a2_fmt = "-7EN16"
#     c2_fmt = "-5EN16"

#     dV_RC1_res = []
#     dV_RC2_res = []
#     dV_RC1_res_dec = []
#     dV_RC2_res_dec = []
#     I_bin = bin_op.decimal_to_binary_string(I, I_fmt)
#     SOC_bin = bin_op.decimal_to_binary_string(SOC, SOC_fmt)
#     bin_res = []
#     for step in range(n_steps):
        
#         a1, a2, c1, c2 = bin_sim.ECM_params(I_bin, SOC_bin, ECM_par)
#         a1_dec, a2_dec, c1_dec, c2_dec = bin_sim.ECM_par_dec(I, SOC, ECM_par)
#         print(f"Step {step}: a1={a1} ({a1_dec}), c1={c1} ({c1_dec}), a2={a2} ({a2_dec}), c2={c2} ({c2_dec})")
#         print(f"Using the I={I_bin} ({I}) and SOC={SOC_bin} ({SOC})")
#         if step > 0:
#             print(f"Previous dV_RC1: {dV_RC1_dic['dV']['binary']} ({dV_RC1_dic_dec['dV']['decimal']})")
#             dV_RC1_dic = {'I': {'binary': I_bin, 'fmt': I_fmt},
#                         'SOC': {'binary': SOC_bin, 'fmt': SOC_fmt},
#                         'a': {'binary': a1, 'fmt': ECM_par['a1']['fmt']},
#                         'c': {'binary': c1, 'fmt': ECM_par['c1']['fmt']},
#                         'dV': {'binary': dV_RC1_dic['dV']['binary' ], 'fmt': dV_RC1_fmt}}

#             dV_RC2_dic = {'I': {'binary': I_bin, 'fmt': I_fmt},
#                         'SOC': {'binary': SOC_bin, 'fmt': SOC_fmt},
#                         'a': {'binary': a2, 'fmt': ECM_par['a2']['fmt']},
#                         'c': {'binary': c2, 'fmt': ECM_par['c2']['fmt']},
#                         'dV': {'binary': dV_RC2_dic['dV']['binary'], 'fmt': dV_RC2_fmt}}

#             dV_RC1_dic_dec = {'I': {'decimal': I},
#                             'SOC': {'decimal': SOC},
#                             'a': {'decimal': a1_dec},
#                             'c': {'decimal': c1_dec},
#                             'dV': {'decimal': 0.0}}
#             dV_RC2_dic_dec = {'I': {'decimal': I},
#                             'SOC': {'decimal': SOC},
#                             'a': {'decimal': a2_dec},
#                             'c': {'decimal': c2_dec},
#                             'dV': {'decimal': 0.0}}
#         else:
#             dV_RC1_dic = {'I': {'binary': I_bin, 'fmt': I_fmt},
#                         'SOC': {'binary': SOC_bin, 'fmt': SOC_fmt},
#                         'a': {'binary': a1, 'fmt': ECM_par['a1']['fmt']},
#                         'c': {'binary': c1, 'fmt': ECM_par['c1']['fmt']},
#                         'dV': {'binary': '0'*48, 'fmt': dV_RC1_fmt}}

#             dV_RC2_dic = {'I': {'binary': I_bin, 'fmt': I_fmt},
#                         'SOC': {'binary': SOC_bin, 'fmt': SOC_fmt},
#                         'a': {'binary': a2, 'fmt': ECM_par['a2']['fmt']},
#                         'c': {'binary': c2, 'fmt': ECM_par['c2']['fmt']},
#                         'dV': {'binary': '0'*48, 'fmt': dV_RC2_fmt}}

#             dV_RC1_dic_dec = {'I': {'decimal': I},
#                             'SOC': {'decimal': SOC},
#                             'a': {'decimal': a1_dec},
#                             'c': {'decimal': c1_dec},
#                             'dV': {'decimal': 0.0}}
#             dV_RC2_dic_dec = {'I': {'decimal': I},
#                             'SOC': {'decimal': SOC},
#                             'a': {'decimal': a2_dec},
#                             'c': {'decimal': c2_dec},
#                             'dV': {'decimal': 0.0}}
#         # Appeding the results for step {step} (dV_RC1 & dV_RC2 [including floating point results as comparison])
#         dV_RC1_res.append(dV_RC1_dic['dV']['binary'])
#         dV_RC1_res_dec.append(dV_RC1_dic_dec['dV']['decimal'])
#         dV_RC2_res.append(dV_RC2_dic['dV']['binary'])
#         dV_RC2_res_dec.append(dV_RC2_dic_dec['dV']['decimal'])
#         bin_res.append((dV_RC1_dic['dV']['binary'], dV_RC2_dic['dV']['binary']))
#         # Update the voltage drops
#         dV_RC1_dic['dV']['binary'] = bin_sim.dV_RC(par_dic=dV_RC1_dic, timestep=4, debug=False)
#         print(f"Updated dV_RC1: {dV_RC1_dic['dV']['binary']}")
#         dV_RC1_dic_dec['dV']['decimal'] = bin_sim.dV_RC_dec(par_dic=dV_RC1_dic_dec, timestep=4, debug=False)
#         dV_RC2_dic['dV']['binary'] = bin_sim.dV_RC(par_dic=dV_RC2_dic, timestep=4, debug=False)
#         dV_RC2_dic_dec['dV']['decimal'] = bin_sim.dV_RC_dec(par_dic=dV_RC2_dic_dec, timestep=4, debug=False)

#     return bin_res

# n_steps = 20
# timestep = 4


# I = 2
# SOC = 0

# # Variable format strings
# I_fmt ="4EN12"
# SOC_fmt = "7EN9"
# dV_RC1_fmt = "11EN37"
# dV_RC2_fmt = "11EN37"

# # ECM Parameters Format
# a1_fmt   = "-5EN16"
# c1_fmt = "0EN16"
# a2_fmt = "-7EN16"
# c2_fmt = "-5EN16"
# res_bin = cell_sim_main(I, SOC, ECM_par, n_steps=n_steps, timestep=timestep)
# for idx, (dV1, dV2) in enumerate(res_bin):
#     print(f"Step {idx}: dVRC1 = {bin_op.binary_string_to_decimal(dV1, dV_RC1_fmt)}, dVRC2 = {bin_op.binary_string_to_decimal(dV2, dV_RC2_fmt)}")





# SOC_fmt = "7EN25"
# SOC_0 = 100 # %, initial state of charge
# SOC_0_invQ = SOC_0 # %, initial state of charge
# SOC0 = bin_op.decimal_to_binary_string(SOC_0, SOC_fmt)
# Q = 18 # Ah, Charge
# inv_Q = 1/(Q*36) # 1/36Ah
# Q_inv_fmt = "-8EN16"
# Q_inv_int_bits, Q_inv_frac_bits = bin_op.split_fmtstring(Q_inv_fmt)
# timestep = 4
# inv_Q_bin = bin_op.decimal_to_binary_string(inv_Q, Q_inv_fmt)
# # Reconverting to decimal to see the difference



# SOC_res = []
# SOC_res_invQ = []
# SOCbin_res =[]
# debug_SOC = False
# cell_charge = False
# for step in range(n_steps): #9*60*60*2**(timestep)
#     SOC_res.append(SOC_0)
#     SOC_res_invQ.append(SOC_0_invQ)
#     SOCbin_res.append(SOC0)
#     SOC_0 = bin_sim.SOC_calc_dec(SOC_0, I, Q, timestep)
#     SOC_0_invQ = bin_sim.SOC_calc_dec_invQ(SOC_0_invQ, I, inv_Q, timestep)
#     SOC0 = bin_sim.SOC_calc(SOC0, bin_op.decimal_to_binary_string(I, I_fmt), inv_Q_bin, timestep,charging=cell_charge , SOC_fmt=SOC_fmt, I_fmt=I_fmt, Q_inv_fmt=Q_inv_fmt, debug=debug_SOC)

# print(f"After 1 step SOC_dec ={SOC_res_invQ[1]} and SOC_invQ = {SOC_res_invQ[1]} and after 1 step SOC0 = {SOCbin_res[0]} ({bin_op.binary_string_to_decimal(SOCbin_res[0], SOC_fmt)})")
# print(f"After {step} steps SOC_dec ={SOC_res_invQ[-1]} and SOC_invQ = {SOC_res_invQ[-1]} and SOC0 = {SOCbin_res[-1]} ({bin_op.binary_string_to_decimal(SOCbin_res[-1], SOC_fmt)})")
# # Plotting the SOC

# print(f"Q (inverse capacity*36 binary) {inv_Q_bin} ({len(inv_Q_bin)} bits) = {bin_op.binary_string_to_decimal(inv_Q_bin, Q_inv_fmt)} (decimal)")

# k = 0
# for bin_step in SOCbin_res:
#     print(f"At {k} : SOC binary: {bin_step} ({len(bin_step)} bits) = {bin_op.binary_string_to_decimal(bin_step, SOC_fmt)} (decimal)")
#     k += 1


# # I = 1.9995
# # SOC_init =100
# # Q = 18
# # timestep = 2
# # SOC = bin_sim.SOC_calc_dec(SOC_init, I, Q, timestep)
# # for step in range(1, 4*9*3600+100):
# #    SOC= bin_sim.SOC_calc_dec(SOC, I, Q, timestep)
# # print(f"After {step} ({step*2**(-timestep)} s)steps SOC_dec ={SOC}")

# # # plt.plot(SOC_res, label="SOC (Ah)")
# # # plt.plot(SOC_res_invQ, label="SOC (1/36Ah)")
# # plt.xlabel("Time (s)")
# # plt.ylabel("State of Charge (%)")
# # plt.title("State of Charge over Time")
# # plt.grid()
# # plt.legend()
# # plt.show()

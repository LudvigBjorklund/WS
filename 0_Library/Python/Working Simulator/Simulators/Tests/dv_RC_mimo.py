import copy
"""
General test harness for fixed-point helpers.
Loads binary_operations.py from the shared Digital Twin Python folder.
"""
import pyperclip
import os
import sys
import importlib.util
import pandas as pd
import numpy as np
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
import Preprocessing.FP_Conversion as fp

def read_2DLUT_data(file_name, sheet_name):
    """
    Reads a 2D LUT parameter from an Excel col.
    
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


# Preferred absolute path (as provided by the user)
ABS_BIN_OP = "/home/ludvig/Documents/Digital Twin/Python/binary_operations.py"

def load_bin_ops():
	candidates = []
	# 1) Absolute path
	candidates.append(ABS_BIN_OP)
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
			print(f"Loading binary_operations from: {path}")
			spec = importlib.util.spec_from_file_location("binary_operations", path)
			mod = importlib.util.module_from_spec(spec)
			assert spec and spec.loader, "Invalid import spec for binary_operations"
			spec.loader.exec_module(mod)
			return mod
		else:
			print(f"Candidate not found: {path}")

	raise FileNotFoundError(
		"binary_operations.py not found. Tried:\n" + "\n".join(tried)
	)

bin_op = load_bin_ops()

def list_excel_sheets(file_name):
    xl = pd.ExcelFile(file_name)
    print(f"Excel file: {file_name} contains sheets: {xl.sheet_names}")
    return xl.sheet_names

# ---------------------------------------------------------------------------
# Expected external dependency: bin_op with the following functions:
# - get_input_formats(sim_dic, required_list)
# - hex_to_binary, decimal_to_binary
# - binary_string_to_decimal, binary_multiplication
# - binary_subtraction, binary_addition
# - new_fmt_string, split_fmtstring
#
# This module extends your single RC simulator to N stages.
# ---------------------------------------------------------------------------

# Existing/global format strings (from your original snippet)
c1_fmt = "0EN16"
a1_fmt = "-5EN16"
I_fmt  = "4EN12"
dV_fmt = "11EN37"

# If second stage uses different formats, set them; else reuse the first:
c2_fmt = "-5EN16"
a2_fmt = "-7EN16"
# You can put per-stage dV format if needed; here we reuse dV_fmt for all:
dV2_fmt = dV_fmt

# ---------------------------------------------------------------------------
# Utility: ensure each required signal has BINARY and DECIMAL populated
# ---------------------------------------------------------------------------
def ensure_formats(sim_dic, signals, debug=False):
    for k in signals:
        if k not in sim_dic:
            raise KeyError(f"Signal {k} missing from sim_dic.")
        entry = sim_dic[k]
        fmt = entry.get('Format')
        # If BINARY missing: derive from Hex or Decimal
        if 'BINARY' not in entry:
            if 'Hex' in entry and entry['Hex'] is not None:
                # Prefer hex->binary via provided helper if exists; else convert hex->int->binary (you can add a fallback)
                entry['BINARY'] = bin_op.hex_to_binary(entry['Hex'])
            elif 'DECIMAL' in entry and entry['DECIMAL'] is not None:
                entry['BINARY'] = bin_op.decimal_to_binary(entry['DECIMAL'], fmt)
            else:
                raise ValueError(f"Cannot derive BINARY for {k}; need Hex or DECIMAL.")
        # If DECIMAL missing: derive from BINARY using format
        if 'DECIMAL' not in entry:
            if fmt is None:
                raise ValueError(f"No Format provided to derive DECIMAL for {k}")
            entry['DECIMAL'] = bin_op.binary_string_to_decimal(entry['BINARY'], fmt)
        if debug:
            print(f"[ensure_formats] {k}: BINARY len={len(entry['BINARY'])}, DECIMAL={entry['DECIMAL']} (fmt={fmt})")

# ---------------------------------------------------------------------------
# Core per-stage update (generalized from your dV_RC_bin_sim)
# stage_key: dictionary with keys:
#   a: name of 'a' signal (e.g. 'i_a1')
#   c: name of 'c' signal (e.g. 'i_c1')
#   dV: name of stage voltage (e.g. 'i_dV1')
#   I: name of current signal (common: 'i_I' or per stage)
# formats_key: dictionary with needed format strings:
#   a_fmt, c_fmt, I_fmt, dV_fmt
# ---------------------------------------------------------------------------
def rc_stage_step(sim_dic, stage_key, formats_key, timestep=10, debug=False):
    """
    Performs one integration step for a single RC stage using fixed-point
    arithmetic in binary form, mirroring original logic while fixing
    some slicing corner cases.
    """
    a_sig  = stage_key['a']
    c_sig  = stage_key['c']
    dV_sig = stage_key['dV']
    I_sig  = stage_key['I']

    a_fmt  = formats_key['a_fmt']
    c_fmt  = formats_key['c_fmt']
    I_fmt  = formats_key['I_fmt']
    dV_fmt = formats_key['dV_fmt']

    dt = 2 ** (-timestep)

    # Ensure required signals
    ensure_formats(sim_dic, [a_sig, c_sig, dV_sig, I_sig], debug=debug)

    # Multiplication format expansions
    t1_new_fmt = bin_op.new_fmt_string(c_fmt, I_fmt, "multiplication")  # c * I
    t2_new_fmt = bin_op.new_fmt_string(dV_fmt, a_fmt, "multiplication") # dV * a

    t1_int_bits, t1_frac_bits = bin_op.split_fmtstring(t1_new_fmt)
    t2_int_bits, t2_frac_bits = bin_op.split_fmtstring(t2_new_fmt)
    max_int_bits = max(t1_int_bits, t2_int_bits)
    max_frac_bits = max(t1_frac_bits, t2_frac_bits)

    if debug:
        print(f"[{dV_sig}] max_int_bits={max_int_bits}, max_frac_bits={max_frac_bits}")

    # Normalize both products to common format
    t1_msb_add = abs(max_int_bits - t1_int_bits)
    t2_msb_add = abs(max_int_bits - t2_int_bits)
    t1_lsb_add = abs(max_frac_bits - t1_frac_bits)
    t2_lsb_add = abs(max_frac_bits - t2_frac_bits)
    common_mul_fmt = f"{max_int_bits}EN{max_frac_bits}"

    if debug:
        print(f"[{dV_sig}] t1_msb_add={t1_msb_add}, t1_lsb_add={t1_lsb_add}, t2_msb_add={t2_msb_add}, t2_lsb_add={t2_lsb_add}")

    I_bin  = sim_dic[I_sig]['BINARY']
    c_bin  = sim_dic[c_sig]['BINARY']
    dV_bin = sim_dic[dV_sig]['BINARY']
    a_bin  = sim_dic[a_sig]['BINARY']

    # Binary products
    t1_raw = bin_op.binary_multiplication(I_bin, c_bin)
    t2_raw = bin_op.binary_multiplication(dV_bin, a_bin)

    t1_bin = t1_msb_add * '0' + t1_raw + t1_lsb_add * '0'
    t2_bin = t2_msb_add * '0' + t2_raw + t2_lsb_add * '0'

    t1_dec = sim_dic[I_sig]['DECIMAL'] * sim_dic[c_sig]['DECIMAL']
    t2_dec = sim_dic[dV_sig]['DECIMAL'] * sim_dic[a_sig]['DECIMAL']

    if debug:
        calc_t1_dec = bin_op.binary_string_to_decimal(t1_bin, common_mul_fmt)
        calc_t2_dec = bin_op.binary_string_to_decimal(t2_bin, common_mul_fmt)
        print(f"[{dV_sig}] t1_bin len={len(t1_bin)} dec_check={calc_t1_dec} vs {t1_dec}")
        print(f"[{dV_sig}] t2_bin len={len(t2_bin)} dec_check={calc_t2_dec} vs {t2_dec}")

    # Subtraction t3 = t1 - t2
    t3_bin = bin_op.binary_subtraction(t1_bin, t2_bin)
    t3_fmt = bin_op.new_fmt_string(common_mul_fmt, common_mul_fmt, "subtraction")
    t3_dec = t1_dec - t2_dec

    if debug:
        print(f"[{dV_sig}] t3_fmt={t3_fmt}, t3_bin_len={len(t3_bin)}, t3_dec={t3_dec}")

    # Convert to target dV format
    t3_int_bits, t3_frac_bits = bin_op.split_fmtstring(t3_fmt)
    dV_int_bits, dV_frac_bits = bin_op.split_fmtstring(dV_fmt)
    t3_msb_add = abs(dV_int_bits - t3_int_bits)
    t3_lsb_slice = abs(dV_frac_bits - t3_frac_bits)

    if debug:
        print(f"[{dV_sig}] Adjust to dV_fmt => msb_add={t3_msb_add}, lsb_slice={t3_lsb_slice}")

    # Pad MSB
    t3_adj = t3_msb_add * '0' + t3_bin
    # Slice LSB (avoid [: -0] producing empty)
    if t3_lsb_slice > 0:
        t3_adj = t3_adj[:-t3_lsb_slice]

    # dt integration: multiply by dt by shifting right 'timestep' bits (equivalent to adding zeros on left and slicing right)
    # Original code: t4_bin = timestep*'0' + t3_bin[:-timestep]
    # We'll apply same logic to t3_adj
    if timestep > 0:
        if len(t3_adj) <= timestep:
            # If t3_adj too short, create minimal zeroed structure
            t4_bin = '0' * len(t3_adj)
        else:
            t4_bin = timestep * '0' + t3_adj[:-timestep]
    else:
        t4_bin = t3_adj  # timestep=0 means dt=1

    t4_dec = t3_dec * dt

    if debug:
        try:
            calc_t4_dec = bin_op.binary_string_to_decimal(t4_bin, f"{dV_int_bits}EN{dV_frac_bits}")
        except Exception:
            calc_t4_dec = "ERR"
        print(f"[{dV_sig}] After dt shift: t4_len={len(t4_bin)}, dec_check={calc_t4_dec} vs {t4_dec}")

    # Add previous dV (integration accumulation)
    new_dV_bin_full = bin_op.binary_addition(dV_bin, t4_bin)
    # Original code truncated leading bit: r_dV_bin[1] = r_dV_bin[1][1:]
    # We'll preserve that behavior (assuming addition produces possible carry).
    new_dV_bin = new_dV_bin_full[1:]

    sim_dic[dV_sig]['BINARY'] = new_dV_bin
    sim_dic[dV_sig]['DECIMAL'] = bin_op.binary_string_to_decimal(new_dV_bin, dV_fmt)

    if debug:
        print(f"[{dV_sig}] Updated dV BINARY len={len(new_dV_bin)} DECIMAL={sim_dic[dV_sig]['DECIMAL']}")

    return sim_dic

# ---------------------------------------------------------------------------
# Multi-stage simulation runner
# stages_config: list of dicts, each:
#   {
#     'a': 'i_a1', 'c': 'i_c1', 'dV': 'i_dV1', 'I': 'i_I',
#     'formats': {'a_fmt': a1_fmt, 'c_fmt': c1_fmt, 'I_fmt': I_fmt, 'dV_fmt': dV_fmt}
#   }
#
# updates: dict mapping signal -> schedule (same patterns you used; applies across all stages)
# history: per-step BINARY & DECIMAL for each dVf
# ---------------------------------------------------------------------------
def run_simulation_multistage(n_steps,
                              sim_dic_init,
                              stages_config,
                              updates=None,
                              timestep=10,
                              debug_first_step=True,
                              cascade=False):
    """
    Runs n_steps for multiple RC stages.
    cascade:
        If True, you can implement coupling (e.g., pass something from stage k
        to stage k+1). Currently left as a placeholder.

    Returns:
        sim_dic (final),
        history (dict: {dV_signal: {'BINARY': [...], 'DECIMAL': [...]}, ...})
    """
    sim_dic = copy.deepcopy(sim_dic_init)
    history = {}
    for st in stages_config:
        dV_sig = st['dV']
        history[dV_sig] = {'BINARY': [], 'DECIMAL': []}

    for step in range(1, n_steps + 1):
        # Apply scheduled updates
        if updates:
            for sig, schedule in updates.items():
                if schedule is None:
                    continue
                # dictionary form
                if isinstance(schedule, dict):
                    if step in schedule:
                        sim_dic.setdefault(sig, {})['Hex'] = schedule[step]
                        sim_dic[sig].pop('BINARY', None)
                        sim_dic[sig].pop('DECIMAL', None)
                else:
                    # iterable of (step_index, hex_val)
                    for s_idx, hexval in schedule:
                        if s_idx == step:
                            sim_dic.setdefault(sig, {})['Hex'] = hexval
                            sim_dic[sig].pop('BINARY', None)
                            sim_dic[sig].pop('DECIMAL', None)

        # OPTIONAL: cascade coupling (example placeholder)
        # if cascade and step > 1:
        #     For example: feed previous stage's dV decimal into next stage's 'i_I' or something similar.
        #     Clarify desired physical relation before implementing.

        # Run each stage
        for si, stage in enumerate(stages_config):
            debug = debug_first_step and step == 1
            sim_dic = rc_stage_step(
                sim_dic,
                stage_key={'a': stage['a'], 'c': stage['c'], 'dV': stage['dV'], 'I': stage['I']},
                formats_key=stage['formats'],
                timestep=timestep,
                debug=debug
            )
            dV_sig = stage['dV']
            history[dV_sig]['BINARY'].append(sim_dic[dV_sig]['BINARY'])
            history[dV_sig]['DECIMAL'].append(sim_dic[dV_sig]['DECIMAL'])

        # Per-step summary
        summary_parts = []
        for stage in stages_config:
            dV_sig = stage['dV']
            summary_parts.append(f"{dV_sig}: {sim_dic[dV_sig]['BINARY']} (dec {sim_dic[dV_sig]['DECIMAL']})")
            print(f"Step {step}: " + " | ".join(summary_parts))

        # Storing all dV1 in r_dV1 (both bin and decimal) for each stage r_dV1{0: {Decimal : val, Binary : binval}} for all the simulated steps
        r_dV1 = history[stages_config[0]['dV']]
        r_dV2 = history[stages_config[1]['dV']]



    return sim_dic, history, r_dV1, r_dV2

# ---------------------------------------------------------------------------
# Example usage with two stages
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    # Initial hex values for stage 1
    a1_hex = "1D75"
    c1_hex = "4C69"
    dV1_hex = "000000000000"
    # Current
    I_hex = "1000"

    # Second stage initial values
    a2_hex = "05B9"
    c2_hex = "9D88"
    dV2_hex = "000000000000"
    # Simulation settings
    i_steps = 5
    i_timestep = 4

    # Build initial sim dictionary
    sim_dic_initial = {
        'i_a1': {'Hex': a1_hex, 'Format': a1_fmt},
        'i_c1': {'Hex': c1_hex, 'Format': c1_fmt},
        'i_dV1': {'Hex': dV1_hex, 'Format': dV_fmt},
        'i_a2': {'Hex': a2_hex, 'Format': a2_fmt},
        'i_c2': {'Hex': c2_hex, 'Format': c2_fmt},
        'i_dV2': {'Hex': dV2_hex, 'Format': dV2_fmt},
        'i_I' : {'Hex': I_hex,  'Format': I_fmt}
    }

    # Configure two stages
    stages = [
        {
            'a': 'i_a1', 'c': 'i_c1', 'dV': 'i_dV1', 'I': 'i_I',
            'formats': {'a_fmt': a1_fmt, 'c_fmt': c1_fmt, 'I_fmt': I_fmt, 'dV_fmt': dV_fmt}
        },
        {
            'a': 'i_a2', 'c': 'i_c2', 'dV': 'i_dV2', 'I': 'i_I',
            'formats': {'a_fmt': a2_fmt, 'c_fmt': c2_fmt, 'I_fmt': I_fmt, 'dV_fmt': dV2_fmt}
        }
    ]

    # Updates example (can target any signal across stages)
    updates = {
        'i_a1': [(30000, "1C00")],  # at step 3 change a1
        'i_c2': {40000: "8000"}     # at step 4 change c2
    }

    final_state, history, r_dV1, r_dV2 = run_simulation_multistage(
        n_steps=i_steps,
        sim_dic_init=sim_dic_initial,
        stages_config=stages,
        updates=updates,
        timestep=i_timestep,
        debug_first_step=True,
        cascade=False
    )

    print("\nFinal dV histories:")
    for dV_sig, rec in history.items():
        print(f"{dV_sig} -> last DECIMAL={rec['DECIMAL'][-1]}")

    # Printing all dV histories
for step in range(0, i_steps ):
    print(f"\n---------------------- Step {step} --------------------------------\n")
    print(f" dV1 DECIMAL={r_dV1['DECIMAL'][step]}, BINARY={r_dV1['BINARY'][step]}")
    print(f": dV2 DECIMAL={r_dV2['DECIMAL'][step]}, BINARY={r_dV2['BINARY'][step]}")

def dVRC_dec(I, a, c, dV_k, dt):

    t1 = I * c
    t2 = dV_k *a
    # Subtracting the two terms t3
    t3 = t1 - t2
    t4 = t3 * dt
    dV_k1 = dV_k + t4
    return dV_k1
## Using decimal val
I = 1;     ##  Current (A) 

timeshift =4

a1 = 0.003595829010009766
c1 = 0.2984771728515625

a2 = 0.000174641609191894
c2 = 0.01922988891601562

dt = 2**(-timeshift)

n_steps = 5
dV1 = 0.0
dV2 = 0.0
for step in range(n_steps):
    dV1 = dVRC_dec(I, a1, c1, dV1, dt)
    dV2 = dVRC_dec(I, a2, c2, dV2, dt)

    print(f"Step {step+1}: dV1 DECIMAL={dV1}, dV2 DECIMAL={dV2}")

def Idx_normalizer(idx, inv_norm_value, fmt_str, n_bits_out):
    """
    Normalize the index value based on the given normalization value.
    """
    norm_val =  bin_op.binary_multiplication(idx, inv_norm_value)
    # We will always expect 4 bits for the integer part and that the inv_norm_value is < 1, thus the fmt_string for examplke 7EN9 will require us skipping the first three bins
    int_bits, frac_bits = bin_op.split_fmtstring(fmt_str)
    req_int_bits = 4
    skip_bits = int_bits - req_int_bits
    print(f"Skipping {skip_bits} bits")
    return norm_val[skip_bits:n_bits_out+skip_bits]


def LUT2D(rowidx, colidx, table, debug= False, fmt_string = "8EN8"):
    """
    rowidx is a binary with 4 bits integer and the rest is the fractional part
    colidx is a binary with 4 bits integer and the rest is the fractional part
    """
    rows = table.shape[0]
    cols = table.shape[1]
    row_int = int(rowidx[:4], 2)
    col_int = int(colidx[:4], 2)
    if debug:
        print(f"Row index: {rowidx}, Col index: {colidx}")
        print(f"Row integer part: {row_int}, Col integer part: {col_int}")
        print(f"Table shape: rows={rows}, cols={cols}")
    # Addresses work with flattened addresses (size(table)*row_int + col_int)
    x11_addr = cols*row_int + col_int
    x12_addr = x11_addr +1
    x21_addr = x11_addr + 1*cols
    x22_addr = x21_addr + 1
    print(f"x11_addr: {x11_addr}, x12_addr: {x12_addr}, x21_addr: {x21_addr}, x22_addr: {x22_addr}")
    # Flattening the input table
    flat_table = table.flatten()
    # Extracting the values based on the addresses
    x11 = flat_table[x11_addr]
    x12 = flat_table[x12_addr]
    x21 = flat_table[x21_addr]
    x22 = flat_table[x22_addr]
    print(f"x11: {x11}, x12: {x12}, x21: {x21}, x22: {x22}")
    if debug:
         print(f"Decimal values based on format string {fmt_string}\n {25*'-'}\n x11: {bin_op.binary_string_to_decimal(x11, fmt_string)}, x12: {bin_op.binary_string_to_decimal(x12, fmt_string)}, x21: {bin_op.binary_string_to_decimal(x21, fmt_string)}, x22: {bin_op.binary_string_to_decimal(x22, fmt_string)}")
    # Fractional parts still in binary
    row_frac = rowidx[4:]
    col_frac = colidx[4:]
    rc_mul = bin_op.binary_multiplication(row_frac, col_frac)
    rc_add = bin_op.binary_addition(row_frac, col_frac)
    if debug:
        print(f"The product of {row_frac} and {col_frac} is {rc_mul} of {len(rc_mul)} bits")
        print(f"The sum of {row_frac} and {col_frac} is {rc_add} of {len(rc_add)} bits")
    if rc_add[0] == '1':
        # The add is larger than 1
        w11 = bin_op.binary_subtraction(rc_mul,bin_op.binary_subtraction(rc_add[1:], '1'*len(rc_add[1:]))+'0'*(len(rc_mul)-len(rc_add[1:])))
        print(f"w11: {w11} of {len(w11)} bits")
    else:
        w11 = bin_op.binary_subtraction('1'*len(rc_mul), bin_op.binary_subtraction(rc_add, rc_mul)) 
    w12 = bin_op.binary_subtraction(col_frac+'0'*(len(rc_mul)-len(col_frac)), rc_mul)
    w21 = bin_op.binary_subtraction(row_frac+'0'*(len(rc_mul)-len(row_frac)), rc_mul)
    w22 = rc_mul

    if debug:
        fmt_weights ="0EN16"
        print(f"w11: {w11} of {len(w11)} bits and in decimal form {bin_op.binary_string_to_decimal(w11, fmt_weights)}")
        print(f"w12: {w12} of {len(w12)} bits and in decimal form {bin_op.binary_string_to_decimal(w12, fmt_weights)}")
        print(f"w21: {w21} of {len(w21)} bits and in decimal form {bin_op.binary_string_to_decimal(w21, fmt_weights)}")
        print(f"w22: {w22} of {len(w22)} bits and in decimal form {bin_op.binary_string_to_decimal(w22, fmt_weights)}")
    val1 = bin_op.binary_multiplication(x11, w11)
    val2 = bin_op.binary_multiplication(x12, w12)
    val3 = bin_op.binary_multiplication(x21, w21)
    val4 = bin_op.binary_multiplication(x22, w22)   
    if debug:
        val_fmt = "8EN24"
        print(f"val1: {val1} of {len(val1)} bits and in decimal form {bin_op.binary_string_to_decimal(val1, val_fmt)}")
        print(f"val2: {val2} of {len(val2)} bits and in decimal form {bin_op.binary_string_to_decimal(val2, val_fmt)}")
        print(f"val3: {val3} of {len(val3)} bits and in decimal form {bin_op.binary_string_to_decimal(val3, val_fmt)}")
        print(f"val4: {val4} of {len(val4)} bits and in decimal form {bin_op.binary_string_to_decimal(val4, val_fmt)}")
        expected_decimal = bin_op.binary_string_to_decimal(val1, val_fmt) + bin_op.binary_string_to_decimal(val2, val_fmt)
        expected_decimal += bin_op.binary_string_to_decimal(val3, val_fmt) + bin_op.binary_string_to_decimal(val4, val_fmt)
        print(f"Expected decimal value: {expected_decimal}")
    o_val = bin_op.binary_addition(bin_op.binary_addition(val1, val2)[1:], bin_op.binary_addition(val3, val4)[1:])[1:]
    if debug:
        print(f"Output binary value: {o_val} of {len(o_val)} bits in decimal {bin_op.binary_string_to_decimal(o_val, val_fmt)}")
    return o_val

def ECM_parameters(I, SOC, R0_tbl, a1_tbl, c1_tbl, a2_tbl, c2_tbl):
    # Step one calculate the row and column indices
    row_idx = bin_op.binary_subtraction(I_bin[:12], "000100000000")
    col_idx = Idx_normalizer(SOC_bin, SOC_norm_val, SOC_fmt, 12)
    print(f"Row index: {row_idx}, Column index: {col_idx}")

file_name = '/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/DT_DM.xlsx'
sheet_name_R0 = 'R0'
R0_fmt = "8EN8"


def save_matrix_for_matlab(matrix, filename):
     """Saves a matrix (numpy) in a .csv file that is clippable to matlab"""
     np.savetxt(filename, matrix, delimiter=",", fmt="%.6f")

list_excel_sheets(file_name)

R0_matrix = read_2DLUT_data(file_name, sheet_name_R0)

# Saving the matrix in Data Management
R0_bin, R0_rel_error = convert_to_bin_matrix(R0_matrix, R0_fmt, 0.0125)


sheet_name_C1 = 'C1'

C1_matrix = read_2DLUT_data(file_name, sheet_name_C1)

# Ensure the C1 matrix is a numpy array
c1 = 1. / C1_matrix # 1/kF

c1_bin, c1_rel_error = convert_to_bin_matrix(c1, "0EN16",0.0125)

sheet_name_R1 = 'R1'

R1_matrix = read_2DLUT_data(file_name, sheet_name_R1)   

# Read R2 and C2
sheet_name_C2 = 'C2'
C2_matrix = read_2DLUT_data(file_name, sheet_name_C2)
# Ensure the C2 matrix is a numpy array
c2 = 1. / C2_matrix # 1/kF
print(f"C2 matrix shape: {c2.shape}, {c2} with the maximum value: {np.nanmax(c2)} and the minimum value: {np.nanmin(c2)}")

c2_bin, c2_rel_error = convert_to_bin_matrix(c2, "-5EN16", 0.0125)
print(f"C2 binary matrix shape: {c2_bin.shape}, {c2_bin}")
print(f"C2 relative error matrix shape: {c2_rel_error.shape}, {c2_rel_error} with the maximum relative error: {np.nanmax(c2_rel_error)}")


# a2 = (1/(R2*C2))

sheet_name_R2 = 'R2'
R2_matrix = read_2DLUT_data(file_name, sheet_name_R2)

a2 = 1 / (R2_matrix * C2_matrix)

print(f"a2 matrix shape: {a2.shape}, {a2} with the maximum value: {np.nanmax(a2)} and the minimum value: {np.nanmin(a2)}")
a2_bin, a2_rel_error = convert_to_bin_matrix(a2, "-7EN16", 0.0125)

print(f"a2 binary matrix shape: {a2_bin.shape}, {a2_bin}")


I = 2.64
SOC = 15.67
I_norm_val = bin_op.decimal_to_binary_string(16/16,"1EN15")
I_fmt = "4EN12"
I_bin = bin_op.decimal_to_binary_string(I, I_fmt)
print(f"The I_bin value is: {I_bin} with normalization value {I_norm_val} converted from {bin_op.binary_string_to_decimal(I_bin, I_fmt)}")
row_idx = bin_op.binary_subtraction(I_bin[:12], "000100000000") #Idx_normalizer(I_bin, I_norm_val, I_fmt, 12)
print(f"row_idx: {row_idx}")

SOC_norm_val ="0001100110011010" # bin_op.decimal_to_binary_string(1/10, "0EN16")
SOC_fmt = "7EN9"
SOC_bin = bin_op.decimal_to_binary_string(SOC, SOC_fmt)
print(f"The SOC_bin value is: {SOC_bin} with normalization value {SOC_norm_val}({bin_op.binary_string_to_decimal(SOC_norm_val,"0EN16")}) converted from {bin_op.binary_string_to_decimal(SOC_bin, SOC_fmt)}")
col_idx = Idx_normalizer(SOC_bin, SOC_norm_val, SOC_fmt, 12)
print(f"col_idx: {col_idx}")
R0_val = LUT2D(row_idx, col_idx, R0_bin, debug=True, fmt_string=R0_fmt)
print(R0_val)


print(f"R1 matrix {R1_matrix} with the maximum value: {np.nanmax(R1_matrix)} and the minimum value: {np.nanmin(R1_matrix)}")


a1_tbl = 1 / (R1_matrix * C1_matrix)
save_matrix_for_matlab(R0_matrix, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/R0_matrix.csv")
save_matrix_for_matlab(C1_matrix, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/C1_matrix.csv")
save_matrix_for_matlab(R1_matrix, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/R1_matrix.csv")
save_matrix_for_matlab(R2_matrix, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/R2_matrix.csv")
save_matrix_for_matlab(C2_matrix, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/C2_matrix.csv")

# Save the adjusted matrices
save_matrix_for_matlab(c1, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/c1_matrix.csv")
save_matrix_for_matlab(a1_tbl, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/a1_table.csv")
save_matrix_for_matlab(a2, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/a2_matrix.csv")
save_matrix_for_matlab(c2, "/home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/Data Management/c2_matrix.csv")


# cwd_file = os.path.dirname(os.path.abspath(__file__))
# print(f"Current file directory: {cwd_file}")
import numpy as np
import matplotlib.pyplot as plt

# Battery specs
Q_total = 18.0   # Ah
I_discharge = 2.0 # A
dt = 1/60        # time step in hours (1 minute)
t_end = Q_total / I_discharge  # total discharge time in hours

# Time vector
time_hours = np.arange(0, t_end + dt, dt)

# Calculate SoC
SoC_percent = 100 * (1 - (I_discharge * time_hours) / Q_total)
SoC_percent = np.maximum(SoC_percent, 0)  # Clamp at 0%

# Plot
plt.figure(figsize=(8,4))
plt.plot(time_hours, SoC_percent, label="State of Charge (%)")
plt.xlabel("Time (hours)")
plt.ylabel("State of Charge (%)")
plt.title("Battery SoC During Constant 2A Discharge (18Ah Battery)")
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()
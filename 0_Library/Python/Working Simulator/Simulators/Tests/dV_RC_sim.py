"""
General test harness for fixed-point helpers.
Loads binary_operations.py from the shared Digital Twin Python folder.
"""

import os
import sys
import importlib.util
import copy
cwd_file = os.path.dirname(os.path.abspath(__file__))
print(f"Current file directory: {cwd_file}")

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



def dV_RC_bin_sim(sim_dic={}, timestep= 10, debug=True):
    if debug:
        print(f"Starting dV_RC_bin_sim with timestep {timestep} \n")
    # required signals
    r_dV_dec = [0]*2
    r_dV_bin = ['0']*2
    dt= 2**(-timestep)

    required = ['i_a', 'i_dV', 'i_I', 'i_c']
    if not all(k in sim_dic for k in required):
        print("Missing input signals in simulation dictionary.")
        return

    formats = bin_op.get_input_formats(sim_dic, required)
    if debug:
       print(f"Detected formats: {formats}")
    bin_dic = {}
    # If we lack BINARY and DECIMAL we must convert and add these to the dictionary (HEX is optional and will only be available when its an input)
    for k, fmt_list in formats.items():
        # normalize list contents to uppercase for checks
        fmt_up = [f.upper() for f in fmt_list]

        # Ensure BINARY exists: prefer existing Binary, else convert from Hex, else convert from Decimal
        if 'BINARY' not in fmt_up:
            if 'HEX' in fmt_up and sim_dic[k].get('Hex'):
                sim_dic[k]['BINARY'] = bin_op.hex_to_binary(sim_dic[k]['Hex'])
            elif 'DECIMAL' in fmt_up and sim_dic[k].get('Decimal') is not None:
                # provide a decimal -> binary helper if available, otherwise string-format a binary
                sim_dic[k]['BINARY'] = bin_op.decimal_to_binary_string(sim_dic[k]['Decimal'], sim_dic[k].get('Format', '0EN0'))
            else:
                raise ValueError(f"Cannot obtain BINARY for {k}; available keys: {fmt_list}")

        # Ensure DECIMAL exists: prefer existing Decimal, else compute from Binary using provided Format
        if 'DECIMAL' not in fmt_up:
            fmt_str = sim_dic[k].get('Format', None)
            if fmt_str is None:
                raise ValueError(f"No Format string to convert Binary->Decimal for {k}")
            sim_dic[k]['DECIMAL'] = bin_op.binary_string_to_decimal(sim_dic[k]['BINARY'], fmt_str)

        # Always populate bin_dic for later use
        bin_dic[k] = sim_dic[k]['BINARY']
        if debug:
           print(f"Converted/available {k}: BINARY {bin_dic[k]} ({len(bin_dic[k])} bits), DECIMAL {sim_dic[k]['DECIMAL']}")

    r_dV_bin[0] = bin_dic['i_dV']
    r_dV_bin[1] = bin_dic['i_a']
    t1_new_fmt = bin_op.new_fmt_string(c1_fmt, I_fmt, "multiplication")
    t2_new_fmt = bin_op.new_fmt_string(dV_fmt, a1_fmt, "multiplication")
    t1_int_bits, t1_frac_bits = bin_op.split_fmtstring(t1_new_fmt)
    t2_int_bits, t2_frac_bits = bin_op.split_fmtstring(t2_new_fmt)
    max_int_bits = max(t1_int_bits, t2_int_bits)
    max_frac_bits = max(t1_frac_bits, t2_frac_bits)
    if debug:
        print(f"Max integer bits: {max_int_bits}, Max fractional bits: {max_frac_bits}")

    t1_msb_add = abs(max_int_bits - t1_int_bits)
    t2_msb_add = abs(max_int_bits - t2_int_bits)
    t1_lsb_add = abs(max_frac_bits - t1_frac_bits)
    t2_lsb_add = abs(max_frac_bits - t2_frac_bits)
    # New format 
    t1_new_fmt = f"{max_int_bits}EN{max_frac_bits}"
    t2_new_fmt = f"{max_int_bits}EN{max_frac_bits}"
    if debug:
       print(f"t1_msb_add: {t1_msb_add}, t1_lsb_add: {t1_lsb_add}, t2_msb_add: {t2_msb_add}, t2_lsb_add: {t2_lsb_add}")
	# The number of bits to add to the MSB and LSB of the binary vectors

    k = 0
    t1_bin = t1_msb_add*'0' + bin_op.binary_multiplication(sim_dic['i_I']['BINARY'], sim_dic['i_c']['BINARY']) + t1_lsb_add * '0'
    t2_bin = t2_msb_add*'0' + bin_op.binary_multiplication(sim_dic['i_dV']['BINARY'], sim_dic['i_a']['BINARY']) + t2_lsb_add * '0'
    t1_dec = sim_dic['i_I']['DECIMAL'] * sim_dic['i_c']['DECIMAL']
    t2_dec = sim_dic['i_dV']['DECIMAL'] * sim_dic['i_a']['DECIMAL']
    
    if debug:
          print(f"t1_bin: {t1_bin} ({len(t1_bin)} bits), t2_bin: {t2_bin} ({len(t2_bin)} bits) \n\n")
          print(f"The decimal values for t1 (bin _> dec and c1_dec*I_dec):\n"
                                 f"{bin_op.binary_string_to_decimal(t1_bin, t1_new_fmt)} vs The decimal {t1_dec} \n", 40*'-','\n')
          print(f"The decimal values for t2 (bin _> dec and dV_dec*a1_dec):\n"
                f"{bin_op.binary_string_to_decimal(t2_bin, t2_new_fmt)} vs The decimal {t2_dec} \n", 40*'-')
    t3_bin = bin_op.binary_subtraction(t1_bin, t2_bin)
    t3_fmt = bin_op.new_fmt_string(t1_new_fmt, t2_new_fmt, "subtraction")
    t3_dec = t1_dec - t2_dec
    # The result of the subtraction is stored in r_dV_bin and first we must go from the the t3_fmt --> dV_fmt
    t3_int_bits, t3_frac_bits = bin_op.split_fmtstring(t3_fmt)
    dV_int_bits, dV_frac_bits = bin_op.split_fmtstring(dV_fmt)
    t3_msb_add = abs(dV_int_bits - t3_int_bits)
    t3_lsb_slice = abs(dV_frac_bits - t3_frac_bits)
    t3_new_fmt = f"{dV_int_bits}EN{dV_frac_bits}"
    if debug:
          print(f"The result of the subtraction is: {t3_bin} with format {t1_new_fmt}\nDecimal:{bin_op.binary_string_to_decimal(t3_bin, t1_new_fmt)} vs {t3_dec}")
          print(f"t3_fmt: {t3_fmt}, t3_bin: {t3_bin} ({len(t3_bin)} bits)")
          # Adding and slicing 
          print(f"Padding for dV_bin: {t3_msb_add} MSB and slicing {t3_lsb_slice} LSB")
    t3_bin = t3_msb_add * '0' + t3_bin[:-t3_lsb_slice]
    if debug:
          print(f"After padding and slicing, t3_bin: {t3_bin} ({len(t3_bin)} bits)")
	# For the dt we shift to the left by adding to the right
    t4_dec = (sim_dic['i_I']['DECIMAL'] * sim_dic['i_c']['DECIMAL'] - sim_dic['i_dV']['DECIMAL'] * sim_dic['i_a']['DECIMAL'])*dt
    t4_bin = timestep*'0' + t3_bin[:-timestep]
    t4_fmt = t3_new_fmt
    if debug:
          print(f"After shifting for dt, t4_bin: {t4_bin} ({len(t4_bin)} bits):",
                f"In decimal : {bin_op.binary_string_to_decimal(t4_bin, t4_fmt)} vs {t4_dec}")
    r_dV_bin[1] = bin_op.binary_addition(r_dV_bin[0], t4_bin)
    r_dV_bin[1] = r_dV_bin[1][1:]
    if debug:
          print(f"After adding the previous dV_bin, r_dV_bin[1]: {r_dV_bin[1]} ({len(r_dV_bin[1])} bits)")
    sim_dic['i_dV']['BINARY'] = r_dV_bin[1]
    sim_dic['i_dV']['DECIMAL'] = bin_op.binary_string_to_decimal(r_dV_bin[1], t4_fmt)
    return sim_dic

## Notice a issue

def run_simulation(n_steps, sim_dic_init, updates=None, timestep=10, debug_first_step=True):
    """
    Run n_steps simulation calling dV_RC_bin_sim each step.
    updates: dict mapping signal -> either
        - dict {step: hex_value, ...}
        - list of (step, hex_value) tuples
    When an update is applied the function removes precomputed 'BINARY' and 'DECIMAL'
    so dV_RC_bin_sim recomputes them from the new Hex value.
    """
    sim_dic = copy.deepcopy(sim_dic_init)
    for step in range(1, n_steps):
        if step == 1:
            sim_dic = copy.deepcopy(sim_dic_init)

        # apply scheduled updates for this step
        if updates:
            for sig, schedule in updates.items():
                if schedule is None:
                    continue
                if isinstance(schedule, dict):
                    if step in schedule:
                        sim_dic[sig]['Hex'] = schedule[step]
                        sim_dic[sig].pop('BINARY', None)
                        sim_dic[sig].pop('DECIMAL', None)
                else:
                    # assume iterable list of (step, hex)
                    for s, hexval in schedule:
                        if s == step:
                            sim_dic[sig]['Hex'] = hexval
                            sim_dic[sig].pop('BINARY', None)
                            sim_dic[sig].pop('DECIMAL', None)
        # Store the dv_Binary

        # run single-step simulator
        sim_dic = dV_RC_bin_sim(sim_dic, timestep, debug=(debug_first_step and step == 1))
        r_dV_bin[step] = sim_dic['i_dV']['BINARY']

        # single, clear report per step
        print(f"Step {step}: i_dV: {sim_dic['i_dV']['BINARY']} ({len(sim_dic['i_dV']['BINARY'])} bits), DECIMAL: {sim_dic['i_dV']['DECIMAL']})")

    return sim_dic, r_dV_bin

c1_fmt = "0EN16"
a1_fmt = "-5EN16"
I_fmt = "4EN12"
dV_fmt = "11EN37"

timestep = 10
a1_hex = "19DA"
c1_hex = "4EC4"
# Sim state
a1_hex = '1D75'
c1_hex = '4C69'
dV_hex_lst = ["000000000000", "000000000000"]
dV_hex_lst[0] ="000000000000"
I_hex = "1000"
n_steps = 500
r_dV_dec = [0]*n_steps
sim_dic = {'i_a': {'Hex': a1_hex, 'Format': a1_fmt}, 'i_dV': {'Hex': dV_hex_lst[0], 'Format': dV_fmt}, 'i_I': {'Hex': I_hex, 'Format': I_fmt}, 'i_c': {'Hex': c1_hex, 'Format': c1_fmt}}


n_steps = 4
r_dV_bin = ['0']*n_steps

# Example usage: replace the previous ad-hoc loop with this call
updates = {
    'i_a': [(0, "1D75"), (4400, "1CD7")],                     # dictionary form: update i_a at step 2
    'i_c': [(0, "4C69"), (4400, "33C0")],     # list form: update i_c at steps 2 and 10
    'i_I': {4555: "5198"}                       # dictionary form: update i_I at step 2
}

# initial sim_dic (reuse your existing variable)
sim_dic_initial = {'i_a': {'Hex': a1_hex, 'Format': a1_fmt},
                   'i_dV': {'Hex': dV_hex_lst[0], 'Format': dV_fmt},
                   'i_I': {'Hex': I_hex, 'Format': I_fmt},
                   'i_c': {'Hex': c1_hex, 'Format': c1_fmt}}

# run
sim_dic_final, dV_bin1=run_simulation(n_steps, sim_dic_initial, updates=updates, timestep=timestep, debug_first_step=True)    
# ...existing code...

a2_hex = "05B9"
c2_hex = "9D88"

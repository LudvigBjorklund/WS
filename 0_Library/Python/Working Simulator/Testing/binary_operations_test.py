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

I_fmt = "4EN12"
R0_fmt = "8EN8"
I = 1 
R0 = 127
I_bin = bin_op.decimal_to_binary_string(I, I_fmt)
R0_bin = bin_op.decimal_to_binary_string(R0, R0_fmt)
print(f"I = {I} -> I_bin = {I_bin}")
print(f"R0 = {R0} -> R0_bin = {R0_bin}")
dV_R0_bin = bin_op.binary_multiplication(I_bin, R0_bin)

# new format 
dv_R0_fmt = "11EN37"
r_i_fmt = bin_op.new_fmt_string(I_fmt, R0_fmt, "multiplication")
print(f"New format for dV_R0: {dv_R0_fmt} and binary: {dV_R0_bin}")

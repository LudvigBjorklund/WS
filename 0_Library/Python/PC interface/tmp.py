import Preprocessing as preprocess


dec= 0.00315581854 
fmt = '-5EN11'
# Convert decimal to binary using decimal_to_binary_string from Preprocessing

binary_str = preprocess.decimal_to_binary_string(dec, fmt)
print(f"Binary representation of {dec} in format {fmt}: {binary_str} (length: {len(binary_str)})")
def print_aligned_two_series(bin_list, dec_list, bin_fmt, name1="dVRC1", name2="dVRC2",
                             timestep=4, num_fmt="{:.8g}"):
    """
    Print two series aligned so labels, '=' and numbers vertically line up.
    - bin_list: list of binary strings (will be converted to decimal using bin_fmt)
    - dec_list: list of decimal values (floats) for the second series
    - bin_fmt: format string for converting bin_list entries (passed to bin_op)
    - name1/name2: label prefixes for each series
    - timestep: used to compute the sample x-axis value (idx*2**(-timestep))
    - num_fmt: numeric formatting string for values
    """
    n1 = len(bin_list)
    n2 = len(dec_list)
    n = max(n1, n2)

    left1_list = [f"{name1}[{idx*2**(-timestep)}]" for idx in range(n)]
    left2_list = [f"{name2}[{idx*2**(-timestep)}]" for idx in range(n)]

    # Convert and format numbers, using placeholder for missing entries
    dec1_list = []
    for i in range(n):
        if i < n1:
            dec1 = bin_op.binary_string_to_decimal(bin_list[i], bin_fmt)
            dec1_list.append(dec1)
        else:
            dec1_list.append(None)
    # dec2_list is provided as floats (or None)
    dec2_list = [dec_list[i] if i < n2 else None for i in range(n)]

    dec1_strs = [num_fmt.format(v) if v is not None else "-" for v in dec1_list]
    dec2_strs = [num_fmt.format(v) if v is not None else "-" for v in dec2_list]

    # Compute max widths
    left1_w = max(len(s) for s in left1_list) if left1_list else 0
    left2_w = max(len(s) for s in left2_list) if left2_list else 0
    num1_w  = max(len(s) for s in dec1_strs) if dec1_strs else 0
    num2_w  = max(len(s) for s in dec2_strs) if dec2_strs else 0

    # Print aligned table
    for idx in range(n):
        print(f"{left1_list[idx].ljust(left1_w)} = {dec1_strs[idx].rjust(num1_w)} , "
              f"{left2_list[idx].ljust(left2_w)} = {dec2_strs[idx].rjust(num2_w)}")

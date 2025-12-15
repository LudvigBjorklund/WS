def decimal_to_binary(value,format_string="-16EN16", acceptable_error=0.0001): 
    """ , integer_bits=4, fractional_bits=12
    Alternative approach: explicitly separate integer and fractional parts.
    
    :param value: The decimal value to convert.
    :param integer_bits: Number of bits for the integer part.
    :param fractional_bits: Number of bits for the fractional part.
    :return: A binary string representation of the value.
    """

    parts = format_string.split('EN')
    int_part = int(parts[0])
    
    if int_part < 0:
        integer_bits = 0
        fractional_bits = int(parts[1])
        multiplicand = int(int_part) * (-1)
        value *= (2 ** multiplicand)
    else:
        multiplicand = int_part
        integer_bits = int(parts[0])
        fractional_bits = int(parts[1])
    total_bits = integer_bits + fractional_bits
    
    # Separate integer and fractional parts
    integer_part = int(value)
    fractional_part = value - integer_part
    
    # Convert integer part to binary
    if integer_part >= (2**integer_bits):
        integer_part = (2**integer_bits) - 1
    
    integer_binary = format(integer_part, f'0{integer_bits}b')
    
    # Convert fractional part to binary
    fractional_binary = ""
    temp_frac = fractional_part
    
    for i in range(fractional_bits):
        temp_frac *= 2
        if temp_frac >= 1:
            fractional_binary += "1"
            temp_frac -= 1
        else:
            fractional_binary += "0"
    
    # Combine integer and fractional parts
    if int_part <= 0:
        full_binary = fractional_binary
    else:
        full_binary = integer_binary + fractional_binary
    
    # Verification
    reconstructed = integer_part
    for i, bit in enumerate(fractional_binary):
        if bit == '1':
            reconstructed += 2**(-(i+1))
    rel_error =abs(value - reconstructed) / value*100
    #print(f"Relative error: {abs(value - reconstructed) / value * 100:.6f}%")
    if abs(value - reconstructed) / value > acceptable_error:
        print(f"Warning: Relative error exceeds acceptable threshold of {acceptable_error * 100:.6f}%")
    return full_binary, rel_error


def binary_to_decimal(binary_string, format_string="-16EN16",debug =False):
    """
    Converts a binary string back to a decimal value.
    
    :param binary_string: The binary string to convert.
    :param format_string: The format string for the binary representation.
    :return: The decimal value represented by the binary string.
    """
    if debug:
        print(f"\n\nConverting binary string: {binary_string} with format: {format_string}")
    # Convert to string if it's not already
    if not isinstance(binary_string, str):
        binary_string = str(binary_string)
    
    parts = format_string.split('EN')
    shift_part = int(parts[0])
    total_bits = int(parts[1])
    if debug:
        print(f"Binary string: {binary_string}")
        print(f"Format: {format_string}")
        print(f"Shift part: {shift_part}")

    # Initialize value
    value = 0.0

    if shift_part <= 0:
        # Negative format: the binary represents scaled-up fractional value
        multiplicand = abs(shift_part)
        
        # Convert binary string to fractional value
        for i, bit in enumerate(binary_string):
            if bit == '1':
                value += 2**(-(i+1))
        if debug:       
            print(f"Fractional value from binary: {value}")
        
        # Scale back down by dividing by 2^multiplicand
        original_value = value / (2**multiplicand)
        if debug:
            print(f"Original value after scaling back: {original_value}")

    else:
        # Positive format: mixed integer and fractional parts
        integer_bits = shift_part
        fractional_bits = total_bits - integer_bits
        
        # Extract integer and fractional parts from binary string
        if len(binary_string) != total_bits:
            print(f"Warning: Binary string length ({len(binary_string)}) doesn't match total bits ({total_bits})")
        
        integer_binary = binary_string[:integer_bits] if integer_bits > 0 else ""
        fractional_binary = binary_string[integer_bits:] if integer_bits < len(binary_string) else ""
        
        # Convert integer part
        if integer_binary:
            integer_value = int(integer_binary, 2)
        else:
            integer_value = 0
        
        # Convert fractional part
        fractional_value = 0.0
        for i, bit in enumerate(fractional_binary):
            if bit == '1':
                fractional_value += 2**(-(i+1))
        
        original_value = integer_value + fractional_value
        if debug:
            print(f"Integer part: {integer_value}")
            print(f"Fractional part: {fractional_value}")

    if debug:
        print(f"Final reconstructed value: {original_value}")
    return original_value
        

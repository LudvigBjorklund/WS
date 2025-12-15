import numpy as np


def generate_flat_2DLUT(matrix, signal_name ="c1"): 
    # Check if the content of the matrix is binary
    
    rows, cols = matrix.shape
    n_elements = rows*cols

    #Start building the VHDL code
    vhdl_code = f"signal {signal_name} : flat_lut :=(\n"

    # Process each row
    for i in range(rows):
        # Add row comment
        vhdl_code+= f" -- Row {i} \n"

        # Collect all the elements in the row
        row_elements = []
        for j in range(cols):

            row_elements.append(f'"{matrix[i,j]}"')

        # add the row data 
        row_line = " " + ", ".join(row_elements)

        # Add a comma (unless we are at the last row)
        if i < rows -1 :
            row_line +=","
        else:
            row_line += "\n);"
        
        vhdl_code += row_line +"\n"
    
    # Closign the signal declaration
    vhdl_code += f" -- Total elements: {n_elements} ({rows} rows x {cols} columns)\n"

    return vhdl_code

def generate_flat_1DLUT(array, signal_name ="vocv"): 
    # Check if the content of the matrix is binary
    
    n_elements = array.shape[0]

    #Start building the VHDL code
    vhdl_code = f"signal {signal_name} : flat_lut_1D :=(\n"

    # Collect all the elements in the array
    elements = []
    for i in range(n_elements):
        elements.append(f'"{array[i]}"')

    # add the data 
    line = " " + ", ".join(elements) + "\n);"
        
    vhdl_code += line
    
    # Closign the signal declaration
    vhdl_code += f" -- Total elements: {n_elements}\n"

    return vhdl_code
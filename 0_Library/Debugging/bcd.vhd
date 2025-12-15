library ieee;
use ieee.std_logic_1164.all; -- Standard logic package for VHDL
use ieee.numeric_std.all;    -- Numeric package for arithmetic operations

-- Entity declaration with generic parameters
entity bcd is 
    generic(
        g_bin_width : integer := 20 -- Default binary input width
    );
    port(
        i_bin : in  unsigned(g_bin_width-1 downto 0); -- Binary input of generic width
        o_bcd : out unsigned(g_bin_width + 3 downto 0) -- BCD output width
    );
end entity bcd;

-- Architecture for binary to BCD conversion
architecture rtl of bcd is 
begin 
    -- Process to perform the binary to BCD conversion using the double dabble algorithm
    process (i_bin) 
        constant no_of_loops : integer := g_bin_width - 1; -- Number of loops based on input width
        constant bcd_width : integer := g_bin_width + 4; -- Calculate BCD width
        variable bcd : unsigned(bcd_width-1 downto 0) := (others => '0'); -- Internal BCD register
        variable bint : unsigned(no_of_loops downto 0) := (others => '0'); -- Internal binary register
    begin
        -- Initialize variables
        bcd := (others => '0'); -- Reset the BCD variable
        bint := i_bin(no_of_loops downto 0); -- Copy input to binary register

        -- Loop to perform the double dabble algorithm
        for i in 0 to no_of_loops loop
            -- Shift BCD digits to the left
            bcd(bcd_width-1 downto 1) := bcd(bcd_width-2 downto 0);
            bcd(0) := bint(no_of_loops); -- Add the MSB of the binary input
            -- Shift binary input to the right
            bint(no_of_loops downto 1) := bint(no_of_loops-1 downto 0);
            bint(0) := '0';

            -- Adjust BCD digits if greater than 4
            for j in 0 to (bcd_width/4)-1 loop
                if i < no_of_loops and bcd((j*4)+3 downto j*4) > "0100" then
                    bcd((j*4)+3 downto j*4) := bcd((j*4)+3 downto j*4) + 3;
                end if;
            end loop;
        end loop;

        -- Assign the converted BCD to the output
        o_bcd <= bcd;
    end process;
end architecture rtl;
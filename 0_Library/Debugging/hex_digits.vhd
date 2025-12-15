-- filepath: /home/ntnu/Documents/Towards Digital Twins for Safety Demonstrations/FPGA Development/Code Projects/VHDL/Digital Twin/RC Circuit VII - Clocked_UART/hex_digits.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_digits is 
    port(
        i_clk : in std_logic;
        i_bin : in unsigned(3 downto 0); -- 4-bit binary input
        o_hex : out std_logic_vector(6 downto 0) -- 7-segment display output
    );
end entity hex_digits;

architecture rtl of hex_digits is

signal r_hex : std_logic_vector(6 downto 0); -- Internal signal to hold the 7-segment display value

begin
    -- Process to calculate the 7-segment display value based on the binary input
    calc_hex_digit: process(i_clk)
    begin 
        case i_bin is 
            when "0000" => r_hex <= "1000000"; -- Display "0"
            when "0001" => r_hex <= "1111001"; -- Display "1"
            when "0010" => r_hex <= "0100100"; -- Display "2"
            when "0011" => r_hex <= "0110000"; -- Display "3"
            when "0100" => r_hex <= "0011001"; -- Display "4"
            when "0101" => r_hex <= "0010010"; -- Display "5"
            when "0110" => r_hex <= "0000010"; -- Display "6"
            when "0111" => r_hex <= "1111000"; -- Display "7"
            when "1000" => r_hex <= "0000000"; -- Display "8"
            when "1001" => r_hex <= "0011000"; -- Display "9"
            when "1111" => r_hex <= "1111111"; -- No display
            when others => r_hex <= "1001110"; -- Display "F" for invalid input
        end case;
        o_hex <= r_hex; -- Assign the calculated 7-segment value to the output
    end process;
end architecture;
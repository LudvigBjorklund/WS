library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_to_int is 
    port(
        i_clk : in std_logic;
        i_hex : in std_logic_vector(6 downto 0); -- 7-segment display input
        o_int : out integer range 0 to 9 -- Integer output (0 to 9)
    );
end entity hex_to_int;

architecture rtl of hex_to_int is

signal r_int : integer range 0 to 9; -- Internal signal to hold the binary value

begin
    -- Process to calculate the binary value based on the 7-segment display input
    calc_bin_digit: process(i_clk)
    begin 
        case i_hex is 
            when "1000000" => r_int <= 0; -- "0"
            when "1111001" => r_int <= 1; -- "1"
            when "0100100" => r_int <= 2; -- "2"
            when "0110000" => r_int <= 3; -- "3"
            when "0011001" => r_int <= 4; -- "4"
            when "0010010" => r_int <= 5; -- "5"
            when "0000010" => r_int <= 6; -- "6"
            when "1111000" => r_int <= 7; -- "7"
            when "0000000" => r_int <= 8; -- "8"
            when "0011000" => r_int <= 9; -- "9"
            when "1111111" => r_int <= 0; -- No display -> 0
            when "1001110" => r_int <= 0; -- "F"
            when others => r_int <= 0; -- Invalid input -> 0
        end case;
        o_int <= r_int; -- Assign the calculated binary value to the output
    end process;
end architecture;
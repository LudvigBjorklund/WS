-- -- Import necessary libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tbl_rd_reset_1D_sim is
    generic(
        max_addr_val : integer := 10;  -- Maximum address value
        hex_init : string := "LUT_1D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;                     -- Clock signal
        i_raddr : in  unsigned(3 downto 0);            -- Read address (4-bit)
        o_data  : out unsigned(19 downto 0)            -- 16-bit data output for read
    );
end entity tbl_rd_reset_1D_sim;

architecture rtl of tbl_rd_reset_1D_sim is

type flat_1D_LUT is array (0 to 10) of unsigned(19 downto 0);

signal r_vocv : flat_1D_LUT :=(
 "10101111000000000000", "10111110101000000000", "11000100010000000000", "11001000000000000000", "11001001010000000000", "11001001111000000000", "11001010110100000000", "11001011001000000000", "11001100011000000000", "11001110010000000000", "11010011010000000000"
); -- Total elements: 11


begin
    process(i_clk)
    begin
        if rising_edge(i_clk) then
        
            if i_raddr <= to_unsigned(max_addr_val, 4) then
                o_data <= r_vocv(to_integer(i_raddr));
            end if;
        end if;
    end process;
end architecture rtl;
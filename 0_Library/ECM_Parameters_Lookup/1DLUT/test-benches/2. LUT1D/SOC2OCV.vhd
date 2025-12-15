library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity SOC2OCV is 
    generic(
        n_frac_bits : integer := 20; -- Number of fractional bits in the SOC input
    );
    port(
        i_clk   : in std_logic;
        i_state : in t_state;
        i_SOC   : in unsigned(15 downto 0); -- Input SOC value
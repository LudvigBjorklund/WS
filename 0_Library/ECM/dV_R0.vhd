library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity dV_R0 is
    generic(
        n_b_int_R0 : integer := 8;  -- Number of bits for the integer part of R0
        n_b_frac_R0 : integer := 8;  -- Number of bits for the fractional part of R0
        n_b_int_I : integer := 4;   -- Number of bits for the integer part of I
        n_b_frac_I : integer := 12;   -- Number of bits for the fractional part of I
        n_b_int_dV_R0 : integer := 11; -- Number of bits for the integer part of dV_R0
        n_b_frac_dV_R0 : integer := 37  -- Number of bits for the fractional part of dV_R0
    );
    port (
        i_clk    : in std_logic;
        i_R0     : in unsigned(15 downto 0);
        i_I      : in unsigned(15 downto 0);
        o_dV_R0  : out unsigned(47 downto 0)
    );  
end entity dV_R0;

architecture rtl of dV_R0 is

    signal initialization : std_logic := '0';
    signal r_dV : unsigned(31 downto 0) := (others => '0');
    
    signal tmp_moved_tb : std_logic := '0';
    -- Constants derived from generics
    constant n_RtimesI_int : integer := n_b_int_R0 + n_b_int_I;
    signal  n_msb : integer := abs(n_RtimesI_int - n_b_int_dV_R0);
    constant dbg_n_b_int_dV_R0 : integer := n_b_int_dV_R0;
    
    -- Function to evaluate MSB removal condition at compile time
    function check_remove_msb return boolean is
    begin
        return (n_RtimesI_int > dbg_n_b_int_dV_R0);
    end function;
    
    signal remove_msb : boolean := check_remove_msb;

begin 
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            tmp_moved_tb <= '1';
            if initialization = '1' then
                if remove_msb then
                    r_dV <= i_R0 * i_I;
                    o_dV_R0 <= r_dV(r_dV'length-1-n_msb downto 0) & to_unsigned(0, 48 +n_msb - r_dV'length);
                else
                end if;
            else
                r_dV <= i_R0 * i_I;
                initialization <= '1'; 
            end if;
     
        end if;
    end process;
    

end architecture rtl;
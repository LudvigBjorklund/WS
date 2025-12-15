library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;
-- The simulation state takes the i_state_bin input and converts it to the t_state
-- type. This is used to track the simulation state
entity sim_SM is 
    port(
        i_clk    : in std_logic;
        i_state_bin  : in unsigned(2 downto 0);
        o_state  : out t_state
    );
end entity sim_SM;

architecture rtl of sim_SM is

constant c_ID_idle : unsigned(2 downto 0) := "000";
constant c_ID_init : unsigned(2 downto 0) := "001";
constant c_ID_ver  : unsigned(2 downto 0) := "010"; -- Verification state
constant c_ID_sim  : unsigned(2 downto 0) := "011"; -- Simulation state
constant c_ID_pause: unsigned(2 downto 0) := "100"; -- Pause state
constant c_ID_end  : unsigned(2 downto 0) := "101"; -- End state
constant c_ID_reset: unsigned(2 downto 0) := "110"; -- Debug state

begin
    process(i_clk)
    begin   
        if rising_edge(i_clk) then
            case i_state_bin is 

                when c_ID_idle =>
                    o_state <= s_idle;
                when c_ID_init => 
                    o_state <= s_init;
                when c_ID_ver =>
                    o_state <= s_verification; -- Verification state
                when c_ID_sim =>
                    o_state <= s_sim; -- Simulation state
                when c_ID_pause =>
                    o_state <= s_pause; -- Pause state
                when c_ID_end => 
                    o_state <= s_end; -- End state
                when c_ID_reset => 
                    o_state <= s_reset; -- Debug state
                when others => 
                    null;
            end case;

        end if;

    end process;
end architecture;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity simulation_time is
    generic(
        timestep : integer := 3 -- dt = 2^(-timestep) seconds
    );
    port(
        i_clk : in std_logic;
        i_state : in t_state;
        i_step : in std_logic;
        o_time : out unsigned(23 downto 0)
    );
end entity simulation_time;

architecture rtl of simulation_time is

-- Calculates the simulation time and returs a unsigned vector for transmission back to the PC
-- 6 MSBs are the minutes, then seconds and then the steps per second
signal steps_per_second : unsigned(timestep downto 0) := (others => '0');
signal seconds : unsigned(5 downto 0) := (others => '0');
signal minutes : unsigned(5 downto 0) := (others => '0');


signal dbg_state_no : integer range 0 to 3 := 3;


begin
    process(i_clk)
    begin 
        if rising_edge(i_clk) then
            
            o_time(23 downto 12) <= minutes & seconds;
            o_time(timestep downto 0) <= steps_per_second;
            o_time(11 downto timestep) <= (others => '0');
            case i_state is 
                when s_idle =>
                    dbg_state_no <= 0;
                    steps_per_second <= (others => '0');
                    seconds <= (others => '0');
                    minutes <= (others => '0');
                when s_init =>
                    dbg_state_no <= 1;
                    steps_per_second <= (others => '0');
                    seconds <= (others => '0');
                    minutes <= (others => '0');
                when s_sim =>
                    dbg_state_no <= 2;
                    if i_step = '1' then 
                        if steps_per_second < to_unsigned(2**timestep - 1, steps_per_second'length) then
                            steps_per_second <= steps_per_second + 1;
                        else
                            steps_per_second <= (others => '0');
                            if seconds < "111011" then
                                seconds <= seconds + 1;
                            else
                                seconds <= (others => '0');
                                if minutes < "111011" then
                                    minutes <= minutes + 1;
                                else
                                    minutes <= (others => '0');
                                end if;
                            end if;
                        end if;
                    end if;
                when others =>
                    null;
            end case;
        end if;
    end process;
end architecture rtl;
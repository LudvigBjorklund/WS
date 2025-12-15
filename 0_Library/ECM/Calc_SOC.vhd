library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity Calc_SOC is
    generic(
        timestep   : integer := 4; -- dt = 2^(-timestep) seconds
        n_b_SOC : integer := 16;
        n_b_I   : integer := 16;
        n_b_Q   : integer := 16;
        n_int_SOC : integer := 7;
        n_frac_SOC : integer := 9;
        n_int_I : integer := 4;
        n_frac_I : integer := 12;
        n_int_Q  : integer := -8;
        n_frac_Q  : integer := 16
    );
    port(
        i_clk : in std_logic;
        i_state : in t_state;
        i_charge : in std_logic; -- '1' - Charging, '0' - Discharging
        i_step : in std_logic;
        i_SOC0 : in unsigned(n_b_SOC - 1 downto 0);
        i_I   : in unsigned(n_b_I - 1 downto 0);
        i_Q   : in unsigned(n_b_Q - 1 downto 0);
        o_SOC : out unsigned(24 - 1 downto 0) 
    );
end entity Calc_SOC;

architecture rtl of Calc_SOC is

signal IQ : unsigned((n_int_SOC - (n_int_I + n_int_Q))+timestep + n_b_I + n_b_Q - 1 downto 0) := (others => '0'); -- Intermediate signal 1: I*Q*dt
--signal SOC_tmp : unsigned(n_b_I + n_b_Q + timestep +((n_int_SOC - (n_int_I + n_int_Q))) -1 downto 0) := (others => '0');

signal SOC_tmp : unsigned(n_b_I + n_b_Q + timestep +((n_int_SOC - (n_int_I + n_int_Q))) -1 downto 0) := i_SOC0 & to_unsigned(0, IQ'left-i_SOC0'left ); -- Intermediate signal 2: SOC + IQ
-- Storing the result of addition/subtraction of IQ and SOC_tmp
signal result : unsigned((n_b_I + n_b_Q + timestep +((n_int_SOC - (n_int_I + n_int_Q)))) downto 0) := (others => '0');

signal initialization_done : std_logic := '0';
signal last_SOC : unsigned(n_b_SOC - 1 downto 0) := (others => '0');
---------------------------------------------------- Debugging Signals --------------------------
signal dbg_t1_fmt_int : integer := n_int_I + n_int_Q; -- The format x'EN'
signal dbg_t1_fmt_frac: integer := n_frac_I + n_frac_Q; -- The format 'EN'x
--signal dbg_
signal dbg_t1_MSB : integer := n_int_SOC - (n_int_I + n_int_Q);
signal dbg_SOC_tmp_LSB : integer :=  n_b_I + n_b_Q + timestep +((n_int_SOC - (n_int_I + n_int_Q)));
begin

process(i_clk)
variable wait_variable : std_logic := '0';
begin
    if rising_edge(i_clk) then
        if i_SOC0 /= last_SOC then
            initialization_done <= '0';
            wait_variable := '0';
            last_SOC <= i_SOC0;
            o_soc <= i_SOC0;
        else 
            o_soc <= SOC_tmp(SOC_tmp'left downto SOC_tmp'left - n_b_SOC+1);
        end if;
        -- Initiation step
        case i_state is 
            when s_idle =>
                SOC_tmp <=  i_SOC0 & to_unsigned(0, IQ'left-i_SOC0'left );
                result(result'left -1 downto 0) <= SOC_tmp;
            when s_init =>
                initialization_done <= '0';
                if initialization_done = '0' then
                    IQ(IQ'left-((n_int_SOC - (n_int_I + n_int_Q))+timestep) downto 0) <= i_I * i_Q; -- By skipping the timesteps we perform a shifting operation to cover dt multiplication
                    SOC_tmp(SOC_tmp'left downto SOC_tmp'left - n_b_SOC+1) <= i_soc0; -- Assigning the current SOC value to the MSBs of SOC_tmp
                    
                    if wait_variable = '1' then
                        initialization_done <= '1';
                        result(result'left -1 downto 0) <= SOC_tmp;

                    else 
                        wait_variable := '1';
                    end if;
                else
                    null;
                end if;
            when s_sim =>
                  if initialization_done = '0' then
                    IQ(IQ'left-((n_int_SOC - (n_int_I + n_int_Q))+timestep) downto 0) <= i_I * i_Q; -- By skipping the timesteps we perform a shifting operation to cover dt multiplication
                    SOC_tmp(SOC_tmp'left downto SOC_tmp'left - n_b_SOC+1) <= i_soc0; -- Assigning the current SOC value to the MSBs of SOC_tmp
                    
                    if wait_variable = '1' then
                        initialization_done <= '1';
                        result(result'left -1 downto 0) <= SOC_tmp;
                    else 
                        wait_variable := '1';
                    end if;
                else 
                    if i_step = '1' then
                        if i_charge ='1' then
                            if SOC_tmp(SOC_tmp'left downto SOC_tmp'left  - (n_int_SOC - 1)) = "1100100" then
                                result(result'left -1 downto result'left - (n_int_SOC -0)) <= "1100100";
                                result(result'left - (n_int_SOC -0) -1 downto 0) <= (others => '0');
                            else
                                result(result'left -1 downto 0) <= SOC_tmp + IQ; -- 1 + SOC_int format 
                            end if;
                        else
                            if SOC_tmp > IQ then
                                result(result'left -1 downto 0) <= SOC_tmp - IQ; 
                            else 
                                result <= (others => '0');
                            end if;
                        end if;
                    else    
                        IQ(IQ'left-((n_int_SOC - (n_int_I + n_int_Q))+timestep) downto 0) <= i_I * i_Q;
                        SOC_tmp <= result(result'left- 1 downto 0);
                    end if;
                end if;
            when others =>  
                null;
            end case;
    end if;
end process;

end architecture rtl;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.num_of_bits.all;
use work.fixed_point_formats.all;

package DT_Parameters is
------ 2D-LUT Addresses for overwriting the values in the stored tables (Stored outside)
constant c_hw_addr_R0_num : integer := 176; 
constant c_hw_addr_a1_num : integer := 176;
constant c_hw_addr_c1_num : integer := 176;
constant c_hw_addr_a2_num : integer := 176;
constant c_hw_addr_c2_num : integer := 176;


------ 2D-LUT Addresses for overwriting the values in the stored tables

-- 2D-LUT init address

constant c_hw_2D_addr_init : integer := 176;


constant ow_addr_R0 : unsigned(n_b_ow_addr-1 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr);
constant ow_addr_a1 : unsigned(n_b_ow_addr-1 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr);
constant ow_addr_c1 : unsigned(n_b_ow_addr-1 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr);
constant ow_addr_a2 : unsigned(n_b_ow_addr-1 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr);
constant ow_addr_c2 : unsigned(n_b_ow_addr-1 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr);


-- ========================================================
-- Hardware Constants: Initial Values, and reset values when we go to s_idle
-- ========================================================


constant c_hw_SM : unsigned(n_b_state-1 downto 0) := "000"; -- Initial state is s_idle

-- ============ Hardware Numeric Values ============

-- ==== Measured Variables ====
constant c_hw_dV_num         : integer := 0;     -- Default value for dV
constant c_hw_I_num          : integer := 2;     -- Default value for I (2A initial current)
constant c_hw_SOC0_num       : integer := 100;   -- Default value for SOC (100%)

-- ==== ECM Parameters ====
constant c_hw_R0_num         : integer := 127;   -- Default value for R0 mOhms (0.127 Ohms) 

-- ============ Hardware Default Values ============
constant c_hw_R0 : unsigned(n_b_R0 - 1 downto 0) :=to_unsigned(c_hw_R0_num, fmt_int_R0) & to_unsigned(0, fmt_frac_R0); -- Initial value for R0 (1/(C1*R1))
constant c_hw_a1 : unsigned(n_b_a - 1 downto 0) := "0001100111011010"; -- Initial value for a1 (1/(C1*R1))
constant c_hw_c1 : unsigned(n_b_c - 1 downto 0) := "0100111011000100"; -- Initial value for c1 (1/(C1))
constant c_hw_a2 : unsigned(n_b_a - 1 downto 0) := "0000010110110110"; -- Initial value for a2 (1/(C2*R2))
constant c_hw_c2 : unsigned(n_b_c - 1 downto 0) := "1011011000001011"; -- Initial value for c2 (1/(C2))



constant c_hw_dV_RC1    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);
constant c_hw_dV_RC2    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);
constant c_hw_dV_R0    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);

constant c_hw_I         : unsigned(n_b_I - 1 downto 0) := to_unsigned(c_hw_I_num, fmt_int_I) & to_unsigned(0, fmt_frac_I);
constant c_hw_SOC0      : unsigned(n_b_SOC - 1 downto 0) := to_unsigned(c_hw_SOC0_num, fmt_int_SOC) & to_unsigned(0, fmt_frac_SOC); -- Initial SOC value (100% in 24 bits fixed point 7.17 format)
----- SOC Parameters
constant c_hw_Q        : unsigned(n_b_Q - 1 downto 0) := "0110010100100010"; -- Battery Capacity (inverted and multiplied by 36) 



end package DT_Parameters;
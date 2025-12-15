library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package ConfigurationData is
    
-- =============================================================================================
-- =========================== Simulation Setttings  =============================
-- ============================================================================================= 
    constant c_timestep : integer := 4; -- dt^(-timestep)
    
-- =============================================================================================
-- =========================== Data Width Settings =============================
-- ============================================================================================= 

    constant n_b_state : integer := 3; -- Number of bits to represent the state signal
    constant n_b_dp_RX : integer := 24; -- Number of bits per data packet (signal) in RX
    constant n_b_dp_TX : integer := 24; -- Number of bits per data packet (signal) in TX
    
    -- Variables
    constant n_b_dV : integer := 48; -- Voltage 11EN37
    constant n_b_I  : integer := 16; 
    constant n_b_SOC : integer := 24;
    constant n_b_SOC0 : integer := 24;

    -- ECM Parameters
    constant n_b_R0 : integer := 16;
    constant n_b_a : integer := 16; 
    constant n_b_c : integer := 16;

    constant n_b_Q : integer := 16;

    constant n_b_ow_addr : integer := 8; -- For all overwrite addresses
    constant n_b_2D_LUT_dp :integer := 16; -- Dimensions of the 2D LUT data cell-elements

-- =============================================================================================
-- =========================== Fixed-Point Settings =============================
-- ============================================================================================= 
    ---- Variables (int)
    constant fmt_int_dV : integer := 11; -- Same for both
    constant fmt_int_I : integer := 4;
    constant fmt_int_SOC : integer := 7;
    ---- Variables (frac)
    constant fmt_frac_dV : integer := n_b_dV - fmt_int_dV;
    constant fmt_frac_I : integer := n_b_I - fmt_int_I;
    constant fmt_frac_SOC : integer := n_b_SOC - fmt_int_SOC;

    ---- ECM Parameters (int)
    constant fmt_int_R0 : integer := 8;
    constant fmt_int_a1 : integer := -5;
    constant fmt_int_c1 : integer := 0;
    constant fmt_int_a2 : integer := -7;
    constant fmt_int_c2 : integer := -5;
    constant fmt_int_Q  : integer := -8;

    ---- ECM Parameters (frac)
    constant fmt_frac_R0 : integer := n_b_R0 - abs(fmt_int_R0);
    constant fmt_frac_a1 : integer := n_b_a - abs(fmt_int_a1);
    constant fmt_frac_c1 : integer := n_b_c - abs(fmt_int_c1);
    constant fmt_frac_c2 : integer := n_b_c - abs(fmt_int_c2);
    constant fmt_frac_a2 : integer := n_b_a - abs(fmt_int_a2);
    constant fmt_frac_Q  : integer := n_b_Q - abs(fmt_int_Q);

-- =============================================================================================
-- =========================== Digital Twin Parameters =============================
-- ============================================================================================= 


-- ====== Memory Initialization Files =================
constant R0_mif          : string := "R0.mif"; -- MIF file for R0 parameter
constant a1_mif          : string := "a1.mif"; -- MIF file for a1 table
constant c1_mif          : string := "c1.mif"; -- MIF file for c1 table
constant a2_mif          : string := "a2.mif"; -- MIF file for a2 table
constant c2_mif          : string := "c2.mif"; -- MIF file for c2 table


    
------ 2D-LUT Addresses for overwriting the values in the stored tables

-- 2D-LUT init address

constant c_hw_2D_addr_init : integer := 176;
constant c_hw_1D_addr_init : integer := 0;


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
constant c_hw_v_oc : unsigned(19 downto 0) := "10101111000000000000";  -- Initial value for V_OCV (2800 mV 12EN36)


constant c_hw_Q        : unsigned(n_b_Q - 1 downto 0) := "0110010100100010"; -- The inverted Q_value (multiplied by 3600) ~  18 Ah
constant c_hw_ow_R0 : unsigned(23 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr) & c_hw_R0;
constant c_hw_ow_a1 : unsigned(23 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr) & c_hw_a1;
constant c_hw_ow_c1 : unsigned(23 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr) & c_hw_c1;
constant c_hw_ow_a2 : unsigned(23 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr) & c_hw_a2;
constant c_hw_ow_c2 : unsigned(23 downto 0) := to_unsigned(c_hw_2D_addr_init, n_b_ow_addr) & c_hw_c2;
constant c_hw_ow_v_ocv : unsigned(23 downto 0) := to_unsigned(c_hw_1D_addr_init, 4) & c_hw_v_oc;

constant c_hw_dV_RC1    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);
constant c_hw_dV_RC2    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);
constant c_hw_dV_R0    : unsigned(n_b_dV - 1 downto 0) := to_unsigned(c_hw_dV_num, fmt_int_dV) & to_unsigned(0, fmt_frac_dV);

constant c_hw_I         : unsigned(n_b_I - 1 downto 0) := to_unsigned(c_hw_I_num, fmt_int_I) & to_unsigned(0, fmt_frac_I);
constant c_hw_SOC0      : unsigned(n_b_SOC - 1 downto 0) := to_unsigned(c_hw_SOC0_num, fmt_int_SOC) & to_unsigned(0, fmt_frac_SOC); -- Initial SOC value (100% in 24 bits fixed point 7.17 format)

    -- =============================================================================================
    -- =========================== UART Settings =============================
    -- ============================================================================================= 

    -- Function Declaration
    function max(L, R: integer) return integer;
    -- =======================================================================
    -- UART Settings
    -- =======================================================================
    constant c_clk_rate : integer := 434; -- Baud rate of the incoming data CHANGE BEFORE SYNTHESIS
    -- ========================================
    -- No. of Interface Signals
    -- ========================================
    constant c_rx_no_sig : integer := 9; -- Number of signals to be received
    constant c_tx_no_sim_sig : integer := 3; -- Number of signals to be transmitted in simulation mode CHANGE BEFORE SYNTHESIS
    constant c_tx_no_ver_sig : integer := 4; -- Number of signals to be transmitted in verification mode
    constant c_tx_no_sig : integer := max(c_tx_no_sim_sig, c_tx_no_ver_sig); -- Maximum number of signals to be transmitted (for array sizing)

    -- ========================================
    -- Supporting Interface Constants
    -- ========================================
    constant signal_fully_verified_ones : std_logic_vector(c_tx_no_ver_sig-1 downto 0) := (others => '1'); -- Indicates if each signal has been verified, only those which are changed need to be transmitted

    -- =======================================================================
    -- Initial Signal Values for Transceiver
    -- =======================================================================
    -- ========================================
    -- Initial RX Signals (Mapping to ID)
    -- ========================================
    constant rx_sig1 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_state) & c_hw_SM; -- Signal 1 from RX concatenation (for initialization)
    constant rx_sig2 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_I)     & c_hw_I; -- Signal 2 from RX concatenation (for initialization)
    constant rx_sig3 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_SOC)   & c_hw_SOC0; -- Signal 3 from RX concatenation (for initialization)
    constant rx_sig4 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_Q)     & c_hw_Q; -- Signal 4 from RX concatenation (for initialization)

    constant rx_sig5 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_R0- n_b_ow_addr) &  ow_addr_R0 & c_hw_R0; -- Signal 4 from RX concatenation (for initialization)
    constant rx_sig6 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_a - n_b_ow_addr) &  ow_addr_a1 & c_hw_a1; -- Signal 5 from RX concatenation (for initialization)
    constant rx_sig7 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_c - n_b_ow_addr) &  ow_addr_c1 & c_hw_c1; -- Signal 6 from RX concatenation (for initialization)
    constant rx_sig8 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_a - n_b_ow_addr) &  ow_addr_a2 & c_hw_a2; -- Signal 7 from RX concatenation (for initialization)
    constant rx_sig9 : unsigned(n_b_dp_RX-1 downto 0) :=  to_unsigned(0, n_b_dp_RX-n_b_c - n_b_ow_addr) &  ow_addr_c2 & c_hw_c2; -- Signal 8 from RX concatenation (for initialization)
    -- ========================================
    -- Initial TX Signals (Mapping to ID)
    -- ========================================
    constant tx_sig1 : unsigned(31 downto 0) := to_unsigned(1, 8) & to_unsigned(10, 8) & to_unsigned(11,8) & to_unsigned(12, 8); -- State signal
    constant tx_sig2 : unsigned(31 downto 0) := to_unsigned(2, 8) & to_unsigned(13,8)  & to_unsigned(14,8) & to_unsigned(15, 8); -- Control signal
    constant tx_sig3 : unsigned(31 downto 0) := to_unsigned(3, 8) & to_unsigned(16,8)  & to_unsigned(17,8)  & to_unsigned(18, 8); -- SOC signal
    constant tx_sig4 : unsigned(31 downto 0) := to_unsigned(4, 8) & to_unsigned(19,8)  & to_unsigned(20, 8) & to_unsigned(21, 8); -- dVRC1 signal
    
    -- =======================================================================
    -- Initial Constant Buses for Transceiver
    -- =======================================================================
    constant c_rx_init_datapacket : unsigned((c_rx_no_sig * 24) - 1 downto 0) := rx_sig9 & rx_sig8 & rx_sig7 & rx_sig6 & rx_sig5 &
                                                                              rx_sig4 & rx_sig3 & rx_sig2 & rx_sig1; -- Initial concatenated data bus for RX

    constant c_tx_init_datapacket : unsigned((c_tx_no_sig * 32) - 1 downto 0) := tx_sig4 & tx_sig3 & tx_sig2 & tx_sig1; -- Initial concatenated data bus for TX


end package ConfigurationData;


-- Package Body Implementation
package body ConfigurationData is

    function max(L, R: integer) return integer is
    begin
        if L > R then
            return L;
        else
            return R;
        end if;
    end function;

end package body ConfigurationData;

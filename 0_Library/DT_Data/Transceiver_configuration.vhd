library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.num_of_bits.all;
use work.fixed_point_formats.all;
use work.DT_Parameters.all;

package Transceiver_configuration is
    -- Function Declaration
    function max(L, R: integer) return integer;
    -- =======================================================================
    -- UART Settings
    -- =======================================================================
    constant c_clk_rate : integer := 434; -- Baud rate of the incoming data CHANGE BEFORE SYNTHESIS
    -- ==== Number of Signals ====
    constant c_no_sig_rx : integer := 9; -- Number of signals to be received
    constant n_TX_sig_sim : integer := 3; -- Number of signals to be transmitted in simulation mode CHANGE BEFORE SYNTHESIS
    constant n_TX_sig_ver : integer := 4; -- Number of signals to be transmitted in verification mode CHANGE BEFORE SYNTHESIS
    constant n_TX_max_no_signals : integer := max(n_TX_sig_sim, n_TX_sig_ver); -- Maximum number of signals to be transmitted (for array sizing)

    
    constant signal_fully_verified_ones : std_logic_vector(n_TX_sig_ver-1 downto 0) := (others => '1'); -- Indicates if each signal has been verified, only those which are changed need to be transmitted

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
    constant c_rx_init_datapacket : unsigned((c_no_sig_rx * 24) - 1 downto 0) := rx_sig9 & rx_sig8 & rx_sig7 & rx_sig6 & rx_sig5 &
                                                                              rx_sig4 & rx_sig3 & rx_sig2 & rx_sig1; -- Initial concatenated data bus for RX

    constant c_tx_init_datapacket : unsigned((n_TX_max_no_signals * 32) - 1 downto 0) := tx_sig4 & tx_sig3 & tx_sig2 & tx_sig1; -- Initial concatenated data bus for TX

end package Transceiver_configuration;


-- Package Body Implementation
package body Transceiver_configuration is

    function max(L, R: integer) return integer is
    begin
        if L > R then
            return L;
        else
            return R;
        end if;
    end function;

end package body Transceiver_configuration;
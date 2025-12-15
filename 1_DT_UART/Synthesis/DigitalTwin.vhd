library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

use work.DT_Components_declaration.all;
use work.ConfigurationData.all;


entity DigitalTwin is 
    port(
        i_clk : in std_logic;
        i_rx  : in std_logic;
        o_led : out unsigned(9 downto 0) := (others => '0');
        o_tx  : out std_logic
    );
end entity DigitalTwin;


architecture rtl of DigitalTwin is

-- =========================================================================
-- Signal Declarations
-- ========================================================================= 
-- ======================
-- UART 32-bit 
-- ======================

-- =========
-- Receiver
-- =========
signal rx_datapacket : unsigned((c_rx_no_sig * 24) - 1 downto 0) := c_rx_init_datapacket; 
-- =========
-- Transmitter
-- =========
signal tx_datapacket : unsigned((c_tx_no_sig * 32) - 1 downto 0) := c_tx_init_datapacket; 
signal tx_start : std_logic := '0';
signal tx_updated_signals : std_logic_vector(c_tx_no_ver_sig-1 downto 0) := (others => '1'); -- Indicates if each signal has been verified, only those which are changed need to be transmitted
signal tx_done : std_logic := '0'; -- To indicate that the DT_TX transmission is done

-- ======================
-- State Machine 
-- ======================
signal r_SM_no       : unsigned(2 downto 0) := (others => '0'); -- State machine number signal
signal r_state : t_state := s_idle; -- s_idle, s_init, s_verification, s_sim, s_pause, s_end, s_reset



begin

    sim_SM_inst : sim_SM
    port map(
        i_clk       => i_clk,
        i_state_bin => r_SM_no,
        o_state     => r_state
    );


-------- Interface
 DT_UART_32bit_inst : DT_UART_32bit
    generic map(
        g_clk_rate => c_clk_rate,
        g_no_signals_rx => c_rx_no_sig,
        g_no_signals_tx => c_tx_no_sim_sig, -- CHANGE BEFORE SYNTHESIS
        g_no_signals_ver_tx => c_tx_no_ver_sig, -- CHANGE BEFORE SYNTHESIS
        g_max_no_signals_tx => c_tx_no_sig, -- CHANGE BEFORE SYNTHESIS
        g_init_rx_data => to_unsigned(0, 32) -- Initial value of the RX data bus
    )
    port map(
        i_clk => i_clk,
        i_state => r_state,
        i_rx => i_rx,
        i_init_rx_cnct => c_rx_init_datapacket,
        i_strt_tx => tx_start,
        i_data_tx => tx_datapacket,
        i_skip_tx => tx_updated_signals,
        o_rx_data => rx_datapacket,
        o_done_tx => tx_done,
        o_busy_tx => open,
        o_tx => o_tx
    );
	 
	 
assign_rx_data : process(i_clk)
begin 
    if rising_edge(i_clk) then
        r_SM_no <= rx_datapacket(2 downto 0);
    end if;
end process assign_rx_data;

    tmp_proc_sw_state : process(i_clk) 
    -- Variable declaration
    variable v_init_strt : std_logic := '0';

    begin
        if rising_edge(i_clk) then
           -- r_SM_no <= rx_datapacket(2 downto 0);
            if v_init_strt = '0' or tx_done = '1' then
                v_init_strt := '1';
                tx_start <= '1'; -- Starting the transmission
            else
                tx_start <= '0';
            end if;
        end if;
    end process tmp_proc_sw_state;


-- =============================================== Debugging Processes ===============================================
set_leds : process(i_clk)
begin
    if rising_edge(i_clk) then
        o_led(2 downto 0) <= r_SM_no;
		  --o_led(9) <= r_strt_tx;
    end if;
end process set_leds;


end architecture rtl;
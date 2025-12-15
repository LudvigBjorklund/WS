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
        i_sw  : in std_logic_vector(9 downto 0);
        o_led : out unsigned(9 downto 0) := (others => '0');
        o_hex0, o_hex1, o_hex2, o_hex3, o_hex4, o_hex5 : out std_logic_vector(6 downto 0);
        o_tx  : out std_logic
    );
end entity DigitalTwin;


architecture rtl of DigitalTwin is

-- =========================================================================
-- ========================= Signal Declarations ===========================
-- ========================================================================= 

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


-- ======================
-- ECM Cell 
-- ======================

-- ==========================
-- ECM Parameters Lookup Signals
-- ==========================
signal r_SOC_init : unsigned(23 downto 0) := to_unsigned(100, 7) & to_unsigned(0, 17); -- Initial SOC value (Integer part only)
signal r_SOC      : unsigned(23 downto 0) := r_SOC_init; -- SOC value signal

signal r_I       : unsigned(15 downto 0) := c_hw_I; -- Current value signal
signal r_Q   : unsigned(n_b_Q-1 downto 0) := c_hw_Q;

-- Overwrite parameters signals
signal ow_R0 : unsigned(23 downto 0) := c_hw_ow_R0;
signal ow_a1 : unsigned(23 downto 0) := c_hw_ow_a1;
signal ow_c1 : unsigned(23 downto 0) := c_hw_ow_c1;
signal ow_a2 : unsigned(23 downto 0) := c_hw_ow_a2;
signal ow_c2 : unsigned(23 downto 0) := c_hw_ow_c2;

signal ow_v_ocv : unsigned(23 downto 0) := c_hw_ow_v_ocv; -- Overwrite OCV signal (1D LUT)

signal dV_R0    : unsigned(19 downto 0) := (others => '0');
signal dV_RC1   : unsigned(19 downto 0) := (others => '0');
signal dV_RC2   : unsigned(19 downto 0) := (others => '0');
signal V_ocv    : unsigned(19 downto 0) := (others => '0');



signal ecm_cell_o_extra : unsigned(31 downto 0);


-- ==========================
-- Debug Signals
-- ==========================
signal bcd_in  : unsigned(19 downto 0) := (others => '0');
signal bcd_out : unsigned(23 downto 0) := (others => '0');

signal hex0, hex1, hex2, hex3, hex4, hex5 : unsigned( 3 downto 0) := (others => '0');

begin

-- ==========================================================================
-- ============================ PROCESSES ===================================
-- ==========================================================================
sim_SM_inst : sim_SM
port map(
  i_clk       => i_clk,
  i_state_bin => r_SM_no,
  o_state     => r_state
);


-------- Interface
DT_UART_32bit_inst : DT_UART_32bit
 generic map(
	  g_clk_rate => c_clk_rate, -- CHANGE BEFORE SYNTHESIS
	  g_no_signals_rx => c_rx_no_sig,
	  g_no_signals_tx => c_tx_no_sim_sig, 
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

--
            
-- ==========================
-- ECM Cell Component Mapping
-- ==========================
ecm_cell_inst : ECM_Cell
  generic map(
		mif_R0 => "R0.mif",
		mif_a1 => "a1.mif",
		mif_c1 => "c1.mif",
		mif_a2 => "a2.mif",
		mif_c2 => "c2.mif",
		timestep => c_timestep,
		n_b_SOC => 24
  )
  port map(
		i_clk      => i_clk,
		i_state    => r_state,
		i_charging => '1',
		i_SOC0     => r_SOC_init,
		i_I        => r_I,
		i_Q        => r_Q, -- Not used in this testbench
		i_ow_R0    => ow_R0,
		i_ow_a1    => ow_a1,
		i_ow_c1    => ow_c1,
		i_ow_a2    => ow_a2,
		i_ow_c2    => ow_c2,

		i_ow_v_ocv => ow_v_ocv, -- Overwrite OCV

		o_SOC      => r_SOC(23 downto 8),
		o_extra    => ecm_cell_o_extra
  );


-- ==========================
-- Debug Components Mapping
-- ==========================
bcd_inst : bcd
 port map(
	  i_bin => bcd_in,
	  o_bcd => bcd_out
 );  



 hex0_inst : hex_digits 
 port map(
	  i_clk => i_clk,
	  i_bin => hex0,
	  o_hex => o_hex0
 );

  hex1_inst : hex_digits 
 port map(
	  i_clk => i_clk,
	  i_bin => hex1,
	  o_hex => o_hex1
 );

hex2_inst : hex_digits
    port map(
        i_clk => i_clk,
        i_bin => hex2,
        o_hex => o_hex2
    );
hex3_inst : hex_digits
    port map(
        i_clk => i_clk,
        i_bin => hex3,
        o_hex => o_hex3
    );
hex4_inst : hex_digits
    port map(
        i_clk => i_clk,
        i_bin => hex4,
        o_hex => o_hex4
    );
hex5_inst : hex_digits
    port map(
        i_clk => i_clk,
        i_bin => hex5,
        o_hex => o_hex5
    );
-- ==========================================================================
-- ============================ PROCESSES ===================================
-- ==========================================================================
assign_rx_data : process(i_clk)
variable v_initialization_done : std_logic := '0';
begin 
    if rising_edge(i_clk) then
        if v_initialization_done = '0' then
            v_initialization_done := '1';
            r_SM_no <= c_rx_init_datapacket(2 downto 0);
        else
            r_SM_no <= rx_datapacket(2 downto 0);
        end if;
    end if;
end process assign_rx_data;


-- ==================
-- Simulation State Process
-- ==================

simulation_process : process(i_clk)
begin
    if rising_edge(i_clk) then
        case r_state is
            when s_idle =>
                -- Do nothing
                null;
            when s_init =>
                -- Do nothing
                null;
            when s_verification =>
                -- Do nothing
                null;
            when s_sim =>
                null;
            when s_pause =>
                -- Do nothing
                null;
            when s_end =>
                -- Do nothing
                null;
            when s_reset =>
                -- Do nothing
                null;
            when others =>
                -- Do nothing
                null;
        end case;
    end if;
end process simulation_process;



tmp_proc_sw_state : process(i_clk) 
-- Variable declaration
variable v_init_strt : std_logic := '0';

begin
    if rising_edge(i_clk) then
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
    end if;
end process set_leds;

assign_extra_debug_to_voltage : process(i_clk)
begin
    if rising_edge(i_clk) then
        case ecm_cell_o_extra(23 downto 20) is
            when "0001" =>
                dV_R0 <= ecm_cell_o_extra(19 downto 0);
            when "0010" =>
                dV_RC1 <= ecm_cell_o_extra(19 downto 0);
            when "0011" =>
                dV_RC2 <= ecm_cell_o_extra(19 downto 0);
            when "0100" =>
                V_ocv <= ecm_cell_o_extra(19 downto 0);
            when "0000" =>
                null;
            when others =>
                null;
        end case;
    end if;
end process assign_extra_debug_to_voltage;



connect_bcd_input : process(i_clk)
begin
    if rising_edge(i_clk) then
        case i_sw(3 downto 0) is
            when "0000" =>
                bcd_in <= to_unsigned(0, 13) & r_SOC(23 downto 17);
                hex0 <= bcd_out(3 downto 0);
                hex1 <= bcd_out(7 downto 4);
                hex2 <= bcd_out(11 downto 8);
                hex3 <= (others => '1'); -- Blank SOC only uses 3 hex digits
                hex4 <= (others => '1');
                hex5 <= (others => '1');
            when "0001" =>
                bcd_in <= to_unsigned(0, 9) & dV_R0(19 downto 19-10);
                hex0 <= bcd_out(3 downto 0);
                hex1 <= bcd_out(7 downto 4);
                hex2 <= bcd_out(11 downto 8);
                hex3 <= bcd_out(15 downto 12);
                hex4 <= (others => '1');
                hex5 <= (others => '1');
            when "0010" =>
                bcd_in <= to_unsigned(0, 9) & dV_RC1(19 downto 19-10);
                hex0 <= bcd_out(3 downto 0);
                hex1 <= bcd_out(7 downto 4);
                hex2 <= bcd_out(11 downto 8);
                hex3 <= bcd_out(15 downto 12);
                hex4 <= (others => '1');
                hex5 <= (others => '1');
            when "0011" =>
                bcd_in <= to_unsigned(0, 9) & dV_RC2(19 downto 19-10);
                hex0 <= bcd_out(3 downto 0);
                hex1 <= bcd_out(7 downto 4);
                hex2 <= bcd_out(11 downto 8);
                hex3 <= bcd_out(15 downto 12);
                hex4 <= (others => '1');
                hex5 <= (others => '1');
            when "0100" =>
                bcd_in <= to_unsigned(0, 8) & V_ocv(19 downto 19-11);
                hex0 <= bcd_out(3 downto 0);
                hex1 <= bcd_out(7 downto 4);
                hex2 <= bcd_out(11 downto 8);
                hex3 <= bcd_out(15 downto 12);
                hex4 <= bcd_out(19 downto 16);
                hex5 <= (others => '1');
            when others =>
                bcd_in <= to_unsigned(0, bcd_in'length- r_SM_no'length) & r_SM_no;
        end case;
    end if;
end process connect_bcd_input;



end architecture rtl;
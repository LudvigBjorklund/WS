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
constant c_sim_step_wait_cycles : integer := 4*2; -- Number of clock cycles to wait between each simulation step pulse CHANGE BEFORE SYNTHESIS

signal r_sim_step_wait : integer range 0 to c_sim_step_wait_cycles := 0;
constant c_cycles_per_sim_second : integer := power_of_2(c_timestep);  -- Becomes 8
signal   r_sim_seconds_counter : integer range 0 to c_cycles_per_sim_second-1 := 0;


constant ID_SM : integer := 1;
constant ID_I  : integer := 2;
constant ID_SOC0 : integer := 3;
constant ID_Q    : integer := 4;
constant ID_pw_clk_cycles : integer := 5;
constant ID_pri_clk_cycles : integer := 6;

signal r_rx_assign_state : unsigned(3 downto 0) := (others => '0');
-- Second state of Assign RX data
constant ID_ow_R0 : integer := 2;
constant ID_ow_a1 : integer := 3;
constant ID_ow_c1 : integer := 4;
constant ID_ow_a2 : integer := 5;
constant ID_ow_c2 : integer := 6;



signal r_charge : std_logic := '0';
-- =========================================================================
-- ========================= Signal Declarations ===========================
-- ========================================================================= 

-- =========
-- Receiver
-- =========
signal rx_datapacket : unsigned((c_rx_no_sig * 24) - 1 downto 0) := c_rx_init_datapacket; 
signal changed_rx_assign_state : std_logic := '0';
signal prev_rx_assign_state : unsigned(3 downto 0) := (others => '0');
signal update_signal : std_logic_vector(c_rx_no_sig-1 downto 0) := (others => '0'); -- Indicates if each signal has been updated from previous value
-- =========
-- Transmitter
-- =========
constant c_tx_smpl_steps : integer := 434*10*6*(3+1)*3; -- Number of simulation steps between each transmission sample CHANGE BEFORE SYNTHESIS clk-rate*n_bits*n_bytes*n_signals*2 to ensure we sample all signals at the same time
signal tx_smpl_stp_cnt : integer range 0 to c_tx_smpl_steps-1 := 0; -- Simulation step counter for transmission sampling
signal tx_datapacket : unsigned((c_tx_no_sig * 32) - 1 downto 0) := c_tx_init_datapacket; 
signal tx_start : std_logic := '0';
signal tx_updated_signals : std_logic_vector(c_tx_no_ver_sig-1 downto 0) := (others => '1'); -- Indicates if each signal has been verified, only those which are changed need to be transmitted
signal tx_done : std_logic := '0'; -- To indicate that the DT_TX transmission is done

-- ======================
-- State Machine 
-- ======================
signal r_SM_no       : unsigned(2 downto 0) := (others => '0'); -- State machine number signal
signal r_state : t_state := s_idle; -- s_idle, s_init, s_verification, s_sim, s_pause, s_end, s_reset



-- Current Pulse Control Signals
signal I : unsigned(15 downto 0) := (others => '0');
signal pw_clk_cycles : unsigned(23 downto 0) := to_unsigned(60, 24);-- Pulse width in clock cycles
signal pw_on  : std_logic := '0';
signal pw_counter    : unsigned(23 downto 0) := (others => '0');-- Pulse width counter in clock cycles
signal pw_seconds    : unsigned(23 downto 0)  := (others => '0');-- Pulse width counter in seconds
signal pri_seconds   : unsigned(23 downto 0)  := (others => '0');-- Period counter in seconds
signal pri_clk_cycles : unsigned(23 downto 0) := to_unsigned(60, 24);-- Period in clock cycles (pulse repetition interval)
signal pri_counter    : unsigned(23 downto 0) := (others => '0');-- Period counter in clock cycless
signal zero_current : std_logic := '0';
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


-- ========================= ECM Output Signals ==========================
-- ======= Voltages ==========
signal dV_R0    : unsigned(23 downto 0) := (others => '0');
signal dV_RC1   : unsigned(23 downto 0) := (others => '0');
signal dV_RC2   : unsigned(23 downto 0) := (others => '0');
signal V_ocv    : unsigned(23 downto 0) := (others => '0');
-- ======= ECM Paraemeters =========
signal r_R0     : unsigned(15 downto 0) := (others => '0');


signal ecm_cell_o_extra : unsigned(31 downto 0);
-- Simulation Time Signals
signal r_tsim : unsigned(23 downto 0) := (others => '0');
-- Simulation Time 
signal r_seconds : unsigned(5 downto 0) := (others => '0');
signal r_minutes : unsigned(5 downto 0) := (others => '0');
signal r_hours   : unsigned(5 downto 0) := (others => '0');



signal previous_rx_dp : unsigned(((c_rx_no_sig - 1) * 24) - 1 downto 0) := (others => '0');
signal setting_first_state  : std_logic := '0';
signal setting_second_state : std_logic := '0';
-- ==========================
-- Debug Signals
-- ==========================
signal bcd_in  : unsigned(19 downto 0) := (others => '0');
signal bcd_out : unsigned(23 downto 0) := (others => '0');
signal hex0, hex1, hex2, hex3, hex4, hex5 : unsigned( 3 downto 0) := (others => '0');
signal clock_bcd_select : integer range 0 to 2 := 0;
signal hex_ss0, hex_ss1, hex_mm0, hex_mm1, hex_hh0, hex_hh1 : unsigned(3 downto 0) := (others => '0');

signal dV_assign_debug : unsigned(3 downto 0) := (others => '0');


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


-- ========================== UART Component Mapping ==========================

-------- Interface
DT_UART_32bit_inst : DT_UART_32bit
 generic map(
	  g_clk_rate => 4, -- CHANGE BEFORE SYNTHESIS
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
ecm_cell_inst : ECM_Cell_sim
  generic map(
		mif_R0 => "R0.mif",
		mif_a1 => "a1.mif",
		mif_c1 => "c1.mif",
		mif_a2 => "a2.mif",
		mif_c2 => "c2.mif",
		timestep => c_timestep,
        timestep_wait_cycles => c_sim_step_wait_cycles, -- CHANGE BEFORE SYNTHESIS
		n_b_SOC => 24
  )
  port map(
		i_clk      => i_clk,
		i_state    => r_state,
		i_charging => r_charge, -- 0 Not Charging<
		i_SOC0     => r_SOC_init,
		i_I        => I,
		i_Q        => r_Q, -- Not used in this testbench
		i_ow_R0    => ow_R0,
		i_ow_a1    => ow_a1,
		i_ow_c1    => ow_c1,
		i_ow_a2    => ow_a2,
		i_ow_c2    => ow_c2,

		i_ow_v_ocv => ow_v_ocv, -- Overwrite OCV

		o_SOC      => r_SOC,
		o_t_sim    => r_tsim,
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


sim_clock_process : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if r_state = s_sim then
                if r_sim_step_wait < c_sim_step_wait_cycles then
                    r_sim_step_wait <= r_sim_step_wait + 1;
                else
                    r_sim_step_wait <= 0;
                    -- When r_tsim reaches c_cycles_per_sim_second, increment simulation time by one second (r_sim_seconds_counter)    
                    if r_sim_seconds_counter < c_cycles_per_sim_second-1 then
                        r_sim_seconds_counter <= r_sim_seconds_counter + 1;
                    else
                        r_sim_seconds_counter <= 0;
                        if pw_on = '1' then
                            I <= r_I;
                            if pw_seconds < pw_clk_cycles then
                                pw_seconds <= pw_seconds + 1;
                            else
                                pw_seconds <= (others => '0');
                                pw_on <= '0';
                            end if;
                        else
                            -- PRI Counter  
                            I <= (others => '0');
                            if pri_seconds < pri_clk_cycles then
                                pri_seconds <= pri_seconds + 1;
                            else
                                pri_seconds <= (others => '0');
                                pw_on <= '1';
                            end if;
                        end if;
                        -- One second has passed in simulation time
                        if r_seconds < 59 then
                            r_seconds <= r_seconds + 1;
                        else
                            r_seconds <= (others => '0');
                            
                            if r_minutes < 59 then
                                r_minutes <= r_minutes + 1;
                            else
                                r_minutes <= (others => '0');
                                if r_hours < 23 then
                                    r_hours <= r_hours + 1;
                                else
                                    r_hours <= (others => '0')  ;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
            else 
                I <= r_I;
            end if;
        end if;
end process sim_clock_process;


-- ========================== Control Update Signals Process ==========================
control_update_signals : process(i_clk)
    variable v_initialization_done : std_logic := '0';

    begin
        if rising_edge(i_clk) then


            if v_initialization_done = '0' then
                v_initialization_done := '1';
                r_SM_no <= c_rx_init_datapacket(2 downto 0);
            else
                    r_SM_no <= rx_datapacket(2 downto 0);
                    r_rx_assign_state <= rx_datapacket(7 downto 4);
                    if r_rx_assign_state = "0000" then
                        if rx_datapacket(rx_datapacket'left downto 24) /= previous_rx_dp then
                            previous_rx_dp <= rx_datapacket(rx_datapacket'left downto 24);
                            setting_first_state <= '1';
                            setting_second_state <= '0';
                        else 
                            null;
                        end if;
                    end if;
                    if r_rx_assign_state = "0001" then
                        if rx_datapacket(rx_datapacket'left downto 24) /= previous_rx_dp then
                            previous_rx_dp <= rx_datapacket(rx_datapacket'left downto 24);
                            setting_first_state <= '0';
                            setting_second_state <= '1';
                        end if;
                    end if;
                
                end if;

            if rx_datapacket(7 downto 4) /= prev_rx_assign_state then
                prev_rx_assign_state <= rx_datapacket(7 downto 4);
                -- Reset update signals when RX assign state changes
                update_signal <= (others => '0'); 
            else
                if rx_datapacket(47 downto 24) /= previous_rx_dp(23 downto 0) then
                    update_signal(0) <= '1';
                elsif rx_datapacket(71 downto 48) /= previous_rx_dp(47 downto 24) then
                    update_signal(1) <= '1';
                elsif rx_datapacket(95 downto 72) /= previous_rx_dp(71 downto 48) then
                    update_signal(2) <= '1';
                elsif rx_datapacket(119 downto 96) /= previous_rx_dp(95 downto 72) then
                    update_signal(3) <= '1';
                elsif rx_datapacket(143 downto 120) /= previous_rx_dp(119 downto 96) then
                    update_signal(4) <= '1';
                else
                    null;
                end if;
            end if;

        end if;
end process control_update_signals;

-- ========================== RX Data Assignment Process ==========================
assign_rx_data : process(i_clk)
begin 
    if rising_edge(i_clk) then

        case r_rx_assign_state is
            -- ========== State 0 : Basic Parameters ==========
            when "0000" =>
                case r_state is
                    when s_idle =>
                        -- Still Require Access to change Simulator State 
                        -- Reset to hardware values
                        r_Q     <= c_hw_Q;
                        r_I     <= c_hw_I;
                        r_SOC_init <= c_hw_SOC0;

                    when s_init =>
                        if update_signal(0) = '1' then
                            r_I         <= rx_datapacket(ID_I*24-1-(24-n_b_I) downto (ID_I-1)*24);
                        end if;
                        if update_signal(1) = '1' then
                            r_SOC_init  <= rx_datapacket(ID_SOC0*24-1-(24-n_b_SOC0) downto (ID_SOC0-1)*24);
                        end if;
                        if update_signal(2) = '1' then
                            r_Q         <= rx_datapacket(ID_Q*24-1-(24-n_b_Q) downto (ID_Q-1)*24);
                        end if;
                    when s_verification =>
                        null;
                    when s_sim =>
                        null;
                        if update_signal(0) = '1' then
                            r_I         <= rx_datapacket(ID_I*24-1-(24-n_b_I) downto (ID_I-1)*24);
                        end if;
                        if update_signal(ID_pw_clk_cycles-2) = '1' then
                            pw_clk_cycles <= rx_datapacket(ID_pw_clk_cycles*24-1 downto (ID_pw_clk_cycles-1)*24);
                        end if;
                    when others =>
                        null;
                end case;
            -- ========== State 1 : Overwrite Parameters ==========
            when "0001" =>
                case r_state is 

                    when s_idle =>
                        null;
                    when s_init =>
                        if setting_second_state = '0' then
                            null; -- We wait for a complete update of the UART data packet 
                        else
                            if update_signal(ID_ow_R0-2) = '1' then
                                ow_R0        <= rx_datapacket(ID_ow_R0*24-1 downto (ID_ow_R0-1)*24);
                            end if;
                            if update_signal(ID_ow_a1-2) = '1' then
                                ow_a1        <= rx_datapacket(ID_ow_a1*24-1 downto (ID_ow_a1-1)*24);
                            end if;
                            if update_signal(ID_ow_c1-2) = '1' then
                                ow_c1        <= rx_datapacket(ID_ow_c1*24-1 downto (ID_ow_c1-1)*24);
                            end if;
                            if update_signal(ID_ow_a2-2) = '1' then
                                ow_a2        <= rx_datapacket(ID_ow_a2*24-1 downto (ID_ow_a2-1)*24);
                            end if;
                            if update_signal(ID_ow_c2-2) = '1' then
                                ow_c2        <= rx_datapacket(ID_ow_c2*24-1 downto (ID_ow_c2-1)*24);
                            end if;
                        end if;
                    when s_verification =>
                        null;
                    when s_sim =>
                        null;
                    when others =>
                        null;
                end case;
            

            when others =>
               null;
        end case;
    end if;
end process assign_rx_data;


-- ========================== TX Data Assignment Process ==========================
assign_tx_data : process(i_clk)
begin
    if rising_edge(i_clk) then

       -- Case 1 : State_of_Charge and Voltages   
        case r_state is
            when s_idle =>
                -- Do nothing
                      -- Do nothing
                if tx_smpl_stp_cnt = c_tx_smpl_steps-1 then
                    tx_smpl_stp_cnt <= 0;
                    tx_datapacket(31 downto 0) <= to_unsigned(1, 8) & r_tsim;
                    -- For now we only transmit SOC in all 4*32 bits
                    tx_datapacket(63 downto 32) <= to_unsigned(ID_SOC0, 8) & r_SOC;
                    tx_datapacket(95 downto 64) <= to_unsigned(4, 8) & dV_R0 ;
                    tx_datapacket(127 downto 96) <=  to_unsigned(1, 8) & r_tsim;
                else
                    tx_smpl_stp_cnt <= tx_smpl_stp_cnt + 1;
                end if;

				 when s_init =>
                   -- Do nothing
                if tx_smpl_stp_cnt = c_tx_smpl_steps-1 then
                    tx_smpl_stp_cnt <= 0;
                    tx_datapacket(31 downto 0) <= to_unsigned(1, 8) & r_tsim;
                    -- For now we only transmit SOC in all 4*32 bits
                    tx_datapacket(63 downto 32) <= to_unsigned(ID_SOC0, 8) & r_SOC;
                    tx_datapacket(95 downto 64) <= to_unsigned(4, 8) & dV_R0 ;
                    tx_datapacket(127 downto 96) <=  to_unsigned(1, 8) & r_tsim;
                else
                    tx_smpl_stp_cnt <= tx_smpl_stp_cnt + 1;
                end if;

            when s_verification =>
                -- Do nothing
                null;
            when s_sim =>
                -- 32 lowest bits tx_id_1 (8 bits) + tx_data_1 (24 bits) (State of charge)
                        -- Do nothing
                if tx_smpl_stp_cnt = c_tx_smpl_steps-1 then
                    tx_smpl_stp_cnt <= 0;
                    tx_datapacket(31 downto 0) <= to_unsigned(1, 8) & r_tsim;
                    -- For now we only transmit SOC in all 4*32 bits
                    tx_datapacket(63 downto 32) <= to_unsigned(ID_SOC0, 8) & r_SOC;
                    tx_datapacket(95 downto 64) <= to_unsigned(4, 8) & dV_R0 ;
                    tx_datapacket(127 downto 96) <=  to_unsigned(1, 8) & r_tsim;
                else
                    tx_smpl_stp_cnt <= tx_smpl_stp_cnt + 1;
                end if;

                
            when others =>
                -- Do nothing
                null;
        end case;
    end if;
end process assign_tx_data;




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
    end if;
end process set_leds;

assign_extra_debug_to_voltage : process(i_clk)
begin
    if rising_edge(i_clk) then
        case ecm_cell_o_extra(31 downto 28) is
            when "0001" =>
                dV_assign_debug <= "0001";
                dV_R0 <= ecm_cell_o_extra(27 downto 4);
            when "0010" =>
                dV_assign_debug <= "0010";
                dV_RC1 <=ecm_cell_o_extra(27 downto 4);
            when "0011" =>
                dV_assign_debug <= "0011";
                dV_RC2 <=ecm_cell_o_extra(27 downto 4);
            when "0100" =>
                dV_assign_debug <= "0100";
                V_ocv <= ecm_cell_o_extra(27 downto 4);
            when "0101" =>
                r_R0 <= ecm_cell_o_extra(15 downto 0);
                
            when "0000" =>
                null;
            when others =>
                null;
        end case;
    end if;
end process assign_extra_debug_to_voltage;


connect_bcd_input : process(i_clk)
variable v_init_strt : std_logic := '0';
begin
    if rising_edge(i_clk) then
        case r_state is
            when s_init =>
                case i_sw(3 downto 0) is
                    when "0000" =>
                        bcd_in <= to_unsigned(0, 13) & r_SOC_init(23 downto 17);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= (others => '1'); -- Blank SOC only uses 3 hex digits
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0001" =>
                        bcd_in <= to_unsigned(0, 8) & dV_R0(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0010" =>
                        bcd_in <= to_unsigned(0, 8) & dV_RC1(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0011" =>
                        bcd_in <= to_unsigned(0, 8) & dV_RC2(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0100" =>
                        bcd_in <= to_unsigned(0, 8) & V_ocv(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= bcd_out(19 downto 16);
                    when "0101" => -- Current (4 MSBs , so only need 2 hex digits)
                        bcd_in <= to_unsigned(0, 16) & I(15 downto 12);
                       -- o_led(9 downto 3) <= I(11 downto 5); -- Display some of the current value on the LEDs
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= (others => '1');
                        hex3 <= (others => '1');
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
					when "0110" => -- Current (4 MSBs , so only need 2 hex digits)
                        bcd_in <= to_unsigned(0, 16) & r_I(15 downto 12);
                       -- o_led(9 downto 3) <= r_I(11 downto 5); -- Display some of the current value on the LEDs
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= (others => '1');
                        hex3 <= (others => '1');
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                                        when "1000" => 

                        -- Start a loop that first inputs seconds, then minutes, then hours to bcd_in,
                        if clock_bcd_select = 0 then
                            bcd_in <= to_unsigned(0, 14) & r_seconds(5 downto 0);
                            clock_bcd_select <= 1;
                            -- If initialized once
                            if v_init_strt = '1' then
                                hex_hh0 <= bcd_out(3 downto 0);
                                hex_hh1 <= bcd_out(7 downto 4);
                            else
                                v_init_strt := '1';
                            end if;
                        elsif clock_bcd_select = 1 then
                            bcd_in <= to_unsigned(0, 14) & r_minutes(5 downto 0);
                            clock_bcd_select <= 2;
                            hex_ss0 <= bcd_out(3 downto 0);
                            hex_ss1 <= bcd_out(7 downto 4);
                        else
                            bcd_in <= to_unsigned(0, 14) & r_hours(5 downto 0);
                            clock_bcd_select <= 0;
                            hex_mm0 <= bcd_out(3 downto 0);
                            hex_mm1 <= bcd_out(7 downto 4);
                        end if;
                        
                    when others =>
                        bcd_in <= to_unsigned(0, bcd_in'length- r_SM_no'length) & r_SM_no;
                end case;
            when others => 
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
                        bcd_in <= to_unsigned(0, 8) & dV_R0(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0010" =>
                        bcd_in <= to_unsigned(0, 8) & dV_RC1(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0011" =>
                        bcd_in <= to_unsigned(0, 8) & dV_RC2(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0100" =>
                        bcd_in <= to_unsigned(0, 8) & V_ocv(23 downto 12);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= bcd_out(19 downto 16);
                        hex5 <= (others => '1');
                    when "0101" => -- Current (4 MSBs , so only need 2 hex digits)
                        bcd_in <= to_unsigned(0, 16) & I(15 downto 12);
                      --  o_led(9 downto 3) <= I(11 downto 5); -- Display some of the current value on the LEDs
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= (others => '1');
                        hex3 <= (others => '1');
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0110" => -- Current (4 MSBs , so only need 2 hex digits)
                        bcd_in <= to_unsigned(0, 16) & r_I(15 downto 12);
                        --o_led(9 downto 3) <= r_I(11 downto 5); -- Display some of the current value on the LEDs
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= (others => '1');
                        hex3 <= (others => '1');
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when "0111" => 
                        bcd_in <= r_tsim(19 downto 0);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= bcd_out(15 downto 12);
                        hex4 <= bcd_out(19 downto 16);
                        hex5 <= bcd_out(23 downto 20);
                    when "1000" => 

                        -- Start a loop that first inputs seconds, then minutes, then hours to bcd_in,
                        if clock_bcd_select = 0 then
                            bcd_in <= to_unsigned(0, 14) & r_seconds(5 downto 0);
                            clock_bcd_select <= 1;
                            -- If initialized once
                            if v_init_strt = '1' then
                                hex_hh0 <= bcd_out(3 downto 0);
                                hex_hh1 <= bcd_out(7 downto 4);
                            else
                                v_init_strt := '1';
                            end if;
                        elsif clock_bcd_select = 1 then
                            bcd_in <= to_unsigned(0, 14) & r_minutes(5 downto 0);
                            clock_bcd_select <= 2;
                            hex_ss0 <= bcd_out(3 downto 0);
                            hex_ss1 <= bcd_out(7 downto 4);
                        else
                            bcd_in <= to_unsigned(0, 14) & r_hours(5 downto 0);
                            clock_bcd_select <= 0;
                            hex_mm0 <= bcd_out(3 downto 0);
                            hex_mm1 <= bcd_out(7 downto 4);
                        end if;
                        hex0 <= hex_ss0;
                        hex1 <= hex_ss1;
                        hex2 <= hex_mm0;
                        hex3 <= hex_mm1;
                        hex4 <= hex_hh0;
                        hex5 <= hex_hh1;
                        

                    when "1001" =>
                        bcd_in <= to_unsigned(0,12) & r_R0(15 downto 8);
                        hex0 <= bcd_out(3 downto 0);
                        hex1 <= bcd_out(7 downto 4);
                        hex2 <= bcd_out(11 downto 8);
                        hex3 <= (others => '1');
                        hex4 <= (others => '1');
                        hex5 <= (others => '1');
                    when others =>
                        bcd_in <= to_unsigned(0, bcd_in'length- r_SM_no'length) & r_SM_no;
                end case;
            end case;
    end if;
end process connect_bcd_input;

       
       
    

end architecture rtl;
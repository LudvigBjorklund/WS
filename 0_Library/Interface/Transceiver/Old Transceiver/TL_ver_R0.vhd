library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common.all; -- ✅ Import the shared package


entity TL_ver is 
    port(
        i_clk       : in std_logic;
        i_rx        : in std_logic; -- The received data
		  i_key		  : in std_logic_vector(3 downto 0);
        i_sw        : in unsigned(9 downto 0); -- Switches for debugging
        o_led       : out unsigned(9 downto 0); -- For debugging
        o_hex0, o_hex1, o_hex2, o_hex3, o_hex4, o_hex5 : out std_logic_vector(6 downto 0); -- For debugging
        o_tx        : out std_logic -- Output data to PC
    );
end entity TL_ver;

architecture rtl of TL_ver is
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------- Component Declaration ------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type lut_16bit_2d is array (0 to 15, 0 to 10) of unsigned(15 downto 0);

-------- Digital Twin Model Components Normalizer and LUT

-- Allow the use of the VHDL-2008 standard
component ECM_Parameters is
    generic(
        init_file_R0 : string := "R0_tbl_int.mif";
        init_file_R1 : string := "R0_tbl_frac.mif"
    );
    port(
        i_clk       : in std_logic;
        i_state     : in unsigned(2 downto 0); 
        i_rst_tbl1  : in lut_16bit_2d; --  Used for resetting table 1
        i_dbg_idx	  : in unsigned(7 downto 0);  -- Connect the inputs to 4b row idx and 4b col idx directly
        i_ow_tbl1   : in unsigned(23 downto 0); --  Used for overwriting table 1 4MSB row index [0,15] | 4MSB col index [0,15] | 8MSB new value int | 8MSB new value frac
        i_SOC       : in unsigned(23 downto 0);
        i_I         : in unsigned(22 downto 0);
        o_RO        : out unsigned(23 downto 0)
    );
end component ECM_Parameters;


component dV_RC is
    generic(
        g_dbg_threshold : integer := 100000000 -- The update rate for debugging, clock cycles<
    );
    port(
        i_clk : in std_logic;
        i_strt : in std_logic;
        i_dbg : in std_logic; -- Used to count 1 step of the action
        i_c1    : in unsigned(47 downto 0);
        i_a1    : in unsigned(23 downto 0);
        i_I     : in unsigned(23 downto 0);
        o_dV    : out unsigned(87 downto 0)
        --o_led : out unsigned(9 downto 0) ONLY FOR DEBUGGING
    );
end component dV_RC;
----------------------------------------------------------------------- Model Components -----------------------------------------------------------------------
----------------------------------------------------------------------- Simulation Platform Components -----------------------------------------------------------------------

-- Simulation Clock Signal
component sim_clock is
    generic(
        cycles_per_simulation_iteration : in integer := 6 -- Number of cycles per simulation iteration
    );
    port(
        i_clk      : in std_logic; -- Input clock signal
        i_strt     : in std_logic; -- Input start signal
        o_sim_clk  : out unsigned(23 downto 0) -- Output simulated clock signal
    );
end component sim_clock;

-- State Machine Transitions
component sim_state_machine is
    port(
        i_clk    : in std_logic;
        r_state  : in unsigned(2 downto 0);
        state    : out t_state
    );
end component sim_state_machine;


----------------------------------------------------------------------- Simulation Platform Components -----------------------------------------------------------------------

component Transceiver is
    generic(
        g_clks_per_bit  : integer := 434; -- Clock cycles per bit
        g_wd_data : integer := 24; -- Signal width | Including the ID bits
        g_wd_ID   : integer := 8; -- Number of bits for the ID
        g_no_signals: integer := 5; -- Number of signals to be transmitted
        g_delay     : integer := 1000; -- Delay for transmission
        g_smpl_f  : integer := 50000 -- Sampling frequency
    );
    port (
        i_clk       : in std_logic;
        i_strt      : in std_logic; -- Start signal to begin transmission
        i_dp_ver    : in unsigned(g_wd_data+g_wd_ID-1 downto 0); -- The verification signal | 32 bits| includes the ID bits
        i_tx_IDs    : in unsigned(g_no_signals*g_wd_ID-1 downto 0); -- IDs for the signals
        i_dp_normal : in unsigned(g_no_signals*(g_wd_data)-1 downto 0); -- The concatenated signals for the sampler
        o_tx_busy  : out std_logic; -- UART busy signal
        o_tx_ver    : out std_logic; -- UART serial data output for verification
        o_tx_normal : out std_logic -- UART serial data output for normal data
    );
end component Transceiver;

-- Receiver component
component rx_32bit is
    generic(
        g_clks_per_bit  : integer := 434;  -- Clock cycles per UART bit (baud rate)
        g_clks_per_byte : integer := 4340  -- Clock cycles per UART byte
    );
    port(
        i_clk  : in  std_logic;           -- Clock input
        i_rx   : in  std_logic;           -- Serial input data
        o_data : out unsigned(31 downto 0); -- Output 32-bit data
        o_flg  : out std_logic            -- Reception complete flag
    );
end component rx_32bit;

component rx_signal_router is
    generic(
     n_signals : integer := 5; -- Number of signals
     n_bits_sig : integer := 24; -- Number of bits in the signal
     n_bits_id : integer := 8; -- Number of bits in the ID
     g_wd : integer := 32
     );
    port(
     i_clk : in std_logic;
     i_data : in unsigned(n_bits_sig+n_bits_id-1 downto 0); -- The n-bit data packet received from the UART (Receiver component rx32bit)
     i_busy_rx : in std_logic; -- Added missing signal
     o_dbg     : out unsigned(7 downto 0); -- Debug output
     o_sig : out unsigned(n_signals*n_bits_sig-1 downto 0) -- Concatenated signals
     );
end component rx_signal_router;

----------------------------------------------------------------------- Debugging Components ---------------------------------------------------------------------------------
component bcd    
    generic(
    g_bin_width : integer := 20 -- Default binary input width
        );
    port(
        i_bin : in  unsigned(g_bin_width-1 downto 0); -- Binary input of generic width
        o_bcd : out unsigned(g_bin_width + 3 downto 0) -- BCD output width
    );
end component bcd;

-- 7-segment display component calculates the 7-segment display value based on the binary input
component hex_digits is 
    port(
        i_bin : in unsigned(3 downto 0); -- 4-bit binary input
        o_hex : out std_logic_vector(6 downto 0) -- 7-segment display output
    );
end component hex_digits;

----------------------------------------------------------------------- Debugging Components ---------------------------------------------------------------------------------


------------------------------------------------------------------------ Generic Settings -----------------------------------------------------------------------------------

constant c_wd_ID        : integer := 8; -- Width of the ID

----------------- UART Interface Settings
constant c_wd_tx_dp      : integer := 24;      -- The width of the transmission data
constant c_wd_tx_ver    : integer := 24; -- Width of the verification data to be sent to the PC

constant c_n_tx_var     : integer := 3; -- Number of verification variables to be sent to the PC
constant c_n_rx_var     : integer := 4; -- Number of verification variables potentially received from the PC

signal cnt_ver_signal : integer range 1 to c_n_rx_var := 1; -- Counter for the verification signal | Looks at the changed varaibles 

constant c_tx_sampling_f : integer := 1000000; -- Sampling frequency every 500000 clock cycles ~ 0.1s with 20 ns per cycle
constant c_clk_cycle : integer := 434; -- Clock cycles before the transmission starts | 434 cycles for the baudrate of 115200


constant c_rx_wd : integer := 24; -- The width of the received data excluding the ID
constant c_rx_ID_wd : integer := 8; -- The width of the ID

signal r_rx_concat_sig : unsigned(c_n_rx_var*c_rx_wd-1 downto 0) := (others => '0'); -- Concatenated signals | Output from the signal router
signal r_rx_dp         : unsigned(c_rx_wd+c_rx_ID_wd-1 downto 0) := (others => '0'); -- The received data packet | 32 bits | includes the ID bits
signal r_rx_busy       : std_logic := '0'; -- The busy signal for the receiver
constant c_only_zeros  : unsigned(c_rx_wd -1 downto 0) := (others =>'0'); -- The signal for the receiver to check if the data stored in the register is all zeros 
-- Boolean debugs
constant c_dbg_dVRC1: std_logic := '1'; -- Debug signal for the voltage drop across the RC circuit (1)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------- Signal Declaration -----------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------- Simulation Platform Signals --------------------------------------------------------------------------
signal r_sim_clk    : unsigned(23 downto 0) := (others => '0');         -- The simulation clock signal from the simulation clock component
signal r_sim_strt   : std_logic := '0';                                 -- The start signal for the simulation clock
signal r_smpl_cnt   : integer range 0 to 500000;                        -- Sample every 50000 cycles ~ 0.01s with 20 ns per cycle

signal state : t_state := s_idle;                                       -- The state type is saved in the Package
signal r_state  : unsigned(2 downto 0) := (others => '0');              -- The state of the simulation state machine in binary

----------------------------------------------------------------------- Simulation Platform Signals --------------------------------------------------------------------------
----------------------------------------------------------------------- Digital Twin Model Signals ---------------------------------------------------------------------------
---- Initialization values
constant c_I_init   : unsigned(23 downto 0) := "001011000000000000000000"; -- The current value to be normalized | signed 6EN18 | [0, 15.9999847412109375] Default value = 5.5A
constant c_SOC_init : unsigned(23 downto 0) := "110001000000000000000000"; -- The SOC value to be normalized | 7EN20 | [0, 100] Default value = 100%


----------------------------------------------------------------------- Equivalent Circuit Model -----------------------------------------------------------------------------
signal r_I   : unsigned(23 downto 0) := c_I_init; -- The current value to be normalized | signed 6EN18 | [0, 15.9999847412109375] Default value = 5.5A
signal r_SOC : unsigned(23 downto 0) := c_SOC_init;--;"110010000000000000000000"; -- The SOC value to be normalized | 7EN20 | [0, 100] Default value = 100%



----------- Verification Transmission
signal cnt_verification_loop : integer range 0 to c_n_rx_var-1 +1 := 0; -- Counter for the verification transmission loop | Trasmitting all changed variables | looping over the tables
signal r_tx_ver_strt : std_logic := '0'; -- Start signal for the transmission
signal r_tx_ver_busy : std_logic := '0'; -- Busy signal for the transmission
signal r_tx_ver_o   : std_logic := '0'; -- Output signal for the transmission
------------ Resistance R0 -----------------------------------------------------------------------
constant str_R0_tbl1 : string :="R0_tbl_int.mif";
constant str_R0_tbl2 : string :="R0_tbl_frac.mif";
signal 	r_newval_R0 		: unsigned(23 downto 0) := (others => '1'); -- Signal for updating the R0 table
signal 	r_R0 : unsigned(23 downto 0);  -- The value (mOhm) for the internal resistance of the battery
-- Default/Reset values --------------------------------------------------------------------------
constant r_R0tbl : lut_16bit_2d := (
    ("0111111100000000", "0011001000000000", "0010001100000000", "0001100100000000", "0001000100000000", "0000111100000000", "0000111000000000", "0000110100000000", "0000110010000000", "0000101100000000", "0000100100000000"),
    ("0111110100000000", "0010100000000000", "0001101100000000", "0001010000000000", "0001000000000000", "0000111000000000", "0000110000000000", "0000101100000000", "0000101000000000", "0000100100000000", "0000100000000000"),
    ("0111101100000000", "0010000000000000", "0001100000000000", "0001001100000000", "0000111100000000", "0000110100000000", "0000101100000000", "0000101000000000", "0000100110000000", "0000100010000000", "0000011110000000"),
    ("0111100000000000", "0001100100000000", "0001011000000000", "0001001000000000", "0000111000000000", "0000110000000000", "0000101010000000", "0000100110000000", "0000100010000000", "0000011100000000", "0000011000000000"),
    ("0110111000000000", "0001010000000000", "0001001000000000", "0001000100000000", "0000110100000000", "0000101100000000", "0000101000000000", "0000100100000000", "0000011111000000", "0000011011000000", "0000010110000000"),
    ("0101111100000000", "0001000100000000", "0000111100000000", "0000111000000000", "0000110000000000", "0000101000000000", "0000100100000000", "0000100000000000", "0000011101000000", "0000011010000000", "0000010101000000"),
    ("0101000000000000", "0001000000000000", "0000111000000000", "0000110100000000", "0000101100000000", "0000100100000000", "0000100000000000", "0000011110000000", "0000011100000000", "0000011001000000", "0000010100100000"),
    ("0100011100000000", "0000111100000000", "0000110100000000", "0000110000000000", "0000101000000000", "0000011110000000", "0000011011000000", "0000011010000000", "0000011001000000", "0000011000000000", "0000010100000000"),
    ("0011111100000000", "0000111000000000", "0000110000000000", "0000101000000000", "0000100101000000", "0000011000000000", "0000010111000000", "0000010110000000", "0000010101100000", "0000010100100000", "0000010011100110"),
    ("0011011000000000", "0000110100000000", "0000101100000000", "0000100110000000", "0000100100000000", "0000010100000000", "0000010011000000", "0000010010000000", "0000010001000000", "0000010000100000", "0000010000000000"),
    ("0010111100000000", "0000110010000000", "0000101010000000", "0000100100000000", "0000100000000000", "0000010010000000", "0000010001100000", "0000010001000000", "0000010000100110", "0000010000000000", "0000001111100000"),
    ("0010100100000000", "0000110000000000", "0000101000000000", "0000100000000000", "0000011100000000", "0000010000000000", "0000001111100000", "0000001111000000", "0000001110100000", "0000001110000000", "0000001101100110"),
    ("0010010000000000", "0000101100000000", "0000100110000000", "0000011110000000", "0000011000000000", "0000001111000000", "0000001110000000", "0000001101100000", "0000001100100000", "0000001100000000", "0000001011100110"),
    ("0010000100000000", "0000101000000000", "0000100100000000", "0000011100000000", "0000010110000000", "0000001101000000", "0000001100100000", "0000001100000000", "0000001011100110", "0000001011100001", "0000001011001100"),
    ("0001111000000000", "0000100100000000", "0000100010000000", "0000011010000000", "0000010100000000", "0000001100000000", "0000001011001100", "0000001011000000", "0000001010110011", "0000001010101011", "0000001010011001"),
    ("0001110000000000", "0000011100000000", "0000011011001100", "0000011001001100", "0000010011100110", "0000001011000000", "0000001010011001", "0000001010001100", "0000001010000000", "0000001001110011", "0000001001100110")
);


signal r_SOC_col   : unsigned(23 downto 0) := (others => '0'); -- The normalized SOC value [0, 100] => [0, 10.99]
signal r_I_row     : unsigned(23 downto 0) := (others => '0'); -- The normalized current value
signal r_loop_row  : integer range 0 to 15 := 0; -- The row of the R0 table
signal r_loop_col  : integer range 0 to 10 := 0; -- The column of the R0 table

signal r_R0_new_val : unsigned(23 downto 0) := to_unsigned(0,8) & r_R0tbl(0,0);
signal r_R0_rowidx : unsigned(23 downto 0) := (others => '0'); -- | The input to the LUT_2D component | case_1 : the output from the Current_Normalizer_inst | case_2 "verification" : Set by the loop in s_verification | case_3 "debug" : Set by the switches (7 downto 4)
signal r_R0_colidx : unsigned(23 downto 0) := (others => '0'); -- | The input to the LUT_2D component | case_1 : the output from the SOC_Normalizer_inst          | case_2 "verification" : Set by the loop in s_verification | case_3 "debug" : Set by the switches (3 downto 0)


-- IDs for the reception and for the verification
constant c_ID_rx_state : integer := 1; -- ID for the state
constant c_ID_rx_I     : integer := 2; -- ID for the current
constant c_ID_rx_SOC   : integer := 3; -- ID for the SOC
constant c_ID_rx_R0    : integer := 4; -- ID for the R0 verification

-------------- IDs for the online transmission 
constant c_ID_tx_state  : integer := 1;
constant c_ID_tx_I		: integer := 2; 
constant c_ID_tx_SOC    : integer := 3;
constant c_ID_tx_R0     : integer := 4; -- ID for the R0 verification
-- Concatenated IDs for the online transmission n_tx_var*8 bits
constant c_ID_tx_cnct : unsigned(c_n_tx_var*c_wd_ID -1 downto 0):= to_unsigned(c_ID_tx_R0, c_wd_ID) & to_unsigned(c_ID_tx_SOC, c_wd_ID) & to_unsigned(c_ID_tx_state, c_wd_ID); -- ID for the connection


-- Signal for tracking the changed variables
signal r_rx_change_tracker : unsigned(c_n_rx_var downto 0) := (others => '0'); -- The signal for tracking the changed variables


signal current_tx_sent : signed(c_n_rx_var downto 0) := (others => '0'); -- The current transmission sent

------ The verification data to be sent to the PC
signal r_tx_ver_dp : unsigned((c_wd_tx_ver+c_wd_ID)-1 downto 0) := (others => '0'); -- The verification data to be sent to the PC
signal r_tx_cnct_for_sampler_dp : unsigned((c_wd_tx_ver)*c_n_tx_var-1 downto 0) := (others => '0'); -- The concatenated data to be sampled
signal r_tx_normal : std_logic := '0'; -- The output data to be transmitted to the PC

-- Debugging signals 
signal r_bcd_i : unsigned(19 downto 0) := (others => '0'); -- The input for the BCD component
signal r_bcd_o : unsigned(23 downto 0) := (others => '0'); -- The output for the BCD component
signal r_sel_hex_disp : unsigned(23 downto 0) := (others => '0'); -- The selected hex display value
begin

    -- Instantiate the state machine
    state_machine : sim_state_machine
        port map(
            i_clk   => i_clk,
            r_state => r_state,
            state   => state
        );
    -- Instantiate the Receiver
    rx_inst : rx_32bit
        generic map(
            g_clks_per_bit  => c_clk_cycle, -- Clock cycles per UART bit (baud rate)
            g_clks_per_byte => c_clk_cycle*10 -- Clock cycles per UART byte
        )
        port map(
            i_clk  => i_clk,
            i_rx   => i_rx,         -- Serial input data | The received data
            o_data => r_rx_dp,    -- Output 32-bit data 8'b ID | 24'b data
            o_flg  => r_rx_busy      -- Reception busy flag 
        );
    -- Instantiate the Receiver Signal Router
    router : rx_signal_router
        generic map(
            n_signals => c_n_rx_var, -- Number of signals
            n_bits_sig => c_rx_wd,   -- Number of bits in the signal
            n_bits_id  => c_wd_ID,   -- Number of bits in the ID
            g_wd       => c_wd_tx_ver -- The width of the transmission data | Excluding the ID bits
        )
        port map(
            i_clk      => i_clk,
            i_data     => r_rx_dp, -- The received data packet | 32 bits | includes the ID bits
            i_busy_rx  => r_rx_busy, -- Added missing signal
            o_dbg      => open, -- Debug output
            o_sig      => r_rx_concat_sig -- Concatenated signals | 32 bits * 4 signals
        );
    
    
    -- Parameter Lookup Component |i_clk, i_SOC, i_I, i_state, i_tbl (R0_tbl, R1_tbl, C1_tbl, R2_tbl, C2_tbl), (and MIF files) | Later output R0, R1, C1, R2, C2 	
    ECM_Par : ECM_Parameters
        generic map(
            init_file_R0 => str_R0_tbl1,
            init_file_R1 => str_R0_tbl2
        )
        port map(
            i_clk       => i_clk,
            i_state     => r_state,
            i_rst_tbl1  => r_R0tbl,
            i_dbg_idx   => to_unsigned(r_loop_row, 4) & to_unsigned(r_loop_col,4), -- The row and column index for the 2D LUT
            i_ow_tbl1   => r_R0_new_val, -- The new value to overwrite the table
            i_SOC       => r_SOC,
            i_I         => r_I(22 downto 0),
            o_RO        => r_R0
        );

    -- Instantiate the Transceiver
    transceiver_inst : Transceiver
        generic map(
            g_clks_per_bit  => c_clk_cycle, -- Clock cycles per byte
            g_wd_data       => c_wd_tx_dp,  -- The width of the transmission data | Excluding the ID bits
            g_wd_ID         => c_wd_ID,     -- The width of the ID
            g_no_signals    => c_n_tx_var,  -- Number of signals to be transmitted
            g_delay         => 1000,        -- Delay for transmission
            g_smpl_f        => c_tx_sampling_f
        )
        port map(
            i_clk       => i_clk,
            i_strt      => r_tx_ver_strt, -- Start signal for the transmission
            i_dp_ver    => r_tx_ver_dp, -- The verification signal | 32 bits| includes the ID bits
            i_tx_IDs    => c_ID_tx_cnct, -- IDs for the signals
            i_dp_normal => r_tx_cnct_for_sampler_dp, -- The concatenated signals for the sampler
            o_tx_busy   => r_tx_ver_busy, -- UART busy signal
            o_tx_ver    => r_tx_ver_o, -- UART serial data output for verification
            o_tx_normal => r_tx_normal -- UART serial data output for normal data
        );

    ---- Debugging Mapping
    bcd_inst : bcd generic map(g_bin_width => 20) port map(i_bin => r_bcd_i, o_bcd => r_bcd_o);
    
    -- Instantiate the hex_digits component
    hex0_inst : hex_digits port map(i_bin => r_bcd_o(3 downto 0),  o_hex => o_hex0);
    hex1_inst : hex_digits port map(i_bin => r_bcd_o(7 downto 4),  o_hex => o_hex1);
    hex2_inst : hex_digits port map(i_bin => r_bcd_o(11 downto 8), o_hex => o_hex2);
    
    o_hex3 <= (others =>'1'); -- The 7-segment display output for the third digit
    o_hex4 <= (others =>'1'); -- The 7-segment display output for the fourth digit
	 hex0_inst_state : hex_digits port map(i_bin => "0" & r_state(2 downto 0), o_hex => o_hex5);
    --o_hex5 <= (others =>'1'); -- The 7-segment display output for the fifth digit
    ---- Debugging Mapping

    display_on_hex : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_sw(9) ='0' then
                case r_sel_hex_disp(7 downto 0) is
                    when "00000000" => -- Display the output of R0 
                        r_bcd_i <=to_unsigned(0,12)  	& r_R0(23 downto 16); -- The input for the BCD component
                    when "00000001" => -- Display the output of SOC
                        r_bcd_i <= to_unsigned(0,13) 	& r_SOC(23 downto 17); -- The input for the BCD component
                    when "00000010" => -- Display the output of I
                        r_bcd_i <= to_unsigned(0,16) 	& r_I(22 downto 19); -- The input for the BCD component
                    when "00000011" => -- Display the output of R0_new_val
                        r_bcd_i <= to_unsigned(0,12) 	& r_R0_new_val(15 downto 8); -- The input for the BCD component
                    when "00000100" => -- Display the output of R0_rowidx
                        r_bcd_i <= to_unsigned(0, 16) & r_R0_rowidx(23 downto 20); -- The input for the BCD component
                    when "00000101" => -- Display the output of R0_colidx
                        r_bcd_i <= to_unsigned(0, 16) & r_R0_colidx(23 downto 20); -- The input for the BCD component
                    when "00000110" => -- Display the output of SOC_col
                        r_bcd_i <= to_unsigned(0, 16) & r_SOC_col(23 downto 20); -- The input for the BCD component
                    when "00000111" => -- Display the output of I_row
                        r_bcd_i <= to_unsigned(0, 16) & r_I_row(23 downto 20); -- The input for the BCD component
                    when others => 
					    r_bcd_i <=to_unsigned(0,12)  	& r_R0(23 downto 16); -- The input for the BCD component

                end case;
            else
                null; -- The switches are used for setting the state
            end if;
        end if;
    end process display_on_hex;

    change_parameters_rx : process(i_clk)
    begin
        if rising_edge(i_clk) then
				if i_sw(9)='1' then
					case i_key is -- Replace with signal sampler
						when "1110" =>
							r_state <= i_sw(2 downto 0); -- The state is set by the switch
							r_rx_change_tracker(c_ID_rx_state) <= '1'; -- The signal for tracking the changed variables
						when "1101" =>
							r_rx_change_tracker(c_ID_rx_SOC) <= '1'; -- The signal for tracking the changed variables
							r_SOC <= to_unsigned(10, 7) & to_unsigned(0, 17); -- The SOC value at (0,0) should be updated to 100%
							o_led(9) <= '1';
						when "1011" => 
							r_R0_new_val<= to_unsigned(0,4) & to_unsigned(0, 4) & "01111000" & "00000000"; -- The R0 value at (0,0) should be updated to 120
							r_rx_change_tracker(c_ID_rx_R0) <= '1'; -- The signal for tracking the changed variables
						when "0111" => -- Change the current
							r_I <= to_unsigned(1, 5) & to_unsigned(0, 18) & "1"; -- The current value at (0,0) should be updated to 1A 
						    r_rx_change_tracker(c_ID_rx_I) <= '1'; -- 
						when others =>
							null;
						end case;
					else
					-- ID : 1
					if r_rx_concat_sig(23 downto 0)  /= c_only_zeros or r_rx_change_tracker(c_ID_rx_state) ='1' then  -- Signal 1 ID = 1 | SET STATE        
						 r_rx_change_tracker(c_ID_rx_state) <= '1'; -- The signal for tracking the changed variables
						 r_state <= r_rx_concat_sig(2 downto 0); -- The state is set by the switch
						 o_led(9) <= '1';

					end if;
					-- ID : 2 | SET CURRENT
					if r_rx_concat_sig(47 downto 24) /= c_only_zeros or r_rx_change_tracker(c_ID_rx_I) ='1' then -- Signal 2 ID = 2 | SET CURRENT
						 r_rx_change_tracker(c_ID_rx_I) <= '1'; -- The signal for tracking the changed variables
						 r_I <= r_rx_concat_sig(47 downto 24); -- The Current value at (0,0) should be updated to the read from the PC
					end if;
					-- ID : 3 | SET SOC
					if r_rx_concat_sig(71 downto 48) /= c_only_zeros or r_rx_change_tracker(c_ID_rx_SOC) ='1' then -- Signal 3 ID = 3 | SET SOC
						 r_rx_change_tracker(c_ID_rx_SOC) <= '1'; -- The signal for tracking the changed variables
						 r_SOC <= r_rx_concat_sig(71 downto 48); -- The SOC value at (0,0) should be updated to 100%
					end if;
					-- ID : 4 | SET R0 (Overwrite)
					if r_rx_concat_sig(95 downto 72) /= c_only_zeros or r_rx_change_tracker(c_ID_rx_R0) ='1' then -- Signal 4 ID = 4 | SET R0
						 r_rx_change_tracker(c_ID_rx_R0) <= '1'; -- The signal for tracking the changed variables
						 r_R0_new_val <= r_rx_concat_sig(95 downto 72); -- The R0 value at (0,0) should be updated to 120
					end if;
                    -- ID : Always the last one | SET HEX_DISPLAY
                    if r_rx_concat_sig(c_n_rx_var*c_rx_wd-1 downto (c_n_rx_var-1)*c_rx_wd) /= c_only_zeros or r_rx_change_tracker(c_n_rx_var) ='1' then -- Signal 5 ID = 5 | SET HEX_DISPLAY
                            r_rx_change_tracker(c_n_rx_var) <= '1'; -- The signal for tracking the changed variables
                            r_sel_hex_disp <= r_rx_concat_sig(c_n_rx_var*c_rx_wd-1 downto (c_n_rx_var-1)*c_rx_wd); -- The input for the BCD component
                    end if;

				end if;
				o_led(c_n_rx_var-1 downto 0) <= r_rx_change_tracker(c_n_rx_var downto 1); -- The LED output for the changed variables | 1 -> state
        end if;
    end process change_parameters_rx;
    
    -- Looping over the colums and then the rows
    loop_process : process(i_clk)
        begin
            if rising_edge(i_clk) then
            -- Adding the state and making the transmission dependent on the state
             case state is 
                when s_idle =>
                    -- The state is idle | Resetting
                    r_tx_ver_dp <= (others => '0');
                    r_loop_row <= 0;
                    r_loop_col <= 0;
                when s_init => 
                    -- The state is in initialization
                    o_tx <= r_tx_normal;
                    r_tx_cnct_for_sampler_dp <= r_R0 & r_SOC  & to_unsigned(0, 21) & r_state  ; -- The concatenated data to be transmitted | Exludes t   
                    r_R0_rowidx <= r_SOC_col;
                    r_R0_colidx <= r_I_row;
                when s_verification => -- We are in the verification state
                    -- The state is in verification
                    o_tx <= r_tx_ver_o;
                    case cnt_ver_signal is
                        when c_ID_rx_state =>
                            if r_rx_change_tracker(c_ID_rx_state) = '0' then
                                    cnt_ver_signal <= cnt_ver_signal + 1;
                                else 
                                    if r_tx_ver_busy = '0' then
                                        r_tx_ver_strt <= '1'; -- Start the transmission
                                        r_tx_ver_dp <= to_unsigned(c_ID_tx_state,8) & to_unsigned(0,21) & r_state;
                                        current_tx_sent<= (c_ID_tx_state => '1', others => '0'); -- Debugging signal
                                        cnt_ver_signal <= cnt_ver_signal + 1;
                                    end if;
                                end if;
                        when c_ID_rx_I => 
                            if r_rx_change_tracker(c_ID_rx_I) = '0' then-- Skip the verification if the signal is not changed
                                cnt_ver_signal <= cnt_ver_signal + 1;
                            else 
                                if r_tx_ver_busy = '0' then
                                    r_tx_ver_dp <= to_unsigned(c_ID_tx_I,8) & r_I;
                                    current_tx_sent<= (c_ID_tx_I => '1', others => '0'); -- Debugging signal
                                    -- Increment the counter
                                    cnt_ver_signal <= cnt_ver_signal + 1;
                                end if;
                            end if;

                            -- Increment the counter
                        when c_ID_rx_SOC =>
                            if r_rx_change_tracker(c_ID_rx_SOC) = '0' then
                                cnt_ver_signal <= cnt_ver_signal + 1;
                            else 
                                if r_tx_ver_busy ='0' then
                                    r_tx_ver_strt <= '1'; -- Start the transmission
                                    r_tx_ver_dp <= to_unsigned(c_ID_tx_SOC,8) & r_SOC;
                                    current_tx_sent<= (c_ID_tx_SOC => '1', others => '0'); -- Debugging signal
                                    -- Increment the counter
                                    cnt_ver_signal <= cnt_ver_signal + 1;
                                end if;
                            end if;

                        -- The R0 verification
                        when c_ID_rx_R0 =>
                            if r_rx_change_tracker(c_ID_rx_R0) = '0' then -- Skip the verification if the signal is not changed
                                cnt_ver_signal <= 1;
                            else
                                if r_tx_ver_busy = '0' then 
                                    r_tx_ver_dp <= to_unsigned(c_ID_tx_R0,8) & to_unsigned(r_loop_row, 4) & to_unsigned(r_loop_col, 4) &  r_R0(23 downto 8); 
                                    current_tx_sent<= (c_ID_tx_R0 => '1', others => '0');  -- Debugging signal
                                    -- The Loop over the R0 table | Next step create a component the verification of LUT tables which can be used for all the tables and outputs the verification data and then a r_table_verification_done when completed
                                    if r_loop_col < 10 then
                                        -- Set the verification data to (row[4bits] + column[4bits] + R0[16bits])
                                        r_loop_col <= r_loop_col + 1;
                                    else
                                        -- Reset the column counter
                                        r_loop_col <= 0;
                                        if r_loop_row < 15 then
                                            -- Increment the row counter
                                            r_loop_row <= r_loop_row + 1;
                                        else
                                            -- Reset the row counter
                                            r_loop_row <= 0;
                                            cnt_ver_signal <= 1; -- Reset the counter
                                            -- Temporary test to see if we skip after the first change
                                        end if;

                                    end if;

                                end if;

                            end if;
           
                            
                        when others =>
                            -- Do nothing
                            null;
                    end case;
                when s_sim => 
                    o_tx <= r_tx_normal;
                    r_R0_colidx <= r_SOC_col;
                    r_R0_rowidx <= r_I_row;
                    r_tx_cnct_for_sampler_dp <= r_R0 & r_SOC & to_unsigned(0, 21) & r_state; -- The concatenated data to be transmitted | Exludes t
                when others =>
            end case;
            
            end if;
        end process loop_process;


end architecture rtl;
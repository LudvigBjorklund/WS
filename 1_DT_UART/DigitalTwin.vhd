library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.alL;

entity DigitalTwin is 
    generic(
        g_clk_rate : integer := 434 -- Clock rate in Hz
    );
    port(
        i_clk : in std_logic;
        i_rx  : in std_logic;
        o_led : out unsigned(9 downto 0) := (others => '0');
        o_tx  : out std_logic
    );
end entity DigitalTwin;


architecture rtl of DigitalTwin is

-- =========================================================================
-- Component Declarations
-- =========================================================================

-- ==========================
-- Simulation State Machine
-- ==========================
component sim_SM is 
    port(
        i_clk    : in std_logic;
        i_state_bin  : in unsigned(2 downto 0);
        o_state  : out t_state
    );
end component sim_SM;


-- ======================
-- UART 32-bit Component
-- ======================
component DT_UART_32bit is
    generic(
        g_clk_rate : integer := 434; -- Clock rate in Hz
        g_no_signals_rx : integer := 8; -- Number of signals to be received
        g_no_signals_tx : integer := 4; -- Number of signals to be transmitted
        g_no_signals_ver_tx : integer := 4; -- Number of signals to be verified
        g_max_no_signals_tx : integer := 8; -- Maximum number of signals that can be transmitted
        g_init_rx_data : unsigned(31 downto 0) := (others => '0') -- Initial 32-bit data bus
    );
    port(
        i_clk          : in std_logic;
        i_state        : in t_state;
        i_rx           : in std_logic;
        i_init_rx_cnct : in unsigned((g_no_signals_rx * 24) - 1 downto 0) := (others => '0'); -- Initial concatenated RX data bus
        i_strt_tx      : in std_logic; -- Start transmission signal
        i_data_tx      : in unsigned((g_max_no_signals_tx * 32) - 1 downto 0); -- Concatenated TX data bus
        i_skip_tx      : in std_logic_vector(g_no_signals_ver_tx-1 downto 0); -- Skip transmission of specific signals for verification
        o_rx_data      : out unsigned((g_no_signals_rx * 24) - 1 downto 0); -- Received concatenated RX data bus
        o_done_tx      : out std_logic; -- Transmission done signal
        o_busy_tx      : out std_logic; -- Transmission busy signal
        o_tx           : out std_logic
    );
end component DT_UART_32bit;


-- =========================================================================
-- Signal Declarations
-- ========================================================================= 
constant clk_rate : integer := 4; -- Change before synthesis: Clk periods to wait between bit transmissions (baud rate = 115200, clk_rate = 434 for 50MHz clk)
constant no_signals_rx : integer := 2; -- Number of signals to be received
constant no_signals_tx : integer := 1; -- Number of signals to be transmitted
constant no_signals_ver_tx : integer := 2; -- Number of signals to be verified
constant max_no_signals_tx : integer := 2; -- Maximum of either verification or transmission signals

-- ======================
-- UART 32-bit 
-- ======================

-- =========
-- Receiver
-- =========
constant init_rx_data : unsigned(31 downto 0) := to_unsigned(1, 8) & to_unsigned(0, 24); -- Initial 32-bit data bus
signal r_rx_data     : unsigned((no_signals_rx * 24) - 1 downto 0) := (others => '0'); -- Received concatenated RX data bus
signal r_init_rx_cnct : unsigned((no_signals_rx * 24) - 1 downto 0) := (others => '0'); -- Initial concatenated RX data bus (both to DT_UART_32bit and DT_RX)

-- =========
-- Transmitter
-- =========
signal r_strt_tx      : std_logic := '0'; -- Start transmission signal UNRELEVANT FOR THIS TESTBENCH (only care about RX)
signal r_data_tx      : unsigned((max_no_signals_tx * 32) - 1 downto 0) := (others => '0'); -- Concatenated TX data bus UNRELEVANT FOR THIS TESTBENCH (only care about RX)
signal r_skip_tx      : std_logic_vector(no_signals_ver_tx-1 downto 0) := (others => '0'); -- Skip transmission of specific signals for verification UNRELEVANT FOR THIS TESTBENCH (only care about RX)
signal r_done_tx      : std_logic; -- Transmission done signal UNRELEVANT FOR THIS TESTBENCH (only care about RX)
signal r_busy_tx      : std_logic; -- Transmission busy signal UNRELEVANT FOR THIS TESTBENCH (only care about RX)
signal r_tx           : std_logic; -- TX signal UNRELEVANT FOR THIS TESTBENCH (only care about RX)

-- ======================
-- State Machine 
-- ======================
signal r_state       : t_state := s_idle;      -- State signal
signal r_SM_no       : unsigned(2 downto 0) := (others => '0'); -- State machine number signal


begin

    sim_SM_inst : sim_SM
    port map(
        i_clk       => i_clk,
        i_state_bin => r_SM_no,
        o_state     => r_state
    );
DT_UART_32bit_inst : DT_UART_32bit
    generic map(
        g_clk_rate       => clk_rate,
        g_no_signals_rx  => no_signals_rx,
        g_no_signals_tx  => no_signals_tx,
        g_no_signals_ver_tx => no_signals_ver_tx,
        g_max_no_signals_tx => max_no_signals_tx,
        g_init_rx_data   => init_rx_data
    )
    port map(
        i_clk          => i_clk,
        i_state        => r_state,
        i_rx           => i_rx,
        i_init_rx_cnct => r_init_rx_cnct,
        i_strt_tx      => r_strt_tx,
        i_data_tx      => r_data_tx,
        i_skip_tx      => r_skip_tx,
        o_rx_data      => r_rx_data,
        o_done_tx      => r_done_tx,
        o_busy_tx      => r_busy_tx,
        o_tx           => r_tx
    );


    assign_rx_data : process(i_clk)
begin 
    if rising_edge(i_clk) then
        r_SM_no <= r_rx_data(2 downto 0);
    end if;
end process assign_rx_data;
send_to_PC : process(i_clk)
variable v_init_complete : integer range 0 to 2:= 0;
begin
    if rising_edge(i_clk) then

        case r_state is 
            when s_idle =>
                -- In the idle state we send back the r_SOC value to the PC
                if v_init_complete < 2 then
                    v_init_complete := v_init_complete + 1;
                else
                    if r_done_tx /= '0' then
                        r_strt_tx <= '1';
                        r_data_tx(31 downto 0) <= to_unsigned(1, 8) & to_unsigned(3, 24); -- Sending test value
                     end if;
                end if;
               
            when s_init =>
                if r_done_tx = '1' then
                    r_strt_tx <= '0';
                end if;
            when others =>

                null;

        end case;
    end if;
end process send_to_PC;


-- =============================================== Debugging Processes ===============================================
set_leds : process(i_clk)
begin
    if rising_edge(i_clk) then
        o_led(2 downto 0) <= r_SM_no;
    end if;
end process set_leds;


end architecture rtl;
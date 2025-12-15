library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity DT_UART_32bit is
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
end entity DT_UART_32bit;

architecture rtl of DT_UART_32bit is
-- Declaration of the transmitter and receiver components
component DT_RX is
    generic(
        g_clk_rate : integer := 434; -- Clock rate in Hz
        g_no_signals : integer := 8; -- Number of signals
        g_wd_ID : integer := 8; 
        g_init_rx_data : unsigned(31 downto 0) := (others => '0') -- Initial 32-bit data bus
        );
    port(
        i_clk   : in std_logic; -- Clock signal
        i_rx    : in std_logic; -- RX signal
        i_init_cnct : in unsigned((g_no_signals * 24) - 1 downto 0); -- Initial concatenated data bus
        i_state : in t_state; -- State signal
        o_data  : out unsigned((g_no_signals * 24) - 1 downto 0) -- Output data into concatenated bus of signals
    );
end component DT_RX;

component DT_TX is 
    generic(
        g_clks_per_bit  : integer := 434;
        no_signals_sim  : integer := 4;  -- Number of signals to transmit
        no_signals_ver  : integer := 8;   -- Number of signals to transmit in version mode
        max_no_signals  : integer := 8   -- Maximum number of signals to transmit (for array sizing)
    );
    port(
        i_clk      : in  std_logic; -- Clock input
        i_state    : in t_state := s_idle; -- Current state of the system
        i_strt     : in  std_logic; -- Start signal to begin transmission
        i_data     : in unsigned((max_no_signals*32)-1 downto 0); -- Input data (32 bits per signal)
        i_skip_tx  : in std_logic_vector(no_signals_ver-1 downto 0) := (others => '0'); -- '1' to skip transmission of corresponding signal
        o_busy     : out std_logic; -- UART busy signal
        o_done     : out std_logic; -- Done signal indicating transmission complete
        o_tx       : out std_logic -- UART serial data output
    );
end component DT_TX;

-- Processes and maoppings
begin
    dt_rx_inst : DT_RX
        generic map(
            g_clk_rate => g_clk_rate,
            g_no_signals => g_no_signals_rx,
            g_wd_ID => 8,
            g_init_rx_data => g_init_rx_data
        )
        port map(
            i_clk => i_clk,
            i_rx => i_rx,
            i_init_cnct => i_init_rx_cnct,
            i_state => i_state,
            o_data => o_rx_data
        );
    dt_tx_inst : DT_TX
        generic map(
            g_clks_per_bit => g_clk_rate,
            no_signals_sim => g_no_signals_tx,
            no_signals_ver => g_no_signals_ver_tx,
            max_no_signals => g_max_no_signals_tx
        )
        port map(
            i_clk => i_clk,
            i_state => i_state,
            i_strt => i_strt_tx,
            i_data => i_data_tx,
            i_skip_tx => i_skip_tx,
            o_busy => o_busy_tx,
            o_done => o_done_tx,
            o_tx => o_tx
        );



end architecture rtl;
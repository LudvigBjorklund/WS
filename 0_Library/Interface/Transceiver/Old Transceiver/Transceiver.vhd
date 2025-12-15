library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Transceiver is
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
end entity Transceiver;


architecture rtl_tx of Transceiver is



-- Transmitter for the verification data
component tx_32bit is 
    generic(
        g_clks_per_bit  : integer := g_clks_per_bit; -- Clock cycles per bit
        g_clks_per_byte : integer := 4340
    );
    port(
        i_clk  : in  std_logic; -- Clock input
        i_strt : in  std_logic; -- Start signal to begin transmission
        i_data : in  unsigned(31 downto 0); -- Input data (32 bits)
        o_busy : out std_logic; -- UART busy signal
        o_tx   : out std_logic  -- UART serial data output
    );
end component tx_32bit;

-- Transmitter for the online data
component tx_signal_sampler is
	generic(
	 n_bits_sig : integer := 24; -- Width of the data signal for transmission
	 n_bits_id 	: integer := 8; -- Number of bits for the ID
	 n_signals 	: integer := 5; -- Number of signals to sample
	 g_smpl_f 	: integer := 500000
	 );
     port(
        i_clk 			: in std_logic; -- Clock signal
        i_data_concat : in unsigned(n_signals*n_bits_sig-1 downto 0); -- Concatenated input signals (5*24 = 120 bits)
        i_tx_IDs 		: in unsigned(n_signals*n_bits_id-1 downto 0); -- IDs for the signals (5*8 = 40 bits)
        o_dbg			: out std_logic;
        o_tx_data_concat : out unsigned(n_signals*(n_bits_sig+n_bits_id)-1 downto 0) -- Concatenated output signals (5*(24+8) = 160 bits)
        );
end component tx_signal_sampler;


component transmit_data_to_PC is
    generic(
        g_signal_wd : integer := 32; -- Signal width | Including the ID bits
        g_no_signals: integer := 5; -- Number of signals to be transmitted
        g_delay     : integer := 1000 -- Delay for transmission
    );
    port (
        i_clk   : in std_logic;
        i_data  : in unsigned(g_no_signals*g_signal_wd-1 downto 0); -- The concatenated signals to be transmitted 
        o_tx    : out std_logic -- UART serial data output
    );
end component transmit_data_to_PC;

signal r_tx_data_normal : unsigned(g_no_signals*(g_wd_data+g_wd_ID)-1 downto 0); -- Data to be transmitted, the incoming

begin
    -- Instantiate the tx_32bit component for verification data
    tx_ver_inst : tx_32bit
        generic map(
            g_clks_per_bit  => g_clks_per_bit,
            g_clks_per_byte => 4340
        )
        port map(
            i_clk  => i_clk,
            i_strt => i_strt, -- Connect the start signal
            i_data => i_dp_ver,
            o_busy => o_tx_busy,
            o_tx   => o_tx_ver
        );

    -- Instantiate the tx_signal_sampler_new component for online data
    tx_signal_sampler_inst : tx_signal_sampler
        generic map(
            n_bits_sig => g_wd_data,
            n_bits_id  => g_wd_ID,
            n_signals  => g_no_signals,
            g_smpl_f   => g_smpl_f
        )
        port map(
            i_clk          => i_clk,
            i_data_concat  => i_dp_normal,
            i_tx_IDs       => i_tx_IDs , -- Placeholder for IDs
            o_dbg          => open,
            o_tx_data_concat => r_tx_data_normal-- Placeholder for output
        );
    
    -- Instantiate the transmit_data_to_PC component for online data
    tx_inst : transmit_data_to_PC
        generic map(
            g_signal_wd => g_wd_data+g_wd_ID,
            g_no_signals => g_no_signals,
            g_delay     => g_delay
        )
        port map(
            i_clk   => i_clk,
            i_data  => r_tx_data_normal, -- Connect the concatenated signals to be transmitted
            o_tx    => o_tx_normal -- Connect the UART serial data output
        );
end architecture rtl_tx;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_online_data is
    generic(
        g_wd_data : integer := 32; -- Signal width | Excluding the ID bits
        g_wd_id   : integer := 8;  -- Number of bits for the ID
        g_no_signals: integer := 5; -- Number of signals to be transmitted
        g_delay     : integer := 1000 -- Delay for transmission
        g_smpl_f  : integer := 500000
    );
    port (
        i_clk           : in std_logic;
        i_data_concat   : in unsigned(g_no_signals*g_wd_data-1 downto 0); -- The concatenated signals to be transmitted 
        i_IDs           : in unsigned(g_no_signals*g_wd_id-1 downto 0); -- IDs for the signals
        o_tx            : out std_logic -- UART serial data output | connect to the UART transmitter peripheral
    );
end entity tx_online_data;

architecture rtl_tx of tx_online_data is

constant c_wd_data : integer := g_wd_data; -- Signal width | Excluding the ID bits
constant c_wd_id   : integer := g_wd_id;   -- Number of bits for the ID
constant c_no_signals: integer := g_no_signals; -- Number of signals to be transmitted


component tx_signal_sampler_new is
    generic(
        n_bits_sig : integer := 24; -- Width of the data signal for transmission
        n_bits_id 	: integer := 8; -- Number of bits for the ID
        n_signals 	: integer := 5; -- Number of signals to sample
        g_smpl_f 	: integer := 500000 -- Sampling frequency | number of clock cycles until the next sample
    port(
        i_clk 			: in std_logic; -- Clock signal
        i_data_concat : in unsigned(n_signals*n_bits_sig-1 downto 0); -- Concatenated input signals (5*24 = 120 bits)
        i_tx_IDs 		: in unsigned(n_signals*n_bits_id-1 downto 0); -- IDs for the signals (5*8 = 40 bits)
        o_dbg			: out std_logic;
        o_tx_data_concat : out unsigned(n_signals*(n_bits_sig+n_bits_id)-1 downto 0) -- Concatenated output signals (5*(24+8) = 160 bits)
        );
end component tx_signal_sampler_new;

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
signal r_tx_strt : std_logic := '0'; -- Start signal for the transmitter
signal r_tx_busy : std_logic := '0'; -- UART busy signal
signal r_tx_data_smpled : unsigned(c_no_signals*(c_wd_data+c_wd_id)-1 downto 0); -- Data to be transmitted, the incoming
begin
    -- Instantiate the tx_signal_sampler_new component
    tx_signal_sampler_inst : tx_signal_sampler_new
        generic map(
            n_bits_sig => c_wd_data,
            n_bits_id  => c_wd_id,
            n_signals  => c_no_signals,
            g_smpl_f   => g_smpl_f
        )
        port map(
            i_clk           => i_clk,
            i_data_concat   => i_data_concat,
            i_tx_IDs       =>, -- Assuming IDs are not used in this context
            o_dbg          => open, -- Debug output not used
            o_tx_data_concat => r_tx_data_smpled -- Output not used directly
        );
    -- Instantiate the transmit_data_to_PC component
    transmit_data_to_PC_inst : transmit_data_to_PC
        generic map(
            g_signal_wd => c_wd_data + c_wd_id, -- Including the ID bits
            g_no_signals => c_no_signals,
            g_delay     => g_delay
        )
        port map(
            i_clk   => i_clk,
            i_data  => r_tx_data_smpled, -- The concatenated signals to be transmitted
            o_tx    => o_tx -- UART serial data output | connect to the UART transmitter peripheral
        );

end architecture rtl_tx;
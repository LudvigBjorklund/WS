library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all; 

entity DT_RX is
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
end entity DT_RX;

architecture rtl of DT_RX is

    -- Signal for storing the output from the 4byte
    signal r_rx_data : unsigned(31 downto 0) := "00000000" &"00000000" & "00000000" & "00000000"; -- Output data from the rx_4byte component
    signal r_rx_data_out : unsigned(31 downto 0) := (others => '0'); -- Output data from the rx_4byte component
    signal r_rx : std_logic := '1'; -- RX line, default high (idle state)
    signal r_4byte_busy : std_logic := '0'; -- Busy signal for the 4-byte receiver
    -- Signals
    signal r_data_cnct : unsigned((g_no_signals * 24) - 1 downto 0) := i_init_cnct; -- Output data bus
    signal r_state : t_state; -- Internal state signal

    -- Component declarations
    component rx_4byte is
        generic(
            g_clk_rate :integer := 434
        );
        port(
            i_clk   : in std_logic; -- Clock input
            i_state : in t_state;  -- State signal
            i_rx    : in std_logic; -- Serial input data 
            o_busy  : out std_logic; -- Output bus signal, not used in this architecture
            o_data  : out unsigned(31 downto 0) -- Output 32-bit data
        );
    end component rx_4byte;    

    component rx_route4byte is 
        generic(
            n_signals : integer := 3
        );
        port(
            i_clk   : in std_logic; -- Clock input
            i_state : in t_state; -- State signal
            i_data  : in unsigned(31 downto 0); -- Input data from the rx_4byte component
            i_init_data : in unsigned((n_signals*24) - 1 downto 0); -- Initial concatenated data bus
            i_busy  : in std_logic;
            o_data  : out unsigned((n_signals*24) - 1 downto 0) -- Concatenated output data bus
        );
    end component rx_route4byte;


begin
    -- Instantiate the rx_4byte component
    read_4byte_inst : rx_4byte
        generic map(
            g_clk_rate => g_clk_rate
        )
        port map(
            i_clk   => i_clk,
            i_state => i_state,
            i_rx    => i_rx,
            o_busy  => r_4byte_busy, -- Used in the router 
            o_data  => r_rx_data
        );

    -- Instantiating the signal router component
    rx_route_inst : rx_route4byte
        generic map(
            n_signals => g_no_signals
        )
        port map(
            i_clk   => i_clk,
            i_state => i_state,
            i_data  => r_rx_data, -- Input data from the rx_4byte component
            i_init_data => i_init_cnct, -- Initial concatenated data bus
            i_busy  => r_4byte_busy, -- RX line state, not used in this architecture
            o_data  => r_data_cnct -- Output data bus
        );

        o_data <= r_data_cnct; -- Assign the output data bus to the output port


end architecture rtl;
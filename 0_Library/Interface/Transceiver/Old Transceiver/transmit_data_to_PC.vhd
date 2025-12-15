library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity transmit_data_to_PC is
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
end entity transmit_data_to_PC;

architecture rtl_tx of transmit_data_to_PC is
signal r_tx_strt : std_logic := '0'; -- Start signal for the transmitter
signal r_tx_busy : std_logic := '0'; -- UART busy signal
signal r_tx_data : unsigned(31 downto 0); -- Data to be transmitted, the incoming 

-- Signals for delaying the data transmission
signal r_delay_cnt : integer range 0 to g_delay := 0; -- Delay counter
signal r_wait       : std_logic := '0'; -- Wait signal for delaying the transmission
signal r_delay_active : std_logic := '0'; -- Delay active signal

signal r_tx_packet_select : integer range 0 to g_no_signals-1 := 0; -- Selects the signal to be transmitted

-- Component declaration for the tx transmitter
component tx_32bit is 
	generic(
		g_clks_per_bit  : integer := 434;
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

begin
    -- Instantiate the tx_32bit component
-- Corrected instantiation of the tx_32bit component
tx_inst : tx_32bit
    generic map(
        g_clks_per_bit  => 434,
        g_clks_per_byte => 4340
    )
    port map(
        i_clk  => i_clk,
        i_strt => r_tx_strt, -- Connect the correct start signal
        i_data => r_tx_data,
        o_busy => r_tx_busy,
        o_tx   => o_tx
    );

    -- Process to transmit the data to the PC
    transmit_data : process(i_clk)
        begin
            if rising_edge(i_clk) then
                r_tx_strt <= '0';
                
                if r_delay_active = '1' then
                    if r_delay_cnt = 0 then
                        r_delay_active <= '0';
                    else
                        r_delay_cnt <= r_delay_cnt - 1;
                    end if;
                elsif r_tx_busy='0' and r_delay_active = '0' then
                    if r_wait = '0' then
                        -- Dynamically select the signal to transmit
                        r_tx_data <= i_data((r_tx_packet_select + 1) * g_signal_wd - 1 downto r_tx_packet_select * g_signal_wd);
                        r_tx_strt <= '1';
                        r_wait <= '1';
                    elsif r_wait = '1' then
                        if r_tx_packet_select < g_no_signals then
                            r_tx_packet_select <= r_tx_packet_select + 1;
                        else
                            r_tx_packet_select <= 0;

                        end if;
                        r_wait <= '0';
                        r_delay_active <= '1';
                        r_delay_cnt <= 1; -- For simulations adjust this value to 1000
                    end if;

                end if;

            end if;
    end process transmit_data;

end architecture rtl_tx;
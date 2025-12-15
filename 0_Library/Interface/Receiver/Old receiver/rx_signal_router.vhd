library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all; -- Common library for shared types and constants

entity rx_signal_router is
    generic(
        n_signals : integer := 5; -- Number of signals
        n_bits_sig : integer := 24; -- Number of bits in the signal
        n_bits_id : integer := 8; -- Number of bits in the ID
        g_wd : integer := 32
        );
    port(
        i_clk 		: in std_logic;
        i_state 	: in  t_state;             -- State signal
		i_init_data : in unsigned(n_signals*n_bits_sig - 1 downto 0); -- The inital datapacket o
        i_data : in unsigned(n_bits_sig+n_bits_id-1 downto 0); -- The n-bit data packet received from the UART (Receiver component rx32bit)
        i_busy_rx : in std_logic;
        o_dbg : out std_logic;
        o_sig : out unsigned(n_signals*n_bits_sig-1 downto 0) -- Concatenated signals
    );
end entity rx_signal_router;


architecture rtl of rx_signal_router is
    -- Default value assignment
    signal r_sig : unsigned(n_signals*n_bits_sig-1 downto 0) := (others => '0');
begin
    -- Combinational output assignment
    o_sig <= r_sig;

    process(i_clk)
    variable v_index : integer range 0 to n_signals-1;
    begin
        if rising_edge(i_clk) then
            if i_state = s_idle then
                    if i_busy_rx = '0' then
                    -- Reset all data to the initial data except the last 3 bittss (least significant bits)
                        v_index := to_integer(unsigned(i_data(n_bits_sig + n_bits_id - 1 downto n_bits_sig))) - 1;
                        if v_index = 0 then
                                r_sig(v_index*n_bits_sig+n_bits_sig-1 downto v_index*n_bits_sig) <= i_data(n_bits_sig-1 downto 0);

                        end if;
                        r_sig(n_signals*n_bits_sig-1 downto 32) <=i_init_data(n_signals*n_bits_sig-1 downto 32);
                    end if;
                    o_dbg <='0';
            else
                    if i_busy_rx = '0' then
                                -- Convert ID portion to integer for indexing
                            v_index := to_integer(unsigned(i_data(n_bits_sig + n_bits_id - 1 downto n_bits_sig))) - 1;
                                -- Update the specific signal in the concatenated output
                            r_sig(v_index*n_bits_sig+n_bits_sig-1 downto v_index*n_bits_sig) <= i_data(n_bits_sig-1 downto 0);
                    end if;
                    o_dbg <='1';
            end if;
        end if;
    end process;
end architecture rtl;
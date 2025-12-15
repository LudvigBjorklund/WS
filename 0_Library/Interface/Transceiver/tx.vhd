-- This VHDL code defines the TX component, which is a UART transmitter designed to send serial data.
-- It converts an 8-bit parallel input (i_data) into serial data transmitted over the UART line (o_tx).
-- The component uses clock cycles (i_clk) to synchronize the transmission of data bits.
-- The generic parameter g_clks_per_bit configures the number of clock cycles per bit.

library ieee;
use ieee.std_logic_1164.all; -- Standard logic package for VHDL
use ieee.numeric_std.all;

entity tx is
    generic(g_clks_per_bit : integer := 434); -- Number of clock cycles per bit
    port(
        i_clk  : in std_logic; -- Clock input
        i_strt : in std_logic; -- Start transmission signal
        i_data : in unsigned(7 downto 0); -- Data to transmit over UART
        o_busy : out std_logic :='1'; -- Busy signal indicating transmission in progress
        o_done : out std_logic :='0'; -- Done signal indicating transmission complete
        o_tx   : out std_logic  -- UART serial data output
    );
end entity tx;

architecture rtl of tx is
    signal r_prscl : integer range 0 to g_clks_per_bit := 0; -- Prescaler for bit timing
    signal r_idx   : integer range 0 to 9 := 0; -- Index for transmitted bits
    signal r_data  : unsigned(9 downto 0) := (others => '0'); -- Shift register to hold data to be transmitted
    signal r_flg   : std_logic := '0'; -- Flag indicating transmission state

begin

    process(i_clk)
    begin
        if i_clk'event and i_clk = '1' then
            -- Detect start signal and initialize transmission
            if (r_flg = '0' and i_strt = '1') then
                r_flg <= '1'; 
                o_busy <= '1';
                o_done <= '0';  -- Reset o_done on start
                r_data(0) <= '0'; -- Start bit
                r_data(r_data'left) <= '1'; -- Stop bit
                r_data(8 downto 1) <= i_data; -- Data bits
            end if;

            -- Shift out transmitted bits
            if r_flg = '1' then
                if r_prscl < g_clks_per_bit - 1 then
                    r_prscl <= r_prscl + 1;
                else    
                    r_prscl <= 0;
                end if;

                -- Clear o_busy one cycle before o_done
                if r_idx = 9 and r_prscl = g_clks_per_bit / 2 - 2 then
                    o_busy <= '0';
                end if;

                if r_prscl = g_clks_per_bit / 2 - 1 then
                    o_tx <= r_data(r_idx);
                    if r_idx < 9 then
                        r_idx <= r_idx + 1;
                    else
                        r_idx <= 0;
                        r_flg <= '0';
                        o_done <= '1'; -- Set o_done here
                    end if;
                end if;
            
            end if;
        end if;
    end process;
end architecture;

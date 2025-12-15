-- The RX component is a UART receiver designed to receive serial data on the i_RX_line input. 
-- It converts the received serial data into an 8-bit parallel output (o_data). 
-- The component uses clock cycles (i_clk) to synchronize the reception of data bits and 
-- uses two generic parameters to configure the clock cycles per bit and the timing period.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common.all;  -- Assumes t_state and s_reset are defined here

entity RX is
    generic(
        g_clks_per_bit : integer := 434; -- Number of clock cycles per bit
        g_period       : integer := 217  -- Timing period for sampling
    );
    port(
        i_clk     : in  std_logic;      -- Clock input
        i_state   : in  t_state;        -- Added state input for reset mode
        i_RX_line : in  std_logic;      -- Serial data input
        o_data    : out unsigned(7 downto 0); -- 8-bit parallel data output
        o_busy    : out std_logic       -- Busy signal indicating reception in progress
    );
end entity RX;

architecture rtl of RX is
    signal r_prscl : integer range 0 to g_clks_per_bit := 0;  -- Prescaler for bit timing
    signal r_data  : unsigned(9 downto 0) := (others => '0');  -- Shift register to hold received bits
    signal r_flg   : std_logic := '0';             -- Flag indicating reception in progress
    signal r_idx   : integer range 0 to 9 := 0;      -- Index for received bits
begin
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_state = s_reset then
                -- Reset all internal signals when a reset state is active
                null;  -- Maintain current state during reset
                -- r_prscl <= 0;
                -- r_data  <= (others => '0');
                -- r_idx   <= 0;
                -- r_flg   <= '0';
                -- o_busy  <= '0';
                -- o_data  <= (others => '0');
            else
                -- Detect start bit and initialize reception
                if (r_flg = '0' and i_RX_line = '0') then
                    r_idx   <= 0;
                    r_flg   <= '1';
                    r_prscl <= 0;
                    o_busy  <= '1';
                end if;
                
                -- Shift in received bits while reception is active
                if (r_flg = '1') then
                    r_data(r_idx) <= i_RX_line;
                    if (r_prscl < g_clks_per_bit) then
                        r_prscl <= r_prscl + 1;
                    else
                        r_prscl <= 0;
                    end if;
                end if;
                -- Sample bit after timing period
                if (r_prscl = g_period) then
                    if r_idx < 9 then
                        r_idx <= r_idx + 1;
                    else
                        -- Check for valid frame: proper start (0) and stop (1) bits
                        if (r_data(0) = '0' and r_data(9) = '1') then
                            o_data <= r_data(8 downto 1);  -- Extract 8-bit parallel data
                        else
                            o_data <= (others => '0');     -- Invalid frame
                        end if;
                        r_flg <= '0';
                        o_busy <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;


    -- -- Debug process for monitoring if we miss a change in the rx_line
    -- dbg_process_rx_line : process(i_clk)
    --     variable v_last_rx_line : std_logic := '1'; -- Idle state is high
    -- begin
    --     if rising_edge(i_clk) then
    --         if i_RX_line /= v_last_rx_line then
    --             report "RX Line changed to: " & std_logic'image(i_RX_line);
    --             v_last_rx_line := i_RX_line;
    --         end if;
    --     end if;
    -- end process dbg_process_rx_line;
end architecture rtl;
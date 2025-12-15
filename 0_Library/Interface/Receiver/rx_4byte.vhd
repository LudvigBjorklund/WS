library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all; -- Common library for shared types and constants

entity rx_4byte is
    generic(
        g_clk_rate :integer := 434
    );
    port(
        i_clk   : in std_logic; -- Clock input
        i_state : in t_state;  -- State signal
        i_rx    : in std_logic; -- Serial input data 
        o_busy  : out std_logic; -- Output bus signal, not used in this architecture
        o_data  : out unsigned(31 downto 0)-- Output 32-bit data
    );
end entity rx_4byte;    

architecture rtl of rx_4byte is

    -- RX Submodule Declaration
    component RX is
        generic(
            g_clks_per_bit : integer := 434; -- Number of clock cycles per bit
            g_period       : integer := 217  -- Timing period for sampling
        );
        port(
            i_clk     : in  std_logic;               -- Clock input
            i_state   : in  t_state;                 -- State input for reset
            i_RX_line : in  std_logic;               -- Serial data input
            o_data    : out unsigned(7 downto 0);      -- 8-bit parallel data output
            o_busy    : out std_logic                -- Busy signal indicating reception in progress
        );
    end component RX;

    -- Internal signal
    signal r_dp_ID  : unsigned(7 downto 0) := (others => '0'); -- ID  byte the most significant byte
    signal r_dp_msb : unsigned(7 downto 0) := (others => '0'); -- Data byte 0 
    signal r_dp_mid : unsigned(7 downto 0) := (others => '0'); -- Data byte 1

    -- Signal for holding the output from the RX submodule
    signal r_dp_rx  : unsigned(7 downto 0) := (others => '0'); -- Data byte 2
    -- Signal for the busy state of the RX, used for stepping to assingning the next byte
    signal r_busy   : std_logic := '0'; -- Indicates RX submodule is busy


    signal r_rx    : std_logic := '1'; -- Internal signal to hold the RX line state
    signal r_busy_prev : std_logic := '1'; -- Signal to store the previous state of r_busy
    signal init_done : std_logic := '0'; -- Signal to indicate if initialization is done
    -- Testing only signal, for tracking the reception state
    signal r_test   : integer range 0 to 3 := 0; -- Tracks which byte is being received
    begin

    -- Instantiate the RX submodule
    rx_inst : RX
        generic map(
            g_clks_per_bit => g_clk_rate,
            g_period       => g_clk_rate / 2
        )
        port map(
            i_clk     => i_clk,
            i_state   => i_state,
            i_RX_line => r_rx,
            o_data    => r_dp_rx,
            o_busy    => r_busy -- Not used in this architecture
        );
    -- Process for setting the i_rx to the RX submodule
    process(i_clk)
    begin 
        if rising_edge(i_clk) then
            r_rx <= i_rx; -- Assign the input RX line to the internal signal
        end if;
    end process;

    -- Process to handle the reception of 4 bytes
process(i_clk)
variable v_set_byte_no : integer range 0 to 3 := 0; -- Variable to track which byte is being set
variable v_wait2_cycles : integer range 0 to 1 := 0; -- Variable to wait for 2 cycles before processing
begin 
if rising_edge(i_clk) then
    -- Detect falling edge of r_busy
    r_test <= v_set_byte_no; -- Update the test signal for tracking
    if init_done ='1' then -- Check if the initialization is done
        case v_set_byte_no is
            when 0 => 
                if r_busy_prev = '1' and r_busy = '0' then
                r_dp_ID <= r_dp_rx; -- Set the ID byte
                v_set_byte_no := 1; -- Move to the next byte
                end if;
                o_busy <= '1'; -- Set busy signal to high to indicate processing
            when 1 =>
                if r_busy_prev = '1' and r_busy = '0' then
                r_dp_msb <= r_dp_rx; -- Set the most significant byte
                v_set_byte_no := 2; -- Move to the next byte
                end if;
            when 2 =>
                if r_busy_prev = '1' and r_busy = '0' then
                r_dp_mid <= r_dp_rx; -- Set the middle byte
                v_set_byte_no := 3; -- Move to the next byte
                end if;
            when 3 =>
                if r_busy_prev = '1' and r_busy = '0' then
                    o_data <= unsigned(r_dp_ID & r_dp_msb & r_dp_mid & r_dp_rx); -- Assemble the final output
                    v_set_byte_no := 0; -- Reset to start over for the next reception
                    o_busy <= '0'; -- Set busy signal to low after processing
                end if;
            when others =>
                v_set_byte_no := 0; -- Reset in case of unexpected value
        end case;
    else 
        o_data <= (others => '0'); -- Reset output data if initialization is not done

        if v_wait2_cycles =0 then
            v_wait2_cycles := 1; -- Increment wait counter
        else
            v_wait2_cycles := 0; -- Reset wait counter after 2 cycles
            init_done <= '1'; -- Set initialization done after waiting
        end if;
    end if;
    -- Update the previous state of r_busy
    r_busy_prev <= r_busy;
end if;
end process;

end architecture rtl;
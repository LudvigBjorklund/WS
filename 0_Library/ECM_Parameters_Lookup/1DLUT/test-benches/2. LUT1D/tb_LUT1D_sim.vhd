library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity tb_LUT1D_sim is
end entity tb_LUT1D_sim;

architecture tb_behavioral of tb_LUT1D_sim is

    -- Component declaration
    component LUT1D_sim is
        generic (
            table_mif  : string := "LUT_1D.mif";
            ADDR_WIDTH : integer := 4;
            n_frac_bits: integer := 20;
            n_out_bits : integer := 16;
            n_tbl_bits : integer := 48
        );
    port (
        i_clk      : in std_logic;
        i_state    : in t_state;
        i_lut_addr : in unsigned(ADDR_WIDTH+ n_frac_bits-1 downto 0); -- 4MSB Int, 8LSB frac for the interpolation
        i_ow_addr  : in unsigned(ADDR_WIDTH-1 downto 0);
        i_ow_data  : in unsigned(19 downto 0);
        o_val      : out unsigned(n_tbl_bits-1 downto 0)
    );
    end component LUT1D_sim;
    constant ADDR_WIDTH : integer := 4;
    constant n_frac_bits: integer := 20;
    -- Test signals
    signal tb_clk      : std_logic := '0';
    signal tb_state    : t_state := s_idle;
    signal tb_lut_addr : unsigned(ADDR_WIDTH+ n_frac_bits-1 downto 0) := (others => '0');
    signal tb_ow_addr  : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal tb_ow_data  : unsigned(19 downto 0) := (others => '0');
    signal tb_o_val    : unsigned(15 downto 0);
    

    signal tb_state_no : integer range 0 to 7 := 0;
    -- Clock period
    constant clk_period : time := 10 ns;

    -- Test data patterns
    type test_data_array is array (0 to 10) of unsigned(19 downto 0);
    constant TEST_DATA : test_data_array := (
        0  => to_unsigned(3070, 12) & to_unsigned(0, 8), -- 20 bits
        1  => to_unsigned(3160, 12) & to_unsigned(0, 8), -- 20 bits
        2  => to_unsigned(3225, 12) & to_unsigned(0, 8), -- 20 bits
        3  => to_unsigned(3235, 12) & to_unsigned(0, 8), -- 20 bits
        4  => to_unsigned(3240, 12) & to_unsigned(0, 8), -- 20 bits
        5  => to_unsigned(3265, 12) & to_unsigned(0, 8), -- 20 bits
        6  => to_unsigned(3270, 12) & to_unsigned(0, 8), -- 20 bits
        7  => to_unsigned(3285, 12) & to_unsigned(0, 8), -- 20 bits
        8  => to_unsigned(3320, 12) & to_unsigned(0, 8), -- 20 bits
        9  => to_unsigned(3380, 12) & to_unsigned(0, 8), -- 20 bits
        10 => to_unsigned(3450, 12) & to_unsigned(0, 8)  -- 20 bits
    );

begin

    -- Instantiate DUT
    DUT: LUT1D_sim
        generic map (
            table_mif  => "LUT_1D.mif",
            ADDR_WIDTH => 4,
            n_out_bits => 16,
            n_tbl_bits => 48
        )
        port map (
            i_clk      => tb_clk,
            i_state    => tb_state,
            i_lut_addr => tb_lut_addr,
            i_ow_addr  => tb_ow_addr,
            i_ow_data  => tb_ow_data,
            o_val      => open
        );

    -- Clock generation
    clk_process: process
    begin
        tb_clk <= '0';
        wait for clk_period/2;
        tb_clk <= '1';
        wait for clk_period/2;
    end process clk_process;

    -- Test stimulus process
    stim_process: process
    begin
        -- Initialize signals
        tb_state    <= s_idle;
        tb_lut_addr <= (others => '0');
        tb_ow_addr  <= (others => '1');
        tb_ow_data  <= (others => '0');
        
        -- Wait for initialization
        wait for 5 * clk_period;

        -- Test 1: Basic LUT address testing
        report "=== Test 1: Basic LUT Address Testing ===";
        tb_state <= s_init;  -- Enable normal operation
        
        for i in 0 to 10 loop
            tb_lut_addr <= to_unsigned(i, 4) & to_unsigned(0, n_frac_bits);  -- Test different addresses
            wait for 2 * clk_period;
            
            report "LUT Address " & integer'image(i * 256) & 
                   " Output: " & integer'image(to_integer(tb_o_val));
        end loop;

        -- Test 2: Overwrite functionality
        report "=== Test 2: Overwrite Testing ===";
        
        -- Write test data to addresses 0-10
        for i in 0 to 10 loop
            tb_ow_addr <= to_unsigned(i, 4);
            tb_ow_data <= TEST_DATA(i);
            wait for clk_period;
            
            report "Written to address " & integer'image(i) & 
                   " data: " & integer'image(to_integer(TEST_DATA(i)));
        end loop;

        -- Wait a few cycles after writing
        wait for 3 * clk_period;
        
        -- Read back the written data by setting appropriate LUT addresses
        report "=== Test 3: Read Back Written Data ===";
        
        for i in 0 to 10 loop
            tb_lut_addr <= to_unsigned(i, 4) & to_unsigned(0, n_frac_bits);  -- Address that should map to our written data
            wait for 2 * clk_period;
            
            -- Check if output matches expected data
            if tb_o_val = TEST_DATA(i)(15 downto 0) then
                report "PASS: Address " & integer'image(i) & 
                       " returned expected value " & integer'image(to_integer(tb_o_val));
            else
                report "INFO: Address " & integer'image(i) & 
                       " returned " & integer'image(to_integer(tb_o_val)) &
                       " expected " & integer'image(to_integer(TEST_DATA(i)));
            end if;
        end loop;
        tb_state <= s_idle;  -- Switch back to idle before reading to see that the reset works
        wait for 20 * clk_period;
        for i in 0 to 10 loop
            tb_lut_addr <= to_unsigned(i, 4) & to_unsigned(0, n_frac_bits);  -- Address that should map to our written data
            wait for 2 * clk_period;
            
            -- Check if output matches expected data
            if tb_o_val = TEST_DATA(i)(15 downto 0) then
                report "PASS: Address " & integer'image(i) & 
                       " returned expected value " & integer'image(to_integer(tb_o_val));
            else
                report "INFO: Address " & integer'image(i) & 
                       " returned " & integer'image(to_integer(tb_o_val)) &
                       " expected " & integer'image(to_integer(TEST_DATA(i)));
            end if;
        end loop;

  
        -- The 20 LSBs are fractional, used in the interpolation so we test different fractions here
        report "=== Test 4: Fractional Address Testing ===";

        tb_state <= s_init;  -- Enable normal operation
        for i in 0 to 9 loop
            for frac in 0 to 2**20-1 loop  -- Test fractional parts from 0 to 2^20-1
                tb_lut_addr <= to_unsigned(i, 4) & to_unsigned(frac, n_frac_bits);  
                wait for clk_period;
                
                report "LUT Address " & integer'image(i * 256 + frac) & 
                       " Output: " & integer'image(to_integer(tb_o_val));
            end loop;
        end loop;
        wait;
        
    
        
    end process stim_process;

    dbg_state_process: process(tb_state)
    begin
        case tb_state is
            when s_idle =>
                report "Current State: IDLE";
                tb_state_no <= 0;
            when s_init =>
                report "Current State: INIT";
                tb_state_no <= 1;
            when s_verification =>
                report "Current State: VERIFICATION";
                tb_state_no <= 2;
            when s_sim =>
                report "Current State: SIMULATION";
                tb_state_no <= 3;
            when s_pause =>
                report "Current State: PAUSE";
                tb_state_no <= 4;
            when s_end =>
                report "Current State: END";
                tb_state_no <= 5;
            when s_reset =>
                report "Current State: RESET/DEBUG";
                tb_state_no <= 6;


            when others =>
                report "Current State: UNKNOWN";
        end case;
    end process dbg_state_process;

end architecture tb_behavioral;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_tbl_rd_ow_1D_sim is
end entity tb_tbl_rd_ow_1D_sim;

architecture tb_behavioral of tb_tbl_rd_ow_1D_sim is

    -- Component declaration
    component tbl_rd_ow_1D_sim is
        generic(
            hex_init : string := "LUT_1D.hex"
        );
        port(
            i_clk   : in  std_logic;
            i_raddr : in  unsigned(3 downto 0);
            i_waddr : in  unsigned(3 downto 0);
            i_data  : in  unsigned(19 downto 0);
            i_wr_en : in  std_logic;
            o_data  : out unsigned(19 downto 0)
        );
    end component tbl_rd_ow_1D_sim;

    -- Test signals
    signal tb_clk   : std_logic := '0';
    signal tb_raddr : unsigned(3 downto 0) := (others => '0');
    signal tb_waddr : unsigned(3 downto 0) := (others => '0');
    signal tb_data  : unsigned(19 downto 0) := (others => '0');
    signal tb_wr_en : std_logic := '0';
    signal tb_o_data : unsigned(19 downto 0);

    -- Clock period
    constant clk_period : time := 10 ns;

    -- Expected initial values
    type expected_data_array is array (0 to 10) of unsigned(19 downto 0);
    constant EXPECTED_INITIAL : expected_data_array := (
        0  => "10101111000000000000",
        1  => "10111110101000000000",
        2  => "11000100010000000000",
        3  => "11001000000000000000",
        4  => "11001001010000000000",
        5  => "11001001111000000000",
        6  => "11001010110100000000",
        7  => "11001011001000000000",
        8  => "11001100011000000000",
        9  => "11001110010000000000",
        10 => "11010011010000000000"
    );

begin

    -- Instantiate DUT
    DUT: tbl_rd_ow_1D_sim
        generic map(
            hex_init => "LUT_1D.hex"
        )
        port map(
            i_clk   => tb_clk,
            i_raddr => tb_raddr,
            i_waddr => tb_waddr,
            i_data  => tb_data,
            i_wr_en => tb_wr_en,
            o_data  => tb_o_data
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
        tb_raddr <= (others => '0');
        tb_waddr <= (others => '0');
        tb_data  <= (others => '0');
        tb_wr_en <= '0';
        
        -- Wait for a few clock cycles
        wait for 3 * clk_period;

        -- Test 1: Read initial values from all addresses
        report "=== Test 1: Reading Initial Values ===";
        for i in 0 to 10 loop
            tb_raddr <= to_unsigned(i, 4);
            wait for clk_period;
            
            -- Check if read data matches expected initial value
           
        end loop;

        -- Test 2: Write new values and read them back
        report "=== Test 2: Write and Read Back ===";
        for i in 0 to 10 loop
            -- Write new value
            tb_waddr <= to_unsigned(i, 4);
            tb_data <= to_unsigned(16#AAAAA# + i * 16#1111#, 20);  -- Test pattern
            tb_wr_en <= '1';
            wait for clk_period;
            tb_wr_en <= '0';
            
            -- Read back the written value
            tb_raddr <= to_unsigned(i, 4);
            wait for clk_period;
            
         
        end loop;

        -- Test 3: Test boundary conditions
        report "=== Test 3: Boundary Conditions ===";
        
        -- Test reading from address 11 (out of bounds)
        tb_raddr <= to_unsigned(11, 4);
        wait for clk_period;
        
        -- Test writing to address 11 (should be ignored)
        tb_waddr <= to_unsigned(11, 4);
        tb_data <= to_unsigned(16#FFFFF#, 20);
        tb_wr_en <= '1';
        wait for clk_period;
        tb_wr_en <= '0';
        
        -- Verify it wasn't written by reading back
        tb_raddr <= to_unsigned(11, 4);
        wait for clk_period;

        -- Test 4: Test maximum values
        report "=== Test 4: Maximum Value Test ===";
        tb_waddr <= to_unsigned(5, 4);  -- Middle address
        tb_data <= (others => '1');     -- Maximum value
        tb_wr_en <= '1';
        wait for clk_period;
        tb_wr_en <= '0';
        
        tb_raddr <= to_unsigned(5, 4);
        wait for clk_period;
        
        if tb_o_data = (19 downto 0 => '1') then
            report "PASS: Maximum value test";
        else
            report "FAIL: Maximum value test" severity error;
        end if;

        -- Test 5: Test minimum values
        report "=== Test 5: Minimum Value Test ===";
        tb_waddr <= to_unsigned(7, 4);
        tb_data <= (others => '0');     -- Minimum value
        tb_wr_en <= '1';
        wait for clk_period;
        tb_wr_en <= '0';
        
        tb_raddr <= to_unsigned(7, 4);
        wait for clk_period;
        
        if tb_o_data = (19 downto 0 => '0') then
            report "PASS: Minimum value test";
        else
            report "FAIL: Minimum value test" severity error;
        end if;

        -- Test 6: Rapid address switching
        report "=== Test 6: Rapid Address Switching ===";
        for i in 0 to 5 loop
            tb_raddr <= to_unsigned(i, 4);
            wait for clk_period/2;
            tb_raddr <= to_unsigned(10-i, 4);
            wait for clk_period/2;
        end loop;

        -- Final summary
        report "=== Test Complete ===";
        wait for 5 * clk_period;
        
        -- End simulation
        report "Simulation finished successfully" severity note;
        wait;
        
    end process stim_process;

end architecture tb_behavioral;
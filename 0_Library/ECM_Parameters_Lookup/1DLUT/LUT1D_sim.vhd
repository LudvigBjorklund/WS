library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use work.Common.all;
entity LUT1D_sim is
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
end entity LUT1D_sim;


architecture rtl of LUT1D_sim is


component tbl_rd_ow_1D_sim is
    generic(
        hex_init : string := "LUT_1D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;                     -- Clock signal
        i_raddr : in  unsigned(3 downto 0);            -- Read address (4-bit)
        i_waddr : in  unsigned(3 downto 0);            -- Write address (4-bit)
        i_data  : in  unsigned(19 downto 0);           -- 16-bit data input for write
        i_wr_en : in  std_logic;                     -- Write enable signal
        o_data  : out unsigned(19 downto 0)            -- 16-bit data output for read
    );
end component tbl_rd_ow_1D_sim;



component tbl_rd_reset_1D_sim is
    generic(
        hex_init : string := "LUT_1D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;                     -- Clock signal
        i_raddr : in  unsigned(3 downto 0);            -- Read address (4-bit)
        o_data  : out unsigned(19 downto 0)            -- 16-bit data output for read
    );
end component tbl_rd_reset_1D_sim;

signal x11, y11 : unsigned(19 downto 0) := (others => '0');
signal x11_addr, y11_addr : unsigned(3 downto 0) := (others => '0');

signal w1, w2 : unsigned(n_frac_bits-1 downto 0) := (others => '0');
signal pipeline_step : integer range 0 to 2 := 0;

signal r_wr_en : std_logic := '0'; -- Enable writing
signal r_wr_addr : unsigned(3 downto 0) := (others => '0');

signal wr_data : unsigned(19 downto 0) := (others => '0');


signal rst_addr : unsigned(3 downto 0) := (others => '0');
signal rst_data : unsigned(19 downto 0) := (others => '0');


begin
    tbl_1D_rd_ow_x11 : tbl_rd_ow_1D_sim
    generic map (
        hex_init => table_mif
    )
    port map (
        i_clk   => i_clk,
        i_raddr => x11_addr,
        i_waddr => r_wr_addr,
        i_data  => wr_data,
        i_wr_en => r_wr_en,
        o_data  => x11
    );

    tbl_1D_rd_ow_y11 : tbl_rd_ow_1D_sim
    generic map (
        hex_init => table_mif
    )
    port map (
        i_clk   => i_clk,
        i_raddr => y11_addr,
        i_waddr => r_wr_addr,
        i_data  => wr_data,
        i_wr_en => r_wr_en,
        o_data  => y11
    );

    tbl_1D_reset_tables : tbl_rd_reset_1D_sim
    generic map (
        hex_init => table_mif
    )
    port map (
        i_clk   => i_clk,
        i_raddr => rst_addr,
        o_data  => rst_data
    );

    enable_write_process : process(i_clk)
    variable counter_reset : integer range 0 to 3 := 0;
    variable init_done : boolean := false;
    begin
        if rising_edge(i_clk) then
            case i_state is
                when s_idle =>
                -- r_wr_en <= '1';  -- Switch after we add the reset loop
                    if init_done = false then
                        r_wr_en <= '0';
                        init_done := true;
                        counter_reset := 0;
                        rst_addr <= (others => '0');
                        r_wr_addr <= (others => '0');
                    else
                        r_wr_en <= '1';
                    end if;
                    
                    -- In Idle we will add the ability to reset all the table values 
                    x11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3);
                    y11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3);
                    o_val(47 downto 28) <= x11;
                    o_val(27 downto 0) <= (others => '0');
                    -- Two clock delay between read and assgignment
                    if counter_reset < 2 then
                        counter_reset := counter_reset + 1;
                        if counter_reset >= 1 then
                            r_wr_addr <= to_unsigned(0, 4); -- Reset the write address
                            wr_data <= rst_data;
                            rst_addr <= rst_addr + 1;
                        end if;
                    else
                        if rst_addr < to_unsigned(10, 4) then
                            rst_addr <= rst_addr + 1;
                        else
                            rst_addr <= rst_addr; -- Hold address
                        end if;

                        if r_wr_addr < to_unsigned(10, 4) then
                            r_wr_addr <= r_wr_addr + 1;
                            wr_data <= rst_data;
                        else 
                            r_wr_addr <= r_wr_addr; -- Hold address
                            wr_data <= wr_data;
                        end if;
                    end if;
                    pipeline_step <= 0; -- Reset pipeline step
                when s_init => 
                    rst_addr <= (others => '0');
                    counter_reset := 0;
                    
                    r_wr_en <= '1';
                    x11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3);
                    y11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3) + 1;
                    r_wr_addr <= i_ow_addr;
                    
                    wr_data <= i_ow_data;

                    -- Step 1 in pipeline: set weight 1 and weight 2 (inverse)
                    case pipeline_step is
                        when 0 =>
                            w1 <= i_lut_addr(n_frac_bits-1 downto 0);
                            if i_lut_addr(n_frac_bits-1 downto 0) = to_unsigned(0,20) then
                                w2 <= (others => '1');
                            else
                                w2 <= to_unsigned(2**20-1,20) - i_lut_addr(n_frac_bits-1 downto 0); -- 2's complement for inverse
                            end if;
                            pipeline_step <= 1;
                        when 1 =>
                            -- Step 2 in pipeline: perform interpolation 
                          
                            pipeline_step <= 2;
                        when others =>
                            -- Step 3, can keep streaming values 
                            w1 <= i_lut_addr(n_frac_bits-1 downto 0);
                            w2 <= to_unsigned(2**20-1,20) - i_lut_addr(n_frac_bits-1 downto 0); -- 2's complement for inverse
                            o_val(47 downto 8) <= x11 * w2 + y11 * w1;
                    end case;
                when s_sim =>
                    r_wr_en <= '0'; 
                    x11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3);
                    y11_addr <= i_lut_addr(i_lut_addr'high downto i_lut_addr'high-3) + 1;

                    -- Step 1 in pipeline: set weight 1 and weight 2 (inverse)
                    case pipeline_step is
                        when 0 =>
                            w1 <= i_lut_addr(n_frac_bits-1 downto 0);
                            w2 <=to_unsigned(2**20-1,20) - i_lut_addr(n_frac_bits-1 downto 0); -- 2's complement for inverse
                            pipeline_step <= 1;
                        when 1 =>

                           
                            pipeline_step <= 2;
                        when others =>
                            -- Step 3, can keep streaming values 
                            w1 <= i_lut_addr(n_frac_bits-1 downto 0);
                            w2 <= to_unsigned(2**20-1,20) - i_lut_addr(n_frac_bits-1 downto 0); -- 2's complement for inverse
                            o_val(47 downto 8) <= x11 * w2 + y11 * w1;
                    end case;

                    
                when others =>
                    r_wr_en <= '0';
            end case;
        end if;
    end process enable_write_process;


end architecture rtl;
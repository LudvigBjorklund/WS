-- -- Import necessary libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tbl_rd_ow_1D_sim is
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
end entity tbl_rd_ow_1D_sim;

architecture rtl of tbl_rd_ow_1D_sim is


      -- Instantiate the dual-port RAM megafunction (altsyncram)
  bram_inst : altsyncram
    generic map(
      address_aclr_b                    => "NONE",         -- No asynchronous clear for read port address
      address_reg_b                     => "CLOCK0",       -- Clock-register the read address
      clock_enable_input_a              => "BYPASS",       -- Bypass clock enable on port A (write)
      clock_enable_input_b              => "BYPASS",       -- Bypass clock enable on port B (read)
      clock_enable_output_b             => "BYPASS",       -- Bypass clock enable on the read output register
      init_file                         => hex_init,       -- Use generic to name the HEX file containing 16-bit words
      intended_device_family            => "Cyclone V",    -- Specify your target FPGA family
      lpm_type                          => "altsyncram",
      numwords_a                        => 11,            -- Set memory depth for write port (176 words)
      numwords_b                        => 11,            -- Set memory depth for read port (176 words)
      operation_mode                    => "DUAL_PORT",    -- Enable dual-port operation (simultaneous read and write)
      outdata_aclr_b                    => "NONE",         -- No asynchronous clear for read data
      outdata_reg_b                     => "CLOCK0",       -- Read output registered on clock edge
      power_up_uninitialized            => "FALSE",        -- Memory initializes with HEX file contents rather than random data
      read_during_write_mode_mixed_ports=> "OLD_DATA",     -- When reading and writing the same address, output prior (old) data
      widthad_a                         => 4,              -- 8-bit wide address for port A
      widthad_b                         => 4,              -- 8-bit wide address for port B
      width_a                           => 20,             -- 16-bit data width for write port
      width_b                           => 20,             -- 16-bit data width for read port
      width_byteena_a                   => 1               -- Single byte enable (writing whole 16-bit word at once)
    )
    port map(
      clock0    => i_clk,
      data_a    => std_logic_vector(i_data),             -- Write data (converted to std_logic_vector)
      wren_a    => i_wr_en,                              -- Write enable for port A
      address_a => std_logic_vector(i_waddr),            -- Write address (converted to std_logic_vector)
      address_b => std_logic_vector(i_raddr),            -- Read address (converted to std_logic_vector)
      q_b       => mem_out            -- Read data output (converted from std_logic_vector)
    );
type flat_1D_LUT is array (0 to 10) of unsigned(19 downto 0);

signal r_vocv : flat_1D_LUT :=(
 "10101111000000000000", "10111110101000000000", "11000100010000000000", "11001000000000000000", "11001001010000000000", "11001001111000000000", "11001010110100000000", "11001011001000000000", "11001100011000000000", "11001110010000000000", "11010011010000000000"
); -- Total elements: 11


begin
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_wr_en = '1' then
                if i_waddr <= to_unsigned(10, 4) then
                    r_vocv(to_integer(i_waddr)) <= i_data;
                end if;
            end if;
            if i_raddr <= to_unsigned(10, 4) then
                o_data <= r_vocv(to_integer(i_raddr));
            end if;
        end if;
    end process;
end architecture rtl;
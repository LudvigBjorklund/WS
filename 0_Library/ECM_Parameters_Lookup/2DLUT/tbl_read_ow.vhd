
-- -- Import necessary libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Include the Altera megafunction components library
-- For Synthesis, ensure the Altera libraries are available in your project settings
library altera_mf;
use altera_mf.altera_mf_components.all;

entity tbl_read_ow is 
    generic(
        hex_init : string := "LUT_2D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;                     -- Clock signal
        i_raddr : in  unsigned(7 downto 0);            -- Read address (8-bit)
        i_waddr : in  unsigned(7 downto 0);            -- Write address (8-bit)
        i_data  : in  unsigned(15 downto 0);           -- 16-bit data input for write
        i_wr_en : in  std_logic;                     -- Write enable signal
        o_data  : out unsigned(15 downto 0)            -- 16-bit data output for read
    );
end entity tbl_read_ow;

architecture rtl of tbl_read_ow is
    -- Internal signal to connect the megafunction's output
    signal mem_out : std_logic_vector(15 downto 0);



begin

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
      numwords_a                        => 176,            -- Set memory depth for write port (176 words)
      numwords_b                        => 176,            -- Set memory depth for read port (176 words)
      operation_mode                    => "DUAL_PORT",    -- Enable dual-port operation (simultaneous read and write)
      outdata_aclr_b                    => "NONE",         -- No asynchronous clear for read data
      outdata_reg_b                     => "CLOCK0",       -- Read output registered on clock edge
      power_up_uninitialized            => "FALSE",        -- Memory initializes with HEX file contents rather than random data
      read_during_write_mode_mixed_ports=> "OLD_DATA",     -- When reading and writing the same address, output prior (old) data
      widthad_a                         => 8,              -- 8-bit wide address for port A
      widthad_b                         => 8,              -- 8-bit wide address for port B
      width_a                           => 16,             -- 16-bit data width for write port
      width_b                           => 16,             -- 16-bit data width for read port
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
   
  -- Map the internal signal to the entity's output
  o_data <= unsigned(mem_out);

end architecture rtl;


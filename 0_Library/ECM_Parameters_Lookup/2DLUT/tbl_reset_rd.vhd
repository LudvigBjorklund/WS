-- Import necessary libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- -- Include the Altera megafunction components library
library altera_mf;
use altera_mf.altera_mf_components.all;

entity tbl_reset_rd is 
    generic(
        hex_init : string := "LUT_2D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;           -- Clock signal
        i_raddr : in  unsigned(7 downto 0); -- Read address (8-bit)
        o_data  : out unsigned(15 downto 0) -- 16-bit data output for read
    );
end entity tbl_reset_rd;

architecture rtl of tbl_reset_rd is


    -- Internal signal to connect the megafunction's output
    signal mem_out : std_logic_vector(15 downto 0);
begin
    -- Instantiate the ROM megafunction (altsyncram in ROM mode)
    rom_inst : altsyncram
    generic map(
       clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => hex_init,
		intended_device_family => "Cyclone V",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 176,
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "CLOCK0",
		power_up_uninitialized => "FALSE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		widthad_a => 8,
		width_a => 16,
		width_byteena_a => 1
	)
    port map(
        clock0    => i_clk,
        address_a => std_logic_vector(i_raddr),  -- Read address (converted to std_logic_vector)
        q_a       => mem_out                     -- Read data output
    );

    -- Map the internal signal to the entity's output
    o_data <= unsigned(mem_out);
end architecture rtl;
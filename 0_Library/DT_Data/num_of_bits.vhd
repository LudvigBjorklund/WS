-- filepath: /home/ludvig/Desktop/FPGA Synthesis/0. Library/DT_Data/DT_Constants.vhd
library IEEE;
use IEEE.std_logic_1164.all;

package num_of_bits is

    -- Platform settings
    constant n_b_state : integer := 3; -- Number of bits to represent the state signal
    constant n_b_dp_RX : integer := 24; -- Number of bits per data packet (signal) in RX
    constant n_b_dp_TX : integer := 24; -- Number of bits per data packet (signal) in TX
    
    -- Variables
    constant n_b_dV : integer := 48; -- Voltage 11EN37
    constant n_b_I  : integer := 16; 
    constant n_b_SOC : integer := 24;

    -- ECM Parameters
    constant n_b_R0 : integer := 16;
    constant n_b_a : integer := 16; 
    constant n_b_c : integer := 16;

    constant n_b_Q : integer := 16;

    constant n_b_ow_addr : integer := 8; -- For all overwrite addresses
    constant n_b_2D_LUT_dp :integer := 16; -- Dimensions of the 2D LUT data cell-elements

end package num_of_bits;
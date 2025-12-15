library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package Common is

    type t_state is (s_idle, s_init, s_sim,s_verification, s_reset,  s_pause, s_end);
    type array_16char_mif is array(natural range <>) of string(1 to 16);
end Common;

library IEEE;
use IEEE.std_logic_1164.all;
use work.num_of_bits.all;


package fixed_point_formats is
------------------------------ Formatting Fixed-Point -------------------------------------
---- Variables (int)
constant fmt_int_dV : integer := 11; -- Same for both
constant fmt_int_I : integer := 4;
constant fmt_int_SOC : integer := 7;
---- Variables (frac)
constant fmt_frac_dV : integer := n_b_dV - fmt_int_dV;
constant fmt_frac_I : integer := n_b_I - fmt_int_I;
constant fmt_frac_SOC : integer := n_b_SOC - fmt_int_SOC;

---- ECM Parameters (int)
constant fmt_int_R0 : integer := 8;
constant fmt_int_a1 : integer := -5;
constant fmt_int_c1 : integer := 0;
constant fmt_int_a2 : integer := -7;
constant fmt_int_c2 : integer := -5;
constant fmt_int_Q  : integer := -8;

---- ECM Parameters (frac)
constant fmt_frac_R0 : integer := n_b_R0 - abs(fmt_int_R0);
constant fmt_frac_a1 : integer := n_b_a - abs(fmt_int_a1);
constant fmt_frac_c1 : integer := n_b_c - abs(fmt_int_c1);
constant fmt_frac_c2 : integer := n_b_c - abs(fmt_int_c2);
constant fmt_frac_a2 : integer := n_b_a - abs(fmt_int_a2);
constant fmt_frac_Q  : integer := n_b_Q - abs(fmt_int_Q);

end package fixed_point_formats;
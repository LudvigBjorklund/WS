-- filepath: /home/ludvig/Documents/Digital Twin/Version 1/Version 7 - SOC Calc and dVRC/FPGA/Test-benches/3_TL_DT_added_DT_RX/prepare_for_bcd0EN16.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prepare_for_bcd0EN16 is
   port(
       i_clk : in std_logic;
       i_r_c1 : in unsigned(15 downto 0); -- Assuming 16-bit input for r_c1
       o_c1_bcd_i : out unsigned(19 downto 0)
   );
end entity prepare_for_bcd0EN16;

architecture rtl of prepare_for_bcd0EN16 is
   constant c_0EN16_bin : unsigned(18 downto 0) := "1111010000100100000"; 
   constant c_0EN16_bin_6to3 : unsigned(19 downto 0) := "10001001010101000100"; --5625000 0.5625
   constant c_0EN16_bin_2to0 : unsigned(19 downto 0) := "01111110010111001010";
   
   signal r_c1 : unsigned(15 downto 0) := (others => '0');
   signal r_iter_0EN16 : integer range 0 to 15 := 15;
   signal C1_digit_converted : unsigned(19 downto 0) := (others => '0');
   signal c1_extra_bits : unsigned(23 downto 0) := (others => '0');
   signal c1_bcd_i : unsigned(19 downto 0) := (others => '0');
begin
   process(i_clk)
   begin
       if rising_edge(i_clk) then
           if r_iter_0EN16 > 0 then
               if r_c1(r_iter_0EN16) = '1' then
                   C1_digit_converted <= C1_digit_converted + c_0EN16_bin(18 downto 15 - r_iter_0EN16);
                   if r_iter_0EN16 < 10 then
                       if r_iter_0EN16 < 7 then
                           if r_iter_0EN16 < 3 then
                               c1_extra_bits <= c1_extra_bits + c_0EN16_bin_2to0(19 downto 2 - r_iter_0EN16);
                           else
                               c1_extra_bits <= c1_extra_bits + c_0EN16_bin_6to3(19 downto 6 - r_iter_0EN16);
                           end if;
                       else
                           c1_extra_bits <= c1_extra_bits + c_0EN16_bin(18 downto 9 - r_iter_0EN16);
                       end if;
                   else
                       null;
                   end if;
               end if;
               r_iter_0EN16 <= r_iter_0EN16 - 1;
           else
               r_c1 <= i_r_c1;
               r_iter_0EN16 <= 15;
               C1_digit_converted <= (others => '0');
               c1_extra_bits <= (others => '0');
               if c1_extra_bits > 1000000 then
                   if c1_extra_bits > 2000000 then
                       if r_c1(r_iter_0EN16) = '1' then
                           c1_bcd_i <= C1_digit_converted + c_0EN16_bin(18 downto 15 - r_iter_0EN16) + 2;
                       else
                           c1_bcd_i <= C1_digit_converted + 2;
                       end if;
                   else
                       if r_c1(r_iter_0EN16) = '1' then
                           c1_bcd_i <= C1_digit_converted + c_0EN16_bin(18 downto 15 - r_iter_0EN16) + 1;
                       else
                           c1_bcd_i <= C1_digit_converted + 1;
                       end if;
                   end if;
               else
                   if r_c1(r_iter_0EN16) = '1' then
                       c1_bcd_i <= C1_digit_converted + c_0EN16_bin(18 downto 15 - r_iter_0EN16);
                   else
                       c1_bcd_i <= C1_digit_converted;
                   end if;
               end if;
           end if;
       end if;
   end process;

   o_c1_bcd_i <= c1_bcd_i;
end architecture rtl;

-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;

-- entity prepare_for_bcd0EN16 is
--     port(
--         i_clk : in std_logic;
--         i_r_c1 : in unsigned(15 downto 0); -- Assuming 16-bit input for r_c1
--         o_c1_bcd_i : out unsigned(19 downto 0)
--     );
-- end entity prepare_for_bcd0EN16;

-- architecture rtl of prepare_for_bcd0EN16 is
--     constant c_0EN16_bin : unsigned(18 downto 0) := "1111010000100100000"; 
--     constant c_0EN16_bin_6to3 : unsigned(19 downto 0) := "10001001010101000100"; --5625000 0.5625
--     constant c_0EN16_bin_2to0 : unsigned(19 downto 0) := "01111110010111001010";
    
--     signal r_c1 : unsigned(15 downto 0) := (others => '0');
--     signal r_iter_0EN16 : integer range 0 to 15 := 15;
--     signal C1_digit_converted : unsigned(19 downto 0) := (others => '0');
--     signal c1_extra_bits : unsigned(23 downto 0) := (others => '0');
--     signal c1_bcd_i : unsigned(19 downto 0) := (others => '0');
-- begin
--     process(i_clk)
--         variable temp_concat : unsigned(18 downto 0);
--     begin
--         if rising_edge(i_clk) then
--             if r_iter_0EN16 > 0 then
--                 if r_c1(r_iter_0EN16) = '1' then
--                     -- Fix: Create the concatenated value first, then resize it
--                     temp_concat := to_unsigned(to_integer(c_0EN16_bin(18 downto 15 - r_iter_0EN16)),20);
--                     C1_digit_converted <= C1_digit_converted + resize(temp_concat, 20);
                    
--                     if r_iter_0EN16 < 10 then
--                         if r_iter_0EN16 < 7 then
--                             if r_iter_0EN16 < 3 then
--                                 c1_extra_bits <= c1_extra_bits + resize(c_0EN16_bin_2to0(19 downto 2 - r_iter_0EN16), 24);
--                             else
--                                 c1_extra_bits <= c1_extra_bits + resize(c_0EN16_bin_6to3(19 downto 6 - r_iter_0EN16), 24);
--                             end if;
--                         else
--                             c1_extra_bits <= c1_extra_bits + resize(c_0EN16_bin(18 downto 9 - r_iter_0EN16), 24);
--                         end if;
--                     else
--                         null;
--                     end if;
--                 end if;
--                 r_iter_0EN16 <= r_iter_0EN16 - 1;
--             else
--                 r_c1 <= i_r_c1;
--                 r_iter_0EN16 <= 15;
--                 C1_digit_converted <= (others => '0');
--                 c1_extra_bits <= (others => '0');
--                 if c1_extra_bits > 1000000 then
--                     if c1_extra_bits > 2000000 then
--                         if r_c1(r_iter_0EN16) = '1' then
--                             c1_bcd_i <= C1_digit_converted + resize(c_0EN16_bin(18 downto 15 - r_iter_0EN16), 20) + 2;
--                         else
--                             c1_bcd_i <= C1_digit_converted + 2;
--                         end if;
--                     else
--                         if r_c1(r_iter_0EN16) = '1' then
--                             c1_bcd_i <= C1_digit_converted + resize(c_0EN16_bin(18 downto 15 - r_iter_0EN16), 20) + 1;
--                         else
--                             c1_bcd_i <= C1_digit_converted + 1;
--                         end if;
--                     end if;
--                 else
--                     if r_c1(r_iter_0EN16) = '1' then
--                         c1_bcd_i <= C1_digit_converted + resize(c_0EN16_bin(18 downto 15 - r_iter_0EN16), 20);
--                     else
--                         c1_bcd_i <= C1_digit_converted;
--                     end if;
--                 end if;
--             end if;
--         end if;
--     end process;
    
--     o_c1_bcd_i <= c1_bcd_i;
-- end architecture rtl;
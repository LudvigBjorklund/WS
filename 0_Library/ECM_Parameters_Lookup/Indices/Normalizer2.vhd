library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Normalizer2 is
    generic(
        wd_in       : integer := 16;
        wd_norm_in  : integer := 16;
        wd_out      : integer := 32
    );
    port(
        i_clk   : in std_logic;
        i_val   : in unsigned(wd_in - 1 downto 0);
        i_norm  : in unsigned(wd_norm_in - 1 downto 0); -- Special case when only 0
        o_val   : out unsigned(wd_out - 1 downto 0)
    );
end entity Normalizer2;

architecture rtl of Normalizer2 is
signal r_val : unsigned(wd_in+wd_norm_in-1 downto 0); 
begin 

    -- Normalizer process
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- Normalize the input value
            if i_norm = to_unsigned(0,wd_norm_in) then
                r_val(wd_in+wd_norm_in - 1 downto wd_in) <= i_val(wd_in-1 downto (wd_in-wd_norm_in)); -- Set to zero if normalization is zero
            else
               r_val <= i_val*i_norm; 
            end if;
        end if;
    end process;
    o_val <= r_val(wd_in+wd_norm_in - 1  downto wd_in+wd_norm_in -wd_out); -- Output the normalized value

end architecture rtl;
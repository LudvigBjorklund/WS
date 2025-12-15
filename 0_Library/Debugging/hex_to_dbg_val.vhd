library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hex_to_dbg_val is
    port(
        i_clk    : in std_logic;
        i_hex0, i_hex1, i_hex2, i_hex3, i_hex4, i_hex5 : in std_logic_vector(6 downto 0); -- 7-segment display inputs
        o_dbg_val : out integer range 0 to 999999 -- Output integer value (0 to 999999)
    );
end entity hex_to_dbg_val;

architecture rtl of hex_to_dbg_val is

    component hex_to_int is
        port(
            i_clk : in std_logic;
            i_hex : in std_logic_vector(6 downto 0); -- 7-segment display input
            o_int : out integer range 0 to 9 -- Integer output (0 to 9)
        );
    end component hex_to_int;

    -- Internal signals to hold the binary values for each HEX digit
    signal r_int0, r_int1, r_int2, r_int3, r_int4, r_int5 : integer range 0 to 9 := 0;
    
    -- Internal signal for the combined value
    signal r_dbg_val : integer range 0 to 999999 := 0;
    
begin
    -- Instantiate hex_to_int for each HEX digit
    U0_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex0,
            o_int => r_int0
        );

    U1_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex1,
            o_int => r_int1
        );

    U2_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex2,
            o_int => r_int2
        );

    U3_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex3,
            o_int => r_int3
        );

    U4_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex4,
            o_int => r_int4
        );

    U5_hex_to_int: hex_to_int
        port map(
            i_clk => i_clk,
            i_hex => i_hex5,
            o_int => r_int5
        );

    -- Combine the individual integer values into a single integer output
    process(r_int0, r_int1, r_int2, r_int3, r_int4, r_int5)
    begin
        r_dbg_val <= r_int5 * 100000 +
                     r_int4 * 10000 +
                     r_int3 * 1000 +
                     r_int2 * 100 +
                     r_int1 * 10 +
                     r_int0;
    end process;

    -- Assign internal signal to output
    o_dbg_val <= r_dbg_val;

end architecture;
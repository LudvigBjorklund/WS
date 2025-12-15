
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity idx_calc is
    generic(
        wd_in       : integer := 16;
        wd_out      : integer := 12;
        g_init_SOC  : integer := 0 -- Initial value for SOC | Integer part only
    );
    port(
        i_clk   : in std_logic;
        i_SOC   : in unsigned(wd_in - 1 downto 0);
        i_I     : in unsigned(wd_in - 1 downto 0); -- Special case when only 0
        o_rowidx : out unsigned(wd_out - 1 downto 0) := (others => '0'); -- Initialize row index output
        o_colidx : out unsigned(wd_out - 1 downto 0) := (others => '0'); -- Initialize column index output
        o_done  : out std_logic := '0'; -- Indicate that initialization is done
        o_busy  : out std_logic := '0' -- Indicate that the module is busy
    );
end entity idx_calc; 

architecture rtl of idx_calc is  
-- Component Normalizer 
component Normalizer
    generic(
        wd_in       : integer;
        wd_norm_in  : integer;
        wd_out      : integer
    );
    port(
        i_clk   : in std_logic;
        i_val   : in unsigned(wd_in - 1 downto 0);
        i_norm  : in unsigned(wd_norm_in - 1 downto 0); -- Special case when only 0
        o_val   : out unsigned(wd_out - 1 downto 0)
    );
end component;

    -- We output 16 bits for the Normalizer, then we slice it to 12 bits
    constant wd_out_norm : integer := 12; -- Output width for row and column indices
    constant wd_norm_in  : integer := 16; -- Normalized input width
    -- Constants for the NORMs
    constant c_Inorm    : unsigned(wd_norm_in - 1 downto 0) := (others => '0');
    constant c_SOCnorm  : unsigned(wd_norm_in - 1 downto 0) :="0001100110011010"; --"0001100110011001"; -- Shifted 3
    constant c_init_SOC : unsigned(wd_in - 1 downto 0) := to_unsigned(g_init_SOC, 7) & to_unsigned(0, wd_in-7); -- Initial value for SOC

    signal r_SOC : unsigned(wd_in - 1 downto 0) := c_init_SOC; -- Register the SOC value
    signal r_I : unsigned(wd_in - 1 downto 0) := (others => '0'); -- Register the I value
    signal i_val2conv : unsigned(wd_in - 1 downto 0) := (others => '0'); -- Input value to be normalized
    signal i_val2conv_norm : unsigned(wd_norm_in - 1 downto 0) := (others => '0'); -- Normalized input value
    signal r_idx : unsigned(15 downto 0); -- Register the index
    signal r_rowidx : unsigned(wd_out - 1 downto 0):= (others => '0'); -- Register the row index
    signal r_colidx : unsigned(wd_out - 1 downto 0):= (others => '0'); -- Register the column index


    -- NEw signals from 24th june 2025
    signal r_init_done : std_logic := '0';
    signal r_busy : std_logic := '0';

    signal dbg_switch_normalizer_input : std_logic := '0'; -- Debug signal to track Normalizer input switching

    signal r_prev_inp : unsigned(wd_in*2 - 1 downto 0) := (others => '0'); -- Register the previous input value
begin
    -- Instantiate the Normalizer component for the indices
    Index_normalizer: Normalizer
        generic map(
            wd_in       => wd_in,
            wd_norm_in  => wd_norm_in,
            wd_out      => wd_out_norm+4
        )
        port map(
            i_clk   => i_clk,
            i_val   => i_val2conv,
            i_norm  => i_val2conv_norm,
            o_val   => r_idx
        );

    process(i_clk)
    variable v_switch_normalizer_input : std_logic := '0'; -- Variable to switch input for Normalizer
    variable v_first_init : std_logic := '0'; -- Variable to track the first initialization
    begin 
        if rising_edge(i_clk) then
            dbg_switch_normalizer_input <= v_switch_normalizer_input; -- Debug signal assignment

            if r_init_done = '1' then
                if v_first_init = '1' then
                    if v_switch_normalizer_input = '0' then
                        v_switch_normalizer_input := '1'; -- Switch to column input next
                        i_val2conv <= i_I;  -- Use SOC for row
                        i_val2conv_norm <= c_Inorm; -- Use SOC for row
                        r_rowidx <= r_idx(15 downto 4); -- Store the row
                        o_busy <= '0'; 
                    else
                        v_switch_normalizer_input := '0'; 
                        r_colidx <= r_idx(12 downto 1); 
                        i_val2conv <= i_SOC; 
                        i_val2conv_norm <= c_SOCnorm; -- Use I for column
                        o_rowidx <= r_rowidx; -- Output row index
                        o_colidx <= r_idx(12 downto 1); -- Output column index
                        -- if r_prev_inp /= (i_SOC & i_I) then -- Check if the input has changed
                        --     r_prev_inp <= (i_SOC & i_I); -- Update the previous input value
                        --     o_busy <= '1'; -- Set busy signal to low
                        -- end if;
                        o_done <= '1'; -- Set done signal 
                    end if;
                else -- Change the input for the Normalizer
                    v_first_init := '1'; 
                    i_val2conv <= i_SOC;  -- Use SOC for row
                    i_val2conv_norm <= c_SOCnorm; -- Use SOC for row
                    o_colidx <= (others => '0'); -- Reset column index output
                    o_rowidx <= (others => '0'); -- Reset row index output
                end if;
            else
                i_val2conv <= i_I; 
                i_val2conv_norm <= c_Inorm; -- Use I for column
                r_init_done <= '1'; -- Set the initialization done flag
                o_colidx <= (others => '0'); -- Reset column index output
                o_rowidx <= (others => '0'); -- Reset row index output
            end if;
        end if;
    end process;    
        
end architecture rtl;
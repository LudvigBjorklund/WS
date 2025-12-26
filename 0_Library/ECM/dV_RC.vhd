library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dV_RC is
    generic (
        timestep : integer := 10; -- 2⁽-10) is the dt 
        n_bits_c : integer := 16;
        n_bits_a : integer := 16;
        n_bits_I : integer := 16;
        n_bits_dV : integer := 48; 
        init_dV : unsigned(47 downto 0) := (others => '0'); -- Initial value for dV
        n_int_a : integer := -5;
        n_frac_a: integer := 16;
        n_int_c : integer := 0;
        n_frac_c: integer := 16;
        n_int_I : integer := 4;
        n_frac_I : integer := 12;
        n_int_dV: integer := 11; -- Number of integer bits in dV, used for formatting
        n_frac_dV: integer := 37 -- Number of fractional bits in dV, used for formatting
    );
    port(
        i_clk  : in std_logic;
        i_rst  : in std_logic;
        i_strt : in std_logic;
        i_step : in std_logic;
        i_c    : in unsigned(n_bits_c - 1 downto 0); -- 0EN16
        i_a    : in unsigned(n_bits_a - 1 downto 0); -- -5EN16
        i_I    : in unsigned(n_bits_I - 1 downto 0); -- 0EN16
        o_dV   : out unsigned(n_bits_dV - 1 downto 0)  -- 0EN48
    );
end dV_RC;

architecture rtl of dV_RC is

        -- helper: return abs(x) if x<0 else 0
    function neg_int_to_shift(x: integer) return integer is
    begin
        if x < 0 then
            return abs(x);
        else
            return 0;
        end if;
    end function;

    function max(a: integer; b: integer) return integer is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function;
    -- filepath: /home/ludvig/Documents/Digital Twin/Version 1/V_6_dVRC1_2/ECM/dV_RC.vhd
    function calc_frac_bits(n_int_c, n_frac_c, n_int_I, n_frac_I: integer) return integer is
    begin
        if n_int_c < 0 or n_int_I < 0 then
            return max(n_frac_c, n_frac_I);
        else
            return neg_int_to_shift(n_int_c) + n_frac_c + neg_int_to_shift(n_int_I) + n_frac_I;
        end if;
    end function;


    -- Reduce to 3-step FSM by merging subtraction and formatting into one step
    signal initialization_step : integer range 0 to 2 := 0;
    -- Formatting constants

    signal c_t1_newfmt : integer := n_int_c+ n_int_I;
    signal c_t1_fnewfmt: integer := neg_int_to_shift(n_int_c) + n_frac_c + neg_int_to_shift(n_int_I) + n_frac_I;
    signal c_t2_newfmt : integer := n_int_a + n_int_dV;
    signal c_t2_fnewfmt : integer := neg_int_to_shift(n_int_a) + n_frac_a + neg_int_to_shift(n_int_dV) + n_frac_dV;

    signal c_msb_t3_add : integer := n_int_dV - c_t2_newfmt;
    signal c_msb_t3_add_timeshift : integer := timestep;
    signal c_msb_t1_add : integer := c_t2_newfmt - c_t1_newfmt;
    signal c_lsb_t1_add : integer := c_t2_fnewfmt - c_t1_fnewfmt;

    constant c_init_dV : unsigned(47 downto 0) := init_dV;
    -- Pipeline Registers for Intermediate Calculations


    ----------------------------------------------------------------------------
    -- Stage 1: Multiply inputs (width calculated so that the sign bit is skipped).
    signal stage1_t1 : unsigned(n_bits_a + n_bits_dV - 2 downto 0) := (others => '0'); --(n_bits_c + n_bits_I - 2
    signal stage1_t2 : unsigned(n_bits_a + n_bits_dV - 2 downto 0) := (others => '0');

    signal t1 : unsigned(n_bits_c + n_bits_I - 1 downto 0) := (others => '0');
    signal r_t1 : unsigned(c_t1_newfmt + c_t1_fnewfmt + c_msb_t1_add + c_lsb_t1_add - 1 downto 0) := (others => '0');
    signal r_t2 : unsigned(c_t2_newfmt + c_t2_fnewfmt - 1 downto 0) := (others => '0');
    signal r_t3 : unsigned(c_t2_newfmt + c_t2_fnewfmt - 1 downto 0) := (others => '0');
    signal t2 : unsigned(n_bits_a + n_bits_dV - 1 downto 0) := (others => '0');


    signal negative_result : std_logic := '0';
    -- Storing the dV_RC of th same instance as the stage 1 calculations
    signal r_dV : unsigned(n_bits_dV - 1 downto 0) := (others => '0');

    -- signal dbg_len_t1 : integer := 0;
    -- signal dbg_len_t2 : integer := 0;
    -- signal dbg_len_t3 : integer := 0;
    -- -- Debugging signals
    -- signal dbg_n_int_a : integer := n_int_a;
    -- signal dbg_n_frac_a: integer := n_frac_a;
    -- signal dbg_n_int_c : integer := n_int_c;
    -- signal dbg_n_frac_c: integer := n_frac_c;
    -- signal dbg_n_int_I : integer := n_int_I;
    -- signal dbg_n_frac_I : integer := n_frac_I;
    -- signal dbg_n_int_dV: integer := n_int_dV;
    -- signal dbg_n_frac_dV: integer := n_frac_dV;
    begin
        process(i_clk)
            -- Local variable to hold the intermediate subtraction result when merging steps
            variable v_t3_alt : unsigned(c_t2_newfmt + c_t2_fnewfmt - 1 downto 0);
        begin
            if rising_edge(i_clk) then
                -- dbg_len_t1 <= r_t1'length;
                -- dbg_len_t2 <= r_t2'length;
                -- dbg_len_t3 <= r_t3'length;
                if i_strt = '1' then
                    case initialization_step is
                        when 0 =>
                            -- ONLY THE VERY FIRST STEP
                            if i_step = '1' then
                            -- Calculating only stage 1 term 
                            r_t1(r_t1'left - c_msb_t1_add downto c_lsb_t1_add) <= i_c * i_I;
                            r_t2 <= r_dV*i_a;
                            

                            initialization_step <= 1;
                            end if;

                        when 1 => 
                            if r_t1(r_t1'left downto c_msb_t3_add+c_msb_t3_add_timeshift) < r_t2(r_t2'left downto c_msb_t3_add+c_msb_t3_add_timeshift) then
                                negative_result <= '1';
                            else
                                negative_result <= '0';
                            end if;
                            -- Calculate subtraction and formatting in the same cycle (merged step)
                            v_t3_alt(v_t3_alt'left downto c_msb_t3_add+c_msb_t3_add_timeshift) := (others => '0');
                            v_t3_alt(v_t3_alt'left - c_msb_t3_add -c_msb_t3_add_timeshift downto 0) := (r_t1(r_t1'left downto c_msb_t3_add+c_msb_t3_add_timeshift) - r_t2(r_t2'left downto c_msb_t3_add+c_msb_t3_add_timeshift));
                            r_t3 <= v_t3_alt; -- Store the subtraction result in r_t3 for debugging
                            initialization_step <= 2;
                        when 2 =>
                            -- Commit the result when a step pulse arrives and prepare next Stage 1 in the same cycle
                            if i_step = '1' then
                                r_t1(r_t1'left - c_msb_t1_add downto c_lsb_t1_add) <= i_c * i_I;
                                r_t2 <=(r_dV + r_t3(r_t3'left downto r_t3'left - n_bits_dV +1))*i_a;
                                r_dV <= r_dV + r_t3(r_t3'left downto r_t3'left - n_bits_dV +1);
                                o_dV <= r_dV + r_t3(r_t3'left downto r_t3'left - n_bits_dV +1);

                                initialization_step <= 1; -- Loop back to merged compute step
                            end if;
                        when others =>
                            null;
                    end case;

                else
                    initialization_step <= 1;
                    r_dV <=  c_init_dV;  
                    o_dV <= c_init_dV; -- Initial value for dV output
                end if;
            end if;
        end process;

end rtl;    
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;    

entity ECM_Parameters is
    generic(
        simulation_build : boolean := FALSE; 
        g_init_SOC : unsigned(15 downto 0) := to_unsigned(0, 16); -- Initial value for SOC (Integer part only)
        g_init_I   : unsigned(15 downto 0) := to_unsigned(0, 16); -- Initial value for I (Integer part only)
        g_wd_in     : integer := 16; -- Width of input data (i_SOC and i_I)
        g_wd_idx  : integer := 12; -- Width of output indices (o_rowidx and o_colidx)
        mif_R0    : string := "R0.mif"; -- MIF file for R0 table
        mif_a1    : string := "a1.mif"; -- MIF file for a1 table
        mif_c1    : string := "c1.mif";
        mif_a2    : string := "a2.mif"; -- MIF file for a2 table
        mif_c2    : string := "c2.mif" -- MIF file for c2 table
    );
    port(
        i_clk     : in std_logic;
        i_state   : in t_state;  
        i_SOC     : in unsigned(g_wd_in - 1 downto 0);
        i_I       : in unsigned(g_wd_in - 1 downto 0);
        i_ow_R0_addr : in unsigned(7 downto 0);
        i_ow_R0   : in unsigned(15 downto 0); 
		i_ow_a1_addr : in unsigned(7 downto 0);
		i_ow_a1   : in unsigned(15 downto 0);
        i_ow_c1_addr : in unsigned(7 downto 0);
        i_ow_c1   : in unsigned(15 downto 0);
        i_ow_a2_addr : in unsigned(7 downto 0);
        i_ow_a2   : in unsigned(15 downto 0);
        i_ow_c2_addr : in unsigned(7 downto 0);
        i_ow_c2   : in unsigned(15 downto 0);
        o_R0      : out unsigned(15 downto 0); 
		o_a1	  : out unsigned(15 downto 0);
        o_c1      : out unsigned(15 downto 0);
        o_a2      : out unsigned(15 downto 0);
        o_c2      : out unsigned(15 downto 0);
        o_done    : out std_logic;
        o_busy    : out std_logic
    );
end entity ECM_Parameters;

architecture rtl of ECM_Parameters is

component idx_calc is
    generic(
        wd_in       : integer := 16;
        wd_out      : integer := 12;
        g_init_SOC  : integer := 0 -- Initial value for SOC | Integer part only
    );
    port(
        i_clk   : in std_logic;
        i_SOC   : in unsigned(wd_in - 1 downto 0);
        i_I     : in unsigned(wd_in - 1 downto 0); -- Special case when only 0
        o_rowidx : out unsigned(wd_out - 1 downto 0);
        o_colidx : out unsigned(wd_out - 1 downto 0);
        o_done  : out std_logic := '0';
		o_busy  : out std_logic := '0' 
    );
end component idx_calc; 


component LUT2D is 
    generic(
    table_name : string := "R0";
    table_mif : string := "R0.mif";
    x11_init   : unsigned(15 downto 0) := (others => '0')
    );
    port(
        i_clk   : in std_logic;
        i_state : in t_state;
        i_ridx  : in unsigned(11 downto 0);
        i_cidx  : in unsigned(11 downto 0);
        i_ow_addr : in unsigned(7 downto 0);
        i_ow_data : in unsigned(15 downto 0);
        o_val     : out unsigned(15 downto 0);
        o_busy    : out std_logic
    );
end component LUT2D;

    signal r_rowidx : unsigned(g_wd_idx - 1 downto 0);
    signal r_colidx : unsigned(g_wd_idx - 1 downto 0);

    signal r_I : unsigned(g_wd_in - 1 downto 0) := (others => '0'); -- Register the I value
    signal r_SOC : unsigned(g_wd_in - 1 downto 0) := (others => '0'); -- Register the SOC value

    signal r_idx_done : std_logic := '0'; -- Signal to indicate that the index calculation is done
    signal r_idx_busy : std_logic := '0'; -- Signal to indicate that the index
    signal r_busy_tbl_rd : std_logic := '0'; -- Signal to indicate if the LUT2D is busy reading
    signal r_busy_tbl_wr : std_logic := '0'; -- Signal to indicate if the
    signal r_R0 : unsigned(15 downto 0) := (others => '0'); -- Register the R0 value
    signal r_R0_alt : unsigned(15 downto 0) := (others => '0');

    -- Busy signals
    signal r_R0_2d_busy : std_logic := '0';
    signal r_a1_2d_busy : std_logic := '1';
    signal r_c1_2d_busy : std_logic := '1';
    signal r_a2_2d_busy : std_logic := '1';
    signal r_c2_2d_busy : std_logic := '1';

begin
    -- Instantiate the idx_calc component
    idx_calc_UUT: idx_calc
    generic map(
        wd_in => g_wd_in,
        wd_out => g_wd_idx)
    port map(
        i_clk => i_clk,
        i_SOC => r_SOC,
        i_I => r_I,
        o_rowidx => r_rowidx,
        o_colidx => r_colidx,
        o_done => r_idx_done,
        o_busy => r_idx_busy
    );
    -- Instantiate the LUT2D component
    R0_LUT : LUT2D
    generic map(
        table_name => "R0",
        table_mif => mif_R0,
        x11_init => "0111111100000000"
    )
    port map(
        i_clk => i_clk,
        i_state => i_state,
        i_ridx  => r_rowidx,
        i_cidx  => r_colidx,
        i_ow_addr => i_ow_R0_addr,
        i_ow_data => i_ow_R0,
        o_val => r_R0_alt,
        o_busy => r_R0_2d_busy
    );
    -- First RC Circuit parameter lookups
    a1_LUT : LUT2D
    generic map(
        table_name => "a1",
        table_mif  => mif_a1
    )
    port map(
        i_clk => i_clk,
        i_state => i_state,
        i_ridx  => r_rowidx,
        i_cidx  => r_colidx,
        i_ow_addr => i_ow_a1_addr, -- Assuming the same address for
        i_ow_data => i_ow_a1,
        o_val => o_a1,
        o_busy => r_a1_2d_busy
    );

    c1_LUT : LUT2D
    generic map(
        table_mif  => mif_c1
    )
    port map(
        i_clk => i_clk,
        i_state => i_state,
        i_ridx  => r_rowidx,
        i_cidx  => r_colidx,
        i_ow_addr => i_ow_c1_addr, -- Assuming the same address for
        i_ow_data => i_ow_c1,
        o_val => o_c1,
        o_busy => r_c1_2d_busy
    );

    -- Second RC Circuit parameter lookups
    a2_LUT : LUT2D
    generic map(
        table_mif  => mif_a2
    )
    port map(
        i_clk => i_clk,
        i_state => i_state,
        i_ridx  => r_rowidx,
        i_cidx  => r_colidx,
        i_ow_addr => i_ow_a2_addr, -- Assuming the same address for
        i_ow_data => i_ow_a2,
        o_val => o_a2,
        o_busy => r_a2_2d_busy
    );

    c2_LUT : LUT2D
    generic map(
        table_name => "c2",
        table_mif  => mif_c2
    )
    port map(
        i_clk => i_clk,
        i_state => i_state,
        i_ridx  => r_rowidx,
        i_cidx  => r_colidx,
        i_ow_addr => i_ow_c2_addr, -- Assuming the same address for
        i_ow_data => i_ow_c2,
        o_val => o_c2,
        o_busy => r_c2_2d_busy
    );

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            r_SOC <= i_SOC; -- Update SOC value
            r_I(15 downto 12) <= i_I(15 downto 12)-1; -- Update I value
            r_I(11 downto 0) <= i_I(11 downto 0);
            o_R0 <= r_R0_alt;
            if r_R0_2d_busy = '0' and r_a1_2d_busy = '0' and r_c1_2d_busy = '0' and r_a2_2d_busy = '0'  and r_c2_2d_busy = '0' then
                o_busy <= '0';
            else
                o_busy <= '1';
            end if;
        end if;
    end process;
end architecture rtl;
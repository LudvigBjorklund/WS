library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity ECM_Cell is
	generic(
          -- Mif file names for the ECM parameters
        mif_R0          : string := "R0.mif"; -- MIF file for
        mif_a1          : string := "a1.mif"; -- MIF file for a1 table
        mif_c1          : string := "c1.mif";
        mif_a2          : string := "a2.mif"; -- MIF file for a2 table
        mif_c2          : string := "c2.mif"; -- MIF file for c2 table
        -- Simulation Parameters
        timestep        : integer := 4; -- dt^(-timestep)
        timestep_wait_cycles : integer := 50; -- Number of clock cycles to wait between each simulation step pulse
        -- Data width parameters
        n_b_SOC         : integer := 24; -- number of bits for SOC
        n_b_I           : integer := 16; -- number of bits for current
        n_b_Q           : integer := 16; -- number of bits for charge

        -- Integers of the signals
        n_int_SOC       : integer := 7;  
        n_int_I         : integer := 4; 
        n_int_Q         : integer := -8 -- For integer_bits <0, the fractional bits are equal to the total bits
    );
    port(
        i_clk       : in std_logic;   -- Clock
        i_state     : in t_state;     -- Simulation state
--.     i_sw        : in unsigned(9 downto 0); -- Switches for debug and control
        i_charging  : in std_logic;   -- 1 if charging, 0 if discharging
        i_SOC0      : in unsigned(n_b_SOC-1 downto 0); -- Initial SOC
        i_I         : in unsigned(n_b_I-1 downto 0);   -- Current
        i_Q         : in unsigned(n_b_Q-1 downto 0);   -- Capacity
        -- ECM parameters overwrite (MSB address, LSB data)
        i_ow_R0     : in unsigned(23 downto 0);
        i_ow_a1     : in unsigned(23 downto 0);
        i_ow_c1     : in unsigned(23 downto 0);
        i_ow_a2     : in unsigned(23 downto 0);
        i_ow_c2     : in unsigned(23 downto 0);
        -- Open Circuit voltage overwrite (MSB address, LSB data)
        i_ow_v_ocv  : in unsigned(23 downto 0);

        -- Outputs
        o_SOC    : out unsigned(23 downto 0);
        o_t_sim  : out unsigned(23 downto 0);
        o_extra  : out unsigned(31 downto 0)
            );
end entity ECM_Cell;

architecture rtl of ECM_Cell is
---- Internal signals, registers, and components ----
-- ========================== Simulation Time Counter ==========================
component simulation_time is
    generic(
        timestep : integer := 3 -- dt = 2^(-timestep) seconds
    );
    port(
        i_clk : in std_logic;
        i_state : in t_state;
        i_step : in std_logic;
        o_time : out unsigned(23 downto 0)
    );
 end component simulation_time;
-- The splitting of the ow inputs into address is 8 MSB and 16 LSB (address, data)
-- Component declarations
component Calc_SOC is
    generic(
        timestep    : integer := 4; -- dt = 2^(-timestep) seconds
        n_b_SOC     : integer := 16;
        n_b_I       : integer := 16;
        n_b_Q       : integer := 16;
        n_int_SOC   : integer := 7;
        n_frac_SOC  : integer := 9;
        n_int_I     : integer := 4;
        n_frac_I    : integer := 12;
        n_int_Q     : integer := -8;
        n_frac_Q    : integer := 16
    );

    port(
        i_clk : in std_logic;
        i_state : in t_state;
        i_charge : in std_logic; -- '1' - Charging, '0' - Discharging
        i_step : in std_logic;
        i_SOC0 : in unsigned(n_b_SOC - 1 downto 0);
        i_I   : in unsigned(n_b_I - 1 downto 0);
        i_Q   : in unsigned(n_b_Q - 1 downto 0);
        o_SOC : out unsigned(n_b_SOC - 1 downto 0)
    );
end component Calc_SOC;


component ECM_Parameters is
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
end component ECM_Parameters;
---------------------------------------------- Voltage caculation components ----------------------------------------------
component dV_R0 is
    generic(
        n_b_int_R0 : integer := 8;  -- Number of bits for the integer part of R0
        n_b_frac_R0 : integer := 8;  -- Number of bits for the fractional part of R0
        n_b_int_I : integer := 4;   -- Number of bits for the integer part of I
        n_b_frac_I : integer := 12;   -- Number of bits for the fractional part of I
        n_b_int_dV_R0 : integer := 11; -- Number of bits for the integer part of dV_R0
        n_b_frac_dV_R0 : integer := 37  -- Number of bits for the fractional part of dV_R0
    );
    port (
        i_clk    : in std_logic;
        i_R0     : in unsigned(15 downto 0);
        i_I      : in unsigned(15 downto 0);
        o_dV_R0  : out unsigned(47 downto 0)
    );  
end component dV_R0;


component dV_RC is
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
        i_a    : in unsigned(n_bits_a - 1 downto 0); -- 0EN16
        i_I    : in unsigned(n_bits_I - 1 downto 0); -- 0EN16
        o_dV   : out unsigned(n_bits_dV - 1 downto 0)  -- 0EN48
    );
end component dV_RC;


---------------------------------------------- Voltage caculation components ----------------------------------------------


----- Calculating the open circuit voltage -----
constant wd_norm_in : integer := 13;
constant c_SOCnorm  : unsigned(wd_norm_in - 1 downto 0) :="1100110011010"; --"0001100110011001"; -- Shifted 3
constant c_wd_out : integer := 24; 

signal  vocv_tbl_idx : unsigned(c_wd_out - 1 downto 0) := (others => '0');-- Index for Vocv table lookup, calculated from SOC using Normalizer
component Normalizer is
    generic(
        wd_in       : integer := 16; -- r_SOC width
        wd_norm_in  : integer := 16; 
        wd_out      : integer := 32
    );
    port(
        i_clk   : in std_logic;
        i_val   : in unsigned(wd_in - 1 downto 0);
        i_norm  : in unsigned(wd_norm_in - 1 downto 0); -- Special case when only 0
        o_val   : out unsigned(wd_out - 1 downto 0)
    );
end component Normalizer;
constant max_vocv_idx : unsigned(c_wd_out - 1 downto 0) := to_unsigned(10,4) & to_unsigned(0, c_wd_out-4); -- Max index for Vocv table lookup
signal v_lut_idx : unsigned(c_wd_out - 1 downto 0) := (others => '0');-- Index for Vocv table lookup, calculated from SOC using Normalizer

component LUT1D_sim is
    generic (
        table_mif  : string := "LUT_1D.mif";
        ADDR_WIDTH : integer := 4;
        n_frac_bits: integer := 20;
        n_out_bits : integer := 16;
        n_tbl_bits : integer := 48
    );
    port (
        i_clk      : in std_logic;
        i_state    : in t_state;
        i_lut_addr : in unsigned(ADDR_WIDTH+ n_frac_bits-1 downto 0); -- 4MSB Int, 8LSB frac for the interpolation
        i_ow_addr  : in unsigned(ADDR_WIDTH-1 downto 0);
        i_ow_data  : in unsigned(19 downto 0);
        o_val      : out unsigned(n_tbl_bits-1 downto 0)
    );
end component LUT1D_sim;

signal v_ocv : unsigned(47 downto 0) := (others => '0'); -- Output OCV from table lookup [12EN36] vs other voltages [11EN37]

----- Calculating the open circuit voltage -----
---------------------------------------------- Voltage caculation components ----------------------------------------------
-- Simulation time signal
signal r_sim_time : unsigned(23 downto 0) := (others => '0');

-- Simulation step signal
signal r_sim_step : std_logic := '0';
signal r_sim_start : std_logic := '0';
signal r_reset : std_logic := '0';


constant c_sim_step_wait_cycles : integer := timestep_wait_cycles; -- Number of clock cycles to wait between each simulation step pulse CHANGE BEFORE SYNTHESIS
signal r_sim_step_wait : integer range 0 to timestep_wait_cycles := 0;

-- The fracional bits are the remaining bits
constant n_frac_SOC : integer := n_b_SOC - n_int_SOC;
constant n_frac_I   : integer := n_b_I - n_int_I;


-- For integer_bits <0, the fractional bits are equal to the total bits 
constant n_frac_Q   : integer := n_b_Q; 


-- ECM Cell parameter registers
signal r_R0  : unsigned(15 downto 0) := (others => '0');
signal r_a1  : unsigned(15 downto 0) := (others => '0');
signal r_c1  : unsigned(15 downto 0) := (others => '0');
signal r_a2  : unsigned(15 downto 0) := (others => '0');
signal r_c2  : unsigned(15 downto 0) := (others => '0');

-- ECM Cell voltage calculation signals
signal r_dV_R0 : unsigned(47 downto 0) := (others => '0');
signal r_dV_RC1 : unsigned(47 downto 0) := (others => '0');
signal r_dV_RC2 : unsigned(47 downto 0) := (others => '0');

signal r_SOC0   : unsigned(23 downto 0) := "1100100" & to_unsigned(0, 24-7);
signal r_SOC    : unsigned(24-1 downto 0) := (others => '0');
-- Truncated SOC for table lookup
signal r_SOC_tbl : unsigned(15 downto 0) := (others => '0');
signal r_I_tbl  : unsigned(16-1 downto 0) := (others => '0');

signal dbg_wait_variable : integer range 0 to 3 := 0;

begin

    
    -- Instantiate SOC calculator
    u_calc_soc : Calc_SOC
        generic map(
            timestep   => timestep,
            n_b_SOC    => 24,
            n_b_I      => n_b_I,
            n_b_Q      => n_b_Q,
            n_int_SOC  => 7,
            n_frac_SOC => n_frac_SOC,
            n_int_I    => n_int_I,
            n_frac_I   => n_frac_I,
            n_int_Q    => n_int_Q,
            n_frac_Q   => n_frac_Q
        )
        port map(
            i_clk   => i_clk,
            i_state => i_state,
            i_charge => i_charging,
            i_step  => r_sim_step,
            i_SOC0  => i_SOC0,
            i_I     => i_I,
            i_Q     => i_Q,
            o_SOC   => r_SOC
        );

    -- Instantiate ECM parameters module
    u_ecm_params : ECM_Parameters
        generic map(
            simulation_build => TRUE,
            mif_R0     => mif_R0,
            mif_a1     => mif_a1,
            mif_c1     => mif_c1,
            mif_a2     => mif_a2,
            mif_c2     => mif_c2
        )
        port map(
            i_clk       => i_clk,
            i_state     => i_state,
            i_SOC       => r_SOC_tbl,
            i_I         => r_I_tbl,
            i_ow_R0_addr => i_ow_R0(23 downto 16),
            i_ow_R0     => i_ow_R0(15 downto 0),
            i_ow_a1_addr => i_ow_a1(23 downto 16),
            i_ow_a1     => i_ow_a1(15 downto 0),
            i_ow_c1_addr => i_ow_c1(23 downto 16),
            i_ow_c1     => i_ow_c1(15 downto 0),
            i_ow_a2_addr => i_ow_a2(23 downto 16),
            i_ow_a2     => i_ow_a2(15 downto 0),
            i_ow_c2_addr => i_ow_c2(23 downto 16),
            i_ow_c2     => i_ow_c2(15 downto 0),
            o_R0        => r_R0,
            o_a1       => r_a1,
            o_c1       => r_c1,
            o_a2       => r_a2,
            o_c2       => r_c2,
            o_done     => open,
            o_busy     => open
        );
       --================ V_OCV Calculation =================--
    ecm_cell_soc_idx : Normalizer
        generic map(
            wd_in      => 24,
            wd_norm_in => wd_norm_in,
            wd_out     => c_wd_out
        )
        port map(
            i_clk  => i_clk,
            i_val  => r_SOC, -- Use the upper 16 bits for index calculation
            i_norm => c_SOCnorm,
            o_val  => vocv_tbl_idx
        );

    -- The voltage OCV table index calculation process (1D LUT index limiting)
    ecm_cell_vocv_val : LUT1D_sim
        generic map(
            table_mif  => "Vocv_LUT.mif",
            ADDR_WIDTH => 4,
            n_frac_bits=> 20,
            n_out_bits => 16,
            n_tbl_bits => 48
        )
        port map(
            i_clk      => i_clk,
            i_state    => i_state,
            i_lut_addr => v_lut_idx,
            i_ow_addr  => i_ow_v_ocv(23 downto 20), -- Replace with V_ocv overwrite address if needed
            i_ow_data  => i_ow_v_ocv(19 downto 0), -- The data to overwrite the V_ocv value with
            o_val      => v_ocv
        );
        
    proc_max_vocv_idx : process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- Limit the vocv index to the max value
            if vocv_tbl_idx > max_vocv_idx then
                v_lut_idx <= max_vocv_idx;
            else
                v_lut_idx <= vocv_tbl_idx;
            end if;
        end if;
    end process proc_max_vocv_idx;

   --================ V_OCV Calculation =================--

        -- Voltage calculation process 
    u_dV_R0 : dV_R0
        generic map(
            n_b_int_R0    => 8,
            n_b_frac_R0   => 8,
            n_b_int_I     => n_int_I,
            n_b_frac_I    => n_frac_I,
            n_b_int_dV_R0 => 11,
            n_b_frac_dV_R0=> 37
        )
        port map(
            i_clk   => i_clk,
            i_R0    => r_R0,
            i_I     => i_I,
            o_dV_R0 => r_dV_R0
        );

    u_dV_RC1 : dV_RC
        generic map(
            timestep    => timestep,
            n_bits_c    => 16,
            n_bits_a    => 16,
            n_bits_I    => 16,
            n_bits_dV   => 48,
            init_dV     => (others => '0'),
            n_int_a     => -5,
            n_frac_a    => 16,
            n_int_c     => 0,
            n_frac_c    => 16,
            n_int_I     => n_int_I,
            n_frac_I    => n_frac_I,
            n_int_dV    => 11,
            n_frac_dV   => 37
        )
        port map(
            i_clk   => i_clk,
            i_rst   => r_reset,
            i_strt  => r_sim_start,
            i_step  => r_sim_step,
            i_c     => r_c1,
            i_a     => r_a1,
            i_I     => i_I,
            o_dV    => r_dV_RC1
        );

    u_dV_RC2 : dV_RC
        generic map(
            timestep    => timestep,
            n_bits_c    => 16,
            n_bits_a    => 16,
            n_bits_I    => 16,
            n_bits_dV   => 48,
            init_dV     => (others => '0'),
            n_int_a     => -7,
            n_frac_a    => 16,
            n_int_c     => -5,
            n_frac_c    => 16,
            n_int_I     => n_int_I,
            n_frac_I    => n_frac_I,
            n_int_dV    => 11,
            n_frac_dV   => 37
        )
        port map(
            i_clk   => i_clk,
            i_rst   => r_reset,
            i_strt  => r_sim_start,
            i_step  => r_sim_step,
            i_c     => r_c2,
            i_a     => r_a2,
            i_I     => i_I,
            o_dV    => r_dV_RC2
        );


        -- Processes for idle, initialize, verification, simulation, pause and more should go here
        proc_SM_actions : process(i_clk)
        begin
            if rising_edge(i_clk) then
                -- Add state machine actions here
                case i_state is 
                    when s_idle => 
                        r_sim_step <= '0';
                        r_sim_start <= '0';
                        r_reset <= '1';
                        r_sim_time <= (others => '0');

                    when s_init =>
                        r_reset <= '0';
                        r_sim_start <= '0';
                        r_sim_step <= '0';
                        r_sim_time <= (others => '0');
                    when s_sim =>
                        r_sim_start <= '1';
                        if r_sim_step_wait < c_sim_step_wait_cycles then
                            r_sim_step_wait <= r_sim_step_wait + 1;
                            r_sim_step <= '0';
                        else
                            r_sim_step <= '1';
                            r_sim_time <= r_sim_time + 1;

                            r_sim_step_wait <= 0;
                        end if;
       
                    when others =>
                        r_sim_step <= '0';
                        r_sim_start <= '0';
                        r_reset <= '0';
                        r_sim_time <= (others => '0');

                end case;
            end if;
        end process proc_SM_actions;
    

                -- Process for assigning to the table lookup inputs
        -- Process for assigning to the table lookup inputs
        proc_set_table_inputs : process(i_clk)
        variable wait_variable : integer range 0 to 3 := 0;
        begin 
            if rising_edge(i_clk) then

                -- Truncate SOC and I for table lookup
                r_SOC_tbl <= r_SOC(n_b_SOC-1 downto n_b_SOC-16);
                r_I_tbl   <= i_I;
            end if;
        end process proc_set_table_inputs;

        process_init_finish : process(i_clk)
        variable initialization_done : boolean := false;
        begin
            if rising_edge(i_clk) then
              --  process_not_done := false;
                if initialization_done = false then
                    --o_SOC <= i_SOC0(23 downto 8);
                    o_SOC <= i_SOC0;
                    initialization_done := true;
                
                else
                    --o_SOC <= r_SOC_tbl;
                  --  o_SOC(23 downto 8) <= r_SOC_tbl;
                --    o_SOC(7 downto 0) <= (others => '0');
                     o_SOC <= r_SOC;
                     o_t_sim <= r_sim_time;
                end if;
            end if;
        end process process_init_finish;

            -- Output extra data for debugging
    extra_variable_output : process(i_clk)
    begin
        -- Outputs the dV_R0, dV_RC1, dV_RC2 and V_OCV values for debugging, incrementally each clock cycle and with a unique 4-bit identifier in the LSBs
        if rising_edge(i_clk) then
            -- case i_sw(9 downto 7) is
            --     when "000" =>
            --         case dbg_wait_variable is
            --             when 0 =>
            --                 o_extra <= "0001" & r_dV_R0(47 downto 47-27);
            --                 dbg_wait_variable <= 1;
            --             when 1 =>
            --                 o_extra <= "0010" & r_dV_RC1(47 downto 47-27);
            --                 dbg_wait_variable <= 2;
            --             when 2 =>
            --                 o_extra <= "0011" & r_dV_RC2(47 downto 47-27);
            --                 dbg_wait_variable <= 3;
            --             when 3 =>
            --                 o_extra <= "0100" & v_ocv(47 downto 47-27);
            --                 dbg_wait_variable <= 0;
            --             when others =>
            --                 dbg_wait_variable <= 0;
            --         end case;
            --     when others =>
                     case dbg_wait_variable is
                         when 0 =>
                            o_extra <= "0001" & to_unsigned(0,12) & r_R0;
                            dbg_wait_variable <= 1;
                        when 1 =>
                            o_extra <= "0010" & r_dV_RC1(47 downto 47-27);
                            dbg_wait_variable <= 2;
                        when 2 =>
                            o_extra <= "0011" & r_dV_RC2(47 downto 47-27);
                            dbg_wait_variable <= 3;
                        when 3 =>
                            o_extra <= "0100" & v_ocv(47 downto 47-27);
                            dbg_wait_variable <= 0;
                        when others =>
                            dbg_wait_variable <= 0;
                end case;
              --  end case;
        end if;
    end process extra_variable_output;

end architecture rtl;

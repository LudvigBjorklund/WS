library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

package DT_Components_declaration is

-- =========================================================================
-- Component Declarations
-- =========================================================================

-- ==========================
-- Simulation State Machine
-- ==========================

    component sim_SM is 
        port(
            i_clk    : in std_logic;
            i_state_bin  : in unsigned(2 downto 0);
            o_state  : out t_state
        );
    end component sim_SM;
 -- ==========================
-- Simulation Time Counter
-- ==========================

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
-- ======================
-- UART 32-bit Component
-- ======================
    component DT_UART_32bit is
        generic(
            g_clk_rate : integer := 434; -- Clock rate in Hz
            g_no_signals_rx : integer := 8; -- Number of signals to be received
            g_no_signals_tx : integer := 4; -- Number of signals to be transmitted
            g_no_signals_ver_tx : integer := 4; -- Number of signals to be verified
            g_max_no_signals_tx : integer := 8; -- Maximum number of signals that can be transmitted
            g_init_rx_data : unsigned(31 downto 0) := (others => '0') -- Initial 32-bit data bus
        );
        port(
            i_clk          : in std_logic;
            i_state        : in t_state;
            i_rx           : in std_logic;
            i_init_rx_cnct : in unsigned((g_no_signals_rx * 24) - 1 downto 0) := (others => '0'); -- Initial concatenated RX data bus
            i_strt_tx      : in std_logic; -- Start transmission signal
            i_data_tx      : in unsigned((g_max_no_signals_tx * 32) - 1 downto 0); -- Concatenated TX data bus
            i_skip_tx      : in std_logic_vector(g_no_signals_ver_tx-1 downto 0); -- Skip transmission of specific signals for verification
            o_rx_data      : out unsigned((g_no_signals_rx * 24) - 1 downto 0); -- Received concatenated RX data bus
            o_done_tx      : out std_logic; -- Transmission done signal
            o_busy_tx      : out std_logic; -- Transmission busy signal
            o_tx           : out std_logic
        );
    end component DT_UART_32bit;

    -- Entity declaration with generic parameters
    component bcd is 
        generic(
            g_bin_width : integer := 20 -- Default binary input width
        );
        port(
            i_bin : in  unsigned(g_bin_width-1 downto 0); -- Binary input of generic width
            o_bcd : out unsigned(g_bin_width + 3 downto 0) -- BCD output width
        );
    end component bcd;


    component hex_digits is 
        port(
            i_clk : in std_logic;
            i_bin : in unsigned(3 downto 0); -- 4-bit binary input
            o_hex : out std_logic_vector(6 downto 0) -- 7-segment display output
        );
    end component hex_digits;
component ECM_Cell is
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
   --         i_sw        : in unsigned(9 downto 0); -- Switches for debug and control
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
    end component ECM_Cell;


    -- ========================== Simulation Only Components ==========================
    component ECM_Cell_sim is
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
        o_t_sim  : out unsigned(23 downto 0);
        o_SOC    : out unsigned(23 downto 0);
        o_extra  : out unsigned(31 downto 0)
        
    );
    end component ECM_Cell_sim;
end package DT_Components_declaration;
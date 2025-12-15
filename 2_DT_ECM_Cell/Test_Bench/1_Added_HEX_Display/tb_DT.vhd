library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- use work.Common.all;
entity tb_dt is
end entity tb_dt;

architecture tb_behavioral of tb_dt is

    
-- =========================================================================
-- Declare test bench DUT component
-- =========================================================================
component DigitalTwin is
        generic(
        g_clk_rate : integer := 434
    );
    port(
        -- Inputs
        i_clk : in std_logic;
        i_rx  : in std_logic;
        i_sw  : in std_logic_vector(9 downto 0);
        -- Outputs
        o_led : out unsigned(9 downto 0) := (others => '0');
        o_hex0, o_hex1, o_hex2, o_hex3, o_hex4, o_hex5 : out std_logic_vector(6 downto 0);
        o_tx  : out std_logic
    );
end component DigitalTwin;


component hex_to_dbg_val is
    port(
        i_clk  :    in std_logic;
        i_hex0, i_hex1, i_hex2, i_hex3, i_hex4, i_hex5 : in std_logic_vector(6 downto 0); -- 7-segment display inputs
        o_dbg_val : out integer range 0 to 999999 -- Output integer value (0 to 999999)
    );
end component hex_to_dbg_val;
-- =========================================================================
-- Signal Declarations
-- =========================================================================

    signal tb_clk       : std_logic := '0';
    signal tb_sw        : std_logic_vector(9 downto 0) := (others => '0');
    constant clk_period : time := 10 ns;
    constant c_clk_rate : integer := 4; -- Clock rate in Hz
    -- Protocol IDs
    constant ID_TL_SM     : integer := 1;   -- State machine control

    signal tb_rx        : std_logic := '1'; -- Idle state is high

        -- Tracking signals
    signal r_last_sent_id : integer := 0;
    signal r_sent_state   : integer := 0;
    signal r_sent_I       : integer := 0;
    signal r_sent_SOC     : integer := 0;
    signal r_sent_R0      : integer := 0;
-- =========================================================================
-- Type Declarations for Structured Parameters
-- =========================================================================
type t_param_record is record
    id      : integer;
    data1   : integer;
    data2   : integer;
    data3   : integer;
end record;

type t_r0_record is record
    id       : integer;
    position : integer;  -- table position (row*11 + col)
    value    : integer;  -- resistance value
    reserved : integer;  -- reserved byte
end record;

-- =========================================================================
-- Procedures
-- =========================================================================
        -- Send a single byte serially (LSB first) with optional start bit
    procedure send_byte(
        signal tx_line : out std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean
    ) is
    begin
        if send_start_bit then
            tx_line <= '0'; -- Start bit
            wait for clk_period * (c_clk_rate + 1);
        end if;

        for i in 0 to 7 loop
            tx_line <= data(i);
            wait for clk_period * (c_clk_rate + 1);
        end loop;

        tx_line <= '1'; -- Stop bit
        wait for clk_period * (c_clk_rate + 1);
    end procedure;

    -- Send 32-bit data packet (ID + 3 data bytes)
    procedure send_32bit_data(
        signal tx_line : out std_logic;
        constant id_val : in std_logic_vector(7 downto 0);
        constant data1 : in std_logic_vector(7 downto 0);
        constant data2 : in std_logic_vector(7 downto 0);
        constant data3 : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    ) is
        variable id_int : integer := 0;
    begin
        send_byte(tx_line, id_val, send_start_bit);
        send_byte(tx_line, data1, send_start_bit);
        send_byte(tx_line, data2, send_start_bit);
        send_byte(tx_line, data3, send_start_bit);

        -- Update tracking signals
        id_int := to_integer(unsigned(id_val));
        r_last_sent_id_sig <= id_int;
        
        case id_int is
            when 1 => r_sent_state_sig <= 1;
            when 2 => r_sent_I_sig <= 1;
            when 3 => r_sent_SOC_sig <= 1;
            when 5 => r_sent_R0_sig <= 1;
            when others => null;
        end case;
    end procedure;
    
    -- High-level procedure to send structured parameter data
    procedure send_param(
        signal tx_line : out std_logic;
        constant param : in t_param_record;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    ) is
        variable v_data : std_logic_vector(31 downto 0);
    begin
        v_data := std_logic_vector(
            to_unsigned(param.id, 8) & 
            to_unsigned(param.data1, 8) & 
            to_unsigned(param.data2, 8) & 
            to_unsigned(param.data3, 8)
        );
        
        send_32bit_data(
            tx_line, 
            v_data(31 downto 24), 
            v_data(23 downto 16), 
            v_data(15 downto 8), 
            v_data(7 downto 0),
            true,
            r_last_sent_id_sig,
            r_sent_state_sig,
            r_sent_I_sig,
            r_sent_SOC_sig,
            r_sent_R0_sig
        );
    end procedure;
    
    -- Specialized procedure for R0 table updates
    procedure send_r0_param(
        signal tx_line : out std_logic;
        constant r0_data : in t_r0_record;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    ) is
        variable v_data : std_logic_vector(31 downto 0);
    begin
        v_data := std_logic_vector(
            to_unsigned(r0_data.id, 8) & 
            to_unsigned(r0_data.position, 8) & 
            to_unsigned(r0_data.value, 8) & 
            to_unsigned(r0_data.reserved, 8)
        );
        
        send_32bit_data(
            tx_line, 
            v_data(31 downto 24), 
            v_data(23 downto 16), 
            v_data(15 downto 8), 
            v_data(7 downto 0),
            true,
            r_last_sent_id_sig,
            r_sent_state_sig,
            r_sent_I_sig,
            r_sent_SOC_sig,
            r_sent_R0_sig
        );
    end procedure;
    
    -- Procedure to send state machine command
    procedure send_state_cmd(
        signal tx_line : out std_logic;
        constant state_val : in integer;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    ) is
        variable v_param : t_param_record;
    begin
        v_param := (id => ID_TL_SM, data1 => 0, data2 => 0, data3 => state_val);
        send_param(tx_line, v_param, r_last_sent_id_sig, r_sent_state_sig, 
                   r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
    end procedure;
-- =========================================================================

begin
    -- =========================================================================
    -- DUT Instantiation
    -- =========================================================================
    DigitalTwin_inst : DigitalTwin
    generic map(
        g_clk_rate => c_clk_rate
    )
    port map(
        i_clk         => tb_clk,
        i_rx          => tb_rx,
        i_sw          => tb_sw,
        o_tx          => open,
        o_led         => open
    );


    -- =========================================================================
    -- Clock Generator
    -- =========================================================================
    clk_process : process
    begin
        while true loop
            tb_clk <= '0';
            wait for clk_period / 2;
            tb_clk <= '1';
            wait for clk_period / 2;
        end loop;
    end process clk_process;

    -- =========================================================================
    -- Stimuli Process
    -- =========================================================================
    stim_process : process
    begin
        wait for 10*clk_period;
        -- =====================================================================
        -- Test Sequence 1: Basic State Transitions
        -- =====================================================================
        report "Test 1: Transition to s_sim state (ID=1, state=3)";
        send_state_cmd(tb_rx, 1, r_last_sent_id, r_sent_state, r_sent_I, r_sent_SOC, r_sent_R0);
        wait;

    end process stim_process;

end architecture tb_behavioral;
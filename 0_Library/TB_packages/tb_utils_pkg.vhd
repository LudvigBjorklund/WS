library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package tb_utils_pkg is
    
    -- Function to convert std_logic_vector to string
    function slv_to_string(slv : std_logic_vector) return string;

    -- Function to convert time to microseconds string
    function time_to_us_string(t : time) return string;
    
    -- Test configuration type
type t_test_config is record
    test_name       : string(1 to 120);
    init_state      : integer;
    sim_state       : integer;
    idle_state      : integer;
    wait_cycles     : integer;
    repeat_init     : boolean;
end record;


-- Enumeration for parameter types
type t_param_type is (PARAM_SOC, PARAM_I, PARAM_R0, PARAM_A1, PARAM_C1, PARAM_A2, PARAM_C2, PARAM_NONE);

-- Record for a single parameter configuration
type t_param_config is record
    param_type : t_param_type;
    real_value : real;        -- For SOC and I values
    address    : integer;     -- For table parameters (R0, a1, c1, a2, c2)
    int_value  : integer;     -- For table values
end record;

-- Array of parameter configurations
type t_param_config_array is array (natural range <>) of t_param_config;

-- Function to pad string to specified length
function pad_string(
    str : string;
    length : positive
) return string;

-- Helper function to create test config with automatic padding
function create_test_config(
    test_name : string;
    init_state : integer := 1;
    sim_state : integer := 3;
    idle_state : integer := 0;
    wait_cycles : integer := 1000;
    repeat_init : boolean := false
) return t_test_config;
    
    -- Procedure to print table overwrite information
    procedure print_overwrite_info(
        constant table_name : in string;
        constant address : in integer;
        constant value : in integer
    );
    

        -- Procedure to print formatted test header
    procedure print_test_header(
        constant test_name : in string
    );
    
    
      -- Procedure to print formatted subtest header
    procedure print_subtest_header(
        constant subtest_name : in string
    );

    -- =========================================================================
    -- Parameter transfer over UART
    -- =========================================================================

    constant clk_period : time := 10 ns;

    -- Constants
    constant ID_SM     : integer := 1;   -- State machine control
    constant ID_I      : integer := 2;   -- Current I value
    constant ID_SOC0   : integer := 3;   -- Initial SOC value
    constant ID_R0     : integer := 5;   -- R0 table update
    constant ID_a1     : integer := 6;   -- a1 table update
    constant ID_c1     : integer := 7;   -- c1 table update
    constant ID_a2     : integer := 8;   -- a2 table update
    constant ID_c2     : integer := 9;   -- c2 table update
    
    -- Types
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
    
    -- UART communication procedures
    procedure send_byte(
        signal tx_line : out std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean;
        constant clk_period : in time;
        constant c_clk_rate : in integer
    );

        
    procedure send_32bit_data(
        signal tx_line : out std_logic;
        constant id_val : in std_logic_vector(7 downto 0);
        constant data1 : in std_logic_vector(7 downto 0);
        constant data2 : in std_logic_vector(7 downto 0);
        constant data3 : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean;
        constant clk_period : in time;
        constant c_clk_rate : in integer;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    );

    procedure send_param(
        signal tx_line : out std_logic;
        constant param : in t_param_record;
        constant clk_period : in time;
        constant c_clk_rate : in integer;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    );
    

    procedure send_state_cmd(
        signal tx_line : out std_logic;
        constant state_val : in integer;
        constant clk_period : in time;
        constant c_clk_rate : in integer;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    );

    procedure send_r0_param(
    signal tx_line : out std_logic;
    constant r0_data : in t_r0_record;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

procedure send_I_value(
    signal tx_line : out std_logic;
    constant current_value : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

procedure send_SOC_value(
    signal tx_line : out std_logic;
    constant current_value : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

-- filepath: /home/ludvig/Documents/Digital Twin/Version 2/1. DigitalTwin/Test-benches/tb_utils_pkg.vhd
-- ...existing code...

-- Procedure to send a single parameter based on type
procedure send_parameter(
    signal tx_line : out std_logic;
    constant param : in t_param_config;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

-- Procedure to send multiple parameters
procedure send_parameters(
    signal tx_line : out std_logic;
    constant params : in t_param_config_array;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);


-- filepath: /home/ludvig/Documents/Digital Twin/Version 2/1. DigitalTwin/Test-benches/tb_utils_pkg.vhd
-- ...existing code...

-- Procedure to loop over current values (table rows)
procedure loop_over_table_rows(
    signal tx_line : out std_logic;
    constant start_current : in real;
    constant end_current : in real;
    constant step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

-- Procedure to loop over SOC values (table columns)
procedure loop_over_table_cols(
    signal tx_line : out std_logic;
    constant start_SOC : in real;
    constant end_SOC : in real;
    constant step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

-- Procedure to sweep 2D table (current vs SOC)
procedure sweep_2d_table(
    signal tx_line : out std_logic;
    constant start_current : in real;
    constant end_current : in real;
    constant current_step : in real;
    constant start_SOC : in real;
    constant end_SOC : in real;
    constant SOC_step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
);

-- ...existing code...
-- ...existing code...
end package tb_utils_pkg;

package body tb_utils_pkg is
    
    -- Function to convert std_logic_vector to string
    function slv_to_string(slv : std_logic_vector) return string is
        variable result : string(1 to slv'length);
        variable bit_val : std_logic;
    begin
        for i in slv'range loop
            bit_val := slv(i);
            if bit_val = '1' then
                result(slv'length - i) := '1';
            elsif bit_val = '0' then
                result(slv'length - i) := '0';
            else
                result(slv'length - i) := 'X';
            end if;
        end loop;
        return result;
    end function;

    -- Function to convert time to microseconds string
    function time_to_us_string(t : time) return string is
        variable time_in_ns : real;
        variable time_in_us : real;
    begin
        time_in_ns := real(t / 1 ns);
        time_in_us := time_in_ns / 1000.0;
        return real'image(time_in_us) & " us";
    end function;
    
    -- Function to pad string to specified length
function pad_string(
    str : string;
    length : positive
) return string is
    variable result : string(1 to length) := (others => ' ');
    variable copy_length : natural;
begin
    copy_length := str'length;
    if copy_length > length then
        copy_length := length;
    end if;
    
    result(1 to copy_length) := str(1 to copy_length);
    return result;
end function;

-- Helper function to create test config with automatic padding
function create_test_config(
    test_name : string;
    init_state : integer := 1;
    sim_state : integer := 3;
    idle_state : integer := 0;
    wait_cycles : integer := 1000;
    repeat_init : boolean := false
) return t_test_config is
    variable config : t_test_config;
begin
    config.test_name := pad_string(test_name, 120);
    config.init_state := init_state;
    config.sim_state := sim_state;
    config.idle_state := idle_state;
    config.wait_cycles := wait_cycles;
    config.repeat_init := repeat_init;
    return config;
end function;
    -- Procedure for when overwriting a table value (for example R0)
    -- Prints the address and the binary vector being sent
    procedure print_overwrite_info(
        constant table_name : in string;
        constant address : in integer;
        constant value : in integer
    ) is
        variable v_address_bin : std_logic_vector(7 downto 0);
        variable v_value_bin : std_logic_vector(15 downto 0);
    begin
        v_address_bin := std_logic_vector(to_unsigned(address, 8));
        v_value_bin := std_logic_vector(to_unsigned(value, 16));
        report "Overwriting => => " & table_name & " at address " & integer'image(address) & " with value " & integer'image(value);
        report "Address (bin): " & slv_to_string(v_address_bin) & ", Value (bin): " & slv_to_string(v_value_bin);
    end procedure;

        -- Procedure to print formatted test header
    procedure print_test_header(
        constant test_name : in string
    ) is
    begin
        report "";
        report "==================================================================================================";
        report "============================ " & test_name & " ============================";
        report "==================================================================================================";
        report "";
    end procedure;

        -- Procedure to print formatted subtest header
    procedure print_subtest_header(
        constant subtest_name : in string
    ) is
    begin
        report "===== " & subtest_name & " =====";
    end procedure;
    

    --=========================================================================
    -- Parameter transfer over UART
    --=========================================================================

        
    -- Send a single byte serially (LSB first) with optional start bit
    procedure send_byte(
        signal tx_line : out std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean;
        constant clk_period : in time;
        constant c_clk_rate : in integer
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

        -- Send 32-bit data as 4 bytes with tracking
    procedure send_32bit_data(
        signal tx_line : out std_logic;
        constant id_val : in std_logic_vector(7 downto 0);
        constant data1 : in std_logic_vector(7 downto 0);
        constant data2 : in std_logic_vector(7 downto 0);
        constant data3 : in std_logic_vector(7 downto 0);
        constant send_start_bit : in boolean;
        constant clk_period : in time;
        constant c_clk_rate : in integer;
        signal r_last_sent_id_sig : out integer;
        signal r_sent_state_sig : out integer;
        signal r_sent_I_sig : out integer;
        signal r_sent_SOC_sig : out integer;
        signal r_sent_R0_sig : out integer
    ) is
        variable id_int : integer := 0;
    begin
        send_byte(tx_line, id_val, send_start_bit, clk_period, c_clk_rate);
        send_byte(tx_line, data1, send_start_bit, clk_period, c_clk_rate);
        send_byte(tx_line, data2, send_start_bit, clk_period, c_clk_rate);
        send_byte(tx_line, data3, send_start_bit, clk_period, c_clk_rate);

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

    procedure send_param(
    signal tx_line : out std_logic;
    constant param : in t_param_record;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
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
        clk_period,
        c_clk_rate,
        r_last_sent_id_sig,
        r_sent_state_sig,
        r_sent_I_sig,
        r_sent_SOC_sig,
        r_sent_R0_sig
    );
end procedure;

procedure send_state_cmd(
    signal tx_line : out std_logic;
    constant state_val : in integer;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_param : t_param_record;
begin
    v_param := (id => ID_SM, data1 => 0, data2 => 0, data3 => state_val);
    send_param(tx_line, v_param, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, 
               r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
    wait for 6*clk_period;
end procedure;

procedure send_r0_param(
    signal tx_line : out std_logic;
    constant r0_data : in t_r0_record;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
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
        clk_period,
        c_clk_rate,
        r_last_sent_id_sig,
        r_sent_state_sig,
        r_sent_I_sig,
        r_sent_SOC_sig,
        r_sent_R0_sig
    );
end procedure;

-- Send Current I value with fixed-point format
procedure send_I_value(
    signal tx_line : out std_logic;
    constant current_value : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_integer_part : integer;
    variable v_fractional_part : integer;
    variable v_data : std_logic_vector(31 downto 0);
begin
    -- Extract integer part (4 bits, max value 15)
    v_integer_part := integer(current_value);
    
    -- Extract fractional part (8 bits, 0-255 representing 0.0 to 0.99609375)
    -- Multiply by 4096 to convert fraction to 12-bit representation
    v_fractional_part := integer((current_value - real(v_integer_part)) * 4096.0);
    
    -- Build the 32-bit data packet:
    -- Bits 31-24: ID_I
    -- Bits 23-16: Reserved (0x00)
    -- Bits 15-12: Integer part (4 bits)
    -- Bits 11-4:  Fractional part (8 bits)
    -- Bits 3-0:   Reserved (0x0)
    v_data := std_logic_vector(to_unsigned(ID_I, 8)) &           -- ID
              std_logic_vector(to_unsigned(0, 8)) &               -- Reserved
              std_logic_vector(to_unsigned(v_integer_part, 4)) &  -- Integer part
              std_logic_vector(to_unsigned(v_fractional_part, 12));  -- Fractional part
              
    send_32bit_data(
        tx_line,
        v_data(31 downto 24),
        v_data(23 downto 16),
        v_data(15 downto 8),
        v_data(7 downto 0),
        true,
        clk_period,
        c_clk_rate,
        r_last_sent_id_sig,
        r_sent_state_sig,
        r_sent_I_sig,
        r_sent_SOC_sig,
        r_sent_R0_sig
    );
    report "Sent I value: " & real'image(current_value) & " A at time " & time_to_us_string(now);
    report "  Integer part: " & integer'image(v_integer_part) & " (0x" & integer'image(v_integer_part) & ")";
    report "  Fractional part: " & integer'image(v_fractional_part) & " (0x" & integer'image(v_fractional_part) & ")";
end procedure;

-- Send SOC value with fixed-point format
procedure send_SOC_value(
    signal tx_line : out std_logic;
    constant current_value : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_integer_part : integer;
    variable v_fractional_part : integer;
    variable v_data : std_logic_vector(31 downto 0);
begin
    -- Extract integer part (4 bits, max value 15)
    v_integer_part := integer(current_value);
    
    -- Extract fractional part (8 bits, 0-255 representing 0.0 to 0.99609375)
    -- Multiply by 256 to convert fraction to 8-bit representation
    v_fractional_part := integer((current_value - real(v_integer_part)) * 131072.0);
    
    -- Build the 32-bit data packet:
    -- Bits 31-24: ID_SOC0
    -- Bits 23-16: Integer part (7 bits)
    -- Bits 15-0:  Fractional part (17 bits)
    v_data := std_logic_vector(to_unsigned(ID_SOC0, 8)) &           -- ID
              std_logic_vector(to_unsigned(v_integer_part, 7)) &  -- Integer part
              std_logic_vector(to_unsigned(v_fractional_part, 17));  -- Fractional part

    send_32bit_data(
        tx_line,
        v_data(31 downto 24),
        v_data(23 downto 16),
        v_data(15 downto 8),
        v_data(7 downto 0),
        true,
        clk_period,
        c_clk_rate,
        r_last_sent_id_sig,
        r_sent_state_sig,
        r_sent_I_sig,
        r_sent_SOC_sig,
        r_sent_R0_sig
    );
    
    report "Sent SOC value: " & real'image(current_value) & " % at time " & time_to_us_string(now);
    report "  Integer part: " & integer'image(v_integer_part) & " (0x" & integer'image(v_integer_part) & ")";
    report "  Fractional part: " & integer'image(v_fractional_part) & " (0x" & integer'image(v_fractional_part) & ")";



end procedure;

-- filepath: /home/ludvig/Documents/Digital Twin/Version 2/1. DigitalTwin/Test-benches/tb_utils_pkg.vhd
-- ...existing code...

-- Procedure to send a single parameter based on type
procedure send_parameter(
    signal tx_line : out std_logic;
    constant param : in t_param_config;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_r0 : t_r0_record;
begin
    case param.param_type is
        when PARAM_SOC =>
            report "Setting SOC to " & real'image(param.real_value) & " %";
            send_SOC_value(tx_line, param.real_value, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, 
                        r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);

        when PARAM_I =>
            report "Setting Current to " & real'image(param.real_value) & " A";
            send_I_value(tx_line, param.real_value, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, 
                        r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        
        when PARAM_R0 =>
            report "Setting R0 at address " & integer'image(param.address) & " to value " & integer'image(param.int_value);
            v_r0 := (id => ID_R0, position => param.address, value => param.int_value, reserved => 0);
            send_r0_param(tx_line, v_r0, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, 
                          r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
            print_overwrite_info("R0", param.address, param.int_value);
        
        when PARAM_A1 =>
            report "Setting a1 at address " & integer'image(param.address) & " to value " & integer'image(param.int_value);
            -- Add send_a1_param when implemented
        
        when PARAM_C1 =>
            report "Setting c1 at address " & integer'image(param.address) & " to value " & integer'image(param.int_value);
            -- Add send_c1_param when implemented
        
        when PARAM_A2 =>
            report "Setting a2 at address " & integer'image(param.address) & " to value " & integer'image(param.int_value);
            -- Add send_a2_param when implemented
        
        when PARAM_C2 =>
            report "Setting c2 at address " & integer'image(param.address) & " to value " & integer'image(param.int_value);
            -- Add send_c2_param when implemented
        
        when PARAM_NONE =>
            null;  -- Do nothing
    end case;
end procedure;

-- Procedure to send multiple parameters
procedure send_parameters(
    signal tx_line : out std_logic;
    constant params : in t_param_config_array;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
begin
    for i in params'range loop
        if params(i).param_type /= PARAM_NONE then
            send_parameter(tx_line, params(i), clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, 
                          r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        end if;
    end loop;
end procedure;

-- filepath: /home/ludvig/Documents/Digital Twin/Version 2/1. DigitalTwin/Test-benches/tb_utils_pkg.vhd
-- ...existing code...

-- Procedure to loop over current values (table rows)
procedure loop_over_table_rows(
    signal tx_line : out std_logic;
    constant start_current : in real;
    constant end_current : in real;
    constant step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_current : real;
begin
    report "Starting current sweep from " & real'image(start_current) & " A to " & real'image(end_current) & " A with step " & real'image(step) & " A";
    
    v_current := start_current;
    while v_current <= end_current loop
        send_I_value(tx_line, v_current, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        v_current := v_current + step;
    end loop;
    
    report "Completed current sweep";
end procedure;

-- Procedure to loop over SOC values (table columns)
procedure loop_over_table_cols(
    signal tx_line : out std_logic;
    constant start_SOC : in real;
    constant end_SOC : in real;
    constant step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_current : real;
begin
    report "Starting SOC sweep from " & real'image(start_SOC) & " % to " & real'image(end_SOC) & " % with step " & real'image(step) & " %";

    v_current := start_SOC;
    while v_current <= end_SOC loop
        send_SOC_value(tx_line, v_current, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        v_current := v_current + step;
    end loop;
    
    report "Completed State-of-Charge sweep";
end procedure;

-- Procedure to sweep 2D table (current vs SOC)
procedure sweep_2d_table(
    signal tx_line : out std_logic;
    constant start_current : in real;
    constant end_current : in real;
    constant current_step : in real;
    constant start_SOC : in real;
    constant end_SOC : in real;
    constant SOC_step : in real;
    constant clk_period : in time;
    constant c_clk_rate : in integer;
    signal r_last_sent_id_sig : out integer;
    signal r_sent_state_sig : out integer;
    signal r_sent_I_sig : out integer;
    signal r_sent_SOC_sig : out integer;
    signal r_sent_R0_sig : out integer
) is
    variable v_current : real;
    variable row_count : integer := 0;
begin
    report "Starting 2D table sweep:";
    report "  Current range: " & real'image(start_current) & " A to " & real'image(end_current) & " A (step: " & real'image(current_step) & " A)";
    report "  SOC range: " & real'image(start_SOC) & " % to " & real'image(end_SOC) & " % (step: " & real'image(SOC_step) & " %)";
    
    v_current := start_current;
    while v_current <= end_current loop
        row_count := row_count + 1;
        report "";
        report "=== Row " & integer'image(row_count) & ": Setting current to " & real'image(v_current) & " A ===";
        
        -- Set the current value for this row
        send_I_value(tx_line, v_current, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        
        -- Loop through all SOC values (columns) for this current
        loop_over_table_cols(tx_line, start_SOC, end_SOC, SOC_step, clk_period, c_clk_rate, r_last_sent_id_sig, r_sent_state_sig, r_sent_I_sig, r_sent_SOC_sig, r_sent_R0_sig);
        
        v_current := v_current + current_step;
    end loop;
    
    report "";
    report "Completed 2D table sweep. Total rows processed: " & integer'image(row_count);
end procedure;

-- ...existing code...    
end package body tb_utils_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity DT_TX is 
    generic(
        g_clks_per_bit  : integer := 434;
        no_signals_sim  : integer := 4;  -- Number of signals to transmit
        no_signals_ver  : integer := 8;  -- Number of signals to transmit in version mode
        max_no_signals  : integer := 8   -- Maximum number of signals to transmit (for array sizing)
    );
    port(
        i_clk      : in  std_logic; -- Clock input
        i_state    : in  t_state := s_idle; -- Current state of the system
        i_strt     : in  std_logic; -- Start signal to begin transmission
        i_data     : in  unsigned((max_no_signals*32)-1 downto 0); -- Input data (32 bits per signal)
        i_skip_tx  : in  std_logic_vector(no_signals_ver-1 downto 0) := (others => '0'); -- '1' to skip transmission of corresponding signal
        o_busy     : out std_logic; -- UART busy signal
        o_done     : out std_logic; -- Done signal indicating transmission complete
        o_tx       : out std_logic  -- UART serial data output
    );
end entity DT_TX;

architecture rtl of DT_TX is
    -- Component Declaration for the 32-bit TX module
    component tx_32bit is
        generic(g_clks_per_bit : integer := 434);
        port(
            i_clk  : in  std_logic;
            i_strt : in  std_logic;
            i_data : in  unsigned(31 downto 0);
            o_busy : out std_logic;
            o_done : out std_logic;
            o_tx   : out std_logic
        );
    end component;

    -- TX Module Interface Signals
    signal tx_32bit_start : std_logic := '0';
    signal tx_32bit_busy  : std_logic := '0';
    signal tx_32bit_done  : std_logic := '0';
    signal tx_32bit_data  : unsigned(31 downto 0) := (others => '0');

    -- Verification Mode Signals
    signal ver_sig_no        : integer range 1 to no_signals_ver := 1;  -- Current verification signal index
    signal ver_sig_no_lowest : integer range 1 to no_signals_ver := 1;  -- Lowest non-skipped index
    signal r_skip_tx         : std_logic_vector(no_signals_ver-1 downto 0) := (others => '0');  -- Current skip mask
    signal r_skip_tx_original: std_logic_vector(no_signals_ver-1 downto 0) := (others => '0');  -- Original skip mask when entering verification
    
    -- Simulation Mode Signals
    signal sim_sig_no : integer range 0 to no_signals_sim := 0;  -- Current simulation signal index
    
    -- State Control Flags
    signal initialization_done           : std_logic := '0';  -- Indicates initial setup is complete
    signal dp_from_prev_state_done      : std_logic := '0';  -- Data packet from previous state handled
    signal first_entry_to_verification   : std_logic := '1';  -- First time entering verification state
    signal found_first_verification_idx : std_logic := '0';  -- Found first valid index in current skip pattern
    signal ver_no_increment_done        : std_logic := '0';  -- Verification index increment completed
    signal sim_no_increment_done        : std_logic := '0';  -- Simulation index increment completed
    signal flipped_to_lowest_idx        : std_logic := '0';  -- Wrapped back to lowest index
    signal sent_all_verification_signals: std_logic := '0';  -- All verification signals sent
    signal lock_ver_sig_no              : std_logic := '0';  -- Lock verification index from changes
    signal flipped_done_output          : std_logic := '0';  -- Done output has been set high
    
    -- Constant for comparison
    constant skip_only_ones : std_logic_vector(no_signals_ver-1 downto 0) := (others => '1');

begin
    -- TX 32-bit Module Instantiation
    tx_32bit_inst : tx_32bit
        generic map(g_clks_per_bit => g_clks_per_bit)
        port map(
            i_clk  => i_clk,
            i_strt => tx_32bit_start,
            i_data => tx_32bit_data,
            o_busy => tx_32bit_busy,
            o_done => tx_32bit_done,
            o_tx   => o_tx
        );

    -- Main Transmission Process
    transmit_process : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case i_state is
                ------------------------------------------------------------------------------
                -- VERIFICATION STATE: Transmit only non-skipped signals
                ------------------------------------------------------------------------------
                when s_verification =>
                    -- Store original skip pattern on first entry to verification
                    if first_entry_to_verification = '1' then
                        r_skip_tx_original <= i_skip_tx;
                        first_entry_to_verification <= '0';
                    end if;
                    
                    -- Start transmission when TX module is not busy or during initialization
                    if tx_32bit_busy = '0' or (i_strt = '1' and initialization_done = '0') then
                        dp_from_prev_state_done <= '1';
                        -- Load data for current verification index
                        tx_32bit_data <= i_data((ver_sig_no)*32 - 1 downto (ver_sig_no-1)*32);
                        tx_32bit_start <= '1';
                        ver_no_increment_done <= '0';
                        found_first_verification_idx <= '0';
                        lock_ver_sig_no <= '0';
                    end if;

                    -- Handle transmission completion
                    if tx_32bit_done = '1' then 
                        if ver_no_increment_done = '0' then
                            ver_no_increment_done <= '1';
                            tx_32bit_start <= '0';
                            
                            -- Check if we've sent all signals or reached the end
                            if ver_sig_no = no_signals_ver - 1 or sent_all_verification_signals = '1' then
                                if flipped_to_lowest_idx = '0' then
                                    lock_ver_sig_no <= '1';
                                    ver_sig_no <= ver_sig_no_lowest;  -- Reset to lowest index
                                    o_done <= '1';
                                    sent_all_verification_signals <= '0';
                                    flipped_to_lowest_idx <= '1';
                                    found_first_verification_idx <= '1';
                                else 
                                    o_done <= '0';
                                end if;
                            else
                                o_done <= '0';
                            end if;
                        end if;
                    else
                        -- Transmission in progress
                        flipped_to_lowest_idx <= '0';
                        o_done <= '0';
                        
                        -- Find next valid index to transmit
                        if found_first_verification_idx = '0' then
                            -- Update skip mask based on current input
                            if i_skip_tx = skip_only_ones then
                                r_skip_tx <= r_skip_tx_original;
                            else
                                r_skip_tx <= i_skip_tx;
                            end if;
                            
                            -- Search for next non-skipped index
                            if lock_ver_sig_no = '0' then
                                for i in 1 to no_signals_ver-1 loop
                                    if i <= ver_sig_no then
                                        next;
                                    else
                                        if r_skip_tx(i) = '0' then
                                            ver_sig_no <= i;
                                            exit;
                                        end if;
                                        if i = no_signals_ver - 1 then
                                            sent_all_verification_signals <= '1';
                                            ver_sig_no <= ver_sig_no_lowest;
                                        end if;
                                    end if;
                                end loop;
                                found_first_verification_idx <= '1';
                            end if;
                        else 
                            -- Update skip mask if it changed
                            if i_skip_tx /= skip_only_ones then
                                if i_skip_tx /= r_skip_tx then 
                                    r_skip_tx <= i_skip_tx;
                                    found_first_verification_idx <= '0';
                                end if;
                            else
                                r_skip_tx <= r_skip_tx_original;
                            end if;
                        end if;
                    end if;

                ------------------------------------------------------------------------------
                -- OTHER STATES: Sequential transmission of simulation signals
                ------------------------------------------------------------------------------
                when others =>
                    -- Reset verification state flags
                    dp_from_prev_state_done <= '0';
                    ver_no_increment_done <= '0';
                    first_entry_to_verification <= '1';
                    
                    -- Find lowest non-skipped index for verification mode preparation
                    if found_first_verification_idx = '0' then
                        r_skip_tx <= i_skip_tx;
                        for i in 1 to no_signals_ver-1 loop
                            if r_skip_tx(i) = '0' then
                                ver_sig_no <= i;
                                ver_sig_no_lowest <= i;
                                exit;
                            end if;
                        end loop;
                        found_first_verification_idx <= '1';
                    else 
                        -- Update if skip mask changed
                        if i_skip_tx /= r_skip_tx then 
                            r_skip_tx <= i_skip_tx;
                            found_first_verification_idx <= '0';
                        end if;
                    end if;
                    
                    -- Handle initial start signal
                    if i_strt = '1' and initialization_done = '0' then
                        o_done <= '0';
                        initialization_done <= '1';
                        -- Transmit first data packet
                        tx_32bit_data <= i_data(31 downto 0);
                        sim_sig_no <= sim_sig_no + 1;
                        tx_32bit_start <= '1';
                    elsif initialization_done = '1' then
                        -- Continue transmission sequence
                        if tx_32bit_busy = '0' then
                            tx_32bit_start <= '1';
                            tx_32bit_data <= i_data(((sim_sig_no + 1) * 32)-1 downto sim_sig_no * 32);
                            flipped_done_output <= '0';
                        end if;

                        -- Handle transmission completion
                        if tx_32bit_done = '1' then
                            tx_32bit_start <= '0';
                            if sim_no_increment_done = '0' then
                                if sim_sig_no = no_signals_sim then
                                    -- All signals sent
                                    if flipped_done_output = '1' then
                                        o_done <= '0';
                                    else
                                        sim_sig_no <= 0;
                                        o_done <= '1';
                                        flipped_done_output <= '1';
                                    end if;
                                else 
                                    -- Move to next signal
                                    sim_sig_no <= sim_sig_no + 1;
                                    o_done <= '0';
                                end if;
                                sim_no_increment_done <= '1';
                            else
                                o_done <= '0';
                            end if;
                        else
                            o_done <= '0';
                            sim_no_increment_done <= '0';
                        end if;
                    end if;
            end case;
        end if;
    end process transmit_process;

end architecture rtl;
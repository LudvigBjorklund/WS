library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tx_32bit is 
	generic(
		g_clks_per_bit  : integer := 434
	);
	port(
		i_clk  : in  std_logic; -- Clock input
		i_strt : in  std_logic; -- Start signal to begin transmission
		i_data : in  unsigned(31 downto 0); -- Input data (32 bits)
		o_busy : out std_logic; -- UART busy signal
		o_done : out std_logic; -- Done signal indicating transmission complete
		o_tx   : out std_logic  -- UART serial data output
	);
end entity tx_32bit;

architecture rtl of tx_32bit is
	-- Internal signals
	signal w_tx_strt : std_logic := '0'; -- Internal start signal for submodule
	signal w_tx_data : unsigned(7 downto 0) := (others => '0'); -- Data for submodule
	signal r_tx_flg  : std_logic := '0'; -- Busy flag from TX submodule
	signal clks_per_byte : integer range 0 to g_clks_per_bit * 10 := 0; -- Clock cycles per byte (1 start, 8 data, 1 stop)
	-- State Machine control
	type t_SM_4byte is (s_idle, s_start, s_id_byte, s_dp0, s_dp1, s_dp2, s_stop, s_clean);
	signal r_SM : t_SM_4byte := s_idle;

	signal r_tx_byte : std_logic := '1'; -- Output from TX submodule
	signal r_tx_done : std_logic := '0'; -- Done signal from TX submodule
	-- Internal registers
	signal r_active  : std_logic := '0'; -- Indicates active transmissional
	signal r_data	: unsigned(31 downto 0) := (others => '0'); -- Latched input data 
    signal r_flip   : std_logic := '0'; -- Flip signal to toggle between bytes
	-- Debbugging, checking the state machine
	signal state_no : integer range 0 to 8 := 0;
	component tx is
   generic(g_clks_per_bit : integer := 434); -- Number of clock cycles per bit
    port(
        i_clk  : in std_logic; -- Clock input
        i_strt : in std_logic; -- Start transmission signal
        i_data : in unsigned(7 downto 0); -- Data to transmit over UART
        o_busy : out std_logic; -- Busy signal indicating transmission in progress
		o_done : out std_logic; -- Done signal indicating transmission complete
        o_tx   : out std_logic  -- UART serial data output
    );
end component tx;

begin
	-- -- Instantiate the TX submodule
	tx_inst : tx generic map(g_clks_per_bit => g_clks_per_bit)
		port map(
			i_clk  => i_clk,
			i_strt => w_tx_strt,
			i_data => w_tx_data,
			o_busy => r_tx_flg,
			o_done => r_tx_done,
			o_tx   => o_tx
		);

	-- -- Main state machine for 32-bit transmission
	transmit_state_machine : process(i_clk)
	begin
		if rising_edge(i_clk) then
			case r_SM is
				-- Idle state: wait for start signal
				when s_idle =>
                    state_no <= 0;
                    w_tx_strt <= '0';
                  --  w_tx_data <= (others => '0');
                    o_busy <= '0';
                    -- Send the start byte and move to the ID byte state
                    if i_strt = '1' then
                        w_tx_data <= "11111111"; -- Start byte
                        w_tx_strt <= '1';
                        r_active <= '1'; -- Set active flag for the component
                        o_busy <= '1';
                        r_SM <= s_id_byte;
						o_done <= '0'; -- Clear done signal on new transmission	
						r_data <= i_data; -- Latch input data
						r_flip <= '1';
                    end if;
				-- Transmit the ID byte (MSB of input data)
                when s_id_byte =>
                    state_no <= 2;
					-- Update data packet when TX submodule is not busy and star the signal
					if r_tx_flg = '0' and r_flip ='0' then
						w_tx_strt <= '1';
						w_tx_data <= r_data(31 downto 24);
					end if;
					-- Ensure that we go low before going to the next state
				    if r_tx_done = '0' then
						r_flip <= '0';
					end if;
					if r_tx_done = '1' and r_flip ='0'  then
						r_SM <= s_dp0;
						w_tx_strt <= '0';
					end if;
				-- Transmit Data Byte 0
				when s_dp0 =>
					state_no <= 3;
					if r_tx_flg = '0' then
						w_tx_strt <= '1';
						w_tx_data <= r_data(23 downto 16);
					end if;
					if r_tx_done = '1' then
						r_SM <= s_dp1;
						w_tx_strt <= '0';
					end if;

				-- Transmit Data Byte 1
				when s_dp1 =>
					state_no <= 4;
					if r_tx_flg = '0' then
						w_tx_strt <= '1';
						w_tx_data <= r_data(15 downto 8);
					end if;
					if r_tx_done = '1' then
						r_SM <= s_dp2;
						w_tx_strt <= '0';
					end if;

				-- Transmit Data Byte 2
				when s_dp2 =>
					state_no <= 5;
					if r_tx_flg = '0' then
						w_tx_strt <= '1';
						w_tx_data <= r_data(7 downto 0);
					end if;
					if r_tx_done = '1' then
						r_SM <= s_stop;
						w_tx_strt <= '0';
					end if;

				-- Stop state: send a stop byte
				when s_stop =>
					state_no <= 6;
					if r_tx_flg = '0' then
						w_tx_strt <= '1';
						w_tx_data <= (others => '1'); -- Stop byte
					end if;
					if r_tx_done = '1' then
						r_SM <= s_clean;
						--o_busy <= '0';
						w_tx_strt <= '0';
					end if;


				-- Clean state: finalize and reset
				when s_clean =>
					state_no <= 7;
					if r_tx_flg = '0' then
						r_active <= '0'; -- Clear active flag
						o_busy <= '0';
						w_tx_strt <= '0';
					end if;
					if r_tx_done = '1' then
						r_SM <= s_idle;	-- All the bytes have been sent, go to idle and await for a new start signal
						--o_busy <= '1';
						o_done <= '1'; -- Signal that the entire 32-bit transmission is complete
					end if;
		
				-- Default state (shouldn't happen)
				when others =>
					r_SM <= s_idle;
			end case;

			-- Update busy output signal
			--o_busy <= r_active;
		end if;
	end process;
end architecture rtl;

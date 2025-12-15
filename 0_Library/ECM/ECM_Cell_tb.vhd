library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;

entity ECM_Cell_tb is
end entity ECM_Cell_tb;

architecture sim of ECM_Cell_tb is
    constant c_clk_period   : time    := 10 ns;
    constant c_timestep     : integer := 4;
    constant c_n_b_SOC      : integer := 16;
    constant c_n_int_SOC    : integer := 7;
    constant c_n_b_I        : integer := 16;
    constant c_n_int_I      : integer := 4;
    constant c_n_b_Q        : integer := 16;
    constant c_n_int_Q      : integer := -8;

    signal clk        : std_logic := '0';
    signal state      : t_state   := s_idle;
    signal charging   : std_logic := '0';
    signal soc0       : unsigned(c_n_b_SOC-1 downto 0) := (others => '0');
    signal current       : unsigned(c_n_b_I-1 downto 0)   := (others => '0');
    signal capacity   : unsigned(c_n_b_Q-1 downto 0)   := (others => '0');

    signal ow_R0      : unsigned(23 downto 0) := (others => '0');
    signal ow_a1      : unsigned(23 downto 0) := (others => '0');
    signal ow_c1      : unsigned(23 downto 0) := (others => '0');
    signal ow_a2      : unsigned(23 downto 0) := (others => '0');
    signal ow_c2      : unsigned(23 downto 0) := (others => '0');

    constant c_expected_n_frac_SOC : integer := c_n_b_SOC - c_n_int_SOC;

begin
    -- Clock generation
    clk <= not clk after c_clk_period / 2;

    -- Device under test
    dut_inst : entity work.ECM_Cell
        generic map(
            timestep  => c_timestep,
            n_b_SOC   => c_n_b_SOC,
            n_b_I     => c_n_b_I,
            n_b_Q     => c_n_b_Q,
            n_int_SOC => c_n_int_SOC,
            n_int_I   => c_n_int_I,
            n_int_Q   => c_n_int_Q
        )
        port map(
            i_clk      => clk,
            i_state    => state,
            i_charging => charging,
            i_SOC0     => soc0,
            i_I        => current,
            i_Q        => capacity,
            i_ow_R0    => ow_R0,
            i_ow_a1    => ow_a1,
            i_ow_c1    => ow_c1,
            i_ow_a2    => ow_a2,
            i_ow_c2    => ow_c2
        );
end architecture sim;

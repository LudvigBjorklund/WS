library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;
entity rx_route4byte is
    generic(
        n_signals : integer := 3
    );
    port(
        i_clk   : in std_logic; -- Clock input
        i_state : in t_state; -- State signal
        i_init_data : in unsigned((n_signals*24) - 1 downto 0); -- Initial concatenated data bus
        i_data  : in unsigned(31 downto 0); -- Input data from the rx_4byte component
        i_busy  : in std_logic; 
        o_data  : out unsigned((n_signals*24) - 1 downto 0)
    );
end entity rx_route4byte;

architecture rtl of rx_route4byte is
    signal r_initialize : integer range 0 to 1 := 0; -- Signal to control initialization of the receiver
    signal dbg_tracker_vindex : integer range 0 to n_signals-1 := 0; -- Debug tracker for the index of the signal being processed
begin 

    -- assign_data2bus_p : process(i_clk)
    -- variable v_index : integer range 0 to n_signals-1;
    -- variable v_index_temp : integer;  -- Unconstrained for bounds checking
    -- variable one_clk_cycle_reset : integer := 0;
    -- begin
    --     if rising_edge(i_clk) then
    --         dbg_tracker_vindex <= v_index;
    --         if r_initialize = 0 then
    --             o_data <= i_init_data;
    --         else
    --             if i_busy = '0' then
    --                 v_index_temp := to_integer(unsigned(i_data(31 downto 24))) - 1;
    --                 if v_index_temp >= 0 and v_index_temp < n_signals then
    --                     v_index := v_index_temp;
    --                     o_data(v_index*24 + 23 downto v_index*24) <= i_data(23 downto 0);
    --                 end if;
    --             end if;
    --         end if;
    --              case i_state is
    --             when s_idle =>
    --                 if one_clk_cycle_reset = 0 then
    --                     r_initialize <= 0; -- Reset initialization signal in idle state
    --                     one_clk_cycle_reset := 1;
    --                 else
    --                    -- one_clk_cycle_reset := 0;
    --                     r_initialize <= 1; -- Set to 1 to indicate initialization is done
    --                 end if;
    --             when others =>
    --                 one_clk_cycle_reset := 0; -- Reset the one clock cycle flag in other states
    --         end case;
    --         -- Assign the input data to the output bus based on the index

    --     end if;
    -- end process assign_data2bus_p;



    assign_data2bus_p : process(i_clk)
    variable v_index : integer range 0 to n_signals;
    variable one_clk_cycle_reset : integer := 0;
    begin
        if rising_edge(i_clk) then
            dbg_tracker_vindex <= v_index; -- Update the debug tracker with the current index
            if r_initialize = 0 then
                -- Initialize the output data bus with the initial data
                o_data <= i_init_data;
               -- r_initialize <= 1; -- Set to 1 to indicate initialization is done
            else
                if i_busy = '0' then
                    if to_integer(unsigned(i_data(31 downto 24))) - 1 >=0 then
                         v_index := to_integer(unsigned(i_data(31 downto 24))) - 1; -- Extract the index from the ID portion
                        if v_index >= 0 and v_index < n_signals then
                            o_data(v_index*24 + 23 downto v_index*24) <= i_data(23 downto 0); -- Assign the data to the corresponding signal
                        end if;
                    else
                        v_index := 0; -- Default to index 0 if the index is invalid
                        --o_data(23 downto 0) <= i_data(23 downto 0); -- Assign the data to the first signal
                    end if;
                end if;
            end if;

            case i_state is
                when s_idle =>
                    if one_clk_cycle_reset = 0 then
                        r_initialize <= 0; -- Reset initialization signal in idle state
                        one_clk_cycle_reset := 1;
                    else
                       -- one_clk_cycle_reset := 0;
                        r_initialize <= 1; -- Set to 1 to indicate initialization is done
                    end if;
                when others =>
                    one_clk_cycle_reset := 0; -- Reset the one clock cycle flag in other states
            end case;
            -- Assign the input data to the output bus based on the index

        end if;
    end process assign_data2bus_p;



end architecture;
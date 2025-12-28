-- library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.numeric_std.all;


-- package Common is

--     type t_state is (s_idle, s_init, s_sim,s_verification, s_reset,  s_pause, s_end);
--     type array_16char_mif is array(natural range <>) of string(1 to 16);
-- end Common;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package Common is
    
    -- Type definitions
    type t_state is (s_idle, s_init, s_sim, s_verification, s_reset, s_pause, s_end);
    type array_16char_mif is array(natural range <>) of string(1 to 16);
    
    -- Compile-time constant calculation functions
    function power_of_2(n : integer) return integer;
    function log2_ceil(n : integer) return integer;
    function calc_bit_width(max_value : integer) return integer;
    
    -- Example system constants (you can modify these)
    --  c_timestep : integer := 2;
   -- constant c_dt : integer := power_of_2(c_timestep);  -- Automatically = 4
    
end package Common;

package body Common is
    
    -- Calculate 2^n at compile time
    function power_of_2(n : integer) return integer is
        variable result : integer := 1;
    begin
        if n < 0 then
            return 0;  -- Can't represent fractional values as integer
        elsif n = 0 then
            return 1;
        else
            for i in 1 to n loop
                result := result * 2;
            end loop;
            return result;
        end if;
    end function power_of_2;
    
    -- Calculate ceiling of log2(n) - useful for bit width calculations
    function log2_ceil(n : integer) return integer is
        variable temp : integer := n - 1;
        variable result : integer := 0;
    begin
        if n <= 1 then
            return 0;
        end if;
        
        while temp > 0 loop
            temp := temp / 2;
            result := result + 1;
        end loop;
        
        return result;
    end function log2_ceil;
    
    -- Calculate required bit width to represent a maximum value
    function calc_bit_width(max_value : integer) return integer is
    begin
        if max_value <= 0 then
            return 1;
        end if;
        return log2_ceil(max_value + 1);
    end function calc_bit_width;
    
end package body Common;

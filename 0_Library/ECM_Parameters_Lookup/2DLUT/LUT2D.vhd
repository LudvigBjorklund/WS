library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common.all;
-- Make a special test-bench for this file, so we can test it separately


entity LUT2D is 
    generic(
    table_mif : string := "R0.mif";
    table_name : string := "R0";
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
end entity LUT2D;

architecture rtl of LUT2D is

component tbl_read_ow is 
    generic(
        hex_init : string := "LUT_2D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;                     -- Clock signal
        i_raddr : in  unsigned(7 downto 0);            -- Read address (8-bit)
        i_waddr : in  unsigned(7 downto 0);            -- Writ,e address (8-bit)
        i_data  : in  unsigned(15 downto 0);           -- 16-bit data input for write
        i_wr_en : in  std_logic;                     -- Write enable signal
        o_data  : out unsigned(15 downto 0)            -- 16-bit data output for read
    );
end component tbl_read_ow;

component tbl_reset_rd is 
    generic(
        hex_init : string := "LUT_2D.hex"  -- Name of the HEX (or MIF) file for initialization
    );
    port(
        i_clk   : in  std_logic;           -- Clock signal
        i_raddr : in  unsigned(7 downto 0); -- Read address (8-bit)
        o_data  : out unsigned(15 downto 0) -- 16-bit data output for read
    );
end component tbl_reset_rd;

signal x12, x21, x22 : unsigned(15 downto 0) := (others => '0');
signal x11 : unsigned(15 downto 0) := x11_init;
signal x11_raddr, x21_raddr, x22_raddr : unsigned(7 downto 0) := (others => '0');
signal x12_raddr : unsigned(7 downto 0) := "00000001";
signal row_fraction, col_fraction : unsigned(15 downto 0) := (others => '0'); -- Fractional parts of row and column indices
signal rc_add : unsigned(15 downto 0) := (others => '0'); -- Row and column addition result
signal rc_mul : unsigned(15 downto 0) := (others => '0');

signal w11_case : std_logic := '0'; -- Case selection for w11
signal w11, w12, w21, w22 : unsigned(15 downto 0) := (others => '0');
signal r_wr_en : std_logic := '0'; -- Write enable signal for the table

signal wr_addr : unsigned(7 downto 0) := (others => '0'); -- Write address for the table
signal wr_data : unsigned(15 downto 0) := (others => '0'); -- Data to write to the table

signal r_state : t_state := s_idle; -- State of the LUT2D operation
signal r_val : unsigned(31 downto 0) := (others => '0'); -- Output value from the LUT2D operation

signal r_rst_addr : unsigned(7 downto 0) := (others => '0'); -- Reset address for the table
signal r_rst_data : unsigned(15 downto 0) := (others => '0'); -- Reset data for the table

signal init_done : std_logic := '0'; -- Initialization done signal
signal wait_two_cycles : integer range 0 to 4 := 0;

begin
    -- Instantiate tbl_read_ow for reading x11 
    tbl_read_ow_x11: tbl_read_ow
        generic map(
            hex_init => table_mif
            )
        port map(
            i_clk   => i_clk,
            i_raddr => x11_raddr,
            i_waddr => wr_addr,
            i_data  => wr_data,           
            i_wr_en => r_wr_en,
            o_data  => x11
        );
    -- Instantiate tbl_read_ow for reading x12
    tbl_read_ow_x12: tbl_read_ow
        generic map(
            hex_init => table_mif)
        port map(
            i_clk   => i_clk,
            i_raddr => x12_raddr,
            i_waddr => wr_addr,
            i_data  => wr_data,
            i_wr_en => r_wr_en,
            o_data  => x12
        );
    -- Instantiate tbl_read_ow for reading x21
    tbl_read_ow_x21: tbl_read_ow
        generic map(
            hex_init => table_mif)
        port map(
            i_clk   => i_clk,
            i_raddr => x21_raddr,
            i_waddr => wr_addr,
            i_data  => wr_data,
            i_wr_en => r_wr_en,
            o_data  => x21
        );
    -- Instantiate tbl_read_ow for reading x22
    tbl_read_ow_x22: tbl_read_ow
        generic map(
            hex_init => table_mif)
        port map(
            i_clk   => i_clk,
            i_raddr => x22_raddr,
            i_waddr => wr_addr,
            i_data => wr_data,            
            i_wr_en => r_wr_en,
            o_data  => x22
        );    
    -- Instantiate tbl_reset_rd for 
    tbl_reset_rd_x11: tbl_reset_rd
        generic map(
            hex_init => table_mif)
        port map(
            i_clk   => i_clk,
            i_raddr => r_rst_addr,
            o_data  => r_rst_data
        );

    
    process(i_clk)
    variable initialization_counter : integer range 0 to 3:= 0;
    variable counter_reset : integer range 0 to 3 := 0;

    begin
        if rising_edge(i_clk) then
            o_busy <= not init_done;
            case i_state is 
                when s_idle => -- Reset 
                    x11_raddr <= to_unsigned(0, 8); -- Reset the read address
                    x12_raddr <= to_unsigned(1, 8);
                    x21_raddr <= to_unsigned(11, 8);
                    x22_raddr <= to_unsigned(12, 8);
                    o_val <= x11(15 downto 0); -- Output the value from x11
                    if counter_reset < 2 then                
                        counter_reset := counter_reset + 1; -- Increment the reset counter
                        if counter_reset >= 1 then
                            wr_addr <= to_unsigned(0, 8); -- Reset the write address
                            wr_data <= r_rst_data; -- Reset the write data
                            r_rst_addr <= r_rst_addr + 1; -- Increment the reset address

                        end if;
                    else
                        r_wr_en <= '1'; -- Enable write operation


                        if r_rst_addr < to_unsigned(175, 8) then
                            r_rst_addr <= r_rst_addr + 1;
                        else 
                            r_rst_addr <= r_rst_addr;
                        end if;

                        if wr_addr < to_unsigned(175, 8) then
                            wr_data <= r_rst_data; -- Reset the write data
                            wr_addr <= wr_addr + 1; -- Increment the write address
                        else 
                            wr_addr <= wr_addr; -- Keep the write address unchanged
                            r_wr_en <= '0';
                        end if;

                    end if;
                when s_init =>
                    r_wr_en <= '1'; -- Enable write operation
                    wr_addr <= i_ow_addr; -- Set the write address to the input address
                    wr_data <= i_ow_data; -- Set the write data to the input data   
                    counter_reset := 0; -- Reset the counter to 0
                    r_rst_addr <= to_unsigned(0, 8); -- Reset address for the table
                    if init_done = '1' then
                        if i_ridx(11 downto 8) >= "1111" or i_cidx(11 downto 8) >= "1010" then                              -- Saturation in row or column
                            if i_ridx(11 downto 8) >= "1111" then                                                           -- Saturation in row (x21 and x22 is not accessible)
                                x11_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                x12_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)+1), 8); 
                                x21_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8);
                                x22_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8))+1, 8);
                                row_fraction(15 downto 8) <= (others => '0');
                                col_fraction(15 downto 8) <= i_cidx(7 downto 0); 
                                rc_add(15 downto 8) <= i_cidx(7 downto 0); -- Row and column addition result
                                
                                rc_mul <= (others => '0'); -- Row and column multiplication result
                            else                                                                                            -- Saturation in column (x12 and x22 is not accessible)
                                x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                row_fraction(15 downto 8) <= i_ridx(7 downto 0); -- Row fractional part
                                col_fraction(15 downto 8) <= (others => '0');
                                rc_add(15 downto 8) <= i_ridx(7 downto 0); -- Row and column addition result
                                rc_mul <= (others => '0'); -- Row and column multiplication result
                            end if;                        
                        else                                                                                                -- No saturation, normal operation
                            x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8)), 8); 
                            x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                            x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8)), 8); 
                            x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                            
                            row_fraction(15 downto 8) <= i_ridx(7 downto 0);
                            col_fraction(15 downto 8) <= i_cidx(7 downto 0);

                            rc_add(15 downto 8) <= i_ridx(7 downto 0) + i_cidx(7 downto 0); -- Row and column addition result
                            rc_mul <= i_ridx(7 downto 0) * i_cidx(7 downto 0); -- Row and column multiplication result
                        end if;

                        if i_ridx(11 downto 8) < "1111" and i_cidx(11 downto 8) < "1010" then  -- Neither is saturated 00
                            if i_ridx(7 downto 0) = "00000000" and i_cidx(7 downto 0) = "00000000" then -- No fractional part -------------- 0000
                                w11_case <= '0'; -- Reset the w11_case signal
                            else 
                                if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- Only one fractional part
                                    if i_ridx(7 downto 0) = "00000000" then ------------------------------------------------------------- 0001
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    else                                                ------------------------------------------------- 0010
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    end if;
                                else -- Both row and column have fractional parts, we need to read x12 and x22  ------------------------- 0011
                                    if i_ridx(7) ='1' and i_cidx(7) ='1' then -- Addition will be larger than 1
                                        w11_case <= '1'; 
                                    else    
                                        if i_ridx(7) = '1' nor i_cidx(7) = '1' then 
                                            w11_case <= '0'; 
                                        else                                                        -- One of them is '1', so we need to check (6)
                                            if i_ridx(6) ='1' and i_cidx(6) ='1' then               -- Addition will be larger than 1   
                                                w11_case <= '1';
                                            else
                                                if i_ridx(6) ='1' nor i_cidx(6) = '1' then          -- Neither is 1 and we can break her
                                                    w11_case <= '0'; 
                                                else
                                                    if i_ridx(5) ='1' and i_cidx(5) ='1' then       -- Addition will be larger than 1
                                                        w11_case <= '1';          
                                                    else
                                                        if i_ridx(5) ='1' nor i_cidx(5) = '1' then  -- Neither is 1 and we can break her
                                                            w11_case <= '0'; 
                                                        else
                                                            if i_ridx(4) ='1' and i_cidx(4) ='1' then -- Addition will be larger than 1
                                                                w11_case <= '1'; 
                                                            else
                                                                if i_ridx(4) ='1' nor i_cidx(4) = '1' then -- Neither is 1 and we can break her
                                                                    w11_case <= '0'; 
                                                                else
                                                                    if i_ridx(3) ='1' and i_cidx(3) ='1' then -- Addition will be larger than 1
                                                                        w11_case <= '1'; 
                                                                    else
                                                                        if i_ridx(3) ='1' nor i_cidx(3) = '1' then                      -- Neither is 1 and we can break her
                                                                            w11_case <= '0'; 
                                                                        else                                                            -- One of them    
                                                                            if i_ridx(2) ='1' and i_cidx(2) ='1' then                   -- Addition will be larger than 1
                                                                                w11_case <= '1'; 
                                                                            else                                                        -- One of them can still be '1', so we need to check (2)
                                                                                if i_ridx(2) ='1' nor i_cidx(2) = '1' then              -- Neither (2) is 1 and we can break her
                                                                                    w11_case <= '0'; 
                                                                                else                                                    -- One of them is '1', so we need to check (1)
                                                                                    if i_ridx(1) ='1' and i_cidx(1) ='1' then           -- Addition will be larger than 1
                                                                                        w11_case <= '1'; 
                                                                                    else 
                                                                                        if i_ridx(1) ='1' nor i_cidx(1) = '1' then      -- Neither (1) is 1 and we can break her
                                                                                            w11_case <= '0'; 
                                                                                        else 
                                                                                            if i_ridx(0) ='1' and i_cidx(0) ='1' then   -- Addition will be larger than 1
                                                                                                w11_case <= '1'; 
                                                                                            else 
                                                                                                w11_case <= '0'; 
                                                                                            end if;
                                                                                        end if;
                                                                                    end if;
                                                                                end if;
                                                                            end if;
                                                                        end if;
                                                                    end if;
                                                                end if;
                                                            end if;
                                                        end if;
                                                    end if;
                                                end if;
                                            end if;
                                        end if;
                                    end if;
                                end if;
                            end if;
                        else -- Potentiall both or 1 is saturated (11,10,01)
                            if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- No fractional part 
                                w11_case <= '0'; 
                            end if;
                        end if;

                        if w11_case = '1' then
                            w11 <= rc_mul - (rc_add -"1111111111111111");
                        else 
                            w11 <= "1111111111111111"- (rc_add-rc_mul);
                        end if;
                        w12 <= col_fraction - rc_mul;
                        w21 <= row_fraction - rc_mul;
                        w22 <= rc_mul;

                        r_val <= x11*w11+x12*w12+x21*w21+x22*w22; -- Calculate the output value
                        o_val <= r_val(31 downto 16);
                    else
                        ------------------ t = 0 ------------------
                        if i_ridx(11 downto 8) >= "1111" and i_cidx(11 downto 8) >= "1010" then                                -- Saturation in both row and column                                
                            -- both are saturated x11 
                            x11_raddr <= to_unsigned(176, 8); 
                            x12_raddr <= to_unsigned(176, 8); 
                            x21_raddr <= to_unsigned(176, 8); 
                            x22_raddr <= to_unsigned(176, 8);
                            row_fraction(15 downto 8) <= (others => '0'); 
                            col_fraction(15 downto 8) <= (others => '0');
                            rc_add <= (others => '0'); -- Row and column addition result
                        else 
                            if initialization_counter < 3 then


                                initialization_counter := initialization_counter + 1; -- Increment the initialization counter
                            else
                                initialization_counter := 0; -- Set the counter to 2 to avoid further increments
                            end if;
                            if initialization_counter >= 0 then -- 
                                if i_ridx(11 downto 8) >= "1111" or i_cidx(11 downto 8) >= "1010" then                              -- Saturation in row or column
                                    if i_ridx(11 downto 8) >= "1111" then                                                           -- Saturation in row (x21 and x22 is not accessible)
                                        x11_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                        x12_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)+1), 8); 
                                        x21_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8);
                                        x22_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8))+1, 8);
                                        row_fraction(15 downto 8) <= (others => '0');
                                        col_fraction(15 downto 8) <= i_cidx(7 downto 0); 
                                        rc_add(15 downto 8) <= i_cidx(7 downto 0); -- Row and column addition result
                                        
                                        rc_mul <= (others => '0'); -- Row and column multiplication result
                                    else                                                                                            -- Saturation in column (x12 and x22 is not accessible)
                                        x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                        x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                        x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                        x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                        row_fraction(15 downto 8) <= i_ridx(7 downto 0); -- Row fractional part
                                        col_fraction(15 downto 8) <= (others => '0');
                                        rc_add(15 downto 8) <= i_ridx(7 downto 0); -- Row and column addition result
                                        rc_mul <= (others => '0'); -- Row and column multiplication result
                                    end if;                        
                                else                                                                                                -- No saturation, normal operation
                                    x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                    x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                                    x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                    x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                                    
                                    row_fraction(15 downto 8) <= i_ridx(7 downto 0);
                                    col_fraction(15 downto 8) <= i_cidx(7 downto 0);

                                    rc_add(15 downto 8) <= i_ridx(7 downto 0) + i_cidx(7 downto 0); -- Row and column addition result
                                    rc_mul <= i_ridx(7 downto 0) * i_cidx(7 downto 0); -- Row and column multiplication result
                                end if;

                                if i_ridx(11 downto 8) < "1111" and i_cidx(11 downto 8) < "1010" then  -- Neither is saturated 00
                                    if i_ridx(7 downto 0) = "00000000" and i_cidx(7 downto 0) = "00000000" then -- No fractional part -------------- 0000
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    else 
                                        if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- Only one fractional part
                                            if i_ridx(7 downto 0) = "00000000" then ------------------------------------------------------------- 0001
                                                w11_case <= '0'; -- Reset the w11_case signal
                                            else                                                ------------------------------------------------- 0010
                                                w11_case <= '0'; -- Reset the w11_case signal
                                            end if;
                                        else -- Both row and column have fractional parts, we need to read x12 and x22  ------------------------- 0011
                                            if i_ridx(7) ='1' and i_cidx(7) ='1' then -- Addition will be larger than 1
                                                w11_case <= '1'; 
                                            else    
                                                if i_ridx(7) = '1' nor i_cidx(7) = '1' then 
                                                    w11_case <= '0'; 
                                                else                                                        -- One of them is '1', so we need to check (6)
                                                    if i_ridx(6) ='1' and i_cidx(6) ='1' then               -- Addition will be larger than 1   
                                                        w11_case <= '1';
                                                    else
                                                        if i_ridx(6) ='1' nor i_cidx(6) = '1' then          -- Neither is 1 and we can break her
                                                            w11_case <= '0'; 
                                                        else
                                                            if i_ridx(5) ='1' and i_cidx(5) ='1' then       -- Addition will be larger than 1
                                                                w11_case <= '1';          
                                                            else
                                                                if i_ridx(5) ='1' nor i_cidx(5) = '1' then  -- Neither is 1 and we can break her
                                                                    w11_case <= '0'; 
                                                                else
                                                                    if i_ridx(4) ='1' and i_cidx(4) ='1' then -- Addition will be larger than 1
                                                                        w11_case <= '1'; 
                                                                    else
                                                                        if i_ridx(4) ='1' nor i_cidx(4) = '1' then -- Neither is 1 and we can break her
                                                                            w11_case <= '0'; 
                                                                        else
                                                                            if i_ridx(3) ='1' and i_cidx(3) ='1' then -- Addition will be larger than 1
                                                                                w11_case <= '1'; 
                                                                            else
                                                                                if i_ridx(3) ='1' nor i_cidx(3) = '1' then                      -- Neither is 1 and we can break her
                                                                                    w11_case <= '0'; 
                                                                                else                                                            -- One of them    
                                                                                    if i_ridx(2) ='1' and i_cidx(2) ='1' then                   -- Addition will be larger than 1
                                                                                        w11_case <= '1'; 
                                                                                    else                                                        -- One of them can still be '1', so we need to check (2)
                                                                                        if i_ridx(2) ='1' nor i_cidx(2) = '1' then              -- Neither (2) is 1 and we can break her
                                                                                            w11_case <= '0'; 
                                                                                        else                                                    -- One of them is '1', so we need to check (1)
                                                                                            if i_ridx(1) ='1' and i_cidx(1) ='1' then           -- Addition will be larger than 1
                                                                                                w11_case <= '1'; 
                                                                                            else 
                                                                                                if i_ridx(1) ='1' nor i_cidx(1) = '1' then      -- Neither (1) is 1 and we can break her
                                                                                                    w11_case <= '0'; 
                                                                                                else 
                                                                                                    if i_ridx(0) ='1' and i_cidx(0) ='1' then   -- Addition will be larger than 1
                                                                                                        w11_case <= '1'; 
                                                                                                    else 
                                                                                                        w11_case <= '0'; 
                                                                                                    end if;
                                                                                                end if;
                                                                                            end if;
                                                                                        end if;
                                                                                    end if;
                                                                                end if;
                                                                            end if;
                                                                        end if;
                                                                    end if;
                                                                end if;
                                                            end if;
                                                        end if;
                                                    end if;
                                                end if;
                                            end if;
                                        end if;
                                    end if;
                                else -- Potentiall both or 1 is saturated (11,10,01)
                                    if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- No fractional part 
                                        w11_case <= '0'; 
                                    end if;
                                end if;
                            end if;
                            if initialization_counter >=1 then -- Calculate the weights
                                if w11_case = '1' then
                                    w11 <= rc_mul - (rc_add -"1111111111111111");
                                else 
                                    w11 <= "1111111111111111"- (rc_add-rc_mul);
                                end if;
                                w12 <= col_fraction - rc_mul;
                                w21 <= row_fraction - rc_mul;
                                w22 <= rc_mul;
                            end if;

                            if initialization_counter > 2 then
                                r_val <= x11*w11+x12*w12+x21*w21+x22*w22; -- Calculate the output value
                                init_done <= '1'; -- Set the initialization done signal
                            end if;
                        end if;
                        
                    end if;

                ------------------------------------------------------------------------------------------------------------------------------------ Initialization  
                ------------------------------------------------------------------------------------------------------------------------------------ Verification  
                when s_verification => 
                    -- The rd address are set row_idx(11 downto 8)*11 + col_idx(11 downto 8) and done from the top-level
                    r_wr_en <= '0'; -- Disable write operation
                    --rd_addr <= i_ridx(11 downto 8) & i_cidx(11 downto 8); -- Set the read address to the input row and column indices
                    if wait_two_cycles < 4 then
                        wait_two_cycles <= wait_two_cycles + 1;
                    else
                        wait_two_cycles <= 0;
                        o_val <= x11(15 downto 0); -- Output the value from x11
                    end if;
                    x11_raddr <= unsigned(std_logic_vector(i_ridx(11 downto 8)) & std_logic_vector(i_cidx(11 downto 8)));
                    
                    counter_reset := 0; -- Reset the counter to 0
                ------------------------------------------------------------------------------------------------------------------------------------ Verification  
                ------------------------------------------------------------------------------------------------------------------------------------ OTHERS  

                when others =>
                    counter_reset := 0;

                    r_rst_addr <= to_unsigned(0, 8); -- Reset address for the table
                    if init_done = '1' then
                        if i_ridx(11 downto 8) >= "1111" or i_cidx(11 downto 8) >= "1010" then                              -- Saturation in row or column
                            if i_ridx(11 downto 8) >= "1111" then                                                           -- Saturation in row (x21 and x22 is not accessible)
                                x11_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                x12_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)+1), 8); 
                                x21_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8);
                                x22_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8))+1, 8);
                                row_fraction(15 downto 8) <= (others => '0');
                                col_fraction(15 downto 8) <= i_cidx(7 downto 0); 
                                rc_add(15 downto 8) <= i_cidx(7 downto 0); -- Row and column addition result
                                
                                rc_mul <= (others => '0'); -- Row and column multiplication result
                            else                                                                                            -- Saturation in column (x12 and x22 is not accessible)
                                x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                row_fraction(15 downto 8) <= i_ridx(7 downto 0); -- Row fractional part
                                col_fraction(15 downto 8) <= (others => '0');
                                rc_add(15 downto 8) <= i_ridx(7 downto 0); -- Row and column addition result
                                rc_mul <= (others => '0'); -- Row and column multiplication result
                            end if;                        
                        else                                                                                                -- No saturation, normal operation
                            x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8)), 8); 
                            x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                            x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8)), 8); 
                            x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                            
                            row_fraction(15 downto 8) <= i_ridx(7 downto 0);
                            col_fraction(15 downto 8) <= i_cidx(7 downto 0);

                            rc_add(15 downto 8) <= i_ridx(7 downto 0) + i_cidx(7 downto 0); -- Row and column addition result
                            rc_mul <= i_ridx(7 downto 0) * i_cidx(7 downto 0); -- Row and column multiplication result
                        end if;

                        if i_ridx(11 downto 8) < "1111" and i_cidx(11 downto 8) < "1010" then  -- Neither is saturated 00
                            if i_ridx(7 downto 0) = "00000000" and i_cidx(7 downto 0) = "00000000" then -- No fractional part -------------- 0000
                                w11_case <= '0'; -- Reset the w11_case signal
                            else 
                                if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- Only one fractional part
                                    if i_ridx(7 downto 0) = "00000000" then ------------------------------------------------------------- 0001
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    else                                                ------------------------------------------------- 0010
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    end if;
                                else -- Both row and column have fractional parts, we need to read x12 and x22  ------------------------- 0011
                                    if i_ridx(7) ='1' and i_cidx(7) ='1' then -- Addition will be larger than 1
                                        w11_case <= '1'; 
                                    else    
                                        if i_ridx(7) = '1' nor i_cidx(7) = '1' then 
                                            w11_case <= '0'; 
                                        else                                                        -- One of them is '1', so we need to check (6)
                                            if i_ridx(6) ='1' and i_cidx(6) ='1' then               -- Addition will be larger than 1   
                                                w11_case <= '1';
                                            else
                                                if i_ridx(6) ='1' nor i_cidx(6) = '1' then          -- Neither is 1 and we can break her
                                                    w11_case <= '0'; 
                                                else
                                                    if i_ridx(5) ='1' and i_cidx(5) ='1' then       -- Addition will be larger than 1
                                                        w11_case <= '1';          
                                                    else
                                                        if i_ridx(5) ='1' nor i_cidx(5) = '1' then  -- Neither is 1 and we can break her
                                                            w11_case <= '0'; 
                                                        else
                                                            if i_ridx(4) ='1' and i_cidx(4) ='1' then -- Addition will be larger than 1
                                                                w11_case <= '1'; 
                                                            else
                                                                if i_ridx(4) ='1' nor i_cidx(4) = '1' then -- Neither is 1 and we can break her
                                                                    w11_case <= '0'; 
                                                                else
                                                                    if i_ridx(3) ='1' and i_cidx(3) ='1' then -- Addition will be larger than 1
                                                                        w11_case <= '1'; 
                                                                    else
                                                                        if i_ridx(3) ='1' nor i_cidx(3) = '1' then                      -- Neither is 1 and we can break her
                                                                            w11_case <= '0'; 
                                                                        else                                                            -- One of them    
                                                                            if i_ridx(2) ='1' and i_cidx(2) ='1' then                   -- Addition will be larger than 1
                                                                                w11_case <= '1'; 
                                                                            else                                                        -- One of them can still be '1', so we need to check (2)
                                                                                if i_ridx(2) ='1' nor i_cidx(2) = '1' then              -- Neither (2) is 1 and we can break her
                                                                                    w11_case <= '0'; 
                                                                                else                                                    -- One of them is '1', so we need to check (1)
                                                                                    if i_ridx(1) ='1' and i_cidx(1) ='1' then           -- Addition will be larger than 1
                                                                                        w11_case <= '1'; 
                                                                                    else 
                                                                                        if i_ridx(1) ='1' nor i_cidx(1) = '1' then      -- Neither (1) is 1 and we can break her
                                                                                            w11_case <= '0'; 
                                                                                        else 
                                                                                            if i_ridx(0) ='1' and i_cidx(0) ='1' then   -- Addition will be larger than 1
                                                                                                w11_case <= '1'; 
                                                                                            else 
                                                                                                w11_case <= '0'; 
                                                                                            end if;
                                                                                        end if;
                                                                                    end if;
                                                                                end if;
                                                                            end if;
                                                                        end if;
                                                                    end if;
                                                                end if;
                                                            end if;
                                                        end if;
                                                    end if;
                                                end if;
                                            end if;
                                        end if;
                                    end if;
                                end if;
                            end if;
                        else -- Potentiall both or 1 is saturated (11,10,01)
                            if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- No fractional part 
                                w11_case <= '0'; 
                            end if;
                        end if;

                        if w11_case = '1' then
                            w11 <= rc_mul - (rc_add -"1111111111111111");
                        else 
                            w11 <= "1111111111111111"- (rc_add-rc_mul);
                        end if;
                        w12 <= col_fraction - rc_mul;
                        w21 <= row_fraction - rc_mul;
                        w22 <= rc_mul;

                        r_val <= x11*w11+x12*w12+x21*w21+x22*w22; -- Calculate the output value
                        o_val <= r_val(31 downto 16);
                    else
                        ------------------ t = 0 ------------------
                        if i_ridx(11 downto 8) >= "1111" and i_cidx(11 downto 8) >= "1010" then                                -- Saturation in both row and column                                
                            -- both are saturated x11 
                            x11_raddr <= to_unsigned(176, 8); 
                            x12_raddr <= to_unsigned(176, 8); 
                            x21_raddr <= to_unsigned(176, 8); 
                            x22_raddr <= to_unsigned(176, 8);
                            row_fraction(15 downto 8) <= (others => '0'); 
                            col_fraction(15 downto 8) <= (others => '0');

                            rc_add <= (others => '0'); -- Row and column addition result
                        else 
                            if initialization_counter < 3 then


                                initialization_counter := initialization_counter + 1; -- Increment the initialization counter
                            else
                                initialization_counter := 0; -- Set the counter to 2 to avoid further increments
                            end if;
                            if initialization_counter >= 0 then -- 
                                if i_ridx(11 downto 8) >= "1111" or i_cidx(11 downto 8) >= "1010" then                              -- Saturation in row or column
                                    if i_ridx(11 downto 8) >= "1111" then                                                           -- Saturation in row (x21 and x22 is not accessible)
                                        x11_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                        x12_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)+1), 8); 
                                        x21_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8)), 8);
                                        x22_raddr <= to_unsigned(15*11 + to_integer(i_cidx(11 downto 8))+1, 8);
                                        row_fraction(15 downto 8) <= (others => '0');
                                        col_fraction(15 downto 8) <= i_cidx(7 downto 0); 
                                        rc_add(15 downto 8) <= i_cidx(7 downto 0); -- Row and column addition result
                                        
                                        rc_mul <= (others => '0'); -- Row and column multiplication result
                                    else                                                                                            -- Saturation in column (x12 and x22 is not accessible)
                                        x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                        x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + 10, 8); 
                                        x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                        x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + 10, 8); 
                                        row_fraction(15 downto 8) <= i_ridx(7 downto 0); -- Row fractional part
                                        col_fraction(15 downto 8) <= (others => '0');
                                        rc_add(15 downto 8) <= i_ridx(7 downto 0); -- Row and column addition result
                                        rc_mul <= (others => '0'); -- Row and column multiplication result
                                    end if;                        
                                else                                                                                                -- No saturation, normal operation
                                    x11_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                    x12_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8))*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                                    x21_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8)), 8); 
                                    x22_raddr <= to_unsigned(to_integer(i_ridx(11 downto 8) + 1)*11 + to_integer(i_cidx(11 downto 8) + 1), 8); 
                                    
                                    row_fraction(15 downto 8) <= i_ridx(7 downto 0);
                                    col_fraction(15 downto 8) <= i_cidx(7 downto 0);

                                    rc_add(15 downto 8) <= i_ridx(7 downto 0) + i_cidx(7 downto 0); -- Row and column addition result
                                    rc_mul <= i_ridx(7 downto 0) * i_cidx(7 downto 0); -- Row and column multiplication result
                                end if;

                                if i_ridx(11 downto 8) < "1111" and i_cidx(11 downto 8) < "1010" then  -- Neither is saturated 00
                                    if i_ridx(7 downto 0) = "00000000" and i_cidx(7 downto 0) = "00000000" then -- No fractional part -------------- 0000
                                        w11_case <= '0'; -- Reset the w11_case signal
                                    else 
                                        if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- Only one fractional part
                                            if i_ridx(7 downto 0) = "00000000" then ------------------------------------------------------------- 0001
                                                w11_case <= '0'; -- Reset the w11_case signal
                                            else                                                ------------------------------------------------- 0010
                                                w11_case <= '0'; -- Reset the w11_case signal
                                            end if;
                                        else -- Both row and column have fractional parts, we need to read x12 and x22  ------------------------- 0011
                                            if i_ridx(7) ='1' and i_cidx(7) ='1' then -- Addition will be larger than 1
                                                w11_case <= '1'; 
                                            else    
                                                if i_ridx(7) = '1' nor i_cidx(7) = '1' then 
                                                    w11_case <= '0'; 
                                                else                                                        -- One of them is '1', so we need to check (6)
                                                    if i_ridx(6) ='1' and i_cidx(6) ='1' then               -- Addition will be larger than 1   
                                                        w11_case <= '1';
                                                    else
                                                        if i_ridx(6) ='1' nor i_cidx(6) = '1' then          -- Neither is 1 and we can break her
                                                            w11_case <= '0'; 
                                                        else
                                                            if i_ridx(5) ='1' and i_cidx(5) ='1' then       -- Addition will be larger than 1
                                                                w11_case <= '1';          
                                                            else
                                                                if i_ridx(5) ='1' nor i_cidx(5) = '1' then  -- Neither is 1 and we can break her
                                                                    w11_case <= '0'; 
                                                                else
                                                                    if i_ridx(4) ='1' and i_cidx(4) ='1' then -- Addition will be larger than 1
                                                                        w11_case <= '1'; 
                                                                    else
                                                                        if i_ridx(4) ='1' nor i_cidx(4) = '1' then -- Neither is 1 and we can break her
                                                                            w11_case <= '0'; 
                                                                        else
                                                                            if i_ridx(3) ='1' and i_cidx(3) ='1' then -- Addition will be larger than 1
                                                                                w11_case <= '1'; 
                                                                            else
                                                                                if i_ridx(3) ='1' nor i_cidx(3) = '1' then                      -- Neither is 1 and we can break her
                                                                                    w11_case <= '0'; 
                                                                                else                                                            -- One of them    
                                                                                    if i_ridx(2) ='1' and i_cidx(2) ='1' then                   -- Addition will be larger than 1
                                                                                        w11_case <= '1'; 
                                                                                    else                                                        -- One of them can still be '1', so we need to check (2)
                                                                                        if i_ridx(2) ='1' nor i_cidx(2) = '1' then              -- Neither (2) is 1 and we can break her
                                                                                            w11_case <= '0'; 
                                                                                        else                                                    -- One of them is '1', so we need to check (1)
                                                                                            if i_ridx(1) ='1' and i_cidx(1) ='1' then           -- Addition will be larger than 1
                                                                                                w11_case <= '1'; 
                                                                                            else 
                                                                                                if i_ridx(1) ='1' nor i_cidx(1) = '1' then      -- Neither (1) is 1 and we can break her
                                                                                                    w11_case <= '0'; 
                                                                                                else 
                                                                                                    if i_ridx(0) ='1' and i_cidx(0) ='1' then   -- Addition will be larger than 1
                                                                                                        w11_case <= '1'; 
                                                                                                    else 
                                                                                                        w11_case <= '0'; 
                                                                                                    end if;
                                                                                                end if;
                                                                                            end if;
                                                                                        end if;
                                                                                    end if;
                                                                                end if;
                                                                            end if;
                                                                        end if;
                                                                    end if;
                                                                end if;
                                                            end if;
                                                        end if;
                                                    end if;
                                                end if;
                                            end if;
                                        end if;
                                    end if;
                                else -- Potentiall both or 1 is saturated (11,10,01)
                                    if i_ridx(7 downto 0) = "00000000" or i_cidx(7 downto 0) = "00000000" then -- No fractional part 
                                        w11_case <= '0'; 
                                    end if;
                                end if;
                            end if;
                            if initialization_counter >=1 then -- Calculate the weights
                                if w11_case = '1' then
                                    w11 <= rc_mul - (rc_add -"1111111111111111");
                                else 
                                    w11 <= "1111111111111111"- (rc_add-rc_mul);
                                end if;
                                w12 <= col_fraction - rc_mul;
                                w21 <= row_fraction - rc_mul;
                                w22 <= rc_mul;
                            end if;

                            if initialization_counter > 2 then
                                r_val <= x11*w11+x12*w12+x21*w21+x22*w22; -- Calculate the output value
                                init_done <= '1'; -- Set the initialization done signal
                            end if;
                        end if;
                        
                    end if;
            end case;

        end if;
    end process;


end architecture rtl;

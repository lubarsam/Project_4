LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY lcd_controller IS
  PORT(
    clk            : IN  STD_LOGIC;
    sys_reset_n    : IN  STD_LOGIC;
    i2c_data_rd    : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    i2c_ack_error  : IN  STD_LOGIC;
    i2c_busy       : IN  STD_LOGIC := '1';
    i2c_clk        : OUT STD_LOGIC;
    i2c_reset_n    : OUT STD_LOGIC;
    i2c_enable     : OUT STD_LOGIC;
    i2c_addr       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    i2c_rw         : OUT STD_LOGIC;
    i2c_data_wr    : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    init_done      : OUT STD_LOGIC
    );
END lcd_controller;

ARCHITECTURE controller OF lcd_controller IS
  TYPE CONTROL IS(beg, start, write_data, wait_delay, done);
  SIGNAL state        : CONTROL;
  SIGNAL count        : INTEGER range 0 to 4095 := 0;
  SIGNAL delay_count  : INTEGER range 0 to 2000000 := 0;
  SIGNAL data_wr      : std_logic_vector(7 downto 0);
  SIGNAL byte_select  : INTEGER range 0 to 24 := 0;
  SIGNAL busy_prev    : std_logic;
  SIGNAL enable_int   : std_logic := '0';
BEGIN

--data select mux controlled by below process statement
process(byte_select)
begin
    case byte_select is
    
        --send 0x30 three times to reset lcd
        when 0   => data_wr <= X"38";
        when 1   => data_wr <= X"3C";
        when 2   => data_wr <= X"38";
        
        when 3   => data_wr <= X"08"; --3
        when 4   => data_wr <= X"0C"; --0
        when 5   => data_wr <= X"08";
                                      --3
        when 6   => data_wr <= X"38"; --0
        when 7   => data_wr <= X"38";
        when 8   => data_wr <= X"3C"; --3
                                      --0
        when 9   => data_wr <= X"08";
        when 10  => data_wr <= X"0C";
        when 12  => data_wr <= X"08";
        
        when 13  => data_wr <= X"38";
        when 14  => data_wr <= X"3C";
        when 15  => data_wr <= X"38";
        
        when 16  => data_wr <= X"08";
        when 17  => data_wr <= X"0C";
        when 18  => data_wr <= X"08";
        
        -- send 0x20 once to select 4-bit mode
        when 19  => data_wr <= X"28";
        when 20  => data_wr <= X"2C";
        when 21  => data_wr <= X"28";
        
        when 22  => data_wr <= X"08";
        when 23  => data_wr <= X"0C";
        when 24  => data_wr <= X"08";
        
        when others => data_wr <= X"38";
    end case;
end process;

--concurrent assignments
i2c_clk     <= clk;
i2c_data_wr <= data_wr;
i2c_reset_n <= sys_reset_n;
i2c_enable  <= enable_int;
init_done   <= '1' WHEN state = done ELSE '0';

--i2c user handshake process, handles init by setting i2c flags and incrementing along the mux
PROCESS(clk, sys_reset_n)
BEGIN
    IF sys_reset_n = '0' THEN
        state       <= beg;
        count       <= 0;
        delay_count <= 0;
        byte_select <= 0;
        enable_int  <= '0';
        i2c_addr    <= (others => '0');
        i2c_rw      <= '0';
        busy_prev   <= '1';

    ELSIF rising_edge(clk) THEN
        busy_prev <= i2c_busy;

        case state is

            when beg =>
                count <= 4095;
                byte_select <= 0;
                enable_int  <= '0';
                state       <= start;

            when start =>
                enable_int <= '0';
                if count /= 0 then
                    count <= count - 1;
                else
                    state <= write_data;
                end if;

            when write_data =>
                i2c_addr <= "0100111";
                i2c_rw   <= '0';

                IF busy_prev = '1' AND i2c_busy = '0' THEN
                    enable_int <= '0';

                    CASE byte_select IS
                        WHEN 0      => delay_count <= 2000000;
                        WHEN 1      => delay_count <= 5000;
                        WHEN OTHERS => delay_count <= 0;
                    END CASE;

                    IF byte_select < 19 THEN
                        byte_select <= byte_select + 1;
                        state       <= wait_delay;
                    ELSE
                        state <= done;
                    END IF;

                ELSIF enable_int = '0' THEN
                    enable_int <= '1';
                END IF;

            --delay to ensure init sequence is in spec 
            when wait_delay =>
                enable_int <= '0';
                IF delay_count /= 0 THEN
                    delay_count <= delay_count - 1;
                ELSE
                    state <= write_data;
                END IF;

            when done =>
                enable_int <= '0';

        END CASE;
    END IF;
END PROCESS;
END controller;
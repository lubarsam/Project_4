LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY lcd_display IS
  PORT(
    clk         : IN  STD_LOGIC;
    sys_reset_n : IN  STD_LOGIC;
    init_done   : IN  STD_LOGIC;
    rx_dv       : IN  STD_LOGIC;                     -- pulse from UART_RX
    rx_byte     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);  -- ASCII from UART_RX
    i2c_busy    : IN  STD_LOGIC;
    i2c_enable  : OUT STD_LOGIC;
    i2c_addr    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
    i2c_rw      : OUT STD_LOGIC;
    i2c_data_wr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END lcd_display;

ARCHITECTURE display OF lcd_display IS

  TYPE CONTROL IS (idle, wait_char, send_char, full);
  SIGNAL state       : CONTROL;

  -- 4 PCF8574 bytes per character, byte_select cycles 0-3
  SIGNAL byte_select : INTEGER range 0 to 3 := 0;
  SIGNAL char_count  : INTEGER range 0 to 16 := 0;
  SIGNAL busy_prev   : STD_LOGIC;
  SIGNAL enable_int  : STD_LOGIC := '0';

  -- Latch received byte so it's stable during 4-byte send
  SIGNAL ascii_latch : STD_LOGIC_VECTOR(7 DOWNTO 0);

  -- PCF8574 byte construction
  -- Upper nibble = bits 7-4 of ASCII, lower nibble = bits 3-0
  -- RS=1 (bit 0), BL=1 (bit 3), EN=bit 2
  SIGNAL data_wr     : STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN

  -- Build PCF8574 byte from latched ASCII and byte_select
  -- byte 0: upper nibble, EN=0, BL=1, RS=1 => upper & "1001"
  -- byte 1: upper nibble, EN=1, BL=1, RS=1 => upper & "1101"
  -- byte 2: lower nibble, EN=0, BL=1, RS=1 => lower & "1001"
  -- byte 3: lower nibble, EN=1, BL=1, RS=1 => lower & "1101"
  process(byte_select, ascii_latch)
  begin
    case byte_select is
      when 0 => data_wr <= ascii_latch(7 downto 4) & "1001";
      when 1 => data_wr <= ascii_latch(7 downto 4) & "1101";
      when 2 => data_wr <= ascii_latch(3 downto 0) & "1001";
      when 3 => data_wr <= ascii_latch(3 downto 0) & "1101";
      when others => data_wr <= X"09";
    end case;
  end process;

  i2c_enable  <= enable_int;
  i2c_addr    <= "0100111";
  i2c_rw      <= '0';
  i2c_data_wr <= data_wr;

  PROCESS(clk, sys_reset_n)
  BEGIN
    IF sys_reset_n = '0' THEN
      state       <= idle;
      byte_select <= 0;
      char_count  <= 0;
      enable_int  <= '0';
      busy_prev   <= '1';
      ascii_latch <= (others => '0');

    ELSIF rising_edge(clk) THEN
      busy_prev <= i2c_busy;

      case state is

        when idle =>
          enable_int <= '0';
          IF init_done = '1' THEN
            state <= wait_char;
          END IF;

        when wait_char =>
          enable_int <= '0';
          IF rx_dv = '1' AND char_count < 16 THEN
            ascii_latch <= rx_byte;  -- latch ASCII before starting send
            byte_select <= 0;
            state       <= send_char;
          END IF;

        when send_char =>
          IF busy_prev = '1' AND i2c_busy = '0' THEN
            enable_int <= '0';
            IF byte_select < 3 THEN
              byte_select <= byte_select + 1;
            ELSE
              -- All 4 bytes sent, character complete
              char_count  <= char_count + 1;
              byte_select <= 0;
              IF char_count < 15 THEN
                state <= wait_char;   -- room for more characters
              ELSE
                state <= full;        -- line 1 now full
              END IF;
            END IF;
          ELSIF enable_int = '0' THEN
            enable_int <= '1';
          END IF;

        when full =>
          -- Line full - stop sending, hold here until reset
          enable_int <= '0';

      end case;
    END IF;
  END PROCESS;
END display;
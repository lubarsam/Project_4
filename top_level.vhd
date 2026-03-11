LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY top IS
  PORT(
    clk         : IN    STD_LOGIC;
    sys_reset_n : IN    STD_LOGIC;
    ps2_clk     : IN    STD_LOGIC;
    ps2_data    : IN    STD_LOGIC;
    --uart_rx_pin : IN    STD_LOGIC;
    uart_tx_pin : OUT   STD_LOGIC;    -- goes to USB/PC
    sda         : INOUT STD_LOGIC;
    scl         : INOUT STD_LOGIC
  );
END top;

ARCHITECTURE top OF top IS

component uart IS
  GENERIC(
    clk_freq  :  INTEGER    := 125_000_000;  --frequency of system clock in Hertz
    baud_rate :  INTEGER    := 115_200;     --data link baud rate in bits/second
    os_rate   :  INTEGER    := 16;          --oversampling rate to find center of receive bits (in samples per baud period)
    d_width   :  INTEGER    := 8;           --data bus width
    parity    :  INTEGER    := 0;           --0 for no parity, 1 for parity
    parity_eo :  STD_LOGIC  := '0'          --'0' for even, '1' for odd parity
    );        
  PORT(
    clk      :  IN   STD_LOGIC;                             --system clock
    reset_n  :  IN   STD_LOGIC;                             --ascynchronous reset
    tx_ena   :  IN   STD_LOGIC;                             --initiate transmission
    tx_data  :  IN   STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
    rx       :  IN   STD_LOGIC;                             --receive pin
    rx_busy  :  OUT  STD_LOGIC;                             --data reception in progress
    rx_error :  OUT  STD_LOGIC;                             --start, parity, or stop bit error detected
    rx_data  :  OUT  STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data received
    tx_busy  :  OUT  STD_LOGIC;                             --transmission in progress
    tx       :  OUT  STD_LOGIC
    );                            --transmit pin
END component;

component ps2_keyboard_to_ascii IS
  GENERIC(
      clk_freq                  : INTEGER := 125_000_000; --system clock frequency in Hz
      ps2_debounce_counter_size : INTEGER := 9           --set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
      );
  PORT(
      clk        : IN  STD_LOGIC;                     --system clock input
      ps2_clk    : IN  STD_LOGIC;                     --clock signal from PS2 keyboard
      ps2_data   : IN  STD_LOGIC;                     --data signal from PS2 keyboard
      ascii_new  : OUT STD_LOGIC;                     --output flag indicating new ASCII value
      ascii_code : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)); --ASCII value
END component;

  COMPONENT lcd_controller IS
    PORT(
      clk          : IN  STD_LOGIC;
      sys_reset_n  : IN  STD_LOGIC;
      i2c_data_rd  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      i2c_ack_error: IN  STD_LOGIC;
      i2c_busy     : IN  STD_LOGIC;
      i2c_clk      : OUT STD_LOGIC;
      i2c_reset_n  : OUT STD_LOGIC;
      i2c_enable   : OUT STD_LOGIC;
      i2c_addr     : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      i2c_rw       : OUT STD_LOGIC;
      i2c_data_wr  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      init_done    : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT lcd_display IS
    PORT(
      clk         : IN  STD_LOGIC;
      sys_reset_n : IN  STD_LOGIC;
      init_done   : IN  STD_LOGIC;
      rx_dv       : IN  STD_LOGIC;
      rx_byte     : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
      i2c_busy    : IN  STD_LOGIC;
      i2c_enable  : OUT STD_LOGIC;
      i2c_addr    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
      i2c_rw      : OUT STD_LOGIC;
      i2c_data_wr : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT i2c_manager IS
    GENERIC(
      input_clk : INTEGER := 125_000_000;
      bus_clk   : INTEGER := 100_000
    );
    PORT(
      clk       : IN     STD_LOGIC;
      reset_n   : IN     STD_LOGIC;
      ena       : IN     STD_LOGIC;
      addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0);
      rw        : IN     STD_LOGIC;
      data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0);
      busy      : OUT    STD_LOGIC;
      data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0);
      ack_error : BUFFER STD_LOGIC;
      sda       : INOUT  STD_LOGIC;
      scl       : INOUT  STD_LOGIC
    );
  END COMPONENT;

  -- I2C controller signals
  SIGNAL ctrl_enable  : STD_LOGIC;
  SIGNAL ctrl_addr    : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL ctrl_rw      : STD_LOGIC;
  SIGNAL ctrl_data    : STD_LOGIC_VECTOR(7 DOWNTO 0);

  SIGNAL disp_enable  : STD_LOGIC;
  SIGNAL disp_addr    : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL disp_rw      : STD_LOGIC;
  SIGNAL disp_data    : STD_LOGIC_VECTOR(7 DOWNTO 0);

  SIGNAL i2c_enable   : STD_LOGIC;
  SIGNAL i2c_addr     : STD_LOGIC_VECTOR(6 DOWNTO 0);
  SIGNAL i2c_rw       : STD_LOGIC;
  SIGNAL i2c_data_wr  : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL i2c_busy     : STD_LOGIC;
  SIGNAL i2c_data_rd  : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL i2c_ack_error: STD_LOGIC;
  SIGNAL i2c_reset_n  : STD_LOGIC;
  SIGNAL i2c_clk      : STD_LOGIC;
  SIGNAL init_done    : STD_LOGIC;
  SIGNAL ascii_new_signal   : STD_LOGIC;
  SIGNAL ascii_code_signal  : STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL reset_n_i : STD_LOGIC;
  SIGNAL Q0, Q1, send_pulse  : STD_LOGIC;

BEGIN

  reset_n_i <= NOT sys_reset_n;
  -- I2C mux
  i2c_enable  <= ctrl_enable WHEN init_done = '0' ELSE disp_enable;
  i2c_addr    <= ctrl_addr   WHEN init_done = '0' ELSE disp_addr;
  i2c_rw      <= ctrl_rw     WHEN init_done = '0' ELSE disp_rw;
  i2c_data_wr <= ctrl_data   WHEN init_done = '0' ELSE disp_data;
  
uart_inst   : uart
  GENERIC MAP(
    clk_freq  => 125_000_000,   --frequency of system clock in Hertz
    baud_rate => 115_200,      --data link baud rate in bits/second
    os_rate   => 16,           --oversampling rate to find center of receive bits (in samples per baud period)
    d_width   => 8,            --data bus width
    parity    => 0,            --0 for no parity, 1 for parity
    parity_eo => '0'           --'0' for even, '1' for odd parity
    )
  PORT MAP(
    clk      => clk,                --system clock
    reset_n  => reset_n_i,          --ascynchronous reset
    tx_ena   => send_pulse,   --initiate transmission
    tx_data  => ascii_code_signal,  --data to transmit
    rx       => '0',                --receive pin
    rx_busy  => open,               --data reception in progress
    rx_error => open,               --start, parity, or stop bit error detected
    rx_data  => open,               --data received
    tx_busy  => open,               --transmission in progress
    tx       => uart_tx_pin
    );     

process(clk)
begin
  if rising_edge(clk) then
  Q0 <= ascii_new_signal;
  Q1 <= Q0;
  send_pulse <= Q0 and not Q1;
  end if;
end process;

keyboard_inst : ps2_keyboard_to_ascii
  GENERIC MAP(
      clk_freq                  => 125_000_000,      --system clock frequency in Hz
      ps2_debounce_counter_size => 9              --set such that 2^size/clk_freq = 5us (size = 8 for 50MHz)
      )               
  PORT MAP(
      clk        => clk,                            --system clock input
      ps2_clk    => ps2_clk,                        --clock signal from PS2 keyboard
      ps2_data   => ps2_data,                       --data signal from PS2 keyboard
      ascii_new  => ascii_new_signal,               --output flag indicating new ASCII value
      ascii_code => ascii_code_signal
      );

  -- lcd_display gets ascii_code and ps2_code_new directly
  U_DISP: lcd_display
    PORT MAP(
      clk         => clk,
      sys_reset_n => reset_n_i,
      init_done   => init_done,
      rx_dv       => send_pulse,   -- direct from PS2, no UART
      rx_byte     => ascii_code_signal,  -- direct from LUT, no UART
      i2c_busy    => i2c_busy,
      i2c_enable  => disp_enable,
      i2c_addr    => disp_addr,
      i2c_rw      => disp_rw,
      i2c_data_wr => disp_data
    );

  U_CTRL: lcd_controller
    PORT MAP(
      clk           => clk,
      sys_reset_n   => reset_n_i,
      i2c_data_rd   => i2c_data_rd,
      i2c_ack_error => i2c_ack_error,
      i2c_busy      => i2c_busy,
      i2c_clk       => i2c_clk,
      i2c_reset_n   => i2c_reset_n,
      i2c_enable    => ctrl_enable,
      i2c_addr      => ctrl_addr,
      i2c_rw        => ctrl_rw,
      i2c_data_wr   => ctrl_data,
      init_done     => init_done
    );

  U_I2C: i2c_manager
    GENERIC MAP(
      input_clk => 125_000_000,
      bus_clk   => 100_000
    )
    PORT MAP(
      clk       => clk,
      reset_n   => i2c_reset_n,
      ena       => i2c_enable,
      addr      => i2c_addr,
      rw        => i2c_rw,
      data_wr   => i2c_data_wr,
      busy      => i2c_busy,
      data_rd   => i2c_data_rd,
      ack_error => i2c_ack_error,
      sda       => sda,
      scl       => scl
    );

END top;
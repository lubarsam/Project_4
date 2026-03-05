----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/27/2026 02:41:59 PM
-- Design Name: 
-- Module Name: Top_Level - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Top_Level is
  Port (
  iClk		: in std_logic;
  reset		: in std_logic;
  ascii		: out std_logic_vector (7 downto 0);
  usb_tx    : in std_logic;
  usb_rx    : out std_logic;
  ps2_clk   : in std_logic;
  ps2_data  : in std_logic
  
  );
end Top_Level;

architecture Behavioral of Top_Level is

component clock is
generic(
    MAX: unsigned (7 downto 0) := "01000000"
);

port(
    clock50M: in std_logic;    --internal clock input
    reset:     in std_logic;
    sw_interlock:    in std_logic;
    sw:    in    std_logic_vector (6 downto 0);
    
    clk:    out std_logic;
    clkn:    out std_logic

);
end component;

component ps2_keyboard_to_ascii IS
  GENERIC(
    clk_freq              : INTEGER := 125_000_000; --system clock frequency in Hz
    ps2_debounce_counter_size : INTEGER := 10);         --set such that (2^size)/clk_freq = 5us (size = 8 for 50MHz) (size = 10 for 125MHz)
  PORT(
    clk          : IN  STD_LOGIC;                     --system clock
    ps2_clk      : IN  STD_LOGIC;                     --clock signal from PS/2 keyboard
    ps2_data     : IN  STD_LOGIC;                     --data signal from PS/2 keyboard
    ascii_new : OUT STD_LOGIC;                     --flag that new PS/2 code is available on ps2_code bus
    ascii_code     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)); --code received from PS/2
END component;

component uart is
    port (
        reset       :in  std_logic;
        txclk       :in  std_logic;
        ld_tx_data  :in  std_logic;
        tx_data     :in  std_logic_vector (7 downto 0);
        tx_enable   :in  std_logic;
        tx_out      :out std_logic;
        tx_empty    :out std_logic;
        rxclk       :in  std_logic;
        uld_rx_data :in  std_logic;
        rx_data     :out std_logic_vector (7 downto 0);
        rx_enable   :in  std_logic;
        rx_in       :in  std_logic;
        rx_empty    :out std_logic
    );
end component;

component btn_debounce_toggle is 
    GENERIC (
	CONSTANT CNTR_MAX : std_logic_vector(15 downto 0) := X"FFFF");  
    Port ( BTN_I 	: in  STD_LOGIC;
           CLK 		: in  STD_LOGIC;
           BTN_O 	: out  STD_LOGIC;
           TOGGLE_O : out  STD_LOGIC;
		   PULSE_O  : out STD_LOGIC);
end component;

signal ascii_data_ps2 : std_logic_vector (7 downto 0);
signal ascii_new      : std_logic;
signal txclk		  : std_logic;
signal txcnt_en	      : std_logic;
signal tx_clken		  : std_logic;
signal rx_clken		  : std_logic;
signal rxclk		  : std_logic;
signal rx_full        : std_logic;

signal rx_empty       : std_logic;
signal uart_rx_data   : std_logic_vector (7 downto 0);

signal shift_trig     : std_logic;
signal old_shift_trig : std_logic;
signal shiftcount     : integer range 0 to 17;

begin

	inst_txclk_gen : clock
	port map (
	clock50M		=> iClk,
	reset			=> reset,
	sw_interlock	=> '0',
	sw				=> "1101101",
	clk				=> txclk,
	clkn			=> open
	);

inst_rxclk_gen : clock
	port map (
	clock50M		=> iClk,
	reset			=> reset,
	sw_interlock	=> '0',
	sw				=> "0000111",
	clk				=> rxclk,
	clkn			=> open
	);

inst_keyboard : ps2_keyboard_to_ascii
    GENERIC map(
        clk_freq                => 125000000,
        ps2_debounce_counter_size => 10
        )
	port map (
	clk				=> iClk,
	ps2_clk			=> ps2_clk,--TODO,
	ps2_data		=> ps2_data, --TODO,
	ascii_new      	=> ascii_new, --TODO,;
	ascii_code		=> ascii_data_ps2
	);

inst_uart : uart
	port map (
	reset		=> reset,
	txclk		=> txclk,
    ld_tx_data  => '1',
    tx_data     => ascii_data_ps2,
    tx_enable   => ascii_new,
    tx_out      => usb_rx,
    tx_empty    => open,
    rxclk       => rx_clken,
    uld_rx_data => '1',
    rx_data     => uart_rx_data,
    rx_enable   => '1',
    rx_in       => usb_tx,
    rx_empty    => rx_empty
);

inst_debounce : btn_debounce_toggle
    GENERIC map (
        CNTR_MAX => x"0001")
        port map(
                BTN_I       => rx_full,
                CLK         => iclk,
                BTN_O       => open,
                TOGGLE_O    => open, 
                PULSE_O     => shift_trig
                );
rx_full <= not rx_empty;
    process(iclk)
    begin
        if reset = '1' then
            old_shift_trig <= '0';
            shiftcount <= 0;
            LCD_data <= (others => '0');
        elsif rising_edge(clk) then
            old_shift_trig <= shift_trig;
            if shift_trig = '0' and old_shift_trig = '1' then
                    shiftcount <= shiftcount + 1;
            end if;
            if shiftcount > 15 then
                LCD_data <= sr_out;
                shiftcount <= 0;
            end if;
        end if;            
end process;
end Behavioral;

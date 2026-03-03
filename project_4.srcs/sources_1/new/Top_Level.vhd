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
  ascii		: out std_logic_vector (7 downto 0)
  
  );
end Top_Level;

architecture Behavioral of Top_Level is

component clock is
generic(
    MAX: unsigned (20 downto 0) := "111000010000000000000"
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

component ps2_keyboard IS
  GENERIC(
    clk_freq              : INTEGER := 50_000_000; --system clock frequency in Hz
    debounce_counter_size : INTEGER := 8);         --set such that (2^size)/clk_freq = 5us (size = 8 for 50MHz)
  PORT(
    clk          : IN  STD_LOGIC;                     --system clock
    ps2_clk      : IN  STD_LOGIC;                     --clock signal from PS/2 keyboard
    ps2_data     : IN  STD_LOGIC;                     --data signal from PS/2 keyboard
    ps2_code_new : OUT STD_LOGIC;                     --flag that new PS/2 code is available on ps2_code bus
    ps2_code     : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)); --code received from PS/2
END component;

component scancode_LUT is
  Port (
  make_code		: in std_logic_vector (7 downto 0);
  ascii			: out std_logic_vector (7 downto 0)
  );
end component;

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

signal make_code : std_logic_vector (7 downto 0);
signal ps2_data  : std_logic;
signal ps2_clk	 : std_logic;
signal ps2_code_new : std_logic;
signal txclk		: std_logic;
signal txcnt_en		: std_logic;
signal txclk_en		: std_logic;
signal rxclk		: std_logic;


begin

inst_txclk_gen : clock
	generic map (
		MAX	=> "000011100001000000000"
		)
	port map (
	clock50M		=> iClk,
	reset			=> reset,
	sw_interlock	=> '0',
	sw				=> sw,
	clk				=> txclk,
	clkn			=> open
	);

inst_scancode_LUT : scancode_LUT
	port map(
	make_code	=> make_code,
	ascii		=> ascii
	);

inst_ps2_keyboard : ps2_keyboard
	port map (
	clk				=> iClk,
	ps2_clk			=> ps2_clk,--TODO,
	ps2_data		=> ps2_data, --TODO,
	ps2_code_new	=> ps2_code_new, --TODO,;
	ps2_code		=> make_code
	);

inst_uart : uart
	port map (
	reset			=> reset,
	txclk			=> txclk,
	ld_tx_data		=>,
	tx_data			=>,
	tx_enable		=>,
	tx_out			=>,
	tx_empty		=>,
	rxclk			=>,
	uld_rx_data		=>,
	rx_data			=>,
	rx_enable		=>,
	rx_in			=>,
	rx_empty		=>
	);
end Behavioral;

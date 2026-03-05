----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/27/2026 02:14:55 PM
-- Design Name: 
-- Module Name: tb_scancode_LUT - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tb_scancode_LUT is
--  Port ( );
end tb_scancode_LUT;

architecture Behavioral of tb_scancode_LUT is
component scancode_LUT is
  Port (
  make_code		: in std_logic_vector (7 downto 0);
  ascii			: out std_logic_vector (7 downto 0)
  );
end component;
signal make_code	: std_logic_vector (7 downto 0);
signal ascii		: std_logic_vector (7 downto 0);
begin
DUT: scancode_LUT
	port map (
	make_code		=> make_code,
	ascii			=> ascii);

process
begin
	make_code  <= x"1c";
	wait for 3 us;
	make_code  <= x"3a";
	wait;
end process;


end Behavioral;

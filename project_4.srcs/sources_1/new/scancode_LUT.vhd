----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/27/2026 01:52:15 PM
-- Design Name: 
-- Module Name: scancode_LUT - Behavioral
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

entity scancode_LUT is
  Port (
  make_code		: in std_logic_vector (7 downto 0);
  ascii			: out std_logic_vector (7 downto 0)
  );
end scancode_LUT;

architecture Behavioral of scancode_LUT is

begin
shift_map : process( make_code ) 
begin 
  case make_code is 
  when x"66" => ascii <= x"08";  -- Backspace ("backspace" key) 
  when x"5a" => ascii <= x"0d";  -- Carriage return ("enter" key) 
  when x"76" => ascii <= x"1b";  -- Escape ("esc" key) 
  when x"1c" => ascii <= x"61";  -- a 
  when x"32" => ascii <= x"62";  -- b 
  when x"21" => ascii <= x"63";  -- c 
  when x"23" => ascii <= x"64";  -- d 
  when x"24" => ascii <= x"65";  -- e 
  when x"2b" => ascii <= x"66";  -- f 
  when x"34" => ascii <= x"67";  -- g 
  when x"33" => ascii <= x"68";  -- h 
  when x"43" => ascii <= x"69";  -- i 
  when x"3b" => ascii <= x"6a";  -- j 
  when x"42" => ascii <= x"6b";  -- k 
  when x"4b" => ascii <= x"6c";  -- l 
  when x"3a" => ascii <= x"6d";  -- m 
  when x"31" => ascii <= x"6e";  -- n 
  when x"44" => ascii <= x"6f";  -- o 
  when x"4d" => ascii <= x"70";  -- p 
  when x"15" => ascii <= x"71";  -- q 
  when x"2d" => ascii <= x"72";  -- r 
  when x"1b" => ascii <= x"73";  -- s 
  when x"2c" => ascii <= x"74";  -- t 
  when x"3c" => ascii <= x"75";  -- u 
  when x"2a" => ascii <= x"76";  -- v 
  when x"1d" => ascii <= x"77";  -- w 
  when x"22" => ascii <= x"78";  -- x 
  when x"35" => ascii <= x"79";  -- y 
  when x"1a" => ascii <= x"7a";  -- z 
  when others => ascii <= x"00";  -- 0xff used for unlisted characters. 
  end case; 
end process; 
end Behavioral;

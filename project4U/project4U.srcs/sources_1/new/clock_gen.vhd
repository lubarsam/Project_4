----------------------------------------------------------------------------------
-- Company: MisCircuitos.com
-- Engineer: Alberto Lopez
-- alberto@miscircuitos.com
-- WWW.MISCIRCUITOS.COM

-- Create Date:    10:09:49 06/18/2020 
-- Module Name:    clock - Behavioral 
-- Description: Frequency divider with interlock
--inputs
--  -->1 switch is for enable or disable the non-overlapping function
--  -->7 switch to program or select the frequency divider
-- OUTPUTS
--  --> 2 signals with clk and clkn
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

entity clock is
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
end clock;

architecture Behavioral of clock is
--signals
    signal counter: unsigned (7 downto 0);
    signal counter_d: unsigned (7 downto 0);    
    
    signal clk_sig: std_logic;
    signal clkn_sig: std_logic;
    signal clk_sig_d: std_logic;
    signal clkn_sig_d: std_logic;
    signal clk_sig_inter: std_logic;
    signal clkn_sig_inter: std_logic;    

    signal interlock: std_logic;
    signal interlock_d: std_logic;
    signal input_freq: unsigned (7 downto 0);
begin

input_freq <= unsigned(sw)& '0';


p_combinatorial : process (counter, clk_sig, clkn_sig, interlock, input_freq) begin    
if(counter = input_freq) then
        counter_d <= (others => '0');
        interlock_d <= '1';
        if(clk_sig ='0') then 
            clk_sig_d <= '1';
            clkn_sig_d <= '0';
        else
            clk_sig_d <= '0';
            clkn_sig_d <= '1';    
        end if;

    elsif (interlock = '0') then
        counter_d <= counter + 1;
        clk_sig_d <= clk_sig;
        clkn_sig_d <= clkn_sig;
        interlock_d <= '0';
    else
        counter_d <= counter;
        clk_sig_d <= clk_sig;
        clkn_sig_d <= clkn_sig;
        interlock_d <= '0';
    end if;        
end process;


p_clock: process( clock50M, reset ) begin
    if(reset = '1') then    --RESET
        counter <= (others => '0');
        clk_sig    <= '0';
        clkn_sig <= '1';
        interlock <= '0';    
    elsif(clock50M'event and clock50M= '1') then
        counter <= counter_d;
        clk_sig <= clk_sig_d;
        clkn_sig <= clkn_sig_d;
        interlock <= interlock_d;
    end if;
end process;

p_interlock: process(counter, clk_sig, clkn_sig, interlock, sw_interlock) begin
if(sw_interlock = '1') then
    clk_sig_inter <= clk_sig and not(interlock);
    clkn_sig_inter <= clkn_sig and not(interlock);
else
    clk_sig_inter <= clk_sig;
    clkn_sig_inter <= clkn_sig;
end if;
end process;

clk <= clk_sig_inter;
clkn <= clkn_sig_inter;

end Behavioral;
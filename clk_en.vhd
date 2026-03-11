LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Clock Enable Generator Component
entity clk_en is
    Generic (
        CLK_FREQ : integer := 50_000_000;  -- Input clock frequency in Hz
        EN_FREQ  : integer := 5_000_000    -- Enable frequency in Hz (5 MHz)
    );
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        clk_en   : out STD_LOGIC
    );
end clk_en;

architecture Behavioral of clk_en is
    constant COUNT_MAX : integer := (CLK_FREQ / EN_FREQ) - 1;
    signal counter : integer range 0 to COUNT_MAX := 0;
begin
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= 0;
            clk_en <= '0';
        elsif rising_edge(clk) then
            if counter = COUNT_MAX then
                counter <= 0;
                clk_en <= '1';
            else
                counter <= counter + 1;
                clk_en <= '0';
            end if;
        end if;
    end process;
end Behavioral;
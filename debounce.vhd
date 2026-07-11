--------------------------------------------------------------------------------
-- debounce.vhd
--
-- Debounce simples por contagem: a saída só muda quando a entrada permanece
-- estável por DEBOUNCE_CYCLES ciclos consecutivos. Usado no botão de reset
-- (BTNC) da Basys3.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
  generic (
    DEBOUNCE_CYCLES : natural := 1_000_000  -- ~10 ms @ 100 MHz
  );
  port (
    clk     : in  std_logic;
    btn_in  : in  std_logic;
    btn_out : out std_logic
  );
end entity debounce;

architecture rtl of debounce is
  signal sync1, sync2 : std_logic := '0';
  signal stable       : std_logic := '0';
  signal counter      : unsigned(31 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      -- sincronizador de 2 estágios (evita metaestabilidade)
      sync1 <= btn_in;
      sync2 <= sync1;

      if sync2 = stable then
        counter <= (others => '0');
      else
        if counter = DEBOUNCE_CYCLES - 1 then
          stable  <= sync2;
          counter <= (others => '0');
        else
          counter <= counter + 1;
        end if;
      end if;
    end if;
  end process;

  btn_out <= stable;

end architecture rtl;

--------------------------------------------------------------------------------
-- timer_pulse.vhd
--
-- Temporizador genérico de contagem regressiva. Ao receber um pulso em
-- "start", conta TIMEOUT_CYCLES ciclos de clock e gera um pulso de 1 ciclo
-- em "done" ao terminar. Usado pela FSM do elevador para os intervalos de
-- 2 s (andar-a-andar) e 4 s (porta destravada), definidos no roteiro.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer_pulse is
  generic (
    TIMEOUT_CYCLES : natural := 200_000_000  -- nº de ciclos de clock até "done"
  );
  port (
    clk   : in  std_logic;
    rst   : in  std_logic;
    start : in  std_logic;  -- pulso de 1 ciclo para (re)iniciar a contagem
    done  : out std_logic   -- pulso de 1 ciclo quando a contagem termina
  );
end entity timer_pulse;

architecture rtl of timer_pulse is
  signal counter : unsigned(31 downto 0) := (others => '0');
  signal running : std_logic := '0';
begin

  process(clk)
  begin
    if rising_edge(clk) then
      done <= '0';

      if rst = '1' then
        running <= '0';
        counter <= (others => '0');

      elsif start = '1' then
        -- (re)carrega o contador e começa a contar, mesmo se já estava rodando
        running <= '1';
        counter <= to_unsigned(TIMEOUT_CYCLES - 1, counter'length);

      elsif running = '1' then
        if counter = 0 then
          done    <= '1';
          running <= '0';
        else
          counter <= counter - 1;
        end if;
      end if;
    end if;
  end process;

end architecture rtl;

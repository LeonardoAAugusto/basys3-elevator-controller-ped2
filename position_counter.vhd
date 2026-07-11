--------------------------------------------------------------------------------
-- position_counter.vhd
--
-- Bloco "Controle de Posição e Localização do Elevador" da Fig. 2.
-- Mantém o andar atual (0 a 3) do elevador. A cada pulso step_up/step_down
-- vindo da FSM (após os 2 s de deslocamento), incrementa/decrementa a
-- posição, com saturação nos limites do prédio (0 e 3).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity position_counter is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    step_up   : in  std_logic;  -- pulso de 1 ciclo: sobe 1 andar
    step_down : in  std_logic;  -- pulso de 1 ciclo: desce 1 andar
    floor     : out unsigned(1 downto 0)  -- andar atual (0..3)
  );
end entity position_counter;

architecture rtl of position_counter is
  signal floor_reg : unsigned(1 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        floor_reg <= (others => '0');  -- reset no térreo
      elsif step_up = '1' and floor_reg < 3 then
        floor_reg <= floor_reg + 1;
      elsif step_down = '1' and floor_reg > 0 then
        floor_reg <= floor_reg - 1;
      end if;
    end if;
  end process;

  floor <= floor_reg;

end architecture rtl;

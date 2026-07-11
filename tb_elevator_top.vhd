--------------------------------------------------------------------------------
-- tb_elevator_top.vhd
--
-- Testbench de simulação do elevator_top. Usa CLK_FREQ_HZ reduzido apenas
-- para SIMULAÇÃO (para não esperar 2 s/4 s reais no simulador). Para
-- síntese/implementação na placa, use os generics padrão de elevator_top
-- (100 MHz, 2 s, 4 s).
--
-- Sinais internos úteis para observar na forma de onda (via hierarquia):
--   tb_elevator_top/dut/floor_position
--   tb_elevator_top/dut/u_fsm/state
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_elevator_top is
end entity tb_elevator_top;

architecture sim of tb_elevator_top is

  constant CLK_PERIOD : time := 10 ns;  -- 100 MHz

  signal clk  : std_logic := '0';
  signal btnC : std_logic := '0';
  signal sw   : std_logic_vector(15 downto 0) := (others => '0');
  signal led  : std_logic_vector(15 downto 0);
  signal seg  : std_logic_vector(6 downto 0);
  signal dp   : std_logic;
  signal an   : std_logic_vector(3 downto 0);

begin

  dut : entity work.elevator_top
    generic map (
      CLK_FREQ_HZ     => 1000,  -- clock "acelerado" só para simulação
      MOVE_TIME_S     => 2,
      DOOR_TIME_S     => 4,
      DEBOUNCE_CYCLES => 10
    )
    port map (
      clk  => clk,
      btnC => btnC,
      sw   => sw,
      led  => led,
      seg  => seg,
      dp   => dp,
      an   => an
    );

  clk <= not clk after CLK_PERIOD / 2;

  stim : process
  begin
    -- reset inicial
    btnC <= '1';
    wait for 200 ns;
    btnC <= '0';
    wait for 200 ns;

    -- chamada de subida para o andar 2
    sw(3) <= '1';
    wait for 100 ns;
    sw(3) <= '0';

    -- tempo para subir (2 andares x 2s "virtuais") e abrir a porta
    wait for 60 us;

    -- simula obstáculo no sensor enquanto a porta está aberta
    sw(6) <= '1';
    wait for 60 us;
    sw(6) <= '0';

    -- aguarda a porta fechar
    wait for 20 us;

    -- chamada de descida do último andar (topo)
    sw(5) <= '1';
    wait for 100 ns;
    sw(5) <= '0';

    wait for 100 us;

    report "Fim do teste - verifique floor_position, door_open e an/seg na forma de onda";
    wait;
  end process;

end architecture sim;

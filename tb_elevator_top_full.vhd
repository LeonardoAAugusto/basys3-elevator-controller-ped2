--------------------------------------------------------------------------------
-- tb_elevator_top_full.vhd
--
-- Testbench de VALIDAÇÃO (auto-verificado) do elevator_top, cobrindo os
-- cenários mínimos exigidos pelo roteiro (algoritmo Coletivo subida/descida,
-- Turma 01). Cada teste termina com um "report" de OK ou uma falha via
-- "assert ... severity error" (aparece em vermelho no log do simulador e
-- interrompe a run se ELAB_MODE=strict; no XSim padrão apenas reporta erro
-- e o teste continua).
--
-- Usa CLK_FREQ_HZ = 1000 (em vez de 100 MHz) só para a simulação ser rápida.
-- Não altere isso para gerar o bitstream — use os generics padrão de
-- elevator_top nesse caso.
--
-- Sinais observados (todos via portas de topo, sem precisar de hierarquia):
--   led(3 downto 0)  -> andar atual (one-hot: 0001=0, 0010=1, 0100=2, 1000=3)
--   led(4)           -> porta aberta
--   led(5)/led(6)    -> motor subindo / descendo
--   led(10 downto 8) -> estado da FSM (000=STOP,001=UP,010=DOWN,
--                                      011=OPEN,100=SENSOR,101=CLOSE)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity tb_elevator_top_full is
end entity tb_elevator_top_full;

architecture sim of tb_elevator_top_full is

  constant CLK_PERIOD : time := 10 ns;   -- 100 MHz "real" no simulador

  -- com CLK_FREQ_HZ=1000 e CLK_PERIOD=10ns: 1 andar = 1000*2 ciclos = 20 us
  --                                          porta destravada = 1000*4 = 40 us
  constant T_MOVE  : time := 20 us;
  constant T_DOOR  : time := 40 us;
  constant MARGIN  : time := 3 us;       -- folga p/ latência de lógica/estado

  signal clk  : std_logic := '0';
  signal btnC : std_logic := '0';
  signal sw   : std_logic_vector(15 downto 0) := (others => '0');
  signal led  : std_logic_vector(15 downto 0);
  signal seg  : std_logic_vector(6 downto 0);
  signal dp   : std_logic;
  signal an   : std_logic_vector(3 downto 0);

  -- pulsa um switch (simula o toque no botão) o suficiente p/ a memória
  -- de retenção capturar a borda de subida
  procedure press(signal s : out std_logic_vector; idx : integer) is
  begin
    s(idx) <= '1';
    wait for 200 ns;
    s(idx) <= '0';
  end procedure;

begin

  dut : entity work.elevator_top
    generic map (
      CLK_FREQ_HZ     => 1000,
      MOVE_TIME_S     => 2,
      DOOR_TIME_S     => 4,
      DEBOUNCE_CYCLES => 10
    )
    port map (
      clk  => clk, btnC => btnC, sw => sw,
      led  => led, seg => seg, dp => dp, an => an
    );

  clk <= not clk after CLK_PERIOD / 2;

  stim : process
  begin

    ----------------------------------------------------------------------
    report "==== TESTE 1: RESET ====";
    ----------------------------------------------------------------------
    btnC <= '1'; wait for 200 ns; btnC <= '0'; wait for 200 ns;
    assert led(3 downto 0) = "0001"
      report "FALHA T1: andar inicial deveria ser 0" severity error;
    assert led(4) = '0'
      report "FALHA T1: porta deveria estar fechada" severity error;
    assert led(10 downto 8) = "000"
      report "FALHA T1: estado inicial deveria ser STOP" severity error;
    report "T1 OK -> reset: andar 0, porta fechada, estado STOP";

    ----------------------------------------------------------------------
    report "==== TESTE 2: chamada NO ANDAR ATUAL (sw0, terreo) ====";
    ----------------------------------------------------------------------
    press(sw, 0);
    wait for MARGIN;
    assert led(4) = '1'
      report "FALHA T2: porta deveria abrir sem necessidade de mover" severity error;
    assert led(3 downto 0) = "0001"
      report "FALHA T2: elevador nao deveria ter se movido" severity error;
    wait for T_DOOR + MARGIN;
    assert led(4) = '0'
      report "FALHA T2: porta deveria ter fechado apos os 4 s" severity error;
    report "T2 OK -> chamada no proprio andar tratada sem movimento";

    ----------------------------------------------------------------------
    report "==== TESTE 3: subida distante (sw3, andar 2) ====";
    ----------------------------------------------------------------------
    press(sw, 3);
    wait for MARGIN;
    assert led(5) = '1'
      report "FALHA T3: motor_up deveria estar ativo" severity error;
    wait for 2 * T_MOVE + MARGIN;
    assert led(3 downto 0) = "0100"
      report "FALHA T3: elevador deveria estar no andar 2" severity error;
    assert led(4) = '1'
      report "FALHA T3: porta deveria abrir no andar 2" severity error;
    wait for T_DOOR + MARGIN;
    assert led(4) = '0'
      report "FALHA T3: porta deveria ter fechado no andar 2" severity error;
    report "T3 OK -> subiu do andar 0 ao 2 e atendeu a chamada";

    ----------------------------------------------------------------------
    report "==== TESTE 4: SENSOR DE OBSTACULO bloqueia fechamento ====";
    ----------------------------------------------------------------------
    press(sw, 4);  -- chamada de descida no proprio andar (2) -> abre sem mover
    wait for MARGIN;
    assert led(4) = '1'
      report "FALHA T4: porta deveria abrir" severity error;

    sw(6) <= '1';  -- obstaculo presente desde o inicio da contagem dos 4s
    wait for T_DOOR + MARGIN;
    assert led(4) = '1'
      report "FALHA T4: porta fechou mesmo com obstaculo no sensor" severity error;

    sw(6) <= '0';  -- obstaculo removido
    wait for T_DOOR + MARGIN;
    assert led(4) = '0'
      report "FALHA T4: porta deveria fechar apos sensor liberar" severity error;
    report "T4 OK -> sensor manteve a porta aberta e liberou corretamente";

    ----------------------------------------------------------------------
    report "==== TESTE 5: COLETIVO (SCAN) + INVERSAO DE SENTIDO ====";
    ----------------------------------------------------------------------
    -- elevador esta parado no andar 2, dir_up = '1' (ultimo movimento foi subida)
    press(sw, 5);  -- chamada descida andar 3 (a frente, na direcao atual)
    press(sw, 1);  -- chamada subida andar 1 (atras, na direcao atual)
    wait for MARGIN;

    -- deve atender primeiro o andar 3 (a frente), nao o andar 1
    wait for T_MOVE + MARGIN;
    assert led(3 downto 0) = "1000"
      report "FALHA T5: elevador deveria subir ao andar 3 primeiro (SCAN)" severity error;
    assert led(4) = '1'
      report "FALHA T5: porta deveria abrir no andar 3" severity error;
    wait for T_DOOR + MARGIN;
    assert led(4) = '0'
      report "FALHA T5: porta deveria fechar no andar 3" severity error;

    -- agora deve inverter o sentido e descer ate o andar 1
    assert led(6) = '1'
      report "FALHA T5: motor_down deveria ativar (inversao de sentido)" severity error;
    wait for 2 * T_MOVE + MARGIN;
    assert led(3 downto 0) = "0010"
      report "FALHA T5: elevador deveria descer ate o andar 1" severity error;
    assert led(4) = '1'
      report "FALHA T5: porta deveria abrir no andar 1" severity error;
    wait for T_DOOR + MARGIN;
    report "T5 OK -> SCAN atendeu andar 3 antes do 1, depois inverteu e desceu";

    ----------------------------------------------------------------------
    report "==== TESTE 6: OCIOSIDADE (sem chamadas pendentes) ====";
    ----------------------------------------------------------------------
    wait for 5 * T_MOVE;
    assert led(10 downto 8) = "000"
      report "FALHA T6: elevador deveria permanecer parado (STOP)" severity error;
    assert led(5) = '0' and led(6) = '0'
      report "FALHA T6: motor nao deveria estar ativo sem chamadas" severity error;
    assert led(4) = '0'
      report "FALHA T6: porta nao deveria estar aberta sem chamadas" severity error;
    report "T6 OK -> elevador permanece ocioso, porta fechada, motor desligado";

    ----------------------------------------------------------------------
    report "==== FIM DOS TESTES - verifique se ha 'FALHA' no log acima ====";
    wait;
  end process;

end architecture sim;

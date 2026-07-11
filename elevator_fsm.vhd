--------------------------------------------------------------------------------
-- elevator_fsm.vhd
--
-- "Lógica do Estado Seguinte" + "Circuito de Controle" da Fig. 2 do roteiro.
--
-- Implementa o algoritmo COLETIVO DE SUBIDA / COLETIVO DE DESCIDA (Turma 01,
-- item (a) do ANEXO I): o elevador continua se movendo na direção atual
-- enquanto houver chamadas pendentes naquela direção (subida ou descida,
-- não importa qual botão originou a chamada); quando não há mais chamadas
-- à frente, inverte o sentido se houver chamadas do outro lado; se não há
-- nenhuma chamada, permanece parado (idle). É o clássico algoritmo SCAN.
--
-- Estados obrigatórios do roteiro: OPEN, STOP, CLOSE, UP, DOWN, SENSOR.
--
-- Simplificações assumidas (permitidas pelo roteiro: "de acordo com a
-- necessidade e bom senso"):
--   * Só existem chaves externas (hall calls); não há botões de cabine.
--   * Ao abrir a porta em um andar, qualquer chamada pendente NAQUELE
--     andar (subida OU descida) é liberada, já que só há uma cabine.
--   * Se o sensor detectar obstáculo ao final dos 4 s, a contagem da
--     porta destravada é reiniciada (a porta só fecha com a via livre).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elevator_fsm is
  generic (
    CLK_FREQ_HZ : natural := 100_000_000;  -- frequência do clock de entrada
    MOVE_TIME_S : natural := 2;            -- tempo entre andares (roteiro)
    DOOR_TIME_S : natural := 4             -- tempo de porta destravada (roteiro)
  );
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;

    pending_up      : in  std_logic_vector(3 downto 0);  -- da memória de retenção
    pending_down    : in  std_logic_vector(3 downto 0);
    sensor_obstacle : in  std_logic;                     -- '1' = obstáculo na porta
    floor_position  : in  unsigned(1 downto 0);          -- do controle de posição

    release_up      : out std_logic_vector(3 downto 0);  -- p/ memória de retenção
    release_down     : out std_logic_vector(3 downto 0);
    step_up          : out std_logic;                    -- p/ controle de posição
    step_down        : out std_logic;

    door_open        : out std_logic;  -- '1' enquanto a porta está aberta
    motor_up         : out std_logic;  -- '1' enquanto o motor sobe
    motor_down       : out std_logic;  -- '1' enquanto o motor desce
    state_dbg        : out std_logic_vector(2 downto 0)  -- depuração (LEDs)
  );
end entity elevator_fsm;

architecture rtl of elevator_fsm is

  type state_t is (S_STOP, S_UP, S_DOWN, S_OPEN, S_SENSOR, S_CLOSE);
  signal state, next_state : state_t := S_STOP;

  -- direção do último/atual deslocamento: '1' = subindo, '0' = descendo
  signal dir_up : std_logic := '1';

  constant MOVE_CYCLES : natural := CLK_FREQ_HZ * MOVE_TIME_S;
  constant DOOR_CYCLES : natural := CLK_FREQ_HZ * DOOR_TIME_S;

  signal move_start, move_done : std_logic;
  signal door_start, door_done : std_logic;

  signal call_here      : std_logic;  -- existe chamada no andar atual
  signal any_call_above : std_logic;  -- existe chamada em andar acima do atual
  signal any_call_below : std_logic;  -- existe chamada em andar abaixo do atual

begin

  ------------------------------------------------------------------
  -- Temporizadores (2 s para andar-a-andar, 4 s para porta destravada)
  ------------------------------------------------------------------
  timer_move : entity work.timer_pulse
    generic map ( TIMEOUT_CYCLES => MOVE_CYCLES )
    port map ( clk => clk, rst => rst, start => move_start, done => move_done );

  timer_door : entity work.timer_pulse
    generic map ( TIMEOUT_CYCLES => DOOR_CYCLES )
    port map ( clk => clk, rst => rst, start => door_start, done => door_done );

  ------------------------------------------------------------------
  -- Avaliação combinacional das chamadas pendentes em relação ao andar atual
  ------------------------------------------------------------------
  process(pending_up, pending_down, floor_position)
    variable ch, above, below : std_logic;
    variable f : integer;
  begin
    f := to_integer(floor_position);
    ch    := pending_up(f) or pending_down(f);
    above := '0';
    below := '0';

    for i in 0 to 3 loop
      if i > f then
        if pending_up(i) = '1' or pending_down(i) = '1' then
          above := '1';
        end if;
      elsif i < f then
        if pending_up(i) = '1' or pending_down(i) = '1' then
          below := '1';
        end if;
      end if;
    end loop;

    call_here      <= ch;
    any_call_above <= above;
    any_call_below <= below;
  end process;

  ------------------------------------------------------------------
  -- Registrador de estado e de direção (SCAN)
  ------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state  <= S_STOP;
        dir_up <= '1';
      else
        state <= next_state;

        if state = S_STOP and call_here = '0' then
          if dir_up = '1' and any_call_above = '1' then
            dir_up <= '1';                       -- continua subindo
          elsif dir_up = '0' and any_call_below = '1' then
            dir_up <= '0';                       -- continua descendo
          elsif any_call_above = '1' then
            dir_up <= '1';                       -- inverte: passa a subir
          elsif any_call_below = '1' then
            dir_up <= '0';                       -- inverte: passa a descer
          end if;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Lógica de próximo estado e saídas de controle (Mealy/Moore misto)
  ------------------------------------------------------------------
  process(state, call_here, any_call_above, any_call_below, dir_up,
          move_done, door_done, sensor_obstacle, floor_position)
    variable f : integer;
  begin
    f := to_integer(floor_position);

    -- valores padrão (evita latches)
    next_state   <= state;
    move_start   <= '0';
    door_start   <= '0';
    step_up      <= '0';
    step_down    <= '0';
    door_open    <= '0';
    motor_up     <= '0';
    motor_down   <= '0';
    release_up   <= (others => '0');
    release_down <= (others => '0');

    case state is

      when S_STOP =>
        if call_here = '1' then
          next_state <= S_OPEN;

        elsif dir_up = '1' and any_call_above = '1' then
          next_state <= S_UP;
          move_start <= '1';

        elsif dir_up = '0' and any_call_below = '1' then
          next_state <= S_DOWN;
          move_start <= '1';

        elsif any_call_above = '1' then
          next_state <= S_UP;
          move_start <= '1';

        elsif any_call_below = '1' then
          next_state <= S_DOWN;
          move_start <= '1';
        end if;
        -- sem chamadas: permanece em S_STOP (idle)

      when S_UP =>
        motor_up <= '1';
        if move_done = '1' then
          step_up    <= '1';
          next_state <= S_STOP;
        end if;

      when S_DOWN =>
        motor_down <= '1';
        if move_done = '1' then
          step_down  <= '1';
          next_state <= S_STOP;
        end if;

      when S_OPEN =>
        door_open           <= '1';
        release_up(f)       <= '1';  -- libera a chamada deste andar
        release_down(f)     <= '1';
        door_start          <= '1'; -- inicia contagem dos 4 s
        next_state          <= S_SENSOR;

      when S_SENSOR =>
        door_open <= '1';
        if door_done = '1' then
          if sensor_obstacle = '1' then
            door_start <= '1';  -- obstáculo: reinicia a contagem, porta continua aberta
          else
            next_state <= S_CLOSE;
          end if;
        end if;

      when S_CLOSE =>
        -- porta fechando; volta a STOP para reavaliar novas chamadas
        next_state <= S_STOP;

    end case;
  end process;

  state_dbg <= "000" when state = S_STOP   else
               "001" when state = S_UP     else
               "010" when state = S_DOWN   else
               "011" when state = S_OPEN   else
               "100" when state = S_SENSOR else
               "101";  -- S_CLOSE

end architecture rtl;

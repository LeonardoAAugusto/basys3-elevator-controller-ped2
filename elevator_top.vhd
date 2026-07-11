--------------------------------------------------------------------------------
-- elevator_top.vhd
--
-- Top-level do Controlador de Elevador (Prédio de 4 andares) para a Basys3.
-- Integra todos os blocos da Fig. 2 do roteiro: memória de retenção,
-- controle de posição, FSM (lógica do estado seguinte + circuito de
-- controle) e a lógica de saída (display de 7 segmentos + LEDs).
--
-- Algoritmo: Coletivo de subida / Coletivo de descida (Turma 01).
--
-- Mapeamento de entradas (switches):
--   sw(0) = chamada de SUBIDA no andar 0 (térreo)      [único botão do térreo]
--   sw(1) = chamada de SUBIDA no andar 1
--   sw(2) = chamada de DESCIDA no andar 1
--   sw(3) = chamada de SUBIDA no andar 2
--   sw(4) = chamada de DESCIDA no andar 2
--   sw(5) = chamada de DESCIDA no andar 3 (último andar) [único botão do topo]
--   sw(6) = sensor infravermelho ('1' = obstáculo/pessoa na porta)
--   sw(15 downto 7) = não utilizados
--   btnC  = reset geral (debounced)
--
-- Mapeamento de saídas:
--   led(3 downto 0)  = vetor um-hot do andar atual (led(0)=andar0 ... led(3)=andar3)
--   led(4)           = porta aberta
--   led(5)           = motor subindo
--   led(6)           = motor descendo
--   led(7)           = sensor com obstáculo (eco do sw(6), útil p/ depuração)
--   led(10 downto 8) = estado da FSM (depuração)
--   an/seg/dp        = pictograma do prédio (ver display_driver.vhd)
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity elevator_top is
  generic (
    CLK_FREQ_HZ     : natural := 100_000_000;  -- clock da Basys3 (100 MHz)
    MOVE_TIME_S     : natural := 2;            -- roteiro: 2 s entre andares
    DOOR_TIME_S     : natural := 4;            -- roteiro: 4 s de porta destravada
    DEBOUNCE_CYCLES : natural := 1_000_000     -- debounce do botão de reset
  );
  port (
    clk  : in  std_logic;
    btnC : in  std_logic;
    sw   : in  std_logic_vector(15 downto 0);
    led  : out std_logic_vector(15 downto 0);
    seg  : out std_logic_vector(6 downto 0);
    dp   : out std_logic;
    an   : out std_logic_vector(3 downto 0)
  );
end entity elevator_top;

architecture structural of elevator_top is

  signal rst : std_logic;

  signal call_up_in, call_down_in       : std_logic_vector(3 downto 0);
  signal pending_up, pending_down       : std_logic_vector(3 downto 0);
  signal release_up, release_down       : std_logic_vector(3 downto 0);

  signal floor_position : unsigned(1 downto 0);
  signal step_up, step_down             : std_logic;

  signal door_open, motor_up, motor_down : std_logic;
  signal sensor_obstacle                 : std_logic;
  signal state_dbg                       : std_logic_vector(2 downto 0);

  signal floor_onehot : std_logic_vector(3 downto 0);

begin

  ------------------------------------------------------------------
  -- Reset (debounce do BTNC)
  ------------------------------------------------------------------
  u_debounce_rst : entity work.debounce
    generic map ( DEBOUNCE_CYCLES => DEBOUNCE_CYCLES )
    port map ( clk => clk, btn_in => btnC, btn_out => rst );

  ------------------------------------------------------------------
  -- Mapeamento das chaves de acionamento (entradas simuladas por switches)
  ------------------------------------------------------------------
  sensor_obstacle <= sw(6);

  call_up_in   <= (0 => sw(0), 1 => sw(1), 2 => sw(3), 3 => '0');
  call_down_in <= (0 => '0',   1 => sw(2), 2 => sw(4), 3 => sw(5));

  ------------------------------------------------------------------
  -- Memória de Retenção
  ------------------------------------------------------------------
  u_retention : entity work.retention_memory
    port map (
      clk          => clk,
      rst          => rst,
      call_up_in   => call_up_in,
      call_down_in => call_down_in,
      release_up   => release_up,
      release_down => release_down,
      pending_up   => pending_up,
      pending_down => pending_down
    );

  ------------------------------------------------------------------
  -- Controle de Posição e Localização do Elevador
  ------------------------------------------------------------------
  u_position : entity work.position_counter
    port map (
      clk       => clk,
      rst       => rst,
      step_up   => step_up,
      step_down => step_down,
      floor     => floor_position
    );

  ------------------------------------------------------------------
  -- Lógica do Estado Seguinte + Circuito de Controle (FSM)
  ------------------------------------------------------------------
  u_fsm : entity work.elevator_fsm
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      MOVE_TIME_S => MOVE_TIME_S,
      DOOR_TIME_S => DOOR_TIME_S
    )
    port map (
      clk             => clk,
      rst             => rst,
      pending_up      => pending_up,
      pending_down    => pending_down,
      sensor_obstacle => sensor_obstacle,
      floor_position  => floor_position,
      release_up      => release_up,
      release_down    => release_down,
      step_up         => step_up,
      step_down       => step_down,
      door_open       => door_open,
      motor_up        => motor_up,
      motor_down      => motor_down,
      state_dbg       => state_dbg
    );

  ------------------------------------------------------------------
  -- Lógica de Saída (display de 7 segmentos)
  ------------------------------------------------------------------
  u_display : entity work.display_driver
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      REFRESH_HZ  => 1000
    )
    port map (
      clk            => clk,
      rst            => rst,
      floor_position => floor_position,
      door_open      => door_open,
      an             => an,
      seg            => seg,
      dp             => dp
    );

  ------------------------------------------------------------------
  -- LEDs: vetor de posição + sinais de depuração
  ------------------------------------------------------------------
  floor_onehot <= "0001" when floor_position = 0 else
                  "0010" when floor_position = 1 else
                  "0100" when floor_position = 2 else
                  "1000";

  led(3 downto 0)  <= floor_onehot;
  led(4)           <= door_open;
  led(5)           <= motor_up;
  led(6)           <= motor_down;
  led(7)           <= sensor_obstacle;
  led(10 downto 8) <= state_dbg;
  led(15 downto 11) <= (others => '0');

end architecture structural;

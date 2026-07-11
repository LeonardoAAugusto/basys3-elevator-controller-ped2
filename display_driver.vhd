--------------------------------------------------------------------------------
-- display_driver.vhd
--
-- "Lógica de Saída" (Fig. 1 do roteiro), usando os 4 dígitos do display de
-- 7 segmentos da Basys3 como um pictograma do prédio:
--   an(0) -> andar 0 (térreo)   an(1) -> andar 1
--   an(2) -> andar 2            an(3) -> andar 3 (último andar)
--
-- Em cada dígito:
--   * Se NÃO é o andar onde está a cabine: acende só o segmento central
--     (g), representando o nível do piso/poço.
--   * Se É o andar da cabine, porta FECHADA: acende a..f (retângulo
--     fechado = cabine "fechada").
--   * Se É o andar da cabine, porta ABERTA: acende b,c,e,f (duas barras
--     verticais separadas = portas afastadas).
--
-- Convenção: display de 7 segmentos da Basys3 é ânodo comum -> segmentos
-- ativos em nível BAIXO. seg(0)=CA, seg(1)=CB, ..., seg(6)=CG (ver XDC).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_driver is
  generic (
    CLK_FREQ_HZ : natural := 100_000_000;
    REFRESH_HZ  : natural := 1000  -- taxa de troca entre os 4 dígitos
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    floor_position : in  unsigned(1 downto 0);
    door_open      : in  std_logic;
    an             : out std_logic_vector(3 downto 0);  -- ativo em nível baixo
    seg            : out std_logic_vector(6 downto 0);  -- ativo em nível baixo
    dp             : out std_logic
  );
end entity display_driver;

architecture rtl of display_driver is

  constant DIV_MAX : natural := CLK_FREQ_HZ / REFRESH_HZ;

  signal div_counter : unsigned(31 downto 0) := (others => '0');
  signal digit_sel    : unsigned(1 downto 0) := (others => '0');
  signal is_current   : std_logic;

begin

  ------------------------------------------------------------------
  -- Divisor de clock: multiplexação dos 4 dígitos (varredura)
  ------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        div_counter <= (others => '0');
        digit_sel   <= (others => '0');
      elsif div_counter = DIV_MAX - 1 then
        div_counter <= (others => '0');
        digit_sel   <= digit_sel + 1;
      else
        div_counter <= div_counter + 1;
      end if;
    end if;
  end process;

  an <= "1110" when digit_sel = 0 else   -- an(0) ativo -> andar 0
        "1101" when digit_sel = 1 else   -- an(1) ativo -> andar 1
        "1011" when digit_sel = 2 else   -- an(2) ativo -> andar 2
        "0111";                          -- an(3) ativo -> andar 3

  is_current <= '1' when to_integer(digit_sel) = to_integer(floor_position) else '0';

  ------------------------------------------------------------------
  -- Padrão de segmentos do dígito atualmente selecionado
  ------------------------------------------------------------------
  process(is_current, door_open)
  begin
    if is_current = '1' and door_open = '0' then
      -- andar da cabine, porta fechada: a..f acesos, g apagado
      seg <= (0 => '0', 1 => '0', 2 => '0', 3 => '0',
              4 => '0', 5 => '0', 6 => '1');

    elsif is_current = '1' and door_open = '1' then
      -- andar da cabine, porta aberta: b,c,e,f acesos (duas barras), a,d,g apagados
      seg <= (0 => '1', 1 => '0', 2 => '0', 3 => '1',
              4 => '0', 5 => '0', 6 => '1');

    else
      -- andar sem a cabine: só o traço central (g) aceso
      seg <= (0 => '1', 1 => '1', 2 => '1', 3 => '1',
              4 => '1', 5 => '1', 6 => '0');
    end if;
  end process;

  dp <= '1';  -- ponto decimal sempre apagado

end architecture rtl;

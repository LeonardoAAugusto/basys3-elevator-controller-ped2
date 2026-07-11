--------------------------------------------------------------------------------
-- retention_memory.vhd
--
-- Bloco "Memória de Retenção" do diagrama da Fig. 2 do roteiro.
--
-- As chaves de acionamento (call_up_in / call_down_in) são simuladas por
-- switches na placa. Uma borda de subida em call_*_in(i) "trava" o pedido
-- daquele andar (pending_*(i) = '1'), mesmo que o usuário abaixe o switch
-- em seguida. O pedido só é liberado quando a FSM envia um pulso de 1 ciclo
-- em release_*(i) (ao abrir a porta naquele andar).
--
-- pending_up(0)/pending_down(3) não existem fisicamente (térreo só sobe,
-- último andar só desce) — o nível acima (top) simplesmente nunca ativa
-- call_up_in(3) nem call_down_in(0).
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity retention_memory is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;

    call_up_in   : in  std_logic_vector(3 downto 0);  -- "andares desejados" (subida)
    call_down_in : in  std_logic_vector(3 downto 0);  -- "andares desejados" (descida)

    release_up   : in  std_logic_vector(3 downto 0);  -- pulso de liberação (subida)
    release_down : in  std_logic_vector(3 downto 0);  -- pulso de liberação (descida)

    pending_up   : out std_logic_vector(3 downto 0);
    pending_down : out std_logic_vector(3 downto 0)
  );
end entity retention_memory;

architecture rtl of retention_memory is
  signal up_reg,   down_reg   : std_logic_vector(3 downto 0) := (others => '0');
  signal up_prev,  down_prev  : std_logic_vector(3 downto 0) := (others => '0');
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        up_reg    <= (others => '0');
        down_reg  <= (others => '0');
        up_prev   <= (others => '0');
        down_prev <= (others => '0');
      else
        for i in 0 to 3 loop
          -- chamadas de subida
          if release_up(i) = '1' then
            up_reg(i) <= '0';
          elsif call_up_in(i) = '1' and up_prev(i) = '0' then
            up_reg(i) <= '1';
          end if;

          -- chamadas de descida
          if release_down(i) = '1' then
            down_reg(i) <= '0';
          elsif call_down_in(i) = '1' and down_prev(i) = '0' then
            down_reg(i) <= '1';
          end if;
        end loop;

        up_prev   <= call_up_in;
        down_prev <= call_down_in;
      end if;
    end if;
  end process;

  pending_up   <= up_reg;
  pending_down <= down_reg;

end architecture rtl;

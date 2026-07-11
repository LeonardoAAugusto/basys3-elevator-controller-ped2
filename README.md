# Controlador de Elevador — Basys3 (VHDL)

Controlador digital para um elevador de 4 andares (térreo + 3 pavimentos),
implementado em VHDL estrutural e sintetizável para a placa **Digilent
Basys3** (FPGA Artix-7, `xc7a35tcpg236-1`).

Projeto desenvolvido para o laboratório substitutivo de **Prática de
Eletrônica Digital 2** (UnB/FCTE, Prof. Gilmar Beserra, 1/2026), Turma 01
— algoritmo **Coletivo de subida / Coletivo de descida** (o clássico
algoritmo *SCAN* de escalonamento de elevadores).

## Sobre o projeto

O sistema controla fisicamente um elevador simulado na placa: recebe
chamadas de andar por meio de switches, decide para onde se mover
seguindo o princípio coletivo (SCAN), controla o tempo de deslocamento
entre andares e de abertura de porta, respeita um sensor de presença
(infravermelho) antes de fechar a porta, e mostra o estado do elevador
em LEDs e em um pictograma no display de 7 segmentos.

**Principais características:**

- Máquina de estados com os 6 estados exigidos no roteiro: `OPEN`,
  `STOP`, `CLOSE`, `UP`, `DOWN`, `SENSOR`.
- Algoritmo coletivo (SCAN): o elevador continua na direção atual
  enquanto houver chamadas pendentes à frente; só inverte o sentido
  quando não há mais nada a atender naquela direção.
- Temporização real de **2 s** por andar percorrido e **4 s** de porta
  destravada, ambas parametrizáveis via `generic`.
- Sensor de obstáculo que impede o fechamento da porta enquanto houver
  presença detectada.
- Memória de retenção das chamadas (funcionam como botões: uma borda de
  subida no switch já trava o pedido, mesmo que você abaixe o switch
  depois).
- Saída visual em LEDs (posição, porta, motor, estado) e um pictograma
  do prédio nos 4 dígitos do display de 7 segmentos.
- Totalmente modular (memória de retenção, controle de posição, FSM e
  lógica de saída são blocos independentes, como no diagrama do
  roteiro) e com testbench próprio.

## Como funciona (visão geral)

```
                 ┌──────────────────────┐
  sw(0..5) ────▶ │  Memória de Retenção  │──▶ pending_up / pending_down
 (chamadas)      └──────────────────────┘            │
                                                       ▼
 ┌───────────┐        ┌─────────────────────────────────┐      ┌────────────────┐
 │  Sensor   │──────▶ │           elevator_fsm            │────▶│ motor_up/down   │
 │  (sw6)    │        │  STOP → UP/DOWN → STOP → OPEN →   │     │ door_open       │
 └───────────┘        │  SENSOR → CLOSE → STOP (SCAN)     │     └────────────────┘
                       └─────────────────────────────────┘
                            ▲                    │
                    floor_position         step_up / step_down
                            │                    ▼
                    ┌──────────────────────┐
                    │   position_counter    │
                    └──────────────────────┘
                            │
                            ▼
                    ┌──────────────────────┐
                    │    display_driver      │──▶ an / seg / dp (7 segmentos)
                    └──────────────────────┘
```

Esse fluxo é a implementação direta do diagrama de blocos da Fig. 2 do
roteiro (Chaves de Acionamento → Memória de Retenção → Lógica do Estado
Seguinte/Circuito de Controle → Motor/Display, com o Controle de Posição
realimentando a FSM).

## Estrutura do repositório

| Arquivo                  | Bloco do diagrama (Fig. 2)                       |
|---------------------------|---------------------------------------------------|
| `timer_pulse.vhd`         | Temporizador genérico (usado para os 2 s e 4 s)   |
| `debounce.vhd`            | Debounce do botão de reset                         |
| `retention_memory.vhd`    | Memória de Retenção                                |
| `position_counter.vhd`    | Controle de Posição e Localização do Elevador      |
| `elevator_fsm.vhd`        | Lógica do Estado Seguinte + Circuito de Controle   |
| `display_driver.vhd`      | Lógica de Saída (display de 7 segmentos)           |
| `elevator_top.vhd`        | Top-level (integra tudo, pinos da Basys3)          |
| `elevator_top_basys3.xdc` | Restrições físicas (pinagem) da Basys3             |
| `tb_elevator_top.vhd`     | Testbench para simulação comportamental            |
| `.gitignore`              | Ignora artefatos gerados pelo Vivado               |

## Algoritmo de escalonamento (Coletivo subida / Coletivo descida)

A cada parada, a FSM (`elevator_fsm.vhd`) decide o próximo passo assim:

1. Há chamada **no andar atual**? → abre a porta.
2. Senão, há chamada **à frente, na direção em que já estava indo**? →
   continua nessa direção.
3. Senão, há chamada **do outro lado**? → inverte o sentido.
4. Senão → fica parado (idle), porta fechada.

Isso é o algoritmo *SCAN*: o elevador "varre" o prédio de ponta a ponta,
atendendo tudo que encontra pelo caminho, só invertendo quando não há
mais nada à frente — evita que ele fique indo e voltando
desnecessariamente. Referência conceitual: Muñoz, A. Daniel M.,
*"Implementação e Simulação de Algoritmos de Escalonamento para Sistemas
de Elevadores Usando Arquiteturas Reconfiguráveis"*, Dissertação de
Mestrado, UnB, 2006 (citada no ANEXO I do roteiro da disciplina).

## Mapeamento de pinos (Basys3)

### Entradas

| Sinal   | Pino  | Função                                              |
|---------|-------|------------------------------------------------------|
| `clk`   | W5    | Clock de 100 MHz da placa                             |
| `btnC`  | U18   | Reset geral (debounced)                               |
| `sw(0)` | V17   | Chamada de **subida** — andar 0 (térreo)               |
| `sw(1)` | V16   | Chamada de **subida** — andar 1                        |
| `sw(2)` | W16   | Chamada de **descida** — andar 1                       |
| `sw(3)` | W17   | Chamada de **subida** — andar 2                        |
| `sw(4)` | W15   | Chamada de **descida** — andar 2                       |
| `sw(5)` | V15   | Chamada de **descida** — andar 3 (topo)                |
| `sw(6)` | W14   | Sensor infravermelho (`1` = obstáculo/pessoa na porta) |

Não há botões de cabine — simplificação explícita permitida pelo roteiro
("consideraremos a existência apenas das chaves externas ao elevador").
Os switches funcionam como botões: uma borda de subida já trava o
pedido na memória de retenção, então dá pra levantar e abaixar o switch
que o pedido continua registrado até ser atendido.

### Saídas

| Sinal              | Função                                                        |
|---------------------|----------------------------------------------------------------|
| `led(3 downto 0)`  | Vetor um-hot do andar atual                                    |
| `led(4)`           | Porta aberta                                                   |
| `led(5)` / `led(6)`| Motor subindo / descendo                                       |
| `led(7)`           | Eco do sensor (depuração)                                      |
| `led(10 downto 8)` | Estado da FSM (depuração — ver tabela abaixo)                  |
| `an` / `seg` / `dp`| Pictograma do prédio no display de 7 segmentos (ver abaixo)    |

**Pictograma do display:** cada um dos 4 dígitos representa um andar
(`an(0)` = térreo ... `an(3)` = topo). O dígito onde está a cabine mostra
um retângulo fechado (porta fechada) ou duas barras verticais (porta
aberta, imitando portas afastadas); os demais dígitos mostram só o
traço central, indicando o nível do piso. É uma interpretação livre da
Fig. 1 do roteiro — ajuste os padrões em `display_driver.vhd` se quiser
algo mais fiel ao desenho exato do enunciado.

### Legenda de `state_dbg` (led 10:8)

| Código | Estado    |
|--------|-----------|
| `000`  | `S_STOP`  |
| `001`  | `S_UP`    |
| `010`  | `S_DOWN`  |
| `011`  | `S_OPEN`  (dura só 1 ciclo de clock — praticamente invisível a olho nu) |
| `100`  | `S_SENSOR` (é aqui que a porta realmente fica "visivelmente" aberta) |
| `101`  | `S_CLOSE` (também dura só 1 ciclo)                                    |

## Temporização

| Parâmetro     | Valor padrão | Generic em `elevator_top`/`elevator_fsm` |
|----------------|--------------|---------------------------------------------|
| Clock da placa | 100 MHz      | `CLK_FREQ_HZ`                                |
| Tempo entre andares | 2 s     | `MOVE_TIME_S`                                |
| Porta destravada    | 4 s     | `DOOR_TIME_S`                                |

## Requisitos

- Xilinx Vivado (testado o fluxo padrão de projeto RTL; qualquer versão
  recente com suporte a `xc7a35tcpg236-1` deve funcionar).
- Placa Digilent Basys3.
- (Opcional, só para simular fora do Vivado) [GHDL](https://github.com/ghdl/ghdl)
  — foi o que usei para validar a sintaxe e o comportamento antes de
  entregar este projeto.

## Como usar

### 1. Criar o projeto no Vivado

1. **File → New Project** → RTL Project.
2. Adicione todos os `.vhd` **exceto** `tb_elevator_top.vhd` como Design
   Sources.
3. Adicione `elevator_top_basys3.xdc` como Constraints.
4. Escolha a placa Basys3 (ou a part `xc7a35tcpg236-1` diretamente).
5. Marque `elevator_top` como top module (Sources → botão direito →
   Set as Top).

### 2. Simular (opcional, mas recomendado)

1. Adicione `tb_elevator_top.vhd` em Simulation Sources e marque-o como
   top de simulação.
2. **Flow Navigator → Run Simulation → Run Behavioral Simulation**.
3. Observe `floor_position`, `door_open`, `led`, `an`, `seg` na
   hierarquia `tb_elevator_top/dut`.

O testbench usa `CLK_FREQ_HZ => 1000` só para a simulação rodar rápido —
**não altere os generics ao gerar o bitstream real** (os valores padrão
já são 100 MHz / 2 s / 4 s).

### 3. Sintetizar, implementar e gravar

1. **Run Synthesis → Run Implementation → Generate Bitstream**.
2. **Open Hardware Manager → Auto Connect → Program Device**, selecione
   o `.bit` gerado.

## Roteiro de testes na placa

Tempos reais (2 s por andar, 4 s de porta). Cada teste parte do estado
final do teste anterior, exceto onde indicado.

| # | Estado inicial | Ação | O que observar (LEDs) | Display | Tempo aprox. |
|---|-----------------|------|--------------------------|---------|----------------|
| 0 | Qualquer | Pressionar e soltar `btnC` | `led(3:0)=0001`, `led(4:10)=0` | Térreo fechado, demais em traço | Imediato |
| 1 | Térreo, porta fechada | Subir `sw(0)` e abaixar | `led(5/6)` não acendem (não anda); `led(4)` sobe já quase na hora | Dígito do térreo vira "aberto" (2 barras) por ~4 s | ~4 s (só a porta) |
| 2 | Térreo, porta fechada | Subir `sw(3)` (chamada andar 2) e abaixar | `led(5)` acende ~4 s (2 pernas de 2 s); `led(3:0)` vai `0001→0010→0100`; `led(4)` sobe ao chegar | Quadrado "anda" andar a andar, ~2 s em cada; abre (2 barras) no andar 2 | ~4 s pra chegar + 4 s de porta |
| 3 | Andar 2, porta aberta (dentro da janela dos 4 s) | Subir `sw(6)` (obstáculo) antes de fechar | `led(4)` continua em 1 enquanto `sw(6)=1` | Dígito do andar 2 continua "aberto" | Enquanto `sw(6)=1`, nunca fecha |
| 4 | Porta aberta, `sw(6)=1` | Abaixar `sw(6)` | `led(4)` volta a 0 até 4 s depois | Dígito do andar 2 volta a "fechado" | Até 4 s |
| 5 | Andar 2, porta fechada (última direção = subida) | Subir `sw(5)` (chamada descida andar 3) e abaixar | `led(5)` acende de novo — sobe até o topo mesmo a chamada sendo de descida (SCAN); `led(3:0)` vai `0100→1000` | Quadrado sobe até o andar 3, abre (2 barras) | ~2 s pra subir + 4 s de porta |
| 6 | Andar 3 (topo), porta fechada | Subir `sw(0)` (chamada subida térreo) e abaixar | `led(6)` acende (inverte p/ descer); `led(3:0)` desce `1000→0100→0010→0001` | Quadrado desce dígito a dígito, ~2 s cada, abre no térreo | ~6 s pra descer + 4 s de porta |
| 7 | Qualquer (ex.: no meio de um deslocamento) | Pressionar `btnC` | `led(3:0)` volta a `0001` na hora; `led(4:10)=0` | Volta direto pro térreo fechado | Imediato |

## Simplificações assumidas

- Só existem chaves externas (hall calls); não há botões de cabine.
- Ao abrir a porta em um andar, tanto o pedido de subida quanto o de
  descida daquele andar são liberados (só há uma cabine).
- Se o sensor detectar obstáculo ao final dos 4 s, a contagem da porta
  destravada é reiniciada.

## Possíveis extensões

- Botões de cabine (chamadas internas), sempre atendidas de forma
  coletiva, coexistindo com as chamadas de pavimento.
- Pictograma mais elaborado no display (ex.: animação de abertura de
  porta).
- Um segundo modo de clock (via botão) para acelerar a demonstração ao
  vivo para o professor.

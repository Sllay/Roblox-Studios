# Refinamento T2-R2 após v20 · PR #14

O feedback integral está na [Bíblia](../VISION_MASTER.md#26112026--refinamento-do-playtest-v20). Staging v20 permanece a referência de comparação. Runtime econômico e ruleset 5 permanecem a base. Toda prévia nova requer autorização específica.

## A · HUD compartilhada

VillageUI reúne paleta, componentes e medidas de área segura. Duas barras separam recursos de equipamento. A superior mantém ordem e posição durante atualizações de quantidade, revela até quatro slots e encaixa a rolagem na largura do slot. Seus valores representam bolsa pessoal, estoque livre em galpões e bolsas de moradores vivos e capacidade total para aquele recurso com o espaço ainda livre. Reservas de retirada e entrega ficam separadas. Ícones são desenhados com elementos nativos. A barra inferior usa registro de itens e valida posse no servidor ao equipar e usar. Controles circulares possuem disposição própria para tela baixa.

Referências revisadas · [Position and size](https://create.roblox.com/docs/ui/position-and-size) · [Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design) · [ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui). O comportamento visual e o encaixe por toque requerem cliente real.

## B — Estruturas e ordens

- O cliente recebe mudanças do alvo contextual. Distância, orientação, linha de visão de Terrain e barreiras fechadas participam da seleção, com preferência pelo alvo atual para evitar alternância rápida.
- Castelo, carpintaria, ferraria, galpão, fazenda e doca têm páginas próprias. Produção exige a estação específica. Transferências do galpão verificam proximidade, autorização, reservas e capacidade.
- Profissões, prioridades e equipamento usam ordens no caderno. Uma reserva de equipamento é temporária. A entrega exige chegada ao depósito que realmente tem o item. Ferramentas substituídas conservam a durabilidade.
- Luau verificou uma lança disputada por dois moradores, reserva exclusiva, reabertura e retirada após deslocamento. Os 26 testes Python específicos passaram. Layout, seleção de alvos e acesso às estruturas seguem pendentes em cliente Roblox.

## C — Navegação local e atendimento

- Índice espacial por tick reduz o conjunto de vizinhos consultado pelo desvio. A procura de rota regional e a capacidade de pontes continuam nos motores existentes.
- Pontos de atendimento distintos são reservados ao chegar à estrutura. O detector compara a distância ao destino ao longo do tempo e pode liberar um trabalho parado sem descartar carga.
- A apresentação usa velocidade suavizada e limiares diferentes para iniciar e parar a animação de caminhada.
- Passaram as suítes Luau de produção, alimentação, mercado, regiões, pontes, trabalho e 2.400 segundos de simulação de dois reinos. A regressão de atendimento confirmou três pontos distintos e transferência da vaga. Cadência de rede e fluidez visual ainda precisam de cliente Roblox.

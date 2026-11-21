# AUDITORIA DE MECÂNICAS — OBSERVAÇÕES COMPROVADAS E ADAPTAÇÕES

Pesquisa inicial 21/11/2026. Fonte técnica central: SongZcode/kingdom-two-crowns-mechanics, versão 2.4.2, revisão 23529, campanha padrão OakAndBirch. Classes/mods de 2.4.0 são contexto independente. Números originais estão em unidades Unity/escala própria e NÃO podem ser tratados como studs ou presets Roblox.

| ID | Subsystem analisado | Evidência do Kingdom (ESPECÍFICA) | Adaptar no Entre Reinos | Responsável |
|---|---|---|---|---|
| K-01 | Câmera/entrada | Minimalismo lateral; pouca UI, esquerda/direita, interações por proximidade (P/O) | Cena 100% 3D com câmera lateral; R6 X/Y, Z visual; ações contextuais, radial touch, sem copiar interface | T1-R1 |
| K-02 | Dia/noite | Relógio 10 segundos por hora, 240s/dia; noite de jogo 75s (A), céu tem transições separadas | TimeService com relógio de jogo e flags de segurança distintas; duração definida por teste Roblox | T1-R3 |
| K-03 | Temporadas | Quatro estações de 16 dias, ano de 64; dias normais/blood moon/descanso por curvas configuradas (A/N) | Calendário modular, fases e eventos; no T1 apenas dia/noite, sem estação sistêmica antes de T2 | T2-R1 |
| K-04 | Ondas | Wave profiles regulares, especiais, retaliação e descanso, 10s de janela configurada; geração depende de curvas/dificuldade/portal (A/N) | RaidDirector com orçamento, alvos, prioridades e portais; não tabelar inimigo por dia cego | T1-R3, final T2-R2 |
| K-05 | Curvas de inimigos | Curva weak Greed com keys 0→1, 4→4, 15→8, 32→16, 96→32, 160→32, 250→0; tangentes e chamadas faltam (A/N/U) | ThreatBudget próprio com multiplicadores de ameaça/reino/objetivo e limites de segurança; curvas próprias testadas | T2-R2 |
| K-06 | Recrutamento | Um coin para mendigo elegível; comprar arco/martelo/foice por 2/3/4 coins; NPC toma ferramenta e vira profissão (A/N) | Recrutar + inventário/equipar + especialização com habilidades em vez de trocar estado fixo | T1-R2 |
| K-07 | Carteiras | Campos 1/3/12/15/1000 conforme tipo; NÃO comprovam capacidade física da bolsa nem proteção universal (A/U) | Ledger dinheiro separado de render, inventários físicos e peso de NPCs, bolsa visual com pooling | T1-R2, T1-R3 |
| K-08 | Banco | Juros dia: min(ceil(saldo*0.1),8); saque: portado+ceil(depositado*0.25), limitado a completar bolsa até 39 (A/N) | Tesouro, impostos, salário e comércio baseado em transações; NÃO gerar inflação passiva bancária automática | T2-R2 |
| K-09 | Fazenda | 20 pontos de trabalho→6 moedas na configuração normal; trabalhador acrescenta pontos; intervalos condicionais (A/N) | Fazendas produzem comida/material, irrigação, consumo e venda; produtividade por skill e terreno | T2-R2 |
| K-10 | Trabalho | Trabalhador 0.65/1.6 unidades/s, tick 0.7 s, 1 ponto, 2 vagas em obra; primeiro muro 10 pontos; cronograma afetado por viagem e interrupção (A/N) | Trabalho em unidades/segundo, multiplos colaboradores, estoque progressivo, especialização, save e retomar | T1-R2 |
| K-11 | Atribuição | Job cost = trunc(distância X) -12 se mantiver trabalho - prioridade; construção tem prioridade 75, reparo -50 no contexto observado (N) | Utility/JobScore: urgência, skill, distância, risco, material, fadiga, continuidade, segurança, reserva e capacidade | T1-R2 |
| K-12 | Perigo e noite | Builder não para toda tarefa só por anoitecer; raio de perigo dentro <5 / fora <8.5; recuo 2–3s e replaneja (A/N) | NPC com estado de ameaça/abrigo, prioridades e interrupção seletiva; não travar todas as tarefas à noite | T1-R2/R3 |
| K-13 | Muros | Estágios Wall1..5 HP 25,50,200,300,400; custo 1,3,5,8,12 coins para aresta; trabalho 10,30,60,75,90 pontos (A/N) | Muro modular por receita madeira/pedra/metais, HP, resistência, trabalhador, distrito e reparo | T1-R2/R3 |
| K-14 | Reparos | Reparar +5 HP/ciclo em um muro analisado; integridade 30% HP inicial para classificação intacta; statue HP=floor(1.5*HPbase) quando ativa (A/N) | Dano de estruturas, materiais reais, reparo parcial e escudos de distrito; buff configurável não automático | T1-R3 |
| K-15 | Arqueiros | 1–2 disparos em grupo; 0.4s de preparação cada; espera após tiro 1.2–1.4s; pausa de grupo 0.3s (A/N) | AI combat state máquina, recarga/aim, munição real, habilidade, perigos/altura, ataques formados | T1-R3 |
| K-16 | Mira/projéteis | Varredura 5.5/8.25 u; gravidade 15 u/s²; trajetória balística com discriminante; lead horizontal condicionado; 90% perfect condicionado à estátua (A/N) | Calculador balístico Luau calibrado a studs, hits no servidor, visuais no cliente; não copiar números/accuracy | T1-R3 |
| K-17 | Greed fraco | HP=1; movimento 2/2.8 u/s; reação, seleção alvos e loot reais; uma unidade de loot carregada por inimigo (A/N) | Enemy AI com objetivo por arquétipo, carga roubada e retirada; saque não duplica recurso | T1-R3/T2-R2 |
| K-18 | Ataque inimigo | Target cache x com prioridade de carga/parede/loot, distância estrita; charge velocity inicial (8,2.3) u/s e speed desejada 3; física condicionada (N) | AI com target scoring e colisões do Roblox; ataque por estado, não uma velocity fixa importada | T1-R3/T2-R2 |
| K-19 | Monstros especiais | Tough HP7, Squid HP22, Stealer HP10, Boss HP150, Crusher HP15 em configs; modificadores separados (A) | Catálogo EnemyArchetypes, corrupção, infectantes e bosses ORIGINAIS e únicos do Entre Reinos | T2-R2/T3-R1 |
| K-20 | Loot e coroa | Inimigo rouba objeto real e pode soltá-lo ao morrer; coroa caída vs carregada por inimigo, temporizador condicional de 2.5s se distancia <12u (N) | Sistema de saque/recuperação e game-over próprio; o prólogo e saves não devem seguir crown-loss do Kingdom | T1-R3/T2-R2 |
| K-21 | Moedas no chão | TTL coin 120s no padrão, regras de cooldown/pickup; bag overflow pode cair na água com probabilidade 0.5 em ramo específico; limite físico da bolsa NÃO provado (A/N/U) | VFX local, drop token único servidor e ledger, TTL/limite por balanceamento, água como efeito visual validado | T1-R3 |
| K-22 | Montarias | Cavalo comum 2u/s andar, 3.6 correr, florestas x0.8, alimentado 48s e exaustão 18s; diferenças por tipo e stamina (A/U) | MountRegistry com velocidade, vigor, fome, controle, domesticação e restrições água/ponte | T2-R3 |
| K-23 | Embarcação | Barco com config 0.5/0.7 u/s empurrar/navegar, espaços e etapas separadas de construção/embarque (A/U) | Barco opcional/fast travel entre reinos, estruturas e cargas; nossa geografia é contínua | T2-R3 |
| K-24 | Campanha e decadência | Proteção de decadência ilha 1=20 dias, 2=15, 3–5=10; decaimento distribuído por grupos; perda pode avançar campanha 100 dias (A/N) | Reinos distantes em simulação agregada e persistida, risco controlado e sem decadência injusta de save desconectado | T2-R3 |
| K-25 | Tecnologia/ilhas | Cinco ilhas base e unlocks pedra/ferro por progresso; temáticas/DLCs mudam requisitos (P/O) | Mundo de reinos conectados por terra; progressão medieval de materiais/infraestrutura; futuras eras narrativas só em doc privado | T1-R2/T2-R3 |
| K-26 | UX e coop | Gestão por moeda e ícones mínimos; coop local/online é funcionalidade declarada do jogo original (P/O) | Comandos contextuais e interface de inspeção mais rica; solo no lançamento, rede server-authoritative preparada para futuro | T1-R1/T2-R3 |
| K-27 | Mods/capacidade | Managers e serviços por relógio, reino, pessoas, itens e ambiente; configs por objeto/asset e mod patches (mod docs) | Serviços Luau originais e registries configuráveis, dados desacoplados do visual | Todos |

## O que é CONHECIDO apenas em parte / proibido inventar

- Capacidade física exata da bolsa original; valores 39 (alvo de saque) e 1000 (campo wallet) NÃO equivalem a capacidade da representação.
- Algoritmo completo de geração de mundo (cavernas, geologia, posições de todos os edifícios), toda seleção de portais e boss, pathfinding de todas as classes, netcode de coop.
- Ordem exata de colisão/dano no motor Unity; diferenças entre Unity 2.4.0 e 2.4.2 e DLCs/temas.
- Eficiência real por segundo de arqueiros/carpinteiros em todas as situações e economia total; números A são defaults, N são interpretação, não medições universais.
- Direitos sobre arte/código do Kingdom Two Crowns: NÃO adquiridos por acesso a repositórios de mods/documentação.
- Fórmulas e pesos adotados por nós serão uma decisão de balanceamento ORIGINAL registrada como H e coberta por testes.

## Ordem de leitura por domínio/runner

- T1-R1: docs de fontes, wiki Controls, user experience, Terrain/Save/Camera Roblox e docs internas de Terrain Builder.
- T1-R2: builders-and-buildings, economy-and-currency, Wiki Subjects/Builder/Wall, módulos do repositório sobre assets/qualidade, documentação Roblox DataStore e Humanoid.
- T1-R3: archers-and-arrows, greed-loot-and-crown, time-seasons-and-waves, WIKI Portal/Coin, scripts e diagnósticos Roblox.
- T2-R1: time-seasons-and-waves, wiki Islands/Seasons/Technology, configs de bioma de mods, Terrain Builder e streaming Roblox.
- T2-R2: economy-and-currency, builders/archers/greed, tempo/portais, guia do Steam e limitações de fontes.
- T2-R3: mounts, travel-decay-and-succession, docs de mods/apoio, wiki Map/Decay e DataStores/simulação remota.
- T3-R1/T3-R2: ler estudos de montarias/greed/arqueiros/waves/reinos, verificar DLC/versão específica antes de citar; referências originais de arte com direitos.
- T3-R3: Roblox performance/test-on-hardware/ads/developer-products, segurança e controle de receipts/QA.

## Fontes e atribuição

Repositório de mecânicas: https://github.com/SongZcode/kingdom-two-crowns-mechanics (texto explicativo original CC BY 4.0; aqui há síntese técnica nova e atribuição, sem redistribuição de conteúdo proprietário).
Mods: FredApps/KingdomMod, abevol/KingdomMod, minwoong-seo/K2C-Mods (usados como contexto de descoberta pública).
Wiki: https://kingdomthegame.fandom.com/wiki/Kingdom_Two_Crowns (comunidade O).
Regras oficiais/engenharia Roblox: consulte RESEARCH_SOURCES.md.

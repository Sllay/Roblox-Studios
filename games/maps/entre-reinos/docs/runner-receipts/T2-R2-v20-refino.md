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

## D — Ameaça, combate e prólogo

- Invasores que alcançam a área habitada acionam evacuação. Uma noite tranquila não interrompe o trabalho. Civis preservam os trabalhos e a custódia e buscam abrigo alcançável sem atravessar o inimigo. Defensores armados mantêm posição ou avançam até alcance útil.
- Cada flecha usa o primeiro impacto do segmento entre posições consecutivas. Os seis volumes vêm das partes do rig R6. Terrain, estruturas físicas e muralhas da faixa jogável limitam o impacto.
- Atores da campanha usam grupo de colisão próprio e orientação explícita em cada cena. A hesitação continua no roteiro. Flechas para um arqueiro são entregues perto dele a partir da bolsa real.
- Luau confirmou noite tranquila, evacuação por ameaça, custódia preservada, retomada e interseções 3D. A animação, o contato do jogador com o duque e a flecha contra um rig no cliente seguem para prova Roblox.

## E — Paisagem e streaming

- A revisão de cenário é independente do gerador jogável. O escritor nativo mantém leitura de segurança, escrita e releitura. As três novas fileiras traseiras, a margem frontal e os dois chunks decorativos por extremidade ocupam volumes externos ao envelope dos saves.
- A paisagem usa o relevo e os cursos d'água existentes como referência. As novas cabeceiras sobem em trechos graduais, com cascatas tridimensionais perto da primeira fileira. Uma faixa de água frontal recebe os canais. Vegetação decorativa determinística varia por bioma, inclinação e distância.
- A câmera e o servidor usam o mesmo limite de enquadramento. O servidor prepara terreno à frente com base na velocidade. O cliente solicita streaming adiantado em intervalos limitados. A viagem rápida prepara o destino antes da confirmação.
- Luau comparou amostras jogáveis, extremidades, água frontal, elevação em Z e vegetação em três seeds. As 26 verificações Python específicas passaram. Visibilidade antes da transição, continuidade percebida e custo de renderização dependem de partida real.

## F — Integração

- Os commits `da2763f`, `8a2eda1`, `2a6e86c`, `fca7d22` e `28d39b8` entregam os checkpoints A–E no PR #14. O checkpoint F conecta viagens e embarque às páginas físicas, cobra reservas na hotbar e corrige a fonte aplicada à interface.
- Foram executados validadores de workspace e deploy, compilação Luau, Quality Gate V2, 171 testes Python, build Rojo e suítes Luau de produção, alimentação, mercado, regiões, pontes, combate e terreno.
- O probe de candidato na v20 verifica os voxels antigos antes e depois da expansão, o Terrain nos dois horizontes, água frontal, orientação e colisão do prólogo, volumes R6 e oclusão física. O probe usa sessão descartável e o namespace isolado de DataStore já estabelecido.
- A autorização anterior identificava o SHA `c905eca` e a substituição da v19 pela v20. A publicação deste refinamento depende de autorização específica para o novo candidato, workflow e baseline v20. T2-R3 segue suspensa.

### Evidência em Roblox

O probe da revisão v20 aprovou o candidato `c239c77` em sessão descartável. Comparou 9.216 voxels jogáveis antes e depois de gerar a paisagem. Confirmou água nativa na faixa frontal, relevo elevado, barreiras nas duas extremidades, 11 partes do duque sem colisão com o grupo do jogador, orientação dos guardas durante a hesitação, acerto em cabeça e torso R6 e bloqueio por uma parede física. O DataStore real isolado aprovou seis slots distintos, backup, restauração, tentativa repetida sem duplicação e migração 4 → 5 com trabalho regional preservado. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45731778502) · [Probe](https://github.com/Sllay/Roblox-Studios/actions/runs/45731768610)

Na seed 516639272, a preparação adicional ao nascer levou 666 ms no servidor, com 38 volumes de cenário e 437.760 voxels adicionais. O maior tempo por volume adicional foi 6,9 ms na região inicial e 7,4 ms após visitar ambas as extremidades. A simulação Luau local de dois reinos por 2.400 s levou 4,62–4,86 s no código da v20 e 4,68–4,82 s no candidato após otimização. Os intervalos se sobrepõem. Memória de cliente, frame pacing, tráfego e fluidez touch exigem sessão real. [Creator Hub sobre streaming](https://create.roblox.com/docs/workspace/streaming) · [Desempenho](https://create.roblox.com/docs/performance-optimization/improve)

### Roteiro para a próxima revisão de staging

1. Em tela pequena, abra um slot existente. Role e solte a barra superior enquanto o estoque muda. Confira rótulos, posição, joystick e salto. Equipe espada e arco e teste pressionar, soltar e cancelar.
2. Interaja com castelo, galpão, carpintaria, ferraria, fazenda e doca. Confirme o catálogo de cada estrutura. No caderno, longe do morador, solicite uma lança e observe a reserva, a caminhada ao estoque e a entrega. Veja se outros moradores conseguem usar o mesmo depósito.
3. No prólogo, caminhe junto ao duque, confira a hesitação dos guardas e atire na cabeça e no corpo de um invasor. Na invasão, observe os civis abandonarem a área de risco e depois retomarem o trabalho. Compare com uma noite tranquila.
4. Monte e acelere até uma fronteira. Confira rio frontal, cascatas, fundo e continuidade do terreno na câmera larga. Embarque e teste carga na doca. Salve e reabra para conferir posição, equipamento e estoques.

### Candidato e restauração

O candidato `c4fb0790c14cd7c42cead0ae17e8f013b36fab1c` atualiza a apresentação dos moradores por eventos de replicação e repete as provas do motor. CI e Roblox passaram. A preparação adicional da seed de referência levou 666 ms, com pico de 12,8 ms por volume. A medição de outro servidor registrou o mesmo tempo total, com pico de 6,9 ms na região inicial. [CI do candidato](https://github.com/Sllay/Roblox-Studios/actions/runs/45732024313) · [Roblox](https://github.com/Sllay/Roblox-Studios/actions/runs/45732016659)

O Scene Sync em leitura confirmou v20, 101 objetos e zero conflitos. O digest `ac7bccae902771c3e1c250886119741a0e2033772e74b650476ebda57e0c726c` coincide com o readback da publicação anterior. O build separado de `c905eca` reproduziu exatamente o artefato da v20, SHA-256 `63d2ffe7261cb815dfe514a0ad9498e4259bf8364410c87db50708954a0e470f`. A futura publicação deve arquivar esse rollback, conferir novamente o baseline e manter o ruleset 5. [Scene Sync v20](https://github.com/Sllay/Roblox-Studios/actions/runs/45732024958) · [Publicação original da v20](https://github.com/Sllay/Roblox-Studios/actions/runs/45723383249)

### Publicação da v21 em 26/11/2026

O workflow oficial publicou o SHA aprovado `c4fb0790c14cd7c42cead0ae17e8f013b36fab1c` somente no staging `10769712413/90623742498445`. A API confirmou v21 às 02:22 UTC e o readback independente comparou 50 scripts com os hashes do build. O Scene Sync posterior confirmou 106 objetos, zero conflitos e digest `b8d6d7db0c1813d29431cdf6f93505a8786d3473607d5b73e13f963751b1b5e6`. [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/45741909503) · [Readback](https://github.com/Sllay/Roblox-Studios/actions/runs/45741909503/job/139648702946) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45742069302)

O RBXLX da v20 foi arquivado antes da escrita e comparado com o inventário histórico de 45 scripts. A atualização do Place preserva o ruleset 5 e os seis slots. T2-R3 aguarda o feedback do criador. [Rollback da v20](https://github.com/Sllay/Roblox-Studios/actions/runs/45741909503/artifacts/15081372944) · [Evidências](https://github.com/Sllay/Roblox-Studios/actions/runs/45741909503/artifacts/15081107686) · [Playtest](https://www.roblox.com/games/90623742498445)

### Correção do rio e das pontes · 27/11/2026

O relato referiu-se à v20. O inventário e o Open Cloud identificaram **v21** como revisão ativa. A correção parte desse código. O PR #14 segue em rascunho e a T2-R3 aguarda o playtest.

**Causa da água.** O cenário traseiro alternava bruscamente entre a elevação do rio e a do morro quando `waterSurface` mudava de presente para ausente. Na seed 516639272, essa troca produziu um degrau de 44,3 studs em 0,25 stud na margem. Planos de vidro segmentados das cascatas também recobriam a água nativa e criavam junções próprias. Os perfis agora compartilham leito, nível e seção da margem. A faixa frontal converge para o mesmo nível em todos os chunks e a superfície é gerada pelo Terrain nativo.

**Causa do encaixe.** A busca exigia que a mira já estivesse no intervalo entre os dois apoios. O probe anterior à correção reproduziu `missing_crossing` a dois studs de todos os seis apoios secos testados. A confirmação também guardava a coordenada bruta da mira enquanto a prévia mostrava o centro. Agora o snap pode começar na aproximação seca dentro do alcance de construção. A prévia e a confirmação usam o mesmo cruzamento. A confirmação verifica as margens em toda a largura do tabuleiro e o espaço físico da travessia. O modelo da ponte provisória existente é isento durante seu reforço. [Reprodução no motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45929927177)

**Validação.** Passaram os testes Luau de perfil em quatro seeds, rotas em sete seeds com 2.048 vãos externos, construção e travessia regional, Quality Gate V2, 171 testes Python, build Rojo e CI. No motor Roblox, o candidato verificou 85 colunas nativas de água, oito junções, seis apoios, a separação entre objeto decorativo e obstáculo colidível e a construção das duas categorias de ponte. A prova confirmou o tabuleiro físico reforçado e a rota montada. O probe também verificou 9.216 voxels da faixa jogável invariáveis durante a geração do cenário, os chunks decorativos, a reabertura da ponte com seu identificador original e a migração 4 → 5 em DataStore isolado. A aparência da água e os controles de prévia permanecem para ensaio no cliente. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45930483702) · [Prova Roblox](https://github.com/Sllay/Roblox-Studios/actions/runs/45930476816)

**Arquivos.** A geração mudou em `SceneryProfile.luau`, `RegionalProfile.luau`, `WorldProfile.luau` e `WorldService.luau`. O encaixe usa `RegionalCrossings.luau`, `StructureDefs.luau`, `WorkEngine.luau`, `BridgeScene.luau`, `LivingService.luau` e `BuildMenu.luau`. Os testes usam o workflow de probe existente. Os commits de diagnóstico e correção são `ca996fa` e `b712a6f`. O staging segue na v21 até autorização específica para publicar o candidato.

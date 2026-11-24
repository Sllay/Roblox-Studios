# Arquitetura técnica — Between Kingdoms

Estado: T1-R1 EM IMPLEMENTAÇÃO; módulos reais de mundo, câmera, controle, slots e UI implementados em Git. Runtime Roblox não validado.

## Base existente

Preservar o projeto Rojo criado a partir de `games/maps/_template/` e pipeline do monorepositório. Código deste jogo somente em `game/places/main/src/`; serviços compartilhados estáveis em `packages/`. Staging e production são Universes/Places diferentes.

## Topologia

`WorldSeed → WorldGraph(Reinos, Corredores, Distritos, Portais) → RegionState → RegionStreaming`.

- Movimento lógico no plano X/Y (X=lateral, Y=altura/natação vertical); Z fixo para personagens durante gameplay, reservado a profundidade de mundo 3D e elementos visuais. Sem parallax 2D. Fundo distante 3D, fundo próximo 3D interativo e primeiro plano 3D.
- Terrain nativo gerado determinística e incrementalmente por regiões. Relevo transitável validado, alturas coerentes, faixa navegável/terra com colisão controlada.
- `WallRing` possui lado, grau de proteção, distrito interno/externo e conexões. Trilhos de NPCs e gates formam grafo local, sem pathfinding genérico 3D para cada agente.
- LOD: full NPC simulation perto; simulação agregada por distrito/reino ao longe; snapshots determinísticos para descarregar/carregar.

## Domínios de servidor planejados

`WorldService`, `DistrictService`, `WallService`, `ResourceLedger`, `InventoryService`, `JobBoard`, `NPCScheduler`, `CombatService`, `InfectionService`, `RaidDirector`, `DiplomacyService`, `TimeService`, `SaveSlotService`, `TransactionService`.

Implementação por necessidade do vertical slice, sem criar serviços vazios de enfeite. Cada domínio publica eventos tipados/identificadores estáveis; nenhum depende de Instances para persistência.

## NPC scheduler

Utility para selecionar tarefa de maior prioridade (sobrevivência → defesa/evacuação → ordens → entregas → trabalho → descanso); FSM para executar. Jobs com reserva e idempotência para não duplicar recursos. Inventário local, tarefas de construção com materiais e timers, path em nós de corredor. Orçamento de IA por frame e atualização com frequência variável segundo LOD.

## Depósitos e transações

`ResourceLedger` é fonte de verdade. Movimentação `available → reserved → in_transit → delivered/consumed` com transações idempotentes.

Ao quebrar armazém: interromper novas reservas; separar estoques em `salvageable`, `destroyed` e `stolen` (percentuais configuráveis); criar `SalvageSite` lógico que pode ser limpo por NPCs depois da raid. Reconstruir não cria estoque novo.

Economia monetária separada do item físico renderizado. Servidor verifica saldo/distância/custo/condição e emite eventos visuais locais de moedas com pooling; câmera nunca decide contabilidade.

## Incursões e reinos

`Portal`: worldRegion, stage, corruptionPressure, cooldown, neighboringKingdoms, lastRaids. `RaidDirector` escolhe intenção e orçamento por região e distribui pressão entre dois reinos segundo distância, exposição, defesas e atividade. Não garantir simultaneidade nem divisão fixa. Simular danos/defesa de vizinhos distantes por eventos agregados validados e determinísticos.

## Save

DataStoreService apenas servidor. Um índice de até 6 slots por usuário mais documentos de slots independentes, com `schemaVersion`, `seed`, `worldClock`, `regions`, `districts`, `npcRecords`, `ledgers`, `raidState`, `storyFlags`, `checksum`. Limites de tamanho/requisição devem ser medidos antes da escolha do shard. Usar `UpdateAsync`, locks de sessão com expiração, backups/migrações e recuperação em erro sem sobrescrever dados mais novos. "Solo" significa servidor privado da experiência, não jogo verdadeiramente offline.

## Visuais e avatares

R6, roupas/cabelos coerentes e originais ou autorizados. `HumanoidDescription` para aplicar roupas compatíveis; estudar `AvatarEditorService:SearchCatalogAsync` e Marketplace API para descoberta, com pipeline de curadoria por filtros de tipo R6, autorização, moderação e cache de IDs aprovados. Não fazer chamadas ilimitadas ao catálogo nem interpretar resultado aleatório como licença ou compatibilidade. Assets existentes do Black Island compartilhados por referência a catálogo versionado, sem alterar arquivos-fonte desse jogo.

## Testes/observabilidade

- Testes puros: distribuição de raids, transações de inventário idempotentes, custo de construção, perdas/salvage, geração seeded, slot indices e migrations.
- Simulações sem render: 100+ dias, economia infinita/negativa, NPC órfão, ataque que nunca termina, deadlock na cadeia de jobs.
- Testes reais no Studio: camera X/Z, colisões R6/Terrain, quedas de muralha, NPC evacuação, render de moedas, save/load, streaming e 3G/mobile FPS.
- Gate: `tools/workspace.py validate`, `tools/script_quality.py`, unittest e Rojo build; CI verde não prova jogabilidade.

## Contratos V0.2 — movimento/camadas 3D

`LaneController`: permitir movimento ao longo de X e Y com física natural, restringir deslocamento em Z sem teletransportar o Humanoid a cada frame. Entradas terra: X move; input vertical só orienta avatar em Yaw para fundo/frente, mantendo coordenada Z. Entradas natação: X horizontal e Y vertical; diagonal normalizada. Máquina de transição de estados Grounded/Jumping/Falling/Swimming/ExitingWater e blend de animação; evitar alternância rápida devido a water voxels marginais. Prototipar controlador e físicas Roblox antes de escolher constraints finais.

`WorldDepthLayers`: distantes decorativos, próximos interativos com `WorkAnchor` acessível via corredor principal, personagens num plano lógico, primeiro plano decorativo preto. WorkAnchor conhece recurso/posição/alcance, sem caminhar Z. Visual de árvore pode ser volumétrico atrás do trilho, mas raio de trabalho liga ao corredor. Nada de invisibilidade de objeto servidor ao descarregar visual, nem silhueta cobrir elementos clicáveis.

`WaterRouteGraph`: superfícies de água com limites, zonas rasas, pontos de ponte (duas margens), permissões per agent type (`CanSwim`, `CanWade`, `CanUseLightBridge`, `CanUseStrongBridge`), correnteza opcional e custo de travessia. A cachoeira visual não implica fluxo de Terrain nativo; separar visual waterfall de volume nadável e validar colisão/gravidade.

## Contratos V0.2 — obras e economia

`PlacementValidator` (servidor) usa footprint contínuo e volumes ocupados, escala de terreno, slopes, distâncias e regras `BuildRequirement` (incluindo acesso à água e conexão entre margens). Blueprint possui id estável e estado `MaterialDelivery | Labor | Complete | Damaged | Cancelled`.

`ConstructionSite` contém `required[resource]`, `delivered[resource]`, `workRequired`, `workDone`, `baseWorkRequired`, `usedAdVouchers`, `paymentState`, `version`. Entrega `NPCInventory → site.delivered` sob uma transação atômica com idempotencyKey; NPC com material já carregado pode entregar sem passar por depósito. No momento da transferência, material muda de custódia e nunca é duplicado. `Labor` só começa após requisitos completos; progresso em unidades lógicas acumuladas, não multiplicando cronômetro em andamento. Salvar/restaurar trabalho parcial, estado do NPC, estoque e reserva.

`Professions` inicial: carpinteiro madeira 3x/pedra 1x; minerador pedra 3x/madeira 1x; construtor qualquer 2x; genérico 1x. `workRate = baseRate * professionMultiplier * skillFactor * toolFactor * staminaFactor / complexityFactor` (fatores balanceáveis e limitados). Massa por item e peso total no inventário do NPC; ferramentas e armaduras são slots de equipamento. Emprego por agendamento e prioridade.

`MonetizationService` (posterior): contratos de recompensas não são `os.time()` arbitrário nem diretos do client. Anúncio `AdService` somente quando elegível, disponível, com consentimento e recompensa Developer Product; `MarketplaceService.ProcessReceipt` com deduplicação persistente. Voucher `WorkCredit` resgata uma fração fixa de `baseWorkRequired`, limitando a `remainingWork` e no máximo três vouchers por site. Vouchers só podem ser aplicados no site/conta pretendida e nenhuma falha pode sumir com o que foi comprado. Para Robux, `FinishSite` finaliza trabalho, não inventa materiais sem um produto explícito `FinishAndSupply`; reembolsos tratados como concessão auditada separada sem duplicar saldo de obra. Segurança anti-exploit e limites de uso validados no servidor.

`FutureLore`: segredos narrativos tardios registrados somente em documentação privada, não publicados. Corrupção entre cidadãos do reino desligada no início, prólogo possui apenas duque infectado; sistema de surto interno progressivo e sinalizado será módulo posterior.

Fontes técnicas: https://create.roblox.com/docs/reference/engine/classes/Humanoid ; https://create.roblox.com/docs/reference/engine/classes/Terrain ; https://create.roblox.com/docs/reference/engine/classes/AdService ; https://create.roblox.com/docs/production/monetization/developer-products .

## Modularidade para nove runners (V0.4)

O novo contrato de entrega esta em docs/SEASON_RUNNERS.md; protocolo em docs/RUNNER_PROTOCOL.md, estados em docs/RUNNER_STATUS.json. Os dominios serao implementados somente quando seus runners forem executados, mas schemas, interface de rede e formatos de persistencia precisam manter compatibilidade futura.
Configurar biomas, itens, profissoes, receitas, estruturas, muros, monstros, montarias, portais e padroes de raids por registries declarativos/versionados, evitando duplicacao de scripts por instancia. Manter logica do jogo no servidor, visuais no cliente e dados serializaveis sem depender da existencia de Instances carregadas. Priorizar codigo modular funcional, nao frameworks abstratos vazios. Migrations/testes de compatibilidade a cada alteracao de schema.
Nenhum runner pode ser marcado validado sem checks reais, commit correto e receipt; nenhum staging sem identity verification, workflow oficial e Scene Sync quando aplicavel.

## Revisao V2 — arquitetura baseada em pesquisa rastreavel

A partir de 21/11/2026 a ordem de implementação e T1 FUNDAÇÃO, T2 FINALIZAÇÃO de TODOS os sistemas centrais e T3 CONTEUDO/POLIMENTO (docs/SEASON_RUNNERS.md V2). Contratos próprios documentados em docs/research/ROBLOX_ADAPTATION.md: mundo por seed, work anchors 3D, Lane/Swim controller, ledgers transacionais, job scheduler utility/FSM, build progress em work units, projeteis balisticos X/Y, portal director por orcamento/pressao e reinos NPCs agregados.

Distinguir algoritmos ORIGINAIS (H) de configuracoes/analise estatica de Kingdom (A/N), ver docs/research/RESEARCH_SOURCES.md e MECHANICS_AUDIT.md. Nenhuma licença de mod autoriza copiar recursos do Kingdom. Serviços novos apenas em runner de escopo correspondente. T3 expande conteudo por registry e nao reescreve fundamentos, corrige bugs e otimiza após testes reais.

## Implementação real T1-R1 — 21/11/2026 (em andamento)

- `ReplicatedStorage/WorldProfile.luau`: geração por seed determinística, domínio x[-128,128], y[-32,64], z[-48,48], rio e margens, centro de assentamento plano. O gerador versão 1 não admite overwrites silenciosos de regiões povoadas.
- `ReplicatedStorage/SlotModel.luau`: contrato versionado e chave por UserId + slot 1..6.
- `ServerScriptService/Services/WorldService.luau`: leitura de preflight para detectar terreno nativo, escrita de canais SolidMaterial/SolidOccupancy/LiquidOccupancy (4 studs), readback e decoração 3D com WorkAnchors; falha fechada diante de Terrain existente.
- `ServerScriptService/Services/SaveSlotService.luau`: DataStore UpdateAsync, aquisição/expiração e refresh de lease, verificação de revisão/lastWriteId, upsert, leitura e tombstones; local de spawn não é gravado como progresso quando Terrain falha.
- `ServerScriptService/Boot.server.luau`: remotes autorizados, XY PlaneConstraint, spawn quando mundo ativo, servidores solo, exigência de Avatar R6, autosave e BindToClose.
- `StarterPlayer/StarterPlayerScripts/LaneController.luau`: input mobile/teclado/controle, Humanoid Move X, AlignOrientation para rotação, LinearVelocity XY em Swimming; não teleporta root a cada frame.
- `SideCamera.luau`, `SlotMenu.luau`, `ClientBoot.client.luau`: câmera 3D, UI criar/entrar/excluir e opções; métricas de cliente.
- `game/tests/region_and_slots.luau`: assertions Luau de seed, rio, chaves de slot e schema. Integradas ao quality_gate_v2.py em CI.
- Requisitos pendentes de validação no Roblox real: física do PlaneConstraint e nado R6, compatibilidade de Avatar Settings, readback Terrain, DataStore e FPS real de dispositivos móveis.
- STATUS: não declarar T1-R1 validado antes de confirmar runtime/mobile e corrigir eventuais erros. Escopo T1-R2 ainda não iniciado.

## T1-R1 — atualização do checkpoint validado em CI, sem runtime

Commit `ce50d163e8978623fa944da27b4b41cc6e58c072`, CI https://github.com/Sllay/Roblox-Studios/actions/runs/44965276453 passou no escopo automatizado. Novo arquivo `ReplicatedStorage/SlotLeasePolicy.luau` formaliza expiração e decisões de `UpdateAsync` idempotentes testadas no Luau VM. `WorldService` está realmente em `ServerScriptService/Services/` (bug de path duplicado corrigido). Post-write do Terrain verifica `SolidMaterial`, `SolidOccupancy` e `LiquidOccupancy`; bordas físicas limitam a primeira região e foreground preto evita a zona central.

A revisão de comportamento físico (R6, PlaneConstraint, Swimming), carga/durabilidade DataStore no Roblox real e desempenho mobile permanecem obrigatórios. Não concluir runner nem liberar T1-R2 com base em build.

## Estado v6 — separação lobby / instância de mundo

No mesmo Place em staging, a função de servidor é decidida por `WorldRoute.isWorldServer(game.PrivateServerId, game.PrivateServerOwnerId)`. Lobby público apenas opera a listagem/criação (sem lease) e envia `TeleportService:TeleportAsync` com `TeleportOptions.ReservedServerId` criado no servidor. Cada mundo abre em um servidor Roblox **reservado e isolado**, exclusivo do jogador nesta fase. JoinData/TeleportData é apenas um ticket e nunca a fonte de seed/posição: record completo vem do DataStore por `Player.UserId`.

Ao chegar, autenticar roteamento, criar R6, abrir save com `UpdateAsync` e lease, gerar chunks nativos 2,3,4, exibir UI opaca progressiva e iniciar simulação só após terreno/corpo prontos. O chunk1 oeste usa `World.ensureNear` enquanto o usuário se desloca; cada chunk possui readback de sólido/líquido/material, evita sobrescrever Terrain. Voltar ao lobby com `TeleportOptions.ForcePublicServer`.

Os testes automáticos e o Roblox Luau edit session passaram, v6 publicada, mas teleport e gameplay reais aguardam teste mobile. `Players.MaxPlayers=1` já observado no Place, sem mutação de configurações. Não levar essa arquitetura para o Black Island.

## T1-F1 — contratos candidatos de save, custódia e colocação

`WorkEngine` calcula reservas de oferta a partir dos trabalhos serializados e reconcilia a demanda da obra ao reabrir. Um trabalho de retirada em `gather` pode referenciar uma fonte natural por `siteId` ou galpão por `storageId`; depois da retirada, o estado `deliver` é sustentado pela bolsa. Entrega ao galpão reserva massa até o depósito. A destruição separa `ruinedStock` do inventário utilizável. A partição de recuperação continua uma decisão de design. Transações de economia e obras usam as mesmas consultas de disponibilidade.

O cliente pede prévia para o X escolhido. O servidor guarda a prévia mais recente, amarra confirmação ao ID e verifica novamente as regras de faixa, posição relativa, previsão do terreno e apoio nativo antes de materializar a obra. O jogador pode liberar o terreno até a entrega do primeiro material. Castelos de campanhas recém-inicializadas vinculam a tesouraria ao comércio local. O servidor usa o ponto histórico de comércio para campanhas anteriores sem castelo.

O ruleset 2 protege a gravação de estados que o runtime v15 não interpreta. Mantém as seis chaves e o formato 1. O backup pré-promoção é gravado separadamente com identidade da geração e revisão do slot, e a promoção falha se o backup não for confirmado. A recuperação operacional precisa de teste em DataStore de staging antes de publicação.

No candidato de playtest, a ocupação inclui sólidos consultáveis no terreno real. As duas muralhas iniciais guardam as fronteiras geográficas dos distritos para a consulta do servidor. O cancelamento de obra em andamento conserva os materiais já entregues como fontes de recuperação no terreno. A inserção é condicionada ao cap de fontes e executada no mesmo passo que libera trabalhos e remove a obra.

No ruleset 3, `Campaign` guarda o estado discreto da história e as posições dos atores, independente da apresentação. `Trajectory` computa a primeira interseção em segmentos curtos, com o Terrain limitado pelo raycast real. `R3Engine` é dono de dano, munição, tarefas suspensas e recuperação. `NPCPresentation` usa amostras de posição e juntas locais. A taxa de trabalho permanece em 10 Hz. População morta fica persistida com seu inventário isolado e sem tarefas.

## T1-F4/F5/F6 — posição, combate e streaming

`WorkEngine` integra X/Z com desvio local limitado e mantém a posição antiga em X ao migrar moradores. Apenas os NPCs ganham liberdade no plano X/Z. `NPCPresentation` interpola o estado replicado e usa faixas do Animator R6. `CombatService` é dono da arma, da janela de carga, do consumo, da trajetória e do dano. `Ballistics` fornece parâmetros compartilhados de previsão ao cliente. `R3HUD` aciona a mesma interação contextual em touch, mouse e controle.

`WorldProfile` define 17 chunks de 64 studs e preserva a função do terreno antigo nessa região. `WorldService` escreve Terrain nativo ao iniciar e sob demanda. Os voxels já escritos permanecem no servidor. O Workspace faz streaming para o cliente, com residência mínima configurada em 64 studs e raio alvo de 160. O snapshot mantém a posição legada e um campo aditivo `frontierPosition` vinculado à revisão do save. Um ponto externo só é usado na revisão corrente, com geração ao redor da posição antes do spawn. Os seis slots, o formato e o ruleset 3 permanecem.

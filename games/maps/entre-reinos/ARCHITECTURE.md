# Arquitetura técnica — Between Kingdoms

Estado: proposta; sem módulos de gameplay implementados.

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

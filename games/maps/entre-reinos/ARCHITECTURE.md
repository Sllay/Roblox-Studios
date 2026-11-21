# Arquitetura técnica — Between Kingdoms

Estado: proposta; sem módulos de gameplay implementados.

## Base existente

Preservar o projeto Rojo criado a partir de `games/maps/_template/` e pipeline do monorepositório. Código deste jogo somente em `game/places/main/src/`; serviços compartilhados estáveis em `packages/`. Staging e production são Universes/Places diferentes.

## Topologia

`WorldSeed → WorldGraph(Reinos, Corredores, Distritos, Portais) → RegionState → RegionStreaming`.

- Coordenadas lógicas de jogabilidade X/Y; trilho e pequena largura Z quando explicitamente permitidos; cenário com parallax/água/silhuetas livres em Z.
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

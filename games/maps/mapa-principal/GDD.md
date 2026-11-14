# GDD — mapa-principal

**Status:** rascunho, aguardando definição de gameplay e título definitivo.

## Plataforma
Roblox; suporte mobile obrigatório.

## Loop principal
Ainda não especificado. Não inventar objetivos, progressão, combate, moeda ou mecânicas.

## Conteúdo criado
Cenário inicial minimalista com plataforma e SpawnLocation, inicialização server/client e módulo compartilhado de versão.

## Próximas definições
Gênero, interface, controles, progressão, persistência, multiplayer, limitações de desempenho e critérios de aceitação.

## S09.5 — gameplay contracts confirmed by owner (2026-11-14)
Black Islands: Book discovery/completion across creatures, items, missions. Creature catalog is authoritative; automatic pages, 2D previews, alphabetical/discovery ordering, level 1/10 comparison, developer-only ID presentation. Permanent random six-digit species IDs; four-digit future item IDs. Natural interactions/kills unlock species once. Vale Esmeralda is the existing initial biome, nine chunks. Reusable Mob Core with passive prey, predators, melee/ranged NPC capability profiles; chicken first. Developer summon command with species/count/position/AI flag. Levels disabled initially, mobile population/simulation budgets mandatory. Detailed contracts: docs/s09/CREATURE_FRAMEWORK.md. Balance, observation rules, UI, and runtime deployment still pending.

## Owner-approved natural chicken population
15 maximum natural chickens across the current nine playable chunks of Vale Esmeralda, grass-only valid terrain; initial fill up to 15, then exactly one replacement per 300 seconds while below cap, timer resets after successful birth. Biome provider enables future expansion without species-specific spawn coordinates. Current developer summons share total cap 15 and cannot earn Book discovery. Book and combat foundations B–F implemented and isolated-verified, not live-published; final balance/client performance pending.

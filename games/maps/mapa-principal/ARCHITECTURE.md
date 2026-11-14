# Arquitetura — mapa-principal

## Estado inicial
Um Place `main`, compilado com Rojo 7 no GitHub Actions. Sem gameplay especificado ainda.

## Mapeamento de serviços
- `ReplicatedStorage.Game.Config`: ModuleScript com parâmetros públicos.
- `ReplicatedStorage.PlatformShared.Version`: módulo comum, gerenciado por `packages/`.
- `ServerScriptService.Boot`: Script de bootstrap autoritativo.
- `StarterPlayer.StarterPlayerScripts.ClientBoot`: LocalScript de bootstrap do cliente.
- `Workspace.StartArea`: Model declarativo com Floor e SpawnLocation.

## Limites
Não existem sistemas de inventário, persistência, combate, economia, UI ou remotes nesta versão. Não assumir funcionalidades que não estejam no GDD. Mobile é alvo, mas desempenho real ainda não foi medido.

## Deploy
`deploy.targets.json` tem os números fornecidos pelo usuário em `production` sem verificação cruzada. `staging` fica nulo até existir um Place de teste separado. Build é diferente de publicação.

## S09.5 source-only creature foundation
`ServerScriptService.CreatureFramework` contains pure typed modules CreatureRegistry, BookCore, MobBrain, SimulationBudget, SummonPlan, AIKernel, EscapePlanner. No auto-running scripts, no remotes or live DataStore mutations. Registry is server authoritative, Book projection comes from it, state and BT memory are per agent. Native chicken model/animations and static 2D preview are linked. See docs/s09/CREATURE_FRAMEWORK.md; integration and mobile validation pending. Staging V25 remains untouched.

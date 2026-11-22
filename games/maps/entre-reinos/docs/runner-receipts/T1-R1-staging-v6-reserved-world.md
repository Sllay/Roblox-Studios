# Entre Reinos T1-R1 — staging v6: lobby + mundo em servidor reservado

**Data:** 2026-11-22 — **status do runner:** `in_progress`; publicação de preview confirmada, aceite mobile pendente.

## Incidente corrigido

Console Roblox do criador (v5) confirmou `ServerScriptService.Boot:101: attempt to index nil with 'seed'`. O código anterior usava expressão condicional com dois retornos de função; Luau descartava o segundo, o registro do mundo era `nil` e `record.seed` quebrava. O Mundo 1 foi preservado com seed **516639272**. O novo fluxo usa ramos separados para obter `ok, record` e valida o registro antes do teleporte.

## Novo fluxo de execução
1. Jogador entra no **lobby público**, com menu visual totalmente opaco; nenhum Terrain nem save de partida ficam ativos neste servidor.
2. Ao clicar **Criar**, `Saves.createDetached` cria registro durável **sem lease**; ao clicar **Entrar**, `Saves.inspect` confere o mundo salvo do próprio `UserId`. Nenhum slot é recriado no caminho Entrar.
3. O **servidor Roblox** gera GUID exclusivo, passa como `TeleportOptions.ReservedServerId`, usa `TeleportAsync` para o **mesmo Place** e envia apenas ticket (slot/userId/protocolo/reservedId). Teleporte não é controlado pelo cliente.
4. No servidor reservado, `WorldRoute.validArrival` valida ticket/usuário/Place/server ID; `CharacterService` cria R6 real e `Saves.open` adquire o lock independente via `UpdateAsync`.
5. `World.activate` gera inicialmente chunks **2, 3 e 4** (64 studs cada), incluindo rio, com sinais reais de progresso; `WorldLoadingUI` opaco mostra as etapas e libera câmera/controles somente após `ER_WorldLoaded=true`.
6. Ao andar à esquerda, `World.ensureNear` gera o chunk **1** em segundo plano ao aproximar de X=-24. A saída para lobby usa `ForcePublicServer`. Um único Player é permitido por servidor, com contratos preparados para ampliar a capacidade futuramente.

## Evidências reais

- **CI código:** https://github.com/Sllay/Roblox-Studios/actions/runs/45030168933 — concluído com sucesso, 155 testes Python, Quality Gate Luau e Rojo `entre-reinos/main.rbxlx`.
- **Publicação no Roblox:** https://github.com/Sllay/Roblox-Studios/actions/runs/45030363476 — `SUCCESS: Place 90623742498445, revision 6`.
- **Leitura independente e teste no engine edit session:** https://github.com/Sllay/Roblox-Studios/actions/runs/45030586488 — `loadedVersion=6`, 17 checks de fonte/objetos PASS, `ReservedServerId` suportado, seed 516639272 gerou 3 regiões iniciais + água nativa (596 células), depois quarta região adicionada (4/4) ao simular jogador próximo. `Players.MaxPlayers=1` observado no Place.
- **Limites de prova:** Luau Execution opera em sessão edit não persistida sem um jogador real. Não confirma o sucesso de `TeleportAsync` entre servidores, R6 real na partida, GUI no celular, FPS e persistência pós-reconexão. Manter o runner aberto até esses testes.
- **Escopo:** somente Entre Reinos staging. `production` com IDs nulos e Black Island não alterado.

## Testes prioritários de aceitação do criador

1. Fechar servidor v5 e abrir novo do Place; conferir título com **v6** e fundo opaco, sem mapa 3D visível através da UI.
2. `Jogar -> Mundo 1 (seed 516639272) -> Entrar`. A cortina de teleporte aparece, depois o Roblox entra em **outro servidor reservado**, e a UI mostra progresso de geração de regiões. Não excluir nem criar Mundo 1 novamente.
3. Quando o progresso terminar, avatar R6 deve surgir sobre Terrain, com câmera lateral e controles. A partida ainda é solo. Testar esquerda/direita, rotação em solo, pulo, rio/natação vertical e diagonal, FPS.
4. Sair completamente; voltar ao lobby e abrir o mesmo Mundo 1, preservar seed e posição. Abrir outro mundo só se o primeiro tiver funcionado.
5. Em caso de erro, enviar a tela do loader com código, console quando possível; não apagar os saves.

**Não iniciar T1-R2 nem marcar validated sem esse retorno.**

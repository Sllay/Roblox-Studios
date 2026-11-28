# ENTRE REINOS — HANDOFF ENTRE MODELOS, AGENTES E RUNNERS

Versão 1.0 — 21/11/2026. PRINCIPAL PONTO DE RETOMADA DE QUALQUER CONVERSA.
Este arquivo não substitui os requisitos completos; funciona como ordem determinística de leitura e execução, com fontes e status verificável. O projeto pertence ao monorepositório Sllay/Roblox-Studios, diretório games/maps/entre-reinos. A existência de pesquisa/documentos NÃO significa runner implementado.

## 0. Estado base nesta data
- Novo jogo: Entre Reinos (inglês provisório Between Kingdoms), solo medieval, cenário 100% 3D com câmera lateral e NPCs ricos.
- Plano V2 oficial (SUBSTITUI V1): T1 Fundação, T2 Finalização dos sistemas centrais, T3 Conteúdo/Variedade/Polimento. 3 runners em cada, ordem estrita.
- T1-R1 até T3-R3: PLANNED. Nenhum sistema de gameplay implementado neste ciclo de pesquisa.
- Dois IDs recebidos do usuário para novo Roblox: 10769712413 e 90623742498445, interpretação Universe/Place apenas PROVISÓRIA; conferir docs/ROBLOX_IDS_PENDING.md e não publicar em ID não verificado.
- Ideias e decisões: GDD.md e docs/VISION_MASTER.md. Histórico docs/DECISION_LOG.md. Lore tardia confidencial NÃO deve ser exposta no repo público.
- Nenhum runner recebe marca VERDE somente porque foram redigidos documentos, planos, pseudocódigo ou CI de documentação.
- Estágio atual: pesquisa inicial registrada, replanejamento documental. O próximo trabalho de implementação inicia em T1-R1 quando seus pré-requisitos forem atendidos.

## 1. Sequência obrigatória de leitura após troca de modelo

1. Verificar branch main HEAD atual e arquivos AGENTS.md global e games/maps/entre-reinos/AGENTS.md. Nunca confiar em SHA antigo para estado atual.
2. Ler este handoff por inteiro.
3. Ler docs/VISION_MASTER.md (decisões FIXADO/PROPOSTA/FUTURO/ABERTO), depois docs/DECISION_LOG.md (última instrução prevalece sobre proposta antiga).
4. Ler GDD.md, ARCHITECTURE.md, game.manifest.json e deploy.targets.json; conferir estado do Place e ferramentas, sem presumir publicação.
5. Ler docs/SEASON_RUNNERS.md: procurar etapa com menor número ainda não validada dentro da temporada aprovada, respeitando T1→T2→T3 e R1→R2→R3.
6. Ler docs/RUNNER_STATUS.json: cada runner guarda estado, SHA de implementação, CI, recibo e validações. Não alterar histórico sem evidência; se houve commit concorrente, conferir HEAD e reconciliar.
7. Ler docs/RUNNER_PROTOCOL.md: critérios, testes, publicação staging e refinamentos.
8. Ler docs/research/RESEARCH_SOURCES.md e docs/research/MECHANICS_AUDIT.md. Abrir fontes exatas do runner atual e conferir versão, qualidade e ressalvas.
9. Ler docs/research/ROBLOX_ADAPTATION.md para contratos/algoritmos originais e docs/research/RESEARCH_GAPS.md para o que NÃO foi comprovado.
10. Ler documentação interna referenciada para o domínio (Terrain Builder, Scene Sync, Deployment, QualityGate, asset-library) e usar as ferramentas reais existentes, sem reinventar código nem publicar Place inteiro por acidente.
11. Abrir receipt do último runner validado e branch/PR relevantes. Se não existe, não inventar progresso; começar pelo escopo planejado do próximo runner.

## 2. Contrato operacional de UM runner

Entrada: escopo e leitura das fontes do runner na SEASON_RUNNERS; inventário de arquivos e riscos; testes escritos antes de alteração.
Execução: desenvolver vários sistemas integrados ao runner, com APIs tipadas, schema migrável, registries e servidor autoritativo; trabalhar no escopo apenas. Não ativar mecânica da temporada seguinte.
Validação: validar arquitetura e script Luau, testes unitários, simulação sem render, build Rojo, testes de runtime quando aplicáveis, testes mobile com métricas reais.
Correção: se houver falha, identificar causa e corrigir; retestar. Não mascarar CI nem dizer que testou Roblox runtime sem prova.
Fechamento: commit/integração na main, receipt com links e evidências, atualizar status JSON somente após validação, e documentar decisões que mudaram. O próximo runner só inicia após o anterior estar verdinho.
Fim da temporada: publicar apenas staging verificado depois de R3, registrar publicação e pedir teste do criador. Se rejeitado, F1-F2-F3 da mesma temporada; se aprovado, próxima temporada.
Fim de T3: revisão final do jogo completo, confirmação do criador e promoção separada a produção com autorização explícita.

## 3. Fonte da verdade e ordem de precedência

1. Ordem explícita MAIS RECENTE do criador e política do repositório.
2. docs/VISION_MASTER.md atualizado e docs/DECISION_LOG.md.
3. docs/SEASON_RUNNERS.md V2 como alocação de escopo, docs/RUNNER_PROTOCOL.md e docs/RUNNER_STATUS.json como execução.
4. GDD.md/ARCHITECTURE.md e documentação do domínio.
5. docs/research/*.md: dados citados, limites e projetos próprios (não sobrescrever decisões fixadas por alegadas fórmulas de outro jogo).
6. Comentários/commits/relatos históricos do projeto com prova de execução.
Em conflito entre plano antigo V1 e plano V2, V2 prevalece. Se houver solicitação do usuário que ultrapasse runner atual, registrar em decisão e reprojetar antes de codificar.

## 4. Pesquisa: que confiança atribuir a cada item

- A: config original observada em versão específica no estudo comunitário; não equivale a regra universal de runtime.
- N: comportamento inferido de análise estática; exige teste independente para confiança prática.
- O: observação de wiki, guia, gameplay; confronto com versão e outros relatos.
- P: editor/dev confirma característica geral, não parâmetros internos.
- R: documentação oficial Roblox que fundamenta a API.
- H: decisão própria do Entre Reinos, precisa de projeto e teste.
- U: desconhecido. NÃO inferir valores.

Principal fonte de mecânicas: https://github.com/SongZcode/kingdom-two-crowns-mechanics (2.4.2 / rev23529, textos próprios CC BY 4.0). Outras: mods FredApps/abevol/minwoong, Kingdom Wiki, guias e site de Raw Fury. Fonte de Roblox sempre Creator Hub atual. Não executar ou portar DLLs, C# de outros jogos, assets protegidos ou decompiladores.

## 5. Adaptar método, não criar clone

Núcleo que será diferente de Kingdom: mundo 3D por zonas e Terrain nativo; movimento lateral R6 com nado vertical; múltiplos reinos conectados sem troca obrigatória de ilha; trabalhos por inventário real/massa e specialty; construção livre com entrega progressiva/trabalho persistido; economia de produção/comércio/tributo sem moedas surgindo de árvore; raids por objetivos e portais compartilhados; relacionamentos entre NPCs e jogador; montarias e pontes; seis saves independentes.

Não copiar números de custo, HP, temporadas ou física de Kingdom sem calibração própria. Não confundir valores numéricos da configuração de um build com fórmula completa. Histórias/arte/sprites/nomes dos monstros devem ser originais.

## 6. Testes, evidências e limites atuais

Comandos do projeto, somente quando ambiente estiver preparado:
~~~sh
python tools/workspace.py validate
python tools/script_quality.py
python -m unittest discover -s tests -v
python tools/workspace.py build --game entre-reinos --place main
python tools/deploy.py validate
~~~

Executar suite oficial Quality Gate 2.0 e testes novos do runner. Build verde não prova funcionamento real, física ou FPS. Verificar Scene Sync/Place Provision antes de alteração do Place remoto. Id de produção é separado; publicar staging só com identidade verificada e autorização pelo fluxo oficial. Nenhum segredo/tokens em Git.

## 7. Handoff ao final de cada runner

Registrar em docs/runner-receipts/Tn-Rn.md (criar quando runner for implementado):
- SHA HEAD e link de CI, testes/comandos com resultados REAIS e cenário;
- nomes/links dos módulos implementados, API e versionamento de schema;
- efeitos observados e screenshots/vídeos REAIS quando houver;
- bugs, bloqueios e itens ainda não validados no motor/mobile;
- fontes de pesquisa realmente usadas e o que foi adaptado;
- gatilho exato do próximo runner e suas dependências;
- se há necessidade de publicação, autorização, refinamento ou validação manual.

Para perguntas sobre 'o que fazer agora', consultar primeiro status JSON em vez de adivinhar a etapa. Em cada resposta, citar o SHA e não inventar que ações anteriores ocorreram.

## Histórico de execução — T1-R1 (21/11/2026)

- [EM ANDAMENTO] Começou T1-R1. Não confundir com planejamento: já foram criados serviços e clientes em Luau no game/places/main/src.
- Commit de referência de integração inicial: 36f7ddebb501877c69f423b74853c1dcfb9a8e12; consultar sempre HEAD e docs/RUNNER_STATUS.json atuais.
- Mundo e rio: WorldProfile + WorldService; salvamento: SlotModel + SaveSlotService; servidor: Boot; câmera/controles: SideCamera + LaneController; UI: SlotMenu + ClientBoot; testes puros Luau em game/tests/region_and_slots.luau.
- Verificar resultado real do CI deste commit: https://github.com/Sllay/Roblox-Studios/actions/runs/44964751575. O último CI já VERDE na hora da escrita foi 44964681829 para o commit 55ecb4e.
- Avatares R6 são configurados em Avatar Settings do Place, e o código falha explicitamente caso o jogador esteja em R15. Não alterar RigType em um Humanoid R15 ao vivo.
- Publicação staging continua BLOQUEADA por ID sem verificação, e não ocorre antes de T1-R3 e aprovação do fluxo oficial.
- Próxima ação: corrigir eventuais falhas do novo CI que executa testes Luau, expandir testes de lock/CRUD em Roblox, capturar métricas reais e validar água/plane/câmera em cliente. NÃO iniciar T1-R2 nem marcar validated.

## Checkpoint mais recente T1-R1 — execução real, CI verde, ainda NÃO validado

Código atual comprovado: `ce50d163e8978623fa944da27b4b41cc6e58c072`.
CI: https://github.com/Sllay/Roblox-Studios/actions/runs/44965276453 (concluído com sucesso).
150 testes Python (inclui wiring/paths), testes Luau puros executados (WorldProfile, SlotModel, SlotLeasePolicy), analise de tipos Luau de módulos puros, Rojo build do novo Place passaram.

Arquivos relevantes:
- `game/places/main/src/ReplicatedStorage/{WorldProfile,SlotModel,SlotLeasePolicy}.luau`
- `game/places/main/src/ServerScriptService/{Boot.server.luau,Services/WorldService.luau,Services/SaveSlotService.luau}`
- `game/places/main/src/StarterPlayer/StarterPlayerScripts/{ClientBoot.client.luau,LaneController.luau,SideCamera.luau,SlotMenu.luau}`
- `game/tests/region_and_slots.luau` e `/tests/test_entre_reinos_wiring.py`.

Diagnóstico do bug já corrigido: WorldService estava sob `src/game/places/main/src/...` duplicado e Boot não o carregaria. Corrigido e protegido por unittest. Gerador possui limites de região x, readback de voxels sólidos/líquidos/materiais e cancela geração se a região tiver Terrain preexistente.

**NÃO declarar validated, NÃO iniciar T1-R2:** runtime Roblox e mobile nunca foram executados neste turno, Avatar R6 e IDs staging não verificados. Próximo checkpoint obrigatório é teste real do servidor (criar/abrir/excluir 6 slots, locks, queda/reconexão, Terrain + água e input Z) e correções. Status oficial docs/RUNNER_STATUS.json.

## Staging de teste PUBLICADO — 21/11/2026, revisão Roblox 2

- Oficial publish.yml `https://github.com/Sllay/Roblox-Studios/actions/runs/44975639993` concluiu SUCCESS Place 90623742498445 revision 2.
- Independent Open Cloud Luau readback `https://github.com/Sllay/Roblox-Studios/actions/runs/44975725822` carregou versão 2 e encontrou 11/11 scripts/módulos/StartArea.
- Original code commit do preview: `bc45d584c547d2e397989b7e9f796d4f7b2a0863`; arquivo de workflow de readback criado em `def96b47a05bafde2afed593808ed9c34e2108d2`. Consultar HEAD atual sempre.
- Marcado somente **preview publicado para teste**, NÃO runner validado. T1-R1 runtime/mobile pendente. No próximo chat, pedir relato de R6, Terrain, travessia e 6 saves; corrigir bug de causa raiz e testar.
- Plano da validação: `docs/TEST_PLAN_T1_R1_STAGING.md`; não confundir com publicação final da temporada depois de T1-R3.
- Plano físico do personagem: normal do PlaneConstraint corresponde ao eixo **X** do Attachment0, transformado para Z pela rotação Y de pi/2; consistente com corredor X/Y. Fonte Roblox oficial: https://create.roblox.com/docs/physics/constraints/plane.

## CORREÇÃO URGENTE R6 publicada — staging v3 (21/11/2026)

Usuário testou v2 e relatou que o menu não deixava criar mundo porque Roblox iniciava em R15. Bug confirmado no `Boot.server.luau` (gate configuracao R6). Corrigido na revisão Roblox **3**.

- Código: commit `01e90365974e3241b49e489a83a3adb28fad9999`. Novo `ServerScriptService/Services/CharacterService.luau` chamado por Boot antes de criar/abrir slot, produz R6 verdadeiro com método oficial `Players:CreateHumanoidModelFromDescriptionAsync(HumanoidDescription, Enum.HumanoidRigType.R6)`, atribui Player.Character e trata respawn R15. Não modifica RigType do modelo R15.
- API oficial comprovada no alvo (sem gravar Place): https://github.com/Sllay/Roblox-Studios/actions/runs/44976095162 mostrou Model R6, Torso, HumanoidRootPart.
- CI compilação e unit tests: https://github.com/Sllay/Roblox-Studios/actions/runs/44976179460 sucesso.
- Publicação staging v3: https://github.com/Sllay/Roblox-Studios/actions/runs/44976293591, Roblox respondeu SUCCESS Place 90623742498445 revision 3.
- Leitura independente v3: https://github.com/Sllay/Roblox-Studios/actions/runs/44976379375, 11/11 arquivos do game publicados, inclusive CharacterService.
- User deve **sair por completo e abrir nova sessão** em https://www.roblox.com/games/90623742498445, criar Mundo 1, verificar avatar R6, geração Terrain/natação e seis slots.
- Runner T1-R1 **ainda in_progress**: teste runtime do ciclo de vida Player.Character real e todo gameplay ainda pendentes. Não começar T1-R2 até correções e aprovação.
- O código não depende mais de mudar Avatar Settings. Se aparecer erro `r6_creation_failed`, pedir evidência, não exigir editar configuração nem excluir mundo.

## Incidente reportado em jogo v3 e correção staging v4

- 21/11/2026 (UTC 22/11): o criador enviou captura do menu após tentar criar Mundo 1. Primeiro retornou `server_operation_failed`; ao tentar de novo, veio `world_already_active`. Ao voltar em Jogar, Mundo 1 já aparecia como **Dia 1**. Portanto a operação de criação/persistência chegou a ocorrer, mas o servidor ficou com estado de mundo/sessão ativo sem entregar uma resposta de entrada ao cliente. Não excluir o Mundo 1.
- Análise do código v3 confirmou falha estrutural: `Boot.server.luau` marcava `activePlayer` e iniciava Terrain antes de executar diretamente `respawnOnLane`; qualquer exceção posterior era capturada como erro genérico e o bloqueio `if activePlayer or WorldService.isActive() or SaveSlotService.active(player)` tornava impossível retomar o mesmo slot.
- Diagnóstico sem mexer em dados do jogador: https://github.com/Sllay/Roblox-Studios/actions/runs/44977611252 carregou Place v3 em sessão de edição Luau descartável, `WorldService.activate(42)` passou, `waterCells=574`, criação R6 real e PlaneConstraint passaram. Isso não isola a exceção específica do jogador, mas direciona para o fluxo de entrada real.
- Fixado em `9e07bcd44f7326be264b8e17ee78aca4a047b8dd`: servidor agora responde com estágio `avatar/slot/terrain/character/lane` e log detalhado, inicia com tratamento de exceções por estágio, libera o lease se Terrain falhar e, principalmente, tem RPC `resume` que permite concluir o **mesmo** slot ativo sem recriar save ou regenerar Terrain. Entrada `create/open` no próprio slot ativo é idempotente. Cliente tenta `resume` quando uma operação falhar após possível ativação. `SaveSlotService.index(player)` fornece identidade da sessão segura, sem acesso a outro slot.
- GitHub CI/Build: https://github.com/Sllay/Roblox-Studios/actions/runs/44977827154 (`success`).
- Publicação oficial staging: https://github.com/Sllay/Roblox-Studios/actions/runs/44978003846; log `SUCCESS: Place 90623742498445, revision 4`.
- Readback independente do Place v4: https://github.com/Sllay/Roblox-Studios/actions/runs/44978130381; versão 4 e 10/10 scripts/módulos presentes, além de `serverRecovery=true`, `clientRecovery=true` inspecionando Source do código publicado. Nenhuma alteração no Black Island nem produção.
- T1-R1 continua `in_progress`: somente o criador pode verificar agora o ciclo verdadeiro do player/cliente, câmera, controls, nado e DataStore no servidor do Roblox.

**Reteste prioritário:** entrar em um servidor NOVO da versão 4, clicar em Jogar > **Entrar Mundo 1**, NUNCA clicar Excluir. Caso falhe, enviar texto exato incluindo `(etapa: X)`. Se o mundo carregar, testar movimento, rio e seed após reconexão. T1-R2 continua planned.

## Incidente persistente em v4 — screenshot do criador; revisão v5 (21/11/2026)

Capturas v4 mostraram, no mesmo menu, erros: `world_needs_new_server (etapa: terrain)`, `bad_slot_or_session_active` e `other_slot_active`. Mundo 1 continuava `Dia 1`. Não apagar.

Diagnóstico do código:
- `SlotMenu.luau` autochamava `resume` após erro genérico, inclusive se a geração já havia falhado; isso substituía o erro original do Terrain por `world_needs_new_server` e impedia saber se era `ReadVoxelChannels`, `WriteVoxelChannels`, readback ou outra fase.
- `SaveSlotService.abortActivation` fazia apenas uma tentativa de `UpdateAsync`; quando ela não confirmava, a sessão ficava ocupada.
- `trackWorld` ainda podia salvar a posição do personagem no menu mesmo sem `ER_WorldLoaded`, potencialmente sobrescrevendo a posição persistente anterior.
- Sem versão do servidor no menu nem seed mostrada, impossível comprovar qual revisão/seed foi testada.

Reparos reais na `main`:
1. `WorldService` registra fase e falha do Terrain, expõe `getFailure/getPhase`, e nunca refaz write parcialmente desconhecido.
2. `Boot` transmite o erro original e a fase; `resume` não mascara mais e tenta liberar com segurança o lease.
3. `SaveSlotService.abortActivation` tem até três tentativas limitadas, idempotência por `revision + lastWriteId`, rejeita lock de outro processo e **não modifica seed/posição**. `trackWorld` não atualiza posição/clock sem `ER_WorldLoaded`.
4. `SlotMenu` só recupera sessão automaticamente se possível problema de personagem/rede; bloqueia operações em outros slots ativos, mostra **versão real do servidor e seed**, preserva erro/etapa original.
5. Testes automatizados acrescidos para os cenários acima.

Teste headless em engine v4: https://github.com/Sllay/Roblox-Studios/actions/runs/44978508712, **cinco seeds (1, 42, 1009, 870001, 123456789) geraram Terrain + água com `worldOk=true`**, em ~26–37 ms por criação (métrica de Luau Execution, não FPS); sexta requisição foi recusada pela API HTTP 429; por isso o *workflow completo terminou failure por quota*, sem evidenciar bug nas cinco seeds verificadas. **A falha real no servidor do criador NÃO foi reproduzida aqui**.

Novo código + testes: `971a306932aa8aa39c301a30a1fe9938f5329859`; CI https://github.com/Sllay/Roblox-Studios/actions/runs/44978915630 success. Publicação em staging com inventário v4 verificado e Place correto: https://github.com/Sllay/Roblox-Studios/actions/runs/44978951305, `SUCCESS: Place 90623742498445, revision 5`. Readback independente https://github.com/Sllay/Roblox-Studios/actions/runs/44979034609 (`success`) comprovou v5 e 12 checks da fonte dos scripts (WorldService, Boot, SaveSlotService, client, etc.).

Reentrada segura: sair da sessão antiga, entrar no Place, Jogar → **Entrar Mundo 1** já existente. Menu deve mostrar `ENTRE REINOS • v5`, seed e diagnóstico detalhado. Se o mundo carregar, testar solo/nado/saves; se falhar, compartilhar a mensagem completa (especialmente `[geração: ...]`) para identificar o método exato que falhou. T1-R1 permanece `in_progress`; T1-R2 bloqueado.

## Checkpoint v6 — lobby e mundo separados (22/11/2026)

**URGENTE: este bloco substitui todos os estados v2-v5 acima.** O usuário mostrou o erro exato no console `ServerScriptService.Boot:101: attempt to index nil with 'seed'`, com save Mundo 1 seed `516639272`. Causa confirmada no código legado: expressão `local success, record = if ... then SaveSlotService.create(...) else SaveSlotService.open(...)` reduziu os retornos de Luau a um valor, deixando `record=nil`. A correção usa `if/else` para capturar `ok,record` explicitamente, sem recriar ou excluir o save.

**Arquitetura T1-R1, implementada na main e publicada em staging v6:**

- **Mesmo Place `90623742498445`, servidores separados:** modo lobby público vs mundo reservado detectado por `game.PrivateServerId`. `TeleportOptions.ReservedServerId` recebe GUID novo do servidor e `TeleportService:TeleportAsync(game.PlaceId,{player},options)` encaminha um jogador para seu mundo.
- **Segurança**: `ReplicatedStorage/WorldRoute.luau` valida protocolo, identidade, ID do Place, slot e ID do servidor reservado; o servidor busca o save exclusivamente pela chave `player.UserId`, nunca confia em seed/posição enviada pelo cliente.
- **Save**: `SaveSlotService.createDetached` cria o registro sem abrir/segurar a sessão no lobby; o servidor reservado chama `Saves.open` com lock próprio via DataStore `UpdateAsync`. `World 1` existente só é aberto, sem reinicializar.
- **Terrain**: quatro chunks de 64 studs, três iniciais (2,3,4; rio incluído) e o quarto (oeste) conforme o jogador se aproxima de X=-24. Voxels sólidos/líquidos/materiais, readback e recusa em sobrescrever Terrain preexistente, sem `Terrain:Clear()`.
- **Visual**: `SlotMenu` tem backdrop opaco e cortina de teleporte; `WorldLoadingUI.luau` opaco no servidor reservado lê `ER_LoadStage`, `ER_LoadProgress` e `ER_LoadMessage` reais.
- **Solo**: servidor rejeita segundo jogador. Leitura do motor no Place publicado retornou `Players.MaxPlayers=1`, logo limite real já estava configurado em 1. Não foi necessário nem tentado forçar propriedade read-only. Multiplayer fica futuro.
- **Validação**: CI https://github.com/Sllay/Roblox-Studios/actions/runs/45030168933, 155 testes Python, Luau puro, Quality Gate tipado e build Rojo todos PASS. Publicação oficial Roblox https://github.com/Sllay/Roblox-Studios/actions/runs/45030363476: `SUCCESS: Place 90623742498445, revision 6`. Readback https://github.com/Sllay/Roblox-Studios/actions/runs/45030586488 aprovou 17 módulos/sources, API `ReservedServerId`, e em sessão edit isolada executou `World.activate(516639272)`: 3 chunks e 596 células de água, seguido de `World.ensureNear(...,-40)`: 4 chunks. **Não demonstra teleport real com usuário**.
- **Teste obrigatório do usuário**: fechar sessão antiga, entrar no Place, conferir tela totalmente opaca e v6, `Jogar > Mundo 1 > Entrar`, ver transição a outro servidor, tela de progresso e avatar R6 no Terrain; depois correr/nadar/salvar/reabrir. Se falhar, registrar mensagem/tela. **Não apagar Mundo 1**.
- **Runner** permanece `in_progress`; T1-R2 `planned`, Black Island e produção intocados. Mais detalhes em `docs/runner-receipts/T1-R1-staging-v6-reserved-world.md`.

## 22/11/2026 — staging v7: correção do joystick e painel de diagnóstico mobile

O criador enviou screenshot da versão 6 mostrando os cinco botões `ContextActionService` sobrepostos (◀ ▶ ▲ ▼ Pular), painel FPS à esquerda atrás do menu superior e confirmou que **a entrada no mundo estava funcionando** (avatar visível, seed 516639272 e Terrain renderizado). Pediu usar **joystick e botão de pulo nativos do Roblox**, mudando apenas a movimentação, e reposicionar o HUD dev.

Implementado:
- `StarterPlayerScripts/LaneController.luau` deixa de usar `ContextActionService:BindActionAtPriority(...,true,...)`, remove todos os botões inventados e não desabilita `PlayerModule`. Lê `controls:GetMoveVector()` em Input+1 e projeta joystick analógico em X terreno (Z bloqueado pelo plano físico); joystick frente/trás gira personagem no solo e se torna subir/descer na água; pulo continua controlado pelo módulo Roblox.
- Novo módulo puro tipado `ReplicatedStorage/InputProjection.luau`, inclui deadzone analógica, normalização de diagonais, conversão nativa `-Z -> +Y`, yaw esquerda/direita/frente/trás. Testado de modo executável no Quality Gate Luau, não apenas inspeção de string.
- `ClientBoot.client.luau`: GUI dev usa `IgnoreGuiInset=false` e `ScreenInsets=CoreUISafeInsets`, com `AnchorPoint=(1,0)` e posição à direita, abaixo das áreas nativas Roblox, em vez de colidir com topbar esquerda.
- CI https://github.com/Sllay/Roblox-Studios/actions/runs/45031416589 com Python, Luau LSP, pure tests, Rojo `success`.
- Publicação via Open Cloud Roblox https://github.com/Sllay/Roblox-Studios/actions/runs/45031576169, Place staging `90623742498445`, versão **7**.
- Leitura independente do Place salvo no motor Roblox https://github.com/Sllay/Roblox-Studios/actions/runs/45031693274: 11/11 checks incluindo ausência dos botões custom, presença PlayerModule:GetMoveVector, HUD CoreUI safe, código de água e execução real de `InputProjection.toLane(1,-1)` resultando em diagonal normalizada. `maxPlayers=1` continua configurado.
- **Ainda não é teste do touchscreen real**: teste mobile do criador ainda necessário. O runner T1-R1 permanece `in_progress`; T1-R2 `planned`. Saves existentes/Black Island/produção intocados.

Reteste: fechar v6, abrir servidor v7, Mundo 1, verificar joystick e pulo padrão sem sobreposição, FPS direito fora do CoreUI, X movimento em terra, giro frente/trás sem andar profundidade, diagonal/nado vertical em água. Reportar print/FPS e comportamento.

## Transição aprovada pelo criador: T1-R1 → T1-R2 (22/11/2026)

O usuário declarou que controles, joystick e movimentação do v7 estavam funcionando bem e **autorizou explicitamente o R2**; solicitou somente que o personagem R6 use a animação padrão `Swimming` quando nadar. O `CharacterService` agora preserva o `Animate` original ao substituir `Player.Character`; Roblox `Humanoid.StateChanged` dirige o estado `Swimming`. A apresentação da animação de nado ainda exige observação no cliente, não marcar como visualmente testada. R1 formalmente aceito para transição com essa ressalva.

**T1-R2 iniciado em código real**, green CI https://github.com/Sllay/Roblox-Studios/actions/runs/45033200114:
- `ReplicatedStorage/Living/`: ItemDefs, ProfessionDefs, StructureDefs, Inventory, LivingModel, WorkEngine (FSM); massa, materiais finitos, reservation counter, construção/reparo cumulativos. Profissões carpinteiro madeira 3x, minerador pedra/ferro 3x, construtor obra 2x, comum 1x. Sem dinheiro nem sistemas prematuros R3.
- `ServerScriptService/Services/LivingService.luau`: quatro NPCs visuais R6, fontes físicas, blueprints, simulação Heartbeat com baixa frequência, stream de chunk pelos trabalhadores.
- Boot server reservado inicia LivingService somente depois de Terrain/R6, atualiza progresso real de carregamento; o lobby permanece isolado. `SaveSlotService` coleta snapshots `living` em UpdateAsync com cópia profunda e preserva seis slots anteriores de schema 1. `BuildMenu` permite ordenar construção no celular, posição definida pelo servidor e custo entregue pelos NPCs.
- Teste executável `game/tests/living_work_r2.luau` fez worker completar um abrigo por madeira/pedra reais, reparo e serialização/restauração; gate de tipagem, Python, compilação e Rojo passaram.
- **Ainda pendente:** observar NPC e UI em partida real, checar performance do celular e persistência prática; T1-R2 `in_progress`, T1-R3 `planned`. Preview staging R2 ainda não publicado neste checkpoint.

## 22/11/2026 — R2 staging v8 publicado e comprovado

- **Publicação real Roblox** Place `90623742498445`, Universe `10769712413`, revisão `8`: https://github.com/Sllay/Roblox-Studios/actions/runs/45033471243 (`SUCCESS: Place 90623742498445, revision 8`). Guardado inventário da versão 7 antes da substituição; sem gravar/excluir saves e sem afetar Black Island ou production.
- **Prova independente no Roblox**: https://github.com/Sllay/Roblox-Studios/actions/runs/45033671441 carregou versão publicada 8, conferiu **16/16** módulos/scripts, executou o WorkEngine dentro de Luau Execution isolado: 4 NPCs de dados, custo real 11 materiais entregue, 1 abrigo concluído, 1 reparo, snapshot de população válido; criou rig R6 real com API oficial. Todos PASS. **Não** equivale a testar GUI / NPCs reais em servidor com jogador mobile.
- T1-R1 nado: script nativo `Animate` foi preservado ao criar R6 na revisão 8. A animação visível quando Humanoid está Swimming ainda precisa ser conferida pelo criador.
- **Próximo teste T1-R2**: abrir Mundo 1 seed `516639272`, verificar quatro moradores R6, botão **Construir** abaixo da interface superior, escolher **Abrigo**, observar NPCs buscarem madeira/pedra, transportarem, entregarem ao canteiro, construírem e salvar/reabrir; conferir FPS. Posição da construção é escolhida pelo servidor, sem aceitar X arbitrário do cliente.
- Status final do turno: T1-R1 validated pela aprovação explícita de movimento; R2 in_progress e sua versão 8 é **preview**, não aceitação de runner. T1-R3 planned.

## 22/11/2026 — Feedback v8 em campo e correção v9

O criador viu em celular um mundo R2 funcional em 60 FPS, mas NPCs R6 aparecem enterrados (só ombro/cabeça), avançam aos trancos em 8~10 Hz, popups de recursos/obras bloqueiam visão, o R6 continua com animação de andar/cair dentro da água. Também solicitou zoom moderado e silhueta escura de árvore verdadeira.

Causas diretas auditadas no Git: `LivingService.syncNPC` colocava `Model:GetPivot` em `sample.height + 3.15` sem considerar os pés; `draw()` fazia `model:PivotTo` com intervalo >=0.12s. O `BillboardGui` 180x50 usava fundo escuro e `AlwaysOnTop=true`. `LaneController` confiava só em `Humanoid:GetState()==Swimming` e `CharacterService` clonava `Animate` R6 sem garantir animação distinta de nado.

Correção v9 em desenvolvimento:
- `LivingService` calcula offset pivot→sola dos dois pés, consulta Raycast real no Terrain ignorando água, move modelo inicialmente para superfície + margem; depois **não faz PivotTo 8 Hz no servidor**, replica pose/velocidade.
- `NPCPresentation` faz interpolação/extrapolação limitada 60 Hz no cliente, usando animação de caminhada oficial R6 180426354, servidor preserva autoridade sobre inventário/trabalho/save.
- Labels 3D com fundo totalmente transparente, texto pequeno e contorno preto, distâncias curtas; galpões/casas visualmente atrás da lane Z=-10.
- `WaterRules` verifica rio seeded e nível d'água original; `LaneController` detecta a imersão mesmo sob estado transitório `Freefall`, pede estado Swimming quando submerso e preserva física/joystick nativos. `R6SwimVisual` usa um ciclo de braços/pernas original apenas como fallback visual de R6 (não afirmar que seja animação nativa R15 transferida para R6).
- `SideCamera` normal 100→88 e wide 134→118; substituídos `WedgePart` pretos por pequenas árvores silhouette 3D com tronco+copas no mesmo vocabulário da arte.
- Feedback futuro sobre world depth, subbiomas, espelhamento de árvores, encosta/muralhas e assets foi especificado em `docs/DESIGN_WORLD_DEPTH_AND_MIRRORING.md`. Não expandir agora bounds do Terrain sem migração de seed e benchmark.

**Gate:** publicar staging apenas após CI de Python/Luau/Rojo verde e snapshot do Place v8, confirmar v9 e leitura independente. Não marcar natação e FPS mobile como testados sem o criador.

## 22/11/2026 — v9 publicada, testes de rig/Terrain PASS

**Feedback observado:** no v8 cliente real a ~60 FPS, NPC R6 apareciam enterrados, movimentação visual aos trancos, retângulos de etiquetas bloqueavam visão, nadador R6 continuava walk/fall na água; cenário muito raso e triângulos pretos; zoom distante. Correções específicas (sem expandir mundo salvo):
- `LivingService.luau`: calcula deslocamento entre pivot do R6 e base física das pernas, obtém solo com `workspace:Raycast` somente `workspace.Terrain` e ignora água, assenta com margem +0.14 stud. Não chama `model:PivotTo` em snapshots de 0.12s; replica atributos da pose e velocidade do servidor.
- `NPCPresentation.luau`: apresentação client-only com `RunService:BindToRenderStep`, interpolação/extrapolação limitada, Roblox default R6 walk clip 180426354. Inventários, lógica, salvamento e propriedade das posições seguem 100% no servidor.
- Etiquetas `BillboardGui` fundo totalmente transparente (`TextLabel.BackgroundTransparency=1`), `TextStrokeTransparency=0.08` preto, distâncias 40 para obra e 23 para recursos, textos menores. Volumes das casas/obras ficam visualmente em Z=-10, ainda sem colisão final.
- `WaterRules` usa seed/nivel `WorldProfile` para reconhecer se torso está submerso mesmo após mudança transitória do `Humanoid` para Freefall; `LaneController` pede estado real Swimming quando na água, preserva joystick e pulo nativos. `R6SwimVisual` fornece nado visual original de membros via `Motor6D.Transform` em `PreSimulation` **porque R6 clássico não garante clip de nado dedicado**; restaura Animate ao sair. Não confundir com transferir animação R15 para R6.
- Câmera normal 100→88 studs, wide 134→118; `WorldService` substitui cunhas pretas por árvore escura com tronco+copas.
- Profundidade do background/void, subbiomas, estoques florestais refletidos atrás, muralhas seguindo relevo e assets próprios foram registrados no `docs/DESIGN_WORLD_DEPTH_AND_MIRRORING.md`, sem ampliar Z agora e invalidar saves existentes.

**Provas**
- GitHub CI código/Quality Gate/Rojo https://github.com/Sllay/Roblox-Studios/actions/runs/45036214420: sucesso.
- Publicação oficial Roblox https://github.com/Sllay/Roblox-Studios/actions/runs/45036519730: `SUCCESS: Place 90623742498445, revision 9`, staging Entre Reinos apenas.
- Readback Roblox Luau Execution isolado https://github.com/Sllay/Roblox-Studios/actions/runs/45036652831: `loadedVersion=9`, 16/16 checagens, Terra nativa 3 chunks, 596 células líquidas, rig oficial R6 posicionado a 0.14 stud do solo real e regra de rio valida. **Não mede animação/FPS no celular**.

**Gate:** T1-R2 continua `in_progress`; T1-R3 continua `planned`. Criador deve reabrir Mundo 1 seed 516639272, verificar NPC acima do chão e andar fluido, labels sem fundo, nado R6 claro/sem fall, UI construir e FPS. **Não apagar mundo nem criar save novo por causa de preview**.

## 22/11/2026 — T1-R3 v12 prévia publicada e verificada

- O criador aprovou a natação nativa na v10, reportou na v11 apenas pequenas oscilações remanescentes nos passos dos NPCs e autorizou começar T1-R3. Em `NPCPresentation.luau` o render dos moradores agora integra movimento continuamente por frame e corrige gradualmente erro contra pose do servidor; não aumenta o orçamento de simulação. FPS e fluidez real aguardam avaliação mobile.
- T1-R3 implementado em `R3Engine.luau`, `CombatService.luau`, `R3HUD.luau`, `LivingService.luau` e validado por `r3_fundamentals.luau`: duque infectado roteirizado, combate corpo a corpo/arco, ondas locais alternadas com noites tranquilas, saque e moeda sem duplicação, inventário de flechas limitado por madeira, defensores, dano/reparo/ruína e salvamento finito, ciclo dia/noite e coroação. Dados R3 opcionais são compatíveis com os seis slots anteriores; Mundo 1 legado entra no sandbox e não repete prólogo, e um slot novo separado permite testá-lo.
- Validação final do código (Python, Luau tipado/executável e build Rojo) em https://github.com/Sllay/Roblox-Studios/actions/runs/45042046569 — success.
- Publicação segura somente no staging: https://github.com/Sllay/Roblox-Studios/actions/runs/45042109502 — `SUCCESS: Place 90623742498445, revision 12`; Universe `10769712413`.
- Readback independente do Roblox da versão 12: https://github.com/Sllay/Roblox-Studios/actions/runs/45042278397 — success, 11/11 verificações das fontes publicadas e ensaio Luau com Terrain, save legado migrado, combate contra duque infectado, invasão bilateral e moeda antifraude. Sessão isolada não mede FPS, UI touch, animação percebida ou gameplay com jogador conectado.
- Status oficial `T1-R3=in_progress`, pois falta playtest mobile do criador, persistência após reconexão, combate/RPC e visual. `RUNNER_STATUS.json` e `runner-receipts/T1-R3.md` contêm recibo e pendências. Não abrir T2 nem publicar em production. Não apagar o Mundo 1 nem alterar Black Island.

## 22/11/2026 — UI v13 sem painel dev
- Feedback real do criador: v12 tinha nove ações no centro da tela, construção em menu separado e falta de informação de moedas/recursos/crafting. Decisão fixada em `docs/DECISION_LOG.md`.
- Em v13, `R3HUD.luau` é o **único** ScreenGui de gameplay: HUD curto com dia/moedas/flechas/fontes, 2 ações de combate fora dos cantos touch, 1 botão interativo conforme contexto e caderno de vila recolhível (OBRAS/ESTOQUE/PESSOAS/OFICINA). `BuildMenu.luau` passou a ser subpainel montado no caderno; não instanciar painel independente no futuro. Removido `BuildMenu.start(player)` de `ClientBoot` e diagnóstico FPS desligado por padrão em `SlotMenu`.
- `WorkEngine.summary` reporta `resources.sources/carried/reserved/committed` reais (fontes no mundo não são bolsa do jogador); `LivingService.status` agrega resumo, dia/saldo/R3 e disponibilidade de ações próximas observada pelo servidor. UI consulta no máximo uma vez a cada 3 segundos, não a cada quadro. Teste Luau verifica ledger de recursos antes/depois de obra e não duplica madeiras/pedras.
- Validação código: CI https://github.com/Sllay/Roblox-Studios/actions/runs/45044388022 — success; fonte oficial Roblox Creator Hub ScreenInsets + mobile UI safe areas checada em 22/11.
- Publicado SOMENTE staging Roblox: Place `90623742498445`, Universe `10769712413`, revisão **13**, workflow https://github.com/Sllay/Roblox-Studios/actions/runs/45044458402 — sucesso confirmado pela Open Cloud.
- Readback Roblox v13: https://github.com/Sllay/Roblox-Studios/actions/runs/45044562948 — PASS 13/13 fonte + 5/5 execução de módulo de catálogo montado, materiais e save legado. **Não chamar de UX aprovado sem o criador testar em partida real/mobile.**
- Próximo gate: verificar v13 em novo servidor, Mundo 1 antigo e opcional Mundo 2 para prólogo, captura visual de posições/proporções mobile, moedas, preços/crafting e botões em relação ao joystick/salto; corrigir em refinamento T1 antes de iniciar T2. Nenhum timer/monitoramento foi criado.


## 22/11/2026 — Auditoria de completude cumulativa ER-001…058, v14
- **Read first**: `docs/FEATURE_COMPLETENESS_AUDIT.md` (58 requisitos de lançamento), `docs/SEASON_RUNNERS.md` (9 owners), `docs/RUNNER_PROTOCOL.md` (gates), `docs/RUNNER_STATUS.json` (execução). `tests/test_entre_reinos_feature_completeness.py` é gate da CI e recusa owner ausente ou requisito "VALIDADO" sem evidência assinada (CI/engine/mobile/save/load/antifraude/review).
- A revisão v14 foi publicada em STAGING `90623742498445`, Universe `10769712413`. Publicação https://github.com/Sllay/Roblox-Studios/actions/runs/45052543242 — SUCCESS revision 14. CI pré-publicação https://github.com/Sllay/Roblox-Studios/actions/runs/45052486884 — success. v14 trabalha raid noturno com primeiro aviso, árvores marcáveis, galpão recebendo recursos, crafting com galpão, peças visualmente distintas e saveFormat/ruleset compatíveis; aprovação do criador **PENDENTE**, não considerar T1 completada.
- **Bugs/lacunas T1 descobertos pela inspeção estática:** WorkEngine ainda só pega `availableSource` para obra, não tira do `b.stored`; destruição do galpão não particiona o inventário armazenado; placement servidor automático não é escolha livre; `LivingModel.new` inicia `buildings={}`, faltando castelo + dois galpões/aneis; prólogo FSM sem escolta/infecção encenada/comando de guardas; morte e recuperação de cidadão/jogador sem regra completa; marca de árvores somente ligada a `sites` específicos, árvores decorativas são estáticas. UX real/mobile precisa review.
- **Obrigatório:** T1-F1/F2/F3 na própria temporada para fechar ER-001…020; T2 fecha ER-021…044 de ponta a ponta; T3 fecha ER-045…058 e revalida 001…044. Não transferir obrigações de gameplay base para polimento T3.
- Novas regras de save são *contratos de dados*, não Place revisions. Ainda faltam backup/restauração verificáveis e migrações automáticas para futuras mudanças estruturais; não excluir saves ou prometer execução da versão antiga por magicamente indicar version=1.
- Fora do contrato do lançamento solo: PvP, multiplayer/coop e segredo futuro privado; não documentar lore sensível no repositório.


## 23/11/2026 — Staging v15 T1-F1: crafting de flechas utilizável
- **Novo feedback:** UI v13/v14 ficou melhor, mas jogador não conseguia fabricar flechas. Raiz: madeira mostrada no HUD é de fontes regionais/galpões, enquanto a ação exigia proximidade e bloqueava o botão sem ajuda; não havia bolsa pessoal de madeira.
- **Implementação v15:** `R3Engine.playerBag` (Inventory.new(24)) inicializada também em R3 salvado de versões anteriores, com schema validado e sem wipe; `R3.takeWood` coleta duas unidades reais de árvore ou transfere de galpão a curta distância observada pelo servidor; `craftArrows` consome duas unidades da bolsa e dá seis flechas de qualquer local. HUD mostra a bolsa e a árvore mais próxima, com botão de pegar madeira e crafting acionável.
- **Evidências:** código+Rojo+Luau: https://github.com/Sllay/Roblox-Studios/actions/runs/45109127316 (success); staging revision 15: https://github.com/Sllay/Roblox-Studios/actions/runs/45109178317 (success); readback **Roblox real**: https://github.com/Sllay/Roblox-Studios/actions/runs/45109284309 (27/27 source e 15/15 probes SUCCESS). Detalhes em `docs/runner-receipts/T1-F1.md`.
- **Não concluir T1 ainda:** auditoria em `docs/FEATURE_COMPLETENESS_AUDIT.md` aponta galpão→obra, perda de estoque em ruína, colocação manual, castelo + 2 galpões iniciais, encenação/tutorial completo do duque, morte/recuperação, migrações/backups e QA de NPC/FPS/mobile. Runners T2 seguem PLANNED; só iniciar após T1-F1/F2/F3 resolvidos e aprovado pelo criador.
- Testar em novo servidor, primeiro **Mundo 1 antigo**, colher 2 unidades junto a árvore, conferir BOLSA MAD 2, fabricar 6 flechas em qualquer ponto, salvar/reabrir e verificar saldo; não apagar slots. Só então considerar o bug de oficina encerrado.

## Checkpoint T1-F1 — integridade estrutural em branch, 23/11/2026

A branch `entre-reinos/t1-f1-integridade` partiu da main `6d18e19`. A auditoria de código dos ER-001–020 está em [T1_F1_CODE_AUDIT.md](T1_F1_CODE_AUDIT.md). Os commits `2bca423` e `233e0a7` entregam proteção de snapshot, retirada de estoque para obras, reservas persistidas, árvore marcada, isolamento de ruínas, comércio/fabricação com custódia, colocação pelo jogador e assentamento inicial. Consultar [recibo T1-F1](runner-receipts/T1-F1.md) antes de continuar.

O candidato grava ruleset 2 após confirmar o backup do último estado legado. O staging continua v15. O probe isolado passou com três suítes Luau, seis edifícios apoiados sobre Terrain e três chunks. O próximo gate depende de validar DataStore/backup e fluxos de partida touch, das regras de recuperação de ruínas/estorno e das ligações entre vila inicial e distritos. T1-F2/F3 não iniciados e T2 continua bloqueada. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45285763613) · [Motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45285764016)

## Staging T1-F1 disponível para playtest

O PR #10 foi integrado em `7983bc57a987837f4bb073bb017c20bfd41edbc1`. A revisão **16** de staging tem CI, probe de DataStore/Terrain e readback independente. Use o roteiro no [recibo da T1-F1](runner-receipts/T1-F1.md). A confirmação do criador em touch e a decisão final sobre estorno/ruínas continuam abertas. T1-F2/F3 permanecem planejados e T2 segue bloqueada.

## T1-F2/F3 — staging v17

O PR #11 foi integrado em `ad458775a6043e013c3795aef16ee51fda135a5b`. Staging v17 foi confirmado pela API, por readback de 29 scripts com execução em motor e por Scene Sync. O [recibo F3](runner-receipts/T1-F3.md) cobre ER-001–020 e contém o roteiro. O [recibo F2](runner-receipts/T1-F2.md) cobre as mudanças de gameplay e compatibilidade. O candidato está **awaiting_creator_review**. A T1 segue em andamento e T2-R1 está bloqueada.


## 24/11/2026 — v17 reprovada no aspecto visual/movimento; novo refinamento T1-F4/F5/F6
- Novo feedback de partida do criador tem prioridade sobre os recibos técnicos da v17. Diagnóstico exato e aceite técnico especificados em `docs/T1_V17_CREATOR_PLAYTEST_REFINEMENT.md`.
- **Falhas verificadas por código:** `LivingService.actorZ` fixava quatro faixas (sem `npc.z` de simulação), `WorkEngine.walk` movia apenas X, `NPCPresentation.poseLimbs` usava Transform trigonométrico, `CombatService.enemyModel` usava blocos escuros, `R3HUD` dois botões fixos sem hotbar, `CombatService` arco com velocidade constante, `Campaign.command("training")` iniciava escolta sem diálogo, `WorldProfile` quatro chunks / três iniciais.
- Branch `entre-reinos/t1-f4-mobile-world-overhaul`, PR #12 draft, base main `279f89f9c261a0a8e05b658753e27e62b54d42ee`: implementados `npc.z` persistido/migrável, movimento X/Z para jobs e idle wandering, render sem faixas, 9 tons de pele determinísticos, animações clássicas R6 Animator (walk/idle/toolslash), teste de depth. CI inicial https://github.com/Sllay/Roblox-Studios/actions/runs/45493792506 — success, ainda SEM Roblox runtime/mobile e sem publicação.
- **Ainda NÃO implementado:** humanos corrompidos R6, armas NPC visualmente verificadas, interação hold, HUD hotbar, arco de carga, efeitos de golpe, diálogo/câmera de duque, 17 chunks/5 iniciais. Fazer por etapas do refinamento; nunca confundir documentação com gameplay.
- **Gate:** staging continua v17, produção e outros jogos intocados. Antes de merge/publicação, quality gate, testes no motor, validação de posse de saves, Scene Sync e fluxo oficial de staging. Não marcar T1 validada/T2 iniciada.

## Staging v18 — candidato T1-F4/F5/F6

O PR #12 foi integrado na main em `af4cb9bde16e8445045fa3c988a694211da6ebf7`. O workflow publicou a árvore desse merge com o registro de Scene Sync prévio (`98f81262ff93066c759b915253d557193e3efc9f`). O readback independente conferiu 33/33 hashes de scripts, StreamingEnabled e a expansão 5 → 17. O Scene Sync posterior confirmou Place 90623742498445, Universe 10769712413, revisão 18, 90 objetos do inventário e zero conflitos. [PR](https://github.com/Sllay/Roblox-Studios/pull/12) · [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45498169441) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/45498317776) · [Readback](https://github.com/Sllay/Roblox-Studios/actions/runs/45498431957) · [Scene Sync prévio](https://github.com/Sllay/Roblox-Studios/actions/runs/45498174949) · [Scene Sync posterior](https://github.com/Sllay/Roblox-Studios/actions/runs/45498437120)

- F4 usa navegação X/Z com desvio local e R6 nativo. A barra de atividade e a roupa continuam indicando a função. Várias ações de trabalho ainda compartilham o mesmo gesto R6.
- F5 usa as bordas para hotbar e interação. Toque curto interage, segurar cerca de 0,8 s alterna a marcação da árvore. Espada e arco têm um botão de ataque. O duque precisa ser abordado para iniciar conversa e escolta.
- F6 prepara cinco chunks no início e visita até 17. Os seis slots mantêm as chaves e o ruleset 3. O DataStore real isolado verificou backup, lease e reabertura na fronteira. [Probe de integração](https://github.com/Sllay/Roblox-Studios/actions/runs/45497927554)

O playtest touch e visual do criador continua pendente. Os pontos principais são sobreposição de controles em telas pequenas, ritmo dos passos e leitura das ações dos NPCs, continuidade do prólogo e fluidez ao atravessar chunks. ER-001–020 permanecem PARCIAIS. As decisões sobre perdas por morte, ruínas e estorno seguem abertas. [Receibo técnico](runner-receipts/T1-F6.md)

## 25/11/2026 — Preparação de T2-R1 em branch isolada

O criador aceitou a v18 como fundação e autorizou o trabalho técnico. A T1 segue em certificação. ER-001–020 permanecem PARCIAIS e o aceite não equivale a aprovação individual. O perfil regional de desenvolvimento prolonga o campo da v18, reusa o gerador nativo e é verificável em sessão Open Cloud descartável. Mantém-se a v18 no staging e o fluxo de save no perfil anterior. A integração do runner depende do protocolo de transição e dos gates ER-021–027. [Recibo T2-R1](runner-receipts/T2-R1.md)

## 25/11/2026 — Runtime regional em desenvolvimento no PR #13

A branch isolada carrega o perfil regional no Boot, convida o jogador a construir as pontes pelo caderno e usa WorkEngine em ambos os reinos. Ruleset 4 grava o estado regional, o destino e os veículos com backup da v18 no mesmo lease. O SaveSlotService mantém um limite explícito para o snapshot. O PR continua em rascunho. O staging permanece na v18. Consultar o [recibo T2-R1](runner-receipts/T2-R1.md) para evidências, parâmetros provisórios e verificações de cliente pendentes.

## 25/11/2026 — regressão de montagem e travessia corrigida no PR #13

O candidato `04d9be796ae944324b7ffd61bba6d2f93ffeeee3` passou no probe Roblox com R6 sintético, incluindo espera na margem, ponte reforçada, remontagem, fronteira, barco com carga e retry da viagem. A migração v18, o restore do segundo reino, a montaria e a carga também passaram no DataStore isolado. O status do runner permanece bloqueado para integração pela certificação da T1 e pela prova em cliente/mobile. A main e o staging v18 foram preservados. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45658252612) · [Motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45658231902) · [Recibo](runner-receipts/T2-R1.md)

## 25/11/2026 — Certificação e prévia regional

O PR #13 recebeu `7bf8a7bafc9e7cf6d0da893fb813ecab3ff4bc55`. Ao morrer montado ou a bordo, o jogador perde o vínculo com o assento e volta ao castelo, inclusive ao reabrir um save com recuperação pendente. Veículo e carga ficam onde estavam. O cancelamento e a ruína de pontes colocam os materiais recuperáveis na margem usada pelos trabalhadores. VILA → ESTOQUE aponta para a Vila do Cedro até a primeira visita. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45671239634) · [Motor](https://github.com/Sllay/Roblox-Studios/actions/runs/45671224264) · [Recibo](runner-receipts/T2-R1.md)

O criador aceitou a v18 para continuar o desenvolvimento. A [revisão individual da T1](T1_CERTIFICATION_V18.md) identifica as provas técnicas reaproveitadas, os ensaios em cliente e as decisões de recuperação pendentes. Os requisitos formais continuam parciais. O PR segue em rascunho e staging em v18. Uma prévia antecipada exige autorização formal registrada, com destino identificado e workflow aprovado para o SHA. O [roteiro da prévia](T2_R1_PLAYTEST.md) contém os passos depois da liberação e o plano de preservação da v18.

O [mapa T2-R2](T2_R2_INTEGRATION_MAP.md) cobre ER-028–035. A proposta de avanço agregado durante sessão ativa usa o mesmo estado de produção regional. O avanço offline continua aberto. A implementação aguarda fechamento dos gates da T1 e T2-R1.

## 25/11/2026 — Autorização formal da prévia isolada

O criador autorizou uma prévia T2-R1 do PR #13 em Universe independente, com candidato `f7d4ac685f2372d066cdf49a19b2b978f2454745`. O workflow na branch usa o secret de staging `ROBLOX_T2_R1_PREVIEW_API_KEY`. A criação da experiência isolada depende da interface oficial do Roblox e do provisionamento da chave pelo dono. O staging v18, o DataStore e os gates de integração continuam separados. [Protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1) · [Procedimento](T2_R1_PLAYTEST.md) · [Inventário v18](https://github.com/Sllay/Roblox-Studios/actions/runs/45681890920)

## 25/11/2026 — Correção do destino da prévia T2-R1

O criador autorizou usar o staging existente e migrar saves compatíveis de ruleset 3 para 4 pelo fluxo com backup. O PR #13 permanece em rascunho. A publicação usa o candidato `f7d4ac685f2372d066cdf49a19b2b978f2454745` e a credencial existente. O Scene Sync confirmou v18 sem alterações externas. Consultar o recibo para revisão final e recuperação. [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45685859918) · [Procedimento](T2_R1_PLAYTEST.md)

## 25/11/2026 — Prévia regional v19 disponível

O candidato `f7d4ac685f2372d066cdf49a19b2b978f2454745` foi publicado no staging existente. A API confirmou v19 e o readback verificou 41 scripts. O Scene Sync pós-publicação confirmou o digest da cena. O backup da v18 permanece no histórico de versões e no artefato verificado. Os saves migram durante a partida pelo fluxo com backup por slot. O PR #13 continua em rascunho e T2-R2 aguarda os gates. [Jogar](https://www.roblox.com/games/90623742498445) · [Recibo](runner-receipts/T2-R1.md) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45686521277)

## 25/11/2026 — Feedback v19 e início da T2-R2

O criador confirmou as duas categorias de construção de ponte, a travessia do jogador corretamente restrita à reforçada e a exploração de múltiplos biomas. O refinamento visual dos biomas ficou para depois. Autorizou iniciar o desenvolvimento da T2-R2 em branch derivada de PR #13. O aceite cobre apenas os fluxos observados. [T2-R1](runner-receipts/T2-R1.md) · [T2-R2](runner-receipts/T2-R2.md)

## 25/11/2026 — Candidato T2-R2 e preparo de playtest

O [PR #14](https://github.com/Sllay/Roblox-Studios/pull/14) contém os checkpoints A–F, com a branch T2-R1 como base. O código `c905eca3437ecd124c6afac6cce0df21df31f8e1` passou em CI e no motor v19, em sessão descartável. A migração 4 → 5 usa backup por slot e o avanço distante vale apenas durante a sessão. O ensaio de dois reinos cobriu 2.400 s de simulação. O staging v19 segue publicado e a nova prévia depende de autorização específica. [Recibo](runner-receipts/T2-R2.md) · [Roteiro e publicação](T2_R2_PLAYTEST.md)

## 25/11/2026 — Prévia econômica v20 disponível

O candidato `c905eca3437ecd124c6afac6cce0df21df31f8e1` foi publicado no staging existente após autorização específica para substituir a v19 e migrar saves compatíveis de ruleset 4 para 5. O readback verificou 45 scripts e o Scene Sync posterior confirmou o digest. O rollback exato da v19 está arquivado. A próxima ação é o playtest do criador. [Jogar](https://www.roblox.com/games/90623742498445) · [Recibo](runner-receipts/T2-R2.md) · [Roteiro](T2_R2_PLAYTEST.md)

## 26/11/2026 — Refino profundo após o playtest da v20

O feedback da v20 cobre interface mobile, hotbars, alvos e estrutura contextual, ordens remotas, congestionamento, evacuação, hitboxes, duque e guardas, streaming antecipado e profundidade aquática/florestal. Manter o PR #14, os contratos da economia regional e os saves; suspender T2-R3. Trabalhar em A interface, B estruturas e ordens, C multidões, D combate e evacuação, E mundo e F integração/provas. [Feedback integral](VISION_MASTER.md#26112026--refinamento-do-playtest-v20) · [Decisões](DECISION_LOG.md#26112026--feedback-da-v20-e-escopo-do-refinamento)

O candidato de refinamento está no PR #14, com recibo por checkpoint e provas separadas para Luau e Roblox. As ordens de equipamento e a revisão da paisagem adicionam campos opcionais ou dados derivados ao ruleset 5. A área jogável conserva a geração regional 2. O staging continua na v20 e a autorização registrada para a publicação anterior é específica para o candidato econômico original. [Recibo do refinamento](runner-receipts/T2-R2-v20-refino.md)

CI e motor confirmaram o candidato `c4fb0790c14cd7c42cead0ae17e8f013b36fab1c`. O inventário remoto confirmou a v20 no staging existente e o RBXLX de rollback foi reproduzido com o hash publicado. Após o aceite explícito para substituir a v20 por esse SHA, atualizar o procedimento de prévia com esse baseline, rodar a proteção de staging e registrar revisão e readback. T2-R3 aguarda o playtest mobile e a decisão do criador. [CI](https://github.com/Sllay/Roblox-Studios/actions/runs/45732024313) · [Roblox](https://github.com/Sllay/Roblox-Studios/actions/runs/45732016659) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45732024958)

## 26/11/2026 — Refinamento T2-R2 v21 disponível para playtest

A autorização do criador fixou o candidato `c4fb079` e a substituição da v20 no staging existente. A API confirmou a v21. O readback verificou 50 scripts e o Scene Sync posterior confirmou o inventário. O rollback da v20 foi arquivado antes da publicação. Ruleset 5 e seis slots preservados. A T2-R3 aguarda o feedback do criador. [Playtest](https://www.roblox.com/games/90623742498445) · [Recibo](runner-receipts/T2-R2-v20-refino.md) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/45741909503) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/45742069302)

## 27/11/2026 — Água e encaixe de ponte

O playtest reportou um corte no morro, linha na água e dificuldade de encaixar a ponte. O candidato `b712a6f6c44e3d91a891ab4db73294aa0e1dcaf9` corrige a seção do rio e o snap das margens secas. CI e Open Cloud confirmaram continuidade do Terrain, obstrução física, construção das duas pontes e preservação de dados. A v21 continua publicada. A correção aguarda autorização para staging e conferência visual no cliente. T2-R3 segue suspensa. [Recibo](runner-receipts/T2-R2-v20-refino.md#correção-do-rio-e-das-pontes--27112026)

## 27/11/2026 — Correção de água e pontes publicada na v22

A v22 está disponível no staging, com ruleset 5 e seis slots. A API confirmou a publicação de `b712a6f`, o readback verificou 50 scripts e o Scene Sync confirmou o digest. O workflow arquivou o rollback da v21 antes da escrita. T2-R3 aguarda o playtest do criador. [Playtest](https://www.roblox.com/games/90623742498445) · [Recibo](runner-receipts/T2-R2-v20-refino.md) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/46027305046) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/46027483067)

## 27/11/2026 — Pontes, vegetação aprovada e mar frontal

O playtest da v22 ainda reportou `solid_obstruction`. No motor, com a vila carregada, os píeres dos ancoradouros do Vale e da Margem ocuparam a faixa da ponte no cruzamento `region:0:crossing:14`. O candidato `46594201fe56d6f49707088e3a919d20977d8f13` desloca fisicamente os píeres, mantém o bloqueio real de estruturas, integra oito modelos aprovados do Black Islands e inicia o mar contínuo na borda do corredor existente. A prova usa os serviços de inicialização do jogo em servidor descartável com jogador de teste. Os diagnósticos de colocação ficam disponíveis no servidor para o próximo playtest e podem ser retirados após essa confirmação. [Reprodução](https://github.com/Sllay/Roblox-Studios/actions/runs/46065489931) · [Prova final](https://github.com/Sllay/Roblox-Studios/actions/runs/46066704862)

O PR #14 continua em rascunho. O staging permanece na v22 e seu rollback reproduziu o hash publicado. A próxima ação é autorizar o SHA candidato para substituição da v22, arquivar o rollback e conferir o inventário pelo procedimento oficial de prévia. O cliente mobile ainda precisa conferir snap, travessia, costa, cascatas e silhueta do fundo. [Scene Sync v22](https://github.com/Sllay/Roblox-Studios/actions/runs/46066703578) · [Recibo e roteiro](runner-receipts/T2-R2-v20-refino.md#pontes-vegetação-aprovada-e-mar-frontal)

## 27/11/2026 — Pontes, vegetação e mar frontal disponíveis na v23

A autorização do criador liberou o SHA `4659420` para o staging existente. A API confirmou a v23. O readback conferiu 51 scripts, 12 malhas e grama nativa. O Scene Sync posterior registrou 137 objetos, zero conflitos e o mesmo digest. O rollback da v22 foi arquivado antes da escrita. Ruleset 5 e seis slots preservados. O PR #14 continua em rascunho e a T2-R3 aguarda o playtest do criador. [Playtest](T2_R2_PLAYTEST.md) · [Recibo](runner-receipts/T2-R2-v20-refino.md#publicação-da-v23--27112026) · [Publicação](https://github.com/Sllay/Roblox-Studios/actions/runs/46082052074) · [Scene Sync](https://github.com/Sllay/Roblox-Studios/actions/runs/46082166226)

## 28/11/2026 — Escala das árvores e câmera lateral

O playtest mobile da v23 mostrou a tela encoberta durante a escolta. O motor confirmou 12 malhas com dimensões originais zeradas na revisão publicada. O candidato `8f30a1f54f233990347bf4d6c0bb454b6f974540` restaura essas dimensões, limita a altura das árvores e deixa as copas inteiramente ao fundo. As fontes conservam suas âncoras e o estado salvo. CI e probe aprovados. A v23 continua no staging e a nova publicação aguarda autorização específica. Após publicar, confirmar a mesma cena de escolta no celular. [Recibo](runner-receipts/T2-R2-v20-refino.md#árvores-e-câmera-lateral--28112026) · [Prova Roblox](https://github.com/Sllay/Roblox-Studios/actions/runs/46163091485)

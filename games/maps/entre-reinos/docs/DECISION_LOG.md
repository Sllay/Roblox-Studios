# ENTRE REINOS — REGISTRO DE DECISÕES

A partir de 21/11/2026 cada mudança de escopo, mecânica ou regra fixada deve aparecer aqui antes de código novo.
Estados: FIXADO, PROPOSTA, FUTURO, ABERTO. Criador tem prioridade sobre sugestões antigas.

## 21/11/2026 — V0.1, concepção
- Novo jogo Roblox Entre Reinos, separado do Black Island, inspirado em microestratégia lateral mas com NPCs muito mais profundos, materiais físicos, comércio, raids e combate próprio.
- História da infecção do duque, ataques em dois lados, tutorial de defesa, coroação, reconstrução, muralhas em anéis, dois armazéns, relações, portais, reinos interligados e seis slots.
- Solo inicial e PvP/guerras/conquista no futuro.

## 21/11/2026 — V0.2, correção visual e econômica
- SUBSTITUI proposta anterior de camadas com parallax: o cenário todo é 3D real com Terrain, inclusive fundo distante e fundo interativo.
- Silhuetas 3D do primeiro plano são preto absoluto. Personagem R6 só caminha em X; Y serve a alturas e natação; Z não permite movimentação normal. Cima/baixo viram corpo em terra; fazem subir/mergulhar na água.
- Rios passam de fundo para frente. Pontes provisórias/reinforçadas alteram travessias por classe de NPC e montaria.
- Construção com livre colocação, blueprint e materiais progressivos entregues de inventário NPC, trabalho persistente e multiplicadores por especialidade.
- Infecção interna futura fica desativada no começo. Segredo da lore tardia deve ser guardado em documento PRIVADO.
- Planejados vídeos recompensados por até três terços de trabalho-base, opção Robux para concluir e starter pack PvE; PvP futuro não herda pay-to-win.

## 21/11/2026 — V0.3, persistência do design
- Criador solicita salvar TODAS as decisões no Git como fonte principal; Drive também aceito.
- Criados Bíblia de Design, este registro, IDs pendentes; regras AGENTS garantem consulta antes de alterações.
- Recebidos os números 10769712413 e 90623742498445. Pela ordem, provavelmente Universe e Place do Entre Reinos, mas não verificados pela API do Roblox; nenhuma publicação deve usar os IDs sem confirmação.

## 21/11/2026 — V0.4, temporadas, runners e entrega final
- FIXADO: 3 temporadas de producao, com 3 runners por temporada. Runner = varias integracoes completas, validacao verde, commit e checklist, sem avancar se falhar.
- FIXADO: publicar versao de STAGING apos cada R3, pedir teste do criador e, se preciso, criar camada EXTRA de tres runners de REFINAMENTO da mesma temporada. Nao adiantar a proxima temporada.
- FIXADO: entrega final depois das tres temporadas deve ser jogo completo medieval solo, nunca MVP descartavel; sistemas modulares e extensíveis desde o começo.
- PROPOSTA: escopo distribuido entre T1/T2/T3 e nove runners no arquivo SEASON_RUNNERS.md; protocolo RUNNER_PROTOCOL.md e estado real RUNNER_STATUS.json.
- ESTADO: somente documentacao de planejamento criada; nenhum runner foi implementado, validado ou publicado por este commit.

## 21/11/2026 — V0.5, pesquisa aprofundada e realocacao das temporadas
- FIXADO: corrigir escopo V1. T1 = Fundação. T2 = FINALIZAÇÃO de todos os sistemas essenciais e ciclo completo do jogo medieval solo. T3 = novo CONTEÚDO, variantes e POLIMENTO, sem obrigação de criar do zero portais/infecção/diplomacia que devem estar prontos na T2.
- FIXADO: antes de executar cada runner, coletar links e mecânicas de Kingdom e do próprio Roblox-Studios, identificar números/lógicas confiáveis e lacunas, adaptar em Luau com algoritmos próprios; registrar uma cronologia que qualquer modelo/agente possa continuar.
- PESQUISA: SongZcode/kingdom-two-crowns-mechanics 2.4.2 rev23529; mods FredApps, abevol, minwoong; Wiki e guia, oficial Raw Fury e Roblox Creator Hub. Evidência A/config, N/static, O/comunidade, P/editor, R/API, H/projeto próprio e U/sem comprovação.
- ENTREGAS DOCUMENTAIS: docs/research/RESEARCH_SOURCES.md; MECHANICS_AUDIT.md (27 dominios); ROBLOX_ADAPTATION.md (contratos/equacoes próprias); RESEARCH_GAPS.md; SOURCE_REGISTRY.json; docs/AGENT_HANDOFF.md; SEASON_RUNNERS.md V2.
- STATUS: nenhum runner de gameplay iniciado, integrado, validado, publicado. Git docs de pesquisa não validam jogabilidade. Receipts reais serão acrescentados por runner.

## 21/11/2026 — T1-R1 revisão para teste antecipado em staging

- Criador autorizou expressamente publicar o T1-R1 em staging para testar antes do encerramento da temporada, sem T1-R2 adiantado, sem produção.
- Identidade do destino comprovada via API Open Cloud autenticada (versão Roblox 1): Universe 10769712413, Place 90623742498445, run 44975065621.
- Cena remota inventariada em 44975381075, total 179 instâncias padrão, baseline 0b52f3641643afdc4d547d83339161f79b57ed38dfe03eb0dc67ce0aeffa96cd, sem conteúdo de outro jogo.
- Aprovação de substituição da cena **padrão desse Place de testes** via manifesto `fullPlaceBuildAuthoritative` após inventário; `publish.yml` mantém confirmação manual e revisão de sync; não autoriza mexer no Black Island.
- T1-R1 continua `in_progress` até usuário executar testes no Roblox/mobile e corrigir defeitos. Desenvolvimento T1-R2 aguarda aceite.

## 21/11/2026 — Staging T1-R1 publicado para playtest do criador
- Confirmado `SUCCESS: Place 90623742498445, revision 2` do upload via API do workflow oficial https://github.com/Sllay/Roblox-Studios/actions/runs/44975639993.
- Leitura independente da versão salva retornou v2 e todos os 11 nós de T1-R1, https://github.com/Sllay/Roblox-Studios/actions/runs/44975725822.
- Baseline da cena padrão anterior v1 foi capturado e auditado, sem alterações no Black Island ou produção.
- O T1-R1 **não** está validado; testagem real de física/água/câmera/R6 e seis DataStore slots no mobile pendente.

## 21/11/2026 — Hotfix R6 v3 e independência de Avatar Settings

- O criador reportou que a revisão 2 recusava criar o mundo exigindo Avatar Settings R6; era bloqueio do nosso código, não problema do jogador.
- FIXADO: os personagens R6 do Entre Reinos devem nascer com rig real produzido pelo servidor e serão independentes do avatar inicial (R15/R6) configurado na experiência.
- Não falsificar rig modificando `Humanoid.RigType`; usar API `Players:CreateHumanoidModelFromDescriptionAsync` após verificação oficial.
- Colocar produção do R6 antes de `SaveSlotService.create/open` para garantir que erro não afete persistência.
- Publicação staging 3 confirmada em https://github.com/Sllay/Roblox-Studios/actions/runs/44976293591; readback independente https://github.com/Sllay/Roblox-Studios/actions/runs/44976379375. R6 em cliente e gameplay ainda requerem teste do criador.

## 21/11/2026 — T1-R1 restauração de sessão v4
- Usuário reportou bug real na versão 3: erro `server_operation_failed` após criar Mundo 1, mas save Dia 1 existe, então `world_already_active` bloqueava a entrada.
- FIXADO: o save permanece intacto; entradas posteriores no **mesmo slot ativo** devem ser recuperáveis e idempotentes, nunca criar outro save ou regenerar o Terrain sem necessidade.
- FIXADO: erros de entrada têm estágio diagnóstico e caminhos de retry explícitos; em falha do Terrain o lease deve ser liberado com cautela.
- V4 publicada em https://github.com/Sllay/Roblox-Studios/actions/runs/44978003846; readback da versão e código de recovery confirmado https://github.com/Sllay/Roblox-Studios/actions/runs/44978130381. Confirmação em partida real continua pendente.

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

## 22/11/2026 — T1-R1: bug de `record.seed` e separação definitiva lobby/partida

Criador enviou Developer Console v5 comprovando `Boot:101 attempt to index nil with 'seed'`, solicitou abandonar geração no lobby, usar outro servidor reservado do mesmo Place, loading opaco com progresso real, chunks iniciais e streaming do restante, 1 jogador no lobby e nos mundos por enquanto.

- **FIXADO**: a expressão condicional Luau que descartava o segundo retorno foi substituída por `if/else` com captura explícita dos valores; saves existentes não são apagados.
- **FIXADO**: lobby público não cria lease de mundo; servidor reservado `ReservedServerId` opera Terrain/R6/Save. Mesma experiência/Place em outro servidor, sem criar Place extra. Ticket conferido por servidor, com seed somente do DataStore.
- **FIXADO**: GUI lobby+teleporte+loading totalmente opacos e progresso real por atributos; chunks iniciais 2,3,4 e chunk1 quando exploração avança.
- **Observado via Open Cloud readback da publicação v6**: `Players.MaxPlayers=1`. Não foi necessário alterar limite; hard gate 1/servidor também foi implementado. Capacidade futura multiplayer fora de T1-R1.
- **Prova**: CI https://github.com/Sllay/Roblox-Studios/actions/runs/45030168933, release https://github.com/Sllay/Roblox-Studios/actions/runs/45030363476, readback https://github.com/Sllay/Roblox-Studios/actions/runs/45030586488. Teste de teleporte com Player no app Roblox ainda pendente; runner não finalizado.

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

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


## 22/11/2026 — T1-R3 UI de jogo, não painel de desenvolvimento
- FIXADO pelo criador, após playtest da staging v12: a barra de nove botões e os menus flutuantes dev obstruem a visão, não explicam recursos, saldo, opções, crafting nem ações. Código sem apresentação utilizável não constitui experiência de jogo aceita.
- UX de jogo mobile/PC: HUD discreto persistente para dia, estado da ameaça, moedas, flechas e materiais realmente disponíveis; dois controles de combate fora dos botões nativos de joystick/salto; ação contextual para interações; painel único da vila com abas de obras, fontes/estoques, cidadãos e oficina; custos, requisitos, progresso e falhas em português. Sem janelas dev abertas automaticamente.
- Diagnóstico de FPS/seed é opção opt-in, inicialmente desligada; preserva o recurso para medir desempenho sem ocupar a tela em jogo normal.
- Fontes de materiais pertencem à vila, bolsas dos trabalhadores são outro custodiante e material entregue à obra não está mais livre. Não apresentar fontes distribuídas no mapa como inventário pessoal do jogador; não habilitar ação apenas com base em um total global quando requer proximidade.
- Preservar simulação, economia, slots, Terrain e natação. Validar CI e UI no mobile em staging antes de encerrar T1-R3.


## 22/11/2026 — Auditoria de completude dos 3 ciclos e proteção de escopo
- [FIXADO] O criador pediu inspeção dos sistemas incompletos e das mecânicas cuja conclusão não esteja claramente atribuída a um runner. Não terminar T1/T2/T3 e descobrir só depois que o jogo está quebrado ou composto por placeholders.
- [DECISÃO DE ENGENHARIA] `docs/FEATURE_COMPLETENESS_AUDIT.md` registra 58 requisitos de lançamento medieval solo, com um owner e uma definição verificável de conclusão, e expõe os gaps atuais. A CI recusa requisitos órfãos e falsos `VALIDADO`, além de verificar o fechamento cumulativo.
- [FIXADO] T1 pode entregar fundação, mas nenhum fundamento parcial pode ser declarado concluído; refinamento fica na mesma temporada. Até T2 todos os sistemas base devem estar COMPLETOS, T3 é variedade/polimento. Nenhuma aprovação sem Roblox/mobile quando pertinente.
- [ABERTO] Morte/respawn/política de drops, mundo descarregado, remuneração/impostos, parâmetros de montarias, portal e decisões de balanceamento precisam de aprovação de design; não esconder lacuna com valor aleatório.
- [FIXADO] Exclusão de saves permanece voluntária/confirmada; schema de dados separado de revisão do Place. Implementar migrações recuperáveis e política de backups antes de alterações destrutivas.


## 23/11/2026 — T1-F1: a madeira da vila NÃO é automaticamente do jogador
- [EVIDÊNCIA] A UI v14 mostrava madeira regional e impedia silenciosamente a fabricação quando não havia fonte ou galpão no raio do avatar. Jogador reportou que não conseguia criar nenhuma flecha apesar do número de madeira no HUD.
- [FIXADO] Estado inicial de inventário do jogador é separado de fontes naturais, estoques de galpão, bolsas dos NPCs, reservas e materiais já gastos. Coleta física e transferência em galpão têm validação do servidor; criar flechas consome 2 unidades realmente carregadas, produz 6 flechas, aplica capacidade/cooldown e funciona longe da fonte quando o item está na bolsa.
- [FIXADO] Atualização de save compatível deve migrar por adição sem apagar/recriar mundos antigos; revisão de Place não implica novo DataStore. O menu informa quantidade da bolsa e caminho até árvore acessível, sem esconder/desabilitar ação sem explicação.
- [ESTADO] v15 publicada somente em staging, testes Luau/CI e motor Roblox passados; jogo mobile do criador ainda não aprovado. A nova preocupação do criador reforça a auditoria ER-001…058: T1-F1/F2/F3 antes de T2-R1.

## 23/11/2026 — execução candidata T1-F1

- [TÉCNICO] O ruleset 2 identifica o armazenamento de castelo inicial e trabalhos com retirada de galpão. O save anterior é copiado por revisão antes da promoção. Formato e gerador continuam em 1. Publicação/recuperação ainda exigem evidência do ambiente.
- [ABERTO] Cancelamento após entrega pode devolver itens ao estoque de origem, exigir recolhimento físico ou aplicar uma fração aprovada. A primeira opção exige tratar lotação e galpão destruído. A segunda mantém o material no mapa e exige trabalho de recolhimento. A terceira precisa de justificativa de custo. O candidato permite cancelar antes da entrega.
- [ABERTO] A divisão do estoque de uma ruína entre perda, roubo e material recuperável continua pendente. A custódia isolada preserva a contabilidade e impede consumo até definição da divisão.

- [PROVISÓRIO PARA STAGING] Cancelar obra incompleta converte cada material entregue em uma pilha recuperável no ponto da obra. A provisão evita perda e crédito simultâneo a outros estoques. O procedimento definitivo de estorno e a partição das ruínas continuam [ABERTO].

## T1-F2 — política provisória de recuperação

- [PROVISÓRIO PARA STAGING] O jogador retorna ao castelo com os recursos preservados. A ficha do morador morto conserva a carga e o equipamento fora da economia ativa. Retomar um slot entre morte e respawn aplica a mesma recuperação.
- [ABERTO] Retenção total preserva progresso e reduz impacto da derrota. Uma perda parcial recuperável introduziria risco e exigiria um depósito físico persistente que só pode ser reivindicado uma vez. Uma penalidade irreversível exigiria regra explícita de balanceamento. O destino definitivo da ficha dos moradores e a partição de ruínas continuam sujeitos à aprovação do criador.


## 24/11/2026 — Feedback v17: refinamento profundo de movimento, combat e mundo
- [FIXADO PELO CRIADOR] NPCs R6 devem usar animações clássicas da Roblox, não senoides impostas em Motor6D. Moradores ociosos caminham livremente em área 3D real nos eixos X/Z dentro das muralhas; não podem ter pistas de Z fixas por ID ou simplesmente esperar em filas. Jogador continua 2.5D.
- [FIXADO] NPCs humanos têm pele natural em gradiente claro→bronzeado→marrom escuro, nunca preta/branca pura. Inimigos iniciais são **humanos corrompidos** e o nobre infectado também permanece humano, visualmente reconhecível. Equipamentos reais e armas visíveis.
- [FIXADO] Botão de interação contextual; tocar interage, manter pressionado marca/desmarca árvore com confirmação e feedback discreto, sem ProximityPrompt/texto persistente encobrindo o jogo.
- [FIXADO] Hotbar com ESPADA e ARCO, munição numérica no arco, botão único de ataque. Espada anima e deixa rastro; arco tem alcance escalado por tempo de carga do botão e previsão parabólica com gravidade, dispara ao soltar.
- [FIXADO] Nova missão fala com duque, interação de proximidade abre diálogo original com câmera aproximando os dois em painel de RPG (estética geral de Stardew Valley sem copiar arte), duque explica seu passeio fora do castelo; só após diálogo a escolta começa.
- [FIXADO] Mundo com 17 chunks totais (um central e oito para cada lado) de 64 studs; iniciar com 5 (central, dois para cada lado), expandir progressivamente conforme deslocamento; preserve áreas/seeds/saves existentes e avalie streaming mobile.
- [ESCOPO] Nova rodada de refinamento da T1 após v17: T1-F4/F5/F6; T2 bloqueada. Proposta técnica detalhada: `docs/T1_V17_CREATOR_PLAYTEST_REFINEMENT.md`.

## 25/11/2026 — Avaliação da v18 e preparação técnica de T2-R1

- [ESTADO] O criador avaliou positivamente a v18 como fundação e autorizou iniciar o trabalho técnico de T2-R1. O aceite de fundação é registrado separadamente do fechamento da T1.
- [ESTADO] A certificação ER-001–020 continua pendente. A preparação segue em branch isolada, com ensaios sem gravação do Place. O staging continua v18 e o gate cumulativo permanece ativo.
- [ABERTO] Escala final das regiões, progresso de regiões distantes, balanceamento e custos de montarias e embarcações. Os valores do laboratório são provisórios.

## T2-R1 — políticas provisórias do candidato

- [PROVISÓRIO] A população distante preserva estoque, reservas, saúde e tarefas com o relógio local parado. Avanço agregado com orçamento por ciclo permanece uma alternativa de design, condicionada a regras de produção, déficit e recuperação.
- [PROVISÓRIO] A passagem reforçada permite montaria com capacidade controlada. Se o tabuleiro cair sob um agente, a recuperação usa a última margem comprovada e mantém sua carga. Custos, capacidade e recuperação definitiva aguardam playtest.
- [PROVISÓRIO] O cavalo custa 12 moedas e o barco opcional liga as duas docas do rio do Vale. O transporte de carga inicial aceita madeira. Viagem rápida exige visita às duas capitais e confirmação do save do destino.
- [ABERTO] Balanceamento e aparência em partida, parâmetros de montaria e barco, escala final e política de tempo distante. As decisões da T1 sobre perdas permanecem no gate próprio.

## 25/11/2026 — Certificação individual e regras de recuperação em avaliação

- [ESTADO] O aceite da v18 como fundação permite o trabalho técnico em branch. Os requisitos ER-001–020 continuam sujeitos às respectivas evidências e à certificação individual.
- [PROPOSTA] Retorno ao castelo com equipamento preservado e, se aprovado, perda parcial de moedas para uma bolsa recuperável uma vez. Permanecem abertos o valor, a duração, as permissões de coleta e as consequências de derrota. O candidato conserva carteira e bolsa e encerra apenas o vínculo do jogador morto com o veículo.
- [PROPOSTA] Liberar reservas no cancelamento e permitir que trabalhadores recuperem materiais entregues. A regra provisória usa pilhas físicas. Em ponte, a pilha fica na margem de trabalho da população proprietária. O cancelamento de um reforço em andamento depende da regra de crédito dos materiais reaproveitados.
- [ABERTO] Na ruína de galpão, definir o destino do roubo e a partição configurável entre perdido, roubado e recuperável. Até essa decisão, o estoque permanece isolado e uma reparação não recria recursos.
- [PROPOSTA] Economia agregada em regiões distantes durante uma sessão ativa, com custódia e progresso confirmados por região. O tempo de save fechado continua uma decisão independente. [Mapa T2-R2](T2_R2_INTEGRATION_MAP.md)

## 25/11/2026 — Prévia de desenvolvimento da T2-R1 autorizada

- [AUTORIZADO PELO CRIADOR] Uma publicação intermediária do candidato `f7d4ac685f2372d066cdf49a19b2b978f2454745` do PR #13 para playtest, antes de R3. O fluxo usa uma experiência isolada e preserva a v18. A exceção está no [protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1).
- [ESTADO] A inspeção oficial confirmou um único Place no Universe da v18. Falta provisionar uma experiência independente e sua chave restrita. [Inventário Roblox](https://github.com/Sllay/Roblox-Studios/actions/runs/45681890920)

## 25/11/2026 — Staging existente autorizado para a prévia T2-R1

- [AUTORIZADO PELO CRIADOR] O Universe `10769712413` e o Place `90623742498445` são o ambiente de desenvolvimento. Publicar a prévia do SHA `f7d4ac685f2372d066cdf49a19b2b978f2454745` nesse destino, substituindo a v18. Usar credenciais e ferramentas existentes.
- [AUTORIZADO PELO CRIADOR] Migrar saves compatíveis de ruleset 3 para 4 com o backup, a validação e a recuperação existentes. Preservar os seis slots. A autorização não inclui excluir saves.
- [ESTADO] A decisão substitui o plano de Universe separado. Certificação visual ocorre após publicar a prévia. [Protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1)

## 25/11/2026 — Playtest parcial da v19 e continuidade

- [CONFIRMADO PELO CRIADOR] Construção das duas categorias de ponte, travessia do jogador exclusivamente na reforçada e exploração de múltiplos biomas. Ajustes visuais dos biomas ficam para refinamento posterior.
- [AUTORIZADO PELO CRIADOR] Iniciar T2-R2 usando a base da v19. Produção recebe parâmetros provisórios em desenvolvimento. Certificação cumulativa e autorização para nova prévia permanecem próprias.

## 25/11/2026 — Parâmetros provisórios da T2-R2

- [PROVISÓRIO] Preços variam por estoque dentro de limites. Salário de uma moeda por dia quando a tesouraria tem saldo e imposto de uma moeda a partir de quatro na bolsa do morador. Tributo custa três moedas; acordo reduz a unidade do valor do frete.
- [PROVISÓRIO] Plantio usa um grão e colhe quatro. Crescimento leva 30 s de simulação irrigada e é mais lento em solo seco. Reposição dos frutos é limitada e depende de tempo de sessão. Dois animais preservam o piso de reprodução.
- [ESTADO] A produção distante roda durante sessão ativa. O avanço offline continua em aberto. Nenhum destes valores equivale a balanceamento final aprovado.

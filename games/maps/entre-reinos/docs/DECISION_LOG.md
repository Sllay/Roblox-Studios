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

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

# ENTRE REINOS — PROGRAMA OFICIAL V2: 3 TEMPORADAS, 9 RUNNERS

21/11/2026. Estado: PLANEJADO (sem runner executado). Este arquivo SUBSTITUI a distribuição de escopo anterior. Contrato do criador: T1 FUNDACAO, T2 FINALIZACAO DOS SISTEMAS, T3 CONTEUDO + POLIMENTO. Ao fim de T2, TODOS os sistemas centrais devem estar funcionais e integrados. T3 nao pode ser usada para consertar uma arquitetura descartavel da T1/T2. Ao fim de T3, jogo medieval solo completo para lançamento com autorização.

## Regras inalteráveis
- Cada temporada possui R1, R2 e R3. Cada runner entrega multiplos sistemas integrados de verdade, testes, correcoes, recibo e commit antes de passar ao proximo.
- Nao adiantar gameplay de runner/temporada seguinte. E PERMITIDO desenhar interfaces versionadas para uso futuro, mas nao implementar funcionalidade secreta/prematura.
- Runner verde precisa de testes evidenciados e versao salva no Git; CI de compilacao nao substitui testes no Roblox real/mobile.
- Apos R3: publicar no STAGING verificado, registrar versao, chamar criador para testar, receber opiniao. Se reprovado, criar 3 runners de REFINAMENTO da temporada atual (F1 F2 F3), sem adicionar escopo novo de temporada seguinte. Somente apos aprovacao seguir adiante.
- Publ. PRODUCTION somente depois de T3 + refinamentos + autorizacao explicita. Black Island totalmente isolado. IDs staging pendentes de verificacao e jamais presumidos.
- O design de TODOS os sistemas nasce modular e orientado a dados (geracao, biomas, itens, receitas, estruturas, NPCs, loot, monstros, montarias, correntes, raids, comercio e save), evitando gambiarras. T1 estrutura e funcionamento do núcleo; T2 completa todos os processos e integrações; T3 amplia repertorio e experiencia.

## Pré-run obrigatório: pacote de pesquisa e engenharia
1. Ler repositorio próprio: AGENTS.md, docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md, docs/TERRAIN_BUILDER.md, docs/SCENE_SYNC.md, docs/DEPLOYMENT.md, docs/QUALITY_GATE_V2.md, asset-library/ e games/maps/entre-reinos/ (GDD, ARCH, VISION_MASTER, log).
2. Ler docs/research/RESEARCH_SOURCES.md e MECHANICS_AUDIT.md, abrangendo SongZcode 2.4.2, wikis, guias, mods FredApps/abevol/minwoong, descricao oficial Raw Fury e os limites.
3. Ler docs/research/ROBLOX_ADAPTATION.md (contratos, equacoes proprias e testes). Nao portar GameAssembly, DLL, sprites, arte, C# de mods nem formulas numericas fora do escopo.
4. Registrar dúvidas, fontes e lacunas em docs/research/RESEARCH_GAPS.md; verificar documentacao de Roblox no momento da execução.
5. Atualizar docs/AGENT_HANDOFF.md, docs/RUNNER_STATUS.json e evidencias ao terminar cada runner. Toda nova pesquisa precisa de link, fonte, versão, escopo, nivel de evidência e se aplica a qual runner.

# TEMPORADA 1 — FUNDAÇÃO DO JOGO (sistemas centrais reais)

Meta: funcionamento real dos alicerces sem sistemas descartaveis: mundo 3D, movimentos, sistemas de inventario, NPC/trabalho, construcao, combat/salvar e defesa inicial. Nao fingir completar tudo em scripts monoliticos; extensibilidade testada desde R1.

## T1-R1 — Arquitetura real do mundo e controladores
Ordem de integração:
1. Estrutura Roblox/Luau por dominios e contratos de rede; schema de mundo por seed/gerador, simulacao de regioes e coordenadas X/Y/Z.
2. Terrain nativo gerado em regiao inicial, rio cruzando trilho, background 3D distante e interativo, foreground 3D preto sem oclusao de personagens. Reservas de vilas e rotas para expansão.
3. Camera lateral, R6 X, rotação cima/baixo em terra sem andar Z, corrida/salto, Humanoid Swimming com cima/baixo Y e diagonais X/Y naturais, transições água/terra.
4. Interface principal Play/Options/Voltar e seis slots reais, versionamento, session locking e persistencia por mundo com recuperação de erro. Validacao de todo objeto marcado como saveable.
5. Ferramentas de debug, benchmark de FPS/rede/memoria em cliente real e testes de mundo deterministico.
Leitura EXTERNA: K2C-RE01 README + evidence + travel/controls, K2C-WIKI11, K2C-UX01, RBX-01, RBX-02, RBX-03/04, RBX-05/06. INTERNA: OUR-01/02/03/04/05.
Gate: seed igual->região igual; seis slots não se cruzam; erro de save não apaga progresso; nenhuma entrada desloca Z; água funciona em runtime Roblox e mobile; visuais totalmente 3D; build e testes completos.
FORA: NPCs produtivos, economia, raids, portal final, relações, montaria.

## T1-R2 — Fundação da vida, inventários e construções
Ordem:
1. Identidade R6 NPC, aparência/roupa curada, registro de NPC/skill/needs/health/equipment/inventory com peso.
2. Engine de trabalho modular por utility + FSM, ordens por proximidade/rota, prioridade/urgencia/skills/carga/fadiga/risco e agendamento/LOD por grupos.
3. Recursos madeira/pedra/alimento/ferro e transferencias, reserva transacional, entrega direta de mochila NPC à obra e armazéns com capacidade.
4. Placement livre (footprint, slope, espaço, terreno, rota), blueprint com entrega progressiva por material; trabalho de construção separado, cumulativo e salvo; profissões carpinteiro 3x madeira, minerador 3x pedra, construtor universal 2x, comum 1x; ferramentas e tempo real.
5. Muralhas em niveis, abrigo/casas, galpões, danos/reparos básicos e distritos em aneis, alimentando dados da AI. Modularizar RecipeDefs, JobDefs, StructureDefs, ProfessionDefs e ItemDefs.
Leitura EXTERNA: K2C-RE01 builders/economy + data/parameters, K2C-WIKI03/04/05/12/18, K2C-MOD01 capabilities (campos e eventos). INTERNA: OUR-02/05/06, ROBLOX_ADAPTATION.
Gate: múltiplos NPCs cooperam sem duplicar material; local sem storage funciona; obra pausa e continua após sono/load; inventário respeita massa; nova construção/receita via registry; NPC não oscila/vibra; erros e CPU instrumentados.
FORA: comércio avançado, montarias, boss, diplomacia.

## T1-R3 — Fundação de combate, defesa, moeda e prólogo
Ordem:
1. CombatEngine X/Y para jogador e NPCs, armas básicas e arcos com velocidade/gravidade Roblox; munição e colisão servidor.
2. EnemyBase e primeiro comportamento de ataque/saque, danos a muros/casas/galpões e abrigo/fuga/defesa de cidadãos, perda parcial e salvage sem duplicação.
3. Relógio dia/noite e RaidDirector LOCAL, avisos e noites sem raid, incapacidade de atravessar muralha intacta. Demais objetivos/portais completos ficam T2.
4. CurrencyLedger/bolsa fisica com drop/pickup/colisões visuais locais mas contabilização no servidor; pequenos contratos de geração de moedas sem árvores spawnando dinheiro.
5. Prologo jogavel do nobre infectado roteirizado, ataque dos dois lados, evacuação, último anel e coroação; UI de ordens/defesa e salvamento da crise em seis slots.
Leitura EXTERNA: K2C-RE01 archers/greed/economy/waves, K2C-WIKI02/06/07/08/19, K2C-GUIDE01, K2C-MOD02 overlay/UI. INTERNA: ROBLOX_ADAPTATION e QUALITY_GATE_V2.
Gate: nova campanha -> prologo -> cidade reconstruída -> raid -> recuperação -> save/load; tiro e dano verificados; saldos e loot sem duplicação; mortalidade justa, FPS mobile documentado.
MARCO: publicar T1 somente STAGING, pedir validação do criador; eventualmente T1-F1/F2/F3. Não iniciar T2 enquanto T1 reprovada.

# TEMPORADA 2 — FINALIZAÇÃO DOS SISTEMAS E DO LOOP COMPLETO

Meta: TODOS os sistemas de jogo prometidos para o lançamento MEDIEVAL SOLO completos e integrados, não meros esqueletos: mundo contínuo de reinos, economia produtiva, profissões, relações, montarias, pontes, portais, ameaças, estratégia, diplomacia e progresso de longo prazo. T3 não resgata funcionalidade essencial incompleta.

## T2-R1 — Mundo completo, biomas, logística e viagens
Ordem:
1. Engine procedural multi-bioma por registros com rios/cachoeiras/costas/colinas/florestas e sub-regiões caminháveis entre reinos; decoração/vegetação 3D e distribuição coerente de recursos.
2. Rivers atravessáveis em 2.5D, fundo 3D com cursos de água, riachos rasos; pontes leves vs reforçadas com permissões, capacidade, custo real e grafo de rotas.
3. Streaming/LOD real e persistência de regiões; reinos distantes simulados via estado agregado, reconciliação do estado quando se aproxima, NPC nunca duplicado.
4. Montaria terrestre (compra/domesticação, vitalidade/energia, velocidade/terreno e regras água/ponte), barco/doca/fast travel em nível funcional conforme geografia aprovada.
5. Infraestrutura para duas ou mais cidades NPC e distritos, recursos/rotas e salvamento sem apagar estrutura customizada.
Leitura EXTERNA: K2C-RE01 mounts/travel/evidence/time, K2C-WIKI08/09/10/13, K2C-MOD01 custom-challenges + mount-modding, RBX-01/05/06. INTERNA: TERRAIN_BUILDER/SCENE_SYNC/ASSET_WORKFLOWS.
Gate: jogador anda entre reinos sem mudar de mundo; geração por seed, biomas e movimento mobile/streaming reais; NPC não cruza rio profundo sem ponte válida; instâncias distantes não sobrecarregam.

## T2-R2 — Finalização da economia, profissões, sociedade e diplomacia
Ordem:
1. Profissões e crafting completos: ferreiro/artesão/agricultor/caçador/minerador/carpinteiro/construtor/transportador/guarda, treinamento, ferramentas, nível e prioridades.
2. Cadeias produtivas extensíveis de madeira, pedra, minério, metal, comida, arma, galpões, entregas e construção complexa; fazenda perto de água e consumo/sustento de vila.
3. Mercado, moedas e preços por oferta/demanda, contratos de venda/comércio entre reinos, impostos/tributos/salários, tesouraria e orçamento dos reinos NPC; consistência contábil.
4. NPCs com estado social individual, relacionamento entre NPCs/jogador, confiança, presente, resgate, eventos e reações, sem LLM obrigatório.
5. Reinos NPCs com economia própria, relações de facção, alianças/hostilidade, diplomacia, intercâmbio e resposta à crise; tudo persistente e operante em simulação distante.
Leitura EXTERNA: K2C-RE01 economy/builders/travel, K2C-WIKI05/12/15/16, K2C-MOD01 capabilities, RBX-03/04, guia Steam. INTERNA: contratos de Inventory/Jobs, testes de economias do T1.
Gate: extração -> fabricação -> distribuição -> consumo -> venda -> imposto/tesouro verificável; não há moedas brotando de árvores; NPC relações mudam decisões; reinos mantêm economias estáveis pós-save; sem inflação/duplicação.

## T2-R3 — Finalização dos inimigos, portais, conquista e campanha
Ordem:
1. Enemy/Portal/Threat registries completos: ataques, saque, infecção de fauna e humanos, progressão da ameaça e objetivo, portais que ameaçam reinos vizinhos, boss BASE.
2. Direção/frequência de raids e estratégia por risco/orçamento, ataque e contra-ataque de reinos vizinhos, expedições para destruir foco; inimigos diurnos onde previstos. Infecção interna só com sinais, cura/isolamento e proteção robusta de iniciantes.
3. Sistema de comando/guarnição e exércitos solo; diplomacia hostilidade/aliança operante, combate contra reino NPC, conquista, gestão de múltiplos reinos, fusão/reorganização territorial sem apagar estruturas; rotas/fast travel persistentes.
4. Metas de progressão do medieval completo: objetivos e encerramentos de arco de campanha, decisões e riscos reais, balanceamento amplo de tempo/raid/construção/recursos.
5. Teste integrado de TODOS os sistemas T1 e T2 em múltiplos saves, relógios e reinos, com recuperação após morte, crash e mudança de região.
Leitura EXTERNA: K2C-RE01 greed, archers, waves, travel, FAQ e evidence; K2C-WIKI07/08/09/10/19; K2C-MOD01 capabilities; RBX-03/05/06. INTERNA: todos os receipts T1/T2 e ROBLOX_ADAPTATION.
Gate: todos sistemas centrais de lançamento já funcionam; nenhum módulo-base incompleto deixado para T3; portal entre dois reinos altera direções; atacar/dominar reino NPC e salvar é funcional; infecção não destrói save injustamente; boss básico e campanha completa testáveis.
MARCO: publicar T2 STAGING, chamar criador; refinar T2-F1/F2/F3 se necessário. Não iniciar T3 enquanto T2 não estiver aprovada.

# TEMPORADA 3 — CONTEÚDO, VARIEDADE, POLIMENTO E LANÇAMENTO

Meta: NÃO reescrever a fundação. Adicionar conteúdo real aos sistemas T1/T2, variantes, polimento visual/sonoro e refinamento técnico, balancear para longa vida, monetização opcional e preparar versão comercial.

## T3-R1 — Conteúdo de mundo, população e construções
Ordem:
1. Ampliar catálogo de biomas, regiões, rios, bosques, montanhas, solos e recursos; composição visual consistente 3D e decorações de silhueta preta.
2. Novas casas e níveis, fortes, oficinas, pontes, muros/torres, receitas e equipamentos; variantes por facção/bioma sem duplicar código.
3. Novos tipos de NPCs, roupas R6 e variabilidade de perfis, padrões sociais, linhas de trabalho e eventos de relacionamento; novas montarias e fauna.
4. Mapas e localidades memoráveis, vilas/tribos novas, objetivos de exploração, recompensas e pontos de interesse.
Leitura EXTERNA: K2C-RE01 builders/mounts/economy, K2C-WIKI03/10/13, K2C-MOD01 challenge/island mods; guias de assets e performance Roblox. INTERNA: cada registry e receipts T1/T2.
Gate: adicionar novo bioma/mob/casa por dados/catálogo é possível; não quebra seeds existentes, saves ou performance; arte estilizada consistente aprovada visualmente.

## T3-R2 — Conteúdo de combate, eventos, campanhas e economia de lançamento
Ordem:
1. Novas espécies e variantes de monstros e corrompidos, chefes de raids com fases/ataques distintos, portais especiais, eventos raros e defensores especializados.
2. Missões/eventos de facções, cooperação temporária de reinos NPCs, encontros, recompensas por exploração e desafios de longo prazo; variedade sem novos fundamentos de IA.
3. Balancear picos, probabilidades, produção e progressão de campanha; ampliar conquistas e narrativa medieval SEM divulgar lore reservada.
4. Conteúdo comercial opcional: starter pack PvE, cosméticos, montarias e Developer Products com regras justas; anúncios recompensados só após elegibilidade/documentação atual e disponibilidade. Pagar nunca permite duplicar materiais, e futuro PvP não herda vantagem competitiva.
Leitura EXTERNA: K2C-RE01 greed/waves/archers, Wiki Portal e guias de gameplay, RBX-08/09, fontes de direitos de assets. INTERNA: Economy/Raid/Portal/Transaction receipts.
Gate: bosses/eventos são conteúdo verdadeiro e extensível; não quebram campanha, saves ou cliente mobile; compra/recibo idempotente e sem abuso.

## T3-R3 — Polimento definitivo, QA, UX, otimização e release candidate
Ordem:
1. Corrigir todos os defeitos encontrados na experiência completa, câmera, movimentação R6, natação, animações, IA, rota, combates, moeda física e construção; nunca mascarar falhas.
2. Perfil/otimização real mobile/PC, streaming, render 3D, NPC scheduling, RPCs, memória, latência e UI de controle por toque, acessibilidade, áudio e VFX.
3. QA global: testes unitários, integração, simulação de longos dias, saves antigos/nova versão, failover e corrupção de dados, antiexploit, monetização, bugs de rede e regressões visuais.
4. Revisar documentação, fontes/assets/licenças, telemetry de funil/retention sem manipulação, política Roblox vigente, crash reporting, guarda de produção e plano de rollback.
5. Gerar build final em staging, registrar recibos e solicitar validação presencial/manual do criador. Caso necessário abrir T3-F1/F2/F3 para polir. Só com aprovação explícita preparar Place de PRODUÇÃO separado.
Leitura EXTERNA: Roblox Performance/Test-on-hardware/DataStores/Ads/Avatar/Terrain; revisão de K2C sources para bugs e comportamento alvo; INTERNA: todas as evidências de T1/T2/T3, Scene Sync/Deployment, VISION_MASTER e QA.
Gate: jogo medieval solo completo, jogável, com evolução durável, sem falhas de save/duplicação, controle mobile e aspectos de gameplay/visuais aprovados pelo criador.

## Ciclo de refinamento da mesma temporada (após R3)

F1: inspeção de bugs e diagnóstico da temporada atual com reprodutores e testes.
F2: correção de causa raiz, UX, animação, IA, balanceamento e desempenho APENAS do escopo existente.
F3: regressão global, revalidação, integração e nova publicação staging, com nova revisão do criador.
Pode repetir camada com IDs diferenciados se necessário; nenhum F adiciona feature da próxima temporada.

## Testes e rastreabilidade

Fonte de pesquisa: docs/research/RESEARCH_SOURCES.md.
Matriz de observações: docs/research/MECHANICS_AUDIT.md.
Algoritmos e contratos Luau originais: docs/research/ROBLOX_ADAPTATION.md.
Lacunas: docs/research/RESEARCH_GAPS.md.
Roteiro para novos agentes/modelos: docs/AGENT_HANDOFF.md.
Protocolo de gates: docs/RUNNER_PROTOCOL.md.
Status único da execução: docs/RUNNER_STATUS.json.
Todos runners PLANEJADOS: não atribuir testes, commits de implementação ou publicação sem evidência.

## Matriz de encerramento obrigatória (auditoria 22/11/2026)

**Fonte executável de rastreabilidade:** `docs/FEATURE_COMPLETENESS_AUDIT.md`, ER-001…ER-058, verificada por `tests/test_entre_reinos_feature_completeness.py`. Cada requisito tem runner fixo, status e condição de aprovação. Essa matriz COMPLEMENTA os 9 runners sem substituí-los; a experiência só termina quando o usuário consegue executar o loop inteiro com controle real e save seguro.

**Gaps de T1 explicitamente não fechados por código v14:** NPCs devem consumir estoque do galpão nas obras, destruição/salvage de estoque depositado, construção escolhida pelo jogador, castelo + 2 galpões de início, encenação completa do duque/prologo, morte/recovery e diferença visual/funcional das fontes/árvores. Tratar em camada F1/F2/F3 antes da T2; não aprovar apenas com CI.

**Gaps que T2 TEM de resolver:** rotas/ponte, viagens/montaria, regiões e reinos vivos, profissões completas, economia/cadeias reais, evolução e relações NPCs, corrupção, portais, diplomacia, conquista solo, exércitos, campanha e save de longo prazo. Nenhum fica para T3 começar como módulo vazio.

**Gaps de T3:** conteúdo extenso/variações, áudio/visuais/UI/UX finais, balanceamento, acessibilidade, monetização justa e opcional, perf/segurança, lançamento somente após teste cumulativo ER-001…058 e aprovação explícita do criador.

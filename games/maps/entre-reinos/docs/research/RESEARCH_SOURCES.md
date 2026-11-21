# FONTES DE PESQUISA — KINGDOM TWO CROWNS PARA ENTRE REINOS

Coleta inicial: 21/11/2026. Escopo: mecanismos publicamente documentados e arquitetura própria. NÃO é cópia, extração ou autorização para reutilizar código/arte proprietário.

## Convenção obrigatória de evidência

A = configuração observada/atributo serializado, com escopo de versão específico.
N = interpretação de lógica de análise estática; NÃO é verificação do comportamento em todas as condições do jogo original.
O = observação de gameplay/documentação comunitária (pode ser inexata ou variar por versão).
P = publicação do desenvolvedor/editor (confirma descrição de produto, não os algoritmos internos).
R = documentação oficial de API Roblox.
H = hipótese/projeto ORIGINAL Entre Reinos; não atribuir ao Kingdom.
U = lacuna não resolvida ou informação insuficiente.

**Proibido dizer que estudamos o código-fonte original completo.** Foram lidas explicações públicas e documentos de projetos da comunidade; não se baixou nem executou binário, decompilador, DLL de terceiro ou jogo original. O repositório SongZcode informa análise estática de build 2.4.2 revisao 23529, Windows 64, Unity 6000.0.66f2, build 2026-09-15; parâmetros e ramos ainda carecem de validação dinâmica em diversos pontos. Sua licença CC BY 4.0 cobre apenas texto e organização originais da documentação; não licencia o jogo de terceiros. Nossas fórmulas são projetos independentes e os dados de jogo são tratados como fatos de análise, creditando a fonte.

## Fonte principal — já existe engenharia reversa documentada

**K2C-RE01** | https://github.com/SongZcode/kingdom-two-crowns-mechanics
- Tipo: pesquisa comunitária independente, documentação de mecanismos/valores de configuração e análise estática (A/N/U).
- Versão descrita: Kingdom Two Crowns 2.4.2 / revision 23529, default OakAndBirch, campanha de cinco ilhas, análise mais forte em solo.
- Arquivos obrigatórios: README.md; docs/evidence-and-limitations.md; docs/time-seasons-and-waves.md; docs/economy-and-currency.md; docs/builders-and-buildings.md; docs/archers-and-arrows.md; docs/greed-loot-and-crown.md; docs/mounts.md; docs/travel-decay-and-succession.md; docs/player-faq.md; data/reference-build.json; data/parameters.json.
- Princípio de reutilização: consultar e CITAR fatos e limites; formular nosso próprio comportamento em Luau. **Não copiar o documento nem código proprietário**. Não assumir que valores 2.4.2 valem para DLCs, outros temas, patches, dificuldades e runtime.
- Licença de texto: CC BY 4.0, https://github.com/SongZcode/kingdom-two-crowns-mechanics/blob/main/LICENSE-SCOPE.md. Exigir crédito e indicar modificações caso se reutilize redação original (aqui o texto é novo).

## Repositórios de mods e ferramentas de terceiros (leitura, sem executar)

**K2C-MOD01** | https://github.com/FredApps/KingdomMod
- Tipo: plataforma de modding MelonLoader C#/SDK para Kingdom Two Crowns; README e documentos de capacidade mostram pontos de observação e eventos do jogo, não são código a transportar.
- Ler: docs/capabilities.md, docs/feasibility.md, docs/api-reference.md, docs/custom-challenges.md, docs/mount-modding.md.
- Documenta 2.4.0 em capabilities/feasibility; diferenças de versão com RE01. A revisão 23488 aparece no estudo de viabilidade.
- Elementos relevantes: game manager/Director/Kingdom/Wallet/Player/EnemyManager/Payable/World, relógio e eventos, snapshots de biomas/ilhas e HUD de estados; arquivos de config em JSON para balanceamento; limitações de código Burst.
- Licença declarada no README: MIT para conteúdo próprio do mod, não código/arte Kingdom. NÃO instalar executáveis nem criar exceções de antivírus na pesquisa.

**K2C-MOD02** | https://github.com/abevol/KingdomMod
- Tipo: mods C# BepInEx; ler Readme.md, BetterPayableUpgrade/, OverlayMap/, StaminaBar/, DevTools/ e código de partes específicas apenas como documentação de integração, nunca portar/copiar.
- Achados: mod altera custo/tempo de edifícios, inclui HUD de stamina, minimapa e dados demográficos; isso é evidência de campos modificáveis, **não** evidência de constantes originais sem confirmar branch/build.
- Licença de uso/código não verificada nesta coleta: evitar reutilizar implementação.

**K2C-MOD03** | https://github.com/minwoong-seo/K2C-Mods
- Tipo: BepInEx IL2CPP mods para 2.4.2; KingdomHud e KingdomMenu mostram dados de stamina, juros, população, blood moon, compras e ferramentas de debug.
- Não reutilizar source/art sem revisão de licença; não instalar nada no ambiente da equipe.

**K2C-MOD04** | https://github.com/wonkotron/K2C-SpiritedAway
- Mod pequeno de supressão do fantasma tutorial; útil para entender que tutorial pode ser desligado e que UI deve ser testável sem guia contextual, não é fonte para IA/economia.

## Fontes de experiência / comunidade / editor

**K2C-OFF01** | https://kingdomthegame.com/kingdom-two-crowns/
- Descrição oficial do jogo: microestratégia lateral minimalista, monarca, montaria, recrutar, construir, defender do Greed; não fornece código ou fórmula.

**K2C-OFF02** | https://rawfury.com/games/kingdom-two-crowns/
- Publicadora e descrição geral.
**K2C-OFF03** | https://rawfury.com/kingdom-two-crowns-call-of-olympus-date-reveal/
- Comunicado de mudanças/QoL e dez saves em update anterior; lembrete: nosso projeto tem seis saves por decisão própria, nunca adotar dez por confusão.

**K2C-WIKI01** | https://kingdomthegame.fandom.com/wiki/Game_basics
**K2C-WIKI02** | https://kingdomthegame.fandom.com/wiki/Purse
**K2C-WIKI03** | https://kingdomthegame.fandom.com/wiki/Wall
**K2C-WIKI04** | https://kingdomthegame.fandom.com/wiki/Builder
**K2C-WIKI05** | https://kingdomthegame.fandom.com/wiki/Subjects
**K2C-WIKI06** | https://kingdomthegame.fandom.com/wiki/Coin
**K2C-WIKI07** | https://kingdomthegame.fandom.com/wiki/Portal
**K2C-WIKI08** | https://kingdomthegame.fandom.com/wiki/Seasons
**K2C-WIKI09** | https://kingdomthegame.fandom.com/wiki/Decay
**K2C-WIKI10** | https://kingdomthegame.fandom.com/wiki/Technology
**K2C-WIKI11** | https://kingdomthegame.fandom.com/wiki/Controls
**K2C-WIKI12** | https://kingdomthegame.fandom.com/wiki/Knight
**K2C-WIKI13** | https://kingdomthegame.fandom.com/wiki/Islands_in_Two_Crowns
- Tipo: comunidade (O). Cruzar com RE01, editor e teste de gameplay. Fandom pode bloquear acesso automatizado; marcar indisponível e usar fontes acessíveis quando isso ocorrer.

**K2C-GUIDE01** | https://steamcommunity.com/sharedfiles/filedetails/?id=1588497381
- Guia longo de jogador (O), boa base para interação observável, upgrade, classes, ilhas, banco e defesa; possui diferenças por atualizações e DLC.
**K2C-GUIDE02** | https://www.trueachievements.com/game/kingdom-two-crowns/walkthrough/2
- Tutorial/guia (O) para estratégia; conferir versão.
**K2C-UX01** | https://medium.com/@kinga.olszewska/how-a-game-that-has-almost-no-hud-elements-engaged-a-ux-ui-designer-for-hours-45d71184205f
- UX de interface minimalista. Serve para entender feedback visual; não copiar layout.

## Fontes oficiais de adaptação Roblox

**RBX-01** | https://create.roblox.com/docs/reference/engine/classes/Terrain — Terrain, água e API/voxels.
**RBX-02** | https://create.roblox.com/docs/reference/engine/classes/Humanoid — Swimming, R6, estados, animação/locomoção.
**RBX-03** | https://create.roblox.com/docs/cloud-services/data-stores — persistência e UpdateAsync.
**RBX-04** | https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing — controle de sessão e compras.
**RBX-05** | https://create.roblox.com/docs/performance-optimization/design — streaming e LOD.
**RBX-06** | https://create.roblox.com/docs/performance-optimization/test-on-hardware — teste REAL mobile.
**RBX-07** | https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService — busca de catálogo, limites.
**RBX-08** | https://create.roblox.com/docs/production/promotion/rewarded-video-ads — opt-in, elegibilidade e publicidade.
**RBX-09** | https://create.roblox.com/docs/production/monetization/developer-products — Developer Products e receipts.
**RBX-10** | https://create.roblox.com/docs/reference/engine/datatypes/CatalogSearchParams — filtros de catálogo.

## Fontes INTERNAS obrigatórias para os agentes

**OUR-01** | /AGENTS.md — regras globais, validação, Scene Sync, segurança de assets e publishing.
**OUR-02** | /docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md — template/scaffold, Rojo e estrutura multi-game.
**OUR-03** | /docs/TERRAIN_BUILDER.md e /tools/terrain_builder.py — Terrain nativo por seed/altura, margens e limites reais.
**OUR-04** | /docs/SCENE_SYNC.md, /docs/DEPLOYMENT.md — observação de Place, direitos de escrita, confirmação e rollback.
**OUR-05** | /docs/QUALITY_GATE_V2.md e /tools/script_quality.py — gate real Luau/testes.
**OUR-06** | /asset-library/, /docs/ASSET_AND_SCENE_WORKFLOWS.md, /docs/ASSET_IMPORT.md — reuso de assets aprovado, sem copiar recursos proprietários.
**OUR-07** | /games/maps/entre-reinos/GDD.md, ARCHITECTURE.md, docs/VISION_MASTER.md, docs/DECISION_LOG.md, docs/SEASON_RUNNERS.md, docs/RUNNER_STATUS.json.
Todos os caminhos OUR se referem ao repositório https://github.com/Sllay/Roblox-Studios, não a fontes do jogo Kingdom. O agente deve abrir o estado da main no momento da execução; a lista é índice, não garantia que ferramenta esteja pronta.

## Obrigações de pesquisa contínua

1. Registrar no docs/research/MECHANICS_AUDIT.md o fato, unidade, versão, fonte, condição e incerteza antes de afirmar fórmula.
2. Cada sistema adaptado ganha um contrato ORIGINAL independente em docs/research/ROBLOX_ADAPTATION.md e referência a runner designado.
3. Se a fonte descrever comportamento de outro DLC/versão, registrar como outra hipótese, sem mesclar valores.
4. A cada runner, reabrir fontes pertinentes, rever links, executar nossos próprios testes e registrar correção em docs/DECISION_LOG.md.
5. Não baixar/converter/redistribuir assets, DLLs, classes decompiladas, arquivos proprietários nem exigir instalação de mods; usar apenas conhecimento público e implementação original.
6. Não guardar documentação confidencial da narrativa no repo público.

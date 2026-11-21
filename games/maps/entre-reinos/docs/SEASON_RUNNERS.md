# ENTRE REINOS — PLANO OFICIAL DAS 3 TEMPORADAS E 9 RUNNERS

Versao 1.0, 21/11/2026. Estado: planejamento. Fonte de escopo: VISION_MASTER.md.
Objetivo final: jogo medieval solo completo, profundo, persistente, jogavel e comercializavel; NAO um prototipo com sistemas ficticios ou temporarios.

## Regras fixadas pelo criador
- Exatamente tres temporadas principais (T1, T2, T3), cada uma com tres runners (R1, R2, R3).
- Cada runner integra multiplas implementacoes reais e seus testes; nao representa uma unica chamada de IA, uma acao do GitHub ou um timer.
- Resultado funcional, modular, extensivel, sem gambiarra e sem sistemas falsos que precisem ser refeitos.
- Corrigir qualquer erro bloqueante antes de marcar runner verde e integrar sua versao validada ao repositorio. O proximo runner so comeca depois de validação real do anterior.
- NAO implementar funcionalidades do runner seguinte antecipadamente. Contratos, schemas e pontos de extensao sao permitidos, desde que nao ativem gameplay futuro.
- Apos o terceiro runner de uma temporada, publicar somente no Place de staging verificado; apresentar ao criador para teste visual e de gameplay.
- Se o criador pedir ajustes, executar camada adicional de tres runners de REFINAMENTO da temporada atual, testar, publicar staging de novo e aguardar nova aprovacao. Nao utilizar refinamento para adiantar a proxima temporada.
- Apenas depois de completar as tres temporadas e aprovar refinamentos, preparar lancamento estavel em Place production separado, com aprovacao.
- O primeiro lancamento final e um jogo medieval SOLO; PvP/co-op e segredos futuros da narrativa nao sao requisitos escondidos da entrega inicial.

## TEMPORADA 1 — A COROA E A PRIMEIRA CIDADE
Meta: jogador inicia um mundo, completa prologo, administra uma cidade realmente funcional, defende-a, reconstrói, salva e continua.

### T1-R1 — Fundacao jogavel do mundo
Integracoes:
1. Arquitetura do mundo por seed, Terrain nativo 100% 3D, fundo distante, fundo proximo interativo, faixa de personagens e primeiro plano de silhuetas pretas (sem parallax 2D).
2. Geracao inicial de assentamento/castelo, terreno, recursos, faixas de caminhabilidade e rio pequeno.
3. Camera lateral e inputs adaptados ao mobile/PC; personagem R6 caminha no X, gira para o fundo/camera sem caminhar em Z, corre, pula e ataca em prototipo de interacao.
4. Agua Terrain nadavel: cima/baixo mudam Y, diagonais combinam X/Y suavemente; transicao solo-agua confiavel.
5. Menu Play/Options/voltar, ate SEIS slots independentes, criar/carregar/excluir com confirmacao, modelo de mundo e salvamento seguro/versionado; schema orientado a evolucoes.
Modulos: WorldSeed, RegionGraph, TerrainAdapter, CharacterLaneController, SwimController, SideCamera, InputRouter, SaveSlotService e WorldSchema.
Aceite: seed reproduz mundo, seis slots nao interferem, personagem nao desliza em Z, nado vertical e diagonal funcionam no cliente Roblox, carregamento restaura estado, camera/UI legiveis no mobile. Registrar medidas reais e casos nao testados.
Nao antecipar: NPCs produtivos, comercio, raids, montarias e pontes.

### T1-R2 — NPCs, recursos e construcoes de verdade
Integracoes:
1. NPCs R6 com aparencias e roupas coerentes/compatíveis, inventario com slots/peso, equipamentos, necessidades e proficiencia.
2. Scheduler de trabalhos autonomeis por prioridade/utility e FSM de execucao, caminho lateral e anchors de interacao no fundo 3D.
3. Extracao de madeira, pedra e comida; transporte real entre inventarios, galpoes e locais de obra; estoques transacionais, reservas e limites de capacidade.
4. Posicionamento livre de casas, muralhas e galpoes com footprint e regras de solo; blueprints com entregas graduais de itens trazidos diretamente pelos NPCs.
5. Trabalho persiste entre turno, noite, ataque e save; carpinteiro 3x madeira, minerador 3x pedra, construtor 2x ambos, outros 1x; upgrades e reparos de muros.
Modulos: NPCRegistry, Appearance, Needs, Skills, Inventory, ResourceLedger, JobBoard, WorkScheduler, PlacementValidator, StructureRegistry, ConstructionSite, Districts.
Aceite: NPCs coletam e transportam recursos reais; sem duplicacao em entregas simultaneas; peso impede cargas impossiveis; obra nao inicia antes de materiais; progresso pausa/retoma e persiste; profissoes medem multiplicadores esperados; galpao lotado preserva itens.
Nao antecipar: boss/raid complexa, comercio externo, diplomacia, montaria.

### T1-R3 — Prologo, combate, economia inicial e primeira raid
Integracoes:
1. Combate direto do guerreiro; armas basicas de guardas, arqueiros e lanceiros, defesa de muralha, ordens, evacuacao e abrigo em casas.
2. Prologo jogavel do duque infectado, queda da primeira muralha, fuga de civis, ultima resistencia e coroacao; risco roteirizado e justo.
3. Dia/noite, inimigos basicos e RaidDirector LOCAL inicial com aviso, variacao de lado e noites sem raid.
4. Destruicao de edificios e galpoes com parte do estoque destruida/roubada/recuperavel sem duplicacao; salvamento e recuperacao de civis e materiais.
5. Tesouraria, bolsa/moedas com fisica visual local e transacoes monetarias iniciais coerentes — arvore nunca dropa dinheiro; tela de administracao e save/load completo do ciclo.
Modulos: Combat, EnemyAI, RaidDirector, ThreatClock, Evacuation, Salvage, CurrencyLedger, CoinVFX, StoryDirector, StoryFlags.
Aceite: ciclo novo save -> prologo -> reconstrucao -> primeira defesa -> reparo -> salvar/carregar funciona ponta a ponta; raid termina; casas e estoques sofrem consequencias reais; economia nao cria moeda por madeira; desempenho testado em cliente/mobile.
MARCO: publicar T1 em staging e pedir review do criador. Refinamento T1-F1/T1-F2/T1-F3 se necessario.

## TEMPORADA 2 — O MUNDO VIVO
Meta: biomas e reinos conectados, logistica de longo alcance, producao/comercio e NPCs com relacoes.

### T2-R1 — Mundo ampliado, biomas, rios, pontes e LOD
Integracoes:
1. BiomeRegistry configuravel e geracao 3D procedural por seed de regioes extensas, florestas, montanhas, rios, costas e recursos.
2. Rios visuais descendo do fundo, volumes Terrain Water jogaveis e correntezas opcionais; curso atravessa faixa de personagens e primeiro plano.
3. Riacho raso, travessias profundas, pontes provisoria e reforcada com custos, trabalho, durabilidade e permissoes por tipo de agente/montaria.
4. Streaming de regiao e LOD de NPC/reinos distantes; estados persistidos sem milhares de Instances remotas, preservando construcoes criadas em jogo.
Aceite: gerar mesma seed e preservar estruturas; water/swim valida no motor; grafo muda com ponte construida/destruida; nenhum NPC bloqueado atravessa rio profundo; regioes distantes mantem estado; perfil mobile medido.
Nao antecipar: politicas de conquista, infecao sistêmica e chefes.

### T2-R2 — Industria, profissões, mercado e impostos
Integracoes:
1. Mineracao/carpintaria evoluidas, ferreiro, artesao, agricultor, cacador e transportador, ferramentas, equipamentos e habilidades por nivel.
2. Cadeias produtivas e receita por recursos, fazenda perto de agua, alimento e consumo da populacao.
3. Mercadorias, producao entre distritos, rotas de transporte e comercio interno e entre reinos; salarios, tributos, impostos e tesouraria.
4. Economia persistente com precos/oferta, reserva de estoque, producao, demanda e resposta dos NPCs.
Aceite: cadeia de extracao->processamento->uso/venda produz valor sem moeda dropada; estoques fecham matematicamente; regras de irrigacao funcionam; habilidades afetam ritmo; save/load sem duplicar transacoes.
Nao antecipar: guerra, bosses e sistema de eras futuras.

### T2-R3 — Reinos vizinhos, relacoes e montarias
Integracoes:
1. Reinos e tribos NPC com habitantes, economia e defesa propria, simulados em resumo ao longe e concretos perto do jogador.
2. Contato, comercio diplomatico, reputacao, pedidos de ajuda/alianca iniciais, impacto real das decisoes na economia.
3. Relacoes NPC↔NPC e jogador↔NPC com traços, presentes, confianca, memoria de ajuda/resgate e conversas contextuais leves.
4. Compra/domesticacao inicial de montarias terrestres, velocidade, saude, comportamento e limites de travessia/ponte; rotas comerciais de longa distancia.
Aceite: reino vizinho existe e reage, relacoes persistem, montarias seguem regras fisicas, compra/estoque/rotas nao duplicam; jogo T2 testavel e administravel no mobile.
MARCO: publicar T2 em staging e pedir review do criador. Refinamento T2-F1/T2-F2/T2-F3 se necessario.

## TEMPORADA 3 — GUERRA DA CORRUPCAO E FECHAMENTO DO JOGO
Meta: versao medieval solo com experiencia longa, ecossistema hostil, reinos politicos e progressao final, pronta para lancamento.

### T3-R1 — Monstros complexos, portais, infecao e boss raids
Integracoes:
1. EnemyRegistry com classes de ataque, saque, cerco e contaminacao; fauna e NPCs podem ser infectados progressivamente.
2. Surtos internos com sintomas, deteccao e tempo justo de isolar, curar ou evacuar; proteger tutorial e primeiras horas.
3. Portais/cavernas que surgem e evoluem, pressao territorial e RaidDirector global: direcao, frequencia, objetivo, defesa do reino vizinho e contra-ataque.
4. Armas/esquadroes, batalhas, expedições para destruir focos e chefes de raids de alto nivel.
Aceite: portal evolui/destrói-se e muda ataques; distribuicao de raids nao e sempre 50/50; infeccao nao mata sem chance de reagir; chefe/monstros obedecem rotas e fim de combate; save/load consistente; testes de stress e performance.
Nao antecipar: PvP/co-op e segredos de lore reservada.

### T3-R2 — Diplomacia, conquista NPC e reinos sob comando
Integracoes:
1. Diplomacia mais profunda, reputacao, alianca, hostilidade, guerra contra reinos controlados por NPCs e batalhoes.
2. Conquista e gerenciamento de multiplos reinos, economia/leis/defesas compartilhadas, centralizacao opcional e relacoes sociais que afetem governo.
3. Fusao/reorganizacao de territorios, novos anéis de muralhas e estruturas preservando itens, proprietarios e estado real.
4. Fast travel por estrutura/rota autorizada e viagens normais caminhando entre reinos; objetivos de longo prazo do mundo medieval.
Aceite: reinos conquistados persistem; fusao nao apaga recursos, personagens e edificios; logistica, raids e relacoes alteram decisao estrategica; migracoes de save funcionam com reinos novos/antigos.
Nao antecipar: PvP multiplayer ou evolucao tecnologica reservada.

### T3-R3 — Integracao final, UX, monetizacao e qualidade
Integracoes:
1. Balanceamento e integracao ponta-a-ponta de TODOS os sistemas das tres temporadas, progressao longa e combate, economia, social, exploracao e raids.
2. UI/UX, acessibilidade, controles mobile/PC, animacoes, audio, VFX, equipamentos, render 3D, streaming, otimizacao real.
3. Seis slots robustos, save/load, migracao, recuperacao de falhas, anti-exploit, stress tests, analise de memoria/FPS e licenciamento de assets.
4. Starter pack PvE, developer products e eventualmente rewarded ads APENAS se elegiveis/autorizados; comprovantes idempotentes, progresso gratuito plenamente viavel e sem vantagem injusta em futuro PvP.
5. Preparacao de release, teste de jornada nova->coroa->mundo aberto->outros reinos->boss->progressao final, telemetria de bugs e documentacao de entrega.
Aceite: campanha/sandbox completo realmente jogavel sem sistemas de mentira; save nao perde dados, materiais nao duplicam; politica comercial validada; cliente real mobile medido; suite de regressao verde; autor revisa build de staging.
MARCO: publicar T3 em staging, pedir review do criador, realizar T3-F1/T3-F2/T3-F3 se necessario; depois preparar release production com autorizacao.

## Princípios de engenharia
- Sistemas modulares com registros de definicao de biomas, itens, receitas, construcoes, NPCs, skills, montarias, monstros, portais e drops. Adicionar conteudo por dados e assets, nao duplicar scripts.
- Server-authoritative para saldo, item, build, combate, transacoes, raid e saves; client-only para camera, UI, animacao e efeitos de moeda.
- Schemas versionados, identificadores estaveis, API explicita entre modulos, eventos idempotentes, tests, metrica e migracao.
- Diferenciar fundamento extensivel (permitido antes) de funcionalidade futura (proibida antes de seu runner).
- Nao prometer datas ou testes que nao foram executados.
- Status oficial: RUNNER_STATUS.json; rito: RUNNER_PROTOCOL.md; regras globais AGENTS.md; todas as ideias no VISION_MASTER.md.

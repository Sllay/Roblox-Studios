# ENTRE REINOS — BÍBLIA DE DESIGN (FONTE CANÔNICA)

Versão V0.5 — 2026-11-21. Estado: PLANEJAMENTO, não funcionalidades implementadas.

LEIA ESTE DOCUMENTO ANTES DE PROJETAR, PROGRAMAR, TESTAR OU PUBLICAR O ENTRE REINOS.
Regras: [FIXADO] = definido pelo criador; [PROPOSTA] = proposta técnica/creativa; [FUTURO] = objetivo preservado, fora da primeira versão; [ABERTO] = não especificado ou não verificado. Nunca transformar exemplos em parâmetros definitivos. Toda mudança aprovada vai para o log de decisões, GDD, arquitetura e testes, sem apagar ideias anteriores silenciosamente. A lore reservada NÃO deve ser escrita em repositório público.

## 1 — Identidade do jogo e desenvolvimento

[FIXADO] Nome em português: Entre Reinos; tradução de trabalho em inglês: Between Kingdoms, a validar. Survival medieval de estratégia e exploração lateral, reino vivo e governável, combate direto, logística, economia, NPCs autônomos, corrupção e ataques.
[FIXADO] Jogo Roblox separado de Black Island. Mesmo estilo stylized cartoon, reaproveitando apenas recursos próprios/aprovados, biblioteca e ferramentas do repositório Roblox-Studios. Nunca misturar scripts, save, IDs e publicação entre projetos.
[FIXADO] Mapas staging e production independentes: staging recebe novas versões validadas por checks e é usado em testes visuais; production recebe somente atualizações estáveis com aprovação. Nenhum deploy em ID não verificado.
[FIXADO] Jogo começa solo (no Roblox ainda depende de servidores/conexão), com seis slots de mundos independentes. Coop, PvP, guerra de jogadores e funcionalidades enormes são FUTURO.
[FIXADO] O objetivo é criar um bom jogo capaz de gerar receita enquanto Black Island continua em desenvolvimento; não sacrificar qualidade por monetização.

## 2 — Prólogo jogável e começo da campanha

[FIXADO] Protagonista é um guerreiro/guarda real do nobre/duque regional, cuja administração é corrupta. O mundo sofre ameaça de monstros obscuros; alguns são infectantes.
[FIXADO] O duque sai da proteção das muralhas, escoltado por guardas. Um monstro especial o infecta; outros guardas hesitam em atacar seu antigo senhor e morrem. O jogador vence o duque transformado.
[FIXADO] Logo depois, grande ataque dos dois lados. Muralhas externas caem, habitantes fogem para o centro. Tutorial ensina caminhar, atacar, equipar NPCs com arcos e lanças, reforçar paredes, ordenar defesa e proteger civis. Os defensores podem lançar lanças/projéteis de posições protegidas.
[FIXADO] Os sobreviventes veem o protagonista defender a cidade melhor do que o nobre, e ao amanhecer oferecem a coroa. Início do sandbox: reparar casas, galpões e muros, obter materiais, administrar sobreviventes e expandir.
[PROPOSTA] Cinco momentos curtos, todos jogáveis, sem cutscene excessiva; confiança/lealdade dos NPCs precisa ser mantida depois da coroação.
[FIXADO] Infecção do nobre é roteirizada. Infecção aleatória entre cidadãos NÃO deve devastar um save iniciante antes do jogador entender os sistemas.

## 3 — Mundo 100% 3D com câmera lateral

[FIXADO] ABSOLUTAMENTE TODO O CENÁRIO É 3D, com Terrain nativo Roblox e modelos 3D; não usar fundo 2D com parallax. O visual é 2.5D pela câmera, não por sprites.
[FIXADO] Eixo X = caminhar para esquerda/direita, Y = altura e subida/descida na água, Z = profundidade visual, sem caminhar livremente para frente/trás em solo.
[FIXADO] Quatro zonas em profundidade, todas tridimensionais:
1. Fundo distante: montanhas, colinas, florestas, cachoeiras e natureza 3D decorativa;
2. Fundo próximo interativo: casas, galpões, muralhas, árvores cortáveis, minérios, fazendas, oficinas, estruturas. NPCs operam por âncoras alcançáveis da faixa jogável;
3. Faixa jogável: jogador R6, NPCs, monstros, animais, combate, grama baixa, obstáculos;
4. Primeiro plano: rio/mar, margens e elementos decorativos como árvores, gramas e galhos em SILHUETA PRETA ABSOLUTA 3D, sem clarear pelo dia/noite; devem ser raros, leves e não ocultar jogador/UI.
[FIXADO] Rios podem nascer nas montanhas de fundo, descer como cursos de água reais visuais, atravessar a faixa jogável e continuar na frente. O primeiro plano pode ter terra em algumas regiões.
[FIXADO] Mundo horizontal muito grande: reinos, vilas, tribos, florestas, cavernas e/ou portais em regiões caminháveis e interligadas; um barco é opcional, não requisito para trocar de reino.
[FIXADO] Procedural por seed, porém controlado: reinos, áreas de expansão, muralhas, cursos de água, montanhas, faixas de caminho e recursos precisam ser coerentes e navegáveis.
[PROPOSTA] Simulação agregada e LOD para reinos muito afastados, regiões em streaming e Terrain gerado por sistema próprio auditado. Não instanciar um continente inteiro nem centenas de agentes de IA em todos os reinos.
[ABERTO] Escalas, terreno exato e largura do corredor de navegação.

## 4 — Jogador R6, controle, água e montaria

[FIXADO] Jogador e NPCs humanoides R6 (roupas/acessórios medievais variados). Jogador inicia a pé; pode correr, pular, usar armas e mais tarde comprar/domesticar montarias.
[FIXADO] Direita/esquerda em solo movem X; cima gira suavemente o avatar para o fundo, baixo gira para a câmera, SEM mover Z. Combinar orientação e movimentação sem travar, vibrar ou deslocar o personagem para fora da faixa.
[FIXADO] Ao nadar em Terrain Water, cima faz subir em Y, baixo faz mergulhar em Y, esquerda/direita movem X, diagonais combinam X/Y suavemente. Permanece bloqueado deslocamento Z. Usar capacidades de Humanoid Swimming e animação nativa sem comprometer física; verificar no motor.
[FIXADO] Riachos rasos podem permitir travessia a pé; águas profundas exigem natação ou pontes. NPCs e montarias terrestres incapazes de nadar só atravessam por rota adequada.
[FIXADO] Montarias oferecem mobilidade e possivelmente atributos de vida/status. Domesticação e espécies especiais são sistema futuro ampliável.
[PROPOSTA] Terrain Water não gera escoamento hidrológico automaticamente; volumes nadáveis, correnteza artificial e cachoeiras visuais são sistemas distintos. Evitar teleport CFrame por frame.

## 5 — Pontes e logística de travessia

[FIXADO] Pontes são construíveis e melhoráveis por trabalhadores.
[FIXADO] Ponte provisória permite inicialmente apenas construtores/trabalhadores autorizados; ponte reforçada permite NPCs, transporte de recursos e montarias terrestres.
[FIXADO] Água rasa dispensa ponte.
[PROPOSTA] Cada ponte é aresta do grafo de deslocamento com classe permitida e capacidade; dano/destruição altera rotas imediatamente.

## 6 — Castelo, galpões, muros, distritos e abrigos

[FIXADO] Castelo central com tesouraria. Dois galpões grandes perto do centro no início, com capacidade finita, mais depósitos construíveis pelo mapa. Muralhas à esquerda e direita; anéis externos delimitam distritos com casas e produções. Distância entre anéis normalmente cresce quando se afasta do centro.
[FIXADO] Paredes evoluem: madeira simples, madeira reforçada, pedra e níveis mais avançados. Custos por materiais e trabalho, NÃO pagar apenas moeda para instantaneamente materializar obra.
[FIXADO] Casas têm níveis de resistência; moradores podem permanecer escondidos durante ataque, e sobrevivem se abrigo suportar até amanhecer. Se destruído, são expostos; fugir, resistir ou ficar são decisões influenciadas por traços/medo.
[FIXADO] Monstros quebram casas, depósitos e muralhas; o reino requer reconstrução e recuperação de setores.
[PROPOSTA] Distritos têm estados Seguro/Alerta/Invadido/Ocupado/Recuperado, com comportamento e rotas associados.
[FUTURO] Conquistar e fundir reinos, reorganizar muralhas e castelos sem apagar estruturas sem justificativa.

## 7 — Posicionamento livre e obra em duas etapas

[FIXADO] NÃO existem slots de construção predefinidos. O jogador escolhe espaço livre onde a construção cabe; validar terreno, acesso, ocupação e condições especiais. Fazendas próximas a fontes de água/irrigação; pontes ligam margens.
[FIXADO] A estrutura começa como placeholder/plano de obra com tabela de materiais necessários, entregues gradualmente (10 madeira, 10 pedra e 10 ferro foram apenas exemplo).
[FIXADO] NPC que já carrega recurso no inventário pode entregá-lo DIRETAMENTE à obra, sem precisar depositar em galpão. Outros NPCs podem completar a lista depois. Materiais saem do inventário ao entregar, sem duplicação.
[FIXADO] Só após entrega total dos materiais a obra entra em fase de trabalho/craft. Trabalhadores adequados progridem a barra; se dormirem ou fugirem de raid, o trabalho parcial continua registrado e pode ser retomado.
[FIXADO] Multiplicadores propostos na conversa são VEZES DE VELOCIDADE, não porcentagem: carpinteiro em madeira 3x / pedra 1x; minerador em pedra 3x / madeira 1x; construtor generalista 2x em ambos; comum 1x. Proficiência, ferramenta, fadiga e dificuldade podem modificar tempo.
[PROPOSTA] Validação contínua de footprint/declive/colisão no servidor; blueprint estado Entrega -> Trabalho -> Concluído/Danificado/Cancelado. Trabalho medido em unidades acumuladas persistidas no save.
[ABERTO] Receitas finais, raio de fazenda, regras de cancelamento, custo de reparo e limites de colaboração.

## 8 — NPCs vivos, profissões e relações

[FIXADO] NPCs possuem inventário real, equipamento (armadura, arma e ferramenta), recursos carregados e limite de peso. Devem poder entregar ao depósito, obra ou usar diretamente em tarefas.
[FIXADO] Profissões: carpinteiro/lenhador, minerador, construtor, ferreiro, artesão, fazendeiro, caçador, transportador, guarda, arqueiro, lanceiro, comércio e outras futuras. São especializações de eficiência, não personagens robóticos limitados a uma só ação.
[FIXADO] Habilidades evoluem com trabalho, como minerador nível 10, reduzindo tempos e aumentando produtividade. Cada agente usa saúde, fome, fadiga, moradia, profissão, objetivos e segurança para decidir ações.
[FIXADO] Trabalhos são autônomos: coletar madeira, pedra, minério, comida, caçar, construir, defender, transportar e vender. O jogador define prioridades e pode atribuir agentes manualmente.
[FIXADO] Relação entre NPCs e entre NPC e jogador: presentear, salvar, cuidar, confiança e memórias de acontecimentos. Traços como coragem/medo podem afetar abrigo e combate.
[PROPOSTA] Planejador leve utility + FSM, fila de jobs e controle de reservas/rotas; sem LLM para cada NPC; atualizações com LOD. Sistema social profundo mais tarde.
[ABERTO] Quantidade de NPCs, habilidades e tipos de relação da versão inicial.

## 9 — Recursos, dinheiro, comércio, depósitos e perdas

[FIXADO] ÁRVORES NÃO DROPAM MOEDAS. Extração gera madeira; mineração gera pedra/minérios; agricultura alimento. Moeda surge de comércio interno/externo, venda de itens, tributos e outras operações econômicas plausíveis. Compras, impostos, salários e vendas movimentam o dinheiro.
[FIXADO] Bolsa física de moedas, lançadas/quicando/catadas; servidor valida o valor, cliente mostra física/efeitos. Tesouro no castelo; galpões armazenam itens, capacidade finita e localização física.
[FIXADO] Sem obrigação de armazenar no galpão para que um NPC use materiais do próprio inventário.
[FIXADO] Se armazém for destruído, recurso é efetivamente retirado do estoque. Parte pode ser perdida ou roubada e parte fica recuperável nos destroços. Reparar ou resgatar pode devolver uma porcentagem, NUNCA duplicar 100% de material do nada.
[PROPOSTA] Ledger autoritativo e eventos idempotentes. Particionar estoque no instante da destruição em destruído/roubado/recuperável. Simular transporte de cargas, negociação e impostos de forma estável.
[ABERTO] Valor da moeda, preços, impostos, percentuais de recuperação e balanceamento da economia.

## 10 — Monstros, infecção e raids

[FIXADO] Monstros obscuros variados. Algumas classes infectam seres vivos (lobos, outros animais pacíficos ou agressivos e humanos), gerando mutações; outras cercam, destroem e atacam. Infecção é mecânica mais ampla do que uma única criatura.
[FIXADO] Raids normalmente à noite, NÃO toda noite obrigatoriamente. Ataques/eventos diurnos são possíveis. Invasões vêm dos horizontes, de cavernas ou portais entre reinos.
[FIXADO] Portais podem surgir/evoluir de nível, ficando perigosos se não destruídos. Portal no corredor entre dois reinos pode mandar força para um ou ambos; escolha não deve ser sempre 50/50. Reinos NPCs também se defendem e podem atacar focos.
[FIXADO] Portais extremamente fortes podem gerar boss raids (nível 10 foi exemplo imaginado), cooperação entre reinos, duas frentes e risco de colapso.
[PROPOSTA] RaidDirector por pressão, nível, chance, defesa, exposição, distância e objetivo (invadir, roubar, contaminar, destruir muro/galpão). Reinos distantes simulados agregadamente.
[FIXADO] Futuramente NPC infectado em expedição poderá retornar e contagiar moradores, mas só com sinais, reação, cura/isolamento/evacuação e depois de uma curva de dificuldade JUSTA. Tutorial inicial não pode sofrer surto destrutivo livre.
[ABERTO] Fonte definitiva dos monstros (portal, caverna ou ambas), curva de nível, periodicidade e ataques de bosses.

## 11 — Reinos, tribos, diplomacia e expansão

[FIXADO] Reinos e tribos habitados por NPCs com suas próprias defesas e produções. Jogador pode caminhar até outros reinos, comerciar, fazer alianças e ajudar atacar portal.
[FUTURO] Guerra, conquistas, administrar vários reinos, fundir reinos/territórios, reorganizar estruturas e muralhas, viajar rapidamente por barco/doca/posto/portal e PvP/co-op com batalhões. Não implementar no começo.
[PROPOSTA] Persistência de reinos distantes como dados, sem spawn de milhares de NPCs.

## 12 — Menus, saves, continuidade e publicação

[FIXADO] Menu inicial com Play, Options, Exit/Back. Play apresenta SEIS slots vazios ou existentes. Criar slot gera mundo procedural seed; carregar retoma construções, NPCs, inventários, tempo, portais e trabalho parcial. Renomear/deletar com confirmação são propostas de UX.
[PROPOSTA] DataStoreService no servidor com versionamento, session-lock, migrações, controle de duplicação, orçamento de escrita, restauração e backups. Não confundir save de jogador com salvamento de IDEIAS: ideias ficam neste repositório e documentos.
[FIXADO] Build e validação de scripts antes da publicação em staging; testes no Studio/mobile separados. Production isolada para versões estáveis.

[EXCEÇÃO AUTORIZADA] Uma prévia intermediária do candidato T2-R1 do PR #13 pode ser publicada no staging existente do Entre Reinos para playtest. A publicação da temporada segue o gate depois de R3. Consulte a autorização específica no [protocolo](RUNNER_PROTOCOL.md#exceção-autorizada-t2-r1).

## 13 — Monetização opcional, anúncios e Robux

[FIXADO] PvE solo aceita benefícios opcionais pagos/ads, mas gratuito precisa ser viável. Queremos monetizar onde útil e divertido, sem obrigar anúncio a cada ação.
[FIXADO] Para obra cujo MATERIAL já foi entregue, anúncio recompensado poderá avançar cerca de 1/3 do TRABALHO-BASE. Máximo planejado de 3 vouchers/anúncios por obra, limitados ao trabalho que falta. Quem já construiu metade pode usar menos; não resetar tempo por anúncio.
[FIXADO] Robux pode concluir construção; ideia de pagamento que também devolve/concede materiais equivalentes requer produto explícito e transação única para não duplicar estoque. Sistema só após validação da API oficial.
[FIXADO] Starter pack PvE com cavalinho mais rápido, vida/status e recursos; vantagens competitivas devem ser normalizadas ou isoladas em PvP futuro.
[PROPOSTA] Roblox Rewarded Video Ads depende de elegibilidade, inventário disponível e confirmação do sistema. Não garantir três anúncios sempre; se indisponíveis, trabalhadores terminam gratuitamente. Developer Products e receipts precisam de idempotência. Critérios comerciais e políticas devem ser reverificados na implementação.
[ABERTO] Preços, conteúdo final do pack, decisão de recompensa entre slots, elegibilidade real e critérios de vantagem justa.

## 14 — Segredos e temporadas posteriores

[FIXADO] Existe lore tardia CONFIDENCIAL em documento privado fora do GitHub público. O visual e jogabilidade da primeira temporada permanecem medievais. Não publicar detalhes do segredo, nem codificá-lo em assets/scripts acessíveis ao público antes da revelação.
[FUTURO] Evolução do mundo em várias temporadas, pesquisa, mudanças de civilização e lore gradual conforme arquivo privado autorizado. Nada de acelerar eras grandes em poucos dias.
[NOTA] Commits públicos anteriores podem conter texto antigo; reescrever documentação atual não apaga histórico Git.

## 15 — Critérios técnicos e prioridades

[FIXADO] Primeiro protótipo comprova: cenário 100% 3D em quatro faixas; R6 controlado lateralmente; frente/fundo em terra sem Z; mergulho/subida/diagonal em água nativa; rio e navegação suaves no mobile.
[PROPOSTA] Depois NPC com inventário e coleta, transporte, entrega direta à obra, blueprint com progresso salvo, muro, galpão, economia de materiais, ataque/raid e save. Evoluir NPCs, demais reinos, relações e monetização gradualmente.
[PROPOSTA] Servidor autoritativo para saves, posse, estoque, trabalho, dinheiro, combate e raids. Cliente com preview/efeitos e física visual de moedas.
[PROPOSTA] Testes automáticos: idempotência, save/load, obras interrompidas, perda e salvage de depósitos, pontes, seed, Profissões 3x/2x/1x, raid director. Validação real de câmera, física, Terrain e FPS em mobile.

## 16 — Pontos não decididos (NÃO INVENTAR)

Distâncias/escala de reinos; limite NPC e carga; regras precisas de derrota e ressurreição; tempo do mundo quando o save estiver descarregado; tipo definitivo dos portais; duração do tutorial e do ciclo noturno; receitas e durações finais; mineração especial; economia e impostos; processo de reparo de galpão; critérios de viralização e anúncio; balanceamento de barcos/montarias; política de alianças; política de fusão de reinos; ID Roblox e se destino é staging; nome comercial em inglês.

## 17 — Regra de producao fixada em 21/11/2026

[FIXADO] A versao medieval solo completa do Entre Reinos sera entregue atraves de 3 temporadas de producao; cada temporada tera 3 runners principais, cada um com varias integracoes reais, validacao/green check e commit no repositorio antes do runner seguinte.
[FIXADO] Apenas depois do terceiro runner da temporada sera publicada uma atualizacao no mapa de testes (staging), seguida da validacao manual do criador. Quando a avaliacao mostrar defeitos ou falta de qualidade, abrir camada extra de 3 runners da MESMA temporada para refinar, validar e republicar; nao adiantar elementos da temporada seguinte.
[FIXADO] Ao termino de T3, o objetivo e jogo funcional completo e pronto para revisao final e lancamento, nao uma demonstracao simplificada. Arquitetura modular desde o primeiro dia: geracao, biomas, vila, estrutura, item/moeda, NPC, profissoes, inventario, montaria, combate, monstros, raids, mundo e saves. Evitar gambiarra, codigo duplicado e reconstrucoes desnecessarias.
[PROPOSTA] Alocacao exata entre T1/T2/T3 e runners esta em docs/SEASON_RUNNERS.md, sujeita a revisao explicita sem alterar o contrato das 3 temporadas. Gates e evidencias em docs/RUNNER_PROTOCOL.md e docs/RUNNER_STATUS.json.
[FUTURO] Modos multiplayer/PvP e revelacoes privadas de longa duracao permanecem fora da versao medieval solo inicial; nao antecipar conteudo de outra fase.

## 18 — Decisao MAIS RECENTE: T1 Fundacao, T2 Finalizacao, T3 Conteudo/Polimento

[FIXADO] O criador corrigiu a alocacao do plano no dia 21/11/2026: T1 entrega a FUNDAÇÃO modular e jogavel; T2 deve FINALIZAR todos os sistemas-base e o ciclo completo do jogo solo medieval, incluindo portais, corrupcao/infecao, raids estratégicas, montarias, economia, diplomacia e reinos NPC; T3 adiciona conteúdo, variedade e POLIMENTO, nao deve ser usada para iniciar os sistemas fundamentais que ficaram faltando.

[FIXADO] Cada runner deve especificar a pesquisa do nosso repo + engenharia reversa comunitaria/observacoes externas, fonte e versao, scripts, integracoes, testes e evidencias em ordem cronológica. Mudanca de modelo deve retomar via docs/AGENT_HANDOFF.md e estado docs/RUNNER_STATUS.json, preservando feeling e fontes.

[PROPOSTA] Detalhamento da alocação e testes esta em docs/SEASON_RUNNERS.md V2. Documentacao completa das fontes, fatos e formulas em docs/research/RESEARCH_SOURCES.md, MECHANICS_AUDIT.md e ROBLOX_ADAPTATION.md. Perguntas nao resolvidas em RESEARCH_GAPS.md; não inventar dados da fonte ou do gameplay para preencher lacunas.

[FIXADO] Encerra T1 e T2 e T3 apenas apos cada R3 validado em CI, publicado em staging verificado e aprovado por teste manual do criador; camadas de 3 refinamentos da mesma temporada se necessario. Nenhum escopo da temporada seguinte antecipado.

## 26/11/2026 — Refinamento do playtest v20

[FIXADO] A v20 revelou apresentação confusa no celular. A experiência existente precisa de interface mobile-first, autoexplicativa e contextual. Uso compartilhado de áreas seguras, escala, tipografia, ícones originais, espaçamento e estado modal. Evitar sobreposição com controles nativos, reconstrução de UI por atualização e navegação diferente por dispositivo.

[FIXADO] Na parte superior, até quatro slots de recursos visíveis com nome, ícone e números atual/estoque/max, rolagem horizontal com snap e ordem estável. Na inferior, seleção centrada de armas, ferramentas, munição e itens realmente disponíveis. Botões circulares na direita se adaptam à ação equipada e ao alvo à frente. Alvos usam direção, alcance, acesso, prioridade e histerese. Preservar pressão longa para árvores e cancelar gestos ao trocar contexto.

[FIXADO] Castelo abre tesouraria e comércio; oficina e forja mostram receitas da estação; galpão mostra estoques e custódia; fazenda mostra cultivo; doca lida com transporte e carga. Painéis compactos, contextualizados, fechados ao perder alcance ou entrar em combate, com pré-condições e permissões validadas no servidor.

[FIXADO] O caderno permite ordenar moradores autorizados à distância. Mudança de profissão, tarefa, coleta, construção, prioridades e equipamento desejado respeita autoridade territorial. Armas e ferramentas percorrem reserva, trajeto, recebimento e transferência de custódia física. Uso de estoque remoto sem teletransporte.

[FIXADO] Preservar o grafo regional e separar planejamento, locomoção, desvio, destino e apresentação. Investigar oscilações, concorrência por pontos comuns, travessias e pausas. Usar soluções leves, com espera em gargalos, detecção de ausência de progresso e interpolação X/Z de posição e orientação. Sem retornos a corredores no Z ou teletransporte habitual. Atrás da câmera não simular NPCs ou economia decorativa.

[FIXADO] Ameaça real aciona alerta, interrupção de atividade, evacuação, abrigo e retomada. Noite sem perigo permite trabalho. Civis preservam carga e reservas, evitam inimigos e procuram refúgio acessível. Defensores reagem conforme função e equipamento. Resolver conflitos entre trabalho, necessidade, perigo e narrativa.

[FIXADO] Flechas precisam de hitboxes anatômicas coerentes e detecção contínua sem colisão física com jogador ou dano através de paredes. Preservar gravidade. Duque mantém interação e animação sem empurrar o jogador. Guardas devem olhar para a transformação, hesitar conforme o roteiro e retomar sua função. Preservar a narrativa.

[FIXADO] Gerar Terrain além do enquadramento máximo, considerando zoom, proporção e velocidade de montaria, e validar o que o cliente recebe. Barreira segura em ambas as extremidades e dois chunks decorativos por lado. Três fileiras adicionais em Z com altura crescente, silhuetas naturais e árvores variadas por altitude, umidade, inclinação e bioma, com densidade e LOD limitados. Faixa frontal de água 3D, margens naturais e continuidade dos cursos que descem do fundo ao primeiro plano, com cascatas visuais e volumes nativos coerentes. Preservar terreno, travessias, seed e dados atuais.

[FIXADO] Medir custo de simulação, render, atualização de UI, memória, movimento, replicação e geração. Perfil em servidor isolado não equivale a FPS mobile. Concluir os checkpoints A–F e revisar em staging existente, com autorização específica de publicação. T2-R3 aguarda o refinamento.

## 27/11/2026 — Mar frontal e vegetação

[FIXADO] A primeira fileira do lado da câmera é mar aberto. A margem fica na transição do terreno jogável. O mar é contínuo em X, incluindo os chunks decorativos das extremidades, com nível comum fora das desembocaduras. Rios vindos das elevações atravessam o terreno jogável e deságuam no mar. Usar volumes nativos de Terrain; preservar as margens, travessias e o limite de movimento do jogador em Z.

[FIXADO] Os modelos aprovados do Black Islands podem ser reutilizados nos elementos naturais do Entre Reinos. A distribuição varia por seed, bioma e relevo e preserva clareiras e acessos. A camada distante tem orçamento reduzido. A apresentação de uma fonte preserva sua identidade, quantidade e estado persistido. Grama usa a decoração nativa de Terrain.

## 28/11/2026 — Leitura da cena na câmera lateral

[FIXADO] As árvores ficam atrás do corredor jogável. A copa inteira precisa ficar do lado oposto à câmera lateral inclusive durante os diálogos. A escala deve manter o personagem legível. Quando uma fonte salva tiver coordenada perto da frente, sua âncora de coleta conserva a posição e seu modelo visível fica atrás.

# Game Design Document — Between Kingdoms / Entre Reinos

Versão: concept-0.2, 2026-11-21. Requisitos do criador; valores de balanceamento ainda provisórios.

## 1. Proposta

Jogo medieval original de estratégia/sobrevivência lateral (3D estilizado em 2.5D). O jogador começa como guarda real, mata o duque infectado e organiza os sobreviventes de uma cidade durante uma invasão. Recebe uma coroa, reconstrói o reino, administra população autônoma, recursos, alianças e expansão territorial. Inspiração funcional: microestratégia lateral, defesa noturna e bolsa física; sem copiar expressão, código ou assets de Kingdom Two Crowns.

Modo inicial: campanha individual com 6 slots de mundos persistentes. Roblox requer conexão e servidores: não prometer execução offline real. PvP, multiplayer, conquista de reinos e fusão territorial: fases futuras.

## 2. Prólogo jogável

1. Guarda no reino de um duque corrupto; tutorial de movimento, corrida e combate.
2. Um monstro-corruptor infecta o duque durante caminhada fora da muralha; guardas hesitam, protagonista enfrenta duque transformado.
3. Invasão simultânea dos dois lados; queda do muro externo; cidadãos fogem ao próximo anel.
4. Protagonista fornece lanças/arcos e comanda proteção, reparos e defesa; primeiros recursos reais retirados de depósito.
5. Ao amanhecer a comunidade lhe entrega a coroa; começa reconstrução. Lealdade é conquistada, não presumida.

O prólogo deve funcionar com instruções discretas e não travar o jogador em múltiplas cutscenes. Efeitos de infecção fantásticos, sem violência gráfica.

## 3. Loop central

Explorar à esquerda/direita → aceitar/coletar trabalhos e recursos → distribuir mão de obra e ferramentas → estocar/produzir → construir e reparar anéis defensivos → defender/fugir de incursões → salvar sobreviventes → negociar e expandir → investigar/destruir focos de corrupção.

O jogador combate diretamente (espada/lanca/arco, a definir) e também comanda NPCs. Montaria não é inicial; compra, resgate e domesticação são progressão.

## 4. Mundo

- Mundo 100% 3D: movimento jogável no eixo X (horizontal), relevo e natação vertical no Y, eixo Z apenas para profundidade do mundo; NÃO usar parallax 2D nem spriteboards para substituir o mundo.
- Quatro faixas visuais 3D: (1) fundo distante de Terrain, montanhas e floresta; (2) fundo próximo interativo com casas, galpões, árvores e minérios; (3) faixa principal com jogador R6, NPCs, inimigos, obstáculos e grama; (4) primeiro plano com rio/mar, docas, vegetação e silhuetas decorativas inteiramente pretas, imunes visualmente ao ciclo de iluminação.
- A faixa interativa no background utiliza pontos de trabalho acessíveis a partir do corredor principal em X, sem obrigar personagem a andar livremente em Z. Trabalhadores animam interações a partir desses pontos; estruturas e depósitos mantêm suas coordenadas físicas em 3D.
- Vegetação de silhueta em primeiro plano só em áreas relevantes, com baixo custo gráfico; impedir oclusão indevida de personagens/interações e testar preto absoluto em iluminação real.
- Terrain nativo do Roblox com geração determinística guiada por seed e constrangimentos de reino/muralhas/distritos/rotas. Não confundir cenário visual 3D com movimentação livre em Z.
- Reinos conectados fisicamente no mesmo eixo; corredores entre reinos contêm natureza, tribos, cavernas/portais e rotas comerciais.
- Mundos vastos: apenas regiões próximas são representadas em detalhe; reinos distantes são simulados resumidamente. Conteúdo do mundo não deve exigir todas as Instances simultaneamente.
- O centro político/tesouraria e dois armazéns grandes começam como infraestrutura parcialmente destruída.
- Defesas em múltiplos anéis esquerda/direita; distância entre anéis cresce em direção aos exteriores sob restrições de biomas, terrenos válidos e ocupação. **Não** mover estruturas de regiões habitadas silenciosamente.

## 5. Distritos e muralhas

Cada intervalo entre dois muros define um distrito com habitações, postos, depósitos e defesa. Estados: Safe, Alert, Breached, Occupied, Recovered.

Muros: estacas → madeira → madeira reforçada → pedra → fortificação superior futura, com materiais reais, trabalhadores, tempo e reparo. Estruturas: HP, material, proteção, guarnição, ordem de reparo, espaço ocupado e resiliência; destruição afeta rota, segurança e economia.

Casas: NPC decide abrigar-se, evacuar ou defender conforme segurança/coragem/ordens; abrigo reduz risco, mas se destruído ocupantes sobreviventes saem expostos. Sem invulnerabilidade automática.

Depósitos: inventário real e capacidade; dano aciona eventos de derramamento/salvamento/saque. Uma fração recuperável fica em cache de destroços sujeito a tempo, inimigos e reconstrução; nunca regenerar recursos do nada.

## 6. NPCs

R6 com variações de pele/cabelo, roupas medievais adequadas e equipagem real. Profissões iniciais: carpinteiro/lenhador, minerador, agricultor, caçador, ferreiro, artesão, transportador, guarda, arqueiro, lanceiro, construtor (multifuncionalidade por habilidade, sem classes rígidas).

Dados individuais (versão progressiva): identidade, aptidões, inventário, profissão, experiência, casa, trabalho, fome, fadiga, saúde, moral, lealdade e relações. Ordens por pontos e setores; decisões autônomas por utility + FSM e agenda. O jogador pode ajudar/resgatar/presentear e desenvolver confiança com NPCs; relações profundas entram após loop econômico estável.

## 7. Economia

Madeira, pedra, ferro, ferramentas, alimento, flechas e produtos são gerados por ações físicas do mundo e trabalhos, não por spawn direto de moedas ao cortar árvore. Comércio interno, externo, tributos e tesouro convertem produção em moeda. Os custos de construção gastam materiais e mão de obra; moedas servem a contratação, remuneração, serviços e comércio.

Bolsa física visual: moedas com arco/quique e presença no chão, mas valores e transações sempre autoritativos no servidor. A moeda visual nunca é a fonte de verdade monetária.

Armazéns possuem capacidade local, reserva, entregas, perdas e missões de resgate. Rota comercial e impostos exigem cadeia produtiva que funcione mesmo com poucos NPCs.

## 8. Corrupção, portais e incursões

A corrupção afeta fauna e habitantes com regras por espécie e por tipo de monstro (alguns infectam, outros saqueiam, cercam ou assaltam). Ameaças ordinárias surgem à noite de forma não obrigatoriamente diária; exceções diurnas e eventos especiais sinalizados.

Focos de corrupção podem existir entre dois reinos e desenvolver níveis. Um diretor decide frequência, intensidade, objetivo, alvo e direção conforme ameaça, preparo, exposição e risco, sem ataques sempre divididos exatamente 50/50. O reino vizinho também é simulado, defendendo-se e potencialmente atacando o portal. Retaliações e chefes surgem de condições, não de um contador obrigatório fixo.

Inimigos têm objetivos variados: abrir passagem, infectar, roubar, sabotar produção, destruir depósito ou atacar centro. O jogador pode realizar expedições e destruir focos de corrupção para reduzir ameaça.

## 9. Diplomacia e expansão

No MVP apenas um reino e um vizinho econômico simplificado. Futuro: tribos, vilas autônomas, relações e reputação, aliança, comércio/tributos, conflito, conquista, reorganização/fusão dos territórios e fast travel por docas ou postos.

Para territórios distantes, o jogo preserva estado serializado e executa simulação agregada; somente perto do jogador materializa NPCs individuais.

## 10. Menu e save

Menu principal: Play, Options, Exit/Back conforme plataforma. Play apresenta seis slots: Empty/Create, Load, Rename e Delete com confirmação. Mundo é gerado por seed estável; progresso salvo por slot, com versões/migrações e proteção contra gravações simultâneas.

## 11. Vertical slice obrigatório

Uma área inicial e um trecho de corredor, câmera e controles mobile, combate básico, 12–20 NPCs de teste, 3 funções de trabalho, um depósito, duas muralhas, recursos madeira/pedra/comida, uma profissão de transporte, bolsa visual, um foco hostil, uma raid, salvar/carregar um slot e um trecho breve de prólogo. Metas de FPS e contagem definitiva só após perfil real em mobile.

## 12. Fora do MVP

Multiplayer/PvP, 6 slots robustos completos em interface, boss raid lv10, guerra e conquista, fusão automática de reinos, relações profundas, catálogo aleatório não curado, montarias complexas, estações extensas e simulação de continentes inteiros em Instances. São requisitos de roadmap, não eliminados.

## 13. Critérios de experiência

- Em até poucos minutos, o jogador anda, luta, protege aldeões e percebe diferenças entre atacar e comandar.
- Trabalhos têm efeito rastreável sobre estoques e edificações.
- Perdas do reino e recuperação de materiais são explicáveis, sem duplicação.
- As raids variam objetivo e direção; existem sinais claros antes de ataques muito fortes.
- No mobile a interface é legível, câmera enquadra combate e comandos e não há necessidade de controlar unidades uma a uma.

## 14. Emenda V0.2 — três dimensões, controles e rio

Decisão de 2026-11-21: **todo cenário é geometria/terrain 3D; nada de parallax 2D**. A câmera fica lateral. Jogadores e NPCs percorrem o mesmo corredor lógico de esquerda/direita; Z não é direção de entrada locomotora do jogador. O fundo próximo é cenário 3D interativo com pontos de trabalho; o fundo distante é visual e geografia. Silhuetas da frente usam objetos 3D baratos que devem parecer absolutamente pretos (sem clarear com o céu/noite), mas nunca cobrir combate ou interface; verificar técnica no render mobile antes de prometer resultado.

Controles em solo: esquerda/direita move X; cima/baixo só orientam suavemente o corpo R6 para o fundo/câmera, não movem Z; diagonal em terra combina deslocamento horizontal com orientação sem deslocamento Z. Em água, cima sobe em Y, baixo mergulha em Y, diagonais combinam X/Y com aceleração e desaceleração naturais. Rotação e animação devem transicionar suavemente, sem CFrame teleport por frame. Utilizar Humanoid/Swimming em Terrain Water nativo e prototipar adição vertical e controle de orientação sem brigar com a flutuabilidade.

Rios descem visualmente de montanhas 3D no background, atravessam a faixa jogável e continuam pelo primeiro plano; usar Terrain water onde há volume nadável, e visual extra somente onde água inclinada/cachoeira precisar representar fluxo. **Roblox Terrain Water não simula hidrologia/fluxo morro abaixo automaticamente**; testar no motor as transições de volumes e correnteza opcional. Riachos rasos são atravessáveis a pé; rios profundos exigem nadar, usar travessia ou ponte.

Pontes possuem evolução: sem ponte (só nadadores onde aplicável) → passagem leve temporária para trabalhadores/construtores → ponte firme para NPCs, cargas e montarias terrestres. Travessia/capacidade é dado de rota de navegação, não só colisão visual. Não exigir que NPCs ou montarias façam natação se não existe habilidade/rota.

## 15. Emenda V0.2 — construção livre, inventários e profissões

Construção livre = usuário seleciona posição contínua válida (sem grid de slots predefinidos), porém geometria e volumes de ocupação ainda são verificados: terreno, inclinação, footprint, colisões, acesso, zonas seguras e regras de categoria (fazenda perto de água irrigável; ponte conectando ambas as margens). Validação de cliente serve só para preview; servidor verifica posição, posse, custo e capacidade.

**Obra em dois progressos separados**:
1. Blueprint/sítio de obra com requisitos de materiais; qualquer NPC que passe com um item aceito no inventário pode depositar até completar os requisitos, mesmo sem depósito. Transferir peso e quantidades do inventário para estoque reservado da obra de forma transacional, idempotente e sem duplicação. Trabalhadores podem ir buscar material faltante, mas não são obrigados a passar por um galpão.
2. Com materiais prontos, progresso de mão de obra (unidades de trabalho), salvo continuamente em checkpoints; interrupção noturna, ataque, falta de trabalhadores ou descanso NÃO zera avanço. Obra finaliza quando trabalho chega ao total. Invalidação/cancelamento precisa oferecer política clara de devolução/salvage; obra destruída não duplica material.

**Eficiência inicial proposta pelo criador** (multiplicadores de velocidade, NÃO porcentagens): carpinteiro 3x em madeira e 1x em pedra; minerador 3x em pedra e 1x em madeira; construtor generalista 2x em qualquer estrutura; trabalhador sem especialização 1x. Algumas obras exigem uma profissão licenciada/equipamento específico apesar do multiplicador. Experiência/proficiência em nível (ex.: 10), ferramentas, fadiga, saúde e complexidade da receita ajustam unidades por segundo, com limites contra explosão de velocidade.

NPC: R6, personalidade e habilidades; inventário real com slots, massa por item, limite de carga, equipamentos e ferramentas separados de estoque transportado. No jogo-base, o personagem deposita materiais diretamente na obra, transporta para depósito ou consome conforme a ordem e a necessidade. Sobrecarregado = perde velocidade/recusa recolher mais, não apaga itens.

## 16. Emenda V0.2 — progressão, corrupção e spoiler

Infecção interna contagiosa de moradores que retornam do exterior é um sistema **posterior**, não ativado nos primeiros minutos nem no tutorial, pois pode causar derrota precoce inevitável. Quando entrar, exige introdução didática, sinais/sintomas detectáveis, cura/isolar/evacuar e janela de reação. No prólogo só existe a infecção roteirizada do duque; outras ameaças são controladas para garantir aprendizado.

A história tem revelações confidenciais de longo prazo em documento privado. Não expor detalhes na documentação pública.

## 17. Emenda V0.2 — monetização planejada e limites

Jogo PvE/solo no primeiro lançamento, com comércio pago por Robux e possibilidade FUTURA de anúncios recompensados elegíveis. Todos os meios pagos são opcionais; nenhuma construção exige ver propaganda para progredir.

- Aceleração de obras: a duração-base de trabalho é dividida em três parcelas de unidades de trabalho. Cada voucher de anúncio válido avança até 1/3 da duração-base, com limite no trabalho restante e máximo planejado de três vouchers por obra. Se trabalhadores avançaram metade, o restante diminui normalmente. O cronômetro e a duração-base são dados imutáveis por obra; nunca calcular duração reduzida em cima do saldo residual repetidamente, para não criar resultados inconsistentes.
- Alternativa Robux: developer product de conclusão instantânea (somente após materiais suficientes ou oferta explícita que inclua a entrega de materiais). Idea do criador: um pacote premium pode **reembolsar** materiais gastos, mas isto precisa ser uma nova concessão auditável e única, mostrada como bônus pago, não 'desfazer' consumo lógico e reaplicar a mesma construção. Não implementar devolução infinita, duplicação, ou bônus silencioso.
- Starter pack: montaria de início rápida/com HP extra e recursos, só em PvE; caso PvP futuro, isolar vantagens econômicas e atributos de combate em modos simétricos ou aplicar normalização, sem pay-to-win.
- A oferta de vídeo só poderá funcionar depois da elegibilidade Roblox (jogo público, 2000 visitantes únicos/mês, conta com ID verificado, 2FA e demais requisitos), opt-in e disponibilidade do anúncio. Não garantir 3 anúncios seguidos; se indisponível, progresso gratuito por trabalhadores continua.
- Roblox Rewarded Video exige itens específicos (Developer Products disponíveis para Robux), premiação não aleatória e sem desbalancear economia; vídeo 6–30s e anúncio fora de combate/seguro. Processar comprovante com controle de duplicação em servidor e fallback caso a obra-alvo seja destruída ou já concluída. Romance como conteúdo de jogo pode impactar elegibilidade de anúncios; reavaliar documentação no lançamento.
- Medir retenção, impacto de aceleração, perda de receita e insatisfação antes de otimizar monetização.

Fontes principais: https://create.roblox.com/docs/production/promotion/rewarded-video-ads ; https://create.roblox.com/docs/reference/engine/classes/AdService ; https://create.roblox.com/docs/production/monetization/developer-products .

## 18. Divisao oficial V2 — substitui alocacao V0.4

O jogo medieval solo completo sera construido em tres temporadas de 3 runners cada:
- T1 FUNDAÇÃO: mundo 3D, agua/controle R6, persistencia 6 saves, NPCs autonomos, inventarios com peso, construcoes com entrega progressiva, muralhas, combat basico, economia inicial, prologo e raid inicial.
- T2 FINALIZAÇÃO: ampliar mundo e biomas/streaming, rios/pontes/montarias, mercado/cadeias completas, diplomacia e relacoes/reinos NPC, portais e contaminacao com sinais, ataques estrategicos, dominio/fusao territorial e progresso medieval completo. Nenhum sistema essencial deve ficar esperando T3 para funcionar.
- T3 CONTEUDO E POLIMENTO: mais biomas, edificios, NPCs, monstros, montarias, eventos, bosses e localidades; equilibrio, UI mobile, acessibilidade, efeitos/animacoes, performance, tests de regressao, seguranca, monetizacao opcional (se elegivel) e release candidate.

Ordem exata, referencias por runner e gates: docs/SEASON_RUNNERS.md. As fontes e evidencias do jogo original ficam em docs/research; nossas formulas/arquitetura original em ROBLOX_ADAPTATION.md. Depois de cada R3 publicar apenas staging verificado e pedir avaliacao do criador, com tres runners de refinamento se necessario. Sistema multi-jogador/PvP e lore privada continuam fora da versao medieval inicial.

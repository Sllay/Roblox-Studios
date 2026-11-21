# Game Design Document — Between Kingdoms / Entre Reinos

Versão: concept-0.1, 2026-11-21. Requisitos do criador; valores de balanceamento ainda provisórios.

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

- Um eixo longitudinal de jogabilidade X; relevo Y; Z usado para profundidade e, futuramente, pequenas faixas navegáveis explicitamente definidas.
- Fundo: florestas, relevo, montanhas, parallax. Faixa jogável: R6, animais, estruturas, combate. Primeiro plano: rio/mar, barcos, docas, bancos de terra e silhuetas que nunca obstruam interações importantes.
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

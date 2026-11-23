# ENTRE REINOS — Auditoria de completude e rastreabilidade do jogo medieval solo

**Iniciada:** 2026-11-22. **Revisão auditada:** staging v14 (Place 90623742498445). **Fonte canônica:** `VISION_MASTER.md`, `../GDD.md`, `../ARCHITECTURE.md`, `SEASON_RUNNERS.md`, `RUNNER_PROTOCOL.md`, `DECISION_LOG.md` e os 27 módulos Luau do Place em `game/places/main/src`.

> **Este relatório não certifica jogo completo.** A CI verifica scripts/lógica/build; somente um teste funcional Roblox real, com saves e dispositivo, verifica a jogabilidade e a experiência. Mesmo um módulo presente pode estar parcialmente integrado ou nunca exercitado pelo jogador.

## Regra de encerramento obrigatório

Cada funcionalidade de lançamento recebe: ID único, dono (runner), estado, consumidor de gameplay, testes que fecham o fluxo e evidências de save/robustez. Nunca interpretar presença do arquivo, função, catálogo, tela ou um teste sintético como “100%”. Se uma parte tiver deficiência, o requisito é **PARCIAL**.

Estados: **PARCIAL** = implementado apenas em parte e/ou testes reais pendentes; **AUSENTE** = fluxo de lançamento não existe em runtime; **PLANEJADO** = específico de T2/T3, ainda sem implementação; **VALIDADO** = conjunto completo de evidências automatizadas e Roblox/mobile com aprovação do criador. Nenhum dos itens abaixo é marcado VALIDADO apenas pelo código.

**Gate absoluto de temporada:** nenhum requisito pertencente aos seus runners pode estar AUSENTE/PARCIAL para declarar a temporada fechada. T1 pode fechar uma *fundação*, mas a T2 precisa completar **todos** os fluxos fundamentais. T3 adiciona conteúdo/variedade/polimento e não é depósito de funções fundamentais esquecidas. Defeito em T1/T2 → camada F1/F2/F3 **da mesma temporada**; não maquiar com um texto de pendência na T3. Ao fim da T3: zero requisitos de lançamento sem dono, zero AUSENTE/PARCIAL, zero falha crítica/alta de gameplay ou save, staging aprovado em mobile pelo criador antes de produção.

## T1 — Fundação que ainda exige provas ou refinamento

| ID | Owner | Estado | Função e condição concreta de conclusão |
|---|---|---|---|
| ER-001 | T1-R1/F | PARCIAL | Menus e 6 slots: criar, abrir, salvar, fechar, excluir, reconectar e repetir sem trocar mundos/sobrescrever; validação de dados e telas reais. |
| ER-002 | T1-R1/F | PARCIAL | Compatibilidade de saves: formato, regras e gerador independentes de revisão do Place; upgrades testados, backups restauráveis, rollback seguro, erro inteligível e **nenhum wipe automático**. Há guard de versão mas ainda não pipeline completo de migração/restauração. |
| ER-003 | T1-R1/F | PARCIAL | Terrain 3D/rios/quatro planos visuais/câmera lateral: arte final sem parallax 2D, sombras/foreground legíveis, chunks, sem sumiço/oclusão e sem travar FPS. |
| ER-004 | T1-R1/F | PARCIAL | Controle R6: X lateral, olhar frente/fundo sem mover Z, corrida, pulo, subida/mergulho/diagonal em água nativa; teste mobile do usuário aprovou água, faltam regressão e perf. |
| ER-005 | T1-R2/F | PARCIAL | NPCs R6 e animações: sem jitter, afundamento, clipping, colisão com jogador, leitura da atividade, roupas medievais e visual correspondente. Não aceitar “60 FPS geral” como prova de movimento fluido. |
| ER-006 | T1-R2/F | PARCIAL | Trabalhos prioritários: profissão, necessidades, fadiga, riscos, bag real, ordem, ações determinísticas e pausas/retomadas depois de ataques e saves, sem loops/travamentos. |
| ER-007 | T1-R2/F | PARCIAL | Madeira, pedras, ferro, comida: coletar de origem real, transportar, reservar, entregar, consumir sem duplicação; árvore marcada deve ser fonte rastreada, com corte/depleção visual e restauração após reload. v14 iniciou, teste humano pendente. |
| ER-008 | T1-R2/F | PARCIAL | Galpão: NPC deposita de fato, capacidade real, obra consome também materiais estocados, inventário persistente, destruição divide recursos entre perda/roubo/salvage uma única vez; v14 iniciou **depósito**, mas retirada para obra e perda integral do galpão ainda precisam fechamento. |
| ER-009 | T1-R2/F | PARCIAL | Construção **escolhida pelo jogador** (não deslocamento automático X+15): preview/rotacionar se permitido, validar água/declive/área/rota, cancelar/reembolsar de forma idempotente, progresso material e trabalho, save/load. Atualmente escolhe-se tipo e servidor escolhe posição. |
| ER-010 | T1-R2/F | PARCIAL | Castelo/tesouro, dois galpões iniciais, anéis/distritos, abrigo e casas: mundo novo começa com lista vazia de edifícios; não confundir ícones/texto/cubos com estrutura inicial funcional. |
| ER-011 | T1-R2/F | PARCIAL | Arte 3D de estruturas: tenda, casa, galpão, cerca e muro distinguíveis, progressão visual por estado, colisão/escala coerente, ocupação e dano reais; v14 tem peças geométricas novas, falta aprovação visual. |
| ER-012 | T1-R3/F | PARCIAL | Ataque corpo a corpo e arco: equipamentos visíveis, cooldown justo, flecha gravitacional com colisão confiável, direção/altura corretas, morte/dano real, exploração proibida e controles mobile práticos. |
| ER-013 | T1-R3/F | PARCIAL | Invasores: perigo legível, spawn local no horizonte, noite tranquila e aviso; segunda noite de sandbox agora prevista com raid (v14), testar todas as fases e saves e dificuldade justa. |
| ER-014 | T1-R3/F | PARCIAL | Defesa: muros intactos barram inimigos, civis buscam abrigo real, defensores recebem ordens/equipamentos, flechas usam recursos, casas/depósitos podem cair, perda/recuperação justa. |
| ER-015 | T1-R3/F | PARCIAL | Prólogo fixado completo: escolta do duque, encontro com monstro infectante, transformação, hesitação de guardas, batalha, muralhas caindo, evacuação e coroação ao amanhecer; por enquanto há transições de estado e duque representado, **não toda encenação jogável nem tutorial contextual**. |
| ER-016 | T1-R3/F | PARCIAL | Economia inicial: moedas/tesouro, drop físico, coleta, crafting local, comércio e custo legível; consumir estoque real, não imprimir dinheiro; validar morte/desconexão/duplo toque. |
| ER-017 | T1-R3/F | PARCIAL | Interface de jogo: HUD enxuto, estoques identificados, preço/posse/requisitos/progresso, respostas de erro e ações contextuais em celular pequeno; v13 criou primeira versão, criador precisa aprovar composição real. |
| ER-018 | T1-R3/F | PARCIAL | Vertical slice completo: novo slot → prólogo → construir/estocar/fabricar → raid → sofrer dano → recuperar materiais → reparar → salvar/reentrar; replay em três seeds, sem intervenção dev. |
| ER-019 | T1-R3/F | AUSENTE | Death/recovery inicial: morte do jogador e NPC, soltar/reter itens conforme regra aprovada, respawn sem duplo saque, derrota/continuação e recuperação de sessão. Contratos ainda precisam decisão do criador. |
| ER-020 | T1-R3/F | PARCIAL | Qualidade base: visual coerente, sem textos/blocos dev, FPS/latência/consumo de memória mensurados no aparelho real, relatório de frame pacing e portas RPC resistentes a spam. |

## T2 — Todos os sistemas BASE precisam terminar aqui

| ID | Owner | Estado | Fluxo completo exigido para fechamento |
|---|---|---|---|
| ER-021 | T2-R1 | PLANEJADO | Multi-bioma/multi-reino procedural por seed, rios/cachoeiras, relevo caminhável e localidades coerentes, persistência regional e geração estável em longa distância. |
| ER-022 | T2-R1 | PLANEJADO | Pontes provisórias/reforçadas com custos, workers, acesso por classes de NPC/montarias, travessia e rotas recalculadas ao destruir ponte. |
| ER-023 | T2-R1 | PLANEJADO | Grafo de rotas, navegação NPC/carga/expedição com margens, pontes, abrigos e bloqueio por raid; não caminhar através de água/estrutura sem permissão. |
| ER-024 | T2-R1 | PLANEJADO | Streaming e simulação agregada de cidades longínquas, NPCs/estoques sem duplicação ao ativar/desativar regiões, custo previsível em mobile. |
| ER-025 | T2-R1 | PLANEJADO | Montarias físicas, compra/domesticação, equipamento, stamina/vida, save, travessias e integração real aos controles/raids/rotas. |
| ER-026 | T2-R1 | PLANEJADO | Portos/barco quando geografia requer e alternativa de fast travel solo funcional, não duplicar ou perder veículos/carga ao trocar região. |
| ER-027 | T2-R1 | PLANEJADO | Segundo reino NPC e seus distritos/estruturas/pessoas/economia/território persistidos em mesmo mundo; dois reinos vivos sem duplicação. |
| ER-028 | T2-R2 | PLANEJADO | Todos ofícios-base: ferreiro, artesão, fazendeiro, caçador, transportador, guarda, arqueiro, lanceiro além dos atuais, com trabalho realmente executável. |
| ER-029 | T2-R2 | PLANEJADO | Ferramentas e receitas registradas, forja/tecelagem/agricultura/refinamento/crafting/equipar, insumos → produto → transporte → consumo, UI interativa. |
| ER-030 | T2-R2 | PLANEJADO | Skill XP/níveis e aprendizagem de profissão com efeito mensurável no trabalho, necessidades/fome/sono/sobrevivência, ferramentas/equipamentos usados e quebrados/repostos. |
| ER-031 | T2-R2 | PLANEJADO | Fazenda, irrigação/terreno próximo a água, caça/pesca quando aprovada, alimento finito, refeições e cadeia econômica sem geração espontânea. |
| ER-032 | T2-R2 | PLANEJADO | Mercado/preços dinâmicos, compras, venda, contratos, salário, tributo, impostos, tesouro e economia entre reinos contabilizados e persistidos sem inflação artificial. |
| ER-033 | T2-R2 | PLANEJADO | Relacionamentos NPC↔NPC/jogador: presentes, resgates, confiança/memórias/traços, decisões distintas sob medo/alegria, UI e save. |
| ER-034 | T2-R2 | PLANEJADO | Prioridades de trabalhadores, ordens individuais/de grupo, reatribuição manual, filas e utilidade, sem decisão aleatória que ignore necessidade do jogador. |
| ER-035 | T2-R2 | PLANEJADO | Facções, alianças, reputação, comércio com reinos NPCs e feedback de decisões na diplomacia/logística; simulação offline/agregada coerente. |
| ER-036 | T2-R3 | PLANEJADO | Inimigos variados por registro, saque com custódia, objetivos distintos e resistências; telemetria do comportamento sem IA cara. |
| ER-037 | T2-R3 | PLANEJADO | Infecção real de fauna/cidadãos, transmissão, sinais, isolamento/cura, defesa de iniciantes e progressão justa; duque roteirizado não conta como sistema completo. |
| ER-038 | T2-R3 | PLANEJADO | Portais evolutivos atacando reinos próximos, escolha de direção dependente de ameaças e fatores reais, contra-ataque/expedição/dano/destruição de portal. |
| ER-039 | T2-R3 | PLANEJADO | RaidDirector estratégico, escala e budget segundo dias, defesas, território e estado dos dois reinos; inimigos diurnos quando previsto, boss básico com mecânica. |
| ER-040 | T2-R3 | PLANEJADO | Guarnição/exército e ordens, defesa em múltiplos anéis, expedições e NPCs guerreando, sem teleporte ou dano imaginário para resolver batalha. |
| ER-041 | T2-R3 | PLANEJADO | Conquista de **reinos NPCs em solo**, fusão territorial e administração dos territórios, direitos de posse/saves/moradores sem reset de estruturas; PvP segue fora. |
| ER-042 | T2-R3 | PLANEJADO | Campanha medieval solo com objetivos e conclusões, decisões, desbloqueios, risco, progresso, falha/retomada, tutorial de sistemas já completos. |
| ER-043 | T2-R3 | PLANEJADO | Teste cruzado de todos os sistemas T1+T2: mais de 100 dias simulados, dois reinos, saques, migrações, mortes, region streaming, server failover, nenhuma duplicação. |
| ER-044 | T2-R3 | PLANEJADO | Checklist de integração UI: todas atividades de T2 descobertas e executadas por controle do jogo, não apenas API; galpão, slots, ordens, defesa, diplomacia, portais, viagens. |

## T3 — Variedade, produção e lançamento, não iniciar sistemas da T2

| ID | Owner | Estado | Critério de aceitação |
|---|---|---|---|
| ER-045 | T3-R1 | PLANEJADO | Biomas variados, fauna, vilas/locais memoráveis, identidade stylized 3D, decoração da câmera e composição sem sprites 2D. |
| ER-046 | T3-R1 | PLANEJADO | Catálogo de edifícios, upgrades e visuais, defensores, ferramentas e equipamentos com alternativas reusando sistemas completos; adicionar sem recodificar NPC core. |
| ER-047 | T3-R1 | PLANEJADO | Variedade de cidadãos, perfis, roupa, profissões e relações, montarias/fauna, NPCs reconhecíveis e animações aprovadas. |
| ER-048 | T3-R1 | PLANEJADO | Mundo de exploração com POIs, recompensas e exploração significativa, não só grandes distâncias vazias. |
| ER-049 | T3-R2 | PLANEJADO | Variantes de monstros, boss raids por fases, encontros/eventos e quests de facção, desafio de progressão de longo prazo. |
| ER-050 | T3-R2 | PLANEJADO | Balanceamento comprovado em jogo: progressão, dificuldade, riqueza, produção e tempo de execução por diferentes estilos de jogador, zero softlock evitável. |
| ER-051 | T3-R2 | PLANEJADO | Monetização **opcional** e justa: produto, receipt único, backup, segurança e limites; anúncios recompensados só quando Roblox confirmar elegibilidade. Não bloquear jogo gratuito. |
| ER-052 | T3-R3 | PLANEJADO | UX, áudio, música/SFX licenciados, VFX, legibilidade, tutorial, acessibilidade, controles touch/gamepad/PC e física/animação revisados em partidas reais. |
| ER-053 | T3-R3 | PLANEJADO | Profiling em telefone fraco e PC, FPS/frame pacing, memória, Network/RPC/DataStore quotas, simulação/streaming sob carga, estabilidade após sessões prolongadas. |
| ER-054 | T3-R3 | PLANEJADO | Segurança: remotes maliciosos, exploração de recursos, lag abuse, receipt replay, duplicação de drops/itens, sessão concorrente e anti-cheat autoritativo. |
| ER-055 | T3-R3 | PLANEJADO | Durabilidade: abrir/editar/fechar slots em versões diferentes, backups e restore verificáveis, upgrades, rollback, falhas de save e recuperação após crash sem perda silenciosa. |
| ER-056 | T3-R3 | PLANEJADO | Conformidade, origem/licenças de assets, moderação, telemetria de crashes e retenção, identidade própria, rollback de Place, documentação e staging assinado. |
| ER-057 | T3-R3 | PLANEJADO | **Fluxo final de ponta a ponta**: início/prólogo, primeira vila, produção, defesa, viagem, várias cidades, eventos, batalha/facções/portais/campanha e longa progressão em 6 slots, sem trabalho manual de desenvolvedor. |
| ER-058 | T3-R3 | PLANEJADO | Receber **aprovação humana explícita do criador** no staging. Produção separada somente após checklist ER-001…057 sem pendências impeditivas. |

## Lacunas que estavam pouco explícitas e precisam de dono antes do lançamento

1. **Produção e uso do estoque** (ER-008, T1-F): o galpão agora recebe recursos, mas o planejador de obra ainda procura `availableSource`, ignorando depósito. Sem consertar, o próprio galpão pode esvaziar as fontes e impedir construção. Revisar reserva e devolução por fonte/estoque no mesmo ledger, sem duplicação.
2. **Destruição do depósito com itens** (ER-008/014, T1-F): a lógica de ruína trata principalmente `delivered` (materiais gastos para construir), não o inventário `stored`. Exigir partição auditável de recursos depositados, bloqueio de acesso à ruína e salvamento parcial uma só vez.
3. **Escolha livre de localização e cancelamento de obras** (ER-009, T1-F): v14 ainda seleciona automaticamente terreno próximo; permitir prévia no mundo, confirmação, cancelamento com custos/estorno consistentes.
4. **Castelo, armazéns iniciais e distritos** (ER-010, T1-F): `LivingModel.new` cria quatro NPCs e seis fontes, mas `buildings={}`. Projetar montagem inicial real antes de dizer que há reino/castelo ou anéis para defender.
5. **Visual vs lógica da árvore** (ER-007, T1-F): o `ProximityPrompt` marca uma fonte de madeira de um `LivingModel.site`; árvores decorativas de `WorldService` não são cortáveis. Unificar referência visual/lógica por ID sem duplicar estoque ou simular queda inexistente.
6. **Acesso ao estoque/produção sem confusão** (ER-016/017, T1-F): dizer claramente 'material na natureza', 'na bolsa do NPC', 'reservado', 'no galpão' e 'consumido', além de ação contextual/craft que atende às mesmas condições verificadas no servidor.
7. **Prólogo não é só FSM** (ER-015, T1-F): duque, escolta, hesitação dos guardas, infecção, muralhas e coroação devem acontecer como cenas realmente jogáveis com atores/dano/progressão/UI, não apenas mudanças de `prologue.stage`.
8. **Morte, civis e recuperação** (ER-019, T1-F): não há política aprovada de derrota/respawn, perda de itens/moedas e morte dos habitantes; travar definição antes de permitir campanha destrutiva.
9. **Habilidade/relação atual é placeholder** (ER-030/033, T2-R2): `skill=1` no modelo não implementa XP; `hunger/fatigue` e defesa simples não são relacionamentos/profissões completas. Não fechar T2 apenas por campos serializados.
10. **Construções e upgrades de muralha** (ER-011/046, T1-F e T3-R1): cinco modelos base não são castelo, casas por nível, fábrica/oficina, torres, portões e distritos com progressão; níveis **funcionais**, não só escala/cor.
11. **Viagem e política de tempo descarregado** (ER-021…027, T2-R1): simulador atual usa 4 chunks finitos; futuro mundo entre reinos precisa de grafo, streaming, regra de offline save, travessia de água e reconciliação.
12. **Profissões integradas à infraestrutura** (ER-028…034, T2-R2): cada profissão deve coletar/produzir/equipar/vender fisicamente e interagir com demandas da vila, estoque e prioridades, não apenas existir no catálogo.
13. **Campanha, portais, diplomacia e conquista solo** (ER-036…044, T2-R3): todas as condições de vitória/derrota, escolhas e consequências de múltiplos reinos precisam ter gameplay. Não confundir um duque infectado com o sistema de corrupção, nem uma raid estática com um diretor estratégico.
14. **Estado save vs revisão do Place** (ER-002/055, T1-F e T3-R3): Roblox revisões não fornecem automaticamente runtime isolado para saves antigos; separar versão de formato/regra/gerador, migrar com backup e teste ou proteger sem sobrescrever; restaurar dados requer ferramenta certificada, não só "duplo toque excluir".
15. **Regras ainda ABERTAS na Bíblia**: morte/respawn, relógio offline, economia e salários, curva de raids/portais, seleção de reinos/escala, balanceamento de montaria, preços/recibos, recuperação de armazém. São decisões de design a registrar em `DECISION_LOG.md`, não valores arbitrários adotados como definitivos.
16. **Ambiente real como prova** (todos): cada fluxo precisa de evidência da CI + Roblox engine + vídeo/captura e medição no mobile do criador, quando aplicável; não transformar o estado de `success` do GitHub em certificado visual.

## Evidências candidatas T1-F1 — 23/11/2026

| IDs | Avanço verificado na branch | Evidência restante |
| --- | --- | --- |
| ER-001/002 | Snapshot validado antes de escrever. Testes de limite da v15, versão legada/futura, identidade do backup e lease. | DataStore real, recuperação operacional, reconexão e seis slots em partida. |
| ER-006/007/008 | Obras consomem estoque finito. Reserva de oferta/demanda/capacidade, reload em trânsito, árvore marcada e estoque de ruína isolado passaram em Luau e motor isolado. | Efeitos e alcance em partida, regras e recuperação da ruína. |
| ER-009 | Prévia a X escolhido, confirmação no mesmo ponto, teste de ocupação/rota e cancelamento antes da entrega. | RPC com cliente real, prévia touch, colisões e estorno após entrega conforme decisão. |
| ER-010/011 | Castelo, dois galpões, muralhas e abrigo inicial exercitados em sete seeds no VM, com apoio no Terrain observado em seis edifícios de uma seed no motor. | Ligações funcionais de distritos, outros anéis, visual e colisão aprovados. |
| ER-014/016/017 | Raid isolou estoque real após perda de galpão. Crafting e venda debitam materiais disponíveis e o HUD reaproveita a consulta do servidor. | Defesa e uso de HUD/munição em partida touch. |
| ER-003–005, 012–015 e 018–020 | A auditoria de código [classificou todos os requisitos](T1_F1_CODE_AUDIT.md). | Runtime/mobile, prólogo interativo, derrota/recuperação e ensaio integrado permanecem abertos. |

As evidências são do candidato sobre uma sessão descartável da v15. Nenhum estado VALIDADO foi adicionado. [Recibo T1-F1](runner-receipts/T1-F1.md)

## Regra de evidências e dependências

Para passar de PARCIAL/PLANEJADO para VALIDADO, anexar em `runner-receipts/`: (a) escopo/IDs, (b) script/asset/versão realmente publicados, (c) testes de origem→reserva→transporte→consumo/alteração de mundo, (d) save/load antes e depois e em versão anterior, (e) rejeição de abuso e casos limite, (f) execução Roblox com usuário, (g) controle e performance mobile, (h) decisão do criador. Efeitos só visuais não aprovam a mecânica, UI sozinha não aprova economia, campos de dados não aprovam jogo, smoke test não aprova fluxo completo.

O fechamento é **cumulativo**: regressões em T3 reabrem ER-001…044. Mesmo com ER-045…058 validados, um ER-008 ou ER-015 ainda PARCIAL bloqueia o lançamento. Requisitos FUTURO fora da primeira versão solo (PvP, co-op multiplayer, segredos privados e eras futuras) NÃO fazem parte do escopo de fechamento; são um backlog separado, sem vazamento de lore privada.

**Contratos prioritários de implementação:** concluir ER-007/008/009/010/014/015/019 e ER-001/002/017 antes de marcar T1 aprovado; completar ER-021…044 até final de T2; completar ER-045…058 e reler TODA a matriz em T3-R3.

### Gate técnico de playtest T1-F1

A T1-F1 passou pelo DataStore real com namespaces sintéticos e cobriu a recuperação de uma gravação com resposta perdida, o backup pré-migração, a reabertura com reserva ativa e o fluxo fonte → NPC → galpão → obra. A partida touch, o teleporte com cliente e a regra final de ruínas/estorno continuam pendentes. Centro, Oeste e Leste agora são associados às muralhas iniciais e usados para identificar a localização das obras. Os estados ER continuam sujeitos às provas de lançamento. [Recibo do refinamento](runner-receipts/T1-F1.md)

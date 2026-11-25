# ENTRE REINOS — PROTOCOLO DE RUNNERS, TESTES E PUBLICACAO

Versao 1.0 — 21/11/2026. Obrigatorio para todos os agentes. Nenhuma execucao de runner foi realizada por este documento.

## Antes do runner
1. Ler AGENTS.md global e local, VISION_MASTER.md, DECISION_LOG.md, GDD.md, ARCHITECTURE.md, SEASON_RUNNERS.md e RUNNER_STATUS.json.
2. Identificar o runner pendente mais proximo e seus limites; nao desenvolver escopo do proximo runner/temporada.
3. Listar arquivos e modulos afetados, contratos, dependencias, plano de rollback, testes funcionais e evidencia necessaria.
4. Usar infraestrutura e ferramentas existentes (Rojo, quality gate, Terrain Builder, catalogo de assets). Nao alterar Black Island.

## Durante o runner
- Implementar sistemas completamente dentro do escopo: funcionalidade real, integrações, UI, servidor, save e testes, sem placeholders permanentes.
- Modularidade pratica: componentes por responsabilidade e registries para dados/variacoes; nao criar frameworks vazios ou copiar codigo em cada estrutura.
- Autoridade de servidor e idempotencia de operacoes de estado; client comunica intenção, nao decide dinheiro, danos ou recompensas.
- Schema migravel, todos os recursos com ownership e estado serializavel. Asset/reino/NPC longe pode ter LOD, nunca apagar logicamente sem regra.
- Caso um sistema precise de futura interface, declarara contrato de extensao sem implementar a futura feature.

## Gate de validacao do runner
Sequencia tipica de comandos, executados em ambiente com ferramentas disponiveis:
    python tools/workspace.py validate
    python tools/script_quality.py
    python -m unittest discover -s tests -v
    python tools/workspace.py build --game entre-reinos --place main
    python tools/deploy.py validate

Alem disso, testes especificos do runner, stress/soak e casos limite, acoes maliciosas, save/load, sincronizacao, recursos e integridade. Para camera, nado, Terrain, NPCs e FPS, exigir testes em Roblox real e indicar explicitamente o que continua pendente de analise visual humana.

Se algo falhar, diagnosticar, corrigir e testar novamente. Nao desativar regras nem marcar PASS sem teste real. Commits WIP de desenvolvimento sao permitidos, mas check final e estado validado dependem de evidencias.
Depois de tudo verde, integrar commit aprovado na main, atualizar RUNNER_STATUS.json com SHA, jobs e relatorio/receipt de testes e somente entao abrir o proximo runner. Nao confundir CI verde com aprovacao humana de visual.

## Receipts e status
Cada runner deve ter um receipt versionado em docs/runner-receipts/Tn-Rn.md com:
identidade do runner; commit e branch; lógicas entregues; parametros/limites; testes realmente executados e resultados; link CI; capturas/links do cliente Roblox quando reais; bugs corrigidos; pendencias; decisao de gate; impactos em schemas/dependencias.
Os status oficiais sao planned, in_progress, blocked, validated; no inicio todos planned. Nao declarar validado por existir apenas um plano.

## Publicacao depois de R3
1. Confirmar Tn-R1, Tn-R2 e Tn-R3 validados e na main.
2. Verificar IDs staging e seu vinculo Universe/Place, titularidade, permissoes, snapshot do Place, preservacao de objetos, Scene Sync antes de alteracoes incrementais, assets e rollback.
3. Executar publicacao via workflow oficial e autorizacoes exigidas. Nao contornar bloqueios nem sobreescrever produção ou o Black Island.
4. Registrar recibo da publicacao: SHA, Place, versao real, URL de run, horario, e sucesso confirmado.
5. Pedir ao criador teste completo da camada da temporada e aguardar aprovacao/reprovacao antes de iniciar a proxima.
6. Caso haja problemas, abrir camada de 3 runners de refinamento, sem antecipar a temporada seguinte.

## Exceção autorizada T2-R1

Em 25/11/2026, o criador autorizou uma publicação intermediária do PR #13, branch `entre-reinos/t2-r1-world-regions`, antes de R3 e exclusivamente para playtest. O candidato fixado é `f7d4ac685f2372d066cdf49a19b2b978f2454745`. Essa autorização mantém os gates da temporada e da integração do PR.

- Publicar em uma experiência privada e independente, com Start Place verificado e chave Open Cloud restrita ao novo Universe. O DataStore é separado por Universe. Preservar a v18 e os seis slots atuais.
- O [workflow específico](../../../../.github/workflows/entre-reinos-t2-r1-preview.yml) adapta a publicação oficial e reutiliza Place Provision, Scene Sync, Rojo, compilação Luau e o publicador Open Cloud existente. Um registro versionado do destino aciona a inspeção de somente leitura. Um registro posterior confirma expressamente a substituição da cena vazia, com revisão e digest verificados. O ambiente GitHub é `staging`.
- Registrar `isPublished=true`, revisão, inventário e hashes de scripts por leitura independente. A revisão inicial do Place isolado fica como referência para restauração. Se uma resposta de escrita se perder, verificar a revisão pela API antes de qualquer nova tentativa.
- Aceite visual e validação formal continuam sujeitos aos recibos do jogo. O escopo da T2-R2 permanece no seu gate. [Roteiro da prévia](T2_R1_PLAYTEST.md)

## Refinamento (pacotes adicionais de tres runners)
T1-F1/F2/F3, T2-F1/F2/F3 ou T3-F1/F2/F3. Quando houver mais de um ciclo, usar sufixo numerado para diferenciar.
F1: auditar defeitos, arquitetura, instrumentacao e corrigir a causa das falhas do escopo atual.
F2: corrigir mecânicas, integracao, UI, fisica, animacao e otimizacao da mesma temporada.
F3: regressao total, testes, build, republicacao staging e novo pedido de avaliacao.
Cada F segue gate + commit antes do proximo; nenhuma parte da proxima temporada entra no refinamento. Apos review positivo, marcar a temporada user_approved.

## Regra para a terceira temporada
T3 termina com jogo solo medieval completo. Lancamento em production so apos T3 validada, staging revisado pelo criador, auditoria final e autorizacao explicita. O escopo de PvP/co-op e segredos de futuras eras nao faz parte do contrato inicial.

## Impedimentos verdadeiros
Se ID nao verificado, ferramenta indisponivel, token insuficiente ou CI falho, sinalizar BLOQUEADO com evidência e continuar apenas tarefas locais/independentes que nao exijam o acesso. Nunca inventar verde ou atribuir sucesso a tarefa nao executada.

## Emenda 21/11/2026 — Plano V2 e research-gated workflow

O cronograma V2 substitui a alocação antiga: T1 FUNDAÇÃO, T2 FINALIZAÇÃO de TODOS os sistemas principais, T3 CONTEÚDO/POLIMENTO. Não usar o plano antigo T3 para iniciar portais/infecção/conquista, pois agora devem estar prontos na T2-R3. Nenhum sistema central pode ser omitido de T2 esperando “polimento” da T3.

No começo de cada runner, consultar AGENT_HANDOFF.md e fonte exata de leitura em SEASON_RUNNERS.md; pesquisar RESEARCH_SOURCES.md, MECHANICS_AUDIT.md e ROBLOX_ADAPTATION.md pertinentes. Registrar no receipt a lista de fontes realmente lidas, URL e versão, além das hipóteses testadas. Se fonte não acessível, marcar em RESEARCH_GAPS.md e não inventar suas regras.

Ao terminar um runner, registrar o mesmo protocolo universal: implementação real + testes + corrigir falhas + ci green + commit + RUNNER_STATUS.json atualizado + handoff do próximo. Documentação de pesquisa não altera status planned. Nenhuma mudança de modelo deve alterar a ordem ou os critérios por interpretação própria.

## Emenda 22/11/2026 — 58 contratos de jogo e bloqueio de "jogo de papel"

**Obrigatório em TODOS os runners:** consultar `docs/FEATURE_COMPLETENESS_AUDIT.md` e registrar no receipt os IDs ER-001…ER-058 impactados. Essa matriz rastreia a Bíblia/GDD até a execução real, com exatamente um runner responsável pelo fechamento de cada requisito. Não se pode apagar requisitos, reduzir o requisito ou mover um fundamento da T2 para "polimento da T3" apenas para obter CI verde.

**Status PARCIAL/AUSENTE não é defeito cosmético.** Módulo/Remote/registrador serializável presente não significa gameplay completo. O fluxo deve ter controles/UX reais, lógica e efeitos de mundo observáveis, economia conservativa, persistência, falhas/abusos e prova de uso em Roblox/mobile. Campos em JSON/Luau, estados de FSM e modelos geométricos não equivalem a jogo aprovado.

A CI executa `tests/test_entre_reinos_feature_completeness.py`, que bloqueia um requisito de lançamento sem dono; impede marcar um requisito como `VALIDADO` sem `docs/feature-evidence/ER-nnn.json` com commit, CI, execução Roblox, evidência mobile, save/load, teste de abuso e aprovação do criador; e bloqueia fechar uma temporada enquanto qualquer requisito dela ou de temporadas anteriores estiver aberto. O arquivo de evidência só deve existir com provas reais, nunca com links falsos ou "pending".

- **T1** entrega fundamento funcional, sem fechar ER-007/008/009/010/014/015/019 enquanto houver árvores decorativas não cortáveis, galpão sem retirada para obra, construção sem preview, castelo inicial ausente, abrigo/invasão sem gameplay, prólogo só por FSM ou death/recovery sem contrato.
- **T2** precisa terminar todos os ER-021…044 de verdade; nenhum pode ser transferido ao T3 apenas porque envolve muitas integrações.
- **T3** amplia e polimenta, revisa a matriz cumulativamente e não publica produção se qualquer ER-001…058 ainda estiver aberto.
- PvP, coop/multiplayer e segredos de eras distantes estão FORA do lançamento solo medieval; não inserir lore privada em documentos públicos.

A política de save por atualização é: preservar formato/ruleset/gerador compatíveis, migrar somente por caminho testado e restaurável, proteger formato futuro/sem conversor. Deleção permanece ação deliberada do jogador com confirmação; preparar rollback/backups auditáveis antes de migrações ou exclusões destrutivas. Jamais usar revisão do Place como substituto do contrato de dados.

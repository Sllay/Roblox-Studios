# Mapa de integração · T2-R2 · ER-028 a ER-035

A implementação em branch foi autorizada após o playtest parcial da v19. A certificação cumulativa e os gates de integração e publicação permanecem registrados no [protocolo](RUNNER_PROTOCOL.md).

## Contratos e pontos de entrada

| ID | Integração prevista | Prova de fechamento |
|---|---|---|
| ER-028 · Profissões | Evoluir `ProfessionDefs`, o agendamento em `WorkEngine` e a apresentação atual dos moradores. Ferreiro, artesão, fazendeiro, caçador e transportador precisam de fontes, destinos e trabalho executável. Integrar guardas, arqueiros e lanceiros à fila e ao abastecimento existentes. | Acompanhar cada ofício da atribuição ao resultado e reabrir trabalho em andamento. |
| ER-029 · Ferramentas e crafting | Compor `ItemDefs`, `Inventory` e catálogo de receitas do `R3Engine`. Entradas, saída com capacidade, ferramentas usadas e transferência têm donos definidos. Mostrar requisitos e estados no caderno/Oficina. | Exercitar falta de insumo, inventário cheio, desgaste, interrupção e replay da mesma operação. |
| ER-030 · Experiência e necessidades | Expandir `LivingModel` por NPC de ID estável. Medir XP por trabalho confirmado, ajustar desempenho com limites rastreáveis e ligar fome, sono e desgaste ao agendamento. | Ganhar XP uma vez por conclusão; medir diferença no trabalho e conferir progresso após troca de região e save. |
| ER-031 · Alimento | Ligar cultivo e irrigação a solo e água do `RegionalProfile`. Usar quantidades e crescimento limitados. Caça consome a entidade/estoque correspondente e alimentação consome inventário. Pesca conforme decisão aprovada. | Simular seca, estoque vazio e maturação durante sessão; verificar origem e destino de cada unidade. |
| ER-032 · Mercado e tesouraria | Reusar débitos e créditos do `R3Engine` e custódia regional. Preço, salário, imposto e tributo geram registros balanceados. Transferências entre reinos exigem routeamento, capacidade e débito confirmado antes do crédito. | Testar insolvência, carga interrompida, lease, retry e ausência de inflação por reprocessamento. |
| ER-033 · Relações | Associar memórias, traços, confiança e eventos a IDs persistentes do `LivingModel`. Vincular presente a transferência real e resgate a evento observável. Limitar histórico sem perder consequências de decisões. | Comparar ações de dois moradores com traços distintos, relações após reativação e custo com mais de uma cidade. |
| ER-034 · Prioridades | Evoluir a escolha de tarefa existente de `WorkEngine`. Ordem manual, prioridade de grupo, demanda, fome, risco e passagem alteram uma fila autoritativa. Cancelamento devolve reservas antes da reatribuição. | Verificar preempção de carga, mudança de ordem, ausência de starvation e reconciliação do trabalho incompleto. |
| ER-035 · Diplomacia | Dar a reputação, facções, trocas e acordos uma ligação a cada reino do `RegionalWorld`, com alterações por evento e resultados mostrados no caderno. A execução de acordos usa estoque e rota válidos. A política offline segue em aberto. | Exercitar acordo, bloqueio de rota, chegada idempotente de carga e efeitos de confiança condicionados ao cumprimento. |

## Economia em regiões distantes durante a sessão

A T2-R1 congela populações distantes e conserva as mesmas referências ao reativar. A proposta para a T2-R2 é usar lotes de tempo limitado de uma **sessão ativa**, sobre o mesmo estado de domínio, sem rigs nem colisões de NPC naquele local. Salvar o cursor de processamento da região junto aos efeitos confirmados. Passagem de sessão, mudanças da hora civil e tempo decorrido com o save fechado precisam de política própria. Até decisão explícita, conservar o congelamento offline.

Cada população tem um único escritor para inventários, jobs e transferências. Antes de ativar ou agregar uma população, resolver o lote em andamento ou adiar a transição. Só registrar o efeito de trabalho após verificar insumos, capacidade, rota e reservas. Uma carga entre reinos tem um ID e uma fase persistida, da custódia de origem à custódia em trânsito e ao recebimento. Reexecutar o mesmo evento após erro de gravação não debita nem credita de novo. Partidas com duas cidades, troca rápida de regiões, falhas de escrita, estoque zero e caminho interrompido são casos mínimos de teste.

Medir trabalho por lote, tamanho dos snapshots e orçamento de DataStore antes de escolher frequência de agregação ou alterar a disposição de chaves. Mudança persistente exige avaliar migração, backup, limite de tamanho, downgrade e o impacto nos seis slots. Decisões sobre taxas, receitas, XP, fome, moldes diplomáticos e progresso offline permanecem abertas. Portais, infecção sistêmica, conquista e guerras permanecem fora desta runner.

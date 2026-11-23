# Auditoria do código da Temporada 1

Base de integração `6d18e19a3f0b0ff92486e9f7400500e3264c282d`. Comparação entre o código, a matriz ER-001–020 e o histórico até a v15. A revisão v15 tem evidência de execução isolada no motor para a bolsa e as flechas. A experiência completa em partida continua pendente.

| Requisito | Classificação | Achado e dependência |
| --- | --- | --- |
| ER-001 | Refinar | `Boot`, `WorldRoute`, `SlotMenu` e `SaveSlotService` já separam lobby, servidor reservado e seis chaves. Saída depende do save de desconexão e a listagem pode apresentar um registro inválido como vazio. |
| ER-002 | Refatorar | `SlotModel` e `SlotLeasePolicy` dão a base de versão/lease. A posição aceita na captura excede o limite aceito na leitura, o payload proposto não é validado antes do write e um retry pode gravar um lease já vencido. Backups/restauração e testes de falha real continuam necessários. |
| ER-003 | Reutilizar e verificar | `WorldProfile`, `WorldService` e `SideCamera` preservam seed, Terrain por chunk e câmera lateral. Oclusão e integridade visual exigem cliente. |
| ER-004 | Reutilizar e verificar | `CharacterService`, `LaneController` e `InputProjection` preservam R6 e o PlayerModule. O nado nativo aprovado precisa de regressão em partida. |
| ER-005 | Refinar | `LivingService.syncNPC` replica pose em lote e `NPCPresentation` interpola; movimento lógico anda em X sem teste de rota. Falta medir jitter por morador e ler trabalho, repouso e combate. |
| ER-006 | Refatorar | `WorkEngine` reserva demanda, mas coleta e depósito competem pela oferta sem reserva; bolsas retidas por interrupções podem impedir novos trabalhos. |
| ER-007 | Refinar | `LivingService.createSiteVisual` liga uma árvore por ID ao prompt e ao estoque; o restante da floresta é decorativo. A depleção visual e a escolha de fontes marcadas precisam de teste repetido com múltiplos trabalhadores. |
| ER-008 | Implementar integração | `Inventory` já tem massa e transferência atômica. Obras ignoram galpões e `R3Engine` ignora o estoque da estrutura ao criar a ruína. |
| ER-009 | Substituir entrada | `BuildMenu` envia apenas o tipo e o server escolhe o X. Reutilizar o blueprint, a validação de custo e o progresso. Verificar a rota e validar cancelamento/reembolso conforme decisão aberta. |
| ER-010 | Implementar | `LivingModel.new` gera moradores e fontes, sem castelo ou galpões iniciais. Preservar posições dos mundos já construídos ao introduzir o assentamento. |
| ER-011 | Refinar | `LivingService.buildVisual` já diferencia volumes. Falta validar apoio real, formas, escala, estados e colisões em partida. |
| ER-012 | Refinar | `CombatService` e `R3Engine` ligam arma e munição ao servidor. Trajetória, hitbox e resposta touch precisam de ensaio com Terrain e muralhas reais. |
| ER-013 | Refinar | `R3Engine` tem aviso e alternância de noites. Testes de domínio cobrem ondas, mas a apresentação e a reconexão em cada fase exigem cliente. |
| ER-014 | Refatorar | Defesa e movimento de invasores usam posição abstrata, e o dano precisa manter coerência com depósitos, rotas e fuga para abrigo. |
| ER-015 | Implementar integração | `R3Engine.command` tem estados e confronto. Faltam sequência física de escolta, infecção, hesitação, defesa e tutorial com atores. |
| ER-016 | Refatorar | A bolsa v15 é finita. A venda ainda retira recursos de qualquer fonte no mapa quando falta estoque próximo. |
| ER-017 | Refinar | `R3HUD` já reúne menus e distingue bolsa e vila. A exibição de disponibilidade deve usar as mesmas reservas do servidor. |
| ER-018 | Implementar integração | Os testes de domínio são separados. O ciclo novo mundo → prólogo → economia → raid → reparo → reconexão ainda não tem evidência de ponta a ponta. |
| ER-019 | Aberto | Boot rearma R6 no respawn nativo, mas não há contrato aprovado de derrota, morte de moradores e retenção/perda. Retenção preserva continuidade; perdas recuperáveis exigem loot persistente e regras de deduplicação; derrota definitiva exige regra explícita e não pode se tornar um wipe de dado. |
| ER-020 | Refinar e medir | Gate, Rojo, tick fixo e diagnóstico existem. Perfil em celular e spam de RPC precisam de verificação separada. |

## Dependências das primeiras correções

- Acertar o contrato de validação do snapshot antes de adicionar estados de logística. Manter chaves de DataStore, versões existentes e tolerância dos registros válidos da v15. Bloquear schema desconhecido. O retorno ao código anterior só é seguro enquanto não houver estados que ele não reconheça.
- Usar IDs existentes de fonte/galpão e a bolsa como custódia. Derivar reserva de retirada do trabalho persistido, sem manter um segundo contador de estoque. Conferir a reserva em construção, crafting, coleta manual e comércio. Na ruína, retirar o estoque utilizável em uma operação e preservar a custódia em separado até a decisão de recuperação.
- A prévia deve pedir validação da coordenada ao servidor e confirmar a mesma posição. Não reaplicar o antigo algoritmo automático como fallback para cliente desatualizado. Posicionamento, inicialização de campanha e visual ficam sobre os mesmos dados e IDs persistentes.
- Validar com os executáveis existentes e regressões no VM. Para reverter desenvolvimento, reverter os commits da branch antes de publicá-los. Publicação futura exige análise específica de compatibilidade com estados já gravados, baseline e procedimento de recuperação.

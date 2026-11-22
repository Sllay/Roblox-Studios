# T1-R1 staging v4 — bug de mundo já ativo

**Estado:** código corrigido, publicado em staging; teste no Roblox real ainda não concluído.

| Item | Evidência |
|---|---|
| Universe | 10769712413 |
| Place | 90623742498445 |
| Versão publicada | 4 |
| Commit do hotfix | `9e07bcd44f7326be264b8e17ee78aca4a047b8dd` |
| CI | https://github.com/Sllay/Roblox-Studios/actions/runs/44977827154 |
| Publicação confirmada | https://github.com/Sllay/Roblox-Studios/actions/runs/44978003846 |
| Leitura independente da publicação | https://github.com/Sllay/Roblox-Studios/actions/runs/44978130381 |
| Diagnóstico isolado Terrain/R6/Plane | https://github.com/Sllay/Roblox-Studios/actions/runs/44977611252 |

**Relato do usuário:** criar mundo dava `server_operation_failed`; save Mundo 1 Dia 1 existia; novas tentativas davam `world_already_active`.

**Causa estrutural identificada:** caminho de entrada marcava sessão e mundo como ativos antes de finalizar personagem e devolver resposta; erro final bloqueava permanentemente outras tentativas no mesmo servidor, sem RPC para retomar.

**Reparo:** Boot passa a ter `resume` idempotente, inicialização por estágios, tratamento de falhas de Terrain/character/lane; cliente tenta recuperação do mesmo slot. SaveSlotService expõe somente o índice da própria sessão. Não há escrita em outro slot nem exclusão de saves.

**Validação:** CI verde; Luau Execution em versão 3 executou world sample+Terrain (574 células de água) e construção de R6/PlaneConstraint em sandbox não persistido. Na versão 4, a API confirmou `serverRecovery=true`, `clientRecovery=true` e 10/10 módulos presentes. Falta teste real do criador.

**Reteste:** abrir um servidor novo, Jogar → **Entrar Mundo 1** (não excluir), conferir se o mundo abre. Caso contrário registrar mensagem e `(etapa: ...)`. Ainda não habilitar T1-R2.

# Agentes — Between Kingdoms

Leia as regras globais `/AGENTS.md` do repositório e este jogo: `GDD.md`, `ARCHITECTURE.md`, `game.manifest.json`, `deploy.targets.json`.

- Trabalho apenas em `games/maps/entre-reinos/`; não editar Black Island nem fazer importações destrutivas.
- Compartilhar módulos existentes apenas através de contratos genéricos e versionados em `packages/`, após verificar compatibilidade.
- Não inventar comandos Roblox, endpoints, direitos de uso de acessórios, IDs de assets ou limites de runtime.
- Monstros, visuais e lore devem ser originais, sem copiar arte/código de Kingdom Two Crowns.
- Primeiro implementar o vertical slice; demais módulos são design planejado, não features implementadas.
- Preservar seis slots de save como requisito; implementar locking de sessão, evolução do schema, escrita atômica por snapshot e orçamento DataStore.
- Jogabilidade principal lateral X/Y com Z visual; Terrain e navegação exigem testes reais, incluindo mobile.
- Todos os saldos, recursos, profissões, combate, invasões, salvamento e perdas são controlados pelo servidor.
- Após checagens verdes, oferecer staging; não confundir testes headless com validação visual.
- Não publicar sem Place/Universe de staging verificados e workflow oficial autorizado; nunca publicar em production sem aprovação.

## Memória obrigatória (V0.3)
- Antes de QUALQUER patch, ler docs/VISION_MASTER.md e docs/DECISION_LOG.md; são a fonte canônica de requisitos do criador.
- Atualizar primeiro a Bíblia e o log quando houver decisão nova. Sincronizar GDD, arquitetura, plano e testes em seguida.
- Não confundir [FIXADO] com [PROPOSTA], [FUTURO] ou [ABERTO]. Exemplos numéricos não são defaults finais.
- Nunca divulgar lore privada em repo público nem em scripts publicados antecipadamente.
- Não usar IDs pendentes listados em docs/ROBLOX_IDS_PENDING.md em deploy até validar vínculo Place/Universe, ambiente e titularidade.

## Processo oficial por temporadas e runners — V0.4

Antes de QUALQUER patch, ler tambem docs/SEASON_RUNNERS.md, docs/RUNNER_PROTOCOL.md e docs/RUNNER_STATUS.json (alem de Biblia, log, GDD, arquitetura e regras globais).
Exatamente 3 temporadas principais x 3 runners principais; cada runner deve ter multiplas implementacoes funcionais, testes, evidence/receipt, validacao e commit antes de iniciar o proximo.
Proibido antecipar funcionalidade planejada para runner/temporada futura; permitir somente contratos e schemas de extensao sem gameplay adiantado.
Depois de R3 (e nunca apenas R1 ou R2), publicar SOMENTE staging verificado mediante procedimentos oficiais/autorizacoes do repositorio, registrar receipt e aguardar revisao do criador.
Se criador reprovar a versao, criar camada de exatamente 3 runners de refinamento para a mesma temporada. Repetir se preciso, sem roubar features da seguinte.
Nao declarar "green", "validado", "publicado" ou "aprovado pelo usuario" sem evidencias objetivas e atualizacao correta do JSON de status.
T3 deve entregar jogo medieval solo completo e jogavel; production apenas com autorizacao explicita e Place separado.

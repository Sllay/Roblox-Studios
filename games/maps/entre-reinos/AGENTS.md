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

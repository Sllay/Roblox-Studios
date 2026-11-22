# Entre Reinos — Staging IDs CONFIRMADOS (21/11/2026)

Os IDs foram comprovados em execução remota de somente leitura usando a API Open Cloud do Roblox, sem publicar ou alterar objetos:

- **Universe ID:** 10769712413
- **Place ID:** 90623742498445
- Versão observada do Place: **1**
- Workflow: https://github.com/Sllay/Roblox-Studios/actions/runs/44975065621 (success)
- Evidência de log: `PLACE_ENROLLED {"verified": true, "recorded": false, "universeId": "10769712413", "placeId": "90623742498445", "version": 1}`.
- A chave existente de `ROBLOX_OPEN_CLOUD_API_KEY` autorizou leitura da experiência; isso não prova permissão de publicação.
- Registro local em `deploy.targets.json` realizado após verificação. `production` continua nulo.

**Atenção:** vínculo de IDs não comprova que o Place esteja vazio nem autoriza substituição integral automaticamente. `game.manifest.json` permanece sem `fullPlaceBuildAuthoritative`; `publish.yml` é manual e exige confirmação de substituição. Antes da publicação, inspecionar o inventário remoto e confirmar se a cena é nova e gerenciada inteiramente por nós. Após isso validar Scene Sync/backup e fazer publicação somente staging.

Não misturar este mapa com `mapa-principal` / Black Island. Não colar secrets no Git.

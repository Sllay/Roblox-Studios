# Smoke test Roblox — Plataforma flutuante e LocalScript

## Escopo
Teste técnico da pipeline GitHub → Rojo → execução remota Roblox, sem alterar código de outros jogos.

- `Workspace.RobloxStudiosSmoke.FloatingPlatform`: Part ancorada, 12 × 1 × 12 studs; movimento vertical ±6 studs.
- `ServerScriptService.CloudFloatController`: Script autoritativo com TweenService, sobe e desce com 2,5s por trecho.
- `StarterPlayer.StarterPlayerScripts.CloudFloatClient`: LocalScript que cria uma barra discreta e confirma inicialização e movimento replicado.
- Sem RemoteEvents, DataStores, permissão de jogador, monetização ou operações de rede externas.

## Resultado da publicação remota — 11 de novembro de 2026

- GitHub Actions: [execução 43108939043](https://github.com/Sllay/Roblox-Studios/actions/runs/43108939043) **sucesso**.
- Universe `10769712453`, Place `118200154785968`.
- Validação de identidade e ausência de colisão entre nomes: **PASSOU**.
- Luau Execution criou/atualizou `Workspace.RobloxStudiosSmoke.FloatingPlatform`, `ServerScriptService.CloudFloatController` e `StarterPlayer.StarterPlayerScripts.CloudFloatClient`.
- `AssetService:SavePlaceAsync({SaveWithoutPublish=false})`: concluído.
- Segunda sessão remota carregou a **versão 2** e confirmou os três objetos e os códigos dos scripts: **PASSOU**.
- Validação visual, dinâmica e mobile: **PENDENTE**, pois scripts de gameplay e física não rodam automaticamente durante Luau Execution Tasks.

O workflow `cloud-smoke.yml` agora tem somente disparo manual para evitar futuras publicações por push. A confirmação de persistência não deve ser confundida com validação do comportamento em partida.

## Implantação segura de teste
O Place ID recebido foi cadastrado em `production`. **Não substituir o Place inteiro com o build Rojo**, pois o projeto local não contém necessariamente a cena completa existente.

Para teste não destrutivo, usar Luau Execution API com `AssetService:SavePlaceAsync()` para inserir/atualizar **somente** objetos com marca `RobloxStudiosCloudSmokeV1`. Conferir associação de Universe/Place e permissões antes de qualquer tentativa.

Pré-requisitos: secret `ROBLOX_OPEN_CLOUD_API_KEY` em Actions, escopos Luau Execution read/write no Universe, opção **Allow place to be updated using Save Place API** ativada no Creator Dashboard (caso o Place tenha sido criado no Studio), sem Team Create ativo.

Se a API rejeitar ou não der resultado verificável, interromper. Não fazer fallback para publicação do `.rbxlx` inteiro.

## Como verificar manualmente no Roblox mobile
1. Abra o Place configurado, após confirmação de sucesso de deploy.
2. Procure a plataforma azul neon próxima ao SpawnLocation, deslocada ao lado do spawn.
3. Observe o movimento suave vertical.
4. Verifique a barra superior: `LOCAL OK | PLATAFORMA FLUTUANDO` significa que o LocalScript iniciou e detectou movimento replicado.
5. Informe resultados e logs. O salvamento remoto deve ser confirmado separadamente.

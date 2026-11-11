# Smoke test Roblox — Plataforma flutuante e LocalScript

## Escopo
Teste técnico da pipeline GitHub → Rojo → execução remota Roblox, sem alterar código de outros jogos.

- `Workspace.RobloxStudiosSmoke.FloatingPlatform`: Part ancorada, 12 × 1 × 12 studs; movimento vertical ±6 studs.
- `ServerScriptService.CloudFloatController`: Script autoritativo com TweenService, sobe e desce com 2,5s por trecho.
- `StarterPlayer.StarterPlayerScripts.CloudFloatClient`: LocalScript que cria uma barra discreta e confirma inicialização e movimento replicado.
- Sem RemoteEvents, DataStores, permissão de jogador, monetização ou operações de rede externas.

## Estado
Build local Rojo e testes no GitHub Actions **não provam** execução efetiva na engine mobile. O status deve ser registrado apenas quando o usuário observar no cliente.

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

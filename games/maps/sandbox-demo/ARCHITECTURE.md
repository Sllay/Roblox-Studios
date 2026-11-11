# Arquitetura — Sandbox Demo

Dois Places independentes: `lobby` e `arena`. Cada um tem seu projeto `default.project.json` em `game/places/`. Os Places compartilham `packages/roblox-common/src` como `ReplicatedStorage.PlatformShared`.

`ServerScriptService/Boot.server.luau` carrega versão compartilhada; `StarterPlayerScripts/ClientBoot.client.luau` inicializa o cliente; `Workspace/StartArea.model.json` declara objetos estáticos.

Não existem RemoteEvents, Datastores ou deploy neste exemplo.

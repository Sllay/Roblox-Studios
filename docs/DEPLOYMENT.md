# Publicação Roblox — planejada, não habilitada

## Requisitos prévios
- Experience/Universe e Places reais criados por fluxo oficialmente suportado.
- IDs reais declarados no `game.manifest.json`; não usar IDs de exemplo.
- Chave Open Cloud com os escopos mínimos necessários e acesso aos recursos corretos.
- Credenciais somente em GitHub Actions Secrets e jamais em arquivos de código.
- Place de homologação separado da produção e aprovação explícita.

## Fluxo desejado

`validate` → `unit tests` → `rojo build` → `upload para teste` → `confirmar operação` → `testes Luau` → `aprovação` → `produção`.

A publicação de Place pode resultar em operação assíncrona; solicitar upload não prova que a publicação concluiu. Nem todo recurso ou classe de Studio pode ser modificado por API. Não presumir atualização instantânea de servidores de jogo já ativos.

**Nenhuma GitHub Action neste repositório publica no Roblox.** Habilitar deploy somente quando a identidade e as permissões dos Places estiverem verificadas.

Referências: https://create.roblox.com/docs/cloud/guides/usage-place-publishing e https://rojo.space/docs/v7/

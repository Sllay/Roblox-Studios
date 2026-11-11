# Template oficial de jogos Roblox

Este diretório é o modelo completo, versionado, usado pelo gerador `tools/scaffold.py`. Não é um Place publicável.

Consulte [a arquitetura canônica](../../../docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md).

Criar um jogo novo:

```sh
python tools/scaffold.py new-game --slug nome-do-jogo --name "Nome do Jogo"
python tools/workspace.py validate
python tools/workspace.py build --game nome-do-jogo --place main
```

Nunca copiar manualmente e inventar estrutura quando o gerador já existe. O código-fonte é compilado em `game/places/main/`; docs e instruções de agentes ficam na raiz do jogo.

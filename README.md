# Roblox-Studios

Monorepositório de desenvolvimento de jogos Roblox orientado por agentes de IA, preparado para trabalhar pelo celular com GitHub, Rojo e GitHub Actions.

## Organização

- `games/maps/<jogo>/`: projeto completo de cada jogo (documentação + código).
- `games/maps/<jogo>/AGENTS.md`, `ARCHITECTURE.md`, `GDD.md`: contexto e regras para agentes.
- `games/maps/<jogo>/game/`: arquivos de jogo, com Places, scripts, modelos e recursos.
- `games/maps/_template/`: modelo para novos jogos.
- `packages/`: sistemas Luau reutilizáveis entre jogos.
- `tools/`: validação, descoberta e compilação.
- `.github/workflows/`: testes e builds na nuvem.

## Exemplo inicial

`games/maps/sandbox-demo/` contém dois Places separados: `lobby` e `arena`.

## Comandos

Requer Python 3.11+ e Rojo conforme `rokit.toml`.

```sh
python tools/workspace.py list
python tools/workspace.py validate
python -m unittest discover -s tests -v
python tools/workspace.py build --all
python tools/workspace.py build --game sandbox-demo --place lobby
```

O build gera arquivos em `dist/<jogo>/<place>.rbxlx`. O GitHub Actions pode validar e compilar sem computador local.

## Publicação e IDs

Cada jogo possui `deploy.targets.json` com seus Universe/Place IDs por ambiente (`staging` e `production`). **IDs não são secretos; nunca inclua chaves aqui.** A chave Open Cloud pode ficar em **Actions → Repository secrets** com o nome `ROBLOX_OPEN_CLOUD_API_KEY`; os IDs ficam apenas nos manifests de deploy. Environment secrets são uma alternativa de maior isolamento por ambiente. O workflow manual `.github/workflows/publish.yml` compila e publica um único Place, com confirmação explícita e validação assíncrona. Configuração de IDs e secrets ainda precisa ser feita por você. Veja [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

```sh
python tools/deploy.py validate
python tools/deploy.py show --game sandbox-demo --place lobby --environment staging
```

## Documentação

- [Arquitetura global](ARCHITECTURE.md)
- [Regras dos agentes](AGENTS.md)
- [Implantação segura](docs/DEPLOYMENT.md)
- [Rojo](https://rojo.space/docs/v7/)
- [Roblox Open Cloud](https://create.roblox.com/docs/cloud)

Cada Place tem seu próprio projeto Rojo e pode ser compilado independentemente. Documentos de agentes e GDDs ficam fora da árvore de objetos exportada ao Roblox.

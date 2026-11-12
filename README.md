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

## Jogos existentes

- `games/maps/mapa-principal/`: projeto inicial com Place `main` e IDs verificados em produção; teste da plataforma publicado e validado no mobile.
- `games/maps/sandbox-demo/`: exemplo técnico de dois Places (`lobby` e `arena`).
- `games/maps/_template/`: modelo canônico de novos jogos.

## Comandos

Requer Python 3.11+ e Rojo conforme `rokit.toml`.

```sh
python tools/scaffold.py new-game --slug novo-jogo --name "Novo Jogo"
python tools/scaffold.py add-place --game novo-jogo --place arena
python tools/workspace.py list
python tools/workspace.py validate
python tools/script_quality.py
python -m unittest discover -s tests -v
python tools/workspace.py build --all
python tools/workspace.py build --game sandbox-demo --place lobby
```

O build gera arquivos em `dist/<jogo>/<place>.rbxlx`. O GitHub Actions pode validar e compilar sem computador local.

## Descoberta de assets e inspeção do mapa

- [Asset Discovery (galeria visual do Creator Store)](.github/workflows/asset-discovery.yml): gera candidates.json, gallery.html, contact-sheet.png e miniaturas em Actions artifacts; nenhum asset é aprovado ou importado.
- [Scene Inspector (Open Cloud, somente leitura)](.github/workflows/scene-inspector.yml): produz scene.json, scene-map.png e report.md com posição de Parts. **Não tira screenshot real nem modifica o Place.**
- Cada jogo tem `ASSET_STYLE_GUIDE.md` e `game/assets/catalog.json`. O CLI `tools/assets/catalog.py` registra escolhas visuais como **pré-selecionadas, não auditadas e não importadas**.
- [Manual dos workflows de assets e inspeção](docs/ASSET_AND_SCENE_WORKFLOWS.md).

## Snapshots e importação estática

- [Manual de auditoria e Safe Import](docs/ASSET_IMPORT.md): política de decoração estática, snapshots, planos versionados e importação somente em staging.
- [Versioned scene snapshot](.github/workflows/scene-snapshot.yml): captura estrutural da versão real, sem escrever.
- [Asset audit and safe staging import](.github/workflows/asset-pipeline.yml): audita um modelo isolado ou aplica um plano explicitamente aprovado em staging. O mapa-principal tem staging separado com identidade verificada; importação real aguarda autorização do asset.
- A substituição integral do Place fica bloqueada até que seu manifesto declare `fullPlaceBuildAuthoritative: true` após revisão da fonte integral.

## Diagnóstico automático de Luau

Os workflows verificam a sintaxe de Scripts, LocalScripts e ModuleScripts com Luau oficial 0.744 e SHA-256 validado. Erros bloqueiam a publicação. Consulte [Quality Gates](docs/QUALITY_GATES.md). Testes de runtime ainda são independentes.

## Publicação e IDs

Cada jogo possui `deploy.targets.json` com seus Universe/Place IDs por ambiente (`staging` e `production`). **IDs não são secretos; nunca inclua chaves aqui.** A chave Open Cloud pode ficar em **Actions → Repository secrets** com o nome `ROBLOX_OPEN_CLOUD_API_KEY`; os IDs ficam apenas nos manifests de deploy. Environment secrets são uma alternativa de maior isolamento por ambiente. O workflow manual `.github/workflows/publish.yml` compila e publica um único Place, com confirmação explícita e validação assíncrona. O mapa-principal já possui IDs e secret funcionais; novos jogos precisam configurar seus próprios destinos. Veja [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

```sh
python tools/deploy.py validate
python tools/deploy.py show --game sandbox-demo --place lobby --environment staging
```

## Documentação

- [Arquitetura completa do template (inclui código dos scripts)](docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md)
- [Arquitetura global](ARCHITECTURE.md)
- [Regras dos agentes](AGENTS.md)
- [Implantação segura](docs/DEPLOYMENT.md)
- [Rojo](https://rojo.space/docs/v7/)
- [Roblox Open Cloud](https://create.roblox.com/docs/cloud)

Cada Place tem seu próprio projeto Rojo e pode ser compilado independentemente. Documentos de agentes e GDDs ficam fora da árvore de objetos exportada ao Roblox.

### Pré-validação de assets e staging

- [Asset access preflight](.github/workflows/asset-access.yml) diferencia autorização de carregamento, auditoria e falhas temporárias sem salvar o Place.
- [Staging readiness](.github/workflows/staging-readiness.yml) verifica a identidade do ambiente de teste; exige IDs reais separados da produção. Consulte `docs/ASSET_IMPORT.md`.

### Safe Import 2.0

A primeira árvore individual do pacote Yasu foi importada e verificada no staging (Place 93428341652658, versão 2), preservando as referências PBR. Consulte [auditoria e importação](docs/ASSET_IMPORT.md) e o [workflow Safe Pack Import v2](.github/workflows/pack-import.yml). A validação visual em cliente mobile ainda está pendente; produção não foi modificada.

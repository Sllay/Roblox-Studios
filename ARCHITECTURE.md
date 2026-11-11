# Arquitetura — Roblox-Studios

## Monorepositório multijogos

Cada diretório `games/maps/<slug>/` é um projeto completo, com memória de arquitetura, design, agentes e seu diretório exportável `game/`.

- `games/maps/_template/`: molde que **não** é compilado no CI.
- `games/maps/<slug>/game.manifest.json`: metadados e relação de Places.
- `games/maps/<slug>/game/places/<place>/`: código-fonte e projeto Rojo de cada Place.
- `packages/`: módulos reutilizáveis, versionados pelo mesmo repositório.
- `tools/`: ferramentas locais e de CI.
- `dist/`: compilações geradas; não versionadas.

## Dependências e fonte da verdade

Git é a fonte da verdade para scripts, modelos declarativos e projetos Rojo. `default.project.json` determina as pastas convertidas em instâncias Roblox. Arquivos de arquitetura e design permanecem fora da árvore sincronizada.

Um jogo pode ter N Places; cada Place é compilado em um `.rbxlx` independente. `game.manifest.json` descreve os Places e guarda IDs oficiais somente quando existirem.

## Qualidade e limites

Validação e compilação são separadas da publicação. CI executa validação estrutural, testes Python e build Rojo. Autorização para publicação Open Cloud, ambientes de teste, testes Luau no motor e gestão de assets são etapas futuras documentadas; ainda não são capacidades prontas.

## Evolução prevista

1. Monorepositório, templates, projetos Rojo e CI.
2. Lint/análise estática Luau e testes no motor Roblox.
3. Catálogo de assets com rastreamento, licenças e IDs.
4. Publicação controlada com credenciais mínimas, homologação e aprovação.

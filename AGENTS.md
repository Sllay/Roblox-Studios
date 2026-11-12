# Regras globais para agentes

Este arquivo é o ponto de entrada para agentes de código que trabalham neste repositório.

## Antes de qualquer alteração
1. Identifique o jogo em `games/maps/<slug>/`.
2. Leia `AGENTS.md`, `GDD.md`, `ARCHITECTURE.md` e `game.manifest.json` desse jogo.
3. Leia a documentação técnica específica em `docs/`; inspecione os arquivos existentes antes de propor mudanças.
4. Defina o escopo: não altere outros jogos sem necessidade demonstrável.
5. Para criar jogos ou Places, leia `docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md` e use `tools/scaffold.py`. Nunca invente a estrutura.

## Contratos
- `game/` contém o jogo exportável. Documentos e contexto dos agentes nunca devem estar em `$path` de um projeto Rojo.
- Use apenas APIs Roblox documentadas; sem dependências ou formatos fictícios.
- Obrigatório passar no quality gate oficial Luau (`python tools/script_quality.py`) antes de cada deploy, corrigindo falhas sem desativar a análise.
- Mantenha scripts do servidor e cliente separados, com contratos explícitos.
- Não publique Places sem confirmação manual; IDs reais ficam em `deploy.targets.json`, credenciais somente em GitHub Actions Repository secrets ou Environment secrets.
- Consulte `docs/DEPLOYMENT.md` e use o workflow manual para publicar apenas um Place por vez.
- Nunca inclua tokens Roblox, chaves Open Cloud ou segredos no Git.
- Preserve `packages/` como código compartilhado e evite acoplamento entre jogos.
- Para assets, siga `docs/ASSET_AND_SCENE_WORKFLOWS.md`. Asset Discovery fornece candidatos visuais, nunca autorização de importação. Só usar `tools/assets/catalog.py` para pré-selecionar, com auditoria pendente.
- Scene Inspector é de leitura; não declarar seu mapa esquemático como screenshot real e não inventar biomas ausentes.
- Registre decisões importantes em `docs/adr/` e atualize a documentação afetada.
- Nunca afirme ter executado testes que não foram executados.

## Verificação mínima
```sh
python tools/workspace.py validate
python tools/script_quality.py
python -m unittest discover -s tests -v
python tools/workspace.py build --all
```
O último comando requer o Rojo CLI. Relate claramente quando uma verificação não puder ser executada.

## Controle de alterações e assets

Antes de editar um Place remoto, consulte `docs/ASSET_IMPORT.md`. Não confundir snapshot estrutural com backup completo. Nunca habilite `fullPlaceBuildAuthoritative` para uma cena parcialmente sincronizada. A importação estática exige staging, pré-seleção visual, auditoria, revisão de direitos, plano versionado e confirmação explícita. Não publicar ou ativar scripts de terceiros. Não inventar resultados de auditoria.

## Memória visual de assets

Antes de buscar ou avaliar novamente um asset conhecido, consulte docs/ASSET_VISUAL_MEMORY.md e tools/assets/visual_lookup.py. Reutilize fichas da biblioteca com escopo de evidência explícito. Não invente cor final PBR, espécie ou adequação a bioma. Revisão visual não aprova segurança, direitos ou importação. Se a evidência mudar, marque a ficha como desatualizada e revise apenas aquele modelo.

Safe Import 2.0: for reviewed pack submodels with PBR, follow docs/ASSET_IMPORT.md and tools/assets/pack_import.py. Never use v1 whole-pack import for a single submodel. Do not commit serialized third-party binaries. Staging-only, explicit plan, no automatic production promotion. Confirm actual mobile rendering separately.

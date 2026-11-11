# Visual Asset Discovery e Scene Inspector

## O que funciona sem PC e sem Studio

- Asset Discovery usa a API oficial Toolbox Service (Creator Store) e a Thumbnails API. Não depende de Roblox Studio.
- O workflow de pesquisa retorna artifact ZIP com `candidates.json`, `contact-sheet.png`, `gallery.html` e `thumbs/*.png`. A galeria funciona offline no celular após extrair o ZIP.
- Scene Inspector executa uma tarefa Luau **somente de leitura** no Place via Open Cloud, devolvendo `scene.json`, `scene-map.png` e `report.md`. Não cria nem atualiza objetos.
- O mapa 2D é esquemático: usa posição X/Z, tamanho e cor de Parts; não renderiza o motor, nem simula física, câmera ou iluminação.
- Os dois workflows são manuais. Não fazem deploy nem modificam o jogo.

## Fluxo Asset Discovery

1. No GitHub acesse **Actions → Asset Discovery - Creator Store Gallery → Run workflow**.
2. Preencha `game`, `query` (ex.: `tropical tree`), `biome` e `count`.
3. Baixe o artifact `creator-store-visual-gallery` da execução e abra `gallery.html` ou `contact-sheet.png` no celular.
4. Avalie visualmente nome, criador, miniatura, estilo e adequação ao bioma; abra os links originais para mais informações.
5. Descompacte o mesmo ZIP, disponibilize `candidates.json` ao agente e execute:

```sh
python tools/assets/catalog.py --game mapa-principal --candidate-json /caminho/candidates.json --id 123456 --biome praia --review-note 'Escolha visual; segurança pendente'
```

6. O script grava o candidato em `games/maps/<game>/game/assets/catalog.json` com os estados `visual_shortlisted`, `not_inspected` e `not_imported`.
7. Commit desse JSON pode ser feito pelo Codex/GitHub. Não é uma autorização para inserir o modelo no Roblox.

**Permissões:** a busca pode funcionar sem chave, conforme o endpoint. Se a API exigir autenticação, use opcionalmente `ROBLOX_CREATOR_STORE_API_KEY` como Actions Secret com escopo `creator-store-product:read`. Não passe chaves em inputs ou commits. O secret de publicação é independente.

**Limites:** busca Creator Store beta pode retornar HTTP 429. O cliente aplica tentativas limitadas e falha com diagnóstico, sem fabricar resultados. Miniaturas são representações estáticas do Roblox; não garantem geometria, textura, direitos, ausência de scripts nem qualidade mobile.

## Fluxo Scene Inspector

1. Acesse **Actions → Scene Inspector - Read Only Open Cloud → Run workflow**.
2. Selecione o jogo, Place e ambiente com IDs já registrados em `deploy.targets.json`.
3. O job utiliza o secret `ROBLOX_OPEN_CLOUD_API_KEY` para executar Luau read-only e exportar os resultados em `roblox-scene-structure`.
4. Abra `scene-map.png` para ver distribuição esquemática; use `scene.json` para pesquisas detalhadas.
5. O campo `biome` só usa o atributo `Biome` existente no objeto; se não existir é marcado `unclassified`. O inspetor **não tenta adivinhar o bioma**.

**Limitações:** primeiro conjunto de até 2500 Parts em uma varredura limitada a 30 mil instâncias. Mapas muito grandes aparecem truncados, com aviso. Não há screenshots reais do cliente e não existe verificação visual automática de gameplay.

## Segurança e próximos módulos

- Não usar modelos sem auditoria da hierarquia, scripts e dependências. Modelos gratuitos podem conter código malicioso.
- Não importar nada automaticamente baseado só no nome ou imagem.
- Uma futura fase `Asset Inspector` precisará validar classes, scripts, meshes, permissões e direitos antes do `Safe Import`.
- A arquitetura é composta por ferramentas CLI e Actions. Um futuro MCP Lite pode expor as mesmas funções sem manter o Studio aberto.

Fontes oficiais: https://create.roblox.com/docs/projects/assets/api ; https://create.roblox.com/docs/cloud/reference/features/thumbnails ; https://create.roblox.com/docs/cloud/reference/features/luau-execution

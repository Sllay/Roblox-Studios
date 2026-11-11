# ADR-0001: Monorepositório com isolamento por jogo

**Status:** Aceito

## Contexto

O ambiente precisa ser desenvolvido pelo celular e por agentes de IA, com vários jogos Roblox no mesmo repositório e sem misturar documentação interna com o Place exportado.

## Decisão

Cada jogo reside em `games/maps/<slug>/`; documentos de produto e instruções de agentes ficam na raiz desse diretório, e arquivos exportáveis ficam em `game/`. Cada Place contém seu próprio `default.project.json`. Bibliotecas comuns vivem em `packages/`.

## Consequências

- Agentes conseguem trabalhar em contexto local.
- Builds e testes podem ser seletivos.
- Compartilhamento de código deve ocorrer explicitamente.
- IDs e deploy de Places são configurados separadamente da compilação.

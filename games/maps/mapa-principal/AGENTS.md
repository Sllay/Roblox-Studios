# Agentes — mapa-principal

1. Ler primeiro os arquivos locais `GDD.md`, `ARCHITECTURE.md`, `game.manifest.json` e `deploy.targets.json`.
2. Ler `../../../AGENTS.md` (global) e `../../../docs/architecture/GAME_TEMPLATE_ARCHITECTURE.md` a partir da raiz do repositório. Quando houver dúvida no caminho, partir da raiz e localizar o documento pelo nome.
3. Nunca inventar requisitos de gameplay; o GDD ainda está pendente.
4. Alterar apenas este jogo e os módulos compartilhados explicitamente necessários.
5. Preservar separação servidor/cliente; documentar APIs e critérios de teste.
6. Compilar com `python tools/workspace.py build --game mapa-principal --place main`.
7. IDs registrados não comprovam associação; validar no Roblox antes de publicar. Jamais publicar sem aprovação explícita. Nunca acessar ou divulgar a chave secreta.

8. Para a sequência P4.5 → P5, ler `../../../docs/NEXT_STEPS.md` (ou `docs/NEXT_STEPS.md` na raiz), `docs/P45_POLISH.md` local e os registros Scene Sync. Preservar aceite mobile v13, distinguir vento publicado v14 de aceite visual, e registrar checkpoint após cada passo. Não inventar coleta, biomas ou outros sistemas ainda não definidos.

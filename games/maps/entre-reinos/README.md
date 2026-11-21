# Between Kingdoms (Entre Reinos)

Novo jogo Roblox com cenário integralmente 3D e câmera lateral (jogabilidade X/Y), reino vivo, sobrevivência medieval e defesa contra corrupção monstruosa. Sem parallax 2D.

- **Estado:** pré-produção / especificação inicial, sem Place Roblox associado.
- **Escopo inicial:** campanha solo persistente (Roblox online com servidor individual, não execução offline local).
- **Identidade:** arquivo de jogo `games/maps/entre-reinos/`, independente de `games/maps/mapa-principal/` (Black Island).
- **Tecnologia:** Luau, R6, Terrain nativo, Rojo, ferramentas versionadas do monorepositório.
- **Ambientes:** staging para desenvolvimento; production separado e ainda não configurado.
- **Assets:** reaproveitar somente assets próprios/aprovados da biblioteca comum; evitar copiar assets externos sem auditoria.

Leia `AGENTS.md`, `GDD.md`, `ARCHITECTURE.md` e `docs/IMPLEMENTATION_PLAN.md` antes de implementar.

A pasta foi baseada no template canônico `games/maps/_template/`, que também é usado pelo scaffold oficial `tools/scaffold.py`. IDs de Universe/Place permanecerão nulos até verificação.

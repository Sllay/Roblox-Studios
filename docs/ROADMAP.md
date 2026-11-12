# Roadmap atualizado

- [x] Monorepositório, template, scaffold, CI e builds Rojo.
- [x] IDs por jogo/Place, Open Cloud incremental, teste real publicado e confirmado no mobile.
- [x] Gate sintático Luau oficial, testes negativos.
- [x] Creator Store, galeria visual, catálogo de pré-seleção, Scene Inspector básico.
- [x] Snapshot estrutural versionado e diff (não é backup completo).
- [x] Asset Inspector: carregamento remoto real e rejeição de modelo com Scripts e classes proibidas.
- [x] Safe Import implementado: plano, reauditoria, versão, ID, verificação e evidências; testes automatizados.
- [x] Staging mapa-principal cadastrado e identidade remota verificada (versão 1).
- [x] Get Model habilitou o carregamento de asset público 79689531752352 no staging.
- [x] Safe Import 2.0: Tree_01 extraída, auditada e publicada no staging, versão 2; geometria, PBR, dependências e persistência confirmadas.
- [x] Inventário de submodelos, inspeção offline PBR via RBXM e importação real verificada.
- [x] P3 Scene Sync e edição incremental para escopo piloto; inventário persistente, preflight, mudanças externas e recuperação específica do centro.
- [ ] Generalizar sincronização de propriedades e Terrain fora das regiões, edição acoplada de floresta e recuperação universal; rollback real ainda não exercitado.
- [ ] Análise Luau com tipos Roblox, testes de gameplay e performance.
- [ ] MCP Lite e orquestrador de agentes.

- [x] Asset access preflight com diagnóstico separado de autorização, política e rate limit.
- [x] Staging readiness e bloqueio global de aliases de produção.

- [x] Inventário de packs e extração individual em memória (29 Models, Bush_01 e Tree_01 clonados e serializados).
- [x] Seletor de submodelo, auditoria PBR e plano versionado de importação integrados.
- [x] Tree_01 renderizada no cliente mobile, screenshots confirmam materiais visíveis; usuário identificou ponta do tronco exposta e brilho excessivo.
- [x] P1.1 perfil de assentamento, raycasts e correção staging v3; verificação estrutural completa.
- [x] P1.2/P1.3 laboratório visual A/B e controles locais de iluminação instalados e verificados estruturalmente.
- [x] Usuário confirmou melhora do assentamento de Tree_01 no staging v3 (6 studs). Brilho residual aceito provisoriamente como questão visual não bloqueante; causa não determinada.
- [ ] P2: remover laboratório temporário e controle de comparação, manter Tree_01; validar terreno, perfis de outros modelos, colisões e orçamento de desempenho em uma floresta piloto. FPS ainda não medido.

- [x] Memória visual de 23 plantas com descrição baseada em miniaturas reais de componentes; consulta offline, correspondência de evidências e atualização controlada.
- [ ] Preview texturizado de submodelos e confirmação de cores PBR por planta.

- [x] P2.1 native terrain plan, multi-noise, solid/liquid channels, material-only paint, bounded lake; preview compiled on Roblox staging v3 (43138809195).
- [x] Native terrain pilot persisted in staging v4; material-only painting exact zero occupancy/liquid changes, independent voxel verification passed (43138959424).
- [x] P2.1: usuário aprovou visualmente o terreno piloto no cliente mobile (staging v5), sem ressalvas relatadas.
- [ ] Calibração de assentamento em Terrain, testes específicos de natação/colisões e desempenho medido, batch Scene Builder.

- [x] Native terrain paint on existing region: branch trail, 98 voxels repainted, exact occupancy/liquid invariants and persistence in staging v5 (43139201978).
- [x] P1 temporary lighting lab removed during P2 terrain creation; Tree_01 preserved.
- [ ] P2 continuation: terrain-aware region catalog, multi-feature sculpt editing with baseline, procedural vegetation and collision budgets; dedicated lake traversal and performance tests.

- [x] P2.2 Scene Builder pilot implementation: deterministic vegetation distribution, native voxel material masks, per-species audits, scaled burial and trunk proxies.
- [x] P2.2 publicação e verificação estrutural: staging v6, 32 plantas, 20 colisores, PBR preservado e terreno intacto (43140641424).
- [x] P2.2 aceite visual mobile: usuário aprovou a distribuição da vegetação em staging v6 e confirmou que areia e trilhas foram respeitadas (screenshot IMG_0930.jpeg).
- [ ] Validação específica do assentamento individual, colisões dos troncos, FPS e resultados do RuntimeGroundCheck; não bloqueia início de P3.
- [ ] P2 evolução: generalizar regiões, assets e planos além do piloto; integrar edição incremental P3.

- [x] P3 Scene Sync dedicated workflow and persisted inventory: staging v6, 1,182 instances, stable second read, three-way comparison and mandatory stale-write guard.
- [x] P3 center migration saved v7, independent terrain/spawn/archive verification; whole-service diff identified default StarterPlayer additions; exact read-only reconciliation passed 43143804231.
- [x] Generic Scene Patch CLI/workflow, add/edit/move/adopt/archive/restore/create/update script; tests and live read-only preview 43144089622 passed.
- [x] Post-write Scene Sync v7 committed 43143950368; durable migration receipt, two native Terrain regions and query index.
- [ ] Mobile v7: central random spawn, seamless expanded ground, old gray platform gone, recovery if falling, no regression of forest/lake. Generic patch apply variants and inverse remain untested remotely.

- [x] P3/P4 world migration: 3x3 playable + 16 horizon chunks, connected native river/lake, 138 plants, prop reanchor, 53 spawn candidates, clouds, v8 saved and verified 43147204931.
- [x] P4 initial typed Roblox gameplay policy, executable Luau logic tests (11), negative type gate and runtime diagnostics panel. CI and world verification passed.
- [x] Place Provision: official inventory verified 43147338256, ID enrollment and owned-template clone path implemented; no new Place/Universe created.
- [ ] P4 live mobile: actual spawn distribution, death/corpse physics, river traversal/shore appearance, clouds and FPS; broader typed script coverage and automated engine gameplay still pending.

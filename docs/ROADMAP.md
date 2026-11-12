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
- [x] Mobile v7 user confirmed spawn worked and reported artificial tree pit, low trunk, corpse falling, absent clouds, sparse spawn distribution; superseded by v8 corrective world test.
- [ ] Generic patch apply variants and inverse remain untested remotely.

- [x] P3/P4 world migration: 3x3 playable + 16 horizon chunks, connected native river/lake, 138 plants, prop reanchor, 53 spawn candidates, clouds, v8 saved and verified 43147204931.
- [x] P4 initial typed Roblox gameplay policy, executable Luau logic tests (11), negative type gate and runtime diagnostics panel. CI and world verification passed.
- [x] Place Provision: official inventory verified 43147338256, ID enrollment and owned-template clone path implemented; no new Place/Universe created.
- [ ] P4 live mobile: actual spawn distribution, death/corpse physics, river traversal/shore appearance, clouds and FPS; broader typed script coverage and automated engine gameplay still pending.

- [x] Scene Sync v8 registered 25 native regions, 2,162 observed instances and environment coverage (43147668959); exact world tile hashes match receipt.
- [x] Dedicated prop support reconciliation preview/apply tool, no Terrain writes; paint transform preservation check added. Live read-only central chunk preview 43147865460 passed: 7 supported props, zero moves/reviews/unmanaged; no save.

- [x] v8 mobile regression: no_safe_spawn prevented character creation. v9 native automatic lifecycle hotfix published; separate ray/voxel diagnostics, two trusted scripts updated, terrain and vegetation unchanged. Patch scope rejected default-module delta, reviewed independently; live mobile retest pending.

- [x] P4 v10: user mobile acceptance of death/ragdoll and corpse ground collision; 58 FPS snapshot, 53 voxel-supported spawn candidates, 138 voxel-supported props; server probe not_supported remains open. See games/maps/mapa-principal/docs/P4_EXPANSION.md.
- [ ] P4 expansion: 12 user-selected packs registered in intake; detached inventory, per-component review, import and mobile verification pending. World clock code and tests prepared; staging deployment and mobile validation pending.
- [ ] P4: 4-stud hex barrier source implemented with bounded GUI pool; stage/verify visual effect, expand vegetation/rocks/vines, validate full cycle and performance; no production promotion.

- [ ] P4 asset intake: first run 43172677254 loaded three assets in staging v10; Particle effects has 235 emitters and was truncated at 128, stopping the old shell loop. Punishment stick contains 5 scripts; Rock contains a MeshPart and no scripts. Revised intake keeps bounded partial results, continues other batches unless cloud/system failure, records static policy and source-risk signals without execution. No imports authorized.

- [x] P4 intake audit resumed successfully through 7/12 assets in run 43179500783: static Rock pass, other packs require individual component/code/PBR review. HTTP 429 stopped at eighth asset; evidence recorded in games/maps/mapa-principal/game/assets/audits/p4-intake-43179500783.json. Resume mode skips observed assets; no Place writes or import approvals.

- [x] P4: 12/12 acquired assets loaded and inventoried in staging v10 (runs 43179500783 and 43179707585). 20 scripts identified, none executed. Rock pack model detail truncated at 256/372; PBR, rights, per-component extraction and runtime approvals remain open. Evidence: game/assets/audits under mapa-principal. No Place writes.

- [x] P4 source-only audit run 43179962130: all 20 external scripts compiled with official Luau and matched recorded source fingerprints; zero external execution or Place writes. Wind Effects uses six script-relative requires, RunService, CollectionService, Trails, BulkMoveTo, noise and octree modules. Punishment stick has FireServer/OnServerEvent; Food Meshpack has OnServerInvoke; Dirt Bag has Lighting and two require expressions needing semantic review. No activation or semantic security approval. Evidence p4-code-audit-43179962130.json.

- [ ] P4 environment expansion: first-party wind (native GlobalWind, 6 local Trails, bounded 48 canopy parts, 30Hz), pure policy tests, candidate plan Tree_03/Tree_12/Bush_03/Rock (24 proposed models), exact Safe Import v2 audits and script patch preview. No external scripts activated; no Place writes. See mapa-principal/docs/P4_ENVIRONMENT.md.

- [x] P4 environment preflight 43181270756: Tree_03, Tree_12, Bush_03, Rock exact v2 pass (PBR/dependency fetch), seven script operations preview v10. CI passed. Corrected wind bush mesh names from live inventory; 24-model layout preview tool added, staging apply remains gated. No Place writes.

- [x] P4 native environment layout: 24/24 planned placements, seven chunks, 138 existing plants preserved, CI and preview passed (43181653770). Exact layout recorded; guarded apply and independent verification prepared, not executed. Rights/explicit staging approval and mobile review pending.

- [ ] P4.3 user explicitly authorized staging integration. One-shot workflow runs validated 24-model layout then independently verifies/syncs before the seven-script patch; no production. P4.4 follows only after P4.3. P4.5 is mobile polish/iteration, not final quality.

- [ ] P4.3 recovery: run 43182382445 saved 24 models/8 colliders to v11 but post-save scope gate detected 164 unexpected records (162 identical default PlayerModule subtree copies, one AtomicBinding copy and its parent child-count increment). Recovery proves exact copies against v10, verifies already-saved layout with no repeated save, records baseline, then scripts. Duplicate default accumulation is an open engine/save issue; no arbitrary scope bypass.

- [x] P4.3 staging v12: 24 models / 8 colliders saved v11, independently verified, then seven scripts applied and verified v12. Sync ebc235a; run 43182858125. Exact default-module clone delta remains documented and must be addressed before repeated saves become routine. P4.4 exact asset preflight follows in same run; detail layout engine merged PR #2 (CI passed).

- [x] P4.4 exact preflight 43183544747: 4/4 sources passed PBR/dependencies after hierarchical surface identity fix; eight geometry thumbnails reviewed, 50 MossLeaf meshes inventoried. 20-model detail plan approved for staging preview; surface-mount vines and static stick extraction remain pending.

- [x] P4.4 first detailed batch staged v13: 20 models, 8 colliders, independent PBR/transform verification and Scene Sync 644b5c8; run 43184077707. All 49 terrain digests unchanged from v12. Total 182 environmental models (44 additions across P4.3 and P4.4). Remaining P4.4: dedicated surface mounting for MossLeaf foliage and inert stick extraction; original external Wind Effects scripts not activated. P4.5 is mobile validation and iterative polish, not final game quality.

- [ ] P4.5 mobile feedback: wind foliage mapping and slower visible sway corrected in source; read-only v13 preflight and pure policy tests added. Full tree cylinder migration, smaller abundant stones/sticks, high-altitude dry trees and visible Bush_03 pending. See mapa-principal/docs/P45_POLISH.md.

- [ ] Agent-ready toolchain evolution: capability registry, offline discovery and shared Scene Sync result envelope implemented; transaction/recovery, terrain surface index, real client visual gate and MCP typed interface planned. See docs/TOOLCHAIN_EVOLUTION.md.

- [ ] Terrain Surface Fields: reusable pure Luau height/dry footprint/slope/relief/altitude percentile integrated into environment layout, executable tests; remote layout regression and persistent spatial cache pending.

- [x] P4.5 read-only preflight 43257411211: 182 models, 162 foliage candidates, 93 coupled trunk colliders, exact wind script preview. Terrain surface module CI passed 43257553076. Script-only verified transaction wrapper implemented; wind staging apply initiated.

- [x] P4.5 wind script transaction verified staging v14 (43257825675), sync dd359a0; 49 terrain hashes unchanged. Mobile motion still pending.
- [ ] Roblox API capability research and pinned read probe: official Studio MCP, native geometry/physics, binary input, asset versioning, serialization, testing and runtime stats. Live probe pending; see docs/ROBLOX_API_RESEARCH.md.

- [x] Pinned v14 API probe 43258355023: terrain voxels, pathfinding (8 waypoints), serialization roundtrip observed; headless physical queries returned no hits and EditableMesh permission denied. Evidence persisted. Terrain atlas (materials, altitude, placement) implemented, read-only live validation pending.

- [x] Terrain Atlas live verified v14 (43258670029): material, altitude and placement diagrams from 9216 samples across nine hash-verified playable chunks. Summary recorded; no Place writes.

## Roteiro operacional atual — 2026-11-12

A sequência ativa de P4.5 → P5 está em [NEXT_STEPS.md](NEXT_STEPS.md). S00 (roteiro) concluído; S01 (segurança/transações) é o próximo checkpoint, seguido por S02 Spatial Engine, S03 Asset Lab, S04 Physics Builder/vento, S05 staging, S06 runtime/mobile, S07 visual, S08 APIs/Studio, S09 MCP e S10 handoff. O roteiro distingue planejado, implementado, verificado, publicado e aceite mobile. Baseline v14; não reaplicar planos históricos. As entradas anteriores acima são histórico, não uma fila de execução.

- [ ] S01: composed task gate, exclusive journal, GET-only reconciliation, coupled-root guard and pinned default clone forensic evidence verified; hash-bound Scene Patch transaction preview pending. Default-module cleanup, isolated restore and coupled environment transaction remain open.

- [x] S01 core safety read-only gate: pinned v13/v14 forensics, composed compile, 119 tests, journal/reconciliation, scoped transaction manifest preview 43262312131, CI 43262312418. No Place writes. Coupled transaction and restore remain pending before S05; next S02 read-only surface index.

- [x] S02 native spatial index core live-verified v14 (43263487282): 36,864 samples, 9 tiles, p80 26.51, 44 prior placement heights reproduced, 216 provisional resource points, identical offline replay. Pine species visual identity and final asset contact pending; no Place writes. Next S03.

- [x] S03 Asset Lab core: exact inert legacy stick conversion, 108+108 resource preview including 8 reused rock IDs, 3 Bush_03 moves; native detached scale proof and deterministic replay validated, evidence 472d9e3/run 43265161056. No Place write; final mobile contact and coupled writer pending. Next S04.

- [x] S04 Physics Builder core verified: 94 detached rounded collider profiles (93 replacements + 1 new), 162 foliage candidates, 126 tests and native preview 43268376332. 86 Yasu widths provisional, mobile physics/visual pending. Next S05 coupled transaction and publication gates; no Place writes.

- [x] S05 integrated P4.5 staged v15: 216 resources, 3 bush moves, 94 rounded tree profiles, wind diagnostics, 49 terrain regions unchanged. One save, independent verification and scoped inverse proof; run 43270255683, sync b07058b. Mobile/runtime, yellow pine altitude and default-module cleanup pending. Next S06.

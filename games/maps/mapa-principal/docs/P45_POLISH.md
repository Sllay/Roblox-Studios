# P4.5 — mobile feedback v13

User approved stable performance, day/night and grass/wind. Reported no noticeable tree leaf motion, scarce visible new props, oversized resource stones, absent visible sticks, dry-looking tree should be confined to high terrain, Bush_03 hard to find, trunk colliders too short. Small stones/sticks and bushes remain noncolliding; future collectables only, no gameplay yet. Preserve accepted terrain, lake, stream and death.

First change: exact Inno foliage identity from audited mesh IDs; slower 6.6s ripple and 14.6s gust, max 3 degrees trees / 1.5 bushes, full strength at 8 studs/sec (native wind ~8.5). Keep 48 active/30Hz and local-only motion, diagnostics under LocalPlayer.RSWindDiagnostics. Read-only v13 preflight inventories all actual managed models, mesh flags and colliders, and previews two script updates. No runtime mobile approval or staging write yet. Need actual eligibility and collider evidence before further migration. Cylinder flat top requires separate sloped cap/physics validation; do not claim low friction alone guarantees sliding. Resource density and altitude thresholds provisional; identify yellow tree visually before relocating. No production.

Preflight run 43256116605 failed after successful gates because standalone inspection called undefined output; shared syncResult envelope added, no Place writes. Registry and dispatch contract tests added to avoid repeating this integration error.

## Live preflight passed — 43257411211
182 managed models observed, 162 candidate foliage meshes (53 Tree_01, 38 Tree_08, 4 Tree_03, 4 Tree_12, 47 Bush_01, 8 Bush_03, 8 Inno Leaves). All are anchored/no collide/no touch/no query; 93 coupled trunk colliders observed. Example Tree_03 height ~20.27 studs vs 3.89 collider; Pine_01.1 height ~27.42 vs 7.94 collider. Actual runtime eligibility/motion still needs client testing. Exact two-script preview passed against v13. Patch recorded and staging-only publication initiated with reusable verified script transaction. Terrain fields pure tests and CI passed 43257553076. Need tree trunk base calibration: Yasu trunk mesh bounds include branches, so width is not valid trunk diameter. Horizon trees intentionally lack physical colliders outside playable bounds; do not add distant physics indiscriminately. The standalone tree has no collider, evaluate in playable scope.

## Atualização v14 e próximos passos
A correção de vento foi publicada e verificada no run 43257825675, sync dd359a0, 49 hashes intactos; aceite visual mobile pendente. 182 modelos, 158 jogáveis, atlas/probe de v14 disponíveis. O roteiro ativo é `docs/NEXT_STEPS.md` na raiz (S01–S10); inclui recursos, altitude, arbustos, colisores e ferramentas reutilizáveis. Não tratar planejamento como implementação.

## S03 resource preparation
108 small stones (8 existing Rock IDs reused, 100 new), 108 new sticks and 3 of 8 Bush_03 relocations planned; exact evidence and plan in docs/spatial/v14/s03. Stick converted from legacy mesh/wood texture, all five pack scripts excluded. Native scale proof passed. No staging write, physical contact and mobile visibility pending. Preserve large moss rocks, existing pine identity pending. Next S04 collider profiles and runtime wind diagnostic; S05 combines approved coupled edits.

## S04 physics and wind preparation
94 playable tree profiles prepared (93 replacements, standalone yasu-tree-01 added). Native detached geometry, shape/axis/top/bottom/seam and serialization verified. 86 Yasu widths provisional; 8 pines use branchless trunk bounds. No exact cross-section available; real slide/jump and visual trunk fit pending. 162 foliage candidates verified against published v14 policy, peak sampled 2.764°/1.382°, fixed pivot and wind direction. Added throttled diagnostic source for future deployment; no staging write. S05 requires coupled transaction/recovery and combined plan review.

## S05 published v15
Run 43270255683, sync b07058b. 108 stones, 108 sticks, 3 Bush_03 moves, 94 tree profiles (188 parts) and wind diagnostics persisted; 49 terrain hashes unchanged. 105 preimages stored and isolated inverse proved, one save. 129 Python tests and Luau/LSP/Quality Gate passed. 86 Yasu widths provisional, yellow pine relocation excluded, runtime contact/visibility/collision/slide/foliage and performance not yet accepted. Staging play link https://www.roblox.com/games/93428341652658/ . Next S06 client development lab and manual mobile checklist. No production.

## Mobile v15 feedback and S06.1
User found no small stones/sticks, pines too small/low, vegetation too sparse and apparent overlapping old/new generation, large rocks noncolliding, wind needs branch deformation; old panel unchanged. v16 published diagnostic lab and server collision policy (small resources collide with environment, not living player; large rocks solid). No geometry regeneration yet. Next S06.2 unified vegetation preview, S06.3 pines/resources, S06.4 wind deformation, S06.5 compatibility, S06.6 acceptance. See NEXT_STEPS.md. Mobile v16 verification pending.

## S06.2 unified regeneration preview
212 playable vegetation planned (120 broadleaf, 12 larger pines, 80 bushes), 138 existing IDs reused and 74 new, 24 exterior vegetation preserved. Coverage metric 48.50% ->73.80%; native 212-model/132-collider proof passed 43280368817. No geometry published. Exact plan and maps docs/s06/regeneration-v16; budget blocked (4840 projected vs4500 safe ceiling). Next S06.3 resource replan and pine geometry. Manual test only after all S06 steps per user.

## S06.3/S06.4 checkpoints
Resources/clearings native preview verified 43281759955, all 216 IDs and 49 restored terrain hashes. Original canopy GLB, bone control, stronger macro and authored-rig controller checked in. Existing mesh editing denied; original model upload 403 denied (43282633795), actual skinning/client render still unverified. No staging changes; manual tests only after S06.6. See docs/s06/resources-v16 and wind-v16.

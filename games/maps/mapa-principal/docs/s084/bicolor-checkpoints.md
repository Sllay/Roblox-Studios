# S08.4.1 — Existing foliage cards, 50/50

## Checkpoint 1 — asset inventory and access
- Verified v23 (run 43545991867): 250 common trees, 16 pines, 200 bushes; no new mesh parts, all existing canopy geometry unchanged.
- The four original canopy meshes are third-party Creator Store dependencies, not editable sources in this repository.
- Native v23 probe run 43546179216: all four CreateEditableMeshAsync calls denied by asset permissions. No place writes.
- Roblox official EditableMesh permissions: https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- Roblox official glTF export permissions: https://create.roblox.com/docs/art/modeling/gltf-export

## Checkpoint 2 — deterministic partition algorithm (synthetic tests only)
- tools/asset_factory/canopy_card_partition.py groups independent two-triangle cards by shared vertex connectivity.
- Stable spatial alternation gives equal group sizes for even card counts and at most one-card imbalance for odd counts.
- Returns original face indices only. Does not alter positions, UVs, normals, winding or triangulation.
- Fails closed on non-quad, welded or nonplanar topology; actual Yasu topology is unknown.
- No third-party geometry is extracted or committed.

## Checkpoint 3 — pending source permission
Obtain explicitly authorized editable geometry for meshes 18716595527, 18720235867, 18720273012, 18720345647, or the creator's original files with permission to modify and reimport for this experience. Keep third-party source files private; do not redistribute. Merely acquiring the model does not grant EditableMesh access.

## Checkpoint 4 — pending native integration
For each of four source types, prove exact source-face union and disjoint groups, identical per-corner UVs/normals/positions and world transforms; use Eggydrasil White 89626593244521 and Gray 109528136250293 with independent green tints. Preserve existing card count and trunk, collision, scale, pivots, placement. Two separate canopy MeshParts per tree would add one MeshPart per tree (250 total), not new leaf cards. Update wind to move both groups around one original canopy pivot as one budget entry, not independent swaying. Preserve pins and external scenery. Validate UV silhouette, sunlight angles, alpha, mobile performance and native persistence before publishing. No automatic publishing while blocked.

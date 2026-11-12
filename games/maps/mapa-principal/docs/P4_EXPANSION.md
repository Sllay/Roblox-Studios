# P4 expansion — user-selected assets and world clock

## Accepted mobile evidence (staging v10)
User reports corpse no longer penetrates terrain and death animation approved. Screenshot shows 58 local FPS, 53 voxel-supported spawn candidates, 138 voxel-supported props, 3 deaths, AJU 14 joints/15 colliders. This is a point sample, not an automated gameplay or performance pass. Server probe not_supported; native raycast gap remains. Do not reopen accepted visual issues without regression.

## Intake
12 unique IDs in game/assets/intake-p4.json; duplicate Particle effects removed. User reports Get for all. Names/use are hints, not audited. Run existing Asset Pack workflow per ID, or python tools/assets/intake.py --batch 1 through 4, using authorized Open Cloud environment. Batches are read-only, max 3, stop on rate limits/unknown errors; inspect artifacts. No external scripts activated, no whole pack import, no binaries committed. Inventory may be truncated or model-only; UI/VFX/script assets may require dedicated read-only inspection. Do not mark a non-model failure as permission denial without evidence.

Static: audit exact submodels, rights, dependency fetch, placement profiles, Safe Import 2.0. Rocks/trees/bushes use dry-ground masks, slope limits and coupled colliders; vines require explicit surface anchors/normals and no terrain excavation. Buildings need footprint/support rules. Food/tools stored as inert templates until gameplay specified. UI extract reviewed image IDs. VFX inspect particle/beam/trail settings and dependency permissions, then build trusted local runtime with distance and emission budgets. Wind code is untrusted; inspect source/dependencies without running, reject remote requires/obfuscation, port allowed behavior to owned code; native Workspace.GlobalWind supports grass/clouds/particles but does not replace mesh animation. No claim that pack is a custom GPU shader.

## Clock
Server publishes epoch + 180/60-second settings once; clients derive synchronized phase using Workspace:GetServerTimeNow. Pure shared RSWorldClock maps dawn 06:00, sunset 18:00, midnight 00:00, next dawn 06:00. Client updates Lighting.ClockTime and ambient/brightness 10Hz; no server frame traffic, preserve authored sky/clouds/atmosphere. Durations are source config for next server session; live retiming is not implemented. Roblox ClockTime is not replicated. Server gameplay reads epoch and pure clock; client visual state is not authoritative. Verify latitude/sky visibility and dawn/dusk in actual mobile; night brightness is provisional. Existing CloudFloat behavior untouched.

## Staging sequence
1. CI + fresh Scene Sync (v10 baseline expected, never assume current). Prepare generic Scene Patch with create_script operations: RSWorldClock ModuleScript in ReplicatedStorage, RSWorldTime Script in ServerScriptService, RSWorldTime LocalScript in StarterPlayerScripts. Source paths must be versioned; preview, explicit apply, verify and sync. No full Rojo upload.
2. Audit all 12 packs; build per-component approval and placement plans. Extend generic Scene Builder beyond hardcoded Tree_01/Tree_08/Bush_01. Add 2 reviewed tree species, confirmed extra bush, rocks, vine anchors; preserve existing 138 plants and Terrain digests. Separate props and templates from live gameplay.
3. Barrier: replace 8-stud square presentation with 3–4 stud hex/octagonal look; retain physical five walls and proximity behavior. Use reviewed repeat texture or bounded reusable GUI pool; benchmark before deployment. No geometry/voxel changes.
4. Run mobile scenario: full 240s cycle, sun/moon visibility, join mid-cycle, respawn, river/lake traversal, wall/corners/ceiling, props/physics, FPS p50/p95 and memory, VFX budgets. Expand typed coverage and runtime tests. Retain raycast diagnostic limitation as open. No production publish.

This change is repository implementation/intake only; not a remote Roblox save or asset approval.

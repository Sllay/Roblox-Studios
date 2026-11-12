# Toolchain evolution — agent-ready Roblox engineering

## Purpose
Make game work generate reusable engineering capabilities, not one-shot scripts. Staging remains a testbed; no production writes. P4.5 mobile feedback is the pilot. CLI discovery: python tools/capabilities.py --ready; --id scene.patch; --mode read. Registry is offline metadata, not an MCP server or write dispatcher. Status live_verified means at least one demonstrated path, not universal runtime coverage.

## Priorities (ordered by evidence)
1. Shared contracts and preflight: versioned capability registry, declared dependencies and write scope; shared Scene Sync result envelope; compile composed Luau, not only fragments; typed result schemas; rate-limit safe read resumption. P4.5 failure 43256116605 was undefined output helper in dispatch; fix syncResult and test composition. Existing cloud transport retries GET only; never blindly resubmit saves.
2. Transaction/recovery: generic change-set plan with stable IDs, expected version, scene/terrain hashes, exact operations and explicit staging authorization. Preview all compatible operations in one session, save once, verify independently, record receipt and inverse/recovery. Default PlayerModule/AtomicBinding duplicate accumulation is open (v13 3218 objects); prove cause, do not arbitrarily delete. Current inventory limit 5000 is a guard, not a solution. Do not claim rollback until exercised.
3. Terrain Surface Index: cache keyed by voxel digest; solid/liquid/material, world height interpolation, normals/slope, water clearance, altitude percentile, paths/spawns/exclusion and contact anchors. Shared placement rules for vegetation, stones, sticks, biome suitability, wall vines, buildings. Separate native voxel estimate from runtime raycast. Reuse prop_support and environment_layout; no second inconsistent terrain representation.
4. Asset component extraction: typed inert mesh/texture/VFX/UI templates, source hash, dependencies, rights, PBR and component hierarchy. Tool source stripped only after explicit selection; never execute embedded code. Cache evidence per fingerprint; avoid repeated cloud tasks. Wind foliage mapping and collider profiles per species.
5. Runtime/visual gate: real client scenario replay, screenshots, camera points, FPS/frame-time percentiles, memory, runtime raycast, character collision and day/night checks. Cloud edit-time jobs do not render a client. Start with compact mobile telemetry and user screenshots; investigate official supported Studio/runtime execution before claiming automation.
6. Agent interface: typed CLI/JSON commands first; MCP read tools first, then staging writes gated by reviewed transaction and authorization. Agent task state, checkpoint receipts, tool discovery, context summaries and ownership/locks. No arbitrary Luau execution endpoint, no secrets in agent output. No claim of running MCP service yet.

## P4.5 pilot
User approved day/night, grass/wind and stable performance. Fix foliage visibility, small decorative resources, high-altitude dry species, bush presence and complete tree colliders. Record actual inventory and scene versions, then reuse the solution contracts. No future collection/biome gameplay yet. User will validate on mobile; do not conflate structural checks and runtime evidence.

## Definition of done
Every capability has entry point, mode, dependencies, evidence output, explicit scope and tests. A planned tool is not callable. New features reuse existing APIs and are marked implemented/verified separately. No deadline guarantee; progress recorded in commits and CI.

## Surface Fields first implementation
Pure Luau tools/terrain/surface_fields.luau extracts the existing four-stud interpolation and dry-footprint policy into shared functions, with slope, relief, horizontal gradients and empirical altitude percentile. Environment layout consumes it directly; tests run in official Luau VM plus LSP. Native channel loading and digest verification remain in the caller. This is the first reusable surface policy, not a persistent spatial cache or full biome generator. Future high-altitude tree selection and small prop distribution should consume this policy. Runtime normal/contact validation remains distinct.

## First reusable verified script transaction
Added tools/verified_script_stage.py wrapping existing Scene Patch with versioned plan, current baseline, script-only operation budget, explicit staging authorization, independent verification/sync, terrain equality and durable receipt. Failures mark requires_reconciliation and no automatic retry. This is script-only, not yet the generic multi-operation transaction engine or automatic rollback. Pilot P4.5 wind correction v13.

## Official API research
See docs/ROBLOX_API_RESEARCH.md. Studio MCP is a local optional visual/playtest backend, not currently connected. Pinned read transport and capability probe added; live result pending. Script transaction verified v14, 49 terrain hashes unchanged.

Pinned v14 API probe completed; documented context-specific support matrix in ROBLOX_API_RESEARCH.md. Native terrain, pathfinding and serialization work in sampled context; physics queries returned no hits and EditableMesh permission denied. Terrain atlas implemented as first visual spatial evidence layer; live run pending.

Terrain atlas live verified v14 (43258670029): nine native region hashes, 9216 samples, 158 playable models, altitude p80 26.5. Evidence in API probe summary. Next use exact full-resolution terrain policy for dry-tree relocation and resource distribution. CaptureService and ViewportFrame documented as optional mobile inspection helpers; Studio MCP remains not connected.

## Active execution order
Use [NEXT_STEPS.md](NEXT_STEPS.md) as the current prioritized game/toolchain backlog, with prerequisites and gates. Historical priorities above remain design context. No Studio host connected or production authorization. Every completed step records its own evidence.

S01-A: exact composed Scene Patch compilation, task identity and exclusive write journal, GET-only resume, expected version/digest guard before baseline record. Pinned v13/v14 duplicate comparison read-only. See NEXT_STEPS.md for status; no automatic rollback or duplicate removal.

S01 forensic evidence: v13→v14 164 exact default clone delta records; 14 PlayerModule roots, 2268 records inside, 3385 total. Engine cause still unproven. New transaction manifest binds prepared operations/source hashes and target baseline; preview is read-only, apply existing Scene Patch only, 500-record reserve. GET-only reconciliation does not promote baseline or authorize retry. See NEXT_STEPS.md.

S01-D: hash-bound Scene Patch transaction preview live verified v14 (43262312131), 119 unit tests and CI 43262312418 passed. Diagnostic only, no save. Generic apply path is not newly live-tested; legacy script transaction verified separately v14. Dedicated coupled/Terrain adapter and isolated restore still pending. S02 read-only can proceed.

S02 native 4-stud index live verified, 9 tiles and 36,864 samples; seam-aware interpolation, bounded water clearance, conservative observed model footprint buckets, deterministic candidate positions and hash-keyed per-tile cache. Replay digest identical without cloud. 44 prior height regression passed. See NEXT_STEPS.md and map-local S02 evidence. Candidate locations not actual placement; exact assets and physical contact still pending.

S03 live verified: reusable exact visual component extractor supports MeshPart and legacy identity-transform FileMesh -> MeshPart (strict URI, permission and dependency gates, detached, inert, serialized roundtrip). Resource geometry planning consumes S02 native snapshot and actual dimensions; native detached scale endpoint tests passed. See map-local docs/spatial/v14/s03 and NEXT_STEPS.md. No arbitrary Tool import, no remote writes or final client render.

S04: physics builder uses observed world-space bounds and S02 native terrain; detached native cylinder/ball cap validation for 94 profiles, all 6 EditableMesh probes denied, legacy Yasu widths explicitly provisional, no fake section measurement. Published wind policy verified by deterministic math and scene eligibility; client diagnostic source expanded but not deployed. Real runtime physics pending. See NEXT_STEPS.md and map-local S04 evidence.

S05 coupled transaction live verified v15: exact prepared scene fingerprint, 105 serialized preimages stored before save, isolated inverse comparison, one SavePlaceAsync, independent persisted proof, Git sync. Dedicated scope for resources/bushes/tree colliders/wind; not universal terrain transaction or general rollback. Inventory 4062, default-module accumulation persists; next writes require fresh scoped budget and baseline. Preview output-limit and selector namespace issues fixed. See NEXT_STEPS.md and map-local docs/spatial/v14/s05.

S06.1: client diagnostic lab replaces old P4 panel; reports local loaded meshes, asset fetch status, nearest resource ID and ground ray, local highlight, performance, wind and ragdoll. New server group policy uses native WorldRoot where supported (v15 probe 43278419535 verified), legacy PhysicsService fallback only for older engines. Resource collidability is pair-filtered, not globally disabled; large Mossy_Rock models restored to normal collision. Script-only staging publication under exact reviewed manifest. Runtime physical and visual acceptance still required. Next unified environmental planning must include RSResourcesP45 and distinguish vegetation layers, native grass occlusion and asset streaming.

S06.1 v16 verified staging publication (43278748110). Native WorldRoot collision matrix and local asset/visibility inspection now supported via checked-in server/client scripts. Runtime actual client simulation still unverified. Resource forensic dimensions and revised environmental priorities in NEXT_STEPS.md; default-module growth 4228 records now limits next mutation.

S06.2: native v16 unified model inventory includes resource root; deterministic coverage-aware woodland planner, explicit ground/canopy separation, altitude reservations, source identity reuse and native detached 212-model/132-collider validation. Exact plan and maps in map-local docs/s06/regeneration-v16. Budget gate rejected publication 4840 >4500; service-sharded read-only Scene Sync parity and default clone investigation required before final writer expansion. No Place write.

S06.3/4: material-only paint preview with exact native channel whitelist and 49-region inverse proof; resource clone/scale verification; original skinned GLB authoring and native Bone.Transform proof. Asset upload 403 denied with current staging credential (receipt in map-local docs/s06/wind-v16), no new asset and no Place save. Capability status distinguishes native control from actual client/render verification. Next S06.5 permissions and scalable inspection.

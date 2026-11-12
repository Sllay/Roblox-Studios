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

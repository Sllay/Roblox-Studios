# S07 — Modular architecture

Status: foundation only; v18 remains live. No publication authorized by this document.

## Prop pipeline
1. Registry: typed templates with per-spec overrides; asset geometry and contact anchors are versioned.
2. Spatial planning: reuse SurfaceIndex and Occupancy; deterministic independent scatter, area-weighted quotas across nine playable tiles, 1000 Branch and 1000 Stone. No shared patch anchors.
3. Native placement: wait for verified terrain collision; use surface normal and tangent yaw for resources, world-up yaw for trees. Sample rotated geometry supports; reject unsupported placements. No height fallback or blanket terrain painting.
4. Materialization: stable IDs, chunk folders, shared physics policy, no per-prop scripts. Measure instance count and streaming on mobile.
5. Reconciliation: version-pinned preview, scoped delta, inverse, publish once, read-only verification. Preserve unrelated terrain and scenery.

Proposed size relative to v18: Branch length 1.5, thickness 2.5; Stone uniform 1.25; variation ±20%. Nonuniform scaling requires an audited mesh variant or validated MeshPart geometry, not Model:ScaleTo alone. Existing Stick IDs require explicit migration. Do not remove old resources until new plan passes. Old painted patches require separate reversible material restoration evidence.

## Project-wide modularization
- P0: consolidate transaction orchestration (scene_sync, scene_transaction, p45_transaction, resource_contact_publish) around one preview/apply/verify contract, bounded read-only retries and durable receipts. Never retry an ambiguous save.
- P0: shared terrain readiness and surface query adapter; keep offline voxel estimates distinct from native physics.
- P1: prop registry, asset import/geometry validation, collision profiles, placement and incremental reconciliation. Reuse spatial_index; migrate resource_layout and vegetation_regeneration behind adapters, not a rewrite.
- P1: shared test fixtures and one command per phase; split pure tests from cloud and mobile tests. Consolidate repetitive workflow boilerplate after parity.
- P2: runtime services: central world lifecycle, resource state and collection, chunk activation; retain existing wind/time policies and server/client separation. Avoid speculative animal systems.
- P2: asset manifest and dependency graph for targeted updates. Preserve existing map template architecture.

## Gates
A: pure deterministic planner tests, invalid config and capacity failure, spacing across chunk borders.
B: actual v18 inventory and nine-tile preview, exact counts, geometry variants and native contact.
C: migration preview and inverse; no unrelated changes, no artificial clearings.
D: publish staging once, reopen, validate native contact, orientation and mobile performance.
E: migrate other props incrementally; tree collider rotation must follow visual transform.

Current limitation: planner foundation is offline only; no actual v18 plan, runtime integration, asset resize or publication yet. Quota shortfalls must block publication, not silently reduce population.

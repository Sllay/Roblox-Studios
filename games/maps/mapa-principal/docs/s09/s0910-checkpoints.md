# S09.10 — Wildlife expansion

## A — Source audit
Baseline: verified staging V31; user approved client locomotion and corpse physics. No runtime changes in this checkpoint.

- CreatureRegistry: only chicken 210080; requires real model/animation IDs; keep new species unpublished until assets validated.
- CreatureAgentFactory: PassivePrey shared brain, combat adapter separate.
- MobBrain/AgentRuntime: Peck/Flap and hunger embedded in passive policy; extract configurable routine capabilities, preserve chicken behavior and protected action semantics.
- FaunaService: single director hardwired to spawn.chicken; replace with multi-species orchestration while retaining one heartbeat and shared combat world.
- SpawnDirector: perChunk=3 hardcoded; per-species budget and group spawn required; current Abstract tier stops locomotion, migration must continue server-side with bounded updates and no teleport.
- PopulationBudget: reusable reserve/commit/release/move; group reservation rollback required.
- SpawnPolicy: chicken maximum/initial 15; change to 16 only at expansion integration; independent clocks.

## Approved scope
64 animals in nine playable chunks: chicken 16, rabbit 16 (solo/dynamic pairs, no fixed territory), cow 8 (one herd), pig 16 (solo/groups <=4, same-species territories disjoint), sheep 8 (four territorial pairs). Territorial migration every 300s test cadence, server movement, force migrate radius 500 studs, no teleport. Cross-species passive overlap allowed, prefer less overlap. Shared local separation and navigation; water capability per species. Farming/hunger requirements deferred to Very Cozy. No aggressive species or inventory changes.

## Gates
A source audit; B profile capabilities and focused tests; C separation/navigation; D groups/territory/migration; E rabbit; F cow; G pig; H sheep; I integrated staging validation. Save each checkpoint, targeted tests before advancing. Art: locate original chicken template before generating transparent full-body 3/4 and front/side/back/top/bottom concepts; no placeholder asset IDs. V31 stays intact. Template discovery and adapter audit remain open in A.

## B — Targeted validation passed
Commit 8b14772: core 43670123917, build 43670123912, historical V31 lifecycle 43670123890 all success. V31 preview is closed, not native certification of S09.10. C next. Art template discovery remains pending before asset production.

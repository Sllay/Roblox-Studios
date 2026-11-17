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

## C — Automated validation passed
7d52626: core 43676270878, build 43676270877, historical lifecycle 43676270875 success. Native terrain and visual regression pending.
## D — Automated validation passed
6c0492e: core 43676817802, build 43676817814, historical lifecycle 43676817807 success. GroupEcology and service integration implemented; real species registration, native group spawn/migration and visual validation remain pending. E next; locate approved chicken art template before asset production.

## V39 — Rabbit motion correction (source-only, not published)
Owner feedback on staging V34: body distorts; rabbit should idle and groom upright;
walk upright with hind-leg-driven hops and no front-paw support; only Run is
quadrupedal. ScratchEar is idle-only, right front paw, with the right ear bending
forward/down toward the hand. Rear-leg grooming is prohibited.

- Authored `tools/creature_factory/rabbit_animation_author_v39.py` as a
  separate unuploaded KeyframeSequence source. Preserves the same native
  19-bone rig, nine skinned parts, six whiskers, texture, and V38 verified IDs.
- Separate FK/geometry assertions in `tests/test_rabbit_animation_v39.py`.
  Runner: `.github/workflows/rabbit-v39-motion-review.yml`. It renders the
  actual skinned Blender rabbit from native keyframes to side and three-quarter
  contact sheets. Never upload directly from this review job.
- Changed only rabbit transition smoothing (.27s). No-target/blocked fleeing
  rabbits use upright Idle rather than visually Run in place; other species
  keep the previous behavior.
- All V39 source tests, XML generation, Blender evaluated real-mesh
  render and two-view contact sheets succeeded on GitHub Actions:
  https://github.com/Sllay/Roblox-Studios/actions/runs/44107771011 .
  Review artifact:
  https://github.com/Sllay/Roblox-Studios/actions/runs/44107771011/artifacts/14338568674 .
  Mobile visual acceptance, actual animation uploads and staging runtime remain
  separate gates; a successful render does not certify natural movement.
- Staging V34 remains verified and unchanged. Do not re-run the retired V34
  one-shot publisher. New V39 clip uploads and staging version 35 need new
  immutable receipts, explicit art review, isolated preflight and readback.

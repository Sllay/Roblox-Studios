# S09.9 — V31 checkpoints

Baseline: main V30 verified, 15 natural chickens, staging. No publish until all gates pass.

## A — source diagnosis (complete)
FaunaService.advance calls SpawnDirector.step on the shared heartbeat (accumulator >= 1/60). SpawnDirector independently duplicates decision intervals (.1/.5/2/10). Near motion runs each visit, Mid motion only after .19 seconds (~5 Hz), Far/Abstract stop motion and call animate("",1). SimulationBudget promotes/demotes at 45/55, 115/125, 245/255 studs. Thus at 60 studs Mid position updates are visibly discrete; beyond 125 studs motion and animation are explicitly stopped. RobloxMobAdapter.moveToward clamps dt to .2 and writes anchored mesh and query hitbox together. Tier changes cancel the adapter goal, adding discontinuity. Developer agents are capped at 128 visits per heartbeat; natural agents are all visited. Death release sets mesh.CanCollide=true without player exclusion. This is source evidence, not a measured mobile trace.

## Pending gates
B: separate decision, movement, client presentation; bound visual/authoritative error and preserve hitbox, no duplicate visual or death conflict.
C: adaptive distance/size/visibility LOD, hysteresis, visible 60/150/300 studs; no starvation.
D: unilateral corpse impulse, terrain collision retained, player collision excluded; server ownership, bounded impulses, procedural death unchanged.
E: regression and native gates for aim, kill/delete, death, respawn and player traversal.
F: measured 15/50/100/200 benchmark; preserve natural cap 15 and protected map.
G: green CI, merge, version-safe V31 release, verified receipt and native gates; reconcile ambiguous save before retry.

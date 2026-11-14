# S09 — Creature Factory / Chicken V1
Baseline: staging V25, S08.6 receipt unchanged. No Place writes.
## S09.1 — queued original geometry pilot
Request: asset-library/creature-queue/chicken-v1.json. Dedicated cloud workflow S09 Creature Factory - Chicken V1; reuses S08 candidate archiver. Separate queue prevents replay of historical prop jobs. Blender authoring backend is deterministic and specialized, not arbitrary prompt/image generation. The request records text direction, not an AI interpretation. Image/multiview inputs remain pending. All six renders are camera views of the same mesh scene. Candidate only; no automatic promotion or Roblox upload.
Provisional design: creamy rounded stylized hen, coral comb, golden beak/feet, dark eyes, separated wings/legs/head/tail. Blender Z up, -Y forward, feet at Z=0; runtime scale not chosen. Budget <=6500 triangles, UV on each mesh, GLB round-trip validation. Source .blend, GLB, views and report archived only after the checks pass. No claim of a finished rig, atlas or client performance.
## Subsequent gates
S09.2: reviewed geometry, unified UV/texture atlas, rig/skin or modular joints, meaningful pivots, no detached pieces, weight and animation roundtrip.
S09.3: idle/walk/run/peck/wing motion, loop seams and foot contact. S09.4: authorized asset upload, native isolated load, animation proof; mobile visual approval separate. S09.5: reviewed map integration plan; behavior/GDD and population not yet specified. No game save until explicitly authorized. Preserve V25 and all terrain/spawn/vegetation.

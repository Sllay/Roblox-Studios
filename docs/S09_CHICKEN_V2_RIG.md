# S09 — Chicken V2 rig and animation handoff

## Checkpoints
- Approved V2 geometry: 3120 triangles, merged to one render mesh/material, 7620 exported vertices.
- 1024x1024 atlas, zero overlapping interior pixels, zero color sample errors; 45 subpixel UV triangles. 11 original materials consolidated; approved palette retained.
- 14 bones, normalized weights, five clips at 24 FPS: Idle 2s, Walk 1s, Run 0.75s, Peck 1.25s, Flap 1.25s.
- Blender clean reimport and source triangle parity passed (43578265487). Final GLB SHA-256 ea0ebd42c7ea7a6b7ec6bf7c976edb2a1e91e205f83a017b21c9e5bc48121466. Peck beak minimum Z 0.059981; minimum animated vertex Z -1.31359e-7. Authoring units are not final studs.
- Native upload attempt (43578622948) returned HTTP 503, empty response, no operation path or asset ID. Durable receipt: asset-library/roblox-receipts/s09/chicken-v2-rig.json. State rejected_or_uncertain, retryAllowed=false. Do not automatically POST again; reconcile the original creation first. Prior Pillow dependency failures occurred before POST and were corrected.
- Roblox specifies separate exports for individual animation tracks. tools/creature_factory/chicken_variants.py derives a static base and five single-clip GLBs while checking exact geometry, skin, image and animation-accessor parity against final GLB. No new upload from the export workflow.
- Place staging V25 unchanged; no SavePlaceAsync. No client render, actual Roblox animation playback or creature population performance claimed.
- Next: reconcile the uncertain asset creation through an authorized creator inventory/asset operation. If confirmed absent, explicitly resolve receipt and upload the static base once; verify detached mesh, texture and 14 bones. Establish animation assets/playback, then design bounded creature runtime and test separately before any Place save.

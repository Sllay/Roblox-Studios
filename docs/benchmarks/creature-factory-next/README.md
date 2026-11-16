# Creature Factory Next — C0 inventory and measured baseline

C0 engineering audit complete. **C1–C6 are not implemented or accepted by this
checkpoint.** No new creature was reconstructed, optimized, imported or published.
No artistic candidate is approved by these measurements.

Reference branch: `feat/s0910-wildlife`, commit
`0e034b5c0c7523f4195b97a2c243a4a8b4ec6115`.
Development branch: `feat/creature-factory-next`.

## Evidence

* [Geometry, clay, depth and normals](c0/geometry.png).
* [Color, UV checker/wire and generic rig probes](c0/color-uv-poses.png).
* [Final observations and environment](c0/measurements.json).
* [Cold-run observations](c0/cold-measurements.json).
* [Cache, corruption rejection and selective recovery](c0/cache-recovery.json).
* [Source PNG alpha/dimensions and hashes](c0/references.json).
* [Raw artifact hashes](c0/artifact-hashes.json).
* [Immutable benchmark registry](baselines.json), 97 source files / 95,278,032 bytes verified before and after.
* [Backend and licensing ADR](../../adr/0002-creature-factory-next-cpu-evidence.md).

Both sheets show **real renders of preserved GLBs**, not concept generations.
Each model uses a bounding-box-framed orthographic camera and the same lighting;
these are not calibrated concept cameras. Depth PNGs use per-view display
normalization. Their underlying `.npy` data are float32 camera-forward distances
in imported world units; normals are geometric world-space unit vectors, not
PBR maps. Background is zero with an explicit visibility mask. All four views
pass finite-buffer, positive-depth and unit-normal checks.

## Baseline measured on this computer

Blender 4.3.2, Cycles CPU, 256 × 256, 32 samples, two render threads. Times below
are the cold worker's complete import/measurement/render duration, **not neural
inference times**. Peak is Blender's process `getrusage` RSS. Separate parent
wall time and sampled process RSS are in the JSON. Values can vary by host/load.

| Preserved candidate | Triangles | Exported vertices | UV charts | Bones | Cold seconds | Peak MiB |
|---|---:|---:|---:|---:|---:|---:|
| Rabbit V1 `43678677522-1` | 6,136 | 4,569 | 86 | 0 | 8.06 | 262.97 |
| Rabbit V2 `43679757855-1` | 26,224 | 17,068 | 324 | 0 | 16.05 | 365.80 |
| Rabbit V3 before silhouette fit `43715596147-1` | 51,732 | 39,837 | 1,964 | 0 | 22.90 | 409.44 |
| Rabbit final UV `43725694005-1` | 60,968 | 37,832 | 504 | 19 | 28.51 | 562.08 |
| Chicken rig `43578265487-1` | 3,120 | 7,620 | 331 | 14 | 6.94 | 300.76 |

Counts agree between GLB accessor metadata and the imported source scene.
UV chart counts use geometric endpoint and UV adjacency, ignoring normal and
material splits but with documented quantization tolerances. These are diagnostic
chart counts, not a painting approval gate. V3 has 1,273 charts with fewer than
four triangles; final rabbit has 207. The historical final atlas records 20
isolated-face **repair** microcharts, a different metric, and 42.920655% coverage.
Its zero-overlap result remains historical; C0 does not claim an independent
positive-area overlap test.

All five imports contain zero exactly-zero-area triangles and no invalid
imported rig weights. This does not mean all meshes are closed or valid for
production: raw seam boundaries, welded diagnostic boundaries/components,
near-degenerate faces and stretch are recorded per mesh. Diagnostic welding
can merge intentionally coincident surfaces. Final rabbit still has 334
diagnostic boundary edges; chicken has zero after welding. Do not infer
watertightness, self-intersection freedom or artistic readiness from the totals.

## Root causes and preservation

V1 authors primitive anatomy without using reference pixels as geometric
constraints. V2 fits front/right envelopes and hand-traced reliefs; concavities,
hidden anatomy and separation remain ambiguous. V3 infers from one hero and later
fits silhouettes; depth and normals were never independent evidence. Its
species-specific polish/limb/UV scripts treat symptoms individually. Exact source
locations and historical rejected reviews are in ADR 0002. The V3 path already
preserves its full master; Next must retain that policy and remove budget-driven
acceptance from future generic authoring, without rewriting historical reports.

The legacy originals are a hero plus four-view sheet, not a validated new
seven-view manifest. Both PNGs have real RGBA alpha and original hashes. Their
nonzero-alpha bounds reach image edges, so future intake must diagnose margins
with an explicit alpha threshold rather than silently changing the references.
There are no measured concept depth, normal or calibrated camera ground truths.

During C0, an independent count caught Blender's generated armature-display
icosphere contaminating metrics/BVH by 80 triangles. It is now excluded by
pose-bone custom-shape references plus hidden collection flags; source scene
triangle counts are asserted. A separate host `/proc` limitation caused an
initial RSS sampling error; direct process RSS and Blender peak memory corrected
the measurement. Earlier local attempts were preserved and excluded from this
final baseline.

## Code, execution and failure checks

Added `tools/creature_factory/next/{audit,blender_audit,compare}.py`, module entry
points, `tests/test_creature_next_audit.py`, this registry/evidence and a read-only
CPU PR/manual workflow. Legacy authoring, gameplay, AI, V31 and chicken source
files are unchanged. No credentials are used or captured. No neural weights,
paid services or external image uploads are involved.

Executed successfully:

* [163 Python regression tests](c0/python-tests.txt), including 18 new C0 tests.
* [Three unchanged legacy organic contract tests](c0/legacy-contract.txt).
* [Official syntax/bytecode checks of all 150 Luau files](c0/luau-quality.txt).
* Workspace structural validation and [all three Rojo Place builds](c0/rojo-build.txt).
* Real Blender NumPy import and GLB export/reimport preflight.
* Five full baseline imports, four color plus four clay views per candidate,
  geometric depth/normal/mask arrays, UV wire/checker and rig probes where present.
* Warm cache: five candidates reused, zero renders, 2.37 seconds including
  preflight and input/hash verification.
* Intentional corruption of one **disposable output**: comparison rejected it;
  recovery rendered only that candidate and reused the other four. Previous
  reports, failed/corrupted output and unique attempt logs remain preserved.
  Rebuilt PNG metadata differed, while decoded RGBA pixels matched exactly.

The workflow is added for future PR execution; these statements describe local
results, not an unobserved GitHub Actions run.

The first [remote C0 run](https://github.com/Sllay/Roblox-Studios/actions/runs/43782590860)
passed Python tests but stopped in Blender preflight: `ModuleNotFoundError: numpy`.
The artifact preserved the error before any candidate execution. `setup-python`
had exported its toolcache `LD_LIBRARY_PATH` while Blender and NumPy were installed
as distribution packages. The workflow now executes the audit with distribution
Python and clears only Python/libpython overrides for that process, keeping the
Blender/NumPy pair in the same environment. The initial failure artifact has SHA-256
`aa897280e7ff727b1ca0b02203ad67e551c5ea8e900fca3493a9c25936fa3a0c`.
Remote success is checked separately; no gate was disabled or converted to a skip.

## Reproduce

From the repository root, with Python 3.11+ and Blender/its own NumPy installed:

```bash
python -m tools.creature_factory.next audit --out dist/creature-next/c0 --render --resolution 256 --timeout 300
python -m tools.creature_factory.next audit --out dist/creature-next/c0 --render --resolution 256 --timeout 300 --resume
python -m tools.creature_factory.next.compare --audit dist/creature-next/c0 --out dist/creature-next/c0-review
python -m unittest tests.test_creature_next_audit -v
```

The contact-sheet command requires Pillow (local suite used 11.3.0; the measured
task interpreter and Blender package inventories are retained separately).
Use a new comparison directory. Cache validity binds source bytes, tool code,
Blender environment, resolution and all output hashes. Cache invalidation retains
prior outputs. There is no full pipeline DAG yet; this is C0 audit caching only.
Raw arrays, individual renders and logs are in the `--out` directory (about 27 MiB
for this run); curated sheets and JSON are versioned here instead of duplicating
GLB/BLEND/concept binaries. PR/manual workflow artifacts retain the full output.

## Limits and next step

Hunyuan3D-2mv is blocked here by hardware and licensing suitability; DSINE is
not adopted because of its noncommercial license. Depth Anything V2 Small is an
Apache-2.0 CPU candidate, not yet installed, benchmarked or adopted. Open3D and
meshoptimizer remain evaluated candidates. No backend has demonstrated C3 quality.

Next is C1: generic manifest contracts, persistent job DAG and cache invalidation,
profile-specific preflight, plus known-geometry wavy-sheet/concave fixtures.
Then C2 establishes correct camera/depth/normal/confidence evidence. C3–C6 must
still prove reconstruction, bounded-error optimization, anatomical UV/rig and
rabbit plus unseen-animal end-to-end results. The holdout concept is not selected;
no replacement was generated. Current pose probes are joint sensitivity checks,
not anatomical movement, interpenetration or mobile performance acceptance.

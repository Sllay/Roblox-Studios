# C2-A/B — foreground and camera evidence
Status: implementation; see PR #9 for CI certification.
## Inputs and outputs
C1 job DAG now has segmentation_ready and calibration_ready between reference_ready and evidence_ready. No depth/model reconstruction runner is registered yet. Each stage reads verified predecessor outputs, persists hashes and can be resumed. No C2-C/D/E or C3 approval implied.
- Alpha masks preserve holes, all 4-connected components, thin pixels, and report threshold sensitivity and border contact. Low threshold 16 is coverage; alpha >=128 is a separate majority-coverage mask. Alpha is not a calibrated probability or semantic part segmentation.
- Camera math uses Blender convention: world Z up, front -Y; camera -Z forward and +Y up; top-left pixel centers. Orthographic scale spans larger image dimension; perspective K follows standard positive focal lengths and pixel coordinates. Known manifest cameras preserved. Unknown views use weak canonical orthographic bbox hypotheses only if sufficient unclipped upright views exist. Normalized height 1 and camera distance are gauges, never metric. Uncalibrated 3/4 remains unknown; incompatible aspect ratios are diagnosed, not forced.
- C2 benchmark restores certified C1 artifact 14190612099 by SHA256, tests 42 views and analytic top surfaces, reuses cached stages, preserves 97 originals, and processes actual legacy rabbit panels. Raw fixture depth/normals are ground truth from C1, not predictions. All reports explicitly separate provenance.
## Run
```sh
python -m unittest tests.test_creature_next_c1 tests.test_creature_next_c2 -v
python -m tools.creature_factory.next.c2_benchmark /path/to/c1-ci dist/creature-next/c2ab
```
C2 CI uses existing fixture artifact rather than re-running Blender for each evidence change. Artifact expiry is a dependency: regenerate certified C1 fixtures and update verified pin if needed. No service uploads, paid inference or GPU.
## First failure
The initial 16-alpha mask compared to center-sampled BVH mask failed on articulated top (IoU ~.897). A thin flat side has even lower overlap because antialiased fringe pixels occupy a large fraction. This is a sampling-definition mismatch, not an excuse to discard thin features. Preserve coverage and validate separate majority-coverage mask at the original >.90 gate for every view. Report both metrics. Initial C0 import failed because Pillow was imported by new evidence module in system Python; lazy import isolates the dependency. See runs 43787912687 and 43787818083. No gate removed.
## Next
C2-C will evaluate a pinned CPU monocular relative-depth backend on actual inputs. C2-D will establish normals/landmark confidence and C2-E cross-view quantitative gates. No metric depth fusion until alignment and quality are demonstrated.

# ADR 0002 — Creature Factory Next: measured evidence before backend adoption

Status: accepted for C0 tooling; reconstruction backend selection remains experimental.

Reference: `feat/s0910-wildlife` at `0e034b5c0c7523f4195b97a2c243a4a8b4ec6115`.
Contract: `docs/CREATURE_FACTORY_NEXT_ARCHITECTURE.md`, checkpoints C0–C6.

## Problem and diagnosis

The preserved models exported successfully but the Rabbit V1/V2/V3 artistic
reviews rejected their geometry. Technical export success was insufficient.

* V1 hashes the reference bytes but authors the anatomy with lofts and spheres
  (`rabbit_v1.py:40–97`). The image does not constrain the resulting geometry.
* V2 reduces front/right silhouettes to elliptical cross sections, adds manually
  traced reliefs and globally smooths the field
  (`rabbit_organic_reference.py:58–146`). It cannot recover concavities or
  independent limbs. Color projections lack visibility tests
  (`rabbit_organic_blender.py:49–57`). Historical review records fused paws,
  bands, distorted/duplicated eyes and dark baked lighting. The old fixed
  decimation/budget are preserved historical behavior, not a Next policy.
* V3 feeds only the hero into TripoSR (`rabbit_neural_inference.py:202–222`).
  The four later silhouettes select yaw and modify cross-section envelopes
  (`rabbit_fit_multiview.py:45–84,117–134`). They do not measure depth or local
  surface orientation. Its fitted views are not held out from fitting.
  The current V3 path already preserves the full-resolution neural master;
  the existence of an unused simplifier is not evidence of an active cap.
* Rabbit polish, articulation and atlas scripts contain species-specific
  coordinates, object names, masks, symmetry assumptions and UV slots. Their
  outputs remain benchmarks; those rules will not become the generic API.
* The final atlas reports 504 charts, 20 isolated-face repair microcharts,
  42.920655% raster coverage and zero overlaps. This is the generator's
  historical report, not independent proof of paintability or distortion.
  The new imported-GLB audit measures fragmentation and Jacobian stretch.

## Real host

Linux x86_64, Blender 4.3.2. Cgroups limit memory to 8 GiB and CPU to 2 cores
(3 CPUs visible). No NVIDIA executable or device is exposed. Disk capacity is
about 7.9 GiB; free space is recorded at execution, not assumed indefinitely.
Task Python is 3.12.14; Blender uses its own Python 3.13.5 and NumPy 2.2.4.
NumPy import, actual GLB export/reimport and Cycles CPU renders work.
Neither interpreter has xatlas installed; task Python also lacks PyTorch,
torchvision, trimesh, Open3D and meshoptimizer. No new model or inference
dependency was installed for C0. Audit results contain the complete inventory.

## Decisions

1. Add an isolated `tools/creature_factory/next/` audit entry point. Preserve
   every legacy executable, reference, model, report, rig and published source.
   Do not invoke workflows that commit rabbit corrections to the reference branch.
2. Hash reference originals and five complete candidate directories in a
   versioned registry. Verify before and after the audit. Use actual GLB accessor
   counts and independent Blender imports, never copy historical counts into
   measured fields. Keep original outputs when a rerun or dependency change
   invalidates the audit cache.
3. Separate measured facts from unavailable evidence. C0 depth/normal buffers
   describe the imported mesh; illustrations do not have measured depth ground
   truth. Report UV overlaps, self-intersections, anatomical clearance and
   optimized-master errors as unmeasured rather than zero.
4. Preserve the artistic master without any triangle/vertex quality ceiling.
   The Roblox individual mesh limit is informational packaging data. Resolution,
   CPU timeouts and resource logging are execution guardrails only.
5. Keep TripoSR as the single-view historical baseline, not the final multiview
   solution. Do not reinfer a 1.68 GB checkpoint to reproduce assets already
   preserved with provenance. Its upstream MIT license covers code and weights.
6. Evaluate Depth Anything V2 **Small** in a later isolated CPU environment.
   Its source and Small weights are Apache-2.0; other sizes have different,
   noncommercial weight licenses. Relative depth needs an explicit convention,
   scale/offset, cameras and confidence before fusion. No weights downloaded yet.
7. Do not adopt Hunyuan3D-2mv here. It is a genuine multiview 1.1B model, but
   requires GPU resources absent here, and its Tencent community license has
   territory/output restrictions. Upstream advertises 6 GB VRAM for shape and
   16 GB for shape+texture; one fp16 weight file alone is about 4.93 GB.
   Do not interpret public availability as a permissive commercial/global license.
8. Validate calibrated CPU fusion first against analytic ground truth.
   Open3D MIT CPU TSDF is a candidate for perspective depth; its pinhole API is
   not an orthographic projector. Orthographic fusion must implement the correct
   projector, and inconsistent monocular depth must not be integrated raw.
9. Initially derive geometric normals from calibrated depth; do not adopt DSINE
   as a commercial dependency: its Imperial license is noncommercial. Normal
   orientation, object/camera coordinates and uncertainty must be explicit.
10. Benchmark MIT meshoptimizer's attribute-aware CPU simplification later
    against Blender Decimate. Its internal error is not a replacement for
    bidirectional surface distances, normals, held-out depth/silhouette or rig
    deformation. Simplification is not animation retopology.

## Pinned primary sources and license evidence

The following are upstream observations, not weights downloaded or executed in
C0. SHA-256 of weights is the LFS metadata's declaration until verified locally.

| Component | Full source / model revision | License and primary evidence |
|---|---|---|
| TripoSR source | `107cefdc244c39106fa830359024f6a2f1c78871` | [README](https://github.com/VAST-AI-Research/TripoSR/blob/107cefdc244c39106fa830359024f6a2f1c78871/README.md), [MIT LICENSE](https://github.com/VAST-AI-Research/TripoSR/blob/107cefdc244c39106fa830359024f6a2f1c78871/LICENSE) |
| TripoSR weights | `c1cf7716aed5aa6c1c5e174657791ef0e1327bde` | [Model card](https://huggingface.co/stabilityai/TripoSR/blob/c1cf7716aed5aa6c1c5e174657791ef0e1327bde/README.md), MIT, 1,677,246,742 bytes |
| Depth Anything V2 source | `a561b849ebae10a6f5ef49e26c83cbbcd36c71bf` | [README: CPU and per-model licenses](https://github.com/DepthAnything/Depth-Anything-V2/blob/a561b849ebae10a6f5ef49e26c83cbbcd36c71bf/README.md), Apache-2.0 code |
| Depth Small weights | `03876f8651c73a60fe4c2c48294e09fcb6838fcf` | [Model card](https://huggingface.co/depth-anything/Depth-Anything-V2-Small/blob/03876f8651c73a60fe4c2c48294e09fcb6838fcf/README.md), Apache-2.0, 24.8M parameters, 99,218,434 bytes |
| Hunyuan3D-2 source | `f8db63096c8282cb27354314d896feba5ba6ff8a` | [README](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/f8db63096c8282cb27354314d896feba5ba6ff8a/README.md), [Tencent LICENSE](https://github.com/Tencent-Hunyuan/Hunyuan3D-2/blob/f8db63096c8282cb27354314d896feba5ba6ff8a/LICENSE) |
| Hunyuan3D-2mv model | `3a761b539b29fe4ff64714813aa9560fd66f5de0` | [Model card](https://huggingface.co/tencent/Hunyuan3D-2mv/blob/3a761b539b29fe4ff64714813aa9560fd66f5de0/README.md), [weight license](https://huggingface.co/tencent/Hunyuan3D-2mv/blob/3a761b539b29fe4ff64714813aa9560fd66f5de0/LICENSE), one fp16 file 4,928,151,562 bytes |
| Open3D v0.19.0 | `1e7b17438687a0b0c1e5a7187321ac7044afe275` | [MIT](https://github.com/isl-org/Open3D/blob/1e7b17438687a0b0c1e5a7187321ac7044afe275/LICENSE), [pinhole TSDF API](https://github.com/isl-org/Open3D/blob/1e7b17438687a0b0c1e5a7187321ac7044afe275/cpp/open3d/pipelines/integration/TSDFVolume.h), [CPU tensor API](https://github.com/isl-org/Open3D/blob/1e7b17438687a0b0c1e5a7187321ac7044afe275/cpp/open3d/t/geometry/VoxelBlockGrid.h) |
| meshoptimizer | `f0a684f11ead064e176775c9b796f82a55910e92` | [MIT](https://github.com/zeux/meshoptimizer/blob/f0a684f11ead064e176775c9b796f82a55910e92/LICENSE.md), [attributes, locks and errors](https://github.com/zeux/meshoptimizer/blob/f0a684f11ead064e176775c9b796f82a55910e92/README.md) |
| DSINE | `ef0c2afa32b4dd19cb8ca4567c652802cd92591c` | [Imperial noncommercial LICENSE](https://github.com/baegwangbin/DSINE/blob/ef0c2afa32b4dd19cb8ca4567c652802cd92591c/LICENSE) |

Weight hashes for prospective verification:

* TripoSR: `429e2c6b22a0923967459de24d67f05962b235f79cde6b032aa7ed2ffcd970ee`.
* Depth Small: `715fade13be8f229f8a70cc02066f656f2423a59effd0579197bbf57860e1378`.
* Hunyuan mv fp16: `d36f5881bcdc56726b73e517cd444c13c60732431622da7268145355c8d38e9c`.

## Measurement failures investigated during C0

Blender's glTF importer creates an 80-triangle / 42-vertex armature display
icosphere in an otherwise hidden collection. It remains in `scene.objects`:
naively counting all mesh objects polluted topology and BVH depth while Cycles
correctly omitted it. The worker now identifies helpers by pose-bone
`custom_shape` references and hidden collection flags, not by object name or
species, and asserts agreement with active glTF scene instances. Diagnostic
exclusions are recorded. Earlier runs remain preserved outside the commit.

This managed host also omits `/proc/<pid>/task/<pid>/children`. Treating failure
to read that optional file as failure to read process RSS produced zero samples.
The runner now samples process RSS directly and labels its scope; Blender
independently records `getrusage` peak memory. Benchmarks were repeated after
both corrections. Neither fault was suppressed by weakening a geometry gate.

## Next checkpoints and limits

C1 adds the generic intake/job DAG, checkpoint/cache invalidation, preflight
profiles and deterministic fixtures. C2 must establish known cameras, float32
depth/normals/confidence and reprojection on the wavy sheet and concave fixture.
C3 must demonstrate reconstruction improvement, not just render old GLBs.
C4 measures error-bounded reduction; C5 UV/rig roundtrip and poses; C6 rabbit
and an unseen, separately frozen animal concept end-to-end. The holdout is not
yet selected; no synthetic stand-in will be described as an unseen animal.
There is no reconstruction/retopology/optimization acceptance in C0. Artistic
approval and Roblox publication remain separate and unauthorized by test success.

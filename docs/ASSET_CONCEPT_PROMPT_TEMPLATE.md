# Asset Factory — Universal 3D concept image prompt
Version: 2.0 | Status: one-sheet default for 3D reconstruction; legacy hero workflow remains optional.
Scope: all original 3D asset concepts (creatures, vegetation, tools, weapons, props, structures). Black Islands default: stylized low-poly, organic/intentional shapes, mobile-friendly visual complexity. This document is not a runtime mesh generator or a publication authorization.

## Parameters
Replace brackets before submitting; omit irrelevant fields rather than inventing details.
- [ASSET]: object or creature and category.
- [PROJECT]: project/style context.
- [STYLE]: target visual language (default: polished stylized low-poly, intentional planar shapes, coherent silhouette; neither crude primitives nor photorealism).
- [SHAPE]: silhouette, proportions, anatomy or functional construction, distinctive details.
- [COLORS]: palette, materials, texture finish; matte by default where appropriate.
- [POSE]: neutral reference pose, articulation state or upright orientation.
- [VIEWS]: default one composite with front, back, left, right, top, bottom and three-quarter. Single hero only when explicitly requested.
- [REFERENCE]: attached approved hero image or design reference, if any. Do not claim an attachment exists if absent.
- [SPECIAL]: constraints such as modular components, foliage cards, movable joints, scale cues internal to the design (no labels).

## Default — One multiview reference sheet (English prompt)
```text
Create ONE original 3D asset reference sheet of [ASSET] for [PROJECT], [STYLE].
Design: [SHAPE]. Materials and colors: [COLORS]. Pose: [POSE]. Constraints: [SPECIAL].
Show the exact same asset in seven distinct views: front, back, left profile, right profile, top, bottom, and three-quarter. Use an evenly spaced grid, generous transparent gaps, complete extremities, consistent scale and neutral pose. Six orthographic-like views, one three-quarter view. Same proportions, anatomy, parts, color placement and intended asymmetry. Reveal actual curvature and thickness with clean diffuse illumination, no harsh shadows or misleading painted relief. No labels, scenery, ground, borders, watermarks, or checkerboard. True transparent PNG background. Do not create a separate hero image. If an approved reference exists, preserve identity without redesign.
```

## A — Single asset hero (optional, only when requested)
```text
Create an original full-object concept image of [ASSET] for [PROJECT].
Visual style: [STYLE].
Design and silhouette: [SHAPE].
Colors and materials: [COLORS].
Pose and orientation: [POSE].
Additional constraints: [SPECIAL].
If an approved reference image is attached, preserve its identity, proportions, color placement, distinctive features and design language. Change only what is explicitly requested.

Show exactly one complete asset in a clean three-quarter view, centered with generous transparent padding. All extremities, appendages, tips, handles, roots and feet must be fully visible. Use clean studio-style illumination on the asset itself to reveal its volume and deliberate planar surfaces. Simplify through purposeful shape design and coherent transitions, not through visibly stacked spheres, cylinders or cubes. Functional hard-surface geometry may use simple forms where appropriate; the finished silhouette must still be designed.

True transparent background (PNG alpha). No floor, ground plane, cast shadow outside the asset, scenery, props unrelated to the asset, text, labels, typography, UI/UX, palette swatches, frame, logo, watermark, or additional objects. No cropping. No visible checkerboard baked into the image. Pure asset only. No gratuitous micro-detail, photorealism or noisy textures unless explicitly requested.
```

## B — Multiple perspectives (English prompt)
Optional legacy workflow when the owner supplies or requests a separate approved hero. Use that image as actual reference. Not the default.
```text
Create a clean multi-view reference of the exact same [ASSET] in the attached approved image, for [PROJECT]. Preserve its design identity, silhouette, dimensions and relative proportions, topology-like form language, materials, palette, distinctive details and articulation state. Do not redesign it between views.
Show [VIEWS] of the complete asset in a neat, evenly spaced arrangement, with every view fully visible at consistent scale and alignment. Front, side and back should be as close to orthographic as possible; use three-quarter only where requested. Maintain the same neutral pose and the same ground/contact alignment. For asymmetric assets, preserve actual left/right details rather than inventing symmetry. No duplicate or missing parts; no overlaps between views. Leave generous transparent margins around each view so individual images can be extracted.
[STYLE]. [SPECIAL].
True transparent background (PNG alpha). No text, captions, labels, UI/UX, panels, borders, palette, floor, scenery, shadows outside the silhouette, logos, watermarks, checkerboard or additional objects. Only the asset, in the requested perspectives.
```

## Production checkpoints
1. Define brief and generate the single seven-view sheet by default; use existing approved references where available.
2. Show the actual sheet for visual review and preserve original PNG. Do not generate a second image unless requested or a specific inconsistency must be corrected.
3. Validate pose, scale, view consistency, alpha, margins and feature correspondence. Record crop boxes and camera estimates; reject inconsistent panels before reconstruction. Depth/normal maps are derived technical outputs, not extra concept generations.
4. Save reviewed references, source prompt and manifest with hashes in the asset's reference directory. Keep candidate and approved status distinct. If alpha/margins or view consistency fail, correct before automated reconstruction. A transparent-looking image is not evidence of an actual alpha channel; inspect the file.
5. Translate the approved reference into geometry, UV/materials, optional rig and LOD; render the actual model from multiple cameras and show those renders in chat. Validate model topology, budgets, export/reimport and platform compatibility separately. Concept art is not a GLB, exact measured blueprint, UV texture or proof of runtime performance.

## Acceptance rules
- Full asset, transparent background, no UI/UX or annotations.
- Intentional silhouette and style; default low-poly does not mean primitive assembly or indiscriminate faceting.
- Consistent design across requested perspectives; genuine asymmetry retained.
- No unapproved changes to an existing model's identity.
- Image outputs are visual candidates until reviewed. No automatic promotion/import or Place write.

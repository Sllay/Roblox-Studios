# Creature Factory — artistic quality contract (S09.10)
- The user rejected Rabbit V1: primitive-based geometry did not match the concept.
- All future creatures use verified reference pixels, camera/landmark calibration, coherent organic geometry, and a real visual review. A successful GLB export is not artistic approval.
- Default high-detail runtime budget: up to 20,000 exported vertices (POSITION accessor counts, including UV seams and all parts). Offline sculpt master unrestricted. Lower LOD budgets are separate and must be tested on mobile; no FPS guarantee from vertex count alone.
- Compare clay and color views, front/profile/back/three-quarter, original silhouette overlays, and closeups of facial anatomy, toes, ears, and material boundaries. Silhouette scores are necessary but not sufficient. Illustrated turnarounds are not true calibrated photographs; concavities and hidden anatomy need sculpting.
- Rabbit V2: exactly six closed tapered whiskers, three per side; head binding and deformation validation required before publication.
- No promotion without explicit artistic approval for the exact candidate and immutable references. Preserve rejected candidates for comparison; do not publish them.
- Candidate texture projection is not a final hand-painted albedo. Final deformation retopology, rig, animations, texture polish, LOD and Roblox preview are separate gates.
- Chicken: future visual redesign requested; preserve the existing passive AI, states, behavior, and V31 for now. Do not replace or publish chicken in this change.
- No paid service, no external model upload, no modification to V31.

## V2 internal visual failure and learned V3 experiment
V2 passed silhouette/GLB checks (17,068 exported vertices) but failed actual artistic inspection. Do not promote it. V3 uses the MIT-licensed TripoSR learned triplane reconstruction from the verified hero. Its source and checkpoint are pinned, the checkpoint SHA-256 is checked, and all inference is on the GitHub runner CPU; only public weights are downloaded. It is not an external image-upload service. The original multi-view sheet is used for orientation and independent silhouette review. The final candidate still requires visual approval, hidden anatomy checks, texture correction, final deformation retopology and rigging. No promise that a learned model matches a specific illustration exactly.

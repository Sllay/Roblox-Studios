# Asset library
Cloud outputs are saved under candidates/<run-id>-<attempt>/ with SHA-256 manifest. Candidates are not approved for game import. Approved releases belong under approved/<asset-id>/<revision>/ after explicit visual approval and technical validation; promotion must preserve hashes and provenance. Never overwrite a candidate.
 
## UV authoring contract
New assets must export a labeled UV template, texture maps and component/material manifest. Prefer continuous front/back blade charts with connected bevels, cylindrical unwrap for handles, continuous strip for wraps, and coherent guard charts. Minimize islands without sacrificing distortion or texel density. Use nonoverlapping charts except explicitly documented intentional symmetry, sufficient padding for mipmaps, and separate tintable grayscale metal from fixed-color wood/leather. Validate UV coverage, overlap, degenerate UV triangles and distortion before promotion. Existing experimental probes do not yet satisfy this contract.
 
## External painting
Chat-generated images are external inputs, not cloud outputs. They must be ingested into the candidate revision before approval; do not substitute procedural textures for approved artwork. The cloud worker can persist all files it receives, but the external binary transfer bridge remains pending.

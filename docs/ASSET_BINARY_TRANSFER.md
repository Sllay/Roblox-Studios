# Binary asset transfer — verified S09.10
Status: tested with the original Rabbit V1 PNG bundle. No credentials copied to the sandbox.
## Transport contract
1. In the file environment, preserve source bytes. Record SHA-256, exact length and metadata for every source. If multiple files, create a ZIP with explicit relative paths and no symlinks.
2. Encode the original binary/ZIP as RFC 4648 Base64, wrapped at 1024 characters (a multiple of four). Expose the text file as a conversation artifact. This is a temporary transport representation, not a replacement for source PNG/GLB/BLEND.
3. Read the text artifact through the file-reading connector in bounded ranges (300 lines verified; at most five ranges per read). Check start/end positions, ordering and complete coverage; concatenate after removing whitespace only. Reject invalid Base64. In the connector execution context, submit the complete string to GitHub create_blob with encoding=base64. Do not print the payload into chat or retype it.
4. Read target branch HEAD and tree. Create a tree from that tree with the binary blob at the intended repository path; create commit with the observed HEAD as parent. Update branch with expected HEAD, non-force. If the ref changed, reread/reconcile rather than overwrite.
5. In GitHub Actions, unpack safe paths, compare hashes, dimensions/alpha when applicable, and commit verified originals. Validate actual binary paths and manifest by reading the repository. No production Place write or automatic artistic approval.
## Verified Rabbit V1
- ZIP blob b1f1243d565ed930b42cbd52e259d834edc7ca69; transfer commit 82c0b9a1f017ed98c8b27108e1032645f82a61e8.
- 2,130,769 bytes ZIP, 2,841,028 Base64 characters; 10 ranges covering 2,775 lines.
- Original hero.png 819185 bytes and views.png 1483380 bytes, both verified by the importer's SHA-256 and PNG-alpha checks.
- The transport is proven for this size. Larger assets require bounded chunks and an assembly manifest, or an authorized native binary transfer. Do not claim unlimited size or fully unattended operation across future sessions; file artifacts must be accessible to the reader and repository permissions must permit writes.

# Roblox Open Cloud permission handoff — S06.5

The project uses a GitHub Actions secret, ROBLOX_OPEN_CLOUD_API_KEY. Never commit or paste a credential.

## Rotation
Creator Dashboard: https://create.roblox.com/dashboard/credentials
- Preserve the existing staging Place and Luau Execution read/write scopes for universe 10769712441; do not add production.
- Add Assets Read and Write (asset:read, asset:write). The Create Asset endpoint requires both. Create the key under the authorized owner of the experience and original asset.
- Update the existing GitHub Actions secret at https://github.com/Sllay/Roblox-Studios/settings/secrets/actions . Verify the new credential before revoking the old one.
- No DataStore, Messaging, user moderation or unrelated scopes are needed for the rig.
- If using GitHub-hosted runners, do not accidentally restrict the key to a phone IP; prefer an appropriate restricted runner/expiry policy.

## Separate experience setting
In staging Creator Dashboard Configure > Settings, enable Mesh / Image APIs (Studio Experience Settings > Security > Allow Mesh / Image APIs). This does not grant ownership or editing rights to third-party meshes. Keep production unchanged. The user will explicitly request the next S06.4 attempt after rotation; no automatic asset POST retry.

## Evidence and limits
403 in 43282633795 proves the old credential did not authorize the attempted upload; missing scope is a plausible cause, not a proven diagnosis of the account. GLB Model upload is documented. Custom GPU vertex shader installation is not a public Roblox MeshPart API. EditableMesh permits script-driven vertex positions on authorized geometry, with memory/update-budget considerations; Bone.Transform is an alternative. Compare on original geometry after authorization, do not claim existing meshes are editable.

Official references:
- https://create.roblox.com/docs/cloud/guides/usage-assets
- https://create.roblox.com/docs/cloud/auth/api-keys
- https://create.roblox.com/docs/cloud/reference/scopes
- https://create.roblox.com/docs/reference/engine/classes/EditableMesh

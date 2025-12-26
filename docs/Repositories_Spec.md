# Repositories Spec (v1)

Repositories provide a structured way to ship modules/bundles/plans offline or online.

## Repository layout (folder-based)

`repositories/<repoName>/`
- `index.json` (signed optional)
- `packages/`
  - `<packageId>/<version>/<artifact files>`

## index.json (concept)
- repository metadata (name, id, updatedAt)
- list of packages with versions, hashes, and signature info

## Trust
- Repos and packages may be signed.
- Framework verifies signatures under the configured trust policy.

## Goals
- Works fully offline (USB / local share).
- Can be mirrored from web later without changing format.


## Channels
Repositories MAY expose `channels` (stable/beta/nightly). See `docs/Repo_Channels.md`.

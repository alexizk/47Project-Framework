# Release Conventions

Releases are **zip-first** and can be created without MSI/EXE installers.

## Artifact names
- `47Project_Framework_Ultimate_Pack_vX.zip`
- Optional signed bundle: `.47bundle`

## Required release artifacts
- Zip pack
- `artifacts/manifest.json` and checksums
- Signature verification instructions

## Release checklist
1. Run: `./tools/Release-47.ps1`
2. Ensure CI is green (tests, style, security scan).
3. Update `CHANGELOG.md` (or generate via `Generate-47Changelog.ps1`).
4. Tag the release (e.g., `v1.2.0`) and publish the zip + signature.

## Signing
Prefer publisher signing (trust store) for distribution.
For dev builds, allow hash pinning in policy/trust store.

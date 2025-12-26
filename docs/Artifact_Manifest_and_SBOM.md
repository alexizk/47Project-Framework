# Artifact Manifest and SBOM-lite

Date: 2025-12-26

## Artifact manifest
Ship a `artifacts/manifest.json` containing:
- pack version tag
- generated timestamp
- list of files with SHA-256 and size
- optional signatures metadata

## SBOM-lite
Track external dependencies:
- PowerShell modules used
- external tools invoked (if any)
- minimum OS/PS requirements

This is intentionally lightweight while still improving integrity and debugging.

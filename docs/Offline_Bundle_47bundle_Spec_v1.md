# Offline Bundle Format (.47bundle) Spec v1

A `.47bundle` is a zip file designed for offline distribution.

## Contents
- `bundle.json` (root manifest)
- `modules/` (module packages or module directories)
- `catalogs/` (app catalogs)
- `profiles/` (profiles)
- `docs/` (optional)
- `flags/` (feature flags, optional)
- `signatures/` (signature + hashes)

## bundle.json fields
- `schemaVersion`
- `createdAt`
- `publisher`
- `components`: list of included components with hashes
- `trust`: signature requirements

## Verification
- Framework verifies `bundle.json` signature and each component hash.
- If policy requires signatures, unsigned bundles are blocked.

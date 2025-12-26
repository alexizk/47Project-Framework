# Schemas

These JSON Schema files are the enforceable contracts for the framework artifacts.

- `module_manifest_v1.schema.json` – `modules/*/module.json`
- `plan_v1.schema.json` – `*.plan.json`
- `bundle_v1.schema.json` – `manifest.json` inside `.47bundle`
- `policy_v1.schema.json` – policy overlays (`policy.json`)
- `catalog_v1.schema.json` – app catalogs
- `profile_v1.schema.json` – install profiles
- `featureflags_v1.schema.json` – feature flags

Validation examples:

```powershell
pwsh .\tools\Validate-47Module.ps1 -Path .\modules\AppSCrawler
pwsh .\tools\Validate-47Plan.ps1   -Path .\examples\plans\sample_install.plan.json
```

- repo_index_v1.schema.json — repository index format (optional/offline)

- `trust_store_v1.schema.json` — Trust store (publisher allowlist + pinned artifact hashes)

- `snapshot_manifest_v1.schema.json` — Snapshot manifest (rollback snapshots)

- `repo_index_v1.schema.json` — Repository index (supports channels)

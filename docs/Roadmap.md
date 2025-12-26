# Roadmap

This is the practical roadmap from **v0.1** to **v1.0**.

## Milestone v0.1 — Core primitives (foundation)
Deliverables:
- Core module: paths/storage resolution (`Get-47Paths`)
- Canonical JSON + hashing (`ConvertTo-47CanonicalJson`, `Get-47Sha256Hex`)
- Policy resolution + capability gates (`Get-47EffectivePolicy`, `Test-47CapabilityAllowed`)
- Module discovery/import (`Get-47Modules`, `Import-47Module`)
- Logging contract implemented (JSONL baseline)

Exit criteria:
- `47 doctor` passes on a clean machine
- Sample modules load and self-test
- Plan validation + hash works end-to-end

## Milestone v0.2 — UX and command surface
Deliverables:
- `47` CLI shim matching `docs/CLI_Conventions.md`
- Menu + command modes
- Settings system: load/save per module
- Support bundle improvements (include policy snapshot + module list)

Exit criteria:
- `47 modules list` stable output
- Settings persisted and reflected in effective policy

## Milestone v0.3 — Trust and signing
Deliverables:
- Trust store: publisher keys
- Plan signature verification integrated into run path
- Bundle verification integrated into import/install

Exit criteria:
- Signed plan runs; unsigned plan blocked under default policy

## Milestone v0.4 — Repositories & updates (offline)
Deliverables:
- Local repository index + verify
- `47 update --from <repo>` and `--from <zip>`

Exit criteria:
- Update works offline with rollback

## Milestone v0.5 — Module API polish
Deliverables:
- Module lifecycle enforcement
- Module doctor hook
- Migrations framework

Exit criteria:
- `Invoke-47ModuleSelfTest` for all included modules

## Milestone v1.0 — Stable release
Deliverables:
- Documentation freeze
- Compatibility matrix published
- Reference modules (AppCrawler + IdentityKit) stable
- Full CI pipeline with release artifact generation

Exit criteria:
- All tests green, no schema drift, stable update path.

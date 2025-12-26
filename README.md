# 47Project Framework — Ultimate Pack (v2)

This pack is a **single-zip, offline-friendly** starter kit for the 47Project Framework ecosystem:

- A minimal **Framework / Nexus Shell** launcher (CLI)
- A **module system** (manifests + entrypoints)
- Enforceable **JSON Schemas**
- A tooling chain for **validation, canonicalization, hashing, signing, bundles**
- Examples (plans, policies, catalogs, profiles)
- Tests (Pester)

## Quick start

### 1) Validate the pack
```powershell
pwsh .\tools\Build-All.ps1
```

### 2) Run Nexus Shell (CLI)
```powershell
pwsh .\Framework\47Project.Framework.ps1
```

### 3) Build & verify an offline bundle
```powershell
pwsh .\tools\Build-47Bundle.ps1  -PlanPath .\examples\plans\sample_install.plan.json -PayloadDir .\examples\bundles\sample_payload -OutBundlePath .\examples\bundles\sample.47bundle
pwsh .\tools\Verify-47Bundle.ps1 -BundlePath .\examples\bundles\sample.47bundle
```

## Layout

- `Framework/` – framework launcher + `Core/`
- `modules/` – module manifests + module entrypoints
- `schemas/` – JSON Schemas (contracts)
- `tools/` – CLI tools (validate/sign/bundle/support)
- `examples/` – plans/policies/catalogs/profiles/payload
- `tests/` – Pester tests
- `docs/` – specs + design docs

## Notes

- The framework is **safe-by-default**: unsafe behaviors are gated via policy (`examples/policies/unsafe_all.policy.json` shows how to enable power-user mode).
- `Project47_AppCrawler_base.ps1` is the primary AppS Crawler engine. `Project47_AppCrawler.ps1` is a thin wrapper.

See `docs/Getting_Started.md` for more.


## More docs
- docs/Project_Overview.md
- docs/Roadmap.md
- docs/Compatibility.md
- docs/ID_Registry.md
- docs/CLI_Conventions.md


## Ultimate Pack v5 additions
- ADRs (`docs/adr/`) and RFCs (`docs/rfc/`)
- Plan runner and journal specifications
- Contribution & security policy docs and GitHub templates
- Artifact manifest generation + validation tools

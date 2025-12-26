# Changelog

## 1.0.4 - 2025-12-26
- Fixed CLI router and plan runner executor registration edge cases.
- Added Ultimate Pre‑Coding checklist + Start Here + additional security/design docs.
- Added new step executors: env, file.ensure, dir.ensure, zip.extract, json.merge.
- Added localization and opt‑in local telemetry scaffolding.
- Added release manifest schema + generation/signing tools (scaffolding).
- Extended policies for restricted mode and prompting behavior.


## v10
- Implemented **download** step executor with cache + SHA256 verification + quarantine staging (local-path friendly)
- Added example plan `examples/plans/sample_download.plan.json` and integration tests
- Updated plan schema and offline docs

## v8
- Added Plan Runner **implementation skeleton** (`Framework/Core/PlanRunner`) with journaling + snapshot-before-apply
- Added CLI + Nexus Shell support for `plan run` (WhatIf/Apply)
- Added integration test for plan runner wiring (`tests/PlanRunner.WhatIf.Tests.ps1`)
- Fixed stray leading `\` lines in PowerShell scripts
- Added VS Code workspace helpers (`.vscode/`) and ADR/RFC scaffolding tools (`tools/New-47ADR.ps1`, `tools/New-47RFC.ps1`)

## v6
- Added `docs/Glossary.md` and `docs/Naming_Conventions.md`.
- Updated `docs/Project_Overview.md` and offline docs index.



## v2 (2025-12-26)
- Added framework skeleton (`Framework/`) with CLI Nexus shell
- Added enforceable JSON Schemas (`schemas/*`)
- Added toolchain scripts (`tools/*`) for validation, hashing, signing, bundles, support bundles
- Added Pester tests (`tests/*`)
- Added examples for policies, catalogs, profiles, and bundle payloads
- Added docs: threat model, trust model, folder layout, diagnostics format, getting started
- Added placeholder module assets and module entrypoints
- Fixed capability catalog to include `cap.inventory.read` and other capabilities used by modules/tools
## 1.0.3 (2025-12-26)

- Plan Runner: added resume/retry support (runId + journal-based skipping)
- New step executors: copy, registry (Windows), module.call
- Repo: signed index support (Sign/Verify) and repo sync with hash verification
- Tests, schemas, and examples updated accordingly
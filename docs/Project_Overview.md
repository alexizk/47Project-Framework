# Project Overview

47Project Framework is a **PowerShell-first modular framework** with:

- **Nexus Shell**: a unified launcher (menu + CLI)
- **Modules**: independent features with manifests, capabilities, and risk profiles
- **Plans**: declarative workflows (validated + hashed + optionally signed)
- **Bundles**: offline packaging format (`.47bundle`)
- **Policy**: safe/unsafe boundaries + capability grants
- **Trust**: signature verification for plans/bundles/repos
- **Diagnostics**: support bundles for quick troubleshooting

## Documentation map

Start here:
- `docs/Getting_Started.md`
- `docs/Folder_Layout.md`

Contracts:
- `docs/Compatibility.md`
- `docs/ID_Registry.md`
- `docs/Logging_Contract.md`
- `docs/Module_Lifecycle_Contract.md`
- `docs/Policy_Boundaries.md`
- `docs/CLI_Conventions.md`

Security:
- `docs/Threat_Model.md`
- `docs/Trust_Model.md`

Packaging:
- `docs/Offline_Bundle_47bundle_Spec_v1.md`
- `docs/Repositories_Spec.md`
- `docs/Updater_Spec.md`

Ops:
- `docs/Diagnostics_SupportBundle_Format.md`
- `docs/CI_Pipeline.md`

Roadmap:
- `docs/Roadmap.md`

## Operations
- Style: `docs/Style_Guide.md`
- Releases: `docs/Release_Process.md`
- Rollback: `docs/Rollback_Snapshots.md`
- Trust: `docs/Trust_Store.md`
- Repo channels: `docs/Repo_Channels.md`
- First run: `docs/First_Run_Wizard.md`
- Config migrations: `docs/Config_Migrations.md`

Governance:
- ADRs (decisions): `docs/adr/`
- RFCs (proposals): `docs/rfc/`
- Contributing: `CONTRIBUTING.md`
- Security policy: `SECURITY.md`

Execution:
- Plan runner: `docs/Plan_Runner_Spec.md`
- Journal format: `docs/Transaction_Journal_Format.md`
- Prompting/permissions UX: `docs/Permissions_Prompting_UX.md`

Quality:
- Test strategy: `docs/Test_Strategy.md`
- Artifact manifest + SBOM-lite: `docs/Artifact_Manifest_and_SBOM.md`
- Doctor extensibility: `docs/Doctor_Extensibility.md`
- Performance & concurrency: `docs/Performance_and_Concurrency.md`
- Operator UX & exit codes: `docs/Operator_UX_and_Exit_Codes.md`

Reference:
- Glossary: `docs/Glossary.md`
- Naming conventions: `docs/Naming_Conventions.md`


## Workflow & Release

- [Commit Conventions](Commit_Conventions.md)
- [Release Conventions](Release_Conventions.md)
- [Diagrams](Diagrams_Index.md)

## Additional

- [Plan resume and retry](Plan_Resume_and_Retry.md)
- [Repository sync and signed indexes](Repo_Sync.md)

## Ultimate pre-coding
- Start here: `docs/Start_Here.md`
- Checklist: `docs/Ultimate_PreCoding_Checklist.md`
- Step taxonomy: `docs/Plan_Step_Taxonomy.md`
- Secrets/redaction: `docs/Secrets_and_Redaction.md`

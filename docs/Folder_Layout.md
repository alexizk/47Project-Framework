# Folder Layout

## Pack layout (this zip)
- `Framework/` – framework launcher + core
- `modules/` – module manifests and module code
- `schemas/` – JSON Schemas
- `tools/` – CLI tools (validate, sign, bundle, diagnostics)
- `examples/` – sample plans/policies/catalogs/profiles/bundles
- `docs/` – specs and design documents

## Runtime layout (on machine)
Paths are created by `Get-47Paths`:
- Machine data: `%ProgramData%\47Project\`
- User data: `%LocalAppData%\47Project\Framework\`
- Logs: `...\Logs\`
- Cache: `...\Cache\`
- Policy:
  - Machine: `%ProgramData%\47Project\policy.json`
  - User: `%LocalAppData%\47Project\Framework\policy.json`

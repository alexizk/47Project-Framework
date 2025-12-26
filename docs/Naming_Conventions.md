# Naming Conventions

This document standardizes names across **modules, capabilities, commands, events, files, and IDs** so the project stays coherent as it grows.

## General rules

- Prefer **clarity over brevity**.
- Names must be **stable** once published. If you must change a public name/ID, use deprecation and migration.
- Use **ASCII** for IDs and filenames unless there is a strong reason otherwise.

## IDs

### Module IDs
Format: `mod.<namespace>.<name>`  
Examples:
- `mod.47.systeminfo`
- `mod.47.nettools`
- `mod.vendor.product`

Rules:
- Lowercase, dot-separated.
- Avoid generic names (`mod.tools`, `mod.utils`)—be specific.

### Capability IDs
Format: `cap.<domain>.<verb>` (optionally add a qualifier)  
Examples:
- `cap.inventory.read`
- `cap.network.scan`
- `cap.filesystem.write.temp`
- `cap.registry.write`

Rules:
- Use verbs like `read`, `write`, `execute`, `download`, `install`, `scan`.
- Keep the meaning narrow and enforceable.

### Plan IDs
Format: `plan.<namespace>.<purpose>`  
Examples:
- `plan.47.bootstrap.dev`
- `plan.47.update.framework`

### Bundle IDs
Format: `bundle.<namespace>.<name>`  
Examples:
- `bundle.47.framework.core`
- `bundle.47.modules.tools`

### Policy IDs
Format: `policy.<namespace>.<profile>`  
Examples:
- `policy.47.default`
- `policy.47.developer`
- `policy.47.lockeddown`

## CLI and PowerShell commands

### CLI verbs
Use lowercase CLI verbs and subcommands:
- `47 help`
- `47 doctor`
- `47 modules list`
- `47 plan validate`
- `47 plan run --whatif`

### PowerShell function names
Format: `Verb-47Noun` (PowerShell approved verbs when possible)  
Examples:
- `Get-47Modules`
- `Invoke-47Doctor`
- `Test-47Policy`
- `Save-47Snapshot`
- `Restore-47Snapshot`

Rules:
- Nouns use **PascalCase**.
- Avoid abbreviations unless widely understood (`Id`, `Url`, `Json`).

### Output modes
Every CLI command should support:
- human-readable (default)
- `--json` (machine-readable)

## Logging and event IDs

### Event IDs
Format:
- Framework core: `FWK0001`, `FWK0002`, ...
- Module events: `MOD1001`, `MOD1002`, ... (or module-specific prefixes if needed)

Rules:
- One event ID = one meaning (don’t reuse).
- Events that indicate security-sensitive actions must include the relevant policy gate/capability in the record.

## Files and folders

### Docs
- Markdown docs in `docs/` use **PascalCase** filenames:
  - `Trust_Model.md`, `Plan_Runner_Spec.md`
- ADRs and RFCs use **kebab-case** with numeric prefix:
  - `docs/adr/0001-powerShell-versions.md`
  - `docs/rfc/0002-plan-step-types.md`

### Schemas
`schemas/<name>_v<major>.schema.json`  
Examples:
- `module_manifest_v1.schema.json`
- `plan_v1.schema.json`

### JSON keys
- Use **camelCase** keys.
- Use consistent suffixes:
  - `...Id`, `...Version`, `...Hash`, `...Path`, `...Url`
- Avoid polymorphic fields unless necessary; prefer explicit structures.

## Deprecation and migration naming
- Deprecated fields: keep the name, mark as deprecated in docs/schema, and provide a migration path.
- Migration scripts: `Framework/Core/Migrations/<version>/Migrate-<thing>.ps1` (or similar), with clear version bounds.

## Examples

**Good**
- `cap.filesystem.write.temp`
- `mod.47.registryPolicyViewer`
- `Invoke-47FirstRun`

**Avoid**
- `cap.doStuff`
- `mod.tools`
- `run47` (not a standard PowerShell verb form)


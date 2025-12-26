# Module Lifecycle Contract

All modules follow a consistent lifecycle so the Nexus Shell can manage them predictably.

## Required module manifest fields
See `schemas/module_manifest_v1.schema.json`.

## PowerShell entrypoint
A module entrypoint is a `.psm1` referenced by `entrypoint` in `module.json`.

## Required exported functions (v1)

Each module must export:

- `Initialize-47Module`
  - Called once after import.
  - Returns a hashtable describing module runtime state.

- `Get-47ModuleCommands`
  - Returns a list of commands the Nexus Shell can expose.

- `Get-47ModuleSettingsSchema`
  - Returns JSON Schema (or a reference to one) describing module settings.

- `Invoke-47ModuleRun`
  - Executes the module’s primary action(s), typically driven by a plan step.

- `Invoke-47ModuleSelfTest`
  - Returns a structured health report.

## Optional exported functions
- `Invoke-47ModuleDoctor` (module-specific environment checks)
- `Invoke-47ModuleMigrations` (settings/data migrations)

## Capability enforcement
Modules must call `Test-47CapabilityAllowed` before performing actions requiring permissions.

## Error handling
- Throw terminating errors for non-recoverable issues.
- Prefer structured error objects for diagnostics in support bundles.

## Versioning
- `module.apiLevel` is the compatibility key.
- Framework supports API levels per `docs/Compatibility.md`.

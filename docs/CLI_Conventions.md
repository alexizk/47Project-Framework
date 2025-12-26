# CLI Conventions

Even if the Nexus Shell is menu-based, we keep a stable CLI command surface.

## Command prefix
- `47` is the primary CLI entrypoint (script shim).

## Common commands
- `47 help`
- `47 version`
- `47 modules list`
- `47 modules import <moduleId>`
- `47 policy show`
- `47 plan validate <path>`
- `47 plan hash <path>`
- `47 doctor`
- `47 diag export`

## Output conventions
- Human-readable by default.
- `--json` for machine-readable output (planned).
- Exit codes:
  - `0` success
  - `1` generic error
  - `2` validation failure
  - `3` policy denied
  - `4` trust/signature failure

## Future flags
- `--portable`
- `--dataRoot <path>`


## Implemented commands (shim)
- `47.ps1 help`
- `47.ps1 doctor`
- `47.ps1 snapshot [name]` (creates a snapshot including the pack)
- `47.ps1 snapshots` (lists snapshots)
- `47.ps1 rollback` (restores the most recent snapshot user data)
- `47.ps1 module new <moduleId>` (scaffolds a module)
- `47.ps1 docs` (build offline docs)
- `47.ps1 style` / `47.ps1 fixstyle`
- `47.ps1 release` (build release zip into `dist/`)
- `47.ps1 update <zipPath> [targetRoot]` (safe stage + atomic swap)

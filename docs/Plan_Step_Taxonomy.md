# Plan Step Taxonomy

This taxonomy is the authoritative list of step types. Schema supports them now; some executors may be stubs.

## Implemented executors (today)
- `exec`
- `download`
- `copy`
- `registry` (Windows)
- `module.call`

## Spec + schema present (executor may be stub)
- `env`
- `service` (Windows)
- `task` (Windows)
- `file.ensure`
- `dir.ensure`
- `zip.extract`
- `json.merge` / `json.patch`
- `hosts` (Windows, policy-gated)
- `winget` (Windows, optional, policy-gated)
- `choco` (Windows, optional, policy-gated)
- `git.clone` (optional, policy-gated)
- `module.install` / `module.uninstall`

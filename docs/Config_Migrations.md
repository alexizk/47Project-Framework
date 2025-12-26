# Config Migrations

Config and policy evolve over time.

## Principles
- Store a `configVersion` in config files.
- Migrations must be **idempotent** and **logged**.
- Never silently reduce security (e.g., don't auto-enable unsafe gates).

## Implementation
- Migration scripts live under: `Framework/Core/Migrations/`
- The core migration runner applies migrations in order until current.

## Operator controls
- `47 doctor` should report pending migrations.
- `47 migrate` (optional) can run migrations explicitly.

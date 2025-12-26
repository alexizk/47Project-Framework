# ID Registry

A single place to prevent ID collisions and enforce naming conventions.

## Prefixes (reserved)

- Modules: `mod.<domain>.<name>`
- Capabilities: `cap.<domain>.<action>`
- Policies: `policy.<scope>.<name>`
- Plans: `plan.<domain>.<name>`
- Bundles: `bundle.<domain>.<name>`
- Repositories: `repo.<domain>.<name>`

## Rules

1. IDs are **lowercase** and use **dot notation**.
2. No spaces. No underscores.
3. Once published, an ID is **never reused** for a different meaning.
4. Renames require a deprecation alias for at least **one MINOR** framework release.

## Current assignments

### Modules
- `mod.framework.appcrawler`
- `mod.framework.identitykit`
- `mod.framework.hellomodule`

### Capabilities
See `schemas/Capability_Catalog_v1.json`.

## How to add a new ID

1. Add it here under the correct section.
2. Add the matching schema/catalog entry if applicable.
3. Add a test in `tests/Schema.Tests.ps1` that validates the updated file(s).

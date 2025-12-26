# Compatibility

This document defines versioning and compatibility rules for **47Project Framework**.

## Versioning

We use **SemVer** (MAJOR.MINOR.PATCH) for each independently-versioned surface:

- **Framework runtime**: `frameworkVersion` (SemVer)
- **Schemas**: `schemaVersion` (SemVer or `vN` depending on file; schema files include their own `$id`)
- **Module packages**: `module.version` (SemVer)
- **Module API Level**: `module.apiLevel` (integer, monotonic)
- **Plans**: `plan.schemaVersion` + `plan.hashSpecVersion` (SemVer)
- **Bundles**: `bundle.schemaVersion` (SemVer)

### What counts as breaking?

- Framework **MAJOR**: breaking changes in CLI, module loading, policy enforcement, trust model, storage layout, or schema compatibility.
- Schema **MAJOR**: a plan/module/policy/bundle JSON that validated before may fail after.
- Module **MAJOR**: breaking behavior or settings changes.

## Compatibility guarantees

### Framework ↔ Schemas
- Framework supports **a range** of schema versions per file type (plan/module/policy/bundle).
- The supported ranges are published in `schemas/README.md` and in `Framework/README.md`.

### Framework ↔ Modules
A module is compatible if:
- `module.apiLevel` is within the framework’s supported API range.
- `minPowerShellVersion` (if present) is satisfied.
- `supportedPlatforms` (if present) matches the host platform.

### Plans
A plan is runnable if:
- It validates against `schemas/plan_v1.schema.json` (or newer supported schema).
- Its `planHash` matches the computed value for the declared `hashSpecVersion`.
- If signed, `signature` verifies under the configured trust policy.

## Deprecation policy
- Deprecations are announced in **MINOR** releases.
- Removals happen only in **MAJOR** releases.

## Compatibility quick reference
- **Aim:** Framework supports the last **2 MAJOR** schema versions per file type.
- **Modules:** Framework supports API levels **N-1 .. N** (current and previous).

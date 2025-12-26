# ADR 0004: Module API level

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Context
Modules evolve. We need compatibility guarantees so older modules keep working.

## Decision
- Each module declares an integer `apiLevel`.
- Framework declares a supported range: `minApiLevel` and `maxApiLevel`.
- Breaking changes increment `apiLevel` and are documented in `Compatibility.md`.

## Consequences
- Loader rejects unsupported modules with a clear diagnostic.
- Generator scaffolds `apiLevel` into new modules.

## Alternatives considered
- SemVer-only: good, but API levels make compatibility checking trivial.

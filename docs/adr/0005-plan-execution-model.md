# ADR 0005: Plan execution model (transactional with journal)

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Context
Plans mutate system state; we need reliability and debuggability.

## Decision
- Plan runs create:
  - a **snapshot** (rollback point) when policy allows,
  - a **journal** recording every step result.
- Default is **transactional-ish**:
  - best-effort apply by step,
  - on failure: stop (unless `continueOnError`), keep journal, rollback optional.

## Consequences
- Plan runner must be deterministic and produce stable result objects.
- “Resume” can be implemented later using journal + idempotency checks.

## Alternatives considered
- Pure best-effort without rollback: faster but harder to recover.
- Full ACID: not realistic for Windows/PowerShell operations.

# ADR 0003: Trust model (publisher + hash pinning)

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Context
We want secure-by-default behavior without requiring enterprise PKI.
Users may run offline and still want integrity checks.

## Decision
Two trust modes:
1. **Publisher trust**: verify signatures against an allowlisted publisher key.
2. **Hash pinning**: allow running artifacts whose SHA-256 is pinned in policy/trust store.

Minimum rules:
- `.47bundle` and release zips should be verifiable (signature optional in dev, required in hardened policies).
- If verification fails, default behavior is **deny** unless policy permits “unsafe allow”.

## Consequences
- Trust store format must be stable and well-documented.
- Release tooling should optionally sign artifacts and always emit hashes.

## Alternatives considered
- No trust: simplest, but too risky.
- PKI-only: too heavy for the “ultimate but accessible” goal.

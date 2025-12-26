# Test Strategy

Date: 2025-12-26

## Layers
1. **Unit tests** (Pester): pure functions, schemas, canonical JSON, hashing
2. **Integration tests** (Pester): temp filesystem, local repo index, module loader
3. **Security tests**:
   - zip-slip/path traversal (safe extraction)
   - signature failure paths
   - policy denied paths
4. **Golden tests**:
   - canonical JSON and hashes stable across runs

## CI expectations
- Run unit tests on every push/PR
- Run integration tests on main (or nightly)
- Optional gates: coverage, analyzer warnings

## Fixture rules
- Tests must not mutate the host system (no registry/service changes outside mocks).


## Security scan

CI runs `tools/Invoke-47SecurityScan.ps1` (lightweight secret pattern scan). For deeper scanning, integrate external tools (gitleaks/trufflehog) later.

## Benchmarks

Benchmarks live under `tests/bench/` and are run manually (not in CI) using `tools/Invoke-47Bench.ps1`.

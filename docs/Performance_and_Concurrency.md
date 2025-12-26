# Performance and Concurrency Policy

Date: 2025-12-26

## Defaults
- Default concurrency: 1 (deterministic)
- Opt-in concurrency for safe operations (e.g., parallel downloads)

## Timeouts
- Global default timeout per step type
- Per-step override `timeoutSec`

## Caching
- Downloads cached by URL+hash
- Cache eviction policy: size/time based (configurable)

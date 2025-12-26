# Doctor Extensibility

Date: 2025-12-26

## Goal
Let modules contribute health checks so `47 doctor` scales with the ecosystem.

## Contract
Modules may export `Get-47DoctorChecks` returning an array of checks:
- `id`, `name`, `severity`, `run` (scriptblock), `helpUrl` (optional)

Framework runs checks and outputs:
- human-readable summary
- optional `--json` structured output

## Safety
Doctor checks should be read-only by default.

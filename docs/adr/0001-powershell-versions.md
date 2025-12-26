# ADR 0001: PowerShell version support

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Context
We want the framework to run on as many Windows machines as possible (Windows PowerShell 5.1),
while also benefiting from PowerShell 7+ features (cross-platform, better performance, modern TLS).

## Decision
- **Windows**: support **Windows PowerShell 5.1** and **PowerShell 7+**.
- Prefer **PowerShell 7+** when available for networking/crypto where practical.
- Modules may specify `minPowerShellVersion` and `supportedPlatforms` in `module.json`.

## Consequences
- Core must avoid PS7-only syntax unless guarded.
- Crypto/signing helpers should offer a PS5.1-compatible path (e.g., .NET APIs).
- CI should test at least PS7; PS5.1 testing is recommended where feasible.

## Alternatives considered
- PS7-only: simpler, but excludes many Windows hosts.
- PS5.1-only: limits features and long-term maintainability.

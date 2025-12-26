# ADR 0002: Storage layout and precedence

- Status: accepted
- Date: 2025-12-26
- Owners: Project47

## Context
We need predictable places for configuration, caches, logs, and module data,
while also supporting **portable** usage.

## Decision
Precedence order (highest wins):
1. **Policy** (machine/user policy files)
2. **User config**
3. **Portable config**
4. **Defaults** shipped with the pack

Storage roots:
- Portable root: next to `47.ps1` (if enabled)
- User root: `%AppData%\47Project\Framework`
- Machine root: `%ProgramData%\47Project\Framework`

## Consequences
- All core code must call a single path resolver (no ad-hoc paths).
- Support bundle must include all roots that exist (portable/user/machine).

## Alternatives considered
- Only portable: poor multi-user/machine support.
- Only AppData/ProgramData: less friendly for “USB zip” distribution.

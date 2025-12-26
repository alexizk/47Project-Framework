# Dependency Resolution

Modules may declare:
- `dependsOn`: list of module IDs with version constraints
- `minApiLevel`: required framework/module API level

Resolution rules:
- Prefer already-installed modules satisfying constraints
- Otherwise install from repo (policy + trust required)
- Detect cycles and fail validation

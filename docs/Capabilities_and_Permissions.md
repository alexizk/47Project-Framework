# Capabilities and Permissions

Capabilities are stable IDs that represent privileged operations.

- Capability catalog: `schemas/Capability_Catalog_v1.json`
- Step type → capability mapping: `Framework/permissions.map.json`

Policy controls capability grants:
- global grants
- per-module grants

The plan runner enforces capability gates on every step before execution.

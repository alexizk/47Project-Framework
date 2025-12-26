# Restricted Mode

Restricted mode is a policy-controlled safety layer.

## Typical blocks
- External process execution
- Network download
- Registry writes
- Installing unsigned modules/bundles

## How it works
Core enforcers check the effective policy and deny actions early with a consistent error + exit code.

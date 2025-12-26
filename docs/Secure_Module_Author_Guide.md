# Secure Module Author Guide

## Rules
- Never execute network calls unless the capability/policy allows it.
- Never write secrets to logs. Use the redaction helpers.
- Prefer idempotent operations (check desired state first).
- Use `Invoke-47External` for processes (timeouts + capture + restricted-mode checks).
- Validate inputs; treat plan JSON as untrusted.

## Required exports
- `Initialize`
- `SelfTest`
- `GetDoctorChecks` (optional)
- `GetCommands` (optional)
- `Invoke` (action dispatcher)

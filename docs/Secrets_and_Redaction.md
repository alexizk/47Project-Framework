# Secrets and Redaction

## Goals
- Plans may reference secrets **without embedding them** in plan JSON.
- Logs, journals, and support bundles must **not** leak secrets.

## Supported secret sources
- Environment references: `${env:NAME}`
- Prompt references (interactive only): `${prompt:Label}`
- Optional encrypted local secret store (future): `${secret:KeyId}`

## Redaction rules
The framework redacts:
- Any value matching common token patterns (JWT-like, long base64, API keys).
- Any key names containing: `password`, `passwd`, `secret`, `token`, `apikey`, `key`.

Redaction applies to:
- `Write-47Log`
- Plan runner journal entries
- Plan runner results JSON
- Support bundles

## Non-interactive behavior
In non-interactive mode:
- `${prompt:*}` is forbidden (policy denied) unless explicitly allowed by policy with a fallback.

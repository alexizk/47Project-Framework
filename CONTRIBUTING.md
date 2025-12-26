# Contributing to 47Project Framework

Thanks for contributing!

## Development setup
- Prefer PowerShell 7+ for development
- Run tests: `pwsh -File .\tools\Invoke-47Tests.ps1`
- Run style checks: `pwsh -File .\tools\Invoke-47StyleCheck.ps1`

## Pull requests
- Keep PRs focused
- Update docs/schemas/tests when behavior changes
- For schema/plan/trust/policy/CLI changes, add an RFC in `docs/rfc/`

## Security-sensitive changes
- Follow `docs/Threat_Model.md` and `docs/Trust_Model.md`
- Do not add telemetry by default

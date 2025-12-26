# First Run Wizard

On first launch, the framework can create default config and policy files.

## What it does
- Creates user config + policy if missing
- Sets default repo/channel
- Sets safety gates (safe by default)
- Enables logs and diagnostics defaults

## Run
- Automatic on first launch (Nexus Shell), or:
- `pwsh -File .\tools\Invoke-47FirstRun.ps1`

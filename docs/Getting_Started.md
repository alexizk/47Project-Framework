# Getting Started

## 1) Validate the pack
```powershell
pwsh .\tools\Build-All.ps1
```

## 2) Run the CLI Nexus shell
```powershell
pwsh .\Framework\47Project.Framework.ps1
```

## 3) Validate and hash a plan
```powershell
pwsh .\tools\Validate-47Plan.ps1 -Path .\examples\plans\sample_install.plan.json
pwsh .\tools\Get-47PlanHash.ps1  -PlanPath .\examples\plans\sample_install.plan.json
```

## 4) Build and verify an offline bundle
```powershell
pwsh .\tools\Build-47Bundle.ps1  -PlanPath .\examples\plans\sample_install.plan.json -PayloadDir .\examples\bundles\sample_payload -OutBundlePath .\examples\bundles\sample.47bundle
pwsh .\tools\Verify-47Bundle.ps1 -BundlePath .\examples\bundles\sample.47bundle
```


## Quick commands
- Launch Nexus Shell: `pwsh -File .\47.ps1 menu`
- Run doctor: `pwsh -File .\47.ps1 doctor`


## First run
Launching the Nexus Shell will run the **first-run wizard** if config/policy are missing.

Manual:
- `pwsh -File .\tools\Invoke-47FirstRun.ps1`

## Rollback snapshots
- Create: `pwsh -File .\tools\Save-47Snapshot.ps1 -IncludePack`
- Restore last (user): `pwsh -File .\47.ps1 rollback`

### Run the sample exec plan

```powershell
pwsh -File .\47.ps1 plan run .\examples\plans\sample_exec.plan.json WhatIf
pwsh -File .\47.ps1 plan run .\examples\plans\sample_exec.plan.json Apply
```

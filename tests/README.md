# Tests

These tests use **Pester 5+** and require **PowerShell 7+** (`pwsh`).

## Prerequisites

### PowerShell 7+
- Windows: install PowerShell 7 (recommended via winget or MSI)
- macOS: `brew install --cask powershell`
- Linux (Debian/Ubuntu): `sudo bash tools/install_dependencies.sh`

Verify:
```powershell
pwsh --version
```

### Pester 5+
Option A (recommended):
```powershell
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1
```

Option B (PSGallery):
```powershell
pwsh -NoLogo -NoProfile -Command "Install-Module Pester -Scope CurrentUser -Force"
```

> If PSGallery is blocked, `tools/install_pester.ps1` can fall back to a git-based vendor install (requires git + network).


## Offline-friendly Pester

The repo supports an **offline cache** of Pester under `tools/.vendor/Modules/`.

Cache once (online):
```powershell
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor
```

Then enforce offline-only:
```powershell
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor -OfflineOnly
```

## Run
From repository root:
```powershell
pwsh -NoLogo -NoProfile -File tools/Invoke-47Tests.ps1
```

Or:
```powershell
pwsh -NoLogo -NoProfile -Command "Invoke-Pester ./tests"
```

## CI
See `.github/workflows/ci.yml`.

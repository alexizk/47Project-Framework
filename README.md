# 47Project Framework

A Windows-first (PowerShell 7+) **Nexus shell** that unifies the Project47 toolset into one place:
- GUI hub with Apps/Modules/Plans/Snapshots/Pack Manager
- CLI shell for non-GUI environments
- Safe update workflows (stage → diff → apply) + snapshots + policy controls

> Current bundle: **v49** (2025-12-28)

## Quick start

### Windows (recommended)
1) Double-click: `Run_47Project_Framework.cmd`  
   - launches the framework  
   - installs PowerShell 7 via winget if missing (when available)

Optional shortcuts:
```powershell
.\tools\install_windows.ps1
```

### Linux / macOS
Install PowerShell 7+, then:
```bash
pwsh -NoLogo -NoProfile -File Framework/47Project.Framework.ps1
```

## Main entry points
- GUI: `47Project.Framework.GUI.v13.ps1`
- CLI: `Framework/47Project.Framework.ps1`
- Smart launcher: `47Project.Framework.Launch.ps1`

## Highlights

### Apps Hub (GUI)
- Discovers **scripts** + **modules**
- Reads metadata from comment-based help and `modules/*/module.json`
- Favorites are pinned; details panel includes Copy Path / Copy CLI

### Command Palette (Ctrl+K)
- Fuzzy search pages/apps
- Shows **Pinned** + **Recent** when empty
- Pinned pages stored in `data/pinned-commands.json`

### Safe Mode
- Global toggle that disables destructive actions
- Stored in `data/safe-mode.json`

### Pack Manager
- Stage pack zip (safe extract)
- Diff staged vs project
- Apply staged pack (**typed confirmation: UPDATE**)  
  *(apply is copy-only: no deletes)*

### Snapshots
Create/restore safety checkpoints before risky changes.

### Verify + Doctor
- Verify page exports a readiness report
- Doctor runs diagnostics and helps identify missing prerequisites

## Data & logs
- Data folder: `data/`
- Logs: `data/logs/YYYY-MM-DD.log`
- UI state: `data/ui-state.json`

## Documentation
Start here: `docs/INDEX.md`

## Release integrity
- `dist_manifest.json` contains SHA256 hashes for all files in the pack.

## License
Internal / project license as defined by the repository (add if/when you publish).

## Versioning
- `version.json` is the single source of truth for pack version/date.
- `tools/bump_version.ps1` updates version.json and regenerates dist_manifest.json.

## Integrity
Verify the pack against the manifest:
```powershell
.\tools\verify_manifest.ps1
```

## Contributing
See `CONTRIBUTING.md`.

## Releases
- Run the release pipeline:
```powershell
.\tools\release.ps1 -Version vXX -Notes "summary"
```
- Checklist: `docs/RELEASE_CHECKLIST.md`

## Maintenance
Smoke test:
```powershell
.\tools\smoke_test.ps1
```
Safe fixes:
```powershell
.\tools\fix_common_issues.ps1 -ResetDataJson -RegenerateManifest
```
Privacy: `PRIVACY.md`

## Support
In the GUI: About -> **Copy Support Info** copies environment details to clipboard.

## Offline HTML docs
```powershell
.\tools\build_docs.ps1
```
Open: `docs/site/index.html`

## Module Wizard (GUI)
Use the Module Wizard page to generate module scaffolding.

## Offline update notifier
Drop pack zip files into `pack_updates/` to show a Local Updates banner.

## Bootstrap (Linux/macOS)
```bash
./start.sh
```
Set `INSTALL_TEST_DEPS=1` to also install Pester before launch.

## Tests
```powershell
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1
pwsh -NoLogo -NoProfile -File tools/Invoke-47Tests.ps1
```

## Testing

Tests are written with **Pester 5+** and run on **PowerShell 7+**.

Run locally from repo root:
```powershell
pwsh -NoLogo -NoProfile -File tools/Invoke-47Tests.ps1
```

Offline-friendly Pester cache (recommended for contributors):
```powershell
# cache once (online)
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor

# later, enforce offline-only
pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor -OfflineOnly
```

## CI

GitHub Actions runs a cross-platform matrix on Windows, Linux, and macOS.

## Offline release zip
Build a fully offline distributable (includes vendored Pester):
```powershell
.\tools\build_offline_release.ps1
```
Output: `dist/47ProjectFramework_Offline_*`.zip

## Vendoring dependencies
```powershell
.\tools\vendor_everything.ps1
```
This populates `tools/.vendor/Modules/` for offline use.

## External modules (Python/Go/Node)
The framework can run external-module runtimes via `module.json` `run` specs.
See `docs/EXTERNAL_MODULES.md`.

## Module security
Modules can declare `risk` and `capabilities`; policy can restrict external runtimes. See docs/MODULE_SECURITY.md


### GUI tip: capture output

In Apps, hold **Shift** while clicking **Launch** to run and capture stdout/stderr.



### GUI: Apps Run & Capture

Use **Apps -> Run & Capture** to capture StdOut/StdErr in a viewer.


### GUI: badges
The Apps list displays runtime and risk badges (pills) to quickly identify external runtimes and non-safe modules.

### Apps filters
Use Apps filters to show only external runtime modules or only caution/unsafe modules.

## GUI Activity
The GUI includes an Activity page that tails `framework.log`.

### Release verification
Use GUI Settings → Release verification, or:
```powershell
pwsh -File tools/release_verify_offline.ps1 -ZipPath ./dist/47Project_Framework_<version>_offline.zip
```

### Support bundle v2
`tools/Export-47SupportBundle.ps1` now includes captures, dist integrity, module list, effective policy, and best-effort redaction.

### Runtime checklist
```powershell
pwsh -File tools/runtime_check.ps1
```

### Offline zip includes Pester (CI-built)
When built in CI, the offline zip includes a cached Pester under `tools/.vendor/` so tests can run immediately offline.

### Activity dashboard
GUI Activity page shows last test, last release build, and last verification status (state files under LogsRootUser/state).

### Activity quick actions
The GUI Activity page can run tests, build offline releases, and verify offline zips with live output.

## Release workflow
Tag `v*` triggers `.github/workflows/release.yml` to run tests, build the offline zip, and publish a GitHub Release.
Optional signing uses secret `RELEASE_SIGNING_KEY_XML`.

## Local Module Store
Build and browse a local module registry at `modules/index.json`.

## Quality tools
- Lint modules: `pwsh -File tools/lint_modules.ps1`
- Verify vendored Pester: `pwsh -File tools/verify_vendor_pester.ps1`

## Release notes
Generate release notes: `pwsh -File tools/release_notes.ps1 -Tag vX -OutPath dist/release_notes.md`

## GUI Update Center
The GUI includes an **Update Center** page for verification, linting, module index builds, and Doctor.

## Windows downloaded zip security prompt (MOTW)
If you see a security warning when running scripts, unblock the extracted folder:
```powershell
Unblock-File -Path . -Recurse
```
Or use `start.cmd` / `./start.ps1 -Bypass`.

## Maintainer release flow
Run:
```powershell
pwsh -File tools/release_checklist.ps1 -BuildOffline
```
Then create a tag with:
```powershell
pwsh -File tools/tag_release.ps1 -Tag vX -BuildOffline
```

### Note for Windows PowerShell 5.1
If you run bootstrap scripts in Windows PowerShell 5.1, the start script avoids using $IsWindows (not defined in 5.1). Using `start.cmd` is recommended.

### Installing PowerShell 7 on Windows
If pwsh is not installed, the launcher will try winget. You can also run manually:
```powershell
winget install --id Microsoft.PowerShell --source winget -e
```

### Installing PowerShell 7 on Windows
If winget doesn't work, the bootstrap will attempt an MSI install from GitHub releases, then a portable ZIP fallback.

### If winget fails with -1978335226 (0x8A150006)
That typically indicates a Microsoft Store / winget source restriction. The bootstrap will use a portable ZIP fallback under `.runtime/pwsh/`.

## Troubleshooting
- Bootstrap logs are written to `.runtime/logs/boot_*.log`.
- `start.cmd` pauses at the end so you can read any errors.

# Usage

## Bootstrap (recommended)
Linux/macOS:
```bash
./start.sh
```
Cross-platform:
```powershell
pwsh -NoLogo -NoProfile -File start.ps1
```

## Windows (fastest)
- Double-click `Run_47Project_Framework.cmd`

## PowerShell (any platform with PowerShell 7+)
GUI:
```powershell
pwsh -NoLogo -NoProfile -File 47Project.Framework.GUI.v13.ps1
```

CLI (Nexus shell):
```powershell
pwsh -NoLogo -NoProfile -File Framework/47Project.Framework.ps1
```

## Core concepts
- **Nexus shell**: the main launcher (GUI + CLI).
- **Modules**: live under `modules/<name>/` and define metadata in `module.json`.
- **Plans**: validated, policy-checked operations that can run in *simulate* or *apply* modes.
- **Snapshots**: safety checkpoints to roll back changes.
- **Pack Manager**: stage/diff/apply updates safely.

## Hotkeys
- **Ctrl+K**: Command Palette (search pages/apps; supports pinned pages and recents)

## Safe Mode
Safe Mode disables destructive actions (apply/restore/update). Toggle:
- header checkbox
- Settings page
State is persisted in `data/safe-mode.json`.

## Local updates (offline)
Drop pack zip files into `pack_updates/` to show an update banner in the GUI.

## Build offline HTML docs
```powershell
.\tools\build_docs.ps1
```
Output: `docs/site/index.html`

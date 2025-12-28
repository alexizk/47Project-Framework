# Install / Run

## Windows (recommended)
### Run without installing (portable)
Double-click:
- `Run_47Project_Framework.cmd`

### Install shortcuts
Open PowerShell (recommended) and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\tools\install_windows.ps1
```

Uninstall shortcuts:
```powershell
.\tools\uninstall_windows.ps1
```

## Linux / macOS
Requires PowerShell 7+.
Run:
```bash
pwsh -NoLogo -NoProfile -File Framework/47Project.Framework.ps1
```

## Portable build (developers)
```powershell
.\tools\build_portable.ps1
```

## Docs index
See `docs/INDEX.md`.

## Bootstrap entry points
- Linux/macOS: `./start.sh` (installs pwsh on Debian/Ubuntu via tools/install_dependencies.sh)
- Cross-platform: `pwsh -File start.ps1`

## Tests
See `tests/README.md`.

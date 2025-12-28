# Quick Start — 47Project Framework (Nexus Shell)

This framework is **Windows-first**, but the Nexus shell is designed to run on **PowerShell 7+** across Windows/Linux/macOS for features that don’t rely on Windows-only APIs (WPF/registry integrations, etc.).

---

## 1) Run the Nexus shell

### Windows
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1
```

### Linux (Ubuntu/Debian)
Install PowerShell + Docker (optional but recommended for containerized testing):
```bash
sudo bash tools/install_dependencies.sh
pwsh --version
docker --version
```

Run:
```bash
pwsh -NoLogo -NoProfile -File ./Framework/47Project.Framework.ps1
```

---



## GUI (Windows)
If WPF is available, the Nexus shell auto-launches the **47Project Framework** GUI.

Force/disable:
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Gui
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -NoGui
```

## 2) Non-interactive / CI modes

### Print menu (text)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu
```

### Print menu (JSON)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu -Json
```

### Validate a plan (JSON output)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 4 `
  -PlanPath .\examples\plans\sample_install.plan.json -Json
```

### Apply a plan (requires -Force)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 6 `
  -PlanPath .\my.plan.json -Force -Json
```

### Restore snapshot (requires -Force)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 12 `
  -SnapshotIndex 0 -Force -Json
```

---

## 3) Container testing

Build:
```bash
docker build -t 47project-framework .
```

Run:
```bash
docker run -it --rm 47project-framework
```

---

## 4) Notes

- Some features are Windows-only (WPF UI, registry-based inventory, System Restore Points).
- The framework supports offline bundles verified by `bundle.manifest.json` and safe extraction (ZipSlip + hash verification).
- Destructive actions are guarded by prompts in interactive mode and require `-Force` in non-interactive mode.


### GUI theme override
Create `data/theme.json` to override colors.

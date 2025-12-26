# 47Project Framework (Nexus Shell)

**Windows-first** framework with a **PowerShell 7+** Nexus shell, module system, plan runner, Trust Center, snapshots, support bundle tooling, and an AppCrawler bridge.

This repo is designed so you can:
- run a guided interactive shell (menu UI in PowerShell)
- run single commands non-interactively (CI / scripting) with `-Command`
- output machine-readable JSON with `-Json`

---

## What’s included (current)

### Nexus shell
- StrictMode + stable bootstrap flow (core module import + first-run wizard)
- Rationalized menu driven by a **command registry** (easy to extend)
- Hardened prompt input helpers + confirmations for destructive actions
- `-Help`, `-Menu`, `-Command`, and `-Json` modes

### Plans
- Plan validation + hashing
- Plan run modes:
  - `WhatIf` (dry run)
  - `Apply` (exec)
- Rollback helpers (best-effort):
  - optional System Restore Point creation (Windows/admin dependent)
  - undo-on-failure hooks per step (reverse order)

### Trust Center + bundles
- Authenticode checks (optional policy enforcement)
- Module fingerprint allowlisting hooks
- Offline bundle verification using `bundle.manifest.json`
- Safe extraction (ZipSlip protection + post-extract hash verification + quarantine on mismatch)

### Snapshots + support
- Inventory snapshots + diff
- Snapshot lifecycle (save/list/restore)
- Support bundle export (logs/settings/policy/inventory)

### Modules
- `modules/<module>/module.json` discovery
- module actions -> callable from plans and/or shell commands
- module settings UI generator
- module scaffold tool to create new modules quickly

### AppCrawler
- Optional bridge to launch AppCrawler and capture best-effort inventory snapshot.

---

## Requirements

### Recommended
- **PowerShell 7+** (`pwsh`) for cross-platform execution
- Windows is required for WPF UI pages and some Windows-only capabilities (registry/service/etc).

### Optional
- Docker (for containerized testing flows)
- Winget (Windows) for winget-based install actions

---

## Quick start

### Windows
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1
```

### Linux (Ubuntu/Debian)
Install prerequisites (PowerShell + Docker):
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
If WPF is available, Nexus auto-launches the **47Project Framework** GUI. You can force/disable it:
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Gui
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -NoGui
```

## CLI / Non-interactive usage

### Print menu
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu
```

### Print menu as JSON (CI-friendly)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu -Json
```

### Run a single command (non-interactive)
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 4 -PlanPath .\examples\plans\sample_install.plan.json -Json
```

> **Safety**: destructive actions invoked with `-Command` require `-Force` (e.g., Apply plan / restore snapshot).

---

## Folder layout (high level)
- `Framework/` — Nexus shell entry
- `Framework/Core/` — core module (imports tools, policies, helpers)
- `modules/` — modules (each has `module.json`)
- `policy/` — trust/policy JSON
- `schemas/` — capability catalog, schemas
- `examples/` — sample plans and bundle templates
- `tools/` — helper scripts (install deps, build docs, doctor, etc.)
- `data/` — runtime logs, snapshots, cache, quarantine (created on first run)

---

## Help
```powershell
pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Help
```

See `docs/QuickStart.md` for more details.


## Apps Hub (GUI)
The GUI includes an **Apps Hub** page that discovers other scripts in the pack and launches them as tiles.

## Theme (GUI)
You can override GUI colors by creating:
- `data/theme.json`

Example:
```json
{
  "Background": "#0F1115",
  "Panel": "#141824",
  "Foreground": "#E6EAF2",
  "Muted": "#9AA4B2",
  "Accent": "#00FF7B",
  "Warning": "#FFB020"
}
```


## Apps Hub (GUI) - Extras
- Tiles with optional icons from `assets/icons/<scriptBaseName>.png`
- Categories and search filter
- Favorites stored in `data/favorites.json`
- Optional arguments per app tile
- Run as Admin (Windows only) + Open Folder

## GUI Ultimate Additions
- Quick Actions (Doctor / Support / Pack / Tasks) in the top bar
- Status page (admin/WPF/docker/winget/readiness)
- Pack Manager (verify + stage packs safely)
- Background task runner page (non-blocking)
- Safety confirmations for Apply/Restore (typed tokens)
- Apps Hub tiles: search/category/favorites, optional args, run as admin, icons in assets/icons/
- Theme override: data/theme.json

## Apps Hub metadata
Apps Hub reads module metadata from modules/*/module.json and script metadata from comment-based help (.SYNOPSIS/.DESCRIPTION) plus optional '# Version: x.y.z'.

## Apps Hub UI
Apps Hub now has a pinned Favorites strip and a right-side Details panel (click a tile).

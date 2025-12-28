# GUI Guide

## Pages
- **Home**: status + Startup Health warnings
- **Status**: host capabilities + Safe Mode status
- **Plans**: validate/run plans (simulate/apply)
- **Modules**: discover/import/scaffold modules
- **Trust**: policy view/simulation
- **Bundles**: build support bundles for debugging
- **Pack Manager**: stage pack, diff staged vs project, apply staged pack (typed confirmation)
- **Verify**: readiness/integrity checks + export report
- **Config**: export/import user config (IMPORT token)
- **Snapshots**: create/list/restore snapshots
- **Doctor**: diagnostics
- **Apps**: Apps Hub with metadata + favorites + details panel
- **Tasks**: background task list (where supported)

## Apps Hub
Apps Hub merges:
- **Scripts** discovered in the repository
- **Modules** discovered from `modules/*/module.json`

### Tile metadata
- Display name
- Category / Kind / Version
- Description (from module.json or comment-based help)

### Actions
- Launch: scripts run in `pwsh`; modules import by moduleId
- Favorite/Unfavorite: stored in `data/favorites.json`
- Copy Path / Copy CLI: convenience actions
- Open Folder: open script/module directory

## Command Palette
- Shows **Pinned** pages, then **Recent**, then browse lists when empty.
- Use Pin/Unpin buttons (pinned pages stored at `data/pinned-commands.json`).

## Module Wizard
A guided generator that creates a new module folder + module.json + Invoke.ps1 stub.

## About
Includes Copy Support Info, Build Support Bundle, Build Docs (HTML), privacy/docs links.

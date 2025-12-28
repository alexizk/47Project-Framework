# Config & Data

The framework stores user data in a `data/` directory (created on first run).

## Key files
- `data/favorites.json` : Apps Hub favorites
- `data/recent.json` : Command Palette recents
- `data/pinned-commands.json` : Command Palette pinned pages
- `data/ui-state.json` : window position/size, last page, Apps filters
- `data/safe-mode.json` : global safe mode toggle
- `data/logs/YYYY-MM-DD.log` : GUI log files

## Export / Import
Use the GUI **Config** page:
- **Export Config**: creates a zip with your key data files
- **Import Config**: overwrites current data after typed token `IMPORT` and creates a backup zip automatically

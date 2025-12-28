# Troubleshooting

## The GUI doesn't open
- Ensure **PowerShell 7** is installed (`pwsh --version`)
- On Windows, ensure WPF is available (Windows Desktop stack)
- Run the CLI shell instead:
```powershell
pwsh -NoLogo -NoProfile -File Framework/47Project.Framework.ps1
```

## "pwsh not found"
Windows: run `Run_47Project_Framework.cmd` (it can install PowerShell via winget if available).

## Pack updates / staging issues
- Stage a zip first in Pack Manager
- Use **Diff Staged vs Project** to preview
- Use **Apply Staged Pack** (requires token `UPDATE`)
- Prefer creating snapshots before applying updates

## Safe Mode blocks actions
Disable Safe Mode via header toggle or Settings page.

## Logs
Open `data/logs/` or use GUI button **Open Latest Log**.

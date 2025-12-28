# CLI Guide

## Nexus shell
```powershell
pwsh -NoLogo -NoProfile -File Framework/47Project.Framework.ps1
```

Common flags:
- `-Help` : print help
- `-Menu` : print menu/commands (non-interactive)

## Launcher
```powershell
pwsh -NoLogo -NoProfile -File 47Project.Framework.Launch.ps1
```

Flags:
- `-NoGui` : launch the CLI shell instead
- `-Elevated` : relaunch elevated on Windows

## Notes
Some features are Windows-first (WPF GUI, shortcuts, certain system integrations). 
Most logic is designed for PowerShell 7+ cross-platform where possible.

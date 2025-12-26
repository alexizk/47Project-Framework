# Cross-platform Support

## Position
- Framework is **Windows-first**, but aims to run on **PowerShell 7+** on Windows/Linux/macOS
  where features do not require Windows-only APIs.

## PowerShell versions
- Recommended: **PowerShell 7.4+**
- Minimum target: **PowerShell 7.2** (Windows PowerShell 5.1 is optional / best-effort)

## Platform flags
Modules may declare:

- `supportedPlatforms`: `win32`, `linux`, `darwin`
- `minPowerShellVersion`: e.g. `7.2`

Framework should refuse to load modules that do not support the host platform.

## Windows-only features
- MSI inventory via registry
- AppX enumeration
- Service manager integration
- HKLM policy persistence

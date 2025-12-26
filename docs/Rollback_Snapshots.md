# Rollback Snapshots

Snapshots are local backups created before risky operations (updates, bulk changes).

## Where
- User snapshots live under: `%LOCALAPPDATA%\47Project\Framework\Snapshots`

## What’s inside
A snapshot can include:
- User data (config, caches)
- Machine policy/config (best-effort)
- (Optional) the **pack folder** itself (for update rollback)

## Commands
- Create: `pwsh -File .\tools\Save-47Snapshot.ps1 -IncludePack`
- List: `pwsh -File .\tools\Get-47Snapshots.ps1`
- Restore: `pwsh -File .\tools\Restore-47Snapshot.ps1 -SnapshotPath <path>`

> Restoring the pack is staged to a separate folder for safety; you can swap manually.

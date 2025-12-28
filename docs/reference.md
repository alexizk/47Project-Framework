# Reference (Buttons, flags, files, folders)

This is a technical reference for power users and IT.

---

## Key concepts

### Tri-state toggles
- **No change** (dash): tool does not modify
- **Off**: tool applies disable
- **On**: tool applies enable

This is the primary mechanism that prevents “bundle changes”.

### Standalone launcher
By default the script relaunches itself as a separate PowerShell process and exits the caller.

---

## CLI flags

### Recommended flags

```powershell
-Standalone   # do not relaunch/detach (use for scheduled tasks)
-DryRun       # preview actions without applying
-Portable     # force portable mode for this run
-NoUI         # headless mode (when supported by build paths)
```

> Some builds may include `-ApplyProfile <name>` or baseline options. The UI is the primary supported interface.

---

## Buttons and behaviors

### Footer
- **Reset No change**: sets tri-state toggles back to dash/indeterminate
- **Profile / Lock / Wallpaper**: quick apply only those actions
- **Apply**: apply everything currently configured (respects “No change”)
- **Exit**: closes UI

### Snapshots
- **Snapshot before apply**: creates snapshot before applying
- **Restore snapshot**: applies the selected snapshot
- **Undo last apply**: restores the most recent snapshot

### Logs
- **Open Logs**: opens log directory
- **Copy log**: copies visible log text to clipboard
- **Open snapshots**: opens backups directory

### Enterprise & Labs/IT
- **Health check**: validates data folders + write permissions + admin warning
- **Auto-fix**: creates missing folders automatically
- **Open data folder**: opens current BasePath
- **Enable/Disable portable mode**: switches where the tool stores all data (auto-restart)

---

## Data directories

### Standard mode
Base path:
- `%SystemDrive%\47Project\IdentityKit\`

Subfolders (typical):
- `Profiles\`
- `Backups\`
- `Logs\`
- `Cache\`
- `Temp\`

### Portable mode
- `.<script folder>\IdentityKitData\`

Marker file:
- `.<script folder>\.identitykit-portable`

---

---

## Compatibility notes (Windows versions & editions)

Identity Kit targets **Windows 10/11**, but some settings can behave differently depending on:

- Windows **edition** (Home/Pro/Enterprise)
- Windows **build** and feature updates
- whether the device is **managed** (Group Policy / MDM)
- whether the tool is running as **Admin**

### What’s stable across most systems
- Wallpaper
- Profile picture (most methods)

### What can vary or require extra steps
- Lock screen enforcement (often needs **Admin** + **reboot**)
- Taskbar/Explorer toggles (may move/rename across builds)

### Best-practice guidance
- Leave optional toggles at **No change** unless you specifically want them.
- Use **Dry run** when trying a section the first time.
- Keep **Snapshot before apply** enabled during testing.
- Expect that some enforced lock screen methods may only fully show after reboot.

## Logs

Where logs live:
- Standard mode: `%SystemDrive%\47Project\IdentityKit\Logs\`
- Portable mode: `IdentityKitData\Logs\`

When reporting issues, include:
- log contents (Copy log)
- Windows version/build
- whether Admin badge was Yes/No
- whether Portable mode was enabled

---

## Lock screen mechanics (high level)

Windows lock screen may be controlled by:
- WinRT user APIs
- local group policy / registry policy keys
- cached system assets under `%WINDIR%\Web\Screen`
- SYSTEM-managed caches (SystemData)

Identity Kit uses best-effort steps and logs what it did.  
Enforced/system methods often require a reboot.
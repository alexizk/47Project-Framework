# UI Tour (What each area is for)

This document walks through the UI at a practical level.

> The exact set of toggles can vary by Windows version and by build of Identity Kit.
> The UI is the source of truth; this tour explains intent and common behavior.

---

## Header

The header shows the current operational context:

- **Admin: Yes/No**
  - Some enforced actions require elevation.
- **Mode: Standard/Portable**
  - Controls where logs/snapshots/config are stored.
- Base path / log path indicators may also appear.

---

## Identity section (core)

This is the “main reason” Identity Kit exists.

### Profile picture
- Select image
- Optional crop mode (if present)
- Apply via **Quick Apply → Profile** or **Apply**

### Wallpaper
- Select image
- Choose style (if present)
- Apply via **Quick Apply → Wallpaper** or **Apply**

### Lock screen
- Select image
- Choose method/mode (if present)

Lock screen may:
- apply immediately in user mode
- require **reboot** in enforced/system paths

---

## Taskbar / Windows / Explorer sections (optional)

These sections are intentionally optional and safe-by-default.

### Tri-state toggles
- **Dash**: No change
- **Empty**: Off
- **Check**: On

This is how a user can avoid “bundled” edits.

### Reset No change
If you are unsure what you changed, click:
- **Reset No change**
Then apply again.

---

## Snapshots area

- **Snapshot before apply**: saves a snapshot of current configuration before changes
- **Restore snapshot**: apply a chosen snapshot
- **Undo last apply**: restore the newest snapshot automatically

---

## Logs area

- **Open Logs**: open the folder in Explorer
- **Copy log**: send log text to clipboard (paste into chat/issues)
- **Open snapshots**: open backups folder

---

## Enterprise & Labs/IT

Operational helpers for testing and deployment:

- **Health check**
  - ensures required folders exist
  - checks write access
  - warns if not Admin
- **Health check: auto-fix**
  - creates missing folders without prompting
- **Portable mode**
  - enable/disable and auto-restart

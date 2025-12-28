# Usage Guide (End Users)

This guide assumes you are an end user who wants to apply identity settings without breaking anything.

---

## 1) Start the tool

Recommended:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\releases\47Apps-IdentityKit-v2.4.43-PATCH-FinalPolish.ps1
```

### What you’ll see
- A WPF window (CyberGlass / Matrix theme)
- A header showing **Admin** and **Mode**
- Tabs/sections for Identity + optional UX toggles + Labs/IT tools

---

## 2) First run checklist (safe)

1. Turn on **Snapshot before apply** (recommended).
2. Turn on **Dry run** once, click Apply, read what it *would* do.
3. Turn off Dry run and apply for real.

This prevents surprises.

---

## 3) Identity (Profile / Lock / Wallpaper)

### Profile picture
- Pick an image file (PNG/JPG).
- Optional crop settings may be available.
- Click **Apply** or **Quick Apply → Profile**.

### Wallpaper
- Pick an image file.
- Choose style if available (Fill/Fit/Stretch/Tile/Center/Span).
- Click **Apply** or **Quick Apply → Wallpaper**.

### Lock screen
Lock screen is the most Windows-dependent item.

- Pick an image file.
- Choose mode if available:
  - **User / best-effort** (least invasive)
  - **Enforced/System** (policy + system asset replacement)

**Important:** enforced/system lock screen paths frequently require a **reboot** to fully update.

If you want the most reliable lock screen:
- Run as Admin
- Use enforced/system mode
- Reboot

---

## 4) Optional UX toggles (Taskbar / Windows / Explorer)

These are designed to be **individual** and **optional**.

### Tri-state behavior (very important)
Most toggles have 3 states:

- **Dash** = **NO CHANGE** (Identity Kit will not touch it)
- **Empty box** = **OFF** (Identity Kit will disable it)
- **Checkmark** = **ON** (Identity Kit will enable it)

Click cycle: **No change → Off → On**.

Tooltips show what state you’re currently in.

### Reset to “No change”
If you experimented and want to go back to safe mode:
- Click **Reset No change** (footer)
This sets tri-state toggles back to dash.

---

## 5) Applying changes

### Apply
Applies **everything currently set**, but respects **NO CHANGE** states.

Recommended settings during testing:
- Snapshot before apply: ✅
- Dry run: ✅ for first test only

### Quick Apply buttons
Use these to apply ONLY ONE thing:

- **Profile** → profile picture only
- **Lock** → lock screen only
- **Wallpaper** → wallpaper only

---

## 6) Snapshots & Undo

### Snapshot before apply
Creates a JSON snapshot of the current state before applying changes.

### Restore snapshot
- Select a snapshot from the dropdown
- Click **Restore snapshot**

### Undo last apply
Restores the newest snapshot automatically.

**When Undo may not look immediate:**
- Explorer settings might need Explorer restart/sign-out
- Enforced lock screen might need a reboot

---

## 7) Enterprise & Labs/IT

### Health check
Checks that:
- data folders exist
- the tool can write to its data folder
- warns if you are not running as Admin

If **Auto-fix** is enabled, it will create missing folders automatically.

### Portable mode
Portable mode stores all data next to the script in `IdentityKitData\`.

- **Enable portable mode** → creates a `.identitykit-portable` marker and restarts
- **Disable portable mode** → removes the marker and restarts

Use portable mode if:
- you run from a USB drive
- you don’t want to write to system drive
- you want a zip-only deployment

---

## 8) Logs

Use:
- **Open Logs** (folder)
- **Copy log** (clipboard)

When reporting issues, include:
- the first red error block (PowerShell)
- the log text
- what you clicked and in what order

---

## 9) Admin vs non-Admin

Some actions are best-effort without Admin but more reliable with Admin:
- Enforced lock screen paths
- System asset replacement
- Certain policy writes

The header badge shows: **Admin: Yes/No**.

---

## 10) When to reboot

Most identity changes apply immediately, but reboot is recommended when:
- you used enforced/system lock screen methods
- Windows caches didn’t refresh properly
- you want to confirm sign-in/lock screen assets updated

# Security & Cautions

Identity Kit is intended to be safe, reversible, and transparent — but it **does change Windows settings**.

---

## What it can modify

Depending on what you enable, Identity Kit may write:

- **User settings**
  - wallpaper settings
  - profile picture-related user settings
- **Registry**
  - user shell/UX toggles (varies by Windows build)
  - optional lock screen policy keys in enforced mode
- **Files**
  - system lock screen assets under `%WINDIR%\Web\Screen` (enforced/system paths)
  - cached images and tool cache folders

---

## Safety features (built in)

### 1) Tri-state “No change”
Most toggles default to **No change**, so applying identity changes won’t touch unrelated UX settings.

### 2) Dry run
Dry run logs what would happen without applying.

### 3) Snapshots + Undo
Snapshots capture the tool configuration before changes and allow restoration.

---

## Recommended safety practices

- Keep **Snapshot before apply** enabled while testing
- Change **one thing at a time** until you know how your OS behaves
- Use **Dry run** the first time you try a new section
- Run as Admin **only when required** (lock screen enforcement/system changes)
- Don’t run modified scripts from untrusted sources

---

## Reboot / sign-out expectations

Some Windows components cache aggressively. It is normal that:
- enforced lock screen changes require **reboot**
- some shell toggles require Explorer restart or sign-out

Identity Kit logs when a reboot is recommended.

---

## Managed devices / policy

If a PC is managed (work/school policies), some settings may be overridden after you apply them.  
This is expected and not a bug in the tool.

---

## Disclaimer

This tool is provided “as is”. Always test on a non-critical machine or create a restore point if your environment requires it.

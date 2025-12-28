# 47Apps – Identity Kit (Project 47 Framework)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue) ![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-brightgreen) ![License](https://img.shields.io/badge/License-MIT-yellow)


Branch: **`identity-kit`** in `alexizk/47Project-Framework`.

Identity Kit is a single-file **PowerShell + WPF** utility focused on:
- ✅ **Profile picture**
- ✅ **Wallpaper**
- ✅ **Lock screen** (best-effort + enforced/system paths)
- ✅ Optional UX toggles that are **safe-by-default** (tri‑state **No change**)

It’s built for Project 47 OS/Framework installs where identity should be consistent **without forcing bundled changes**.

---

## Table of contents

- [Install & first run](docs/installation.md)
- [How to use (end users)](docs/usage.md)
- [Examples / recipes](docs/examples.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Lock screen notes](docs/lockscreen.md)
- [Support / bug reports](docs/support.md)
- [All documentation](docs/index.md)


## Files in this branch

- `47Apps-IdentityKit.ps1` → **stable “latest” filename** (same content as the current versioned file)
- `47Apps-IdentityKit-v2.4.43-PATCH-FinalPolish.ps1` → versioned build
- `docs/` → full documentation (usage, security, troubleshooting, IT notes)

> Tip: Keep both files committed. Use the stable one in automations; keep the versioned one for traceability.

---

## Requirements

- Windows 10/11
- **Windows PowerShell 5.1** (`powershell.exe`) recommended

---

## Quickstart

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1
```

- For Task Scheduler / automation: add `-Standalone`
- To preview actions: add `-DryRun`

## Run

From the repo folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1
```

### Automation / Task Scheduler
Prevent the UI from relaunching/detaching:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone
```

### Optional: Dry run
Preview actions without applying:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone -DryRun
```

---

## Key safety feature: Tri‑state toggles

Many settings are tri‑state:

- **Dash** = **NO CHANGE** (Identity Kit will not touch it)
- **Empty** = OFF
- **Check** = ON

Click cycle: **No change → Off → On**

This is what lets users change things **individually**.

---

## Snapshots & Undo

- Enable **Snapshot before apply** when testing
- Use **Undo last apply** to restore the newest snapshot
- Some changes may require Explorer restart/sign-out
- Enforced lock screen changes often require a **reboot**

---

## Docs

Start here: `docs/index.md`

- `docs/usage.md` – end-user guide
- `docs/reference.md` – buttons/flags/paths
- `docs/ui-tour.md` – UI walkthrough
- `docs/lockscreen.md` – lock screen deep notes (caching/policy/reboot)
- `docs/deployment.md` – builders/IT notes
- `docs/security.md` – cautions & safe practices
- `docs/troubleshooting.md`
- `docs/faq.md`
- `docs/changelog.md`

---

## License

MIT (see `LICENSE`).

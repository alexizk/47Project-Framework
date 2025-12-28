# Installation & First Run

This page is for people who have never run Project 47 tools before.

---

## Option A: Download as ZIP from GitHub

1. Open the `identity-kit` branch.
2. Click **Code → Download ZIP**.
3. Extract the ZIP somewhere simple, e.g.:
   - `C:\Tools\IdentityKit\`

You should see:
- `47Apps-IdentityKit.ps1`
- `docs\...`

---

## Option B: Clone with Git

```bash
git clone https://github.com/alexizk/47Project-Framework.git
cd 47Project-Framework
git checkout identity-kit
```

---

## Windows “downloaded from the internet” (Unblock)

If Windows blocks the script because it came from the internet:

### Unblock the script file
Right click `47Apps-IdentityKit.ps1` → **Properties** → check **Unblock** → Apply.

Or do it in PowerShell:

```powershell
Unblock-File .\47Apps-IdentityKit.ps1
```

---

## Run

Recommended:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1
```

### Task Scheduler / automation
Prevent the relaunch/detach behavior:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone
```

---

## Where does it store data?

### Standard mode
`%SystemDrive%\47Project\IdentityKit\`

### Portable mode
`.\IdentityKitData\` (next to the script)

Use **Open data folder** in the UI to jump there.

# Deployment notes (Builders / IT)

This document is for people integrating Identity Kit into installers, images, or post-install scripts.

---

## Recommended approach

- Keep Identity Kit as a **single script** in your assets.
- Launch it for the user post-install.
- Let users change settings individually using tri-state toggles.

---

## Running silently / automation

Use `-Standalone` to prevent the detaching relaunch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone
```

Use `-DryRun` to validate on a new machine image without applying:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone -DryRun
```

---

## Portable mode in deployments

Portable is useful when:
- you deploy the script via zip
- you don’t want to write to `%SystemDrive%`

You can pre-enable portable mode by placing a marker file next to the script:

- `.identitykit-portable`

Then run normally.

---

## Log capture

Logs are stored under the active data folder:
- Standard: `%SystemDrive%\47Project\IdentityKit\Logs\`
- Portable: `IdentityKitData\Logs\`

If you collect logs centrally, copy the latest log file after running.

---

## Change control

Identity Kit is designed to avoid bundled changes. If you use it in an image:
- keep tri-state toggles at **No change**
- apply only identity elements you intend

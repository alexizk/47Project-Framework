# Policies, Management & “Why Windows ignores me”

Identity Kit works in “best effort” mode. Windows may still override changes.

---

## Managed devices

On work/school managed PCs, settings can be controlled by:
- Group Policy
- MDM (Intune, etc.)
- provisioning packages
- OEM policies

If management enforces a lock screen, your changes can revert after:
- reboot
- sign-in
- policy refresh

This is expected behavior.

---

## What “Enforced” means in Identity Kit

When you pick enforced/system methods, Identity Kit may:
- write policy keys (admin only)
- replace system lock screen assets
- trigger cache refresh steps

Even then, Windows can still override depending on edition/build/management.

---

## Lock screen is special

Unlike wallpaper/profile picture, lock screen can be governed by:
- WinRT APIs
- policies
- cached SystemData assets

Result:
- A reboot can be required for enforced/system paths.
- On managed devices, lock screen can be forced back.

See: `docs/lockscreen.md` for deep details.

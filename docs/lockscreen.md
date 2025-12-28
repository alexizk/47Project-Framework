# Lock screen details

Windows lock screen is less predictable than wallpaper/profile picture because it can be controlled by:
- WinRT user APIs
- local group policy / registry policy
- cached system assets
- SYSTEM-managed caches (SystemData)

Identity Kit uses best-effort techniques, and logs what it did.

---

## Practical guidance

### If you just want it to work
1. Run as **Admin**
2. Use an **enforced/system** method (if available in the UI)
3. **Reboot**

### If you want least invasive changes
Use the user/best-effort method first. This may not survive on managed devices.

---

## Why reboot is sometimes required

Windows may cache lock screen assets and policy evaluations. Even after:
- replacing `%WINDIR%\Web\Screen` images
- setting policy keys

…the visible lock screen can remain unchanged until reboot or until caches refresh.

Identity Kit includes a SystemData refresh helper for reliability.

---

## Managed devices

If the PC is managed, the lock screen may be enforced by the organization and your changes can be overwritten on next policy refresh.

This is expected.

---

## Troubleshooting checklist

- Confirm the log shows the lock screen image path you selected
- Confirm the log indicates which method ran (user vs enforced/system)
- Reboot after enforced/system operations
- Try running as Admin

If still failing:
- include the log and Windows build number in your report

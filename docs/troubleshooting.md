# Troubleshooting

If something doesn’t work, start here.

---

## 1) Gather information quickly

Use:
- **Copy log** (preferred)
- or **Open Logs** and open the latest log file

Also note:
- `Admin: Yes/No`
- `Mode: Portable/Standard`
- whether you used **Dry run**
- which button you clicked (Apply vs Quick Apply)

---

## 2) UI opens but “nothing changes”

Common causes:
- you didn’t pick an image file
- everything is left at **No change** (tri-state dash)
- you ran **Dry run** (it only logs actions)

Fix:
- pick an image
- turn off Dry run
- apply again

---

## 3) Lock screen did not change

Lock screen behavior differs per Windows edition/build.

Try in order:
1. If you used enforced/system method: **reboot**
2. Sign out and sign in
3. Run Identity Kit as **Admin**
4. If on a managed PC, confirm policy isn’t overriding

If it still doesn’t change:
- copy the log and look for lock screen steps
- include the log in your report

---

## 4) “Admin: No” and enforced options

Some enforced/system operations require admin rights.  
If you need those actions:
- run PowerShell as Administrator
- launch the script again

---

## 5) “I clicked and it changed multiple things!”

This typically happens if toggles were left set to Off/On from testing.

Fix:
- click **Reset No change**
- apply again (only chosen identity items will change)

---

## 6) Script won’t start / Parser error

Ensure:
- you’re using **Windows PowerShell 5.1** (`powershell.exe`)

Try:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\47Apps-IdentityKit.ps1 -Standalone
```

If you still get a red error:
- copy the first error block + line number

---

## 7) Where are my files?

Standard mode:
- `%SystemDrive%\47Project\IdentityKit\`

Portable mode:
- `.<script folder>\IdentityKitData\`

Use **Open data folder** to jump there.

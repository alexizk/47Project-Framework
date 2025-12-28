# Examples / Recipes

These are practical “copy this workflow” examples.

> Tip: Keep **Snapshot before apply** enabled while testing.

---

## 1) Set ONLY a profile picture

1. Go to **Identity**
2. Pick a profile image
3. Leave everything else at **No change**
4. Click **Quick Apply → Profile**

If you need to roll back:
- click **Undo last apply**

---

## 2) Set ONLY wallpaper

1. Pick a wallpaper image
2. Choose style (if shown)
3. Click **Quick Apply → Wallpaper**

---

## 3) Set ONLY lock screen (most reliable)

1. Run Identity Kit as **Admin**
2. Pick a lock screen image
3. Choose enforced/system method (if available)
4. Click **Quick Apply → Lock**
5. **Reboot**

---

## 4) Safe testing workflow (recommended)

1. Enable **Dry run**
2. Click **Apply** and read the log
3. Disable Dry run
4. Enable **Snapshot before apply**
5. Click **Apply**
6. If anything feels off: **Undo last apply**

---

## 5) Portable mode on a USB drive

1. Copy the repo folder to a USB drive
2. Run `47Apps-IdentityKit.ps1`
3. In **Enterprise & Labs/IT**, click **Enable portable mode**
4. Re-open (auto restart happens)
5. Now logs/snapshots live under `IdentityKitData\` next to the script

---

## 6) “I changed too many toggles” reset

If you tested a lot and want to go back to safe defaults:

1. Click **Reset No change**
2. Apply again (only identity items you selected will change)

---

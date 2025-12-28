# FAQ

### Why does the tool detach from the terminal?
So it can be launched from other scripts or installers without holding the parent console open. The UI runs in its own PowerShell process.

### Why does lock screen sometimes only update after reboot?
Windows caches lock screen assets and policies. Enforced/system methods often require reboot to fully refresh.

### What is “No change”?
It means the tool will not touch that setting. It prevents accidental bundle changes.

### Can I apply only one thing?
Yes — use the Quick Apply buttons: **Profile**, **Lock**, **Wallpaper**.

### What is portable mode?
It stores logs/snapshots/cache next to the script inside `IdentityKitData\` and uses a marker file `.identitykit-portable` to remember the choice.

### Is this safe on a managed PC?
It’s safe in the sense that it won’t bypass management. Policies may override the tool’s changes afterward.

### How do I quickly return to “safe mode”?
- Click **Reset No change** (sets tri-state toggles back to dash)
- Use **Undo last apply** if you want to roll back the last applied snapshot

### Where should I start if something looks wrong?
- Click **Copy log** and review the last actions
- Check badges: `Admin` and `Mode`
- See `docs/troubleshooting.md`

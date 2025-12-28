# Architecture (high level)

Identity Kit is intentionally a **single-file** PowerShell script with an embedded **WPF XAML** UI.

---

## Why single-file?
- easy distribution (copy one file)
- easier auditing (one artifact)
- fewer dependency failures

---

## Main components

1. **UI layer (WPF/XAML)**
   - renders pages and controls
   - uses themed styles (CyberGlass / Matrix)

2. **State**
   - tracks selected images and toggle states
   - builds an apply-config object from UI

3. **Apply engine**
   - applies profile picture / wallpaper / lock screen
   - applies optional UX toggles when not “No change”

4. **Safety**
   - **DryRun**: logs actions without applying
   - **Snapshots**: store config before changes; restore/undo

5. **Storage**
   - Standard mode: `%SystemDrive%\47Project\IdentityKit`
   - Portable mode: `.\IdentityKitData`

6. **Logging**
   - log file under `Logs\`
   - UI log panel + Copy log

---

## Design rules
- Default to “No change”
- Log everything meaningful
- Never silently apply bundles
- Prefer best-effort with clear messaging over brittle hacks

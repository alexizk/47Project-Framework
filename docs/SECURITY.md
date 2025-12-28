# Security Notes

This project intentionally offers powerful automation (running scripts, applying staged updates, restoring snapshots).
Use these safeguards:

- **Safe Mode**: disables destructive actions for demos and shared environments.
- **Typed confirmations**: high-impact actions require a token (e.g., `UPDATE`, `IMPORT`).
- **Staging**: packs are extracted to a staging area before any apply.
- **No-delete apply**: applying a staged pack copies files into the project without deleting existing files.
- **Snapshots**: create snapshots before applying changes.

If you distribute builds:
- consider Authenticode signing (`tools/sign_release.ps1`)
- ship the `dist_manifest.json` for integrity verification

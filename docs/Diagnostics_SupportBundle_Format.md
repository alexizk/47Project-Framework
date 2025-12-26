# Diagnostics Support Bundle Format

Created by: `tools/Export-47SupportBundle.ps1`

Contents (typical):
- `env.json` – OS + PowerShell version + basic identifiers
- `logs-*/*` – user and machine log folders (if present)
- `policy.json` – copied if present (machine/user)
- `modules/*.module.json` – module manifests in effect

Notes:
- The exporter avoids collecting secrets by design, but always review the bundle before sharing.

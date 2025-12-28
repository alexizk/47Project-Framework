# Vendored Pester

This folder is used by `tools/install_pester.ps1` as the offline cache location.

To vendor Pester (online environment):
```powershell
pwsh -File tools/install_pester.ps1 -PreferVendor:$false
```
This will cache Pester under `tools/.vendor/Modules/Pester/<Version>/`.

Then commit `tools/.vendor/` so offline runs work.

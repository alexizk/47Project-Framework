# tools/.vendor

This folder stores **vendored/offline caches** of third‑party dependencies.

## Pester offline cache

`tools/install_pester.ps1` will cache Pester under:

`tools/.vendor/Modules/Pester/<Version>/`

Workflow:
1) Run once online:
   - `pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor`
2) Then you can run offline:
   - `pwsh -NoLogo -NoProfile -File tools/install_pester.ps1 -PreferVendor -OfflineOnly`

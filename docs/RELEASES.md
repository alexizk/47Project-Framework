# Offline releases

The framework supports building a reproducible offline zip that includes vendored dependencies and integrity metadata.

## Build

```powershell
pwsh -NoLogo -NoProfile -File tools/release_build.ps1
```

Outputs:
- `dist/47Project_Framework_<version>_offline.zip`
- `dist/manifest.json`
- `dist/SHA256SUMS.txt`

## Vendoring Pester (optional)

If you want the offline zip to include Pester:
```powershell
pwsh -File tools/vendor_pester.ps1
pwsh -File tools/release_build.ps1
```

## Signing (optional)

Generate a keypair:
```powershell
pwsh -File tools/release_keygen.ps1 -OutDir ./keys
```

Build + sign:
```powershell
pwsh -File tools/release_build.ps1 -SignKeyPath ./keys/release_private.xml
```

Verify:
```powershell
pwsh -File tools/release_verify.ps1 -PublicKeyPath ./keys/release_public.xml -InputPath ./dist/manifest.json
pwsh -File tools/release_verify.ps1 -PublicKeyPath ./keys/release_public.xml -InputPath ./dist/SHA256SUMS.txt
```

## Verify an offline zip
```powershell
pwsh -File tools/release_verify_offline.ps1 -ZipPath ./dist/47Project_Framework_<version>_offline.zip
```

The offline zip embeds integrity data under `_integrity/`.

## Vendoring dependencies in CI
CI runs `tools/install_pester.ps1`, which caches Pester under `tools/.vendor/Modules/Pester/` and the offline zip includes it.

## GitHub Releases
Tag `v*` to trigger `.github/workflows/release.yml`. It builds the offline zip and attaches it to a GitHub Release.

### Optional signing
Add repository secret `RELEASE_SIGNING_KEY_XML` containing the private RSA key XML.

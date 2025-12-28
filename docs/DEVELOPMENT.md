# Development

## Structure
- `Framework/` : Nexus shell + core module
- `modules/` : optional modules (each with `module.json`)
- `tools/` : install/build helpers
- `assets/` : branding/icons
- `docs/` : documentation

## Portable builds
```powershell
.\tools\build_portable.ps1
```

## Signing (optional)
You need a code-signing certificate:
```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
.\tools\sign_release.ps1 -CertThumbprint $cert.Thumbprint
```

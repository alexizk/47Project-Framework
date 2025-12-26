# Repository sync and signed indexes

A repository is represented by an `index.json` file (optionally signed) plus package files referenced by relative paths in the index.

## Sync (offline or HTTP)

```powershell
pwsh -File .\47.ps1 repo sync .\repositories\local\channels\stable\index.json
```

From a URL:

```powershell
pwsh -File .\47.ps1 repo sync https://example.com/repo/stable/index.json
```

## Signature verification

If `index.json` contains a `signature` block, you must provide a certificate:

```powershell
pwsh -File .\tools\Verify-47RepoIndex.ps1 -IndexPath .\index.json -CertPath .\publisher.cer
```

Or during sync:

```powershell
pwsh -File .\47.ps1 repo sync https://example.com/repo/stable/index.json .\repositories\local .\publisher.cer
```

Unsigned indexes are rejected unless you pass `allowUnsigned`.

## Signing

```powershell
pwsh -File .\tools\Sign-47RepoIndex.ps1 -IndexPath .\index.json -PfxPath .\publisher.pfx
```

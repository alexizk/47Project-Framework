\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$PfxPath,
  [Parameter(Mandatory)][string]$PfxPassword,
  [Parameter()][string]$KeyId = 'default'
)

# NOTE: This is a minimal placeholder. It signs the manifest sha256 using the certificate private key.
# Improve later: detach signature, support key rotation, store kid/thumbprint, and verify via trust store.

$cert = Get-PfxCertificate -FilePath $PfxPath
if (-not $cert.HasPrivateKey) { throw "Certificate has no private key: $PfxPath" }

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json -AsHashtable
$data = [Text.Encoding]::UTF8.GetBytes([string]$manifest.sha256)

$sha = [System.Security.Cryptography.SHA256]::Create()
$hash = $sha.ComputeHash($data)

$rsa = $cert.GetRSAPrivateKey()
$sig = $rsa.SignHash($hash, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)

$manifest.signature = [ordered]@{ alg='RS256'; kid=$KeyId; value=[Convert]::ToBase64String($sig) }
($manifest | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $ManifestPath -Encoding UTF8

Write-Host "Signed manifest: $ManifestPath"

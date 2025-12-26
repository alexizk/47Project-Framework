<#
.SYNOPSIS
  Verify the signature embedded in a repo index file (RS256).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$IndexPath,
  [Parameter(Mandatory)][string]$CertPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$idx = Read-47Json -Path $IndexPath
if (-not $idx.signature) { throw "No signature block in index: $IndexPath" }
if ($idx.signature.alg -ne 'RS256') { throw "Unsupported alg: $($idx.signature.alg)" }

$sigB64 = $idx.signature.sig
if (-not $sigB64) { throw "Signature missing 'sig' value" }

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
$rsa = $cert.GetRSAPublicKey()
if (-not $rsa) { throw "No RSA public key in cert: $CertPath" }

$idxNoSig = ConvertTo-47CanonicalObject -InputObject $idx
$idxNoSig.PSObject.Properties.Remove('signature') | Out-Null
$bytes = Get-47CanonicalBytes -InputObject $idxNoSig
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)

$sigBytes = [Convert]::FromBase64String($sigB64)
$ok = $rsa.VerifyHash($hashBytes, $sigBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)

if (-not $ok) { throw "Signature verification FAILED for: $IndexPath" }
Write-Host "Signature verification OK: $IndexPath"

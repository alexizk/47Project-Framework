<#
.SYNOPSIS
  Verify the signature embedded in a plan file (RS256).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PlanPath,
  [Parameter(Mandatory)][string]$CertPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$planFull = Read-47Json -Path $PlanPath
if (-not $planFull.signature) { throw "No signature block in plan: $PlanPath" }
if ($planFull.signature.alg -ne 'RS256') { throw "Unsupported alg: $($planFull.signature.alg)" }

$sigB64 = $planFull.signature.sig
if (-not $sigB64) { throw "Signature missing 'sig' value" }

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
$rsa = $cert.GetRSAPublicKey()
if (-not $rsa) { throw "No RSA public key in cert: $CertPath" }

# Build canonical bytes excluding planHash + signature
$plan = $planFull
if ($plan.PSObject.Properties.Name -contains 'planHash') { $plan.planHash = $null }
$plan.signature = $null

$bytes = Get-47CanonicalBytes -InputObject $plan
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)

$sigBytes = [Convert]::FromBase64String($sigB64)
$ok = $rsa.VerifyHash($hash, $sigBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)

if ($ok) { Write-Host "OK: Signature valid" } else { throw "INVALID: Signature does not verify" }

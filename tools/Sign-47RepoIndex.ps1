<#
.SYNOPSIS
  Sign a repository index file (RS256) and embed a signature block into the JSON.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$IndexPath,
  [Parameter(Mandatory)][string]$PfxPath,
  [Parameter()][string]$PfxPassword,
  [string]$KeyId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

if (-not (Test-Path -LiteralPath $IndexPath)) { throw "Index not found: $IndexPath" }
if (-not (Test-Path -LiteralPath $PfxPath)) { throw "PFX not found: $PfxPath" }

$idx = Read-47Json -Path $IndexPath

# Canonical bytes excluding signature
$idxNoSig = ConvertTo-47CanonicalObject -InputObject $idx
$idxNoSig.PSObject.Properties.Remove('signature') | Out-Null

$bytes = Get-47CanonicalBytes -InputObject $idxNoSig
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)

$pw = if ($PfxPassword) { (ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force) } else { $null }
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxPath, $pw, 'Exportable,PersistKeySet')
$rsa = $cert.GetRSAPrivateKey()
if (-not $rsa) { throw "No RSA private key in PFX: $PfxPath" }

$sigBytes = $rsa.SignHash($hashBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$sigB64 = [Convert]::ToBase64String($sigBytes)

$kid = if ($KeyId) { $KeyId } else { $cert.Thumbprint }

$idx.signature = [ordered]@{
  alg = 'RS256'
  kid = $kid
  sig = $sigB64
  signedAt = [DateTime]::UtcNow.ToString("o")
}

if ($PSCmdlet.ShouldProcess($IndexPath, "Write signature block")) {
  ($idx | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath $IndexPath -Encoding UTF8
}

Write-Host "Signed index: $IndexPath"
Write-Host "kid: $kid"

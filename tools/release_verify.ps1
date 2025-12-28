<#
.SYNOPSIS
  Verifies a signature created by tools/release_sign.ps1.

.PARAMETER PublicKeyPath
  Path to RSA public key in .NET XML format (ToXmlString(false)).

.PARAMETER InputPath
  Signed file path.

.EXAMPLE
  pwsh -File tools/release_verify.ps1 -PublicKeyPath ./keys/release_public.xml -InputPath ./dist/manifest.json
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PublicKeyPath,
  [Parameter(Mandatory)][string]$InputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SigPath = $InputPath + '.sig'
if (-not (Test-Path -LiteralPath $PublicKeyPath)) { throw "Key not found: $PublicKeyPath" }
if (-not (Test-Path -LiteralPath $InputPath)) { throw "File not found: $InputPath" }
if (-not (Test-Path -LiteralPath $SigPath)) { throw "Signature not found: $SigPath" }

$xml = Get-Content -Raw -LiteralPath $PublicKeyPath
$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.FromXmlString($xml) | Out-Null

$data = [System.IO.File]::ReadAllBytes($InputPath)
$sig  = [Convert]::FromBase64String((Get-Content -Raw -LiteralPath $SigPath).Trim())

$ok = $rsa.VerifyData($data, $sig, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
if ($ok) { Write-Host "OK" } else { throw "INVALID" }

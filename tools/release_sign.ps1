<#
.SYNOPSIS
  Signs a file with an RSA private key.

.PARAMETER KeyPath
  Path to RSA private key in .NET XML format (ToXmlString(true)).

.PARAMETER InputPath
  Path to file to sign.

.OUTPUTS
  Writes <InputPath>.sig (base64 signature).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$KeyPath,
  [Parameter(Mandatory)][string]$InputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $KeyPath)) { throw "Key not found: $KeyPath" }
if (-not (Test-Path -LiteralPath $InputPath)) { throw "File not found: $InputPath" }

$xml = Get-Content -Raw -LiteralPath $KeyPath
$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.FromXmlString($xml) | Out-Null

$data = [System.IO.File]::ReadAllBytes($InputPath)
$sig  = $rsa.SignData($data, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$b64  = [Convert]::ToBase64String($sig)

$out = $InputPath + '.sig'
Set-Content -LiteralPath $out -Value $b64 -Encoding ascii
Write-Host ("Signed: " + $out)

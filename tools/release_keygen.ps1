<#
.SYNOPSIS
  Generates a release signing keypair (RSA) for signing manifest/sums.

.DESCRIPTION
  Creates:
    - <OutDir>/release_private.xml
    - <OutDir>/release_public.xml

.EXAMPLE
  pwsh -File tools/release_keygen.ps1 -OutDir ./keys
#>
[CmdletBinding()]
param([string]$OutDir = (Join-Path (Get-Location) 'keys'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Security

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$rsa = [System.Security.Cryptography.RSA]::Create(3072)

$priv = $rsa.ToXmlString($true)
$pub  = $rsa.ToXmlString($false)

Set-Content -LiteralPath (Join-Path $OutDir 'release_private.xml') -Value $priv -Encoding utf8
Set-Content -LiteralPath (Join-Path $OutDir 'release_public.xml')  -Value $pub  -Encoding utf8

Write-Host ("Wrote: " + (Join-Path $OutDir 'release_private.xml'))
Write-Host ("Wrote: " + (Join-Path $OutDir 'release_public.xml'))

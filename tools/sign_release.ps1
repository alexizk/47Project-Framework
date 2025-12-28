<#
.SYNOPSIS
  Authenticode-signs PowerShell scripts for distribution.
.DESCRIPTION
  Signs ps1/psm1 files using a provided code signing certificate thumbprint.
.PARAMETER CertThumbprint
  Thumbprint of the code signing certificate in CurrentUser\My.
.PARAMETER Path
  Root path to sign (default: repository root).
#>


<# 
Optional: Authenticode signing helper (requires your own code signing cert).
Usage:
  $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
  .\tools\sign_release.ps1 -CertThumbprint $cert.Thumbprint
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$CertThumbprint,
  [string]$Path = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$cert = Get-Item ("Cert:\CurrentUser\My\" + $CertThumbprint)
if (-not $cert) { throw "Cert not found: $CertThumbprint" }

$files = Get-ChildItem -LiteralPath $Path -Recurse -File -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue
foreach ($f in $files) {
  Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert | Out-Null
  Write-Host ("Signed: " + $f.FullName)
}

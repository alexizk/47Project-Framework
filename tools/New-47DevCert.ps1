<#
.SYNOPSIS
  Create a development self-signed certificate (Windows) for signing plans.
#>
[CmdletBinding()]
param(
  [string]$Subject = 'CN=47Project Dev Plan Signing',
  [string]$OutPfxPath = '.\47Project.DevSigning.pfx',
  [string]$OutCerPath = '.\47Project.DevSigning.cer',
  [string]$Password = 'dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command New-SelfSignedCertificate -ErrorAction SilentlyContinue)) {
  throw "New-SelfSignedCertificate not available. Run on Windows PowerShell/Windows with certificate cmdlets."
}

$secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cert = New-SelfSignedCertificate -Subject $Subject -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy Exportable -HashAlgorithm sha256 -CertStoreLocation 'Cert:\CurrentUser\My' -KeyUsage DigitalSignature

Export-PfxCertificate -Cert $cert -FilePath $OutPfxPath -Password $secure | Out-Null
Export-Certificate -Cert $cert -FilePath $OutCerPath | Out-Null

Write-Host "Created:"
Write-Host " - $OutPfxPath"
Write-Host " - $OutCerPath"
Write-Host "Password: $Password"

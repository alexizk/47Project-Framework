<#
.SYNOPSIS
  Verify the current repository/pack folder if _integrity is present (for strict verified-release policies).

.DESCRIPTION
  If _integrity is not present, prints a message and exits 0.

.EXAMPLE
  pwsh -File tools/verify_current_pack.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Force (Join-Path $root 'Framework/Core/47.Core.psd1')

$int = Join-Path $root '_integrity'
if (-not (Test-Path -LiteralPath $int)) {
  Write-Host "No _integrity folder in pack root; skipping."
  exit 0
}

& (Join-Path $PSScriptRoot 'release_verify_offline.ps1') -FolderPath $root | Out-Null
Write-Host "OK"

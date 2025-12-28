<#
.SYNOPSIS
  Vendors Pester into ./vendor/Pester (best-effort).

.DESCRIPTION
  This script is intended for environments with internet access.
  It attempts to download Pester from PowerShell Gallery.
  The release builder can then include ./vendor so offline zips contain Pester.

.NOTES
  If PSGallery is blocked, use CI to vendor from a trusted source and commit the vendor folder.

.EXAMPLE
  pwsh -File tools/vendor_pester.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..')).Path
$vendorRoot = Join-Path $root 'vendor'
$pesterDst  = Join-Path $vendorRoot 'Pester'

if (Test-Path -LiteralPath $pesterDst) {
  Write-Host "vendor/Pester already exists."
  return
}

New-Item -ItemType Directory -Force -Path $pesterDst | Out-Null

try {
  # Prefer PSGallery when available
  Save-Module -Name Pester -MinimumVersion 5.0.0 -Path $vendorRoot -Force
  # Save-Module will create vendorRoot/Pester/<version>. Flatten a bit:
  $found = Get-ChildItem -Directory -LiteralPath (Join-Path $vendorRoot 'Pester') -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { Write-Host ("Vendored Pester: " + $found.FullName) }
} catch {
  Write-Warning ("Failed to vendor Pester via PSGallery: " + $_.Exception.Message)
  Write-Warning "You can vendor Pester in CI or manually drop it into vendor/Pester."
  throw
}

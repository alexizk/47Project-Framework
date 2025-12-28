<#
.SYNOPSIS
  Runs the release checklist locally (tests + lints + verification).

.DESCRIPTION
  Intended for maintainers before tagging a release.
  Exits non-zero if any step fails.

.PARAMETER BuildOffline
  Also build the offline release zip (dist/).

.EXAMPLE
  pwsh -File tools/release_checklist.ps1 -BuildOffline
#>
[CmdletBinding()]
param(
  [switch]$BuildOffline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host "== Vendor Pester ==" -ForegroundColor Cyan
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/verify_vendor_pester.ps1')

Write-Host "== Lint modules ==" -ForegroundColor Cyan
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/lint_modules.ps1')

Write-Host "== Run tests ==" -ForegroundColor Cyan
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/Invoke-47Tests.ps1') -CI

Write-Host "== Verify current pack (if _integrity exists) ==" -ForegroundColor Cyan
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/verify_current_pack.ps1')

if ($BuildOffline) {
  Write-Host "== Build offline release ==" -ForegroundColor Cyan
  pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/release_build.ps1')
  Write-Host "== Verify built offline zip ==" -ForegroundColor Cyan
  # If last_release state exists, verify it
  try {
    Import-Module -Force (Join-Path $root 'Framework/Core/47.Core.psd1')
    $lr = Get-47StateRecord -Name 'last_release'
    if ($lr -and $lr.zipPath) {
      pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/release_verify_offline.ps1') -ZipPath $lr.zipPath
    }
  } catch { }
}

Write-Host "OK"

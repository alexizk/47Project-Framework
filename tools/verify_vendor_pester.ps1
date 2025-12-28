<#
.SYNOPSIS
  Verifies that Pester can be imported from the vendored cache.

.DESCRIPTION
  Uses tools/install_pester.ps1 -PreferVendor to ensure the vendored cache is used.

.EXAMPLE
  pwsh -File tools/verify_vendor_pester.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
& (Join-Path $here 'install_pester.ps1') -PreferVendor | Out-Null

Import-Module Pester -ErrorAction Stop
Write-Host "OK"

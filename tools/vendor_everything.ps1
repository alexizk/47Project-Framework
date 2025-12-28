
<#
.SYNOPSIS
  Vendors test/runtime PowerShell dependencies into tools/.vendor for offline use.
.DESCRIPTION
  Populates tools/.vendor/Modules with dependencies (currently Pester 5+).
  After running once on a machine with internet access, subsequent runs can be fully offline
  by using tools/install_pester.ps1 -OfflineOnly -PreferVendor.
.PARAMETER Root
  Root folder of the pack (default: inferred).
.PARAMETER Force
  Force re-vendoring even if the vendor folder already contains the module.
.PARAMETER IncludePester
  Vendor Pester (default: true).
.PARAMETER MinPesterVersion
  Minimum Pester version (default: 5.0.0).
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
  [switch]$Force,
  [switch]$IncludePester = $true,
  [string]$MinPesterVersion = '5.0.0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[OK] " + $m) -ForegroundColor Green }
function Warn($m){ Write-Host ("[WARN] " + $m) -ForegroundColor Yellow }

# Resolve root (allow invocation from tools/)
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Framework\47Project.Framework.ps1'))) {
  $Root = Split-Path -Parent $Root
}

$vendorRoot = Join-Path $Root 'tools\.vendor'
$modulesDir = Join-Path $vendorRoot 'Modules'
New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
Info ("Vendor dir: " + $modulesDir)

if ($IncludePester) {
  $pesterDir = Join-Path $modulesDir 'Pester'
  if ((Test-Path -LiteralPath $pesterDir) -and (-not $Force)) {
    Ok "Pester already present in vendor cache (use -Force to refresh)."
  } else {
    Info "Vendoring Pester..."
    $installer = Join-Path $Root 'tools\install_pester.ps1'
    if (-not (Test-Path -LiteralPath $installer)) { throw "Missing tools/install_pester.ps1" }

    # Prefer vendor (cache) path; if empty, installer will fetch and then cache.
    & $installer -MinimumVersion $MinPesterVersion -PreferVendor:$true | Out-Null

    if (Test-Path -LiteralPath $pesterDir) { Ok "Pester vendored." }
    else { Warn "Pester vendor cache not found after install. Check install_pester.ps1 output." }
  }
}

Ok "Vendor step complete."

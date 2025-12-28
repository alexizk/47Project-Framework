<#
.SYNOPSIS
  Ensure Pester 5+ is available (and optionally cached for offline use).
.DESCRIPTION
  Strategy:
    1) If -PreferVendor or -OfflineOnly: try vendored module first (./tools/.vendor/Modules/Pester/*)
    2) Try existing installed Pester (>= MinimumVersion)
    3) Try PSGallery Install-Module (CurrentUser)
    4) Fallback: git clone https://github.com/pester/Pester.git (requires git + network)
  After Pester is available, this script will cache it under:
    ./tools/.vendor/Modules/Pester/<Version>/
  so future runs can be offline (use -OfflineOnly).
.PARAMETER MinimumVersion
  Minimum Pester version (default: 5.0.0)
.PARAMETER PreferVendor
  Prefer loading the vendored copy (if present).
.PARAMETER OfflineOnly
  Do not attempt network installs; require vendored copy.
#>
[CmdletBinding()]
param(
  [string]$MinimumVersion = '5.0.0',
  [switch]$PreferVendor,
  [switch]$OfflineOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ToolsRoot = $PSScriptRoot
$VendorModules = Join-Path $ToolsRoot '.vendor\Modules'
$VendorPesterRoot = Join-Path $VendorModules 'Pester'
$GitVendorRepo = Join-Path $ToolsRoot '.vendor\PesterRepo'

function Get-HighestVersionPath {
  param([string]$Root, [string]$LeafFile)
  if (-not (Test-Path -LiteralPath $Root)) { return $null }

  $candidates = Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
      $ver = $null
      if ([version]::TryParse($_.Name, [ref]$ver)) {
        $leaf = Join-Path $_.FullName $LeafFile
        if (Test-Path -LiteralPath $leaf) {
          [pscustomobject]@{ Version = $ver; Path = $leaf }
        }
      }
    } | Where-Object { $_ } | Sort-Object Version -Descending

  return ($candidates | Select-Object -First 1)
}

function Import-VendoredPester {
  $best = Get-HighestVersionPath -Root $VendorPesterRoot -LeafFile 'Pester.psd1'
  if (-not $best) { return $false }

  if ($best.Version -lt [version]$MinimumVersion) {
    Write-Host "Vendored Pester found ($($best.Version)) but below MinimumVersion ($MinimumVersion)." -ForegroundColor Yellow
    return $false
  }

  Import-Module $best.Path -Force | Out-Null
  Write-Host "Pester loaded (vendored): $($best.Version)" -ForegroundColor Green
  return $true
}

function Cache-PesterToVendor {
  # Finds best available Pester module and copies it into ./tools/.vendor/Modules/Pester/<Version>
  $m = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
  if (-not $m) { return }

  $dest = Join-Path $VendorPesterRoot $m.Version.ToString()
  $destManifest = Join-Path $dest 'Pester.psd1'
  if (Test-Path -LiteralPath $destManifest) { return }

  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -LiteralPath (Join-Path $m.ModuleBase '*') -Destination $dest -Recurse -Force
  Write-Host "Cached Pester to vendor: $dest" -ForegroundColor Cyan
}

function Ensure-InstalledFromPSGallery {
  if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
    throw "Install-Module not available in this PowerShell session."
  }

  # Use side-by-side install and accept publisher cert changes where needed
  $params = @{
    Name = 'Pester'
    Scope = 'CurrentUser'
    Force = $true
    AllowClobber = $true
  }

  try {
    $params['SkipPublisherCheck'] = $true
  } catch {}

  if ($MinimumVersion) { $params['MinimumVersion'] = $MinimumVersion }

  Write-Host "Installing Pester from PSGallery (CurrentUser)..." -ForegroundColor Cyan
  Install-Module @params
}

function Ensure-InstalledFromGitRepo {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is not available. Install git or vendor Pester manually."
  }

  if (-not (Test-Path -LiteralPath $GitVendorRepo)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $GitVendorRepo) | Out-Null
    Write-Host "Cloning Pester git repo..." -ForegroundColor Cyan
    git clone --depth 1 https://github.com/pester/Pester.git $GitVendorRepo | Out-Null
  } else {
    Write-Host "Pester git repo already present (vendor)." -ForegroundColor Cyan
  }

  $mod = Join-Path $GitVendorRepo 'src\Pester.psd1'
  if (-not (Test-Path -LiteralPath $mod)) { $mod = Join-Path $GitVendorRepo 'Pester.psd1' }
  if (-not (Test-Path -LiteralPath $mod)) { throw "Vendor Pester module not found after clone." }

  Import-Module $mod -Force | Out-Null
  Write-Host "Pester loaded from git repo vendor." -ForegroundColor Green

  # Copy the 'src' folder into the vendor Modules layout so we can be offline later
  $src = Split-Path -Parent $mod
  $mf = Import-PowerShellDataFile -LiteralPath $mod
  $ver = [version]$mf.ModuleVersion

  $dest = Join-Path $VendorPesterRoot $ver.ToString()
  $destManifest = Join-Path $dest 'Pester.psd1'
  if (-not (Test-Path -LiteralPath $destManifest)) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -LiteralPath (Join-Path $src '*') -Destination $dest -Recurse -Force
    Write-Host "Cached Pester (from git) to vendor: $dest" -ForegroundColor Cyan
  }
}

# --- main ---
try {
  if ($PreferVendor -or $OfflineOnly) {
    if (Import-VendoredPester) { return }
    if ($OfflineOnly) { throw "OfflineOnly specified but no suitable vendored Pester found under: $VendorPesterRoot" }
  }

  # Try installed Pester first
  $existing = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
  if ($existing -and ($existing.Version -ge [version]$MinimumVersion)) {
    Import-Module $existing.Path -Force | Out-Null
    Write-Host "Pester loaded (installed): $($existing.Version)" -ForegroundColor Green
    Cache-PesterToVendor
    return
  }

  if ($OfflineOnly) { throw "OfflineOnly specified but Pester is not vendored and not installed." }

  # Try PSGallery
  try {
    Ensure-InstalledFromPSGallery
    $after = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
    if ($after -and ($after.Version -ge [version]$MinimumVersion)) {
      Import-Module $after.Path -Force | Out-Null
      Write-Host "Pester loaded (PSGallery): $($after.Version)" -ForegroundColor Green
      Cache-PesterToVendor
      return
    }
    throw "PSGallery install did not yield a suitable Pester module."
  } catch {
    Write-Host "PSGallery install failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Falling back to git vendor install..." -ForegroundColor Yellow
  }

  Ensure-InstalledFromGitRepo

  # Prefer vendored copy after caching
  if (Import-VendoredPester) { return }

  # last resort: keep whatever is loaded
  Write-Host "Pester is available, but vendoring check did not succeed; continuing." -ForegroundColor Yellow
} catch {
  throw "Unable to provision Pester. Hint: run `pwsh -File tools/install_pester.ps1 -PreferVendor` once online to cache it. Details: $($_.Exception.Message)"
}

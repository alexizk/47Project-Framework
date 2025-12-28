<#
.SYNOPSIS
  Builds an offline release zip (vendored dependencies + checksums + manifest).

.DESCRIPTION
  Creates dist/47Project_Framework_<version>_offline.zip
  Generates:
    - dist/manifest.json
    - dist/SHA256SUMS.txt
  Optionally signs outputs if -SignKeyPath is provided.

  This script is designed to be reproducible: it copies a curated set of repo paths into a staging folder,
  then zips the staging folder.

.PARAMETER OutDir
  Output directory (default: ./dist)

.PARAMETER IncludeTests
  Include ./tests in release (default: true)

.PARAMETER SignKeyPath
  Optional RSA private key path (XML or PEM) used to sign SHA256SUMS.txt and manifest.json.
  Use tools/release_keygen.ps1 to generate a keypair.

.PARAMETER VendorPester
  If set, attempts to vendor Pester into ./vendor/Pester before building (requires internet).

.EXAMPLE
  pwsh -NoLogo -NoProfile -File tools/release_build.ps1 -VendorPester

.EXAMPLE
  pwsh -NoLogo -NoProfile -File tools/release_build.ps1 -SignKeyPath ./keys/release_private.xml
#>
[CmdletBinding()]
param(
  [string]$OutDir = (Join-Path (Get-Location) 'dist'),
  [switch]$IncludeTests = $true,
  [string]$SignKeyPath = '',
  [switch]$VendorPester
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
  $here = Split-Path -Parent $PSCommandPath
  return (Resolve-Path (Join-Path $here '..')).Path
}

function Get-VersionTag {
  $root = Get-RepoRoot
  $verPath = Join-Path $root 'version.json'
  if (-not (Test-Path -LiteralPath $verPath)) { return 'unknown' }
  try {
    $v = (Get-Content -Raw -LiteralPath $verPath | ConvertFrom-Json)
    if ($v.version) { return [string]$v.version }
  } catch { }
  return 'unknown'
}

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Copy-Tree([string]$src,[string]$dst) {
  if (-not (Test-Path -LiteralPath $src)) { return }
  Ensure-Dir $dst
  Copy-Item -Recurse -Force -LiteralPath $src -Destination $dst
}

function Hash-File([string]$path) {
  $h = Get-FileHash -Algorithm SHA256 -LiteralPath $path
  return $h.Hash.ToLowerInvariant()
}

function Write-Manifest([string]$stage,[string]$outPath) {
  $items = @()
  Get-ChildItem -Recurse -File -LiteralPath $stage | ForEach-Object {
    $rel = $_.FullName.Substring($stage.Length).TrimStart('\','/')
    $rel = $rel -replace '\\','/'
    $items += [pscustomobject]@{
      path = $rel
      sha256 = (Hash-File $_.FullName)
      bytes = $_.Length
    }
  }
  $items | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outPath -Encoding utf8
}

function Write-ShaSums([string]$stage,[string]$outPath) {
  $lines = @()
  Get-ChildItem -Recurse -File -LiteralPath $stage | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring($stage.Length).TrimStart('\','/')
    $rel = $rel -replace '\\','/'
    $lines += ("{0}  {1}" -f (Hash-File $_.FullName), $rel)
  }
  $lines | Set-Content -LiteralPath $outPath -Encoding utf8
}

$root = Get-RepoRoot

if ($VendorPester) {
  & (Join-Path $root 'tools/vendor_pester.ps1') | Out-Null
}

$tag = Get-VersionTag
Ensure-Dir $OutDir

$stage = Join-Path $OutDir ("stage_" + $tag + "_" + (Get-Date).ToString('yyyyMMdd_HHmmss'))
Ensure-Dir $stage

# Curated copy set
Copy-Tree (Join-Path $root 'Framework') (Join-Path $stage 'Framework')
Copy-Tree (Join-Path $root 'modules')   (Join-Path $stage 'modules')
Copy-Tree (Join-Path $root 'tools')     (Join-Path $stage 'tools')
Copy-Tree (Join-Path $root 'tools/.vendor') (Join-Path $stage 'tools/.vendor')
Copy-Tree (Join-Path $root 'docs')      (Join-Path $stage 'docs')
Copy-Tree (Join-Path $root 'vendor')    (Join-Path $stage 'vendor')
Copy-Item -Force -LiteralPath (Join-Path $root 'README.md') -Destination (Join-Path $stage 'README.md') -ErrorAction SilentlyContinue
Copy-Item -Force -LiteralPath (Join-Path $root 'LICENSE')   -Destination (Join-Path $stage 'LICENSE')   -ErrorAction SilentlyContinue
Copy-Item -Force -LiteralPath (Join-Path $root 'version.json') -Destination (Join-Path $stage 'version.json') -ErrorAction SilentlyContinue

if ($IncludeTests) {
  Copy-Tree (Join-Path $root 'tests') (Join-Path $stage 'tests')
}

# Build manifest + sums
$manifestPath = Join-Path $OutDir 'manifest.json'
$sumsPath     = Join-Path $OutDir 'SHA256SUMS.txt'
Write-Manifest -stage $stage -outPath $manifestPath
Write-ShaSums  -stage $stage -outPath $sumsPath

# Embed integrity metadata inside the offline zip
$intDir = Join-Path $stage '_integrity'
Ensure-Dir $intDir
Copy-Item -Force -LiteralPath $manifestPath -Destination (Join-Path $intDir 'manifest.json')
Copy-Item -Force -LiteralPath $sumsPath -Destination (Join-Path $intDir 'SHA256SUMS.txt')

# Zip
$zipName = ("47Project_Framework_{0}_offline.zip" -f $tag)
$zipPath = Join-Path $OutDir $zipName
if (Test-Path -LiteralPath $zipPath) { Remove-Item -Force -LiteralPath $zipPath }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zipPath)

# Optional signing
if (-not [string]::IsNullOrWhiteSpace($SignKeyPath)) {

  & (Join-Path $root 'tools/release_sign.ps1') -KeyPath $SignKeyPath -InputPath $manifestPath | Out-Null
  
  # Also embed sigs into the zip
  Copy-Item -Force -LiteralPath ($manifestPath + '.sig') -Destination (Join-Path $intDir 'manifest.json.sig') -ErrorAction SilentlyContinue
  Copy-Item -Force -LiteralPath ($sumsPath + '.sig') -Destination (Join-Path $intDir 'SHA256SUMS.txt.sig') -ErrorAction SilentlyContinue
  & (Join-Path $root 'tools/release_sign.ps1') -KeyPath $SignKeyPath -InputPath $sumsPath | Out-Null
}

Write-Host ("Release built: " + $zipPath)
Write-Host ("Manifest: " + $manifestPath)
Write-Host ("SHA256SUMS: " + $sumsPath)



# Record last release build (best-effort)
try {
  Import-Module (Join-Path (Join-Path $root 'Framework') 'Core/47.Core.psd1') -Force | Out-Null
  $rec = [pscustomobject]@{
    timestamp = (Get-Date).ToString('o')
    tag = $tag
    zipPath = $zipPath
    manifestPath = $manifestPath
    sha256SumsPath = $sumsPath
    signed = (-not [string]::IsNullOrWhiteSpace($SignKeyPath))
  }
  Set-47StateRecord -Name 'last_release' -Value $rec | Out-Null
} catch { }

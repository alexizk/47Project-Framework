
<#
.SYNOPSIS
  Produces a fully offline distributable zip (includes tools/.vendor cache).
.DESCRIPTION
  Runs vendoring, regenerates dist_manifest.json, and emits a timestamped offline zip into dist/.
  The offline zip includes vendored dependencies so tests can run without PSGallery/network.
.PARAMETER Root
  Root folder of the pack (default: inferred).
.PARAMETER OutDir
  Output directory (default: <root>\dist).
.PARAMETER Version
  Override version label (default: value from version.json).
.PARAMETER Notes
  Optional release notes summary to pass to tools/release.ps1.
.PARAMETER SkipVendor
  Skip vendoring step (assumes vendor cache already populated).
.PARAMETER SkipManifest
  Skip regenerating dist_manifest.json.
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
  [string]$OutDir = '',
  [string]$Version = '',
  [string]$Notes = '',
  [switch]$SkipVendor,
  [switch]$SkipManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }
function Ok($m){ Write-Host ("[OK] " + $m) -ForegroundColor Green }

# Resolve root (allow invocation from tools/)
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Framework\47Project.Framework.ps1'))) {
  $Root = Split-Path -Parent $Root
}
if (-not $OutDir) { $OutDir = Join-Path $Root 'dist' }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# Determine version
if ([string]::IsNullOrWhiteSpace($Version)) {
  $vp = Join-Path $Root 'version.json'
  if (Test-Path -LiteralPath $vp) {
    $j = Get-Content -LiteralPath $vp -Raw | ConvertFrom-Json
    if ($j -and $j.version) { $Version = [string]$j.version }
  }
}
if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'v?' }

# 1) Vendor dependencies
if (-not $SkipVendor) {
  $vend = Join-Path $Root 'tools\vendor_everything.ps1'
  if (-not (Test-Path -LiteralPath $vend)) { throw "Missing tools/vendor_everything.ps1" }
  & $vend -Root $Root | Out-Null
}

# 2) Regenerate manifest (or run release pipeline if present)
if (-not $SkipManifest) {
  $rel = Join-Path $Root 'tools\release.ps1'
  if (Test-Path -LiteralPath $rel) {
    # do not bump version here, just refresh manifest
    & $rel -Version $Version -Notes $Notes -SkipChangelog -SkipReadme | Out-Null
  } else {
    # fallback: compute dist_manifest.json
    $manifest = @()
    Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
      $relp = $_.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/')
      $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      $manifest += [pscustomobject]@{ path = $relp; sha256 = $sha; bytes = $_.Length }
    }
    ($manifest | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath (Join-Path $Root 'dist_manifest.json') -Encoding utf8
  }
}

# 3) Copy to staging folder and zip
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$stage = Join-Path $OutDir ("47ProjectFramework_Offline_" + $Version + "_" + $stamp)
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

Info "Staging copy..."
Copy-Item -LiteralPath (Join-Path $Root '*') -Destination $stage -Recurse -Force

# Remove dist and data inside stage to keep distribution clean
$innerDist = Join-Path $stage 'dist'
if (Test-Path -LiteralPath $innerDist) { Remove-Item -LiteralPath $innerDist -Recurse -Force }
$innerData = Join-Path $stage 'data'
if (Test-Path -LiteralPath $innerData) { Remove-Item -LiteralPath $innerData -Recurse -Force }

# Ensure vendor cache is present
$vendDir = Join-Path $stage 'tools\.vendor\Modules\Pester'
if (-not (Test-Path -LiteralPath $vendDir)) {
  Info "WARNING: vendor cache missing in stage (offline tests may not work)."
}

$zip = $stage + '.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

Info ("Creating offline zip: " + $zip)
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Ok "Offline release ready."
Ok ("Zip: " + $zip)

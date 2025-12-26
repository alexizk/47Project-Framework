# Generate-47RepoIndex.ps1
# Builds/updates repository indexes by scanning a packages/ folder (offline).
# Supports optional channels at: <RepoRoot>\channels\<channel>\packages\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)]
  [string]$RepoRoot,

  [string]$RepositoryId = 'repo.local.generated',
  [string]$DisplayName  = 'Local Repo (Generated)',

  [ValidateSet('stable','beta','nightly')]
  [string]$Channel
)

function Build-Index([string]$packagesRoot, [hashtable]$meta) {
  if (-not (Test-Path -LiteralPath $packagesRoot)) {
    New-Item -ItemType Directory -Force -Path $packagesRoot | Out-Null
  }

  $now = (Get-Date).ToUniversalTime().ToString('o')
  $packages = @()

  Get-ChildItem -LiteralPath $packagesRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $pkgId = $_.Name
    Get-ChildItem -LiteralPath $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $ver = $_.Name
      $files = Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue
      $hashes = @()
      foreach ($f in $files) {
        $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLowerInvariant()
        $rel = $f.FullName.Substring($_.FullName.Length).TrimStart('\','/')
        $hashes += [pscustomobject]@{ path = $rel; sha256 = $h; size = $f.Length }
      }
      $packages += [pscustomobject]@{
        packageId = $pkgId
        version   = $ver
        updatedAt = $now
        channel   = $meta.Channel
        files     = $hashes
      }
    }
  }

  $index = [ordered]@{
    schemaVersion = '1.0.0'
    repositoryId  = $meta.RepositoryId
    displayName   = $meta.DisplayName
    updatedAt     = $now
    packages      = $packages
  }

  return $index
}

if (-not (Test-Path -LiteralPath $RepoRoot)) { throw "RepoRoot not found: $RepoRoot" }

if ($Channel) {
  $channelRoot = Join-Path $RepoRoot "channels\$Channel"
  if (-not (Test-Path -LiteralPath $channelRoot)) { New-Item -ItemType Directory -Force -Path $channelRoot | Out-Null }
  $packagesRoot = Join-Path $channelRoot 'packages'
  $indexPath = Join-Path $channelRoot 'index.json'

  $idx = Build-Index -packagesRoot $packagesRoot -meta @{ RepositoryId=$RepositoryId; DisplayName="$DisplayName ($Channel)"; Channel=$Channel }
  $idx | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $indexPath -Encoding UTF8
  Write-Host "Wrote: $indexPath"
  exit 0
}

# No channel -> generate main (non-channel) index from <RepoRoot>\packages\
$packagesRoot = Join-Path $RepoRoot 'packages'
$indexPath = Join-Path $RepoRoot 'index.json'
$idx = Build-Index -packagesRoot $packagesRoot -meta @{ RepositoryId=$RepositoryId; DisplayName=$DisplayName; Channel=$null }
$idx | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $indexPath -Encoding UTF8
Write-Host "Wrote: $indexPath"

# If channels exist, create/update a root manifest that references them
$channelsRoot = Join-Path $RepoRoot 'channels'
if (Test-Path -LiteralPath $channelsRoot) {
  $now = (Get-Date).ToUniversalTime().ToString('o')
  $manifest = [ordered]@{
    schemaVersion = '1.0.0'
    repositoryId  = $RepositoryId
    displayName   = $DisplayName
    updatedAt     = $now
    channels      = [ordered]@{}
  }
  foreach ($ch in @('stable','beta','nightly')) {
    $p = Join-Path $channelsRoot "$ch\index.json"
    if (Test-Path -LiteralPath $p) {
      $manifest.channels[$ch] = [ordered]@{
        updatedAt = $now
        packages  = (Get-Content -Raw -LiteralPath $p | ConvertFrom-Json).packages
      }
    }
  }
  $manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $RepoRoot 'index.json') -Encoding UTF8
  Write-Host "Updated channel manifest: $(Join-Path $RepoRoot 'index.json')"
}

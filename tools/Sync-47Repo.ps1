# Sync-47Repo.ps1
# Download/copy a repository index and its referenced files into a local repo root, verifying hashes (and optional signature).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Index,
  [string]$TargetRepoRoot,
  [string]$CertPath,
  [switch]$AllowUnsigned
)

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

function Is-Uri([string]$s) {
  try { [void][uri]$s; return ($s -match '^\w+://') } catch { return $false }
}

$paths = Get-47Paths
if (-not $TargetRepoRoot) { $TargetRepoRoot = $paths.RepositoriesRoot }

# Stage index
$tmp = Join-Path $paths.TempRoot ("repo_sync_" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$indexLocal = Join-Path $tmp 'index.json'

$baseUri = $null
$basePath = $null

if (Is-Uri $Index) {
  $u = [uri]$Index
  $baseUri = ($u.GetLeftPart([System.UriPartial]::Authority) + ($u.AbsolutePath -replace '/[^/]+$','/'))
  Invoke-WebRequest -Uri $Index -OutFile $indexLocal -UseBasicParsing | Out-Null
} else {
  $full = (Resolve-Path -LiteralPath $Index).Path
  Copy-Item -LiteralPath $full -Destination $indexLocal -Force
  $basePath = Split-Path -Parent $full
}

$idx = Read-47Json -Path $indexLocal

# Verify signature if present
if ($idx.signature) {
  if (-not $CertPath) { throw "Index is signed but -CertPath not provided." }
  & (Join-Path $packRoot 'tools\Verify-47RepoIndex.ps1') -IndexPath $indexLocal -CertPath $CertPath | Out-Null
} else {
  if (-not $AllowUnsigned) { throw "Index is unsigned. Re-run with -AllowUnsigned if you want to proceed." }
}

# Determine destination
$channel = $idx.channel
$destRoot = $TargetRepoRoot
if ($channel) {
  $destRoot = Join-Path $TargetRepoRoot ("channels\" + $channel)
}
New-Item -ItemType Directory -Force -Path $destRoot | Out-Null

# Save index into destination
Copy-Item -LiteralPath $indexLocal -Destination (Join-Path $destRoot 'index.json') -Force

# Sync files
$pkgs = @($idx.packages)
foreach ($pkg in $pkgs) {
  $files = @($pkg.files)
  foreach ($f in $files) {
    $rel = $f.path
    if (-not $rel) { continue }
    $expected = if ($f.sha256) { $f.sha256.ToLowerInvariant() } else { $null }

    $dest = Join-Path $destRoot $rel
    $destDir = Split-Path -Parent $dest
    if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

    $stage = Join-Path $tmp ([Guid]::NewGuid().ToString('N') + "_" + (Split-Path -Leaf $rel))

    if ($baseUri) {
      $srcUri = ($baseUri.TrimEnd('/') + "/" + $rel.TrimStart('/')) -replace '\\','/'
      Invoke-WebRequest -Uri $srcUri -OutFile $stage -UseBasicParsing | Out-Null
    } else {
      $srcPath = Join-Path $basePath $rel
      if (-not (Test-Path -LiteralPath $srcPath)) { throw "Repo file missing: $srcPath" }
      Copy-Item -LiteralPath $srcPath -Destination $stage -Force
    }

    if ($expected) {
      $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $stage).Hash.ToLowerInvariant()
      if ($actual -ne $expected) { throw "Hash mismatch for $rel. expected=$expected actual=$actual" }
    }

    Move-Item -LiteralPath $stage -Destination $dest -Force
  }
}

Write-Host "Repo sync complete: $destRoot"

# Update-47Framework.ps1
# Offline updater: installs a new framework pack from a local zip using safe extraction + atomic swap + snapshot.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)]
  [string]$ZipPath,

  [string]$TargetRoot,

  [switch]$SkipTrustCheck
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Zip not found: $ZipPath" }
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ZipPath).Hash.ToLowerInvariant()

if (-not $TargetRoot) { $TargetRoot = (Get-47PackRoot) }

Write-Host "Zip: $ZipPath"
Write-Host "SHA256: $zipHash"
Write-Host "TargetRoot: $TargetRoot"
Write-Host ""

# Trust (optional)
if (-not $SkipTrustCheck) {
  if (Test-47ArtifactHashTrusted -Sha256Hex $zipHash) {
    Write-Host "Trust: OK (hash pinned in trust store)"
  } else {
    Write-Warning "Trust: NOT VERIFIED (hash not pinned). Proceeding because SkipTrustCheck is not set to block."
    Write-Warning "To pin this artifact, add the hash to: trust/publishers.json -> trustedArtifactHashes"
  }
}

# Snapshot (for rollback)
Write-Host "Creating pre-update snapshot (includes pack)..."
$snap = Save-47Snapshot -Name 'pre_update' -IncludePack
Write-Host "Snapshot: $snap"
Write-Host ""

# Stage
$stage = New-47TempDirectory -Prefix 'update'
$newRoot = Join-Path $stage 'new_pack'
Expand-47ZipSafe -ZipPath $ZipPath -DestinationPath $newRoot

# Minimal sanity checks
$mustHave = @('Framework','schemas','modules','tools','README.md')
foreach ($m in $mustHave) {
  if (-not (Test-Path -LiteralPath (Join-Path $newRoot $m))) { throw "Invalid pack, missing '$m' at root." }
}

# Atomic swap
$parent = Split-Path -Parent (Resolve-Path $TargetRoot).Path
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $parent ("Framework_Previous_{0}" -f $ts)

Write-Host "Swapping..."
Write-Host "Backup: $backup"

try {
  if (Test-Path -LiteralPath $backup) { Remove-Item -Recurse -Force -LiteralPath $backup }

  # Move current -> backup
  Move-Item -LiteralPath $TargetRoot -Destination $backup

  # Move new -> target
  Move-Item -LiteralPath $newRoot -Destination $TargetRoot

  Write-Host ""
  Write-Host "Update complete."
  Write-Host "Previous version kept at: $backup"
} catch {
  Write-Error "Update failed: $($_.Exception.Message)"
  Write-Warning "Attempting rollback to previous..."
  try {
    if (Test-Path -LiteralPath $TargetRoot) { Remove-Item -Recurse -Force -LiteralPath $TargetRoot }
    if (Test-Path -LiteralPath $backup) { Move-Item -LiteralPath $backup -Destination $TargetRoot }
  } catch {
    Write-Warning "Rollback move failed. You can restore from snapshot: $snap"
  }
  throw
} finally {
  # cleanup
  try { if (Test-Path -LiteralPath $stage) { Remove-Item -Recurse -Force -LiteralPath $stage } } catch {}
}

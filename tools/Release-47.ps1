# Release-47.ps1
# Reproducible-ish release builder for the zip-distributed framework.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$OutDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'dist'),
  [string]$VersionTag = (Get-Date -Format "yyyy.MM.dd-HHmmss"),
  [switch]$RunStyleCheck,
  [switch]$RunDocsBuild,
  [switch]$RunSecurityScan
)

$packRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function New-EmptyDir([string]$p) {
  if (Test-Path -LiteralPath $p) { Remove-Item -Recurse -Force -LiteralPath $p }
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

if ($RunStyleCheck) {
  & (Join-Path $packRoot 'tools\Invoke-47StyleCheck.ps1') -Path $packRoot
}

# Tests
& (Join-Path $packRoot 'tools\Build-All.ps1')

if ($RunDocsBuild) {
  & (Join-Path $packRoot 'tools\Build-47Docs.ps1') -PackRoot $packRoot
}


if ($RunSecurityScan) {
  Write-Host "Security scan..."
  & (Join-Path $packRoot 'tools\Invoke-47SecurityScan.ps1') -FailOnFindings
}
# Create release zip
$zipName = "47Project_Framework_Ultimate_Pack_$VersionTag.zip"
$zipPath = Join-Path $OutDir $zipName

if (Test-Path -LiteralPath $zipPath) { Remove-Item -Force -LiteralPath $zipPath }


# Artifact manifest
$manifestTool = Join-Path $packRoot 'tools\Generate-47ArtifactManifest.ps1'
if (Test-Path -LiteralPath $manifestTool) {
  & $manifestTool -PackRoot $packRoot -VersionTag $VersionTag | Out-Null
}

Write-Host "Creating release zip: $zipPath"
Compress-Archive -Path (Join-Path $packRoot '*') -DestinationPath $zipPath -Force

# Checksums
$sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
$shaPath = $zipPath + '.sha256'
"$sha256  $zipName" | Set-Content -NoNewline -Encoding ascii -LiteralPath $shaPath

# Optional: sign artifacts (pluggable)
Write-Host ""
Write-Host "Release created:"
Write-Host " - $zipPath"
Write-Host " - $shaPath"
Write-Host ""
Write-Host "Next: integrate Verify-47Signature/Trust store at release time if desired."

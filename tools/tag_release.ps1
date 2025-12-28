<#
.SYNOPSIS
  Run release checklist then create an annotated git tag.

.PARAMETER Tag
  Tag name (e.g., v38).

.PARAMETER BuildOffline
  Also build offline zip and verify.

.EXAMPLE
  pwsh -File tools/tag_release.ps1 -Tag v38 -BuildOffline
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Tag,
  [switch]$BuildOffline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Checklist first
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/release_checklist.ps1') -BuildOffline:$BuildOffline

# Generate release notes for tag
pwsh -NoLogo -NoProfile -File (Join-Path $root 'tools/release_notes.ps1') -Tag $Tag -OutPath (Join-Path $root 'dist/release_notes.md') | Out-Null

# Tag via git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git is not available. Install git or tag manually: git tag -a $Tag -m 'Release $Tag'"
}

Push-Location $root
try {
  git status --porcelain | Out-String | ForEach-Object {
    if (-not [string]::IsNullOrWhiteSpace($_)) { throw "Working tree not clean. Commit changes before tagging." }
  }
  git tag -a $Tag -m ("Release " + $Tag)
  Write-Host "Tagged: $Tag"
  Write-Host "Next: git push origin $Tag"
} finally {
  Pop-Location
}

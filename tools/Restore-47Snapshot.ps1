Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)]
  [string]$SnapshotPath,
  [switch]$RestorePack,
  [switch]$RestoreMachine,
  [switch]$Force
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

if (-not $Force) {
  Write-Host ""
  Write-Warning "Restore will overwrite your current user data (and optionally machine data)."
  Write-Warning "Re-run with -Force to proceed."
  exit 2
}

Restore-47Snapshot -SnapshotPath $SnapshotPath -RestorePack:$RestorePack -RestoreMachine:$RestoreMachine -Confirm:$false

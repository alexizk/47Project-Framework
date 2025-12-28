
<#
.SYNOPSIS
  Verifies file hashes against dist_manifest.json.
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manPath = Join-Path $Root 'dist_manifest.json'
if (-not (Test-Path -LiteralPath $manPath)) { throw "Missing dist_manifest.json" }

$items = Get-Content -LiteralPath $manPath -Raw | ConvertFrom-Json
$bad = @()

foreach ($it in $items) {
  $p = Join-Path $Root ([string]$it.path).Replace('/','\')
  if (-not (Test-Path -LiteralPath $p)) { $bad += "MISSING: $($it.path)"; continue }
  $sha = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($sha -ne ([string]$it.sha256).ToLowerInvariant()) { $bad += "MISMATCH: $($it.path)" }
}

if ($bad.Count -gt 0) {
  Write-Host "Manifest verification FAILED:" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "Manifest verification OK." -ForegroundColor Green

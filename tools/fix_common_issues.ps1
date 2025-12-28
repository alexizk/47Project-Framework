
<#
.SYNOPSIS
  Applies safe, offline fixes for common 47Project Framework issues.
.DESCRIPTION
  Creates missing folders, backs up and resets broken JSON files under data/, and can regenerate manifest.
  This tool does NOT run destructive actions (no delete of project content).
.PARAMETER Root
  Root folder of the pack.
.PARAMETER ResetDataJson
  Backup and reset common JSON config files in data/ (favorites, recent, ui-state, etc.).
.PARAMETER RegenerateManifest
  Regenerate dist_manifest.json (SHA256).
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
  [switch]$ResetDataJson,
  [switch]$RegenerateManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info($m){ Write-Host ("[INFO] " + $m) -ForegroundColor Cyan }

if (-not (Test-Path -LiteralPath (Join-Path $Root 'Framework\47Project.Framework.ps1'))) {
  $Root = Split-Path -Parent $Root
}

$data = Join-Path $Root 'data'
$logs = Join-Path $data 'logs'
$docs = Join-Path $Root 'docs'
$tools = Join-Path $Root 'tools'
New-Item -ItemType Directory -Path $data -Force | Out-Null
New-Item -ItemType Directory -Path $logs -Force | Out-Null
New-Item -ItemType Directory -Path $docs -Force | Out-Null
New-Item -ItemType Directory -Path $tools -Force | Out-Null
Info "Ensured core folders exist."

if ($ResetDataJson) {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $backup = Join-Path $data ("backup_datajson_" + $stamp + ".zip")

  $common = @(
    'favorites.json',
    'recent.json',
    'ui-state.json',
    'app-profiles.json',
    'safe-mode.json',
    'pinned-commands.json'
  )

  $tmp = Join-Path $data ("_reset_" + $stamp)
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null

  foreach ($f in $common) {
    $p = Join-Path $data $f
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination (Join-Path $tmp $f) -Force }
  }

  if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force }
  Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $backup -Force
  Remove-Item -LiteralPath $tmp -Recurse -Force
  Info ("Backed up JSON to: " + $backup)

  # Reset to minimal defaults
  @{ } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'ui-state.json') -Encoding utf8
  @()  | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'favorites.json') -Encoding utf8
  @()  | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'recent.json') -Encoding utf8
  @()  | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'pinned-commands.json') -Encoding utf8
  @{ enabled = $false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'safe-mode.json') -Encoding utf8
  @{ } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $data 'app-profiles.json') -Encoding utf8
  Info "Reset common data/*.json to defaults."
}

if ($RegenerateManifest) {
  $manifest = @()
  Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/')
    $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest += [pscustomobject]@{ path = $rel; sha256 = $sha; bytes = $_.Length }
  }
  ($manifest | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath (Join-Path $Root 'dist_manifest.json') -Encoding utf8
  Info "Regenerated dist_manifest.json"
}

Info "Done."

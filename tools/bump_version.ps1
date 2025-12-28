
<#
.SYNOPSIS
  Bumps the pack version and regenerates dist_manifest.json.
.PARAMETER Version
  New version string (e.g., v17).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$verPath = Join-Path $root 'version.json'

if (-not (Test-Path -LiteralPath $verPath)) { throw "Missing version.json" }

$j = Get-Content -LiteralPath $verPath -Raw | ConvertFrom-Json
$j.version = $Version
$j.date = (Get-Date -Format 'yyyy-MM-dd')
($j | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $verPath -Encoding utf8

Write-Host ("Updated version.json to " + $Version)

$manifest = @()
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
  $rel = $_.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
  $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest += [pscustomobject]@{ path = $rel; sha256 = $sha; bytes = $_.Length }
}
($manifest | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath (Join-Path $root 'dist_manifest.json') -Encoding utf8
Write-Host "Regenerated dist_manifest.json"


<#
.SYNOPSIS
  One-command release pipeline for 47Project Framework.
.DESCRIPTION
  Updates version.json, regenerates dist_manifest.json, updates docs/CHANGELOG.md, and refreshes README header.
  This is a local helper for maintainers (does not publish to GitHub automatically).
.PARAMETER Version
  New version string (e.g., v17).
.PARAMETER Notes
  Optional short notes to add under the changelog entry.
.PARAMETER SkipManifest
  Skip regenerating dist_manifest.json.
.PARAMETER SkipChangelog
  Skip updating docs/CHANGELOG.md.
.PARAMETER SkipReadme
  Skip updating README.md.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Version,
  [string]$Notes = '',
  [switch]$SkipManifest,
  [switch]$SkipChangelog,
  [switch]$SkipReadme
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Root {
  return (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
}

$root = Get-Root
$verPath = Join-Path $root 'version.json'
if (-not (Test-Path -LiteralPath $verPath)) { throw "Missing version.json" }

# 1) Update version.json
$j = Get-Content -LiteralPath $verPath -Raw | ConvertFrom-Json
$j.version = $Version
$j.date = (Get-Date -Format 'yyyy-MM-dd')
($j | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $verPath -Encoding utf8
Write-Host ("Updated version.json -> " + $Version)

# 2) Manifest
if (-not $SkipManifest) {
  $manifest = @()
  Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
    $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest += [pscustomobject]@{ path = $rel; sha256 = $sha; bytes = $_.Length }
  }
  ($manifest | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath (Join-Path $root 'dist_manifest.json') -Encoding utf8
  Write-Host "Regenerated dist_manifest.json"
}

# 3) Changelog
if (-not $SkipChangelog) {
  $cl = Join-Path $root 'docs\CHANGELOG.md'
  if (Test-Path -LiteralPath $cl) {
    $txt = Get-Content -LiteralPath $cl -Raw
    $date = (Get-Date -Format 'yyyy-MM-dd')
    $entry = "`n## $Version ($date)`n- Release pipeline run.`n"
    if (-not [string]::IsNullOrWhiteSpace($Notes)) {
      $n = $Notes -replace "`r","" -split "`n"
      foreach ($line in $n) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { $entry += ("- " + $line.Trim() + "`n") }
      }
    }
    if ($txt -notmatch [regex]::Escape("## $Version")) {
      $txt = $txt -replace "(?s)^# Changelog(\r?\n)", ("# Changelog`r`n" + $entry + "`r`n")
      Set-Content -LiteralPath $cl -Value $txt -Encoding utf8
      Write-Host "Updated docs/CHANGELOG.md"
    } else {
      Write-Host "Changelog already contains this version."
    }
  } else {
    Write-Host "docs/CHANGELOG.md not found - skipped."
  }
}

# 4) README
if (-not $SkipReadme) {
  $rp = Join-Path $root 'README.md'
  if (Test-Path -LiteralPath $rp) {
    $r = Get-Content -LiteralPath $rp -Raw
    $r = [regex]::Replace($r, "Current bundle:\s*\*\*v\d+\*\*", ("Current bundle: **" + $Version + "**"))
    Set-Content -LiteralPath $rp -Value $r -Encoding utf8
    Write-Host "Updated README.md header"
  }
}

Write-Host "Done."

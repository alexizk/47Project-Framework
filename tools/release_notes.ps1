<#
.SYNOPSIS
  Generate release notes markdown (from docs/CHANGELOG.md), optionally for a given tag.

.PARAMETER Tag
  Tag name (e.g., v37). If not provided, uses current version from version.json.

.PARAMETER OutPath
  Write markdown to this file. Defaults to dist/release_notes.md.

.EXAMPLE
  pwsh -File tools/release_notes.ps1 -Tag v37 -OutPath dist/release_notes.md
#>
[CmdletBinding()]
param(
  [string]$Tag = '',
  [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ch = Join-Path $root 'docs/CHANGELOG.md'
if (-not (Test-Path -LiteralPath $ch)) { throw "Missing changelog: $ch" }

if ([string]::IsNullOrWhiteSpace($Tag)) {
  try {
    $v = Get-Content -Raw -LiteralPath (Join-Path $root 'version.json') | ConvertFrom-Json
    $Tag = [string]$v.version
  } catch { }
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $OutPath = Join-Path (Join-Path $root 'dist') 'release_notes.md'
}

$txt = Get-Content -Raw -LiteralPath $ch

function Extract-Section([string]$md,[string]$tag) {
  $re = [regex]("(?ms)^\#\#\s+" + [regex]::Escape($tag) + "\b.*?$")
  $m = $re.Match($md)
  if (-not $m.Success) { return $null }

  $start = $m.Index
  $next = [regex]::Match($md, "(?ms)^\#\#\s+", $start + 1)
  if ($next.Success) {
    return $md.Substring($start, $next.Index - $start).Trim()
  }
  return $md.Substring($start).Trim()
}

$sec = $null
if (-not [string]::IsNullOrWhiteSpace($Tag)) {
  $sec = Extract-Section -md $txt -tag $Tag
}

if (-not $sec) {
  # fallback: latest section
  $m = [regex]::Match($txt, "(?ms)^\#\#\s+v\d+\b.*?$")
  if ($m.Success) {
    $sec = $txt.Substring($m.Index).Trim()
    # trim to next section
    $n = [regex]::Match($sec, "(?ms)^\#\#\s+", 4)
    if ($n.Success) { $sec = $sec.Substring(0, $n.Index).Trim() }
  } else {
    $sec = "## Release Notes`n`n(No changelog section found.)"
  }
}

$body = @(
  "# 47Project Framework $Tag"
  ""
  $sec
  ""
  "### Assets"
  "- Offline zip in this release includes `_integrity/` metadata and vendored tooling (Pester under `tools/.vendor` when built in CI)."
) -join "`n"

$od = Split-Path -Parent $OutPath
if ($od -and -not (Test-Path -LiteralPath $od)) { New-Item -ItemType Directory -Force -Path $od | Out-Null }
$body | Set-Content -LiteralPath $OutPath -Encoding utf8
Write-Host $body

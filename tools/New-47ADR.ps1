# Creates a new ADR from the template
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Title
)

$packRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$adrDir = Join-Path $packRoot 'docs\adr'
New-Item -ItemType Directory -Force -Path $adrDir | Out-Null

$existing = Get-ChildItem -LiteralPath $adrDir -Filter '*.md' | Where-Object { $_.Name -match '^\d{4}-' } | Sort-Object Name
$next = if ($existing.Count -gt 0) { [int]($existing[-1].Name.Substring(0,4)) + 1 } else { 1 }
$number = $next.ToString('0000')

$slug = ($Title.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-')
$file = Join-Path $adrDir ("$number-$slug.md")

$template = Get-Content -LiteralPath (Join-Path $adrDir '0000-template.md') -Raw
$today = (Get-Date).ToString('yyyy-MM-dd')
$template = $template -replace '\{\{NUMBER\}\}', $number
$template = $template -replace '\{\{DATE\}\}', $today
$template = $template -replace '\{\{TITLE\}\}', $Title

$template | Set-Content -LiteralPath $file -Encoding UTF8
Write-Host "Created ADR: $file"


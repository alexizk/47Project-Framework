# Bump-47Version.ps1
# Updates a single source of truth version file, and (best-effort) propagates it to known places.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)][string]$NewVersion,
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$verPath = Join-Path $PackRoot 'Framework\version.json'
$ver = [pscustomobject]@{
  version = $NewVersion
  updatedAt = (Get-Date).ToString('o')
}
$ver | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $verPath -Encoding UTF8
Write-Host "Wrote version file: $verPath"

# Best-effort update README badge line if present
$readme = Join-Path $PackRoot 'README.md'
if (Test-Path -LiteralPath $readme) {
  $t = Get-Content -Raw -LiteralPath $readme
  $t2 = $t -replace '(Framework Version:\s*)\S+','$1' + $NewVersion
  if ($t2 -ne $t) { Set-Content -LiteralPath $readme -Value $t2 -Encoding UTF8; Write-Host "Updated README.md version line." }
}

Write-Host "Done."

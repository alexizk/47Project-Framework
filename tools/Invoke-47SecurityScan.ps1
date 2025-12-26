# Invoke-47SecurityScan.ps1
# Lightweight repo scan (no external scanners required).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$FailOnFindings
)

$patterns = @(
  'AKIA[0-9A-Z]{16}',                 # AWS access key
  '-----BEGIN (RSA|EC|DSA) PRIVATE KEY-----',
  '-----BEGIN PRIVATE KEY-----',
  'xox[baprs]-[0-9A-Za-z-]{10,48}',   # Slack tokens
  'ghp_[0-9A-Za-z]{30,}',             # GitHub PAT (classic-like)
  'sk-[A-Za-z0-9]{20,}'               # generic secret prefix (OpenAI/Stripe-like)
)

$exclude = @('\.git\\', '\\docs_offline\\', '\\artifacts\\manifest\.json$')

function Is-Excluded([string]$path) {
  foreach ($e in $exclude) { if ($path -match $e) { return $true } }
  return $false
}

$findings = New-Object System.Collections.Generic.List[object]

Get-ChildItem -Path $Root -Recurse -File | ForEach-Object {
  $p = $_.FullName
  if (Is-Excluded $p) { return }
  # skip huge binaries
  if ($_.Length -gt 5MB) { return }
  $content = $null
  try { $content = Get-Content -Raw -LiteralPath $p -ErrorAction Stop } catch { return }
  foreach ($pat in $patterns) {
    if ($content -match $pat) {
      $findings.Add([pscustomobject]@{ file = $p; pattern = $pat })
    }
  }
}

if ($findings.Count -eq 0) {
  Write-Host "Security scan: OK (no findings)."
  exit 0
}

Write-Warning ("Security scan: {0} potential secret finding(s)" -f $findings.Count)
$findings | Select-Object -First 50 | ForEach-Object {
  Write-Warning (" - {0}" -f $_.file)
}

if ($FailOnFindings) { exit 9 } else { exit 0 }

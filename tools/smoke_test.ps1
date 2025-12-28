
<#
.SYNOPSIS
  Runs a basic offline smoke test for 47Project Framework.
.DESCRIPTION
  Checks pwsh availability, key file presence, script parseability, data folder writability,
  and verifies dist_manifest.json (if present).
.PARAMETER Root
  Root folder of the pack (default: inferred).
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ok($m){ Write-Host ("[OK] " + $m) -ForegroundColor Green }
function Warn($m){ Write-Host ("[WARN] " + $m) -ForegroundColor Yellow }
function Fail($m){ Write-Host ("[FAIL] " + $m) -ForegroundColor Red }

# Resolve root
if (-not (Test-Path -LiteralPath (Join-Path $Root 'Framework\47Project.Framework.ps1'))) {
  # maybe invoked from tools/
  $Root = Split-Path -Parent $Root
}

$failed = $false

try { $null = Get-Command pwsh -ErrorAction Stop; Ok "pwsh found" } catch { Fail "pwsh not found"; $failed = $true }

$must = @(
  'Framework\47Project.Framework.ps1',
  'README.md',
  'version.json',
  'dist_manifest.json'
)
foreach ($m in $must) {
  $p = Join-Path $Root $m
  if (Test-Path -LiteralPath $p) { Ok ("exists: " + $m) } else { Warn ("missing: " + $m) }
}

# Parseability (no execution)
$parse = @(
  'Framework\47Project.Framework.ps1',
  '47Project.Framework.GUI.v13.ps1',
  '47Project.Framework.Launch.ps1'
)
foreach ($f in $parse) {
  $p = Join-Path $Root $f
  if (-not (Test-Path -LiteralPath $p)) { Warn ("skip parse missing: " + $f); continue }
  try {
    [System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$null) | Out-Null
    Ok ("parses: " + $f)
  } catch {
    Fail ("parse error: " + $f)
    $failed = $true
  }
}

# Data folder writability
try {
  $data = Join-Path $Root 'data'
  if (-not (Test-Path -LiteralPath $data)) { New-Item -ItemType Directory -Path $data -Force | Out-Null }
  $t = Join-Path $data ('_write_test_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.tmp')
  'ok' | Set-Content -LiteralPath $t -Encoding utf8
  Remove-Item -LiteralPath $t -Force
  Ok "data/ writable"
} catch {
  Fail "data/ not writable"
  $failed = $true
}

# Manifest verify (optional)
$verify = Join-Path $Root 'tools\verify_manifest.ps1'
if (Test-Path -LiteralPath $verify) {
  try {
    & $verify -Root $Root
    Ok "manifest verification OK"
  } catch {
    Fail "manifest verification FAILED"
    $failed = $true
  }
} else {
  Warn "verify_manifest.ps1 not found - skipped"
}

if ($failed) {
  Fail "Smoke test finished with failures."
  exit 1
}

Ok "Smoke test PASSED."

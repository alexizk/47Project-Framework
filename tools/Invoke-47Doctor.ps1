# Invoke-47Doctor.ps1
# Basic environment self-test for 47Project Framework.

[CmdletBinding()]
param(
  [switch]$Fix,
  [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

function Add-Result([System.Collections.Generic.List[object]]$list, [string]$name, [bool]$ok, [string]$details) {
  $list.Add([pscustomobject]@{
    name    = $name
    ok      = $ok
    details = $details
  }) | Out-Null
}

$results = New-Object 'System.Collections.Generic.List[object]'

try {
  $psv = $PSVersionTable.PSVersion.ToString()
  Add-Result $results 'PowerShell' $true "PowerShell $psv"
} catch {
  Add-Result $results 'PowerShell' $false $_.Exception.Message
}

try {
  $paths = Get-47Paths
  Add-Result $results 'Paths' $true ("PackRoot=" + $paths.PackRoot)
} catch {
  Add-Result $results 'Paths' $false $_.Exception.Message
}

foreach ($p in @('LocalAppDataRoot','LogsRootUser','SnapshotsRootUser','StagingRootUser')) {
  try {
    $dir = $paths.$p
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = Join-Path $dir ("doctor-" + [guid]::NewGuid().ToString('N') + ".tmp")
    "ok" | Set-Content -LiteralPath $tmp -Encoding UTF8
    Remove-Item -LiteralPath $tmp -Force
    Add-Result $results "WriteAccess:$p" $true $dir
  } catch {
    Add-Result $results "WriteAccess:$p" $false $_.Exception.Message
  }
}

try {
  $mods = Get-47Modules
  Add-Result $results 'ModuleDiscovery' $true ("Found " + $mods.Count + " module(s)")
} catch {
  Add-Result $results 'ModuleDiscovery' $false $_.Exception.Message
}

try {
  $policy = Get-47EffectivePolicy
  Add-Result $results 'Policy' $true ("allowUnsafe=" + $policy.allowUnsafe)
} catch {
  Add-Result $results 'Policy' $false $_.Exception.Message
}

try {
  $schemas = @(
    (Join-Path $paths.SchemasRoot 'module_manifest_v1.schema.json'),
    (Join-Path $paths.SchemasRoot 'plan_v1.schema.json'),
    (Join-Path $paths.SchemasRoot 'policy_v1.schema.json'),
    (Join-Path $paths.SchemasRoot 'bundle_v1.schema.json')
  )
  $missing = @($schemas | Where-Object { -not (Test-Path -LiteralPath $_) })
  Add-Result $results 'SchemasPresent' ($missing.Count -eq 0) (if ($missing.Count -eq 0) { "OK" } else { "Missing: " + ($missing -join ', ') })
} catch {
  Add-Result $results 'SchemasPresent' $false $_.Exception.Message
}

$failed = @($results | Where-Object { -not $_.ok }).Count
Write-Host ""
Write-Host "47 Doctor Results"
Write-Host "-----------------"
$results | Format-Table -AutoSize

# Fix plan (best-effort)
$fixes = @()
function Add-Fix([string]$id,[string]$title,[string]$cmd,[string]$notes) {
  $script:fixes += [pscustomobject]@{ id=$id; title=$title; command=$cmd; notes=$notes }
}

try {
  if ($IsLinux -or $IsMacOS) {
    $inst = Join-Path $here 'install_dependencies.sh'
    if (Test-Path -LiteralPath $inst) {
      Add-Fix 'deps' 'Install dependencies (pwsh/docker)' ("bash " + $inst) 'Runs the helper installer.'
    }
  }
} catch { }

try {
  Add-Fix 'pester' 'Cache Pester into tools/.vendor' 'pwsh -File tools/install_pester.ps1' 'Ensures offline test runs.'
} catch { }

$report = [pscustomobject]@{
  timestamp = (Get-Date).ToString('o')
  results = $results
  fixPlan = $fixes
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  try {
    $paths = Get-47Paths
    $OutPath = Join-Path $paths.LogsRootUser ('doctor_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.json')
  } catch { }
}

try {
  ($report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $OutPath -Encoding utf8
  Write-Host ('Doctor report: ' + $OutPath)
  try { Set-47StateRecord -Name 'last_doctor' -Value $report | Out-Null } catch { }
} catch { }

if ($Fix) {
  Write-Host ""
  Write-Host "Suggested fixes:"
  foreach ($f in $fixes) { Write-Host ('- ' + $f.title + ': ' + $f.command) }
  Write-Host "Auto-fix execution is intentionally conservative; run commands above manually."
}

if ($failed -gt 0) {
  Write-Warning "$failed check(s) failed."
  exit 1
}

Write-Host "All checks passed."
exit 0

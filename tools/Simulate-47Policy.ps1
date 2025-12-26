# Simulate-47Policy.ps1
# Shows which plan steps would be allowed/blocked by policy.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)][string]$PlanPath,
  [string]$PolicyPath,
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Import-Module -Force (Join-Path $PackRoot 'Framework\Core\47.Core.psd1')

$plan = Read-47Json -Path $PlanPath
$policy = Get-47EffectivePolicy -PolicyPath $PolicyPath

function Normalize-Risk([string]$r) {
  if (-not $r) { return 'safe' }
  switch ($r.ToLowerInvariant()) {
    'safe' { 'safe' }
    'caution' { 'unsafe_requires_explicit_policy' }
    'unsafe' { 'unsafe_requires_admin' }
    default { $r.ToLowerInvariant() }
  }
}

Write-Host "Plan: $PlanPath"
Write-Host "Module: $($plan.moduleId)  Action: $($plan.action)"
Write-Host ""

$steps = $plan.steps
if (-not $steps) { Write-Warning "No steps found in plan."; exit 0 }

$blocked = 0
foreach ($s in $steps) {
  $riskNorm = Normalize-Risk $s.risk
  $ok = Test-47RiskAllowed -Risk $riskNorm -Policy $policy
  $status = if ($ok) { 'ALLOW' } else { $blocked++; 'BLOCK' }
  $sid = $s.stepId
  $type = $s.type
  Write-Host ("[{0}] {1} ({2}) risk={3}" -f $status, $sid, $type, $s.risk)
}

Write-Host ""
Write-Host ("Blocked steps: {0} / {1}" -f $blocked, $steps.Count)
if ($blocked -gt 0) { exit 3 } else { exit 0 }

# Diff-47Plan.ps1
# Basic diff between two plan files (targets + steps).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)][string]$PlanA,
  [Parameter(Mandatory)][string]$PlanB,
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Import-Module -Force (Join-Path $PackRoot 'Framework\Core\47.Core.psd1')

$a = Read-47Json -Path $PlanA
$b = Read-47Json -Path $PlanB

Write-Host "Plan A: $PlanA"
Write-Host "Plan B: $PlanB"
Write-Host ""

function KeyTargets($p) {
  if (-not $p.targets) { return @() }
  return $p.targets | ForEach-Object { "$($_.provider):$($_.id)" } | Sort-Object -Unique
}
function KeySteps($p) {
  if (-not $p.steps) { return @() }
  return $p.steps | ForEach-Object { "$($_.type):$($_.stepId)" } | Sort-Object -Unique
}

$ta = KeyTargets $a
$tb = KeyTargets $b
$sa = KeySteps $a
$sb = KeySteps $b

$addedTargets = Compare-Object -ReferenceObject $ta -DifferenceObject $tb | Where-Object SideIndicator -eq '=>' | Select-Object -ExpandProperty InputObject
$removedTargets= Compare-Object -ReferenceObject $ta -DifferenceObject $tb | Where-Object SideIndicator -eq '<=' | Select-Object -ExpandProperty InputObject

$addedSteps = Compare-Object -ReferenceObject $sa -DifferenceObject $sb | Where-Object SideIndicator -eq '=>' | Select-Object -ExpandProperty InputObject
$removedSteps= Compare-Object -ReferenceObject $sa -DifferenceObject $sb | Where-Object SideIndicator -eq '<=' | Select-Object -ExpandProperty InputObject

Write-Host "Targets:"
Write-Host "  Added:"; $addedTargets | ForEach-Object { Write-Host "    + $_" }
Write-Host "  Removed:"; $removedTargets | ForEach-Object { Write-Host "    - $_" }

Write-Host ""
Write-Host "Steps:"
Write-Host "  Added:"; $addedSteps | ForEach-Object { Write-Host "    + $_" }
Write-Host "  Removed:"; $removedSteps | ForEach-Object { Write-Host "    - $_" }

exit 0

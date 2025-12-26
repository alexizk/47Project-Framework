\
# Runs a plan using the 47 Plan Runner
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PlanPath,
  [ValidateSet('WhatIf','Apply')][string]$Mode = 'WhatIf',
  [string]$PolicyPath,
  [switch]$NoSnapshot,
  [switch]$ContinueOnError,
  [string]$RunId,
  [switch]$Resume,
  [switch]$RetryFailedOnly
)

$packRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
Import-Module (Join-Path $packRoot 'Framework\Core\PlanRunner\47.PlanRunner.psm1') -Force | Out-Null

$res = Invoke-47PlanRun `
  -PlanPath $PlanPath `
  -Mode $Mode `
  -PolicyPath $PolicyPath `
  -NoSnapshot:$NoSnapshot `
  -ContinueOnError:$ContinueOnError `
  -RunId $RunId `
  -Resume:$Resume `
  -RetryFailedOnly:$RetryFailedOnly

$res | ConvertTo-Json -Depth 50

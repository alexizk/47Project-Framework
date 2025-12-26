# Resume a plan run from an existing runId using the journal
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PlanPath,
  [Parameter(Mandatory)][string]$RunId,
  [ValidateSet('WhatIf','Apply')][string]$Mode = 'Apply',
  [string]$PolicyPath,
  [switch]$NoSnapshot,
  [switch]$ContinueOnError,
  [switch]$RetryFailedOnly
)

$packRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null

Invoke-47PlanRun -PlanPath $PlanPath -Mode $Mode -PolicyPath $PolicyPath -NoSnapshot:$NoSnapshot -ContinueOnError:$ContinueOnError -RunId $RunId -Resume -RetryFailedOnly:$RetryFailedOnly

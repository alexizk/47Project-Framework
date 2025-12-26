<#
.SYNOPSIS
  Convenience script: validate shipped examples and modules, then (optionally) build a sample .47bundle.
#>
[CmdletBinding()]
param(
  [switch]$BuildSampleBundle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'Validate-47Plan.ps1') -Path (Join-Path $packRoot 'examples\plans\sample_install.plan.json')
Get-ChildItem -Directory -LiteralPath (Join-Path $packRoot 'modules') | ForEach-Object {
  & (Join-Path $PSScriptRoot 'Validate-47Module.ps1') -Path $_.FullName
}

if ($BuildSampleBundle) {
  & (Join-Path $PSScriptRoot 'Build-47Bundle.ps1') `
    -PlanPath (Join-Path $packRoot 'examples\plans\sample_install.plan.json') `
    -PayloadDir (Join-Path $packRoot 'examples\bundles\sample_payload') `
    -OutBundlePath (Join-Path $packRoot 'examples\bundles\sample.47bundle')
}
Write-Host "All checks passed."


# Optional smoke check
# & (Join-Path $PSScriptRoot 'Invoke-47Doctor.ps1')

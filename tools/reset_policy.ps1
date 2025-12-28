<#
.SYNOPSIS
  Resets user policy to defaults (deletes user policy file).

.EXAMPLE
  pwsh -File tools/reset_policy.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

$paths = Get-47Paths
$p = $paths.PolicyUserPath

if (Test-Path -LiteralPath $p) {
  if ($PSCmdlet.ShouldProcess($p, 'Remove user policy')) {
    Remove-Item -Force -LiteralPath $p
  }
  Write-Host "Removed: $p"
} else {
  Write-Host "No user policy found: $p"
}

Write-Host "Effective policy will fall back to defaults."

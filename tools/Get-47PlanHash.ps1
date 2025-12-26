<#
.SYNOPSIS
  Compute the SHA-256 hash of a plan after canonicalization.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PlanPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

Get-47PlanHash -PlanPath $PlanPath

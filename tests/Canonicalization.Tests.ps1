#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$packRoot = Resolve-Path (Join-Path $here '..') | Select-Object -ExpandProperty Path
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

Describe 'Canonicalization' {
  It 'Plan hash is stable across reads' {
    $plan = Join-Path $packRoot 'examples\plans\sample_install.plan.json'
    $h1 = Get-47PlanHash -PlanPath $plan
    $h2 = Get-47PlanHash -PlanPath $plan
    $h1 | Should -Be $h2
  }
}

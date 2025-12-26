# Pester integration tests: module.call executor
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner - module.call executor" {

  It "Applies sample module.call plan and returns a result object" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47mc_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $packRoot = Split-Path -Parent $PSScriptRoot
      $srcPlan = Join-Path $packRoot 'examples\plans\sample_modulecall.plan.json'
      $planPath = Join-Path $tmp 'sample_modulecall.plan.json'
      Copy-Item -LiteralPath $srcPlan -Destination $planPath -Force

      $res = Invoke-47PlanRun -PlanPath $planPath -Mode Apply -NoSnapshot -ContinueOnError
      $step = $res.results | Where-Object { $_.stepId -eq 'systeminfo_summary' } | Select-Object -First 1
      $step.status | Should -Be 'ok'
      $step.moduleId | Should -Be 'mod.systeminfo'
      $null -ne $step.result | Should -BeTrue
    }
    finally {
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

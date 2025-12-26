# Pester integration tests: Plan Runner wiring + exec executor
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner" {

  It "Runs sample exec plan in WhatIf mode and produces results" {
    $planPath = Join-Path $packRoot 'examples\plans\sample_exec.plan.json'
    $res = Invoke-47PlanRun -PlanPath $planPath -Mode WhatIf
    $res.runId | Should -Not -BeNullOrEmpty
    $res.mode  | Should -Be 'WhatIf'
    ($res.results.Count) | Should -BeGreaterThan 0
    ($res.results | Where-Object { $_.type -eq 'exec' }).Count | Should -BeGreaterThan 0
  }

  It "Applies sample exec plan in a temp folder and writes per-step output files" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47plan_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $srcPlan = Join-Path $packRoot 'examples\plans\sample_exec.plan.json'
      $planPath = Join-Path $tmp 'sample_exec.plan.json'
      Copy-Item -LiteralPath $srcPlan -Destination $planPath -Force

      $res = Invoke-47PlanRun -PlanPath $planPath -Mode Apply
      $res.runId | Should -Not -BeNullOrEmpty

      # marker should exist (created by step 'create-marker')
      (Test-Path -LiteralPath (Join-Path $tmp 'marker.txt')) | Should -BeTrue

      # run folder should exist
      $paths = Get-47Paths
      $runRoot = Join-Path (Join-Path $paths.LogsRoot 'runs') $res.runId
      (Test-Path -LiteralPath $runRoot) | Should -BeTrue

      # at least one step folder should contain stdout/stderr files
      $stepsRoot = Join-Path $runRoot 'steps'
      (Test-Path -LiteralPath $stepsRoot) | Should -BeTrue
      $stdoutFiles = Get-ChildItem -LiteralPath $stepsRoot -Recurse -Filter 'stdout.txt' -ErrorAction SilentlyContinue
      $stderrFiles = Get-ChildItem -LiteralPath $stepsRoot -Recurse -Filter 'stderr.txt' -ErrorAction SilentlyContinue
      $stdoutFiles.Count | Should -BeGreaterThan 0
      $stderrFiles.Count | Should -BeGreaterThan 0
    }
    finally {
      Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

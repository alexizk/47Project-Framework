# Pester integration tests: resume + retryFailedOnly
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner - resume" {

  It "Skips previously ok steps when resuming (retry failed only)" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47rs_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $plan = @{
        schemaVersion = '1.0.0'
        id='plan.test.resume'
        displayName='Resume Test Plan'
        risk='safe'
        steps=@(
          @{
            type='exec'
            stepId='ok_step'
            exec=@{ file='pwsh'; args=@('-NoProfile','-Command','"ok" | Out-File -LiteralPath ok.txt -Encoding UTF8') }
          },
          @{
            type='exec'
            stepId='fail_step'
            exec=@{ file='pwsh'; args=@('-NoProfile','-Command','exit 1') }
          }
        )
      } | ConvertTo-Json -Depth 50

      $planPath = Join-Path $tmp 'resume.plan.json'
      $plan | Set-Content -LiteralPath $planPath -Encoding UTF8

      # First run: expect error
      $res1 = Invoke-47PlanRun -PlanPath $planPath -Mode Apply -NoSnapshot -ContinueOnError
      $res1.runId | Should -Not -BeNullOrEmpty

      $runId = $res1.runId

      # Resume: retry failed only => ok_step should be skipped
      $res2 = Invoke-47PlanRun -PlanPath $planPath -Mode Apply -NoSnapshot -ContinueOnError -RunId $runId -Resume -RetryFailedOnly
      ($res2.results | Where-Object { $_.stepId -eq 'ok_step' } | Select-Object -First 1).status | Should -Be 'skip'
      ($res2.results | Where-Object { $_.stepId -eq 'fail_step' } | Select-Object -First 1).status | Should -Be 'error'
    }
    finally {
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

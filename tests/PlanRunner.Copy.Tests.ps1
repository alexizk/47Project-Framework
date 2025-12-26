# Pester integration tests: copy executor
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner - copy executor" {

  It "Applies sample copy plan and writes destination file" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47cp_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $packRoot = Split-Path -Parent $PSScriptRoot
      $srcPlan = Join-Path $packRoot 'examples\plans\sample_copy.plan.json'
      $srcPayload = Join-Path $packRoot 'examples\plans\payload_source.txt'

      $planPath = Join-Path $tmp 'sample_copy.plan.json'
      Copy-Item -LiteralPath $srcPlan -Destination $planPath -Force
      Copy-Item -LiteralPath $srcPayload -Destination (Join-Path $tmp 'payload_source.txt') -Force

      $res = Invoke-47PlanRun -PlanPath $planPath -Mode Apply -NoSnapshot -ContinueOnError
      $dest = Join-Path $tmp 'runs_output\copied_payload.txt'
      (Test-Path -LiteralPath $dest) | Should -BeTrue
      $content = Get-Content -Raw -LiteralPath $dest
      $content.Length | Should -BeGreaterThan 0
      ($res.results | Where-Object { $_.stepId -eq 'copy_payload' }).status | Should -Be 'ok'
    }
    finally {
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

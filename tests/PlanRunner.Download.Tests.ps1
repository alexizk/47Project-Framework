# Pester integration tests: download executor
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner - download executor" {

  It "Applies sample download plan (local path) and writes destination file" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47dl_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $srcPlan = Join-Path $packRoot 'examples\plans\sample_download.plan.json'
      $srcPayload = Join-Path $packRoot 'examples\plans\payload_source.txt'

      $planPath = Join-Path $tmp 'sample_download.plan.json'
      Copy-Item -LiteralPath $srcPlan -Destination $planPath -Force
      Copy-Item -LiteralPath $srcPayload -Destination (Join-Path $tmp 'payload_source.txt') -Force

      $res = Invoke-47PlanRun -PlanPath $planPath -Mode Apply
      $res.runId | Should -Not -BeNullOrEmpty

      (Test-Path -LiteralPath (Join-Path $tmp 'downloaded_payload.txt')) | Should -BeTrue
    }
    finally {
      Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It "Runs sample download plan in WhatIf mode" {
    $planPath = Join-Path $packRoot 'examples\plans\sample_download.plan.json'
    $res = Invoke-47PlanRun -PlanPath $planPath -Mode WhatIf
    ($res.results | Where-Object { $_.type -eq 'download' }).Count | Should -BeGreaterThan 0
  }
}

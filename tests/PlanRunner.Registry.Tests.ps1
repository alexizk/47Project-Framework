# Pester integration tests: registry executor (Windows only)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "47 Plan Runner - registry executor" {

  It "Applies a simple HKCU registry plan and cleans up" -Skip:(!$IsWindows) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47rg_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      $packRoot = Split-Path -Parent $PSScriptRoot
      $policy = Join-Path $packRoot 'examples\policies\unsafe_all.policy.json'

      $keyPath = "Software\\47Project\\Tests\\" + ([Guid]::NewGuid().ToString('N'))
      $planObj = @{
        schemaVersion='1.0.0'
        id='plan.test.registry'
        displayName='Registry Test Plan'
        risk='unsafe_requires_explicit_policy'
        steps=@(
          @{ type='registry'; stepId='ensure'; registry=@{ hive='HKCU'; path=$keyPath; action='ensureKey' } },
          @{ type='registry'; stepId='set'; registry=@{ hive='HKCU'; path=$keyPath; action='setValue'; name='Enabled'; valueType='DWord'; value=1 } },
          @{ type='registry'; stepId='remove'; registry=@{ hive='HKCU'; path=$keyPath; action='removeKey' } }
        )
      }

      $planPath = Join-Path $tmp 'registry.plan.json'
      ($planObj | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath $planPath -Encoding UTF8

      $res = Invoke-47PlanRun -PlanPath $planPath -Mode Apply -PolicyPath $policy -NoSnapshot -ContinueOnError
      ($res.results | Where-Object { $_.status -eq 'error' }).Count | Should -Be 0
    }
    finally {
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

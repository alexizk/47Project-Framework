\
# Validates all example plans (best effort)
Set-StrictMode -Version Latest

Describe "Example plans validate" {
  It "All example plans parse as JSON" {
    $plans = Get-ChildItem -LiteralPath "$PSScriptRoot\..\examples\plans" -Filter '*.json' -File -Recurse
    $plans.Count | Should -BeGreaterThan 0

    foreach ($p in $plans) {
      { Get-Content -Raw -LiteralPath $p.FullName | ConvertFrom-Json -ErrorAction Stop | Out-Null } | Should -Not -Throw
    }
  }

  It "All example plans validate schema when Test-Json exists" {
    $tj = Get-Command Test-Json -ErrorAction SilentlyContinue
    if (-not $tj) {
      Set-ItResult -Skipped -Because "Test-Json not available (PowerShell 7+ recommended for schema validation)."
      return
    }

    $schema = Join-Path $PSScriptRoot '..\schemas\plan_v1.schema.json'
    $plans = Get-ChildItem -LiteralPath "$PSScriptRoot\..\examples\plans" -Filter '*.json' -File -Recurse
    foreach ($p in $plans) {
      $json = Get-Content -Raw -LiteralPath $p.FullName
      (Test-Json -Json $json -SchemaFile $schema) | Should -BeTrue
    }
  }
}

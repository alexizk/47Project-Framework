#requires -Version 5.1
# Pester v5+
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$packRoot = Resolve-Path (Join-Path $here '..') | Select-Object -ExpandProperty Path

Describe '47Project Schemas' {
  It 'Module manifests validate' {
    $schema = Join-Path $packRoot 'schemas\module_manifest_v1.schema.json'
    Get-ChildItem -Directory -LiteralPath (Join-Path $packRoot 'modules') | ForEach-Object {
      $manifest = Join-Path $_.FullName 'module.json'
      (Test-Json -Json (Get-Content -Raw -LiteralPath $manifest) -SchemaFile $schema) | Should -BeTrue
    }
  }

  It 'Sample plans validate' {
    $schema = Join-Path $packRoot 'schemas\plan_v1.schema.json'
    $plans = @(
      Join-Path $packRoot 'examples\plans\sample_install.plan.json'
      Join-Path $packRoot 'examples\plans\sample_exec.plan.json'
      Join-Path $packRoot 'examples\plans\sample_download.plan.json'
      Join-Path $packRoot 'examples\plans\sample_copy.plan.json'
      Join-Path $packRoot 'examples\plans\sample_modulecall.plan.json'
      Join-Path $packRoot 'examples\plans\sample_registry.plan.json'
    )
    foreach ($plan in $plans) {
      (Test-Json -Json (Get-Content -Raw -LiteralPath $plan) -SchemaFile $schema) | Should -BeTrue
    }
  }

  It 'Policies validate' {
    $schema = Join-Path $packRoot 'schemas\policy_v1.schema.json'
    Get-ChildItem -File -LiteralPath (Join-Path $packRoot 'examples\policies') -Filter *.json | ForEach-Object {
      (Test-Json -Json (Get-Content -Raw -LiteralPath $_.FullName) -SchemaFile $schema) | Should -BeTrue
    }
  }
}


Describe 'Repository index schema validation' {
  It 'validates repositories/local/index.json' {
    $schema = Join-Path $PSScriptRoot '..\schemas\repo_index_v1.schema.json'
    $file = Join-Path $PSScriptRoot '..\repositories\local\index.json'
    $ok = Test-Json -Json (Get-Content -Raw -LiteralPath $file) -SchemaFile $schema
    $ok | Should -BeTrue
  }
}

Describe 'Trust store schema validation' {
  It 'validates trust/publishers.json' {
    $schema = Join-Path $PSScriptRoot '..\schemas\trust_store_v1.schema.json'
    $file = Join-Path $PSScriptRoot '..\trust\publishers.json'
    (Test-Json -Json (Get-Content -Raw -LiteralPath $file) -SchemaFile $schema) | Should -BeTrue
  }
}

Describe 'Repository channel indexes' {
  It 'validate channel index files' {
    $schema = Join-Path $PSScriptRoot '..\schemas\repo_index_v1.schema.json'
    Get-ChildItem -File -LiteralPath (Join-Path $PSScriptRoot '..\repositories\local\channels') -Recurse -Filter index.json | ForEach-Object {
      (Test-Json -Json (Get-Content -Raw -LiteralPath $_.FullName) -SchemaFile $schema) | Should -BeTrue
    }
  }
}

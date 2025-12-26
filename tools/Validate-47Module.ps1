<#
.SYNOPSIS
  Validate a module.json against the shipped JSON Schema.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
$schema = Join-Path $packRoot 'schemas\module_manifest_v1.schema.json'

$manifestPath = $Path
if (Test-Path -LiteralPath $Path -PathType Container) {
  $manifestPath = Join-Path $Path 'module.json'
}

if (-not (Test-Path -LiteralPath $manifestPath)) { throw "module.json not found: $manifestPath" }
if (-not (Test-Path -LiteralPath $schema)) { throw "Schema not found: $schema" }

$ok = Test-Json -Json (Get-Content -Raw -LiteralPath $manifestPath) -SchemaFile $schema
if (-not $ok) { throw "Module manifest failed schema validation: $manifestPath" }
Write-Host "OK: $manifestPath"

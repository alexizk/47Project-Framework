\
<#
.SYNOPSIS
  Validate a plan file against the shipped JSON Schema (best effort).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$PlanPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
$schema = Join-Path $packRoot 'schemas\plan_v1.schema.json'
if (-not (Test-Path -LiteralPath $schema)) { throw "Schema not found: $schema" }
if (-not (Test-Path -LiteralPath $PlanPath)) { throw "Plan not found: $PlanPath" }

$jsonText = Get-Content -Raw -LiteralPath $PlanPath

# Always ensure JSON parses
$null = $jsonText | ConvertFrom-Json -ErrorAction Stop

$cmd = Get-Command Test-Json -ErrorAction SilentlyContinue
if ($cmd) {
  $ok = Test-Json -Json $jsonText -SchemaFile $schema
  if (-not $ok) { throw "Plan failed schema validation: $PlanPath" }
  Write-Host "OK (schema): $PlanPath"
} else {
  Write-Warning "Test-Json not available. Only verified JSON parses. For full schema validation, use PowerShell 7+."
  Write-Host "OK (parse-only): $PlanPath"
}

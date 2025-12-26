<#
.SYNOPSIS
  Verify a .47bundle file structure and manifest schema.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$BundlePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$packRoot = Split-Path -Parent $PSScriptRoot
$schema = Join-Path $packRoot 'schemas\bundle_v1.schema.json'
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("47bundle-verify-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null

Expand-47ZipSafe -ZipPath $BundlePath -DestinationPath $temp

$manifestPath = Join-Path $temp 'manifest.json'
$planPath = Join-Path $temp 'plan.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "manifest.json missing" }
if (-not (Test-Path -LiteralPath $planPath)) { throw "plan.json missing" }

$ok = Test-Json -Json (Get-Content -Raw -LiteralPath $manifestPath) -SchemaFile $schema
if (-not $ok) { throw "Manifest schema validation failed" }

$manifest = Read-47Json -Path $manifestPath
$planHash = Get-47PlanHash -PlanPath $planPath
if ($manifest.planHash -ne $planHash) { throw "Plan hash mismatch. Manifest=$($manifest.planHash) Actual=$planHash" }

Write-Host "OK: Bundle verified"
Remove-Item -Recurse -Force -LiteralPath $temp

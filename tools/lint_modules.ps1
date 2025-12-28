<#
.SYNOPSIS
  Lint module manifests (module.json) for schema-ish correctness.

.EXAMPLE
  pwsh -File tools/lint_modules.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Force (Join-Path $root 'Framework/Core/47.Core.psd1')

$errs = @()
$warn = @()

function Err([string]$m) { $script:errs += $m }
function Warn([string]$m) { $script:warn += $m }

$mods = @(Get-47Modules)
if ($mods.Count -eq 0) {
  Write-Host "No modules found."
  exit 0
}

$allowedRisk = @('safe','caution','unsafe')
$allowedType = @('pwsh-module','pwsh-script','python','node','go','exe')

foreach ($m in $mods) {
  $id = $m.ModuleId
  $path = $m.Path
  $mj = Join-Path $path 'module.json'
  if (-not (Test-Path -LiteralPath $mj)) { Err "$id: missing module.json"; continue }
  $o = $null
  try { $o = Get-Content -Raw -LiteralPath $mj | ConvertFrom-Json } catch { Err "$id: module.json invalid JSON"; continue }

  try { if ([string]::IsNullOrWhiteSpace([string]$o.moduleId)) { Err "$id: moduleId missing/empty" } } catch { Err "$id: moduleId missing" }
  try { if ([string]::IsNullOrWhiteSpace([string]$o.name)) { Err "$id: name missing/empty" } } catch { Err "$id: name missing" }
  try { if ([string]::IsNullOrWhiteSpace([string]$o.version)) { Err "$id: version missing/empty" } } catch { Err "$id: version missing" }

  $risk = ''
  try { $risk = ([string]$o.risk).ToLowerInvariant() } catch { }
  if ($risk -and ($allowedRisk -notcontains $risk)) { Warn "$id: risk '$risk' not in {safe,caution,unsafe}" }

  $rt = ''
  try { $rt = ([string]$o.run.type).ToLowerInvariant() } catch { }
  if ($rt -and ($allowedType -notcontains $rt)) { Err "$id: run.type '$rt' unsupported" }

  try {
    $caps = @($o.capabilities)
    if ($caps.Count -eq 0) { Warn "$id: capabilities empty (recommended to declare)" }
  } catch { Warn "$id: capabilities missing" }

  try {
    $plats = @($o.supportedPlatforms)
    if ($plats.Count -eq 0) { Warn "$id: supportedPlatforms empty" }
  } catch { Warn "$id: supportedPlatforms missing" }
}

if ($warn.Count) {
  Write-Host ""
  Write-Host "Warnings:"
  $warn | ForEach-Object { Write-Host ("- " + $_) }
}

if ($errs.Count) {
  Write-Host ""
  Write-Host "Errors:"
  $errs | ForEach-Object { Write-Host ("- " + $_) }
  exit 1
}

Write-Host "OK"

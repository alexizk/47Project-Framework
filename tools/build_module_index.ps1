<#
.SYNOPSIS
  Builds modules/index.json (local module registry).

.EXAMPLE
  pwsh -File tools/build_module_index.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

$paths = Get-47Paths
$outDir = Join-Path $paths.PackRoot 'modules'
$outPath = Join-Path $outDir 'index.json'

$mods = @()
foreach ($m in @(Get-47Modules)) {
  $mods += [pscustomobject]@{
    moduleId = $m.ModuleId
    name = $m.Name
    version = $m.Version
    publisher = $m.Publisher
    risk = $m.Risk
    runType = $m.RunType
    capabilities = @($m.Capabilities)
  }
}

$idx = [pscustomobject]@{
  schemaVersion = 1
  generatedAt = (Get-Date).ToString('o')
  modules = $mods
}

($idx | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $outPath -Encoding utf8
Write-Host ("Wrote: " + $outPath)

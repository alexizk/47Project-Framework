<#
.SYNOPSIS
  Export a diagnostics support bundle (zip) with logs, policy, and module manifests.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$paths = Get-47Paths
if (-not $OutPath) {
  $OutPath = Join-Path $paths.LocalAppDataRoot ("SupportBundle-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".zip")
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("47support-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null

# Logs
foreach ($src in @($paths.LogsRootUser, $paths.LogsRootMachine)) {
  if (Test-Path -LiteralPath $src) {
    $dst = Join-Path $temp ("logs-" + (Split-Path -Leaf $src))
    Copy-Item -Recurse -Force -LiteralPath $src -Destination $dst
  }
}

# Policy
foreach ($p in @($paths.PolicyMachinePath, $paths.PolicyUserPath)) {
  if (Test-Path -LiteralPath $p) {
    Copy-Item -Force -LiteralPath $p -Destination (Join-Path $temp (Split-Path -Leaf $p))
  }
}

# Module manifests
$modsDir = Join-Path $temp 'modules'
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
Get-47Modules | ForEach-Object {
  $dst = Join-Path $modsDir ($_.ModuleId + ".module.json")
  Copy-Item -Force -LiteralPath $_.ManifestPath -Destination $dst
}

# Environment snapshot
$envObj = [pscustomobject]@{
  createdUtc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  os = [System.Environment]::OSVersion.VersionString
  psVersion = $PSVersionTable.PSVersion.ToString()
  machine = $env:COMPUTERNAME
  user = $env:USERNAME
}
$envJson = ConvertTo-47CanonicalJson -InputObject $envObj
[System.IO.File]::WriteAllText((Join-Path $temp 'env.json'), $envJson, [System.Text.Encoding]::UTF8)

if ($PSCmdlet.ShouldProcess($OutPath, 'Create support bundle')) {
  if (Test-Path -LiteralPath $OutPath) { Remove-Item -Force -LiteralPath $OutPath }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $OutPath)
  Write-Host "Wrote support bundle: $OutPath"
}

Remove-Item -Recurse -Force -LiteralPath $temp

<#
.SYNOPSIS
  Build a .47bundle (zip) containing a manifest, a plan, and optional payload files.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$PlanPath,
  [string]$PayloadDir,
  [Parameter(Mandatory)][string]$OutBundlePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$planHash = Get-47PlanHash -PlanPath $PlanPath
$bundleId = "bundle-" + $planHash.Substring(0,12)

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("47bundle-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null

Copy-Item -LiteralPath $PlanPath -Destination (Join-Path $temp 'plan.json') -Force

$payloadList = @()
if ($PayloadDir) {
  if (-not (Test-Path -LiteralPath $PayloadDir)) { throw "PayloadDir not found: $PayloadDir" }
  $destPayload = Join-Path $temp 'payload'
  Copy-Item -Recurse -Force -LiteralPath $PayloadDir -Destination $destPayload
  Get-ChildItem -Recurse -File -LiteralPath $destPayload | ForEach-Object {
    $rel = $_.FullName.Substring($destPayload.Length+1).Replace('\','/')
    $payloadList += [pscustomobject]@{ path = "payload/$rel"; bytes = $_.Length }
  }
}

$manifest = [pscustomobject]@{
  schemaVersion = 1
  bundleId = $bundleId
  createdUtc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  planHash = $planHash
  payload = $payloadList
}

$manifestJson = ConvertTo-47CanonicalJson -InputObject $manifest
[System.IO.File]::WriteAllText((Join-Path $temp 'manifest.json'), $manifestJson, [System.Text.Encoding]::UTF8)

if ($PSCmdlet.ShouldProcess($OutBundlePath, 'Create bundle')) {
  if (Test-Path -LiteralPath $OutBundlePath) { Remove-Item -Force -LiteralPath $OutBundlePath }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $OutBundlePath)
  Write-Host "Built bundle: $OutBundlePath"
}

Remove-Item -Recurse -Force -LiteralPath $temp

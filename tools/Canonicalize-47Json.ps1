<#
.SYNOPSIS
  Canonicalize JSON according to 47Project rules (sorted object keys, stable JSON, UTF-8).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InFile,
  [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

$obj = Read-47Json -Path $InFile
$json = ConvertTo-47CanonicalJson -InputObject $obj

if ($OutFile) {
  [System.IO.File]::WriteAllText((Resolve-Path $OutFile), $json, [System.Text.Encoding]::UTF8)
  Write-Host "Wrote canonical JSON: $OutFile"
} else {
  $json
}

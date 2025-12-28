<#
.SYNOPSIS
  Builds a portable distribution zip of the Framework pack.
.DESCRIPTION
  Copies the repository into dist/ and creates a timestamped .zip for distribution.
.PARAMETER OutDir
  Output directory for portable builds (default: dist/).
#>


<# 
Builds a portable distribution zip.
Copies the pack into dist/ with a timestamp and creates a zip.
#>

[CmdletBinding()]
param(
  [string]$OutDir = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\dist')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dst = Join-Path $OutDir ("47ProjectFramework_Portable_" + $stamp)

New-Item -ItemType Directory -Path $dst -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root '*') -Destination $dst -Recurse -Force

# remove dist inside itself if exists
$innerDist = Join-Path $dst 'dist'
if (Test-Path -LiteralPath $innerDist) { Remove-Item -LiteralPath $innerDist -Recurse -Force }

$zip = $dst + '.zip'
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $dst '*') -DestinationPath $zip -Force

Write-Host "Portable built:"
Write-Host " - Folder: $dst"
Write-Host " - Zip:    $zip"

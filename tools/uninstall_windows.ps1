<#
.SYNOPSIS
  Removes 47Project Framework shortcuts.
.DESCRIPTION
  Deletes Start Menu folder and Desktop shortcut created by install_windows.ps1.
.PARAMETER AllUsers
  Remove shortcuts from the all-users Start Menu location.
#>


<# Removes 47Project Framework shortcuts. #>
[CmdletBinding()]
param([switch]$AllUsers)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($AllUsers) {
  $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
} else {
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
}
$folder = Join-Path $startMenu '47Project Framework'
$desktop = [Environment]::GetFolderPath('Desktop')
$lnk2 = Join-Path $desktop '47Project Framework.lnk'

if (Test-Path -LiteralPath $folder) { Remove-Item -LiteralPath $folder -Recurse -Force }
if (Test-Path -LiteralPath $lnk2) { Remove-Item -LiteralPath $lnk2 -Force }

Write-Host "Shortcuts removed."

<#
.SYNOPSIS
  Installs Start Menu and Desktop shortcuts for 47Project Framework.
.DESCRIPTION
  Creates shortcuts that point to the one-click CMD runner. Optional icon supported via assets/theme/framework.ico.
.PARAMETER AllUsers
  Install shortcuts for all users (requires permissions).
#>


<# 
Installs shortcuts for 47Project Framework (portable style).
- Creates Desktop + Start Menu shortcuts
- Optional icon at assets\theme\framework.ico
#>

[CmdletBinding()]
param(
  [switch]$AllUsers
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Root {
  $here = Split-Path -Parent $MyInvocation.MyCommand.Path
  return (Split-Path -Parent $here)
}

$root = Get-Root
$target = Join-Path $root 'Run_47Project_Framework.cmd'
if (-not (Test-Path -LiteralPath $target)) { throw "Missing: $target" }

$icon = Join-Path $root 'assets\theme\framework.ico'
if (-not (Test-Path -LiteralPath $icon)) { $icon = $null }

if ($AllUsers) {
  $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
} else {
  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$folder = Join-Path $startMenu '47Project Framework'
New-Item -ItemType Directory -Path $folder -Force | Out-Null

function New-Shortcut([string]$Path,[string]$Target,[string]$WorkingDirectory,[string]$Arguments,[string]$IconLocation) {
  $wsh = New-Object -ComObject WScript.Shell
  $sc = $wsh.CreateShortcut($Path)
  $sc.TargetPath = $Target
  if ($WorkingDirectory) { $sc.WorkingDirectory = $WorkingDirectory }
  if ($Arguments) { $sc.Arguments = $Arguments }
  if ($IconLocation) { $sc.IconLocation = $IconLocation }
  $sc.Save()
}

$cmd = Join-Path $env:ComSpec 'cmd.exe'
$lnk1 = Join-Path $folder '47Project Framework.lnk'
New-Shortcut -Path $lnk1 -Target $cmd -WorkingDirectory $root -Arguments ("/c `"$target`"") -IconLocation $icon

$lnk2 = Join-Path $desktop '47Project Framework.lnk'
New-Shortcut -Path $lnk2 -Target $cmd -WorkingDirectory $root -Arguments ("/c `"$target`"") -IconLocation $icon

Write-Host "Installed shortcuts:"
Write-Host " - $lnk1"
Write-Host " - $lnk2"

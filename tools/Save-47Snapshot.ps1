Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Name = 'snapshot',
  [switch]$IncludePack,
  [switch]$IncludeMachine
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

$snap = Save-47Snapshot -Name $Name -IncludePack:$IncludePack -IncludeMachine:$IncludeMachine
Write-Host "Snapshot: $snap"

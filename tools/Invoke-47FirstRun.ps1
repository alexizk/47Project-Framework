Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

Invoke-47FirstRunWizard | Out-Null

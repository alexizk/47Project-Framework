# Invoke-47StyleCheck.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Path = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Import-Module PSScriptAnalyzer -ErrorAction Stop

$settings = Join-Path $Path 'style\PSScriptAnalyzerSettings.psd1'
if (-not (Test-Path -LiteralPath $settings)) { throw "Settings not found: $settings" }

Write-Host "Running PSScriptAnalyzer..."
$results = Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $settings
if (-not $results) {
  Write-Host "Style check: OK"
  exit 0
}

$results | Sort-Object RuleName, ScriptName, Line | Format-Table -AutoSize
Write-Error ("Style check failed: {0} issue(s)." -f $results.Count)
exit 2

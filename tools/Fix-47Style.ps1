# Fix-47Style.ps1
# Best-effort formatting/auto-fix for analyzer rules that support -Fix.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Path = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Import-Module PSScriptAnalyzer -ErrorAction Stop

$settings = Join-Path $Path 'style\PSScriptAnalyzerSettings.psd1'
if (-not (Test-Path -LiteralPath $settings)) { throw "Settings not found: $settings" }

Write-Host "Applying -Fix where supported..."
Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $settings -Fix | Out-Null

Write-Host "Re-running analyzer..."
$results = Invoke-ScriptAnalyzer -Path $Path -Recurse -Settings $settings
if ($results) {
  $results | Sort-Object RuleName, ScriptName, Line | Format-Table -AutoSize
  Write-Warning "Some issues remain (not all rules are auto-fixable)."
  exit 1
}

Write-Host "All clear."
exit 0

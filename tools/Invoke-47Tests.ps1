<#
  Invoke-47Tests.ps1
  Convenience wrapper to run Pester tests and record last run state.

  Writes LogsRootUser/state/last_test.json
#>
[CmdletBinding()]
param(
  [string]$Path = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'tests'),
  [switch]$CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Ensure Pester is available (prefers vendor in CI)
$install = Join-Path $PSScriptRoot 'install_pester.ps1'
if ($CI -or $env:CI) {
  & $install -PreferVendor | Out-Null
} else {
  & $install | Out-Null
}

# Import core for state recording
try {
  Import-Module (Join-Path (Join-Path $root 'Framework') 'Core/47.Core.psd1') -Force | Out-Null
} catch { }

$result = $null
$ok = $true
try {
  if ($CI -or $env:CI) {
    $result = Invoke-Pester -Path $Path -CI
  } else {
    $result = Invoke-Pester -Path $Path
  }
} catch {
  $ok = $false
  throw
} finally {
  try {
    if (Get-Command Set-47StateRecord -ErrorAction SilentlyContinue) {
      $rec = [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        path = $Path
        ci = [bool]($CI -or $env:CI)
        ok = $ok
        status = (if ($ok) { 'ok' } else { 'failed' })
      }
      if ($result) {
        foreach ($k in @('FailedCount','PassedCount','SkippedCount','TotalCount','NotRunCount')) {
          try {
            $v = $result.$k
            if ($null -ne $v) { $rec | Add-Member -Force -NotePropertyName ($k.Substring(0,1).ToLower()+$k.Substring(1)) -NotePropertyValue $v }
          } catch { }
        }
      }
      Set-47StateRecord -Name 'last_test' -Value $rec | Out-Null
    }
  } catch { }
}

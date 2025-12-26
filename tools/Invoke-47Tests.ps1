    <#
      Invoke-47Tests.ps1
      Convenience wrapper to run Pester tests.
    #>
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    param(
      [string]$Path = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'tests'),
      [switch]$CI
    )

    if ($CI) {
      Invoke-Pester -Path $Path -CI
    } else {
      Invoke-Pester -Path $Path
    }

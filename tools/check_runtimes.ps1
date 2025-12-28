
<#
.SYNOPSIS
  Checks optional external runtimes (Python, Node, Go) for external modules.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Check($name){
  try {
    $cmd = Get-Command $name -ErrorAction Stop
    $ver = ''
    try { $ver = (& $cmd.Source --version 2>$null) } catch { try { $ver = (& $cmd.Source version 2>$null) } catch { } }
    [pscustomobject]@{ runtime=$name; status='ok'; path=$cmd.Source; version=($ver | Out-String).Trim() }
  } catch {
    [pscustomobject]@{ runtime=$name; status='missing'; path=''; version='' }
  }
}

$items = @(
  Check 'pwsh',
  Check 'python',
  Check 'python3',
  Check 'node',
  Check 'go'
)

$items | Format-Table -AutoSize

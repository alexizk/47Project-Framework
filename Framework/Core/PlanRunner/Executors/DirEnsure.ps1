\
# dir.ensure step executor
Set-StrictMode -Version Latest

function Register-47DirEnsureStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $p = $step.dirEnsure
    if (-not $p) { throw "dir.ensure step missing 'dirEnsure' payload." }

    $path = $p.path
    if (-not $path) { throw "dirEnsure.path is required." }

    $ensure = if ($p.ensure) { $p.ensure } else { 'present' }

    $exists = Test-Path -LiteralPath $path

    if ($ensure -eq 'absent') {
      if (-not $exists) { return [ordered]@{ status='skipped'; message="Directory already absent."; path=$path } }
      if ($mode -eq 'WhatIf') { return [ordered]@{ status='whatif'; message="Would remove directory."; path=$path } }
      Remove-Item -LiteralPath $path -Recurse -Force
      return [ordered]@{ status='ok'; message="Removed directory."; path=$path }
    }

    if ($exists) { return [ordered]@{ status='skipped'; message="Directory already present."; path=$path } }
    if ($mode -eq 'WhatIf') { return [ordered]@{ status='whatif'; message="Would create directory."; path=$path } }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return [ordered]@{ status='ok'; message="Created directory."; path=$path }
  }

  Register-47StepExecutor -Context $Context -Type 'dir.ensure' -Executor $executor
}

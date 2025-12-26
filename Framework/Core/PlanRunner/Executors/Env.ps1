\
# Env step executor
Set-StrictMode -Version Latest

function Register-47EnvStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $p = $step.env
    if (-not $p) { throw "env step missing 'env' payload." }

    $name = $p.name
    if (-not $name) { throw "env step missing env.name" }

    $scope = if ($p.scope) { $p.scope } else { 'process' } # process|user|machine
    $ensure = if ($p.ensure) { $p.ensure } else { 'present' }

    $current = [Environment]::GetEnvironmentVariable($name, $scope)
    if ($ensure -eq 'absent') {
      if ($mode -eq 'WhatIf') {
        return [ordered]@{ status='whatif'; message=("Would remove env var '" + $name + "' from scope '" + $scope + "'."); current=$current }
      }
      [Environment]::SetEnvironmentVariable($name, $null, $scope)
      return [ordered]@{ status='ok'; message=("Removed env var '" + $name + "' from scope '" + $scope + "'.") }
    }

    $value = $p.value
    if ($null -eq $value) { throw "env step missing env.value for ensure=present" }

    if ($current -eq $value) {
      return [ordered]@{ status='skipped'; message=("Env var already set: " + $name); value=$value; scope=$scope }
    }

    if ($mode -eq 'WhatIf') {
      return [ordered]@{ status='whatif'; message=("Would set env var '" + $name + "' in scope '" + $scope + "'."); current=$current; desired=$value }
    }

    [Environment]::SetEnvironmentVariable($name, $value, $scope)
    return [ordered]@{ status='ok'; message=("Set env var '" + $name + "' in scope '" + $scope + "'."); desired=$value }
  }

  Register-47StepExecutor -Context $Context -Type 'env' -Executor $executor
}

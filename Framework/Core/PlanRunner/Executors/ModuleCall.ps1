# ModuleCall step executor for 47 Plan Runner
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-47ModulePathById {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ModuleId
  )
  $mods = Get-47Modules
  $m = $mods | Where-Object { $_.ModuleId -eq $ModuleId } | Select-Object -First 1
  if (-not $m) { return $null }
  return $m.Path
}

function Register-47ModuleCallStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($Step, $Mode, $ctx, $Plan)

    $stepId = $Step.stepId
    if (-not $stepId) { $stepId = $Step.id }

    $spec = $Step.moduleCall
    if (-not $spec) { throw "ModuleCall: missing 'moduleCall' payload for step $stepId" }

    $moduleId = $spec.moduleId
    $action = $spec.action
    $args = $spec.args

    if (-not $moduleId) { throw "ModuleCall: missing moduleId" }
    if (-not $action) { throw "ModuleCall: missing action" }
    if (-not $args) { $args = @{} }

    if ($Mode -eq 'WhatIf') {
      return [ordered]@{
        status='whatif'
        message=("Would call module " + $moduleId + " action " + $action)
        moduleId=$moduleId
        action=$action
        args=$args
      }
    }

    $modulePath = Find-47ModulePathById -ModuleId $moduleId
    if (-not $modulePath) { throw "ModuleCall: module not found: $moduleId" }

    $manifestPath = Join-Path $modulePath 'module.json'
    $manifest = Read-47Json -Path $manifestPath
    if (-not $manifest.entrypoint) { throw "ModuleCall: module manifest missing entrypoint: $moduleId" }

    $entry = Join-Path $modulePath $manifest.entrypoint
    if (-not (Test-Path -LiteralPath $entry)) { throw "ModuleCall: entrypoint not found: $entry" }

    $mod = Import-Module -Force -Name $entry -PassThru
    if (-not $mod) { throw "ModuleCall: failed to import module $moduleId" }

    # Prefer Invoke-47Module signature (Action, Args) optionally (Context)
    $cmd = $mod.ExportedCommands['Invoke-47Module']
    if (-not $cmd) {
      throw "ModuleCall: module $moduleId does not export Invoke-47Module"
    }

    $hasContext = $false
    try {
      if ($cmd.Parameters.ContainsKey('Context')) { $hasContext = $true }
    } catch { }

    $result = $null
    if ($hasContext) {
      $result = & $mod { param($a,$h,$c) Invoke-47Module -Action $a -Args $h -Context $c } $action $args $ctx
    } else {
      $result = & $mod { param($a,$h) Invoke-47Module -Action $a -Args $h } $action $args
    }

    return [ordered]@{
      status='ok'
      message='Module call completed.'
      moduleId=$moduleId
      action=$action
      result=$result
    }
  }

  Register-47StepExecutor -Context $Context -Type 'module.call' -Executor $executor
}

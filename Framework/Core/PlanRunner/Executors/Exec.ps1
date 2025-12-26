# Exec step executor for 47 Plan Runner
Set-StrictMode -Version Latest

function Limit-47Text {
  param(
    [AllowNull()][string]$Text,
    [int]$MaxChars = 262144
  )
  if ($null -eq $Text) { return $null }
  if ($Text.Length -le $MaxChars) { return $Text }
  return ($Text.Substring(0, $MaxChars) + "`n[TRUNCATED]")
}

function Resolve-47ExecCommandPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$File,
    [Parameter(Mandatory)][string]$PlanDir
  )

  # If looks like a path, resolve relative to plan dir
  $looksLikePath = ($File -match '[\\\/]') -or ($File -match '^\.' ) -or ($File -match '^[A-Za-z]:')
  if ($looksLikePath) {
    $p = $File
    if (-not [System.IO.Path]::IsPathRooted($p)) {
      $p = Join-Path $PlanDir $p
    }
    return (Resolve-Path -LiteralPath $p).Path
  }

  # Otherwise resolve through PATH
  $cmd = Get-Command -Name $File -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  if ($cmd -and $cmd.Path) { return $cmd.Path }
  throw "Exec: command not found: $File"
}

function Test-47ExecCheckSatisfied {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][hashtable]$Step,
    [Parameter(Mandatory)][string]$PlanDir,
    [Parameter(Mandatory)][ValidateSet('WhatIf','Apply')][string]$Mode
  )

  if (-not $Step.check) { return [pscustomobject]@{ HasCheck=$false; Satisfied=$false; Detail=$null } }

  $check = $Step.check
  $ctype = $check.type
  if (-not $ctype) { throw "Exec: step.check.type is required when check is present." }

  switch ($ctype) {
    'pathExists' {
      $path = $check.path
      if (-not $path) { throw "Exec: check.path required for check.type=pathExists" }
      $full = $path
      if (-not [System.IO.Path]::IsPathRooted($full)) { $full = Join-Path $PlanDir $full }
      $ok = Test-Path -LiteralPath $full
      return [pscustomobject]@{ HasCheck=$true; Satisfied=$ok; Detail=@{ type='pathExists'; path=$full } }
    }

    'exec' {
      # In WhatIf, don't run side-effecting checks.
      if ($Mode -eq 'WhatIf') {
        return [pscustomobject]@{ HasCheck=$true; Satisfied=$false; Detail=@{ type='exec'; note='check not executed in WhatIf' } }
      }

      $c = $check.exec
      if (-not $c) { throw "Exec: check.exec object required for check.type=exec" }
      $file = $c.file
      if (-not $file) { throw "Exec: check.exec.file required" }
      $args = @()
      if ($c.args) { $args = @($c.args) }
      $cwd = $c.cwd
      if (-not $cwd) { $cwd = $PlanDir }
      if (-not [System.IO.Path]::IsPathRooted($cwd)) { $cwd = Join-Path $PlanDir $cwd }

      $timeout = 60
      if ($c.timeoutSec) { $timeout = [int]$c.timeoutSec }

      $expect = 0
      if ($null -ne $c.expectExitCode) { $expect = [int]$c.expectExitCode }

      $cmdPath = Resolve-47ExecCommandPath -File $file -PlanDir $PlanDir
      $res = Invoke-47External -FilePath $cmdPath -ArgumentList $args -WorkingDirectory $cwd -TimeoutSeconds $timeout -Environment @{} -CaptureMaxKB 64
      return [pscustomobject]@{
        HasCheck  = $true
        Satisfied = ([int]$res.ExitCode -eq $expect)
        Detail    = @{
          type='exec'
          file=$cmdPath
          args=$args
          cwd=$cwd
          timeoutSec=$timeout
          expectExitCode=$expect
          actualExitCode=[int]$res.ExitCode
        }
      }
    }

    default {
      throw "Exec: unsupported check.type '$ctype'. Supported: pathExists, exec"
    }
  }
}

function Register-47ExecStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $planDir = $ctx.PlanDir
    if (-not $planDir) { $planDir = (Get-Location).Path }

    $stepId = $step.stepId
    if (-not $stepId) { $stepId = $step.id }
    if (-not $stepId) { $stepId = ("step_" + ([Guid]::NewGuid().ToString('N')).Substring(0,8)) }

    # Idempotency check (optional)
    $checkInfo = Test-47ExecCheckSatisfied -Context $ctx -Step $step -PlanDir $planDir -Mode $mode
    if ($checkInfo.HasCheck -and $checkInfo.Satisfied) {
      return [ordered]@{
        status  = 'skipped'
        reason  = 'already_satisfied'
        check   = $checkInfo.Detail
        message = "Exec step already satisfied; skipping."
      }
    }

    $exec = $step.exec
    if (-not $exec) { throw "Exec: missing required object 'exec' for step type 'exec'." }

    $file = $exec.file
    if (-not $file) { throw "Exec: exec.file is required." }

    $args = @()
    if ($exec.args) { $args = @($exec.args) }

    $cwd = $exec.cwd
    if (-not $cwd) { $cwd = $planDir }
    if (-not [System.IO.Path]::IsPathRooted($cwd)) { $cwd = Join-Path $planDir $cwd }

    $timeout = 300
    if ($step.timeoutSec) { $timeout = [int]$step.timeoutSec }
    if ($exec.timeoutSec) { $timeout = [int]$exec.timeoutSec }

    $env = @{}
    if ($exec.env) {
      foreach ($p in $exec.env.PSObject.Properties) { $env[$p.Name] = [string]$p.Value }
    }

    $cmdPath = Resolve-47ExecCommandPath -File $file -PlanDir $planDir
    $cmdString = ($cmdPath + ' ' + ($args -join ' ')).Trim()

    if ($mode -eq 'WhatIf') {
      $msg = "Would run: $cmdString"
      if ($checkInfo.HasCheck -and ($checkInfo.Detail.type -eq 'exec')) {
        $msg += " (check not executed in WhatIf)"
      }
      return [ordered]@{
        status='whatif'
        command=$cmdString
        file=$cmdPath
        args=$args
        cwd=$cwd
        timeoutSec=$timeout
        envKeys=@($env.Keys)
        message=$msg
      }
    }

    # Apply mode: execute and capture outputs to run folder
    $stepRoot = Join-Path $ctx.StepsRoot $stepId
    New-Item -ItemType Directory -Force -Path $stepRoot | Out-Null
    $stdoutPath = Join-Path $stepRoot 'stdout.txt'
    $stderrPath = Join-Path $stepRoot 'stderr.txt'

    # Limit captured output in JSON results/journal
    $maxKB = 256
    if ($exec.captureMaxKB) { $maxKB = [int]$exec.captureMaxKB }
    $res = Invoke-47External -FilePath $cmdPath -ArgumentList $args -WorkingDirectory $cwd -TimeoutSeconds $timeout -Environment $env -StdOutFile $stdoutPath -StdErrFile $stderrPath -CaptureMaxKB $maxKB
    $maxChars = $maxKB * 1024
    $out = Limit-47Text -Text $res.StdOut -MaxChars $maxChars
    $err = Limit-47Text -Text $res.StdErr -MaxChars $maxChars

    $exitCode = [int]$res.ExitCode
    $okCodes = @()
    if ($exec.okExitCodes) { $okCodes = @($exec.okExitCodes | ForEach-Object { [int]$_ }) } else { $okCodes = @(0) }

    if ($okCodes -notcontains $exitCode) {
      return [ordered]@{
        status='error'
        message=("Exec failed with exit code " + $exitCode)
        command=$cmdString
        file=$cmdPath
        args=$args
        cwd=$cwd
        timeoutSec=$timeout
        exitCode=$exitCode
        stdout=$out
        stderr=$err
        stdoutPath=$stdoutPath
        stderrPath=$stderrPath
      }
    }

    return [ordered]@{
      status='ok'
      message='Exec completed.'
      command=$cmdString
      file=$cmdPath
      args=$args
      cwd=$cwd
      timeoutSec=$timeout
      exitCode=$exitCode
      stdout=$out
      stderr=$err
      stdoutPath=$stdoutPath
      stderrPath=$stderrPath
    }
  }

  Register-47StepExecutor -Context $Context -Type 'exec' -Executor $executor
}

# 47 Plan Runner (skeleton implementation)
Set-StrictMode -Version Latest

function New-47RunId {
  [CmdletBinding()]
  param()
  return ([Guid]::NewGuid().ToString('N'))
}

function New-47RunContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Paths,
    [Parameter(Mandatory)][hashtable]$Policy,
    [Parameter(Mandatory)][hashtable]$Config,
    [Parameter()][string]$RunId
  )

  if (-not $RunId) { $RunId = New-47RunId }

  $runRoot = Join-Path $Paths.LogsRoot ("runs\" + $RunId)
  New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

  $stepsRoot = Join-Path $runRoot "steps"
  New-Item -ItemType Directory -Force -Path $stepsRoot | Out-Null

  $ctx = [ordered]@{
    RunId      = $RunId
    RunRoot    = $runRoot
    StepsRoot  = $stepsRoot
    Journal    = Join-Path $runRoot "journal.jsonl"
    Results    = Join-Path $runRoot "result.json"
    Paths      = $Paths
    Policy     = $Policy
    Config     = $Config
    StartUtc   = [DateTime]::UtcNow.ToString("o")
    StepExec   = @{}
  }
  return $ctx
}

function Register-47StepExecutor {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][string]$Type,
    [Parameter(Mandatory)][scriptblock]$Executor
  )
  $Context.StepExec[$Type.ToLowerInvariant()] = $Executor
}

function Write-47JournalEntry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][hashtable]$Entry
  )

  $entry2 = [ordered]@{} + $Entry
  if (-not $entry2.ContainsKey('tsUtc')) { $entry2.tsUtc = [DateTime]::UtcNow.ToString("o") }
  if (-not $entry2.ContainsKey('runId')) { $entry2.runId = $Context.RunId }

  ($entry2 | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $Context.Journal -Encoding UTF8
}

function Invoke-47PlanStep {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][hashtable]$Plan,
    [Parameter(Mandatory)][hashtable]$Step,
    [Parameter(Mandatory)][ValidateSet('WhatIf','Apply')][string]$Mode
  )

  $stepId = $Step.stepId
  if (-not $stepId) { $stepId = $Step.id }
  if (-not $stepId) { $stepId = ("step_" + ([Guid]::NewGuid().ToString('N')).Substring(0,8)) }

  $type = $Step.type
  if (-not $type) { throw "Plan step missing required field 'type'." }

  # Risk gate (default: safe)
  $risk = if ($Step.risk) { $Step.risk } elseif ($Plan.risk) { $Plan.risk } else { 'safe' }
  if (-not (Test-47RiskAllowed -Risk $risk -Policy $Context.Policy)) {
    $msg = "Blocked by policy. risk=$risk step=$stepId type=$type"
    Write-47JournalEntry -Context $Context -Entry ([ordered]@{
      kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='blocked'; risk=$risk; message=$msg
    })
    return [ordered]@{ stepId=$stepId; type=$type; status='blocked'; risk=$risk; message=$msg }
  }


# Capability gate
$cap = if ($Step.capability) { $Step.capability } else { Get-47DefaultCapabilityForStepType -Type $type }
if ($cap -and (-not (Test-47CapabilityAllowed -CapabilityId $cap -Policy $Context.Policy))) {
  $msg = "Blocked by policy. capability=$cap step=$stepId type=$type"
  Write-47JournalEntry -Context $Context -Entry ([ordered]@{
    kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='blocked'; risk=$risk; capability=$cap; message=$msg
  })
  return [ordered]@{ stepId=$stepId; type=$type; status='blocked'; risk=$risk; capability=$cap; message=$msg }
}

# Restricted mode blocks (optional)
if ($Context.Policy.restrictedMode -and $Context.Policy.restrictedMode.enabled) {
  $rm = $Context.Policy.restrictedMode
  if ($rm.blockExternalExec -and ($type.ToLowerInvariant() -in @('exec'))) {
    $msg = "Blocked by restrictedMode: external exec disabled. step=$stepId type=$type"
    Write-47JournalEntry -Context $Context -Entry ([ordered]@{ kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='blocked'; risk=$risk; message=$msg })
    return [ordered]@{ stepId=$stepId; type=$type; status='blocked'; risk=$risk; message=$msg }
  }
  if ($rm.blockNetwork -and ($type.ToLowerInvariant() -in @('download','git.clone','winget','choco'))) {
    $msg = "Blocked by restrictedMode: network disabled. step=$stepId type=$type"
    Write-47JournalEntry -Context $Context -Entry ([ordered]@{ kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='blocked'; risk=$risk; message=$msg })
    return [ordered]@{ stepId=$stepId; type=$type; status='blocked'; risk=$risk; message=$msg }
  }
  if ($rm.blockRegistryWrites -and ($type.ToLowerInvariant() -in @('registry'))) {
    $msg = "Blocked by restrictedMode: registry writes disabled. step=$stepId type=$type"
    Write-47JournalEntry -Context $Context -Entry ([ordered]@{ kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='blocked'; risk=$risk; message=$msg })
    return [ordered]@{ stepId=$stepId; type=$type; status='blocked'; risk=$risk; message=$msg }
  }
}

  Write-47JournalEntry -Context $Context -Entry ([ordered]@{
    kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='start'; risk=$risk
  })

  try {
    $executor = $Context.StepExec[$type.ToLowerInvariant()]
    if (-not $executor) {
      throw "No executor registered for step type '$type'. (Skeleton runner expects executors to be registered.)"
    }

    $res = & $executor $Context $Plan $Step $Mode
    if (-not $res) { $res = [ordered]@{ status='ok' } }

    $status = if ($res.status) { $res.status } else { 'ok' }

    Write-47JournalEntry -Context $Context -Entry ([ordered]@{
      kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status=$status; risk=$risk; result=$res
    })
    return [ordered]@{ stepId=$stepId; type=$type; risk=$risk } + $res
  }
  catch {
    $err = $_.Exception.Message
    Write-47JournalEntry -Context $Context -Entry ([ordered]@{
      kind='step'; stepId=$stepId; stepType=$type; mode=$Mode; status='error'; risk=$risk; error=$err
    })
    return [ordered]@{ stepId=$stepId; type=$type; status='error'; risk=$risk; error=$err }
  }
}

function Import-47StepExecutors {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $execDir = Join-Path $PSScriptRoot 'Executors'
  if (-not (Test-Path -LiteralPath $execDir)) { return }

  Get-ChildItem -LiteralPath $execDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
    . $_.FullName
  }

  # Auto-register any executor registrar functions that match: Register-47*StepExecutor
  $registrars = Get-Command -CommandType Function -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'Register-47*StepExecutor' -and $_.Name -ne 'Register-47StepExecutor' } |
    Sort-Object Name

  foreach ($r in $registrars) {
    try {
      & $r.Name -Context $Context
    } catch {
      Write-47JournalEntry -Context $Context -Entry ([ordered]@{ kind='executor'; status='error'; registrar=$r.Name; error=$_.Exception.Message })
      throw
    }
  }
}


function Register-47DefaultStepExecutors {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  # default stubs (safe for WhatIf; Apply throws)
  $stub = {
    param($ctx,$plan,$step,$mode)
    $t = $step.type
    if ($mode -eq 'WhatIf') {
      return [ordered]@{ status='whatif'; message=("Would execute step type '" + $t + "'. (executor stub)") }
    }
    throw ("Step executor '" + $t + "' is a stub in this skeleton pack. Implement it in Framework/Core/PlanRunner/Executors.")
  }

  foreach ($t in @('copy','download','registry','env','service','task','file.ensure','dir.ensure','zip.extract','json.merge','json.patch','hosts','winget','choco','git.clone','module.install','module.uninstall','module.call')) {
    Register-47StepExecutor -Context $Context -Type $t -Executor $stub
  }

  # load real executors (currently: exec)
  Import-47StepExecutors -Context $Context

  # If exec executor didn't load, fall back to stub for exec too
  if (-not $Context.StepExec.ContainsKey('exec')) {
    Register-47StepExecutor -Context $Context -Type 'exec' -Executor $stub
  }
}


function Get-47LastStepStatusMap {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$JournalPath)

  $map = @{}
  if (-not (Test-Path -LiteralPath $JournalPath)) { return $map }

  Get-Content -LiteralPath $JournalPath -ErrorAction SilentlyContinue | ForEach-Object {
    $line = $_
    if (-not $line) { return }
    try {
      $obj = $line | ConvertFrom-Json -Depth 50
      if ($obj.kind -eq 'step' -and $obj.stepId -and $obj.status -and ($obj.status -ne 'start')) {
        $map[$obj.stepId] = $obj.status
      }
    } catch {
      # ignore malformed lines
    }
  }
  return $map
}

function Invoke-47PlanRun {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$PlanPath,
    [Parameter()][ValidateSet('WhatIf','Apply')][string]$Mode = 'WhatIf',
    [Parameter()][string]$PolicyPath,
    [Parameter()][switch]$NoSnapshot,
    [Parameter()][switch]$ContinueOnError,
    [Parameter()][string]$RunId,
    [Parameter()][switch]$Resume,
    [Parameter()][switch]$RetryFailedOnly
  )
  $paths = Get-47Paths
  $policy = if ($PolicyPath) { Read-47Json -Path $PolicyPath } else { Get-47EffectivePolicy }
  $config = Get-47EffectiveConfig

  $plan = Read-47Json -Path $PlanPath

  $plan = Resolve-47PlanComposition -Plan $plan -PlanPath $PlanPath


  $ctx = New-47RunContext -Paths $paths -Policy $policy -Config $config -RunId $RunId
  $ctx.PlanPath = (Resolve-Path -LiteralPath $PlanPath).Path
  $ctx.PlanDir = Split-Path -Parent $ctx.PlanPath
  Register-47DefaultStepExecutors -Context $ctx

  Write-47JournalEntry -Context $ctx -Entry ([ordered]@{
    kind='run'; status=$(if($Resume){'resume-start'} else {'start'}); mode=$Mode; planPath=(Resolve-Path $PlanPath).Path; planId=$plan.id
  })

  # Pre-run snapshot (apply only)
  if (($Mode -eq 'Apply') -and (-not $NoSnapshot)) {
    try {
      Save-47Snapshot -Name ("plan-" + $ctx.RunId) -IncludePack:$true | Out-Null
      Write-47JournalEntry -Context $ctx -Entry ([ordered]@{ kind='snapshot'; status='created' })
    } catch {
      Write-47JournalEntry -Context $ctx -Entry ([ordered]@{ kind='snapshot'; status='error'; error=$_.Exception.Message })
      if (-not $ContinueOnError) { throw }
    }
  }

    $resumeMap = @{}
  if ($Resume) {
    $resumeMap = Get-47LastStepStatusMap -JournalPath $ctx.Journal
    Write-47JournalEntry -Context $ctx -Entry ([ordered]@{
      kind='run'; status='resume'; retryFailedOnly=[bool]$RetryFailedOnly; knownSteps=@($resumeMap.Keys)
    })
  }

$results = @()
  $steps = @($plan.steps)
  for ($i=0; $i -lt $steps.Count; $i++) {
    $step = $steps[$i]
    if ($Resume) {
      $sid = $step.stepId
      if (-not $sid) { $sid = $step.id }
      if ($sid -and $resumeMap.ContainsKey($sid)) {
        $last = $resumeMap[$sid]
        $shouldRun = $true
        if ($RetryFailedOnly) {
          if ($last -ne 'error') { $shouldRun = $false }
        } else {
          if (($last -eq 'ok') -or ($last -eq 'skip')) { $shouldRun = $false }
        }
        if (-not $shouldRun) {
          $r = [ordered]@{ stepId=$sid; type=$step.type; status='skip'; message=("Skipped due to resume. lastStatus=" + $last) }
          $results += $r
          continue
        }
      }
    }

    $r = Invoke-47PlanStep -Context $ctx -Plan $plan -Step $step -Mode $Mode
    $results += $r
    if (($r.status -eq 'error') -and (-not $ContinueOnError)) {
      break
    }
  }

  $final = [ordered]@{
    schemaVersion = '1.0.0'
    runId         = $ctx.RunId
    planId        = $plan.id
    mode          = $Mode
    startUtc      = $ctx.StartUtc
    endUtc        = [DateTime]::UtcNow.ToString("o")
    results       = $results
    journal       = $ctx.Journal
  }

  ($final | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath $ctx.Results -Encoding UTF8

  Write-47JournalEntry -Context $ctx -Entry ([ordered]@{
    kind='run'; status='end'; resultsPath=$ctx.Results
  })

  return $final
}

Export-ModuleMember -Function New-47RunId, New-47RunContext, Register-47StepExecutor, Register-47DefaultStepExecutors, Write-47JournalEntry, Invoke-47PlanStep, Invoke-47PlanRun



function Get-47DefaultCapabilityForStepType {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Type)

  switch ($Type.ToLowerInvariant()) {
    'exec' { return 'cap.exec.process' }
    'download' { return 'cap.network.access' }
    'copy' { return 'cap.file.write' }
    'registry' { return 'cap.registry.write' }
    'env' { return 'cap.env.write' }
    'service' { return 'cap.service.manage' }
    'task' { return 'cap.task.manage' }
    'file.ensure' { return 'cap.file.write' }
    'dir.ensure' { return 'cap.file.write' }
    'zip.extract' { return 'cap.zip.extract' }
    'json.merge' { return 'cap.json.modify' }
    'json.patch' { return 'cap.json.modify' }
    'hosts' { return 'cap.hosts.edit' }
    'winget' { return 'cap.package.winget' }
    'choco' { return 'cap.package.choco' }
    'git.clone' { return 'cap.git.clone' }
    'module.install' { return 'cap.module.install' }
    'module.uninstall' { return 'cap.module.install' }
    'module.call' { return 'cap.module.call' }
    default { return $null }
  }
}



function Resolve-47PlanComposition {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Plan,
    [Parameter(Mandatory)][string]$PlanPath
  )

  $planDir = Split-Path -Parent $PlanPath

  function LoadPlan([string]$p) {
    $full = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $planDir $p }
    if (-not (Test-Path -LiteralPath $full)) { throw "Included/extended plan not found: $full" }
    return (Read-47Json -Path $full)
  }

  $resolved = $Plan

  if ($Plan.extends) {
    $base = LoadPlan $Plan.extends
    # shallow merge: current overrides base; steps concatenated base first
    foreach ($k in $base.Keys) {
      if (-not $resolved.ContainsKey($k)) { $resolved[$k] = $base[$k] }
    }
    if ($base.targets -and $resolved.targets) {
      $resolved.targets = Merge-47Object -Base $base.targets -Overlay $resolved.targets
    }
    if ($base.steps) {
      $resolved.steps = @($base.steps) + @($resolved.steps)
    }
  }

  if ($Plan.include) {
    $incSteps = @()
    foreach ($p in @($Plan.include)) {
      $inc = LoadPlan $p
      if ($inc.steps) { $incSteps += @($inc.steps) }
    }
    $resolved.steps = @($incSteps) + @($resolved.steps)
  }

  return $resolved
}

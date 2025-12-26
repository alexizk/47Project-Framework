\
# 47.ps1 - CLI entrypoint shim
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(ValueFromRemainingArguments)]
  [string[]]$Args
)

$packRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-47Help {
  @"
47Project Framework CLI

Core
  menu|shell                          Launch Nexus shell
  doctor                              Run diagnostics
  firstrun                            Run first-run wizard

Plan
  plan run <plan> whatif|apply [policy] [--continue] [--nosnapshot]
  plan resume <plan> <runId> whatif|apply [policy] [--continue] [--nosnapshot] [--retryfailed]
  plan diff <a> <b>
  plan validate <plan>

Policy
  policy simulate <plan> [policy]

Repo
  repo sync <indexUriOrPath> [targetRepoRoot] [certPath] [--allowUnsigned]

Trust
  trust get
  trust add-publisher <publisherId> <certPath> [keyId] [active|retired|revoked]
  trust pin-hash <sha256>

Snapshots
  snapshot [name]
  snapshots
  rollback <snapshotId>

Dev
  module new <moduleId>
  stylecheck
  tests

"@ | Write-Host
}

if (-not $Args -or $Args[0] -in @('help','-h','--help')) { Show-47Help; exit 0 }

$cmd = $Args[0].ToLowerInvariant()

switch ($cmd) {
  'menu' { & (Join-Path $packRoot 'Framework\47Project.Framework.ps1'); exit $LASTEXITCODE }
  'shell' { & (Join-Path $packRoot 'Framework\47Project.Framework.ps1'); exit $LASTEXITCODE }

  'doctor' { & (Join-Path $packRoot 'tools\Invoke-47Doctor.ps1'); exit $LASTEXITCODE }
  'firstrun' { & (Join-Path $packRoot 'tools\Invoke-47FirstRun.ps1'); exit $LASTEXITCODE }

  'stylecheck' { & (Join-Path $packRoot 'tools\Invoke-47StyleCheck.ps1'); exit $LASTEXITCODE }
  'tests' { & (Join-Path $packRoot 'tools\Invoke-47Tests.ps1'); exit $LASTEXITCODE }

  'snapshot' {
    $name = if ($Args.Count -gt 1) { $Args[1] } else { 'snapshot' }
    & (Join-Path $packRoot 'tools\Save-47Snapshot.ps1') -Name $name -IncludePack
    exit $LASTEXITCODE
  }
  'snapshots' { & (Join-Path $packRoot 'tools\Get-47Snapshots.ps1'); exit $LASTEXITCODE }
  'rollback' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 rollback <snapshotId>"; exit 1 }
    & (Join-Path $packRoot 'tools\Restore-47Snapshot.ps1') -SnapshotId $Args[1]
    exit $LASTEXITCODE
  }

  'policy' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 policy simulate ..."; exit 1 }
    $sub = $Args[1].ToLowerInvariant()
    switch ($sub) {
      'simulate' {
        if ($Args.Count -lt 3) { Write-Warning "Usage: .\47.ps1 policy simulate <plan> [policy]"; exit 1 }
        $plan = $Args[2]
        $pol = if ($Args.Count -gt 3 -and -not $Args[3].StartsWith('--')) { $Args[3] } else { $null }
        & (Join-Path $packRoot 'tools\Simulate-47Policy.ps1') -PlanPath $plan -PolicyPath $pol
        exit $LASTEXITCODE
      }
      default { Write-Warning "Unknown policy subcommand '$sub'."; exit 1 }
    }
  }

  'plan' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 plan <run|resume|diff|validate> ..."; exit 1 }
    $sub = $Args[1].ToLowerInvariant()

    if ($sub -eq 'diff') {
      if ($Args.Count -lt 4) { Write-Warning "Usage: .\47.ps1 plan diff <a> <b>"; exit 1 }
      & (Join-Path $packRoot 'tools\Diff-47Plan.ps1') -PlanA $Args[2] -PlanB $Args[3]
      exit $LASTEXITCODE
    }

    if ($sub -eq 'validate') {
      if ($Args.Count -lt 3) { Write-Warning "Usage: .\47.ps1 plan validate <plan>"; exit 1 }
      & (Join-Path $packRoot 'tools\Validate-47Plan.ps1') -PlanPath $Args[2]
      exit $LASTEXITCODE
    }

    if ($sub -eq 'run') {
      if ($Args.Count -lt 4) { Write-Warning "Usage: .\47.ps1 plan run <plan> whatif|apply [policy] [--continue] [--nosnapshot]"; exit 1 }
      $plan = $Args[2]
      $mode = $Args[3]
      $policy = $null
      $flags = $Args[4..($Args.Count-1)]
      if ($Args.Count -gt 4 -and -not $Args[4].StartsWith('--')) {
        $policy = $Args[4]
        $flags = if ($Args.Count -gt 5) { $Args[5..($Args.Count-1)] } else { @() }
      }
      $continue = ($flags -contains '--continue')
      $nosnap   = ($flags -contains '--nosnapshot')
      & (Join-Path $packRoot 'tools\Run-47Plan.ps1') -PlanPath $plan -Mode $mode -PolicyPath $policy -ContinueOnError:$continue -NoSnapshot:$nosnap
      exit $LASTEXITCODE
    }

    if ($sub -eq 'resume') {
      if ($Args.Count -lt 5) { Write-Warning "Usage: .\47.ps1 plan resume <plan> <runId> whatif|apply [policy] [--continue] [--nosnapshot] [--retryfailed]"; exit 1 }
      $plan = $Args[2]
      $runId = $Args[3]
      $mode = $Args[4]
      $policy = $null
      $flags = $Args[5..($Args.Count-1)]
      if ($Args.Count -gt 5 -and -not $Args[5].StartsWith('--')) {
        $policy = $Args[5]
        $flags = if ($Args.Count -gt 6) { $Args[6..($Args.Count-1)] } else { @() }
      }
      $continue = ($flags -contains '--continue')
      $nosnap   = ($flags -contains '--nosnapshot')
      $retryFailed = ($flags -contains '--retryfailed')
      & (Join-Path $packRoot 'tools\Run-47Plan.ps1') -PlanPath $plan -Mode $mode -PolicyPath $policy -RunId $runId -Resume -RetryFailedOnly:$retryFailed -ContinueOnError:$continue -NoSnapshot:$nosnap
      exit $LASTEXITCODE
    }

    Write-Warning "Unknown plan subcommand '$sub'."
    exit 1
  }

  'repo' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 repo sync ..."; exit 1 }
    $sub = $Args[1].ToLowerInvariant()
    switch ($sub) {
      'sync' {
        if ($Args.Count -lt 3) { Write-Warning "Usage: .\47.ps1 repo sync <indexUriOrPath> [targetRepoRoot] [certPath] [--allowUnsigned]"; exit 1 }
        $index = $Args[2]
        $target = if ($Args.Count -gt 3 -and -not $Args[3].StartsWith('--')) { $Args[3] } else { $null }
        $cert = if ($Args.Count -gt 4 -and -not $Args[4].StartsWith('--')) { $Args[4] } else { $null }
        $allowUnsigned = ($Args -contains '--allowUnsigned')
        & (Join-Path $packRoot 'tools\Sync-47Repo.ps1') -IndexUriOrPath $index -TargetRepoRoot $target -CertPath $cert -AllowUnsigned:$allowUnsigned
        exit $LASTEXITCODE
      }
      default { Write-Warning "Unknown repo subcommand '$sub'."; exit 1 }
    }
  }

  'trust' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 trust <get|add-publisher|pin-hash> ..."; exit 1 }
    $sub = $Args[1].ToLowerInvariant()
    switch ($sub) {
      'get' { & (Join-Path $packRoot 'tools\Get-47Trust.ps1'); exit $LASTEXITCODE }
      'add-publisher' {
        if ($Args.Count -lt 4) { Write-Warning "Usage: .\47.ps1 trust add-publisher <publisherId> <certPath> [keyId] [active|retired|revoked]"; exit 1 }
        $pub = $Args[2]
        $cert = $Args[3]
        $keyId = if ($Args.Count -gt 4) { $Args[4] } else { 'default' }
        $status = if ($Args.Count -gt 5) { $Args[5] } else { 'active' }
        & (Join-Path $packRoot 'tools\Add-47TrustedPublisher.ps1') -PublisherId $pub -CertPath $cert -KeyId $keyId -Status $status
        exit $LASTEXITCODE
      }
      'pin-hash' {
        if ($Args.Count -lt 3) { Write-Warning "Usage: .\47.ps1 trust pin-hash <sha256>"; exit 1 }
        & (Join-Path $packRoot 'tools\Pin-47ArtifactHash.ps1') -Sha256Hex $Args[2]
        exit $LASTEXITCODE
      }
      default { Write-Warning "Unknown trust subcommand '$sub'."; exit 1 }
    }
  }

  'module' {
    if ($Args.Count -lt 2) { Write-Warning "Usage: .\47.ps1 module new <moduleId>"; exit 1 }
    $sub = $Args[1].ToLowerInvariant()
    switch ($sub) {
      'new' {
        if ($Args.Count -lt 3) { Write-Warning "Usage: .\47.ps1 module new <moduleId>"; exit 1 }
        & (Join-Path $packRoot 'tools\New-47Module.ps1') -ModuleId $Args[2]
        exit $LASTEXITCODE
      }
      default { Write-Warning "Unknown module subcommand '$sub'."; exit 1 }
    }
  }

  default { Write-Warning "Unknown command '$cmd'. Try: .\47.ps1 help"; exit 1 }
}

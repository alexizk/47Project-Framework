# Copy step executor for 47 Plan Runner
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-47PathRelativeToPlan {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][string]$Path
  )
  if ([string]::IsNullOrWhiteSpace($Path)) { throw "Copy: path is empty." }

  # If rooted, use as-is
  if ([System.IO.Path]::IsPathRooted($Path)) { return (Resolve-Path -LiteralPath $Path).Path }

  $base = $Context.PlanDir
  $full = Join-Path $base $Path
  return (Resolve-Path -LiteralPath $full).Path
}

function Get-47FileSha256 {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Register-47CopyStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($Step, $Mode, $ctx, $Plan)

    $stepId = $Step.stepId
    if (-not $stepId) { $stepId = $Step.id }

    $spec = $Step.copy
    if (-not $spec) { throw "Copy: missing 'copy' payload for step $stepId" }

    $ensure = if ($spec.ensure) { $spec.ensure } else { 'present' }
    $overwrite = if ($null -ne $spec.overwrite) { [bool]$spec.overwrite } else { $true }
    $recurse = if ($null -ne $spec.recurse) { [bool]$spec.recurse } else { $true }
    $skipIfSameHash = if ($null -ne $spec.skipIfSameHash) { [bool]$spec.skipIfSameHash } else { $true }

    $src = if ($spec.source) { Resolve-47PathRelativeToPlan -Context $ctx -Path $spec.source } else { $null }
    $dst = Resolve-47PathRelativeToPlan -Context $ctx -Path $spec.destination

    if ($Mode -eq 'WhatIf') {
      return [ordered]@{
        status='whatif'
        message=("Would ensure copy $ensure -> " + $dst)
        source=$spec.source
        destination=$spec.destination
      }
    }

    if ($ensure -eq 'absent') {
      if (-not (Test-Path -LiteralPath $dst)) {
        return [ordered]@{ status='skip'; message='Destination already absent.'; destination=$dst }
      }
      Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction Stop
      return [ordered]@{ status='ok'; message='Removed destination.'; destination=$dst }
    }

    if (-not $src) { throw "Copy: 'source' is required unless ensure=absent (step $stepId)" }
    if (-not (Test-Path -LiteralPath $src)) { throw "Copy: source not found: $src" }

    # Ensure destination parent
    $dstParent = Split-Path -Parent $dst
    if ($dstParent -and -not (Test-Path -LiteralPath $dstParent)) {
      New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
    }

    # Idempotency: file-to-file same hash
    $srcItem = Get-Item -LiteralPath $src -ErrorAction Stop
    $isSrcDir = $srcItem.PSIsContainer

    if (-not $isSrcDir -and (Test-Path -LiteralPath $dst)) {
      $dstItem = Get-Item -LiteralPath $dst -ErrorAction Stop
      if (-not $dstItem.PSIsContainer -and $skipIfSameHash) {
        try {
          $h1 = Get-47FileSha256 -Path $src
          $h2 = Get-47FileSha256 -Path $dst
          if ($h1 -eq $h2) {
            return [ordered]@{
              status='skip'
              message='Destination file already matches source hash.'
              source=$src
              destination=$dst
              sha256=$h1
            }
          }
        } catch {
          # If hashing fails, fall through and copy
        }
      }
    }

    # Copy
    if ($isSrcDir) {
      # Copy directory contents into destination directory
      if (-not (Test-Path -LiteralPath $dst)) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
      }
      Copy-Item -LiteralPath (Join-Path $src '*') -Destination $dst -Recurse:$recurse -Force:$overwrite -ErrorAction Stop
    } else {
      Copy-Item -LiteralPath $src -Destination $dst -Force:$overwrite -ErrorAction Stop
    }

    return [ordered]@{
      status='ok'
      message='Copy completed.'
      source=$src
      destination=$dst
      overwrite=$overwrite
      recurse=$recurse
    }
  }

  Register-47StepExecutor -Context $Context -Type 'copy' -Executor $executor
}

\
# json.merge step executor
Set-StrictMode -Version Latest

function Register-47JsonMergeStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $p = $step.jsonMerge
    if (-not $p) { throw "json.merge step missing 'jsonMerge' payload." }

    $path = $p.path
    $merge = $p.merge
    if (-not $path) { throw "jsonMerge.path is required." }
    if (-not $merge) { throw "jsonMerge.merge object is required." }

    $exists = Test-Path -LiteralPath $path
    $current = if ($exists) { Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    $desired = Merge-47Object -Base $current -Overlay $merge

    $curJson = ($current | ConvertTo-Json -Depth 50 -Compress)
    $desJson = ($desired | ConvertTo-Json -Depth 50 -Compress)
    if ($curJson -eq $desJson) { return [ordered]@{ status='skipped'; message="JSON already matches desired merged state."; path=$path } }

    if ($mode -eq 'WhatIf') {
      return [ordered]@{ status='whatif'; message="Would merge JSON into file."; path=$path }
    }

    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($desired | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath $path -Encoding UTF8
    return [ordered]@{ status='ok'; message="Merged JSON into file."; path=$path }
  }

  Register-47StepExecutor -Context $Context -Type 'json.merge' -Executor $executor
}

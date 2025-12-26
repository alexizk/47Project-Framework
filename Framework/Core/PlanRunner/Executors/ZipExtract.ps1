\
# zip.extract step executor (safe)
Set-StrictMode -Version Latest

function Register-47ZipExtractStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $p = $step.zipExtract
    if (-not $p) { throw "zip.extract step missing 'zipExtract' payload." }

    $zip = $p.zipPath
    $dest = $p.destDir
    if (-not $zip) { throw "zipExtract.zipPath is required." }
    if (-not $dest) { throw "zipExtract.destDir is required." }

    if ($mode -eq 'WhatIf') {
      return [ordered]@{ status='whatif'; message="Would extract zip safely."; zipPath=$zip; destDir=$dest }
    }

    if (-not (Test-Path -LiteralPath $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
    Expand-47ZipSafe -ZipPath $zip -Destination $dest
    return [ordered]@{ status='ok'; message="Extracted zip safely."; zipPath=$zip; destDir=$dest }
  }

  Register-47StepExecutor -Context $Context -Type 'zip.extract' -Executor $executor
}

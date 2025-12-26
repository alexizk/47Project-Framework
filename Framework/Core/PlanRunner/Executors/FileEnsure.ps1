\
# file.ensure step executor
Set-StrictMode -Version Latest

function Register-47FileEnsureStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)

    $p = $step.fileEnsure
    if (-not $p) { throw "file.ensure step missing 'fileEnsure' payload." }

    $path = $p.path
    if (-not $path) { throw "fileEnsure.path is required." }

    $ensure = if ($p.ensure) { $p.ensure } else { 'present' }
    $encoding = if ($p.encoding) { $p.encoding } else { 'utf8' }
    $exists = Test-Path -LiteralPath $path

    if ($ensure -eq 'absent') {
      if (-not $exists) { return [ordered]@{ status='skipped'; message="File already absent."; path=$path } }
      if ($mode -eq 'WhatIf') { return [ordered]@{ status='whatif'; message="Would remove file."; path=$path } }
      Remove-Item -LiteralPath $path -Force
      return [ordered]@{ status='ok'; message="Removed file."; path=$path }
    }

    $content = if ($p.content) { [string]$p.content } else { '' }
    $op = if ($p.op) { $p.op } else { 'write' } # write|append

    $current = if ($exists) { Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue } else { $null }

    $desired = if ($op -eq 'append' -and $exists) { $current + $content } else { $content }

    if ($current -eq $desired) {
      return [ordered]@{ status='skipped'; message="File already in desired state."; path=$path }
    }

    if ($mode -eq 'WhatIf') {
      return [ordered]@{ status='whatif'; message="Would ensure file content."; path=$path; op=$op }
    }

    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($op -eq 'append' -and $exists) {
      Add-Content -LiteralPath $path -Value $content -Encoding $encoding
    } else {
      Set-Content -LiteralPath $path -Value $content -Encoding $encoding
    }

    return [ordered]@{ status='ok'; message="Ensured file content."; path=$path; op=$op }
  }

  Register-47StepExecutor -Context $Context -Type 'file.ensure' -Executor $executor
}

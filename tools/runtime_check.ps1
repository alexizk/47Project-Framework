<#
.SYNOPSIS
  Prints a runtime checklist and (optionally) verifies required tools exist.

.PARAMETER Verify
  If set, exits non-zero when required tools are missing.

.DESCRIPTION
  Designed for offline zips so users can quickly validate the host before running tests or modules.

Required:
  - PowerShell 7+ (pwsh)

Optional (used by some modules / workflows):
  - Git
  - Python
  - Node.js
  - Go
  - Docker
#>
[CmdletBinding()]
param([switch]$Verify)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Has-Cmd([string]$n) {
  try { return [bool](Get-Command $n -ErrorAction Stop) } catch { return $false }
}

$req = @(
  @{ name='pwsh'; required=$true; note='PowerShell 7+' }
)
$opt = @(
  @{ name='git'; required=$false; note='Used for vendoring fallback and some workflows' },
  @{ name='python'; required=$false; note='External modules may use Python' },
  @{ name='node'; required=$false; note='External modules may use Node.js' },
  @{ name='go'; required=$false; note='External modules may use Go' },
  @{ name='docker'; required=$false; note='Optional container runs' }
)

$missing = @()

Write-Host "Runtime checklist"
Write-Host "-----------------"
foreach ($t in @($req + $opt)) {
  $ok = Has-Cmd $t.name
  $mark = if ($ok) { 'OK ' } else { 'MISS' }
  $reqtxt = if ($t.required) { 'required' } else { 'optional' }
  Write-Host ("{0}  {1}  ({2}) - {3}" -f $mark, $t.name, $reqtxt, $t.note)
  if (-not $ok -and $t.required) { $missing += $t.name }
}

if ($Verify -and $missing.Count -gt 0) {
  throw ("Missing required tools: " + ($missing -join ', '))
}

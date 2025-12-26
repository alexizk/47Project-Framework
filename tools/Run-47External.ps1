Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)]
  [string]$FilePath,
  [string[]]$ArgumentList = @(),
  [int]$TimeoutSeconds = 300,
  [string]$WorkingDirectory
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

$r = Invoke-47External -FilePath $FilePath -ArgumentList $ArgumentList -TimeoutSeconds $TimeoutSeconds -WorkingDirectory $WorkingDirectory
$r.StdOut
if ($r.StdErr) { Write-Error $r.StdErr }
exit $r.ExitCode

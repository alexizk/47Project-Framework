# Invoke-47Bench.ps1
# Lightweight benchmark harness for cold-start and module discovery.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [int]$Iterations = 5,
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Import-Module -Force (Join-Path $PackRoot 'Framework\Core\47.Core.psd1')

$results = @()

for ($i=1; $i -le $Iterations; $i++) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $mods = Get-47Modules
  $sw.Stop()
  $results += [pscustomobject]@{ iteration=$i; ms=$sw.ElapsedMilliseconds; moduleCount=$mods.Count }
}

$avg = [math]::Round(($results | Measure-Object -Property ms -Average).Average, 2)
Write-Host "Iterations: $Iterations"
Write-Host "Avg module discovery (ms): $avg"
$results | Format-Table -AutoSize

# 47Project Framework - Nexus Shell (CLI)
# Run: pwsh -File .\Framework\47Project.Framework.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here 'Core\47.Core.psd1')

# First-run setup (creates default config/policy if missing)
try { Invoke-47FirstRunWizard | Out-Null } catch { Write-Warning $_ }


function Show-Menu {
  Write-Host ''
  Write-Host '47Project Framework (Nexus Shell)'
  Write-Host '--------------------------------'
  Write-Host '1) List modules'
  Write-Host '2) Import a module'
  Write-Host '3) Show effective policy'
  Write-Host '4) Validate a plan (example)'
  Write-Host '6) Run a plan (WhatIf)'
  Write-Host '7) Run a plan (Apply)'
  Write-Host '8) Simulate policy against a plan'
  Write-Host '5) Build a support bundle'
  Write-Host ''
  Write-Host 'a) New module (scaffold)'
  Write-Host 'b) Build offline docs'
  Write-Host 'c) Style check'
  Write-Host '0) Exit'
  Write-Host ''
}

while ($true) {
  Show-Menu
  $choice = Read-Host 'Select'
  switch ($choice.ToLowerInvariant()) {
    '1' {
      $mods = Get-47Modules
      $mods | Sort-Object ModuleId | Format-Table ModuleId, Version, DisplayName, Entrypoint -AutoSize
    }
    '2' {
      $mods = Get-47Modules | Sort-Object ModuleId
      $mods | ForEach-Object { Write-Host " - $($_.ModuleId)" }
      $id = Read-Host 'ModuleId'
      $m = $mods | Where-Object ModuleId -eq $id | Select-Object -First 1
      if (-not $m) { Write-Warning "Module not found: $id"; break }
      Import-47Module -ModulePath $m.Path | Out-Null
      Write-Host "Imported module: $id"
    }
    '3' {
      $p = Get-47EffectivePolicy
      $p | ConvertTo-Json -Depth 20
    }
    '4' {
      $paths = Get-47Paths
      $plan = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'
      $schema = Join-Path $paths.SchemasRoot 'plan_v1.schema.json'
      if (-not (Test-Path -LiteralPath $schema)) { Write-Warning "Schema not found: $schema"; break }
      $ok = Test-Json -Json (Get-Content -Raw -LiteralPath $plan) -SchemaFile $schema
      Write-Host ("Plan valid: " + $ok)
      if ($ok) { Write-Host ("Plan hash: " + (Get-47PlanHash -PlanPath $plan)) }
    }
    '5' {
      $paths = Get-47Paths
      $tool = Join-Path $paths.ToolsRoot 'Export-47SupportBundle.ps1'
      & $tool | Out-Null
    }
    '6' {
      $paths = Get-47Paths
      $tool = Join-Path $paths.ToolsRoot 'Invoke-47Doctor.ps1'
      & $tool | Out-Null
    }

    '7' {
      $paths = Get-47Paths
      $tool = Join-Path $paths.ToolsRoot 'Save-47Snapshot.ps1'
      & $tool -IncludePack | Out-Null
    }
    '8' {
      $paths = Get-47Paths
      & (Join-Path $paths.ToolsRoot 'Get-47Snapshots.ps1') | Out-Null
    }
    '9' {
      $snaps = Get-47Snapshots
      if (-not $snaps -or $snaps.Count -eq 0) { Write-Warning 'No snapshots found.'; break }
      $last = $snaps[0].FullName
      Write-Warning "Restoring user data from: $last"
      Write-Warning "This will overwrite your current user data. Press ENTER to continue or Ctrl+C to cancel."
      [void](Read-Host)
      Restore-47Snapshot -SnapshotPath $last -Confirm:$false
    }
    'a' {
      $moduleId = Read-Host "ModuleId (e.g. mod.tools.example)"
      if (-not $moduleId) { break }
      $display = Read-Host "DisplayName [optional]"
      $desc = Read-Host "Description [optional]"
      & (Join-Path (Get-47Paths).ToolsRoot 'New-47Module.ps1') -ModuleId $moduleId -DisplayName $display -Description $desc | Out-Null
    }
    'b' {
      & (Join-Path (Get-47Paths).ToolsRoot 'Build-47Docs.ps1') | Out-Null
    }
    'c' {
      & (Join-Path (Get-47Paths).ToolsRoot 'Invoke-47StyleCheck.ps1') | Out-Null
    }

    '0' { break }
    default { Write-Warning 'Unknown selection' }
  }
}

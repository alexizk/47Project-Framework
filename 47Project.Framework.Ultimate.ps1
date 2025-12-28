<#
.SYNOPSIS
  47Project Framework - Nexus Shell (CLI)

.DESCRIPTION
  Minimal CLI shell for the 47Project Framework pack.
  Keeps the bootstrap flow stable:
    - Strict mode
    - Import core module
    - First-run wizard (creates default config/policy when missing)

  Then exposes a command-registry-driven menu with validated input handling.

.PARAMETER Help
  Show help/usage and exit.

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Menu

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Command 4 -PlanPath .\examples\plans\sample_install.plan.json -Json

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Command 6 -PlanPath .\my.plan.json -Force -Json

$script:JsonMode = [bool]$Json
$script:NonInteractive = [bool](-not [string]::IsNullOrWhiteSpace($Command))

$script:CliArgs = @{
  PlanPath      = $PlanPath
  PolicyPath    = $PolicyPath
  ModuleId      = $ModuleId
  SnapshotIndex = $SnapshotIndex
  SnapshotPath  = $SnapshotPath
  SnapshotName  = $SnapshotName
  OutPath       = $OutPath
  NewModuleId   = $NewModuleId
  DisplayName   = $DisplayName
  Description   = $Description
  Force         = [bool]$Force
}

function Get-47CliArg {
  param([Parameter(Mandatory)][string]$Name, $Default = $null)
  if ($script:CliArgs.ContainsKey($Name)) {
    $v = $script:CliArgs[$Name]
    if ($null -ne $v) {
      if ($v -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
      } else {
        return $v
      }
    }
  }
  return $Default
}

function Write-47Json {
  param([Parameter(Mandatory)]$Object, [int]$Depth = 16)
  ($Object | ConvertTo-Json -Depth $Depth)
}

function Get-47MenuModel {
  param([hashtable]$Registry)
  $Registry.Values | Sort-Object Order, Key | ForEach-Object {
    [pscustomobject]@{ key=$_.Key; label=$_.Label; category=$_.Category; order=$_.Order }
  }
}

function Invoke-47CommandKey {
  param([Parameter(Mandatory)][string]$Key)
  if ($Key -eq '0') { return $null }
  $cmd = $script:CommandRegistry[$Key]
  if (-not $cmd) { throw "Unknown command key: $Key" }
  & $cmd.Handler
}



.PARAMETER Menu
  Print the current menu/command map and exit (useful for non-interactive invocation).

.PARAMETER Command
  Run a single command by key and exit (e.g., -Command 1, -Command b).

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 4
#>

[CmdletBinding()]
param(
  [switch]$Help,
  [switch]$Menu,
  [string]$Command,

  # GUI behavior (Windows only)
  [switch]$Gui,
  [switch]$NoGui,

  # Common passthrough args for non-interactive use (-Command)
  [string]$PlanPath,
  [string]$PolicyPath,
  [string]$ModuleId,
  [int]$SnapshotIndex,
  [string]$SnapshotPath,
  [string]$SnapshotName,
  [string]$OutPath,
  [string]$NewModuleId,
  [string]$DisplayName,
  [string]$Description,

  [switch]$Force,
  [switch]$Json
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here 'Core\47.Core.psd1')

# First-run setup (creates default config/policy if missing)
try { Invoke-47FirstRunWizard | Out-Null } catch { Write-Warning $_ }

#region Helpers
function Write-47Banner {
  Write-Host ''
  Write-Host '47Project Framework (Nexus Shell)'
  Write-Host '--------------------------------'
  Write-Host ("Framework: {0}" -f (Get-47FrameworkRoot))
  Write-Host ("PackRoot : {0}" -f (Get-47PackRoot))
  Write-Host ''
}

function Get-47ToolPath {
  param([Parameter(Mandatory)][string]$Name)
  $paths = Get-47Paths
  $p = Join-Path $paths.ToolsRoot $Name
  if (-not (Test-Path -LiteralPath $p)) { throw "Tool not found: $Name ($p)" }
  $p
}

function Invoke-47Tool {
  param(
    [Parameter(Mandatory)][string]$Name,
    [hashtable]$Args = @{}
  )
  $p = Get-47ToolPath -Name $Name
  & $p @Args
}

function Read-47Choice {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string[]]$Valid,
    [string]$Default = $null
  )
  while ($true) {
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $raw = Read-Host ("{0}{1}" -f $Prompt, $suffix)
    $val = if ([string]::IsNullOrWhiteSpace($raw)) { $Default } else { $raw.Trim() }
    if ($null -eq $val) { continue }
    if ($val -in $Valid) { return $val }
    Write-Warning ("Invalid selection. Valid: {0}" -f ($Valid -join ', '))
  }
}

function Read-47Path {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [string]$Default = $null,
    [switch]$MustExist
  )
  while ($true) {
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $p = Read-Host ("{0}{1}" -f $Prompt, $suffix)
    $p = if ([string]::IsNullOrWhiteSpace($p)) { $Default } else { $p.Trim('"').Trim() }
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if ($MustExist -and -not (Test-Path -LiteralPath $p)) {
      Write-Warning "Path not found: $p"
      continue
    }
    return $p
  }
}

function Confirm-47 {
  param([Parameter(Mandatory)][string]$Message, [switch]$DefaultNo)
  $valid = @('y','n','Y','N')
  $def = if ($DefaultNo) { 'n' } else { 'y' }
  $ans = Read-47Choice -Prompt ("{0} (y/n)" -f $Message) -Valid $valid -Default $def
  return ($ans.ToLowerInvariant() -eq 'y')
}

function Write-47Menu {
  param([hashtable]$Registry)

  Write-Host 'Commands'
  Write-Host '--------'

  $items = $Registry.Values | Sort-Object Order, Key
  $groups = $items | Group-Object Category
  foreach ($g in $groups) {
    if ($g.Name) { Write-Host ("[{0}]" -f $g.Name) }
    foreach ($c in $g.Group | Sort-Object Order, Key) {
      Write-Host ("{0}) {1}" -f $c.Key, $c.Label)
    }
    Write-Host ''
  }

  Write-Host '0) Exit'
  Write-Host ''
}

function Register-47Command {
  param(
    [Parameter(Mandatory)][hashtable]$Registry,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Category,
    [Parameter(Mandatory)][int]$Order,
    [Parameter(Mandatory)][scriptblock]$Handler
  )
  $Registry[$Key] = [pscustomobject]@{
    Key=$Key; Label=$Label; Category=$Category; Order=$Order; Handler=$Handler
  }
}
#endregion Helpers

#region Tool wrappers (small functions to keep menu handler clean)
function Invoke-Doctor { Invoke-47Tool -Name 'Invoke-47Doctor.ps1' | Out-Null }
function Build-Docs   { Invoke-47Tool -Name 'Build-47Docs.ps1' | Out-Null }
function Style-Check  { Invoke-47Tool -Name 'Invoke-47StyleCheck.ps1' | Out-Null }
function Export-SupportBundle {
  $out = Get-47CliArg -Name 'OutPath' -Default $null
  if (-not $out) {
    $paths = Get-47Paths
    $out = Join-Path $paths.SupportRoot ("support_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  }
  $res = Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath=$out }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; outPath=$out; result=$res } }
  Write-Host "Support bundle: $out"
}

function Plan-Validate {
  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt 'Plan file to validate' -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $v = Invoke-47Tool -Name 'Validate-47Plan.ps1' -Args @{ PlanPath=$plan }
  $hash = $null
  try { $hash = Invoke-47Tool -Name 'Get-47PlanHash.ps1' -Args @{ PlanPath=$plan } } catch { }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; planPath=$plan; validated=$true; hash=$hash; toolResult=$v } }
  if ($hash) { Write-Host ("Plan hash: {0}" -f $hash) }
}

function Plan-Run {
  param([ValidateSet('WhatIf','Apply')][string]$Mode)

  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt "Plan file to run ($Mode)" -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $policy = Get-47CliArg -Name 'PolicyPath' -Default $null
  if (-not $policy -and -not $script:NonInteractive) {
    $policy = Read-47Path -Prompt 'Policy file [optional]' -Default ''
  }
  if ($policy -and -not (Test-Path -LiteralPath $policy)) { throw "PolicyPath not found: $policy" }

  if ($Mode -eq 'Apply') {
    if ($script:NonInteractive) {
      if (-not (Get-47CliArg -Name 'Force' -Default $false)) {
        throw "Refusing to apply plan non-interactively without -Force."
      }
    } else {
      if (-not (Confirm-47 -Message "Apply plan now? This can modify the system." -DefaultNo)) { return }
    }
  }

  $args = @{ PlanPath=$plan; Mode=$Mode }
  if ($policy) { $args.PolicyPath = $policy }

  $res = Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; mode=$Mode; planPath=$plan; policyPath=$policy; result=$res } }
}

function Policy-ShowEffective {
  $p = Get-47EffectivePolicy
  $p | ConvertTo-Json -Depth 20
}

function Policy-Simulate {
  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt 'Plan file to simulate policy against' -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $policy = Get-47CliArg -Name 'PolicyPath' -Default $null
  if (-not $policy) {
    $policy = Read-47Path -Prompt 'Policy file [optional]' -Default ''
  }
  $args = @{ PlanPath=$plan }
  if (-not [string]::IsNullOrWhiteSpace($policy)) {
    if (-not (Test-Path -LiteralPath $policy)) { throw "PolicyPath not found: $policy" }
    $args.PolicyPath = $policy
  }

  $res = Invoke-47Tool -Name 'Simulate-47Policy.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; planPath=$plan; policyPath=$policy; result=$res } }
}

function Modules-List {
  Get-47Modules | Select-Object Id, Name, Version, Description | Format-Table -AutoSize
}

function Modules-Import {
  $mods = @(Get-47Modules)
  if (-not $mods -or $mods.Count -eq 0) { Write-Warning 'No modules found.'; return }

  $mods | Select-Object Id, Name, Version | Format-Table -AutoSize

  $id = Get-47CliArg -Name 'ModuleId' -Default $null
  if (-not $id) {
    $id = Read-Host 'Module Id to import'
    $id = $id.Trim()
  } else { $id = $id.Trim() }

  if ([string]::IsNullOrWhiteSpace($id)) { return }
  if (-not ($mods.Id -contains $id)) { throw "Unknown module id: $id" }

  Import-47Module -Id $id | Out-Null
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; moduleId=$id } }
  Write-Host "Imported: $id"
}

function Snapshots-Save {
  $name = Get-47CliArg -Name 'SnapshotName' -Default $null
  $args = @{ IncludePack=$true }
  if ($name) { $args.Name = $name }
  $res = Invoke-47Tool -Name 'Save-47Snapshot.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; name=$name; result=$res } }
}

function Snapshots-List {
  Invoke-47Tool -Name 'Get-47Snapshots.ps1' | Out-Null
}

function Snapshots-Restore {
  $path = Get-47CliArg -Name 'SnapshotPath' -Default $null
  $ix = Get-47CliArg -Name 'SnapshotIndex' -Default $null

  if ($path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "SnapshotPath not found: $path" }
    if ($script:NonInteractive -and -not (Get-47CliArg -Name 'Force' -Default $false)) {
      throw "Refusing to restore snapshot non-interactively without -Force."
    }
    if (-not $script:NonInteractive) {
      if (-not (Confirm-47 -Message ("Restore snapshot '{0}'?" -f (Split-Path -Leaf $path)) -DefaultNo)) { return }
    }
    $res = Invoke-47Tool -Name 'Restore-47Snapshot.ps1' -Args @{ SnapshotPath=$path; RestorePack=$true; RestoreMachine=$false; Force=$true }
    if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; snapshotPath=$path; result=$res } }
    return
  }

  $snaps = @(Get-47Snapshots)
  if (-not $snaps -or $snaps.Count -eq 0) { Write-Warning 'No snapshots found.'; return }

  $snaps | Select-Object Index, Name, Created, Path | Format-Table -AutoSize

  if ($null -eq $ix) { $ix = Read-Host 'Snapshot index to restore' }
  if (-not ($ix -as [int] -ge 0)) { throw 'Invalid index.' }

  $sel = $snaps | Where-Object { $_.Index -eq [int]$ix } | Select-Object -First 1
  if (-not $sel) { throw "Snapshot not found: $ix" }

  if ($script:NonInteractive -and -not (Get-47CliArg -Name 'Force' -Default $false)) {
    throw "Refusing to restore snapshot non-interactively without -Force."
  }
  if (-not $script:NonInteractive) {
    if (-not (Confirm-47 -Message ("Restore snapshot '{0}'?" -f $sel.Name) -DefaultNo)) { return }
  }

  $res = Invoke-47Tool -Name 'Restore-47Snapshot.ps1' -Args @{ SnapshotPath=$sel.Path; RestorePack=$true; RestoreMachine=$false; Force=$true }
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; snapshotIndex=[int]$ix; snapshotPath=$sel.Path; result=$res } }
}

function Modules-Scaffold {
  $moduleId = Get-47CliArg -Name 'NewModuleId' -Default $null
  if (-not $moduleId) { $moduleId = Read-Host "ModuleId (e.g. app.foo)" }
  $moduleId = $moduleId.Trim()

  if (-not ($moduleId -match '^[a-z0-9][a-z0-9\.\-_]{1,60}$')) { throw 'Invalid ModuleId format.' }

  $display = Get-47CliArg -Name 'DisplayName' -Default $null
  if (-not $display -and -not $script:NonInteractive) { $display = Read-Host "DisplayName [optional]" }

  $desc = Get-47CliArg -Name 'Description' -Default $null
  if (-not $desc -and -not $script:NonInteractive) { $desc = Read-Host "Description [optional]" }

  $res = Invoke-47Tool -Name 'New-47Module.ps1' -Args @{
    ModuleId=$moduleId
    DisplayName=$display
    Description=$desc
  }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; moduleId=$moduleId; result=$res } }
}
#endregion Tool wrappers

#region Command registry
$script:CommandRegistry = @{}
Register-47Command -Registry $script:CommandRegistry -Key '1' -Label 'List modules'                    -Category 'Modules'      -Order 10 -Handler { Modules-List }
Register-47Command -Registry $script:CommandRegistry -Key '2' -Label 'Import a module'                 -Category 'Modules'      -Order 20 -Handler { Modules-Import }
Register-47Command -Registry $script:CommandRegistry -Key '3' -Label 'Show effective policy'           -Category 'Policy'       -Order 30 -Handler { Policy-ShowEffective }
Register-47Command -Registry $script:CommandRegistry -Key '4' -Label 'Validate a plan'                 -Category 'Plans'        -Order 40 -Handler { Plan-Validate }
Register-47Command -Registry $script:CommandRegistry -Key '5' -Label 'Run a plan (WhatIf)'             -Category 'Plans'        -Order 50 -Handler { Plan-Run -Mode 'WhatIf' }
Register-47Command -Registry $script:CommandRegistry -Key '6' -Label 'Run a plan (Apply)'              -Category 'Plans'        -Order 60 -Handler { Plan-Run -Mode 'Apply' }
Register-47Command -Registry $script:CommandRegistry -Key '7' -Label 'Simulate policy against a plan'  -Category 'Policy'       -Order 70 -Handler { Policy-Simulate }
Register-47Command -Registry $script:CommandRegistry -Key '8' -Label 'Build a support bundle'          -Category 'Support'      -Order 80 -Handler { Export-SupportBundle }
Register-47Command -Registry $script:CommandRegistry -Key '9' -Label 'Run doctor (diagnostics)'        -Category 'Diagnostics'  -Order 90 -Handler { Invoke-Doctor }
Register-47Command -Registry $script:CommandRegistry -Key '10' -Label 'Save snapshot'                  -Category 'Snapshots'    -Order 100 -Handler { Snapshots-Save }
Register-47Command -Registry $script:CommandRegistry -Key '11' -Label 'List snapshots'                 -Category 'Snapshots'    -Order 110 -Handler { Snapshots-List }
Register-47Command -Registry $script:CommandRegistry -Key '12' -Label 'Restore snapshot'               -Category 'Snapshots'    -Order 120 -Handler { Snapshots-Restore }

Register-47Command -Registry $script:CommandRegistry -Key 'a' -Label 'New module (scaffold)'           -Category 'Dev Tools'    -Order 200 -Handler { Modules-Scaffold }
Register-47Command -Registry $script:CommandRegistry -Key 'b' -Label 'Build offline docs'              -Category 'Dev Tools'    -Order 210 -Handler { Build-Docs }
Register-47Command -Registry $script:CommandRegistry -Key 'c' -Label 'Style check'                     -Category 'Dev Tools'    -Order 220 -Handler { Style-Check }
#endregion Command registry

#region Entrypoints
function Show-Usage {
  Get-Help -Detailed -ErrorAction SilentlyContinue $MyInvocation.MyCommand.Path
  if ($?) { return }
  Write-Host "Usage: pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 [-Help] [-Menu] [-Gui] [-NoGui] [-Command <key>] [-Json] [passthrough args]"
}

#region GUI (Windows / WPF)
function Test-47GuiAvailable {
  if (-not $IsWindows) { return $false }
  try {
    Add-Type -AssemblyName PresentationFramework | Out-Null
    Add-Type -AssemblyName PresentationCore | Out-Null
    Add-Type -AssemblyName WindowsBase | Out-Null
    return $true
  } catch { return $false }
}

function Ensure-47StaAndRelaunchForGui {
  param([string]$ScriptPath)

  try {
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') { return $true }
  } catch { }

  $pwsh = Join-Path $PSHOME 'pwsh.exe'
  if (-not (Test-Path -LiteralPath $pwsh)) { return $false }

  $args = @('-NoLogo','-NoProfile','-STA','-File', $ScriptPath, '-Gui')
  Start-Process -FilePath $pwsh -ArgumentList $args | Out-Null
  return $false
}

function New-47GuiBrush {
  param([string]$Hex)
  return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(
    0xFF,
    [Convert]::ToByte($Hex.Substring(1,2),16),
    [Convert]::ToByte($Hex.Substring(3,2),16),
    [Convert]::ToByte($Hex.Substring(5,2),16)
  )))
}

function Show-47GuiMessage {
  param([string]$Text,[string]$Title='47Project Framework')
  [System.Windows.MessageBox]::Show($Text,$Title) | Out-Null
}


  function Show-47CommandPalette {
  try {
    $dlg = New-Object System.Windows.Window
    $dlg.Title = 'Command Palette (Ctrl+K)'
    $dlg.Width = 580
    $dlg.Height = 480
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $win
    $dlg.Background = $bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '12'

    $q = New-Object System.Windows.Controls.TextBox
    $q.Background = $panel
    $q.Foreground = $fg
    $q.BorderBrush = $accent
    $q.BorderThickness = '1'
    $q.Margin = '0,0,0,10'
    $q.Text = ''

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = 'Type to search (fuzzy). Double-click to run. Pinned/Recent shown when empty.'
    $hint.Foreground = $muted
    $hint.Margin = '0,0,0,8'

    $list = New-Object System.Windows.Controls.ListBox
    $list.Height = 350
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'

    $btns = New-Object System.Windows.Controls.WrapPanel
    $btns.Margin = '0,10,0,0'

    $btnPin = New-Object System.Windows.Controls.Button
    $btnPin.Content = 'Pin Selected'
    $btnPin.Padding = '10,6,10,6'
    $btnPin.Background = $panel
    $btnPin.Foreground = $fg
    $btnPin.BorderBrush = $accent
    $btnPin.BorderThickness = '1'
    $btnPin.Margin = '0,0,10,0'

    $btnUnpin = New-Object System.Windows.Controls.Button
    $btnUnpin.Content = 'Unpin Selected'
    $btnUnpin.Padding = '10,6,10,6'
    $btnUnpin.Background = $panel
    $btnUnpin.Foreground = $fg
    $btnUnpin.BorderBrush = $accent
    $btnUnpin.BorderThickness = '1'

    $btns.Children.Add($btnPin) | Out-Null
    $btns.Children.Add($btnUnpin) | Out-Null

    $sp.Children.Add($q) | Out-Null
    $sp.Children.Add($hint) | Out-Null
    $sp.Children.Add($list) | Out-Null
    $sp.Children.Add($btns) | Out-Null
    $dlg.Content = $sp

    $all = @()
    foreach ($k in ($pages.Keys | Sort-Object)) {
      $all += [pscustomobject]@{ Kind='Page'; Title=$k; Ref=$k }
    }
    foreach ($a in @(Get-47AppCatalog)) {
      $all += [pscustomobject]@{ Kind='App'; Title=$a.DisplayName; Ref=$a }
    }

    function GetPinnedItems {
      $pinned = @(Get-47PinnedCommands)
      $out = @()
      foreach ($p in $pinned) {
        $pi = $all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $p } | Select-Object -First 1
        if ($pi) { $out += @($pi) }
      }
      return $out
    }

    function Render {
      $list.Items.Clear()
      $s = $q.Text
      $recent = @(Get-47Recent)

      if ([string]::IsNullOrWhiteSpace($s)) {
        foreach ($p in (GetPinnedItems)) { [void]$list.Items.Add(("Pinned: " + $p.Title)) }
        foreach ($r in $recent) { [void]$list.Items.Add(("Recent: " + $r)) }
        foreach ($p2 in ($all | Where-Object { $_.Kind -eq 'Page' } | Sort-Object Title | Select-Object -First 30)) {
          [void]$list.Items.Add(("Page: " + $p2.Title))
        }
        foreach ($a2 in ($all | Where-Object { $_.Kind -eq 'App' } | Sort-Object Title | Select-Object -First 30)) {
          [void]$list.Items.Add(("App: " + $a2.Title))
        }
        return
      }

      $scored = foreach ($it in $all) {
        $t = ($it.Kind + ' ' + $it.Title)
        $score = Get-47FuzzyScore -Text $t -Query $s
        if ($score -gt -9999) { [pscustomobject]@{ Item=$it; Score=$score } }
      }

      foreach ($x in ($scored | Sort-Object Score -Descending | Select-Object -First 90)) {
        [void]$list.Items.Add(("{0}: {1}" -f $x.Item.Kind, $x.Item.Title))
      }
    }

    function ResolveItem([string]$sel) {
      if (-not $sel) { return $null }
      if ($sel.StartsWith('Pinned: ')) {
        $t = $sel.Substring(8)
        return ($all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $t } | Select-Object -First 1)
      }
      if ($sel.StartsWith('Recent: ')) {
        $t = $sel.Substring(8)
        $page = $all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $t } | Select-Object -First 1
        if ($page) { return $page }
        $app = $all | Where-Object { $_.Kind -eq 'App' -and $_.Title -eq $t } | Select-Object -First 1
        if ($app) { return $app }
        return $null
      }
      $kind = $sel.Split(':')[0].Trim()
      $title = ($sel.Substring($sel.IndexOf(':')+1)).Trim()
      return ($all | Where-Object { $_.Kind -eq $kind -and $_.Title -eq $title } | Select-Object -First 1)
    }

    function GoItem($it) {
      if (-not $it) { return }
      Add-47Recent -Entry $it.Title

      if ($it.Kind -eq 'Page') {
        $nav.SelectedItem = $it.Ref
        $dlg.Close()
        return
      }
      if ($it.Kind -eq 'App') {
        $nav.SelectedItem = 'Apps'
        try { Set-SelectedApp $it.Ref } catch { }
        $dlg.Close()
        return
      }
    }

    $q.Add_TextChanged({ Render })
    $dlg.Add_ContentRendered({ $q.Focus() | Out-Null; Render })

    $list.Add_MouseDoubleClick({
      try {
        $sel = [string]$list.SelectedItem
        $it = ResolveItem -sel $sel
        GoItem $it
      } catch { }
    })

    $btnPin.Add_Click({
      try {
        $sel = [string]$list.SelectedItem
        $it = ResolveItem -sel $sel
        if (-not $it) { return }
        if ($it.Kind -ne 'Page') { Show-47GuiMessage 'Only pages can be pinned.'; return }
        $p = @(Get-47PinnedCommands)
        if (-not ($p -contains $it.Title)) { $p = @($it.Title) + $p }
        $p = $p | Select-Object -Unique
        Save-47PinnedCommands -Pinned $p
        Render
      } catch { }
    })

    $btnUnpin.Add_Click({
      try {
        $sel = [string]$list.SelectedItem
        if (-not $sel.StartsWith('Pinned: ')) { return }
        $title = $sel.Substring(8)
        $p = @(Get-47PinnedCommands) | Where-Object { $_ -ne $title }
        Save-47PinnedCommands -Pinned $p
        Render
      } catch { }
    })

    $dlg.ShowDialog() | Out-Null
  } catch { }
}

function Get-47OpenFile {
  param([string]$Title='Select file',[string]$Filter='All files (*.*)|*.*')
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Title = $Title
  $dlg.Filter = $Filter
  if ($dlg.ShowDialog()) { return $dlg.FileName }
  return $null
}

function Get-47SaveFile {
  param([string]$Title='Save file',[string]$Filter='All files (*.*)|*.*',[string]$DefaultName=$null)
  $dlg = New-Object Microsoft.Win32.SaveFileDialog
  $dlg.Title = $Title
  $dlg.Filter = $Filter
  if ($DefaultName) { $dlg.FileName = $DefaultName }
  if ($dlg.ShowDialog()) { return $dlg.FileName }
  return $null
}

function Get-47FolderPicker {
  param([string]$Description='Select folder')
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = $Description
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
  return $null
}

function Get-47FavoritesPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'favorites.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'favorites.json')
  }
}

function Get-47Favorites {
  $fp = Get-47FavoritesPath
  if (Test-Path -LiteralPath $fp) {
    try {
      $j = Get-Content -LiteralPath $fp -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @()
}

function Save-47Favorites {
  param([Parameter(Mandatory)][string[]]$Favorites)
  $fp = Get-47FavoritesPath
  $dir = Split-Path -Parent $fp
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Favorites | Sort-Object -Unique | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $fp -Encoding utf8
}

function Get-47AppCategory {
  param([Parameter(Mandatory)][string]$Path)
  $p = $Path.ToLowerInvariant()
  if ($p -like "*\\framework\\*") { return "Framework" }
  if ($p -like "*\\tools\\*") { return "Tools" }
  if ($p -like "*\\modules\\*") { return "Modules" }
  if ($p -like "*appcrawler*") { return "AppCrawler" }
  if ($p -like "*launcher*") { return "Launcher" }
  return "Apps"
}


function Find-47IconForApp {
  param(
    [Parameter(Mandatory)][string]$AppPath,
    [string]$ModuleId = $null,
    [string]$DisplayName = $null
  )
  try {
    # module-local icon
    if ($ModuleId -and (Test-Path -LiteralPath $AppPath) -and (Test-Path -LiteralPath (Join-Path $AppPath 'icon.png'))) {
      return (Join-Path $AppPath 'icon.png')
    }
  } catch { }

  try {
    $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $assets = Join-Path $root 'assets\\icons'
    if (-not (Test-Path -LiteralPath $assets)) { return $null }

    $base = [IO.Path]::GetFileNameWithoutExtension($AppPath)
    $candNames = @()
    if ($base) { $candNames += @($base) }
    if ($ModuleId) { $candNames += @($ModuleId -replace '[^a-zA-Z0-9\.\-_]','') }
    if ($DisplayName) { $candNames += @($DisplayName -replace '\s+','') }
    # folder name
    try {
      $d = Split-Path -Parent $AppPath
      $candNames += @([IO.Path]::GetFileName($d))
    } catch { }

    $candNames = $candNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($n in $candNames) {
      foreach ($ext in @('png','jpg','jpeg','ico')) {
        $c = Join-Path $assets ($n + '.' + $ext)
        if (Test-Path -LiteralPath $c) { return $c }
      }
    }
  } catch { }
  return $null
}




function Get-47AppCatalog {
  # Discover scripts and modules in the pack and enrich with metadata.
  $root = Split-Path -Parent $MyInvocation.MyCommand.Path
  $root2 = Split-Path -Parent $root

  $patterns = @(
    '47Project.*.ps1',
    'Project47_*.ps1',
    '*AppCrawler*.ps1',
    '*Launcher*.ps1',
    '*Nexus*.ps1'
  )

  $scriptItems = @()
  foreach ($pat in $patterns) {
    $scriptItems += Get-ChildItem -LiteralPath $root2 -Filter $pat -File -ErrorAction SilentlyContinue
  }
  $scriptItems = $scriptItems | Sort-Object FullName -Unique

  $apps = @()

  foreach ($it in $scriptItems) {
    $m = Get-47AppMetadata -Path $it.FullName
    $apps += [pscustomobject]@{
      Type              = 'script'
      Id                = $it.FullName
      Name              = $m.Name
      DisplayName       = $m.Name
      Description       = $m.Description
      Version           = $m.Version
      Kind              = $m.Kind
      Path              = $it.FullName
      Category          = (Get-47AppCategory -Path $it.FullName)
      ModuleId          = $null
      ModuleDir         = $null
      EntryPath         = $it.FullName
      SupportedPlatforms= $null
      MinPowerShellVersion = $null
      RequiresAdmin     = $false
    }
  }

  # Modules (modules/<folder>/module.json)
  $modsDir = Join-Path $root2 'modules'
  if (Test-Path -LiteralPath $modsDir) {
    foreach ($d in (Get-ChildItem -LiteralPath $modsDir -Directory -ErrorAction SilentlyContinue)) {
      $j = Read-47ModuleJson -ModuleDir $d.FullName
      if (-not $j) { continue }

      $entry = $null
      try {
        if ($j.entrypoint) {
          $ep = Join-Path $d.FullName ([string]$j.entrypoint)
          if (Test-Path -LiteralPath $ep) { $entry = $ep }
        }
      } catch { }

      $sp = $null
      try { $sp = $j.supportedPlatforms } catch { }
      $minPs = $null
      try { $minPs = $j.minPowerShellVersion } catch { }

      $apps += [pscustomobject]@{
        Type              = 'module'
        Id                = [string]$j.moduleId
        Name              = $d.Name
        DisplayName       = ([string]$j.displayName)
        Description       = ([string]$j.description)
        Version           = ([string]$j.version)
        Kind              = 'Module'
        Path              = $d.FullName
        Category          = 'Modules'
        ModuleId          = ([string]$j.moduleId)
        ModuleDir         = $d.FullName
        EntryPath         = $entry
        SupportedPlatforms= $sp
        MinPowerShellVersion = $minPs
        RequiresAdmin     = $false
      }
    }
  }

  return ($apps | Sort-Object Category, DisplayName)
}



function Read-47Theme {
  # Optional theme file: data/theme.json (created by you later), else defaults
  $t = @{
    Background = '#0F1115'
    Panel      = '#141824'
    Foreground = '#E6EAF2'
    Muted      = '#9AA4B2'
    Accent     = '#00FF7B'
    Warning    = '#FFB020'
  }
  try {
    $paths = Get-47Paths
    $themePath = Join-Path $paths.DataRoot 'theme.json'
    if (Test-Path -LiteralPath $themePath) {
      $j = Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json
      foreach ($k in @('Background','Panel','Foreground','Muted','Accent','Warning')) {
        if ($j.$k) { $t[$k] = [string]$j.$k }
      }
    }
  } catch { }
  return $t
}

function Test-47IsAdmin {
  if (-not $IsWindows) { return $false }
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Test-47HasCommand {
  param([Parameter(Mandatory)][string]$Name)
  try { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) } catch { return $false }
}

function Get-47DockerStatus {
  try {
    if (-not (Test-47HasCommand -Name 'docker')) { return 'missing' }
    $null = & docker info 2>$null
    return 'ok'
  } catch { return 'not-running' }
}

function Get-47WingetStatus {
  if (-not $IsWindows) { return 'n/a' }
  try {
    if (Test-47HasCommand -Name 'winget') { return 'ok' }
    return 'missing'
  } catch { return 'unknown' }
}

function Get-47LastSnapshotInfo {
  try {
    $s = @(Get-47Snapshots) | Sort-Object Created -Descending | Select-Object -First 1
    return $s
  } catch { return $null }
}

function Get-47HostStatus {
  $o = [ordered]@{}
  try { $o.PwshVersion = $PSVersionTable.PSVersion.ToString() } catch { $o.PwshVersion = '' }
  $o.IsWindows = [bool]$IsWindows
  $o.IsAdmin = [bool](Test-47IsAdmin)
  $o.WpfAvailable = [bool](Test-47GuiAvailable)
  $o.Docker = (Get-47DockerStatus)
  $o.Winget = (Get-47WingetStatus)
  $o.LastSnapshot = (Get-47LastSnapshotInfo)
  return [pscustomobject]$o
}

function Get-47AppProfilesPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'app-profiles.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'app-profiles.json')
  }
}

function Get-47AppProfiles {
  $fp = Get-47AppProfilesPath
  if (Test-Path -LiteralPath $fp) {
    try {
      $j = Get-Content -LiteralPath $fp -Raw | ConvertFrom-Json
      if ($j) { return $j }
    } catch { }
  }
  return @{}
}

function Save-47AppProfiles {
  param([Parameter(Mandatory)]$Profiles)
  $fp = Get-47AppProfilesPath
  $dir = Split-Path -Parent $fp
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Profiles | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $fp -Encoding utf8
}

function Get-47ModuleSettingsPath {
  param([Parameter(Mandatory)][string]$ModuleId)
  $paths = Get-47Paths
  $dir = Join-Path $paths.DataRoot 'module-settings'
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  return (Join-Path $dir ($ModuleId + '.json'))
}

function Get-47ModuleSettings {
  param([Parameter(Mandatory)][string]$ModuleId)
  $p = Get-47ModuleSettingsPath -ModuleId $ModuleId
  if (Test-Path -LiteralPath $p) {
    try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { }
  }
  return @{}
}

function Save-47ModuleSettings {
  param([Parameter(Mandatory)][string]$ModuleId,[Parameter(Mandatory)]$Settings)
  $p = Get-47ModuleSettingsPath -ModuleId $ModuleId
  ($Settings | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $p -Encoding utf8
}


function Read-47PsHelpSummary {
  param([Parameter(Mandatory)][string]$Path)

  $syn = ''
  $desc = ''
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Synopsis=''; Description='' } }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return [pscustomobject]@{ Synopsis=''; Description='' } }

    $m1 = [regex]::Match($raw, '(?ms)^\s*\.SYNOPSIS\s*$\s*(.+?)\s*(?:\r?\n\s*\.\w+|\r?\n\s*#>)')
    if ($m1.Success) { $syn = ($m1.Groups[1].Value -replace '\s+',' ').Trim() }

    $m2 = [regex]::Match($raw, '(?ms)^\s*\.DESCRIPTION\s*$\s*(.+?)\s*(?:\r?\n\s*\.\w+|\r?\n\s*#>)')
    if ($m2.Success) {
      $desc = ($m2.Groups[1].Value -replace '\s+',' ').Trim()
      if ($desc.Length -gt 180) { $desc = $desc.Substring(0,180) + '...' }
    }
  } catch { }

  return [pscustomobject]@{ Synopsis=$syn; Description=$desc }
}

function Read-47ModuleJson {
  param([Parameter(Mandatory)][string]$ModuleDir)

  $mj = Join-Path $ModuleDir 'module.json'
  if (-not (Test-Path -LiteralPath $mj)) { return $null }

  try {
    $j = Get-Content -LiteralPath $mj -Raw | ConvertFrom-Json
    return $j
  } catch { return $null }
}


function Get-47AppMetadata {
  param([Parameter(Mandatory)][string]$Path)

  $name = [IO.Path]::GetFileNameWithoutExtension($Path)
  $desc = ''
  $ver = ''
  $kind = 'PowerShell'
  try {
    $h = Read-47PsHelpSummary -Path $Path
    if ($h.Synopsis) { $desc = $h.Synopsis }
    elseif ($h.Description) { $desc = $h.Description }

    if (-not $ver) {
      $raw = Get-Content -LiteralPath $Path -TotalCount 120 -ErrorAction SilentlyContinue
      if ($raw) {
        $t = ($raw -join "`n")
        $m2 = [regex]::Match($t, '(?m)^\s*\#\s*Version\s*:\s*(.+)$')
        if ($m2.Success) { $ver = $m2.Groups[1].Value.Trim() }
      }
    }
  } catch { }

  return [pscustomobject]@{ Name=$name; Description=$desc; Version=$ver; Kind=$kind; Path=$Path }
}


function Confirm-47Typed {
  param([Parameter(Mandatory)][string]$Title,[Parameter(Mandatory)][string]$Prompt,[Parameter(Mandatory)][string]$Token)
  try {
    $w = New-Object System.Windows.Window
    $w.Title = $Title
    $w.Width = 420
    $w.Height = 200
    $w.WindowStartupLocation = 'CenterOwner'
    $w.ResizeMode = 'NoResize'
    $w.Background = (New-47GuiBrush '#141824')

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '12'

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Prompt + "`n`nType: " + $Token
    $t.TextWrapping = 'Wrap'
    $t.Foreground = (New-47GuiBrush '#E6EAF2')
    $t.Margin = '0,0,0,10'

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.BorderBrush = (New-47GuiBrush '#00FF7B')
    $tb.BorderThickness = '1'
    $tb.Background = (New-47GuiBrush '#0F1115')
    $tb.Foreground = (New-47GuiBrush '#E6EAF2')
    $tb.Margin = '0,0,0,10'

    $row = New-Object System.Windows.Controls.WrapPanel
    $ok = New-Object System.Windows.Controls.Button
    $ok.Content = 'Confirm'
    $ok.Padding = '12,6,12,6'
    $ok.BorderBrush = (New-47GuiBrush '#00FF7B')
    $ok.BorderThickness = '1'
    $ok.Background = (New-47GuiBrush '#141824')
    $ok.Foreground = (New-47GuiBrush '#E6EAF2')

    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content = 'Cancel'
    $cancel.Padding = '12,6,12,6'
    $cancel.Margin = '10,0,0,0'
    $cancel.BorderBrush = (New-47GuiBrush '#00FF7B')
    $cancel.BorderThickness = '1'
    $cancel.Background = (New-47GuiBrush '#141824')
    $cancel.Foreground = (New-47GuiBrush '#E6EAF2')

    $result = $false
    $ok.Add_Click({
      if ($tb.Text -eq $Token) { $result = $true; $w.Close() }
      else { [System.Windows.MessageBox]::Show("Token mismatch.","Confirm") | Out-Null }
    })
    $cancel.Add_Click({ $w.Close() })

    $row.Children.Add($ok) | Out-Null
    $row.Children.Add($cancel) | Out-Null

    $sp.Children.Add($t) | Out-Null
    $sp.Children.Add($tb) | Out-Null
    $sp.Children.Add($row) | Out-Null

    $w.Content = $sp
    $w.ShowDialog() | Out-Null
    return $result
  } catch { return $false }
}


function Get-47ProjectRoot {
  $root = Split-Path -Parent $MyInvocation.MyCommand.Path
  return (Split-Path -Parent $root)
}

function Compare-47FolderDiff {
  param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Target)

  $srcFiles = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue
  $tgtFiles = Get-ChildItem -LiteralPath $Target -Recurse -File -ErrorAction SilentlyContinue

  $srcRel = @{}
  foreach ($f in $srcFiles) { $srcRel[$f.FullName.Substring($Source.Length).TrimStart('\','/')] = $f }
  $tgtRel = @{}
  foreach ($f in $tgtFiles) { $tgtRel[$f.FullName.Substring($Target.Length).TrimStart('\','/')] = $f }

  $added = @()
  $changed = @()
  $same = @()
  foreach ($k in $srcRel.Keys) {
    if (-not $tgtRel.ContainsKey($k)) { $added += @($k); continue }
    try {
      $sf = $srcRel[$k]; $tf = $tgtRel[$k]
      if ($sf.Length -ne $tf.Length -or $sf.LastWriteTimeUtc -ne $tf.LastWriteTimeUtc) { $changed += @($k) } else { $same += @($k) }
    } catch { $changed += @($k) }
  }

  $extra = @()
  foreach ($k in $tgtRel.Keys) {
    if (-not $srcRel.ContainsKey($k)) { $extra += @($k) }
  }

  return [pscustomobject]@{
    Added = $added
    Changed = $changed
    Same = $same
    ExtraInTarget = $extra
  }
}

function Compare-47FolderSummary {
  param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Target)
  $srcFiles = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue
  $tgtFiles = Get-ChildItem -LiteralPath $Target -Recurse -File -ErrorAction SilentlyContinue
  $srcRel = @{}
  foreach ($f in $srcFiles) { $srcRel[$f.FullName.Substring($Source.Length).TrimStart('\','/')] = $f }
  $tgtRel = @{}
  foreach ($f in $tgtFiles) { $tgtRel[$f.FullName.Substring($Target.Length).TrimStart('\','/')] = $f }

  $new = 0; $changed = 0; $same = 0
  foreach ($k in $srcRel.Keys) {
    if (-not $tgtRel.ContainsKey($k)) { $new++ ; continue }
    try {
      $sf = $srcRel[$k]; $tf = $tgtRel[$k]
      if ($sf.Length -ne $tf.Length -or $sf.LastWriteTimeUtc -ne $tf.LastWriteTimeUtc) { $changed++ } else { $same++ }
    } catch { $changed++ }
  }
  return [pscustomobject]@{ New=$new; Changed=$changed; Same=$same; Source=$Source; Target=$Target }
}

function Apply-47StagedPack {
  param([Parameter(Mandatory)][string]$StageDir)

  $target = Get-47ProjectRoot
  if (-not (Test-Path -LiteralPath $StageDir)) { throw "Stage folder not found." }

  # Safe: copy only new/changed from stage to target, do not delete target files.
  if ($IsWindows -and (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    & robocopy $StageDir $target /E /XO /XN /XC /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
  } else {
    $files = Get-ChildItem -LiteralPath $StageDir -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
      $rel = $f.FullName.Substring($StageDir.Length).TrimStart('\','/')
      $dest = Join-Path $target $rel
      $dir = Split-Path -Parent $dest
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
  }
}


function Get-47RecentPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'recent.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'recent.json')
  }
}

function Get-47Recent {
  $p = Get-47RecentPath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @()
}

function Add-47Recent {
  param([Parameter(Mandatory)][string]$Entry)
  try {
    $cur = @(Get-47Recent)
    $cur = @($Entry) + @($cur | Where-Object { $_ -ne $Entry })
    if ($cur.Count -gt 30) { $cur = $cur[0..29] }
    $p = Get-47RecentPath
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($cur | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $p -Encoding utf8
  } catch { }
}

function Get-47FuzzyScore {
  param([Parameter(Mandatory)][string]$Text,[Parameter(Mandatory)][string]$Query)

  $t = $Text.ToLowerInvariant()
  $q = $Query.ToLowerInvariant().Trim()
  if ([string]::IsNullOrWhiteSpace($q)) { return 0 }

  $tokens = $q -split '\s+' | Where-Object { $_ }
  $score = 0
  foreach ($tok in $tokens) {
    $idx = $t.IndexOf($tok)
    if ($idx -lt 0) { return -9999 }
    $score += (200 - [Math]::Min(200,$idx))
    if ($idx -eq 0) { $score += 80 }
  }

  if ($t -like "*$q*") { $score += 60 }
  return $score
}

function Get-47UiStatePath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'ui-state.json')
}

function Get-47SafeModePath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'safe-mode.json')
}

function Get-47UiState {
  $p = Get-47UiStatePath
  if (Test-Path -LiteralPath $p) {
    try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { }
  }
  return [pscustomobject]@{}
}

function Save-47UiState {
  param([Parameter(Mandatory)]$State)
  $p = Get-47UiStatePath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($State | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $p -Encoding utf8
}

function Get-47SafeMode {
  $p = Get-47SafeModePath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -and $j.enabled -ne $null) { return [bool]$j.enabled }
    } catch { }
  }
  return $false
}

function Set-47SafeMode {
  param([Parameter(Mandatory)][bool]$Enabled)
  $p = Get-47SafeModePath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ([pscustomobject]@{ enabled = $Enabled; updated = (Get-Date) } | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $p -Encoding utf8
}

function Export-47UserConfig {
  param([Parameter(Mandatory)][string]$OutZip)
  $paths = Get-47Paths
  $root = $paths.DataRoot

  $tmp = Join-Path $root ('_export_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null

  $items = @(
    'favorites.json',
    'recent.json',
    'ui-state.json',
    'app-profiles.json',
    'safe-mode.json'
  )

  foreach ($i in $items) {
    $src = Join-Path $root $i
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination (Join-Path $tmp $i) -Force
    }
  }

  $ms = Join-Path $root 'module-settings'
  if (Test-Path -LiteralPath $ms) {
    Copy-Item -LiteralPath $ms -Destination (Join-Path $tmp 'module-settings') -Recurse -Force
  }

  if (Test-Path -LiteralPath $OutZip) { Remove-Item -LiteralPath $OutZip -Force }
  Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $OutZip -Force
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

function Import-47UserConfig {
  param([Parameter(Mandatory)][string]$InZip)
  $paths = Get-47Paths
  $root = $paths.DataRoot

  $tmp = Join-Path $root ('_import_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  Expand-Archive -LiteralPath $InZip -DestinationPath $tmp -Force

  # Backup current config
  $backup = Join-Path $root ('backup_config_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
  try { Export-47UserConfig -OutZip $backup } catch { }

  foreach ($f in (Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue)) {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $root $f.Name) -Force
  }
  $ms = Join-Path $tmp 'module-settings'
  if (Test-Path -LiteralPath $ms) {
    $dst = Join-Path $root 'module-settings'
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $ms '*') -Destination $dst -Recurse -Force
  }

  Remove-Item -LiteralPath $tmp -Recurse -Force
  return $backup
}

function Get-47PinnedCommandsPath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'pinned-commands.json')
}

function Get-47PinnedCommands {
  $p = Get-47PinnedCommandsPath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @('Doctor','Verify','Support','Pack Manager')
}

function Save-47PinnedCommands {
  param([Parameter(Mandatory)]$Pinned)
  $p = Get-47PinnedCommandsPath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Pinned | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $p -Encoding utf8
}

function Show-47Gui {
  if (-not (Test-47GuiAvailable)) { Write-Warning "GUI not available on this platform/host. Falling back to CLI."; return $false }
  $scriptPath = $MyInvocation.MyCommand.Path
  if (-not (Ensure-47StaAndRelaunchForGui -ScriptPath $scriptPath)) { return $true } # relaunched; exit current  # Theme
  $theme = Read-47Theme
  $bg = New-47GuiBrush $theme.Background
  $panel = New-47GuiBrush $theme.Panel
  $fg = New-47GuiBrush $theme.Foreground
  $muted = New-47GuiBrush $theme.Muted
  $accent = New-47GuiBrush $theme.Accent
  $warn = New-47GuiBrush $theme.Warning

  # Window
  $win = New-Object System.Windows.Window
  $win.Title = '47Project Framework'

  # Load UI state (size/position/last page/filters)
  $script:UiState = Get-47UiState
  try {
    if ($script:UiState.WindowWidth) { $win.Width = [double]$script:UiState.WindowWidth }
    if ($script:UiState.WindowHeight) { $win.Height = [double]$script:UiState.WindowHeight }
    if ($script:UiState.WindowLeft -ne $null) { $win.Left = [double]$script:UiState.WindowLeft }
    if ($script:UiState.WindowTop -ne $null) { $win.Top = [double]$script:UiState.WindowTop }
    if ($script:UiState.WindowState) { $win.WindowState = $script:UiState.WindowState }
  } catch { }

  $win.Width = 1080
  $win.Height = 720
  $win.Background = $bg
  $win.WindowStartupLocation = 'CenterScreen'

  $grid = New-Object System.Windows.Controls.Grid
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = '56' })) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = '*' })) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = 'Auto' })) | Out-Null

  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '240' })) | Out-Null
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '*' })) | Out-Null

  # Header
  $hdr = New-Object System.Windows.Controls.Border
  $hdr.Background = $panel
  $hdr.BorderBrush = $accent
  $hdr.BorderThickness = '0,0,0,2'
  [System.Windows.Controls.Grid]::SetRow($hdr,0)
  [System.Windows.Controls.Grid]::SetColumnSpan($hdr,2)

  $hdrGrid = New-Object System.Windows.Controls.Grid
  $hdrGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='*' })) | Out-Null
  $hdrGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='Auto' })) | Out-Null

  $title = New-Object System.Windows.Controls.TextBlock
  $title.Text = '47Project Framework'
  $title.Margin = '16,14,0,0'
  $title.FontSize = 18
  $title.FontWeight = 'SemiBold'
  $title.Foreground = $fg

  $sub = New-Object System.Windows.Controls.TextBlock
  $sub.Text = 'Nexus Shell * Plans * Modules * Trust * Bundles * Snapshots'
  $sub.Margin = '16,32,0,0'
  $sub.FontSize = 11
  $sub.Foreground = $muted

  $btnRow = New-Object System.Windows.Controls.StackPanel
  $btnRow.Orientation = 'Horizontal'
  $btnRow.Margin = '0,10,16,0'
  [System.Windows.Controls.Grid]::SetColumn($btnRow,1)

  function New-47TopButton([string]$text,[scriptblock]$onClick) {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $text
    $b.Margin = '8,0,0,0'
    $b.Padding = '12,6,12,6'
    $b.Background = $bg
    $b.Foreground = $fg
    $b.BorderBrush = $accent
    $b.BorderThickness = '1'
    $b.Add_Click({ & $onClick })
    return $b
  }

  $btnRow.Children.Add((New-47TopButton 'Open Data' {
    try { $paths = Get-47Paths; Start-Process $paths.DataRoot | Out-Null } catch { Show-47GuiMessage $_.Exception.Message }
  })) | Out-Null

  $btnRow.Children.Add((New-47TopButton 'Help' {
    Show-47GuiMessage "Use the left navigation.\n\nNon-interactive CLI: -Menu / -Command / -Json.\nDestructive actions require -Force when non-interactive."
  })) | Out-Null

  $btnRow.Children.Add((New-47TopButton 'Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Support' { $nav.SelectedItem = 'Support' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Pack' { $nav.SelectedItem = 'Pack Manager' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Tasks' { $nav.SelectedItem = 'Tasks' })) | Out-Null


  $hdrGrid.Children.Add($title) | Out-Null
  $hdrGrid.Children.Add($sub) | Out-Null
  $hdrGrid.Children.Add($btnRow) | Out-Null

  # Safe Mode toggle (disables destructive actions)
  $script:SafeMode = Get-47SafeMode
  $safeBox = New-Object System.Windows.Controls.CheckBox
  $safeBox.Content = 'Safe Mode'
  $safeBox.Foreground = $fg
  $safeBox.Margin = '12,2,0,0'
  $safeBox.IsChecked = $script:SafeMode
  $safeBox.ToolTip = 'When enabled: disables Apply/Restore/Update actions.'
  $safeBox.Add_Click({
    $script:SafeMode = [bool]$safeBox.IsChecked
    Set-47SafeMode -Enabled $script:SafeMode
    try { Update-47ActionGates } catch { }
  })
  [System.Windows.Controls.Grid]::SetColumn($safeBox,1)
  [System.Windows.Controls.Grid]::SetRow($safeBox,0)
  $hdrGrid.Children.Add($safeBox) | Out-Null

  $hdr.Child = $hdrGrid

  # Left nav
  $navBorder = New-Object System.Windows.Controls.Border
  $navBorder.Background = $panel
  $navBorder.BorderBrush = $panel
  $navBorder.BorderThickness = '0,0,1,0'
  [System.Windows.Controls.Grid]::SetRow($navBorder,1)
  [System.Windows.Controls.Grid]::SetColumn($navBorder,0)

  $navStack = New-Object System.Windows.Controls.StackPanel
  $navStack.Margin = '12'

  $navLabel = New-Object System.Windows.Controls.TextBlock
  $navLabel.Text = 'Nexus'
  $navLabel.Foreground = $accent
  $navLabel.FontSize = 12
  $navLabel.FontWeight = 'SemiBold'
  $navLabel.Margin = '4,0,0,8'
  $navStack.Children.Add($navLabel) | Out-Null

  $nav = New-Object System.Windows.Controls.ListBox
  $nav.Height = 520
  $nav.Background = $panel
  $nav.Foreground = $fg
  $nav.BorderBrush = $bg
  $nav.BorderThickness = '0'
  $navStack.Children.Add($nav) | Out-Null
  $navBorder.Child = $navStack

  # Right content + console
  $rightGrid = New-Object System.Windows.Controls.Grid
  $rightGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='*' })) | Out-Null
  $rightGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='Auto' })) | Out-Null
  [System.Windows.Controls.Grid]::SetRow($rightGrid,1)
  [System.Windows.Controls.Grid]::SetColumn($rightGrid,1)

  $contentBorder = New-Object System.Windows.Controls.Border
  $contentBorder.Background = $bg
  $contentBorder.Padding = '16'
  [System.Windows.Controls.Grid]::SetRow($contentBorder,0)

  $contentHost = New-Object System.Windows.Controls.ContentControl
  $contentBorder.Child = $contentHost

  $consoleExp = New-Object System.Windows.Controls.Expander
  $consoleExp.Header = 'Console'
  $consoleExp.IsExpanded = $false
  $consoleExp.Margin = '16,0,16,12'
  $consoleExp.Foreground = $fg
  [System.Windows.Controls.Grid]::SetRow($consoleExp,1)

  $consoleBox = New-Object System.Windows.Controls.TextBox
  $consoleBox.Height = 140
  $consoleBox.Background = $panel
  $consoleBox.Foreground = $fg
  $consoleBox.IsReadOnly = $true
  $consoleBox.TextWrapping = 'Wrap'
  $consoleBox.VerticalScrollBarVisibility = 'Auto'
  $consoleBox.BorderBrush = $accent
  $consoleBox.BorderThickness = '1'
  $consoleExp.Content = $consoleBox

  $rightGrid.Children.Add($contentBorder) | Out-Null
  $rightGrid.Children.Add($consoleExp) | Out-Null

  # Status bar
  $status = New-Object System.Windows.Controls.Border
  $status.Background = $panel
  $status.Padding = '12,8,12,8'
  [System.Windows.Controls.Grid]::SetRow($status,2)
  [System.Windows.Controls.Grid]::SetColumnSpan($status,2)

  $statusText = New-Object System.Windows.Controls.TextBlock
  $statusText.Foreground = $muted
  $statusText.Text = 'Ready.'
  $status.Child = $statusText

    function Get-47LogFilePath {
    try {
      $paths = Get-47Paths
      $dir = Join-Path $paths.DataRoot 'logs'
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $fn = (Get-Date -Format 'yyyy-MM-dd') + '.log'
      return (Join-Path $dir $fn)
    } catch {
      return $null
    }
  }

  function GuiLog([string]$line,[string]$level='INFO') {
    $ts = Get-Date -Format 'HH:mm:ss'
    $msg = ("[{0}][{1}] {2}" -f $ts, $level, $line)
    $consoleBox.AppendText($msg + "`r`n")
    $consoleBox.ScrollToEnd()

    try {
      $lp = Get-47LogFilePath
      if ($lp) { Add-Content -LiteralPath $lp -Value $msg -Encoding utf8 }
    } catch { }
  }

  function Open-47LatestLog {
    try {
      $paths = Get-47Paths
      $dir = Join-Path $paths.DataRoot 'logs'
      if (-not (Test-Path -LiteralPath $dir)) { return }
      $f = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($f) { Start-Process $f.FullName | Out-Null }
    } catch { }
  }

  function GuiRun([string]$label,[scriptblock]$op) {
    try {
      $statusText.Text = $label
      GuiLog $label 'INFO'
      $r = & $op
      if ($null -ne $r) { GuiLog ($r | Out-String).TrimEnd() 'INFO' }
      $statusText.Text = 'Ready.'
    } catch {
      $statusText.Text = 'Error.'
      GuiLog $_.Exception.Message 'ERROR'
      Show-47GuiMessage $_.Exception.Message
      $statusText.Text = 'Ready.'
    }
  
  # Task runner (non-blocking)
  $script:GuiTasks = @()
  function Add-GuiTaskItem([pscustomobject]$t) {
    # t: Id, Name, State, Started, Ended, CanCancel, Ps
    $script:GuiTasks += @($t)
    try {
      if ($script:TaskList) {
        $script:TaskList.Items.Clear()
        foreach ($x in $script:GuiTasks) {
          [void]$script:TaskList.Items.Add(("{0} | {1} | {2}" -f $x.Id, $x.State, $x.Name))
        }
      }
    } catch { }
  }

  function Refresh-GuiTasks {
    try {
      if ($script:TaskList) {
        $script:TaskList.Items.Clear()
        foreach ($x in $script:GuiTasks) {
          [void]$script:TaskList.Items.Add(("{0} | {1} | {2}" -f $x.Id, $x.State, $x.Name))
        }
      }
    } catch { }
  }

  function Start-47Task([string]$name,[scriptblock]$op) {
    $id = (Get-Date -Format 'HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6))
    $t = [pscustomobject]@{ Id=$id; Name=$name; State='Running'; Started=(Get-Date); Ended=$null; CanCancel=$true; Ps=$null }
    Add-GuiTaskItem $t
    GuiLog ("Task started: " + $name) 'INFO'
    $ps = [PowerShell]::Create()
    $t.Ps = $ps
    $ps.AddScript($op) | Out-Null

    $cb = {
      param($ar)
      try {
        $output = $ps.EndInvoke($ar)
        $t.State = 'Done'
        $t.Ended = Get-Date
        if ($output) { GuiLog (($output | Out-String).TrimEnd()) 'INFO' }
      } catch {
        $t.State = 'Error'
        $t.Ended = Get-Date
        GuiLog $_.Exception.Message 'ERROR'
      } finally {
        $t.CanCancel = $false
        try { $ps.Dispose() } catch { }
        try { $win.Dispatcher.Invoke([action]{ Refresh-GuiTasks }) } catch { }
      }
    }

    $ar = $ps.BeginInvoke()
    # poll completion using dispatcher timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
      if ($ar.IsCompleted) {
        $timer.Stop()
        & $cb $ar
      }
    })
    $timer.Start()
    return $t
  }

  function Stop-47SelectedTask {
    try {
      if (-not $script:TaskList) { return }
      if (-not $script:TaskList.SelectedItem) { return }
      $id = ([string]$script:TaskList.SelectedItem).Split('|')[0].Trim()
      $t = $script:GuiTasks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
      if ($t -and $t.CanCancel -and $t.Ps) {
        try { $t.Ps.Stop() } catch { }
        $t.State = 'Canceled'
        $t.Ended = Get-Date
        $t.CanCancel = $false
        GuiLog ("Task canceled: " + $t.Name) 'WARN'
        Refresh-GuiTasks
      }
    } catch { }
  }

}

  # Gate destructive actions when Safe Mode is enabled
  function Update-47ActionGates {
    try {
      $isSafe = [bool]$script:SafeMode
      # known buttons we store in script scope if present
      foreach ($b in @('BtnApplyPlan','BtnRestoreSnap','BtnApplyStaged')) {
        try {
          $obj = Get-Variable -Name $b -Scope Script -ErrorAction SilentlyContinue
          if ($obj -and $obj.Value) { $obj.Value.IsEnabled = (-not $isSafe) }
        } catch { }
      }
    } catch { }
  }


  function New-47Card([string]$titleText,[string]$descText,[scriptblock]$bodyBuilder) {
    $card = New-Object System.Windows.Controls.Border
    $card.Background = $panel
    $card.CornerRadius = '12'
    $card.Padding = '14'
    $card.Margin = '0,0,0,12'
    $card.BorderBrush = $bg
    $card.BorderThickness = '1'

    $sp = New-Object System.Windows.Controls.StackPanel
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $titleText
    $t.FontSize = 16
    $t.FontWeight = 'SemiBold'
    $t.Foreground = $fg

    $d = New-Object System.Windows.Controls.TextBlock
    $d.Text = $descText
    $d.Margin = '0,4,0,10'
    $d.Foreground = $muted
    $d.TextWrapping = 'Wrap'

    $sp.Children.Add($t) | Out-Null
    $sp.Children.Add($d) | Out-Null
    if ($bodyBuilder) { $sp.Children.Add((& $bodyBuilder)) | Out-Null }
    $card.Child = $sp
    return $card
  }

  function New-47Button([string]$text,[scriptblock]$onClick,[string]$kind='primary') {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $text
    $b.Margin = '0,0,10,0'
    $b.Padding = '14,8,14,8'
    $b.Foreground = $fg
    $b.BorderThickness = '1'
    if ($kind -eq 'danger') { $b.BorderBrush = $warn; $b.Background = $panel }
    else { $b.BorderBrush = $accent; $b.Background = $panel }
    $b.Add_Click({ & $onClick })
    return $b
  }

  # Pages
  $pages = @{}

  $pages['Home'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    # Startup health gate (warnings)
    $root.Children.Add((New-47Card 'Startup Health' 'Quick warnings and one-click tools.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $st = Get-47HostStatus
      $warn = @()

      if (-not $st.WpfAvailable) { $warn += 'WPF not available - GUI will fail.' }
      if ($st.IsWindows -and (-not $st.IsAdmin)) { $warn += 'Not running as Admin (some actions need elevation).' }
      $pol = $null
      try { $pol = Get-47EffectivePolicy } catch { }
      if ($pol -and $pol.Mode -and ($pol.Mode -ne 'Permissive')) { $warn += ('Policy mode: ' + $pol.Mode) }

      if ($warn.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = 'All checks look good.'
        $t.Foreground = $muted
        $sp.Children.Add($t) | Out-Null
      } else {
        foreach ($w in $warn) {
          $t = New-Object System.Windows.Controls.TextBlock
          $t.Text = ' ' + $w
          $t.Foreground = $fg
          $t.Margin = '0,2,0,2'
          $sp.Children.Add($t) | Out-Null
        }

        $btns = New-Object System.Windows.Controls.WrapPanel
        $btns.Margin = '0,10,0,0'
        $btns.Children.Add((New-47Button 'Run Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
        $btns.Children.Add((New-47Button 'Verify' { $nav.SelectedItem = 'Verify' })) | Out-Null
        $btns.Children.Add((New-47Button 'Policy' { $nav.SelectedItem = 'Trust' })) | Out-Null
        $sp.Children.Add($btns) | Out-Null
      }

      return $sp
    })) | Out-Null

    $root.Children.Add((New-47Card 'Dashboard' 'All core features in one place.' {
      $row = New-Object System.Windows.Controls.WrapPanel
      $row.Margin = '0,6,0,0'
      $row.Children.Add((New-47Button 'Plans' { $nav.SelectedItem = 'Plans' })) | Out-Null
      $row.Children.Add((New-47Button 'Modules' { $nav.SelectedItem = 'Modules' })) | Out-Null
      $row.Children.Add((New-47Button 'Trust & Policy' { $nav.SelectedItem = 'Trust' })) | Out-Null
      $row.Children.Add((New-47Button 'Bundles' { $nav.SelectedItem = 'Bundles' })) | Out-Null
      $row.Children.Add((New-47Button 'Snapshots' { $nav.SelectedItem = 'Snapshots' })) | Out-Null
      $row.Children.Add((New-47Button 'Support' { $nav.SelectedItem = 'Support' })) | Out-Null
      $row.Children.Add((New-47Button 'Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
            $row.Children.Add((New-47Button 'Status' { $nav.SelectedItem = 'Status' })) | Out-Null
      $row.Children.Add((New-47Button 'Settings' { $nav.SelectedItem = 'Settings' })) | Out-Null
      $row.Children.Add((New-47Button 'Pack' { $nav.SelectedItem = 'Pack Manager' })) | Out-Null
      $row.Children.Add((New-47Button 'Tasks' { $nav.SelectedItem = 'Tasks' })) | Out-Null
$row.Children.Add((New-47Button 'Apps' { $nav.SelectedItem = 'Apps' })) | Out-Null
      return $row
    })) | Out-Null
    return $root
  }

  
  $pages['Status'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'System Status' 'Readiness indicators for this host.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $st = Get-47HostStatus

      function AddLine([string]$k,[string]$v) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = ($k + ': ' + $v)
        $tb.Margin = '0,2,0,2'
        $tb.Foreground = $fg
        $sp.Children.Add($tb) | Out-Null
      }

      AddLine 'PowerShell' $st.PwshVersion
      AddLine 'Windows' ([string]$st.IsWindows)
      AddLine 'Admin' ([string]$st.IsAdmin)
      AddLine 'WPF' ([string]$st.WpfAvailable)
      AddLine 'Docker' ([string]$st.Docker)
      AddLine 'Winget' ([string]$st.Winget)
      AddLine 'Safe Mode' ([string](Get-47SafeMode))

      if ($st.LastSnapshot) {
        AddLine 'Last Snapshot' ($st.LastSnapshot.Name + ' @ ' + [string]$st.LastSnapshot.Created)
      } else {
        AddLine 'Last Snapshot' 'none'
      }

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'
      $btns.Children.Add((New-47Button 'Run Doctor' { Start-47Task 'Doctor' { Invoke-47Tool -Name 'Invoke-47Doctor.ps1' -Args @{} } | Out-Null })) | Out-Null
      $btns.Children.Add((New-47Button 'Export Support Bundle' {
        $out = Get-47SaveFile -Title 'Save support bundle' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*' -DefaultName ("support_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        if ($out) { Start-47Task 'Support Bundle' { Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath=$out } } | Out-Null }
      })) | Out-Null
      $btns.Children.Add((New-47Button 'Open Logs' {
        try { $paths = Get-47Paths; Start-Process (Join-Path $paths.DataRoot 'logs') | Out-Null } catch { }
      })) | Out-Null
      $sp.Children.Add($btns) | Out-Null

      return $sp
    })) | Out-Null

    return $root
  }

$pages['Plans'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $planPathBox = New-Object System.Windows.Controls.TextBox
    $planPathBox.MinWidth = 520
    $planPathBox.Background = $panel
    $planPathBox.Foreground = $fg
    $planPathBox.BorderBrush = $accent
    $planPathBox.BorderThickness = '1'
    $planPathBox.Text = ''

    $policyBox = New-Object System.Windows.Controls.TextBox
    $policyBox.MinWidth = 520
    $policyBox.Background = $panel
    $policyBox.Foreground = $fg
    $policyBox.BorderBrush = $accent
    $policyBox.BorderThickness = '1'
    $policyBox.Text = ''

    $pickPlan = { 
      $p = Get-47OpenFile -Title 'Select plan JSON' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
      if ($p) { $planPathBox.Text = $p }
    }
    $pickPolicy = {
      $p = Get-47OpenFile -Title 'Select policy JSON (optional)' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
      if ($p) { $policyBox.Text = $p }
    }

    $root.Children.Add((New-47Card 'Plan Runner' 'Validate, WhatIf, or Apply a plan.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='PlanPath'; Foreground=$muted; Margin='0,0,0,6' })) | Out-Null
      $r1 = New-Object System.Windows.Controls.StackPanel
      $r1.Orientation = 'Horizontal'
      $r1.Children.Add($planPathBox) | Out-Null
      $r1.Children.Add((New-47Button 'Browse Plan' $pickPlan)) | Out-Null
      $sp.Children.Add($r1) | Out-Null

      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='PolicyPath (optional)'; Foreground=$muted; Margin='0,12,0,6' })) | Out-Null
      $r2 = New-Object System.Windows.Controls.StackPanel
      $r2.Orientation = 'Horizontal'
      $r2.Children.Add($policyBox) | Out-Null
      $r2.Children.Add((New-47Button 'Browse Policy' $pickPolicy)) | Out-Null
      $sp.Children.Add($r2) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,14,0,0'

      $btns.Children.Add((New-47Button 'Validate' {
        Start-47Task 'Validate plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
          Invoke-47Tool -Name 'Validate-47Plan.ps1' -Args @{ PlanPath=$p } | Out-Null
          $h = $null
          try { $h = Invoke-47Tool -Name 'Get-47PlanHash.ps1' -Args @{ PlanPath=$p } } catch { }
          if ($h) { Show-47GuiMessage "Plan validated.`nHash: $h" } else { Show-47GuiMessage "Plan validated." }
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'WhatIf' {
        Start-47Task 'WhatIf plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
          $args = @{ PlanPath=$p; Mode='WhatIf' }
          if (-not [string]::IsNullOrWhiteSpace($policyBox.Text)) { $args.PolicyPath = $policyBox.Text }
          Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args | Out-Null
          Show-47GuiMessage "WhatIf completed."
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Apply' {
        if ($script:SafeMode) { throw 'Safe Mode is enabled.' }
        Start-47Task 'Apply plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
                    if (-not (Confirm-47Typed -Title 'Confirm Apply' -Prompt 'Applying a plan can modify the system.' -Token 'APPLY')) { return }
          $args = @{ PlanPath=$p; Mode='Apply' }
          if (-not [string]::IsNullOrWhiteSpace($policyBox.Text)) { $args.PolicyPath = $policyBox.Text }
          Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args | Out-Null
          Show-47GuiMessage "Apply completed."
        }
      } 'danger')) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null

    return $root
  }

  $pages['Modules'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $list = New-Object System.Windows.Controls.ListView
    $list.Height = 260
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'

    $refresh = {
      $list.Items.Clear()
      foreach ($m in @(Get-47Modules)) {
        $list.Items.Add(("{0} - {1} ({2})" -f $m.Id,$m.Name,$m.Version)) | Out-Null
      }
    }

    $idBox = New-Object System.Windows.Controls.TextBox
    $idBox.MinWidth = 360
    $idBox.Background = $panel
    $idBox.Foreground = $fg
    $idBox.BorderBrush = $accent
    $idBox.BorderThickness = '1'

    $root.Children.Add((New-47Card 'Modules' 'Discover, import, and scaffold modules.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add((New-47Button 'Refresh' { GuiRun 'Refresh modules' { & $refresh } })) | Out-Null
      $sp.Children.Add($list) | Out-Null

      $row = New-Object System.Windows.Controls.WrapPanel
      $row.Margin = '0,12,0,0'
      $row.Children.Add($idBox) | Out-Null
      $row.Children.Add((New-47Button 'Import by Id' {
        GuiRun 'Import module' {
          $id = $idBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($id)) { throw 'Enter module id.' }
          Import-47Module -Id $id | Out-Null
          Show-47GuiMessage "Imported: $id"
        }
      })) | Out-Null

      $row.Children.Add((New-47Button 'Scaffold Module' {
        GuiRun 'Scaffold module' {
          $mid = $idBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($mid)) { throw 'Enter new module id in the box.' }
          Invoke-47Tool -Name 'New-47Module.ps1' -Args @{ ModuleId=$mid } | Out-Null
          Show-47GuiMessage "Scaffolded: $mid"
          & $refresh
        }
      })) | Out-Null

      $sp.Children.Add($row) | Out-Null
      return $sp
    })) | Out-Null

    & $refresh
    return $root
  }

  
  $pages['Settings'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Safe Mode (global)' 'Disable destructive actions for demos and safety.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $cb = New-Object System.Windows.Controls.CheckBox
      $cb.Content = 'Enable Safe Mode'
      $cb.Foreground = $fg
      $cb.IsChecked = (Get-47SafeMode)
      $cb.Add_Click({
        $script:SafeMode = [bool]$cb.IsChecked
        Set-47SafeMode -Enabled $script:SafeMode
        try { Update-47ActionGates } catch { }
        Show-47GuiMessage ('Safe Mode: ' + $script:SafeMode)
      })
      $sp.Children.Add($cb) | Out-Null
      return $sp
    })) | Out-Null


    $mods = @(Get-47Modules)
    $pick = New-Object System.Windows.Controls.ComboBox
    $pick.MinWidth = 360
    $pick.Background = $panel
    $pick.Foreground = $fg
    $pick.BorderBrush = $accent
    $pick.BorderThickness = '1'
    foreach ($m in $mods) { [void]$pick.Items.Add($m.Id) }
    if ($pick.Items.Count -gt 0) { $pick.SelectedIndex = 0 }

    $box = New-Object System.Windows.Controls.TextBox
    $box.Height = 320
    $box.AcceptsReturn = $true
    $box.VerticalScrollBarVisibility = 'Auto'
    $box.Background = $panel
    $box.Foreground = $fg
    $box.BorderBrush = $accent
    $box.BorderThickness = '1'
    $box.Text = ''

    function LoadSel {
      $id = [string]$pick.SelectedItem
      if ([string]::IsNullOrWhiteSpace($id)) { return }
      $s = Get-47ModuleSettings -ModuleId $id
      $box.Text = ($s | ConvertTo-Json -Depth 10)
    }

    $pick.Add_SelectionChanged({ LoadSel })

    $root.Children.Add((New-47Card 'Module Settings' 'Edit JSON settings per module (stored under data/module-settings).' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add($pick) | Out-Null
      $sp.Children.Add($box) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'

      $btns.Children.Add((New-47Button 'Reload' { LoadSel })) | Out-Null
      $btns.Children.Add((New-47Button 'Save' {
        GuiRun 'Save settings' {
          $id = [string]$pick.SelectedItem
          if ([string]::IsNullOrWhiteSpace($id)) { throw 'Select a module.' }
          $obj = $null
          try { $obj = ($box.Text | ConvertFrom-Json) } catch { throw 'Invalid JSON.' }
          Save-47ModuleSettings -ModuleId $id -Settings $obj
          Show-47GuiMessage ("Saved settings for: " + $id)
        }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null

    LoadSel
    return $root
  }

$pages['Trust'] = {
    $root = New-Object System.Windows.Controls.StackPanel
    $root.Children.Add((New-47Card 'Trust & Policy' 'View policy and simulate policy vs a plan.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Show Effective Policy' {
        GuiRun 'Load policy' {
          $p = Invoke-47Tool -Name 'Get-47EffectivePolicy.ps1' -Args @{}
          Show-47GuiMessage ($p | Out-String)
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Simulate Policy vs Plan' {
        GuiRun 'Simulate policy' {
          $plan = Get-47OpenFile -Title 'Select plan JSON' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
          if (-not $plan) { return }
          $pol = Get-47OpenFile -Title 'Select policy JSON (optional)' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
          $args = @{ PlanPath=$plan }
          if ($pol) { $args.PolicyPath = $pol }
          $res = Invoke-47Tool -Name 'Simulate-47Policy.ps1' -Args $args
          Show-47GuiMessage ($res | Out-String)
        }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null
    return $root
  }

  $pages['Bundles'] = {
    $root = New-Object System.Windows.Controls.StackPanel
    $root.Children.Add((New-47Card 'Offline Bundles' 'Verify bundle.manifest.json and safe extract (ZipSlip + hash verify).' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Verify Bundle Zip' {
        GuiRun 'Verify bundle' {
          $zip = Get-47OpenFile -Title 'Select bundle zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*'
          if (-not $zip) { return }
          $r = P47-VerifyBundleZip -ZipPath $zip
          Show-47GuiMessage ("OK: {0}`nFiles: {1}" -f $r.ok, $r.fileResults.Count)
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Safe Extract Bundle' {
        GuiRun 'Extract bundle' {
          $zip = Get-47OpenFile -Title 'Select bundle zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*'
          if (-not $zip) { return }
          $dest = Get-47FolderPicker -Description 'Select destination folder'
          if (-not $dest) { return }
          $r = P47-SafeExtractBundle -ZipPath $zip -Destination $dest
          Show-47GuiMessage ("Extracted to: {0}" -f $r.dest)
        }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null
    return $root
  }

  
  $pages['Pack Manager'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Pack Manager' 'Verify, extract, and stage new pack zips. Safe by default (no overwrite).' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Verify Pack Zip' {
        $zip = Get-47OpenFile -Title 'Select pack zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*'
        if (-not $zip) { return }
        Start-47Task 'Verify pack' { P47-VerifyBundleZip -ZipPath $zip } | Out-Null
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Stage Pack Zip (Safe Extract)' {
        $zip = Get-47OpenFile -Title 'Select pack zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*'
        if (-not $zip) { return }
        $paths = Get-47Paths
        $stage = Join-Path $paths.DataRoot ('staged-pack-' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
        New-Item -ItemType Directory -Path $stage -Force | Out-Null
        Start-47Task 'Stage pack' { P47-SafeExtractBundle -ZipPath $zip -Destination $stage } | Out-Null
        Show-47GuiMessage ("Staging folder: " + $stage)

      $btns.Children.Add((New-47Button 'Diff Staged vs Project' {
        $stage = Get-47FolderPicker
        if (-not $stage) { return }
        $target = Get-47ProjectRoot
        $d = Compare-47FolderDiff -Source $stage -Target $target

        $dlg = New-Object System.Windows.Window
        $dlg.Title = 'Staged Diff'
        $dlg.Width = 820
        $dlg.Height = 520
        $dlg.WindowStartupLocation = 'CenterOwner'
        $dlg.Owner = $win
        $dlg.Background = $bg

        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Margin = '12'

        $hdr = New-Object System.Windows.Controls.TextBlock
        $hdr.Text = ("Added: {0}  Changed: {1}  Same: {2}  ExtraInTarget: {3}" -f $d.Added.Count,$d.Changed.Count,$d.Same.Count,$d.ExtraInTarget.Count)
        $hdr.Foreground = $fg
        $hdr.Margin = '0,0,0,10'

        $tabs = New-Object System.Windows.Controls.TabControl
        $tabs.Background = $panel
        $tabs.BorderBrush = $accent
        $tabs.BorderThickness = '1'

        function NewTab([string]$name,[string[]]$items) {
          $tab = New-Object System.Windows.Controls.TabItem
          $tab.Header = $name
          $list = New-Object System.Windows.Controls.ListBox
          $list.Background = $panel
          $list.Foreground = $fg
          $list.BorderBrush = $accent
          $list.BorderThickness = '1'
          $list.Height = 360
          foreach ($i in $items) { [void]$list.Items.Add($i) }
          $tab.Content = $list
          return $tab
        }

        $tabs.Items.Add((NewTab 'Added' $d.Added)) | Out-Null
        $tabs.Items.Add((NewTab 'Changed' $d.Changed)) | Out-Null
        $tabs.Items.Add((NewTab 'ExtraInTarget' $d.ExtraInTarget)) | Out-Null

        $btns2 = New-Object System.Windows.Controls.WrapPanel
        $btns2.Margin = '0,10,0,0'

        $btns2.Children.Add((New-47Button 'Export Diff' {
          $out = Get-47SaveFile -Title 'Save diff report' -Filter 'Text (*.txt)|*.txt|All files (*.*)|*.*' -DefaultName ("diff_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
          if ($out) {
            $lines = @()
            $lines += ('Stage: ' + $stage)
            $lines += ('Target: ' + $target)
            $lines += ''
            $lines += '== Added =='
            $lines += $d.Added
            $lines += ''
            $lines += '== Changed =='
            $lines += $d.Changed
            $lines += ''
            $lines += '== ExtraInTarget =='
            $lines += $d.ExtraInTarget
            Set-Content -LiteralPath $out -Value ($lines -join "`r`n") -Encoding utf8
            Show-47GuiMessage ('Saved: ' + $out)
          }
        })) | Out-Null

        $sp.Children.Add($hdr) | Out-Null
        $sp.Children.Add($tabs) | Out-Null
        $sp.Children.Add($btns2) | Out-Null

        $dlg.Content = $sp
        $dlg.ShowDialog() | Out-Null
      })) | Out-Null


      $btns.Children.Add(($script:BtnApplyStaged = New-47Button 'Apply Staged Pack' {
        $stage = Get-47FolderPicker
        if (-not $stage) { return }
        $target = Get-47ProjectRoot
        $sum = Compare-47FolderSummary -Source $stage -Target $target
        $msg = ("Stage: {0}`nTarget: {1}`nNew: {2}  Changed: {3}  Same: {4}`n`nCreate a snapshot first, then apply staged files? (no deletes)" -f $sum.Source,$sum.Target,$sum.New,$sum.Changed,$sum.Same)
        if (-not (Confirm-47Typed -Title 'Confirm Update' -Prompt $msg -Token 'UPDATE')) { return }

        if ($script:SafeMode) { throw 'Safe Mode is enabled.' }
        Start-47Task 'Snapshot + Apply staged pack' {
          try { Save-47Snapshot -Name ('pre_update_' + (Get-Date -Format 'yyyyMMdd_HHmmss')) | Out-Null } catch { }
          Apply-47StagedPack -StageDir $stage
        } | Out-Null
      })) | Out-Null

      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open Data Folder' {
        try { $paths = Get-47Paths; Start-Process $paths.DataRoot | Out-Null } catch { }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null

      $note = New-Object System.Windows.Controls.TextBlock
      $note.Text = "Tip: staging extracts into data/ and does NOT overwrite your project.
Use Apply Staged Pack to copy staged files into the project (no deletes)."
      $note.Foreground = $muted
      $note.Margin = '0,10,0,0'
      $note.TextWrapping = 'Wrap'
      $sp.Children.Add($note) | Out-Null

      return $sp
    })) | Out-Null

    return $root
  }


  $pages['Verify'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $reportBox = New-Object System.Windows.Controls.TextBox
    $reportBox.Height = 360
    $reportBox.AcceptsReturn = $true
    $reportBox.VerticalScrollBarVisibility = 'Auto'
    $reportBox.Background = $panel
    $reportBox.Foreground = $fg
    $reportBox.BorderBrush = $accent
    $reportBox.BorderThickness = '1'
    $reportBox.Text = ''

    function Run-Verify {
      $lines = @()
      $lines += ('Timestamp: ' + (Get-Date))
      try {
        $st = Get-47HostStatus
        $lines += ('PowerShell: ' + $st.PwshVersion)
        $lines += ('Windows: ' + $st.IsWindows + '  Admin: ' + $st.IsAdmin + '  WPF: ' + $st.WpfAvailable)
        $lines += ('Docker: ' + $st.Docker + '  Winget: ' + $st.Winget)
      } catch { $lines += 'Status: error' }

      try {
        $mods = @(Get-47Modules)
        $lines += ('Modules discovered: ' + $mods.Count)
      } catch { $lines += 'Modules discovered: error' }

      try {
        $pol = Get-47EffectivePolicy
        $lines += ('Policy mode: ' + $pol.Mode)
      } catch { $lines += 'Policy: error' }

      try {
        $sn = @(Get-47Snapshots)
        $lines += ('Snapshots: ' + $sn.Count)
      } catch { $lines += 'Snapshots: error' }

      $lines += ''
      $lines += 'OK - Verify done.'
      $reportBox.Text = ($lines -join "`r`n")
    }

    $root.Children.Add((New-47Card 'Verify Everything' 'Run a quick integrity/readiness check and export a report.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Run Verify' { Start-47Task 'Verify' { } | Out-Null; $win.Dispatcher.Invoke([action]{ Run-Verify }) })) | Out-Null

      $btns.Children.Add((New-47Button 'Export Report' {
        $out = Get-47SaveFile -Title 'Save verify report' -Filter 'Text (*.txt)|*.txt|All files (*.*)|*.*' -DefaultName ("verify_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        if ($out) { Set-Content -LiteralPath $out -Value $reportBox.Text -Encoding utf8; Show-47GuiMessage ("Saved: " + $out) }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open Latest Log' { Open-47LatestLog })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      $sp.Children.Add($reportBox) | Out-Null
      Run-Verify
      return $sp
    })) | Out-Null

    return $root
  }


  $pages['Config'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Config Export/Import' 'Export/import your user configuration (favorites, recents, UI state, profiles, module settings).' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Export Config' {
        $out = Get-47SaveFile -Title 'Save config zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*' -DefaultName ("47_config_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        if (-not $out) { return }
        Start-47Task 'Export config' { Export-47UserConfig -OutZip $out } | Out-Null
        Show-47GuiMessage ('Saved: ' + $out)
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Import Config' {
        $zip = Get-47OpenFile -Title 'Select config zip' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*'
        if (-not $zip) { return }
        if (-not (Confirm-47Typed -Title 'Confirm Import' -Prompt 'This will overwrite your current config files. A backup zip will be created.' -Token 'IMPORT')) { return }
        Start-47Task 'Import config' {
          $backup = Import-47UserConfig -InZip $zip
          if ($backup) { $backup }
        } | Out-Null
        Show-47GuiMessage 'Imported config. Restart recommended.'
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open Data Folder' {
        try { $paths = Get-47Paths; Start-Process $paths.DataRoot | Out-Null } catch { }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null

      $note = New-Object System.Windows.Controls.TextBlock
      $note.Text = "Import creates a backup zip under data/. Token required: IMPORT."
      $note.Foreground = $muted
      $note.Margin = '0,10,0,0'
      $note.TextWrapping = 'Wrap'
      $sp.Children.Add($note) | Out-Null

      return $sp
    })) | Out-Null

    return $root
  }

$pages['Snapshots'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $list = New-Object System.Windows.Controls.ListView
    $list.Height = 260
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'

    $refresh = {
      $list.Items.Clear()
      foreach ($s in @(Get-47Snapshots)) {
        $list.Items.Add(("{0}: {1} - {2}" -f $s.Index,$s.Name,$s.Created)) | Out-Null
      }
    }

    $root.Children.Add((New-47Card 'Snapshots' 'Save, list, and restore snapshots (pack-focused).' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add((New-47Button 'Refresh' { GuiRun 'Refresh snapshots' { & $refresh } })) | Out-Null
      $sp.Children.Add($list) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'

      $btns.Children.Add((New-47Button 'Save Snapshot' {
        GuiRun 'Save snapshot' {
          Invoke-47Tool -Name 'Save-47Snapshot.ps1' -Args @{ IncludePack=$true } | Out-Null
          & $refresh
          Show-47GuiMessage "Snapshot saved."
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Restore Selected (by Index)' {
        GuiRun 'Restore snapshot' {
          if (-not $list.SelectedItem) { throw 'Select a snapshot from the list.' }
          $ix = ([string]$list.SelectedItem).Split(':')[0].Trim()
                    if (-not (Confirm-47Typed -Title 'Confirm Restore' -Prompt ('Restoring snapshot index ' + $ix + ' can modify files.') -Token 'RESTORE')) { return }
          $sn = @(Get-47Snapshots) | Where-Object { $_.Index -eq [int]$ix } | Select-Object -First 1
         
  $pages['Support'] = {
    $root = New-Object System.Windows.Controls.StackPanel
    $root.Children.Add((New-47Card 'Support Bundle' 'Export diagnostics into a zip you can share.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,6,0,0'

      $btns.Children.Add((New-47Button 'Export Support Bundle' {
        $out = Get-47SaveFile -Title 'Save support bundle' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*' -DefaultName ("support_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        if (-not $out) { return }
        Start-47Task 'Support Bundle' { Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath=$out } } | Out-Null
        Show-47GuiMessage ("Saved: " + $out)
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open Support Folder' {
        try { $paths = Get-47Paths; $d = Join-Path $paths.DataRoot 'support'; Start-Process $d | Out-Null } catch { }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Copy Last Output' {
        try { [System.Windows.Clipboard]::SetText($consoleBox.Text) } catch { }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null
    return $root
  }

  $pages['Doctor'] = {
    $root = New-Object System.Windows.Controls.StackPanel
    $root.Children.Add((New-47Card 'Doctor' 'Run diagnostics and print recommendations.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add((New-47Button 'Run Doctor' {
        Start-47Task 'Doctor' { Invoke-47Tool -Name 'Invoke-47Doctor.ps1' -Args @{} } | Out-Null
      })) | Out-Null
      return $sp
    })) | Out-Null
    return $root
  }

  $pages['Tasks'] = {
    $root = New-Object System.Windows.Controls.StackPanel
    $root.Children.Add((New-47Card 'Tasks' 'Background task runner (non-blocking).' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $list = New-Object System.Windows.Controls.ListBox
      $list.Height = 260
      $list.Background = $panel
      $list.Foreground = $fg
      $list.BorderBrush = $accent
      $list.BorderThickness = '1'
      $script:TaskList = $list

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'
      $btns.Children.Add((New-47Button 'Refresh' { Refresh-GuiTasks })) | Out-Null
      $btns.Children.Add((New-47Button 'Cancel Selected' { Stop-47SelectedTask } 'danger')) | Out-Null

      $sp.Children.Add($list) | Out-Null
      $sp.Children.Add($btns) | Out-Null
      Refresh-GuiTasks
      return $sp
    })) | Out-Null
    return $root
  }


$pages['Apps'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $favorites = @(Get-47Favorites)

    $filters = New-Object System.Windows.Controls.WrapPanel
    $filters.Margin = '0,0,0,10'

    $script:AppsSearch = New-Object System.Windows.Controls.TextBox
    $search = $script:AppsSearch
    $search.MinWidth = 420
    $search.Background = $panel
    $search.Foreground = $fg
    $search.BorderBrush = $accent
    $search.BorderThickness = '1'
    $search.Margin = '0,0,12,0'
    $search.Text = ''

    $script:AppsCategory = New-Object System.Windows.Controls.ComboBox
    $category = $script:AppsCategory
    $category.MinWidth = 200
    $category.Background = $panel
    $category.Foreground = $fg
    $category.BorderBrush = $accent
    $category.BorderThickness = '1'
    $category.Margin = '0,0,12,0'
    foreach ($c in @('All','Framework','Tools','Modules','AppCrawler','Launcher','Apps')) { [void]$category.Items.Add($c) }
    $category.SelectedIndex = 0

    try {
      if ($script:UiState.AppsSearch) { $search.Text = [string]$script:UiState.AppsSearch }
      if ($script:UiState.AppsCategory) {
        $ci = $category.Items.IndexOf([string]$script:UiState.AppsCategory)
        if ($ci -ge 0) { $category.SelectedIndex = $ci }
      }
      if ($script:UiState.AppsFavOnly -ne $null) { $onlyFav.IsChecked = [bool]$script:UiState.AppsFavOnly }
    } catch { }


    $script:AppsFavOnly = New-Object System.Windows.Controls.CheckBox
    $onlyFav = $script:AppsFavOnly
    $onlyFav.Content = 'Favorites only'
    $onlyFav.Foreground = $fg
    $onlyFav.Margin = '0,6,0,0'
    $onlyFav.IsChecked = $false

    $filters.Children.Add($search) | Out-Null
    $filters.Children.Add($category) | Out-Null
    $filters.Children.Add($onlyFav) | Out-Null

    # Layout: left list + right details
    $layout = New-Object System.Windows.Controls.Grid
    $layout.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '*' })) | Out-Null
    $layout.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '360' })) | Out-Null

    $left = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($left,0)

    $favLabel = New-Object System.Windows.Controls.TextBlock
    $favLabel.Text = 'Pinned Favorites'
    $favLabel.Foreground = $accent
    $favLabel.FontWeight = 'SemiBold'
    $favLabel.Margin = '2,0,0,6'

    $favWrap = New-Object System.Windows.Controls.WrapPanel
    $favWrap.Margin = '0,0,0,10'

    $appsLabel = New-Object System.Windows.Controls.TextBlock
    $appsLabel.Text = 'All Apps'
    $appsLabel.Foreground = $accent
    $appsLabel.FontWeight = 'SemiBold'
    $appsLabel.Margin = '2,0,0,6'

    $appsWrap = New-Object System.Windows.Controls.WrapPanel
    $appsWrap.Margin = '0,0,0,0'

    $scroll = New-Object System.Windows.Controls.ScrollViewer
    $scroll.VerticalScrollBarVisibility = 'Auto'
    $scroll.HorizontalScrollBarVisibility = 'Disabled'
    $scroll.Content = $appsWrap
    $scroll.Height = 420

    $left.Children.Add($filters) | Out-Null
    $left.Children.Add($favLabel) | Out-Null
    $left.Children.Add($favWrap) | Out-Null
    $left.Children.Add($appsLabel) | Out-Null
    $left.Children.Add($scroll) | Out-Null

    # Details panel (right)
    $right = New-Object System.Windows.Controls.Border
    [System.Windows.Controls.Grid]::SetColumn($right,1)
    $right.Background = $panel
    $right.CornerRadius = '12'
    $right.Padding = '12'
    $right.Margin = '12,0,0,0'
    $right.BorderBrush = $accent
    $right.BorderThickness = '1'

    $rightStack = New-Object System.Windows.Controls.StackPanel

    $detailsTitle = New-Object System.Windows.Controls.TextBlock
    $detailsTitle.Text = 'Select a tile'
    $detailsTitle.FontSize = 16
    $detailsTitle.FontWeight = 'SemiBold'
    $detailsTitle.Foreground = $fg

    $detailsMeta = New-Object System.Windows.Controls.TextBlock
    $detailsMeta.Text = ''
    $detailsMeta.Margin = '0,4,0,10'
    $detailsMeta.Foreground = $muted
    $detailsMeta.TextWrapping = 'Wrap'

    $detailsDesc = New-Object System.Windows.Controls.TextBlock
    $detailsDesc.Text = ''
    $detailsDesc.Foreground = $fg
    $detailsDesc.TextWrapping = 'Wrap'
    $detailsDesc.Margin = '0,0,0,10'

    $detailsPath = New-Object System.Windows.Controls.TextBlock
    $detailsPath.Text = ''
    $detailsPath.Foreground = $muted
    $detailsPath.TextWrapping = 'Wrap'
    $detailsPath.Margin = '0,0,0,10'

    $detailsArgs = New-Object System.Windows.Controls.TextBox
    $detailsArgs.Background = $bg
    $detailsArgs.Foreground = $fg
    $detailsArgs.BorderBrush = $accent
    $detailsArgs.BorderThickness = '1'
    $detailsArgs.Margin = '0,0,0,10'
    $detailsArgs.Text = ''
    $detailsArgs.ToolTip = 'Optional arguments (scripts only)'

    $btnRow = New-Object System.Windows.Controls.WrapPanel

    $btnLaunch = New-Object System.Windows.Controls.Button
    $btnLaunch.Content = 'Launch'
    $btnLaunch.Padding = '10,6,10,6'
    $btnLaunch.Background = $panel
    $btnLaunch.Foreground = $fg
    $btnLaunch.BorderBrush = $accent
    $btnLaunch.BorderThickness = '1'
    $btnLaunch.Margin = '0,0,10,10'
    $btnLaunch.IsEnabled = $false

    $btnAdmin = New-Object System.Windows.Controls.Button
    $btnAdmin.Content = 'Run as Admin'
    $btnAdmin.Padding = '10,6,10,6'
    $btnAdmin.Background = $panel
    $btnAdmin.Foreground = $fg
    $btnAdmin.BorderBrush = $accent
    $btnAdmin.BorderThickness = '1'
    $btnAdmin.Margin = '0,0,10,10'
    $btnAdmin.IsEnabled = $false

    $btnFolder = New-Object System.Windows.Controls.Button
    $btnFolder.Content = 'Open Folder'
    $btnFolder.Padding = '10,6,10,6'
    $btnFolder.Background = $panel
    $btnFolder.Foreground = $fg
    $btnFolder.BorderBrush = $accent
    $btnFolder.BorderThickness = '1'
    $btnFolder.Margin = '0,0,10,10'
    $btnFolder.IsEnabled = $false

    $btnFav = New-Object System.Windows.Controls.Button
    $btnFav.Content = 'Favorite'
    $btnFav.Padding = '10,6,10,6'
    $btnFav.Background = $panel
    $btnFav.Foreground = $fg
    $btnFav.BorderBrush = $accent
    $btnFav.BorderThickness = '1'
    $btnFav.Margin = '0,0,10,10'
    $btnFav.IsEnabled = $false

    $btnCopy = New-Object System.Windows.Controls.Button
    $btnCopy.Content = 'Copy Path'

    $btnCopyCli = New-Object System.Windows.Controls.Button
    $btnCopyCli.Content = 'Copy CLI'
    $btnCopyCli.Padding = '10,6,10,6'
    $btnCopyCli.Background = $panel
    $btnCopyCli.Foreground = $fg
    $btnCopyCli.BorderBrush = $accent
    $btnCopyCli.BorderThickness = '1'
    $btnCopyCli.Margin = '0,0,10,10'
    $btnCopyCli.IsEnabled = $false
    $btnCopy.Padding = '10,6,10,6'
    $btnCopy.Background = $panel
    $btnCopy.Foreground = $fg
    $btnCopy.BorderBrush = $accent
    $btnCopy.BorderThickness = '1'
    $btnCopy.Margin = '0,0,10,10'
    $btnCopy.IsEnabled = $false

    $btnRow.Children.Add($btnLaunch) | Out-Null
    $btnRow.Children.Add($btnAdmin) | Out-Null
    $btnRow.Children.Add($btnFolder) | Out-Null
    $btnRow.Children.Add($btnFav) | Out-Null
    $btnRow.Children.Add($btnCopy) | Out-Null
    $btnRow.Children.Add($btnCopyCli) | Out-Null

    $rightStack.Children.Add($detailsTitle) | Out-Null
    $rightStack.Children.Add($detailsMeta) | Out-Null
    $rightStack.Children.Add($detailsDesc) | Out-Null
    $rightStack.Children.Add($detailsPath) | Out-Null
    $rightStack.Children.Add($detailsArgs) | Out-Null
    $rightStack.Children.Add($btnRow) | Out-Null

    $right.Child = $rightStack

    $layout.Children.Add($left) | Out-Null
    $layout.Children.Add($right) | Out-Null

    function New-47IconElement([string]$name,[string]$iconPath,[int]$size=44) {
      $box = New-Object System.Windows.Controls.Border
      $box.Width = $size
      $box.Height = $size
      $box.CornerRadius = '10'
      $box.Margin = '0,0,10,0'
      $box.BorderBrush = $accent
      $box.BorderThickness = '1'
      $box.Background = $bg

      if ($iconPath -and (Test-Path -LiteralPath $iconPath)) {
        try {
          $img = New-Object System.Windows.Controls.Image
          $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
          $bmp.BeginInit()
          $bmp.UriSource = (New-Object System.Uri($iconPath))
          $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
          $bmp.EndInit()
          $img.Source = $bmp
          $img.Stretch = 'UniformToFill'
          $box.Child = $img
          return $box
        } catch { }
      }

      $t = New-Object System.Windows.Controls.TextBlock
      $t.Text = ($name.Substring(0,[Math]::Min(2,$name.Length))).ToUpperInvariant()
      $t.HorizontalAlignment = 'Center'
      $t.VerticalAlignment = 'Center'
      $t.FontWeight = 'Bold'
      $t.Foreground = $accent
      $box.Child = $t
      return $box
    }

    $script:SelectedApp = $null
    function Set-SelectedApp($a) {
      $script:SelectedApp = $a
      if (-not $a) { return }

      $detailsTitle.Text = $a.DisplayName
      $detailsMeta.Text = ($a.Category + '  |  ' + $a.Kind + (([string]::IsNullOrWhiteSpace($a.Version)) ? '' : ('  |  v' + $a.Version)))
      $detailsDesc.Text = $a.Description
      $detailsPath.Text = ($a.Type -eq 'module' -and $a.EntryPath) ? ('Entry: ' + $a.EntryPath) : $a.Path

      $btnLaunch.IsEnabled = $true
      $btnFolder.IsEnabled = $true
      $btnCopy.IsEnabled = $true
      $btnCopyCli.IsEnabled = $true

      $isScript = ($a.Type -ne 'module')
      $detailsArgs.IsEnabled = $isScript
      $btnAdmin.IsEnabled = ($IsWindows -and $isScript)

      $btnFav.IsEnabled = $true
      $btnFav.Content = ( ($favorites -contains $a.Id) ? 'Unfavorite' : 'Favorite' )
    }

    function Toggle-Favorite([string]$id) {
      if ($favorites -contains $id) { $favorites = @($favorites | Where-Object { $_ -ne $id }) }
      else { $favorites = @($favorites + @($id)) }
      Save-47Favorites -Favorites $favorites
    }

    function Launch-Selected([switch]$Elevated) {
      $a = $script:SelectedApp
      if (-not $a) { return }

      if ($a.Type -eq 'module') {
        if (-not $a.ModuleId) { throw 'ModuleId missing.' }
        Import-47Module -Id $a.ModuleId | Out-Null
        Show-47GuiMessage ("Imported module: " + $a.ModuleId)
        return
      }

      $pw = Join-Path $PSHOME 'pwsh.exe'
      if (-not (Test-Path -LiteralPath $pw)) { throw "pwsh.exe not found." }
      if (-not (Test-Path -LiteralPath $a.Path)) { throw ("File not found: " + $a.Path) }
      $extra = $detailsArgs.Text
      $argList = @('-NoLogo','-NoProfile','-File',$a.Path)
      if (-not [string]::IsNullOrWhiteSpace($extra)) { $argList += $extra }

      if ($Elevated -and $IsWindows) {
        Start-Process -FilePath $pw -ArgumentList $argList -Verb RunAs | Out-Null
      } else {
        Start-Process -FilePath $pw -ArgumentList $argList | Out-Null
      }
    }

    $btnLaunch.Add_Click({ GuiRun 'Launch' { Launch-Selected } })
    $btnAdmin.Add_Click({ GuiRun 'Launch (Admin)' { Launch-Selected -Elevated } })
    $btnFolder.Add_Click({
      GuiRun 'Open folder' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        $dir = (Test-Path -LiteralPath $a.Path -PathType Container) ? $a.Path : (Split-Path -Parent $a.Path)
        Start-Process $dir | Out-Null
      }
    })
    $btnFav.Add_Click({
      GuiRun 'Toggle favorite' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        Toggle-Favorite -id $a.Id
        RenderApps
        Set-SelectedApp $a
      }
    })
    $btnCopy.Add_Click({
      try {
        $a = $script:SelectedApp
        if ($a) { [System.Windows.Clipboard]::SetText([string]$a.Path) }
      } catch { }
    })

    function New-47Tile($a,[switch]$Small) {
      $tile = New-Object System.Windows.Controls.Border
      $tile.Background = $panel
      $tile.CornerRadius = '12'
      $tile.Padding = '12'
      $tile.Margin = '0,0,12,12'
      $tile.BorderBrush = $accent
      $tile.BorderThickness = '1'
      $tile.Width = ($Small ? 260 : 320)

      $sp = New-Object System.Windows.Controls.StackPanel

      $hdr = New-Object System.Windows.Controls.StackPanel
      $hdr.Orientation = 'Horizontal'
      $hdr.Margin = '0,0,0,8'

      $iconPath = Find-47IconForApp -AppPath $a.Path -ModuleId $a.ModuleId -DisplayName $a.DisplayName
      $hdr.Children.Add((New-47IconElement -name $a.DisplayName -iconPath $iconPath -size ($Small ? 36 : 44))) | Out-Null

      $titleStack = New-Object System.Windows.Controls.StackPanel

      $t = New-Object System.Windows.Controls.TextBlock
      $t.Text = $a.DisplayName
      $t.FontSize = 14
      $t.FontWeight = 'SemiBold'
      $t.Foreground = $fg

      $meta = New-Object System.Windows.Controls.TextBlock
      $meta.Text = ($a.Category + '  |  ' + $a.Kind + (([string]::IsNullOrWhiteSpace($a.Version)) ? '' : ('  |  v' + $a.Version)))
      $meta.Margin = '0,2,0,0'
      $meta.Foreground = $muted
      $meta.TextWrapping = 'Wrap'

      $titleStack.Children.Add($t) | Out-Null
      $titleStack.Children.Add($meta) | Out-Null
      $hdr.Children.Add($titleStack) | Out-Null

      $sp.Children.Add($hdr) | Out-Null

      if (-not $Small) {
        $d1 = New-Object System.Windows.Controls.TextBlock
        $d1.Text = $a.Description
        $d1.Margin = '0,0,0,8'
        $d1.Foreground = $muted
        $d1.TextWrapping = 'Wrap'
        $sp.Children.Add($d1) | Out-Null
      }

      $tile.Child = $sp

      $tile.Add_MouseLeftButtonUp({
        Set-SelectedApp $a
      })

    $btnCopyCli.Add_Click({
      try {
        $a = $script:SelectedApp
        if (-not $a) { return }
        if ($a.Type -eq 'module') {
          [System.Windows.Clipboard]::SetText(("pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command import-module -ModuleId " + $a.ModuleId))
        } else {
          $args = $detailsArgs.Text
          $cmd = "pwsh -NoLogo -NoProfile -File `"{0}`"" -f $a.Path
          if (-not [string]::IsNullOrWhiteSpace($args)) { $cmd = $cmd + " " + $args }
          [System.Windows.Clipboard]::SetText($cmd)
        }
      } catch { }
    })


      return $tile
    }

    function RenderApps {
      $favWrap.Children.Clear()
      $appsWrap.Children.Clear()

      $q = $search.Text
      $cat = [string]$category.SelectedItem
      $favOnly = [bool]$onlyFav.IsChecked

      $apps = @(Get-47AppCatalog)

      if (-not [string]::IsNullOrWhiteSpace($q)) {
        $apps = $apps | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.Description -like "*$q*" -or $_.Path -like "*$q*" }
      }
      if ($cat -and $cat -ne 'All') {
        $apps = $apps | Where-Object { $_.Category -eq $cat }
      }
      if ($favOnly) {
        $apps = $apps | Where-Object { $favorites -contains $_.Id }
      }

      # Pinned favorites first (strip), then main list without duplicates
      $favApps = $apps | Where-Object { $favorites -contains $_.Id } | Sort-Object DisplayName
      foreach ($a in $favApps) {
        [void]$favWrap.Children.Add((New-47Tile $a -Small))
      }

      $rest = $apps | Where-Object { -not ($favorites -contains $_.Id) } | Sort-Object Category, DisplayName
      foreach ($a in $rest) {
        [void]$appsWrap.Children.Add((New-47Tile $a))
      }

      $favLabel.Visibility = ($favApps.Count -gt 0) ? 'Visible' : 'Collapsed'
      $favWrap.Visibility = ($favApps.Count -gt 0) ? 'Visible' : 'Collapsed'
    }

    $search.Add_TextChanged({ RenderApps })
    $category.Add_SelectionChanged({ RenderApps })
    $onlyFav.Add_Click({ RenderApps })

    $root.Children.Add((New-47Card 'Apps Hub' 'Favorites strip + details panel. Click a tile to view details and launch.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add($layout) | Out-Null
      return $sp
    })) | Out-Null

    RenderApps
    return $root
  }

foreach ($k in @('Home','Status','Plans','Modules','Settings','Trust','Bundles','Pack Manager','Verify','Config','Snapshots','Support','Doctor','Apps','Tasks')) { [void]$nav.Items.Add($k) }
  $nav.SelectedIndex = 0


  try {
    if ($script:UiState.LastPage) {
      $i = $nav.Items.IndexOf([string]$script:UiState.LastPage)
      if ($i -ge 0) { $nav.SelectedIndex = $i } else { $nav.SelectedIndex = 0 }
    } else { $nav.SelectedIndex = 0 }
  } catch { $nav.SelectedIndex = 0 }

  $nav.Add_SelectionChanged({
    try {
      $key = [string]$nav.SelectedItem
      if (-not $key) { return }
      $statusText.Text = $key
      $contentHost.Content = & $pages[$key]
      $statusText.Text = 'Ready.'
    } catch { Show-47Gu
  $win.Add_Closing({
    try {
      $st = [pscustomobject]@{
        WindowWidth = $win.Width
        WindowHeight = $win.Height
        WindowLeft = $win.Left
        WindowTop = $win.Top
        WindowState = [string]$win.WindowState
        LastPage = [string]$nav.SelectedItem
        AppsSearch = ''
        AppsCategory = ''
        AppsFavOnly = $false
      }

      # capture Apps page filter controls if present
      try {
        if ($script:AppsSearch) { $st.AppsSearch = [string]$script:AppsSearch.Text }
        if ($script:AppsCategory) { $st.AppsCategory = [string]$script:AppsCategory.SelectedItem }
        if ($script:AppsFavOnly) { $st.AppsFavOnly = [bool]$script:AppsFavOnly.IsChecked }
      } catch { }

      Save-47UiState -State $st
    } catch { }
  })


iMessage $_.Exception.Message }
  })

  $grid.Children.Add($hdr) | Out-Null
  $grid.Children.Add($navBorder) | Out-Null
  $grid.Children.Add($rightGrid) | Out-Null
  $grid.Children.Add($status) | Out-Null
  $win.Content = $grid

  GuiLog "GUI started." 'INFO'
  
  # Hotkeys
  $win.Add_KeyDown({
    param($sender,$e)
    try {
      if (($e.Key -eq [System.Windows.Input.Key]::K) -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
        $e.Handled = $true
        Show-47CommandPalette
      }
    } catch { }
  })

  try { Update-47ActionGates } catch { }

$win.ShowDialog() | Out-Null
  return $true
}
#endregion

if ($Help) { Show-Usage; return }

# GUI auto-launch (Windows only) unless disabled.
if (-not $NoGui -and -not $Menu -and -not $Command) {
  if ($Gui -or (Test-47GuiAvailable)) {
    $launched = Show-47Gui
    if ($launched) { return }
  }
}


Write-47Banner

if ($Menu) {
  if ($script:JsonMode) {
    Write-Output (Write-47Json -Object (Get-47MenuModel -Registry $script:CommandRegistry))
  } else {
    Write-47Menu -Registry $script:CommandRegistry
  }
  return
}

if ($Command) {
  if ($Command -eq '0') { return }
  try {
    $result = Invoke-47CommandKey -Key $Command
    if ($script:JsonMode) {
      Write-Output (Write-47Json -Object ([pscustomobject]@{ ok=$true; command=$Command; result=$result }))
    } elseif ($null -ne $result) {
      Write-Output $result
    }
  } catch {
    if ($script:JsonMode) {
      Write-Output (Write-47Json -Object ([pscustomobject]@{ ok=$false; command=$Command; error=$_.Exception.Message }))
      exit 1
    }
    throw
  }
  return
}

# Interactive loop
while ($true) {
  Write-47Menu -Registry $script:CommandRegistry

  $validKeys = @('0') + @($script:CommandRegistry.Keys)
  $sel = Read-47Choice -Prompt 'Select option' -Valid $validKeys -Default '0'

  if ($sel -eq '0') { break }

  $cmd = $script:CommandRegistry[$sel]
  if (-not $cmd) { Write-Warning 'Unknown selection.'; continue }

  try {
    & $cmd.Handler
  } catch {
    Write-Warning $_
  }
}
#endregion

# Project47 - AppS - Crawler (Installer Suite)
# BUILD: Ultimate v1_62 (Matrix rain timer pinned + visible + parse fixes)
# Copyright (c) 2025 47Project and More
# License: MIT (attribution required - keep this notice)
# Third-party apps are owned by their respective publishers. This script does NOT grant rights to third-party software.
# AI-assisted development: this project may include AI-assisted code. More: https://47.bearguard.cloud/47project
# NOTE: Some embedded snippets (if any) must keep their original attributions/licenses.

[CmdletBinding()]
param(
  [switch]$RunUI,
  [switch]$NoConsole,
  [switch]$SafeMode,
  [switch]$NoUI,
  [string]$ApplyProfile = '',
  [ValidateSet('','download','install','update','uninstall','scanupdates','inventory')] [string]$Action = '',
  [ValidateSet('interactive','auto')] [string]$InstallMode = 'interactive',
  [ValidateSet('csv','json')] [string]$Format = 'csv'
)
# ------------
# Failsafe: capture any terminating error in the UI child process and show a dialog + write a log.
# ------------
$script:FallbackLog = Join-Path $PSScriptRoot '47Suite.fatal.log'
function Write-FatalLog([string]$Text){
  try { Add-Content -LiteralPath $script:FallbackLog -Value $Text -Encoding UTF8 -Force } catch {}
}
$ErrorActionPreference = 'Stop'
trap {
  $e = $_
  $msg = "[{0}] FATAL: {1}`r`n`r`nLocation: {2}:{3}`r`n`r`nStack:`r`n{4}" -f (Get-Date), ($e.Exception.Message), ($e.InvocationInfo.ScriptName), ($e.InvocationInfo.ScriptLineNumber), ($e.ScriptStackTrace)
  Write-FatalLog $msg
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show($msg, '47Project Suite - Fatal Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
  } catch {}
  break
}

# ----------------------------
# Process hygiene / environment
# ----------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Boot([string]$msg){
  try {
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    Add-Content -LiteralPath $script:BootLog -Value "[$ts] $msg" -Encoding UTF8
  } catch {}
}

# Ensure sane TEMP/TMP (some environments override these incorrectly). Prefer a machine-wide folder.
try {
  $candidates = @(
    'C:\47Project\Temp',
    (Join-Path $PSScriptRoot '_temp'),
    (Join-Path $env:LOCALAPPDATA 'Temp')
  ) | Where-Object { $_ -and $_.Trim() }

  foreach($cand in $candidates){
    try {
      if(-not (Test-Path -LiteralPath $cand)) { New-Item -ItemType Directory -Path $cand -Force | Out-Null }
      # Quick write test to ensure it's actually usable
      $probe = Join-Path $cand '.__47probe'
      'ok' | Set-Content -LiteralPath $probe -Encoding ASCII -Force
      Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue

      $env:TEMP = $cand
      $env:TMP  = $cand
      break
    } catch {}
  }
} catch {}


# Default folders
$BaseDir      = 'C:\47Project\47AppSCrawled'
$InstallRoot  = 'C:\47Project\Installed'
$ProfilesDir  = Join-Path $BaseDir 'profiles'
$ExportsDir   = Join-Path $BaseDir 'exports'
$LogsDir      = Join-Path $BaseDir 'logs'
$CatalogDir   = Join-Path $BaseDir 'catalog.d'
$DiagDir      = Join-Path $BaseDir 'diagnostics'
$DownloadsDir = Join-Path $BaseDir 'downloads'
$MetaDir      = Join-Path $DownloadsDir '_meta'
$SettingsPath = Join-Path $BaseDir 'settings.json'
# Enterprise settings (stored in settings.json -> enterprise)
if(-not (Get-Variable -Name Enterprise -Scope Script -ErrorAction SilentlyContinue)){
  $script:Enterprise = [ordered]@{
    lock = $false
    allowedMethods = @('winget','choco','download','portable')
    mirrorBase = ''
    proxy = ''
    useSystemProxy = $true
    tls = 'Tls12'
    allowlist = @()   # optional: ids/names considered "approved baseline"
    denylist  = @()   # optional: name/id fragments to block
  }
}


function Ensure-EnterpriseDefaults {
  # Adds new enterprise keys in-place without breaking existing settings.
  if(-not $script:Enterprise){ $script:Enterprise = [ordered]@{} }
  $defaults = [ordered]@{
    repoShare = ''
    requireSignedCatalog = $false
    catalogPublicKeyXml = ''
    certPinEnabled = $false
    certPinThumbprint = ''
    strictAllowlist = $false
    requireApproval = $false
    approvedPlanHash = ''
    logJsonl = $false
    writeEventLog = $false
    eventSource = '47ProjectSuite'
    policyFile = (Join-Path $BaseDir 'enterprise.policy.json')
    scriptUpdateBase = 'https://47.bearguard.cloud/project47/47crawler'
    requireSignedSelfUpdate = $false
  }
  foreach($k in $defaults.Keys){
    try {
      if(-not $script:Enterprise.Contains($k)) { $script:Enterprise[$k] = $defaults[$k] }
    } catch {
      try { $script:Enterprise | Add-Member -NotePropertyName $k -NotePropertyValue $defaults[$k] -Force } catch {}
    }
  }
}
Ensure-EnterpriseDefaults
$SnapshotsDir = Join-Path $BaseDir 'snapshots'
$PacksDir     = Join-Path $BaseDir 'packs'
$ChangelogPath = Join-Path $BaseDir 'CHANGELOG.txt'

foreach($d in @($BaseDir,$ProfilesDir,$ExportsDir,$LogsDir,$CatalogDir,$DiagDir,$DownloadsDir,$MetaDir,$InstallRoot,$SnapshotsDir,$PacksDir)){
  if(-not (Test-Path -LiteralPath $d)){ New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$script:BootLog = Join-Path $LogsDir '47-AppCrawler.boot.log'
Write-Boot "Boot: PS=$($PSVersionTable.PSVersion) STA=$([Threading.Thread]::CurrentThread.ApartmentState) RunUI=$RunUI SafeMode=$SafeMode"

# --------------------------------
# Relaunch: isolate WPF Application
# --------------------------------
# Always run UI in a fresh PowerShell process to avoid stale WPF Application instances.
if (-not $RunUI) {
  $self = $MyInvocation.MyCommand.Path
  if (-not $self) { throw "Cannot determine script path." }
  $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File', $self, '-RunUI')
  if ($NoConsole) { $argsList += '-NoConsole' }
  if ($SafeMode)  { $argsList += '-SafeMode' }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
  $psi.Arguments = ($argsList | ForEach-Object {
    if($_ -match '\s'){ '"' + $_.Replace('"','\"') + '"' } else { $_ }
  }) -join ' '
  $psi.UseShellExecute = $true
  # Hide console by default (users asked earlier). If you want console, run with -NoConsole:$false and remove WindowStyle below.
  $psi.WindowStyle = 'Hidden'  # Always hide child to avoid extra console window
  [System.Diagnostics.Process]::Start($psi) | Out-Null
  return
}

# ------------
# WPF imports
# ------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# -------------------------
# Matrix rain background (safe, lightweight)
# -------------------------
function Start-MatrixRain {
  param(
    [System.Windows.Window]$Window,
    [System.Windows.Controls.Canvas]$CanvasBG,
    [System.Windows.Controls.Canvas]$CanvasFG
  )
  try {
    if (-not $Window -or -not $CanvasBG -or -not $CanvasFG) { return }

    # Make sure rain never blocks clicks
    $CanvasBG.IsHitTestVisible = $false
    $CanvasFG.IsHitTestVisible = $false

    # Layering: BG behind everything, FG slightly above (still subtle)
    try { [System.Windows.Controls.Panel]::SetZIndex($CanvasBG, -5) } catch {}
    try { [System.Windows.Controls.Panel]::SetZIndex($CanvasFG, 50) } catch {}

    if (-not $script:MatrixRainRandom) { $script:MatrixRainRandom = New-Object System.Random }

    # ASCII-only to avoid encoding issues in .ps1 files
    $chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()

    function New-RainText([int]$lines) {
      $sb = New-Object System.Text.StringBuilder
      for ($i = 0; $i -lt $lines; $i++) {
        [void]$sb.Append($chars[$script:MatrixRainRandom.Next(0, $chars.Length)])
        if ($i -lt ($lines - 1)) { [void]$sb.Append("`n") }
      }
      return $sb.ToString()
    }

    function Build-RainLayer(
      [System.Windows.Controls.Canvas]$Canvas,
      [byte]$r, [byte]$g, [byte]$b,
      [double]$opacity,
      [int]$fontSize
    ) {
      $w = [int][Math]::Max(900, $Window.ActualWidth)
      $h = [int][Math]::Max(650, $Window.ActualHeight)

      # Canvas can report 0 size in some layouts; set explicit size
      $Canvas.Width  = $w
      $Canvas.Height = $h
      $Canvas.Children.Clear() | Out-Null

      $colWidth = 14
      $cols = [int]([Math]::Min(260, [Math]::Max(90, [Math]::Floor($w / $colWidth))))

      $brush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb($r, $g, $b))

      $items = @()
      for ($c = 0; $c -lt $cols; $c++) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.FontFamily = 'Consolas'
        $tb.FontSize   = $fontSize
        $tb.Foreground = $brush
        $tb.Opacity    = $opacity

        $lines = [int]([Math]::Min(90, [Math]::Max(26, [Math]::Floor($h / $fontSize))))
        $tb.Text = New-RainText $lines

        # Start in-view so you see it immediately
        [System.Windows.Controls.Canvas]::SetLeft($tb, ($c * $colWidth))
        [System.Windows.Controls.Canvas]::SetTop($tb, ($script:MatrixRainRandom.Next(0, [Math]::Max(1, $h))))
        $null = $Canvas.Children.Add($tb)

        $speed = 4 + $script:MatrixRainRandom.Next(0, 14)
        $items += [pscustomobject]@{ TB = $tb; Speed = $speed }
      }

      return ,$items
    }

    # Build once now
    $script:RainColsBG = Build-RainLayer -Canvas $CanvasBG -r 0 -g 255 -b 127 -opacity 0.55 -fontSize 16
    $script:RainColsFG = Build-RainLayer -Canvas $CanvasFG -r 0 -g 229 -b 255 -opacity 0.35 -fontSize 18
    $script:RainLastW  = [int]$Window.ActualWidth
    $script:RainLastH  = [int]$Window.ActualHeight

    # Restart timer if it exists
    if ($script:MatrixRainTimer) { try { $script:MatrixRainTimer.Stop() } catch {} }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(55)

    $timer.Add_Tick({
      try {
        $wNow = [int][Math]::Max(900, $Window.ActualWidth)
        $hNow = [int][Math]::Max(650, $Window.ActualHeight)

        # Rebuild on resize
        if ([Math]::Abs($wNow - $script:RainLastW) -gt 80 -or [Math]::Abs($hNow - $script:RainLastH) -gt 80) {
          $script:RainColsBG = Build-RainLayer -Canvas $CanvasBG -r 0 -g 255 -b 127 -opacity 0.55 -fontSize 16
          $script:RainColsFG = Build-RainLayer -Canvas $CanvasFG -r 0 -g 229 -b 255 -opacity 0.35 -fontSize 18
          $script:RainLastW  = $wNow
          $script:RainLastH  = $hNow
          return
        }

        foreach ($col in $script:RainColsBG) {
          if (-not $col -or -not $col.TB) { continue }
          $y = [System.Windows.Controls.Canvas]::GetTop($col.TB) + $col.Speed
          if ($y -gt ($hNow + 40)) {
            $y = -1 * $script:MatrixRainRandom.Next(40, 260)
            if ($script:MatrixRainRandom.NextDouble() -lt 0.55) {
              $lines = [int]([Math]::Min(90, [Math]::Max(26, [Math]::Floor($hNow / 16))))
              $col.TB.Text = New-RainText $lines
            }
          }
          [System.Windows.Controls.Canvas]::SetTop($col.TB, $y)
        }

        foreach ($col in $script:RainColsFG) {
          if (-not $col -or -not $col.TB) { continue }
          $y = [System.Windows.Controls.Canvas]::GetTop($col.TB) + [Math]::Max(3, [int]($col.Speed * 0.8))
          if ($y -gt ($hNow + 40)) {
            $y = -1 * $script:MatrixRainRandom.Next(40, 260)
            if ($script:MatrixRainRandom.NextDouble() -lt 0.45) {
              $lines = [int]([Math]::Min(90, [Math]::Max(26, [Math]::Floor($hNow / 18))))
              $col.TB.Text = New-RainText $lines
            }
          }
          [System.Windows.Controls.Canvas]::SetTop($col.TB, $y)
        }
      } catch {
        # Never let rain break the UI; if something goes wrong, keep going.
      }
    })

    $timer.Start()
    $script:MatrixRainTimer = $timer

    # Clean shutdown
    $Window.Add_Closed({
      try { if ($script:MatrixRainTimer) { $script:MatrixRainTimer.Stop() } } catch {}
    }) | Out-Null

  } catch {
    # If anything goes wrong, do nothing (never break the main UI)
  }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Web

# -----------------------
# Localization (ready)
# -----------------------
$L = @{
  Title = '47 - AppS - Crawler'
  SubTitle = 'Select apps -> download / winget / choco -> install/update/uninstall (suite)'
  Notice1 = 'Copyright (c) 2025 47Project and More'
  Notice2 = 'License: MIT (keep this notice for credit)'
  Notice3 = 'Third-party apps are owned by their publishers'
  SearchPlaceholder = 'Search apps...'
  CategoryAll = 'All'
  ProfileNone = 'Profile: None'
  BtnScan = 'Scan'
  BtnInstall = 'Install Selected'
  BtnUpdate = 'Update Selected'
  BtnUpdateAllInstalled = 'Update All Installed (Catalog)'
  BtnUninstall = 'Uninstall Selected (Managed)'
  BtnUninstallAll = 'Uninstall All Installed (Catalog, Managed)'
  BtnDownload = 'Download Selected'
  BtnSelectVisible = 'Select visible'
  BtnSelectMissing = 'Select missing'
  BtnInvertVisible = 'Invert visible'
  BtnClearVisible = 'Clear visible'
  BtnExportSelected = 'Export selected'
  BtnCopySelected = 'Copy selected'
  BtnOpenLogs = 'Open logs'
  BtnValidateCatalog = 'Validate catalog'
  BtnResetUI = 'Reset UI'
  BtnDryRun = 'Dry run'
  BtnSaveProfile = 'Save profile'
  BtnLoadProfile = 'Load profile'
  BtnOverwriteProfile = 'Overwrite profile'
  BtnDeleteProfile = 'Delete profile'
  BtnOpenProfiles = 'Open profiles folder'
  BtnOpenProfileFile = 'Open current profile file'
  BtnShare = 'Share profile'
  BtnCompareProfiles = 'Compare/Merge'
  BtnSnapshotSave = 'Save snapshot'
  BtnSnapshotLoad = 'Load snapshot'
  BtnExportPack = 'Export pack'
  BtnImportPack = 'Import pack'
  BtnPreflight = 'Readiness check'
  BtnSelfUpdate = 'Check for updates'
  BtnHelp = 'Help'
  CompactMode = 'Compact mode'
  SafeMode = 'Safe mode'
  IncludeInstalled = 'Include installed (reinstall/update)'
  InstalledOnly = 'Installed only'
  MissingOnly = 'Missing only'
  SelectedOnly = 'Selected only'
  FavoritesOnly = 'Favorites only'
  PortableOnly = 'Portable only'
  UpdateableOnly = 'Updateable only'
  OnlyUpdateIfInstalled = 'Only update if installed'
  ContinueOnErrors = 'Continue on errors'
  StopOnFailure = 'Stop on first failure'
  SkipAdminNeeded = 'Skip admin-needed (best effort)'
  ParallelDownloads = 'Parallel downloads'
  Concurrency = 'Concurrency'
  BtnApplyAutoProfile = 'Apply'
  ChkProfileClearFirst = 'Clear first'
  ChkProfileOnlyMissing = 'Only missing'
  BtnSelectRecommendedMissing = 'Select recommended missing'
  ProfileDesc_None = 'No auto-selection. Choose a profile and click Apply.'
  ProfileDesc_Minimal = 'Essentials: browser, archiver, notes, PDF/security basics.'
  ProfileDesc_Gaming = 'Gaming setup: launchers, chat/voice, capture/stream tools, GPU utilities.'
  ProfileDesc_Office = 'Office setup: documents, PDF, conferencing, mail/password tools.'
  ProfileDesc_Dev = 'Developer setup: editors/IDEs, git, runtimes, terminals, API tools.'
  ProfileDesc_Creator = 'Creator setup: media/graphics tools, editing, capture utilities.'
  ProfileDesc_Sysadmin = 'Sysadmin setup: remote, network, disk tools, imaging, diagnostics.'
  ProfileDesc_Portable = 'Portable toolkit: selects portable-tagged utilities.'

}

# -----------------------
# Utilities
# -----------------------
function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Show-Message([string]$text, [string]$caption='47Project', [string]$icon='Information'){
  # Accept friendly icon names (Info/Warn/Error) and map to MessageBoxImage enum members
  $iconNorm = [string]$icon
  switch -Regex ($iconNorm) {
    '^(info|information)$' { $iconNorm = 'Information' }
    '^(warn|warning|exclamation)$' { $iconNorm = 'Warning' }
    '^(err|error|stop|hand)$' { $iconNorm = 'Error' }
    '^(question)$' { $iconNorm = 'Question' }
    default {
      # If unknown, fall back safely
      $iconNorm = 'Information'
    }
  }
  $img = [System.Windows.MessageBoxImage]::$iconNorm
  [System.Windows.MessageBox]::Show($text,$caption,[System.Windows.MessageBoxButton]::OK,$img) | Out-Null
}

function Open-ExplorerSelect([string]$path){
  if(-not $path){ return }
  if(Test-Path -LiteralPath $path){
    Start-Process explorer.exe -ArgumentList "/select,`"$path`"" | Out-Null
  } else {
    $dir = Split-Path -Parent $path
    if(Test-Path -LiteralPath $dir){ Start-Process explorer.exe -ArgumentList "`"$dir`"" | Out-Null }
  }
}

function Open-Explorer([string]$dir){
  if(-not $dir){ return }
  if(Test-Path -LiteralPath $dir){ Start-Process explorer.exe -ArgumentList "`"$dir`"" | Out-Null }
}

function Get-NowStamp(){ (Get-Date).ToString('yyyyMMdd_HHmmss') }

function Read-JsonFile([string]$path){
  if(Test-Path -LiteralPath $path){
    try { return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
  }
  return $null
}
function Write-JsonFile([string]$path, $obj){
  $json = $obj | ConvertTo-Json -Depth 6
  Set-Content -LiteralPath $path -Value $json -Encoding UTF8
}

# -----------------------
# Policy / Inventory / History helpers
# -----------------------
function Get-PolicyObject {
  $policy = [ordered]@{
    schema = '47Project.AppCrawler.Policy.v1'
    generated = (Get-Date).ToString('s')
    baseDir = $BaseDir
    defaults = @{
      downloadsDir = $DownloadsDir
      installRoot  = $InstallRoot
    }
    overrides = @{}
  }
  foreach($it in $items){
    $policy.overrides[$it.Name] = @{
      PreferredMethod = [string]$it.PreferredMethod
      PinnedVersion   = [string]$it.PinnedVersion
      Skip            = [bool]$it.Skip
      UserNote        = [string]$it.UserNote
      Profiles        = @($it.Profiles)
      WingetId        = [string]$it.WingetId
      ChocoId         = [string]$it.ChocoId
      Category        = [string]$it.Category
    }
  }
  return $policy
}

function Export-Policy([string]$path){
  $p = Get-PolicyObject
  Write-JsonFile $path $p
  return $path
}

function Import-Policy([string]$path){
  $p = Read-JsonFile $path
  if(-not $p -or -not $p.overrides){ throw "Invalid policy file." }
  foreach($it in $items){
    $o = $p.overrides[$it.Name]
    if(-not $o){ continue }
    if($o.PreferredMethod){ $it.PreferredMethod = [string]$o.PreferredMethod }
    if($o.PinnedVersion -ne $null){ $it.PinnedVersion = [string]$o.PinnedVersion }
    if($o.Skip -ne $null){ $it.Skip = [bool]$o.Skip }
    if($o.UserNote -ne $null){ $it.UserNote = [string]$o.UserNote }
    if($o.Profiles){ $it.Profiles = @($o.Profiles) }
  }
  if (Get-Command Save-OverridesToSettings -ErrorAction SilentlyContinue) { Save-OverridesToSettings }
}

function Export-InventoryCsv([string]$path){
  $rows = foreach($it in $items){
    [pscustomobject]@{
      Name = $it.Name
      Category = $it.Category
      Method = $it.Method
      PreferredMethod = $it.PreferredMethod
      WingetId = $it.WingetId
      ChocoId = $it.ChocoId
      Installed = [bool]$it.IsInstalled
      Selected = [bool]$it.IsSelected
      Favorite = [bool]$it.IsFavorite
      Portable = [bool]$it.IsPortable
      Updateable = [bool]$it.IsUpdateable
      Skip = [bool]$it.Skip
      Note = [string]$it.UserNote
      Profiles = ($it.Profiles -join ';')
    }
  }
  $rows | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8
  return $path
}

# -----------------------
# Enterprise helpers (inventory/compliance)
# -----------------------
function Get-RegistryInventory {
  $list = New-Object System.Collections.Generic.List[object]
  $paths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  foreach($p in $paths){
    try {
      $rows = Get-ItemProperty -Path $p -EA SilentlyContinue
      foreach($r in $rows){
        $dn = [string]$r.DisplayName
        if([string]::IsNullOrWhiteSpace($dn)){ continue }
        $list.Add([pscustomobject]@{
          Source = 'registry'
          Name = $dn
          Version = [string]$r.DisplayVersion
          Publisher = [string]$r.Publisher
          InstallLocation = [string]$r.InstallLocation
          UninstallString = [string]$r.UninstallString
        }) | Out-Null
      }
    } catch {}
  }
  return $list
}

function Get-SystemInventory {
  $inv = New-Object System.Collections.Generic.List[object]

  # winget
  if(Get-Command winget -EA SilentlyContinue){
    $out = Invoke-WithTimeout -TimeoutSec 15 -Script { & winget list --disable-interactivity 2>$null }
    if($out){
      foreach($line in ($out -split "`r?`n")){
        if($line -match '^\s*$'){ continue }
        if($line -match '\s([A-Za-z0-9]+\.[A-Za-z0-9\.\-]+)\s+([0-9][0-9A-Za-z\.\-\+]+)'){
          $id = $Matches[1]; $ver = $Matches[2]
          $inv.Add([pscustomobject]@{ Source='winget'; Id=$id; Name=''; Version=$ver; Publisher=''; InstallLocation='' }) | Out-Null
        }
      }
    }
  }

  # choco
  if(Get-Command choco -EA SilentlyContinue){
    $out = Invoke-WithTimeout -TimeoutSec 15 -Script { & choco list --local-only --limit-output 2>$null }
    if($out){
      foreach($line in ($out -split "`r?`n")){
        if($line -match '^([A-Za-z0-9\.\-_]+)\|(.+)$'){
          $id = $Matches[1]; $ver = $Matches[2]
          $inv.Add([pscustomobject]@{ Source='choco'; Id=$id; Name=''; Version=$ver; Publisher=''; InstallLocation='' }) | Out-Null
        }
      }
    }
  }

  # registry
  foreach($r in (Get-RegistryInventory)){
    $inv.Add([pscustomobject]@{ Source='registry'; Id=''; Name=$r.Name; Version=$r.Version; Publisher=$r.Publisher; InstallLocation=$r.InstallLocation }) | Out-Null
  }

  return $inv
}


function Export-SBOMLite {
  param(
    [Parameter(Mandatory)] [string]$CsvPath,
    [Parameter(Mandatory)] [string]$JsonPath
  )
  $inv = Get-SystemInventory
  $sb = @()
  foreach($i in $inv){
    $sb += [pscustomobject]@{
      Name = [string]$i.Name
      Version = [string]$i.Version
      Publisher = [string]$i.Publisher
      Source = [string]$i.Source
      Id = [string]$i.Id
      InstallLocation = [string]$i.InstallLocation
    }
  }
  $sb | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
  $sb | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
  return $CsvPath
}

function Export-SystemInventory {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [ValidateSet('csv','json')] [string]$Format = 'csv'
  )
  $inv = Get-SystemInventory
  if($Format -eq 'json'){
    $inv | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Encoding UTF8
  } else {
    $inv | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
  }
  return $Path
}

function _NormKey([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "" }
  return (($s -replace '[^a-zA-Z0-9]','').ToLowerInvariant())
}

function Build-ComplianceReport {
  param(
    [Parameter(Mandatory)] [System.Collections.IEnumerable]$Items,
    [string]$Profile = '',
    [string[]]$AllowList,
    [string[]]$DenyList
  )

  $baseline = @()
  if($AllowList -and $AllowList.Count -gt 0){
    $allow = @($AllowList | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
    foreach($it in $Items){
      $k = ("$($it.WingetId) $($it.ChocoId) $($it.Name)").ToLowerInvariant()
      if($allow | Where-Object { $k -like ("*" + $_ + "*") } | Select-Object -First 1){
        $baseline += $it
      }
    }
  } elseif($Profile -and $Profile -ne 'None'){
    $baseline = @($Items | Where-Object { $_.Profiles -and ($_.Profiles -contains $Profile) })
  } else {
    $baseline = @($Items | Where-Object { $_.IsSelected })
  }

  $missing = @($baseline | Where-Object { -not $_.IsInstalled })
  $extraManaged = @($Items | Where-Object { $_.IsInstalled -and (-not ($baseline | Where-Object { $_.Name -eq $PSItem.Name } | Select-Object -First 1)) })

  $deniedInstalled = @()
  if($DenyList -and $DenyList.Count -gt 0){
    $deny = @($DenyList | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
    foreach($it in $Items | Where-Object { $_.IsInstalled }){
      $k = ("$($it.WingetId) $($it.ChocoId) $($it.Name)").ToLowerInvariant()
      if($deny | Where-Object { $k -like ("*" + $_ + "*") } | Select-Object -First 1){
        $deniedInstalled += $it
      }
    }
  }

  return [pscustomobject]@{
    Timestamp = (Get-Date).ToString('s')
    BaselineType = if($AllowList -and $AllowList.Count -gt 0){ 'AllowList' } elseif($Profile){ "Profile:$Profile" } else { 'CurrentSelection' }
    BaselineCount = $baseline.Count
    Missing = @($missing | Select-Object Name,Category,Method,WingetId,ChocoId,InstalledVersion)
    ExtraManagedInstalled = @($extraManaged | Select-Object Name,Category,Method,WingetId,ChocoId,InstalledVersion)
    DeniedInstalled = @($deniedInstalled | Select-Object Name,Category,Method,WingetId,ChocoId,InstalledVersion)
  }
}

function Export-ComplianceReport {
  param(
    [Parameter(Mandatory)] [object]$Report,
    [Parameter(Mandatory)] [string]$Path,
    [ValidateSet('json','csv')] [string]$Format='json'
  )
  if($Format -eq 'json'){
    $Report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
  } else {
    # CSV is "flattened" by section
    $rows = New-Object System.Collections.Generic.List[object]
    foreach($m in @($Report.Missing)){ $rows.Add([pscustomobject]@{Section='Missing'; Name=$m.Name; Category=$m.Category; Method=$m.Method; WingetId=$m.WingetId; ChocoId=$m.ChocoId; InstalledVersion=$m.InstalledVersion}) | Out-Null }
    foreach($m in @($Report.ExtraManagedInstalled)){ $rows.Add([pscustomobject]@{Section='ExtraManagedInstalled'; Name=$m.Name; Category=$m.Category; Method=$m.Method; WingetId=$m.WingetId; ChocoId=$m.ChocoId; InstalledVersion=$m.InstalledVersion}) | Out-Null }
    foreach($m in @($Report.DeniedInstalled)){ $rows.Add([pscustomobject]@{Section='DeniedInstalled'; Name=$m.Name; Category=$m.Category; Method=$m.Method; WingetId=$m.WingetId; ChocoId=$m.ChocoId; InstalledVersion=$m.InstalledVersion}) | Out-Null }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
  }
  return $Path
}

function Show-EnterpriseCenter {
  try {
    $ex = [string]$ExportsDir
    $x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="47Project - Enterprise &amp; IT / Labs"
        Height="640" Width="920" WindowStartupLocation="CenterOwner"
        Background="#070A07" Foreground="#00FF7F" FontFamily="Consolas">
  <Window.Resources>
    <!-- Enterprise Center styles: keep text readable even when disabled -->
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="#B6FFD6"/>
      <Setter Property="Opacity" Value="0.95"/>
      <Style.Triggers>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Foreground" Value="#B6FFD6"/>
          <Setter Property="Opacity" Value="0.85"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#B6FFD6"/>
      <Setter Property="Opacity" Value="0.95"/>
      <Setter Property="Margin" Value="8,2"/>
      <Style.Triggers>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Foreground" Value="#B6FFD6"/>
          <Setter Property="Opacity" Value="0.85"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style TargetType="Button">
      <Setter Property="Background" Value="#0B120B"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,5"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#B6FFD6"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="CaretBrush" Value="#00FF7F"/>
    </Style>

    
    <!-- ComboBox dropdown styling (dark popup + readable items) -->
    <Style x:Key="MatrixComboBoxItem" TargetType="ComboBoxItem">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#B6FFD6"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
      <Style.Triggers>
        <Trigger Property="IsHighlighted" Value="True">
          <Setter Property="Background" Value="#102810"/>
          <Setter Property="Foreground" Value="#00FF7F"/>
        </Trigger>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#103010"/>
          <Setter Property="Foreground" Value="#00FF7F"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#B6FFD6"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="6,2"/>
      <Setter Property="MaxDropDownHeight" Value="260"/>
      <Setter Property="ItemContainerStyle" Value="{StaticResource MatrixComboBoxItem}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border x:Name="Bd"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}"
                      CornerRadius="4"
                      SnapsToDevicePixels="True">
                <DockPanel LastChildFill="True">
                  <ToggleButton x:Name="ToggleBtn" DockPanel.Dock="Right"
                                Focusable="False"
                                Width="24"
                                Background="Transparent"
                                BorderThickness="0"
                                IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                    <Path Fill="#00FF7F" Data="M 0 0 L 4 4 L 8 0 Z" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </ToggleButton>
                  <ContentPresenter Margin="{TemplateBinding Padding}"
                                    VerticalAlignment="Center"
                                    HorizontalAlignment="Left"
                                    Content="{TemplateBinding SelectionBoxItem}"
                                    ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                    ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"/>
                </DockPanel>
              </Border>

              <Popup x:Name="Popup"
                     Placement="Bottom"
                     IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True"
                     Focusable="False"
                     PopupAnimation="Fade">
                <Border Background="#050A05" BorderBrush="#00FF7F" BorderThickness="1" CornerRadius="4" Padding="1">
                  <ScrollViewer CanContentScroll="True"
                                Background="#050A05"
                                VerticalScrollBarVisibility="Auto"
                                HorizontalScrollBarVisibility="Disabled"
                                MaxHeight="{TemplateBinding MaxDropDownHeight}">
                    <ScrollViewer.Resources>
                      <Style TargetType="ScrollBar">
                        <Setter Property="Width" Value="10"/>
                        <Setter Property="Background" Value="#050A05"/>
                        <Setter Property="Template">
                          <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                              <Grid Background="{TemplateBinding Background}">
                                <Track x:Name="PART_Track" IsDirectionReversed="True">
                                  <Track.Thumb>
                                    <Thumb Background="#00FF7F" Opacity="0.65" Height="20" Width="8"/>
                                  </Track.Thumb>
                                </Track>
                              </Grid>
                            </ControlTemplate>
                          </Setter.Value>
                        </Setter>
                      </Style>
                    </ScrollViewer.Resources>
                    <Border Background="#050A05">
                      <ItemsPresenter/>
                    </Border>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

</Window.Resources>

  <Grid Margin="12">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,10">
      <TextBlock Text="Enterprise &amp; Labs/IT Center" Foreground="#00FFFF" FontSize="14" FontWeight="Bold" Opacity="0.95"/>
      <TextBlock Text="Enterprise upgrades are optional (Labs/IT). Main installer stays simple." Opacity="0.85" Margin="0,2,0,0"/>
    </StackPanel>

    <TabControl Grid.Row="1" Background="#070A07" BorderBrush="#00FF7F">
      <TabItem Header="Inventory">
        <StackPanel Margin="10">
          <TextBlock Text="Export system inventory (registry + winget + choco). Uses timeouts so it won't hang." Margin="0,0,0,8"/>
          <WrapPanel>
            <Button x:Name="BtnSysInvCsv" Content="Export system inventory CSV" Margin="0,0,8,8"/>
            <Button x:Name="BtnSysInvJson" Content="Export system inventory JSON" Margin="0,0,8,8"/>
            <Button x:Name="BtnOpenExports" Content="Open exports folder" Margin="0,0,8,8"/>
            <Button x:Name="BtnExportSBOM" Content="Export SBOM-lite (CSV/JSON)" Margin="0,0,8,8"/>
          </WrapPanel>
          <TextBox x:Name="TxtInvOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F"/>
        </StackPanel>
      </TabItem>

      <TabItem Header="Compliance">
        <StackPanel Margin="10">
          <TextBlock Text="Baseline = AllowList (if set) else selected profile else current selection." Margin="0,0,0,8"/>
          <WrapPanel>
            <TextBlock Text="Baseline profile:" VerticalAlignment="Center" Margin="0,0,8,8"/>
            <ComboBox x:Name="CmbBaseline" Width="180" Margin="0,0,12,8"/>
            <Button x:Name="BtnGenCompliance" Content="Generate report" Margin="0,0,8,8"/>
            <Button x:Name="BtnExportCompJson" Content="Export JSON" Margin="0,0,8,8"/>
            <Button x:Name="BtnExportCompCsv" Content="Export CSV" Margin="0,0,8,8"/>
          </WrapPanel>
          <TextBox x:Name="TxtCompOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F" Margin="0,0,0,8"/>
          <TextBox x:Name="TxtCompSummary" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Height="320"
                   Background="#050A05" BorderBrush="#00FF7F"/>
        </StackPanel>
      </TabItem>

      <TabItem Header="Policy">
        <StackPanel Margin="10">
          <TextBlock Text="Lock mode limits allowed install methods. Denylist blocks specific apps. Saved in settings.json." Margin="0,0,0,8"/>
          <CheckBox x:Name="ChkLock" Content="Enable enterprise lock mode (allowed methods only)" Margin="0,0,0,8"/>
          <TextBlock Text="Allowed methods:" Margin="0,0,0,4"/>
          <WrapPanel>
            <CheckBox x:Name="ChkM_Winget" Content="winget" Margin="0,0,10,8"/>
            <CheckBox x:Name="ChkM_Choco" Content="choco" Margin="0,0,10,8"/>
            <CheckBox x:Name="ChkM_Download" Content="download" Margin="0,0,10,8"/>
            <CheckBox x:Name="ChkM_Portable" Content="portable" Margin="0,0,10,8"/>
          </WrapPanel>

          <CheckBox x:Name="ChkStrictAllow" Content="Strict allowlist (block anything not in AllowList)" Margin="0,0,0,8"/>

    <TextBlock Text="AllowList (one per line, optional):" Margin="0,6,0,2"/>
          <TextBox x:Name="TxtAllow" AcceptsReturn="True" Height="90" Background="#050A05" BorderBrush="#00FF7F"/>

          <TextBlock Text="DenyList (one per line, blocks by name/id fragment):" Margin="0,8,0,2"/>
          <TextBox x:Name="TxtDeny" AcceptsReturn="True" Height="90" Background="#050A05" BorderBrush="#00FF7F"/>

          <WrapPanel Margin="0,10,0,0">
            <Button x:Name="BtnSavePolicy" Content="Save enterprise policy" Margin="0,0,8,0"/>
            <Button x:Name="BtnReloadPolicy" Content="Reload from settings" Margin="0,0,8,0"/>
          </WrapPanel>
        </StackPanel>
      </TabItem>

      <TabItem Header="Network">
        <StackPanel Margin="10">
          <TextBlock Text="Optional: internal mirror and/or proxy for downloads (main UI unaffected)." Margin="0,0,0,8"/>
          <TextBlock Text="Mirror base URL (example: https://mirror.company.local/files)"/>
          <TextBox x:Name="TxtMirror" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="0,2,0,8"/>
          <TextBlock Text="Proxy (example: http://proxy:8080)"/>
          <TextBox x:Name="TxtProxy" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="0,2,0,8"/>
          <CheckBox x:Name="ChkSysProxy" Content="Use system proxy when proxy is blank" Margin="0,0,0,10"/>
          <WrapPanel>
            <Button x:Name="BtnSaveNet" Content="Save network settings" Margin="0,0,8,0"/>
          </WrapPanel>
        </StackPanel>
      </TabItem>

      <TabItem Header="Headless">
        <StackPanel Margin="10">
          <TextBlock Text="Basic headless mode is supported (no UI) for labs/automation." Margin="0,0,0,8"/>
          <TextBlock Text="Examples:" Margin="0,0,0,2"/>
          <TextBox AcceptsReturn="True" IsReadOnly="True" Height="140"
Background="#050A05" BorderBrush="#00FF7F"
Text=".\\Project47_AppCrawler.ps1 -NoUI -ApplyProfile Gaming -Action install -InstallMode auto
.\\Project47_AppCrawler.ps1 -NoUI -ApplyProfile Office -Action update
.\\Project47_AppCrawler.ps1 -NoUI -Action inventory -Format csv"/>
        </StackPanel>
      </TabItem>

<TabItem Header="Sources">
  <StackPanel Margin="10">
    <TextBlock Text="Health checks for package sources (safe)." Margin="0,0,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnWingetSources" Content="winget source list" Margin="0,0,8,8"/>
      <Button x:Name="BtnWingetReset" Content="winget source reset" Margin="0,0,8,8"/>
      <Button x:Name="BtnWingetRepair" Content="Install/Repair winget (App Installer)" Margin="0,0,8,8"/>
      <Button x:Name="BtnChocoSources" Content="choco source list" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBox x:Name="TxtSourcesOut" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Height="340" Background="#050A05" BorderBrush="#00FF7F"/>
  </StackPanel>
</TabItem>

<TabItem Header="Bundle">
  <StackPanel Margin="10">
    <TextBlock Text="Export/Import enterprise bundle (settings + profiles + catalog.d)." Margin="0,0,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnExportBundle" Content="Export bundle (.zip)" Margin="0,0,8,8"/>
      <Button x:Name="BtnImportBundle" Content="Import bundle (.zip)" Margin="0,0,8,8"/>
      <Button x:Name="BtnOpenBaseDir" Content="Open base folder" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBox x:Name="TxtBundleOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F"/>
  </StackPanel>
</TabItem>

<TabItem Header="Config-as-Code">
  <StackPanel Margin="10">
    <TextBlock Text="Export/Apply enterprise.policy.json (Git-friendly)." Margin="0,0,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnExportPolicyFile" Content="Export policy file" Margin="0,0,8,8"/>
      <Button x:Name="BtnApplyPolicyFile" Content="Apply policy file" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBlock Text="Policy file path:"/>
    <TextBox x:Name="TxtPolicyFile" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="0,2,0,8"/>
  </StackPanel>
</TabItem>

<TabItem Header="Repo">
  <StackPanel Margin="10">
    <TextBlock Text="Offline repo/share for labs: copy-first installs + repo builder." Margin="0,0,0,8"/>
    <TextBlock Text="Repo share path (optional):"/>
    <TextBox x:Name="TxtRepoShare" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="0,2,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnSaveRepo" Content="Save repo share" Margin="0,0,8,8"/>
      <Button x:Name="BtnBuildRepo" Content="Build offline repo from downloads" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBox x:Name="TxtRepoOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F"/>
  </StackPanel>
</TabItem>

<TabItem Header="Change Control">
  <StackPanel Margin="10">
    <TextBlock Text="Optional approval gate for runs. Generates a Run Plan file." Margin="0,0,0,8"/>
    <CheckBox x:Name="ChkRequireApproval" Content="Require approval before executing queue" Margin="0,0,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnGeneratePlan" Content="Generate Run Plan (current queue)" Margin="0,0,8,8"/>
      <Button x:Name="BtnApprovePlan" Content="Approve last plan" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBox x:Name="TxtPlanOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F"/>
  </StackPanel>
</TabItem>


<TabItem Header="Intune/SCCM">
  <StackPanel Margin="10">
    <TextBlock Text="Export helper templates for Intune/SCCM packaging (safe, no deployment required)." Margin="0,0,0,8"/>
    <WrapPanel>
      <Button x:Name="BtnExportIntunePack" Content="Export packaging helper pack" Margin="0,0,8,8"/>
      <Button x:Name="BtnOpenIntunePack" Content="Open last pack folder" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBox x:Name="TxtIntuneOut" Height="22" IsReadOnly="True" Background="#050A05" BorderBrush="#00FF7F"/>
    <TextBox x:Name="TxtIntuneHelp" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" Height="260" Background="#050A05" BorderBrush="#00FF7F" Margin="0,8,0,0"/>
  </StackPanel>
</TabItem>

<TabItem Header="Signing &amp; Logs">
  <StackPanel Margin="10">
    <TextBlock Text="Signed catalog is optional; enable only if you publish .sig + public key." Margin="0,0,0,8"/>
    <CheckBox x:Name="ChkRequireSignedCatalog" Content="Require signed catalogs" Margin="0,0,0,8"/>
    <TextBlock Text="Catalog public key (RSA XML):"/>
    <TextBox x:Name="TxtPubKey" AcceptsReturn="True" Height="120" Background="#050A05" BorderBrush="#00FF7F" Margin="0,2,0,8"/>
    <TextBlock Text="Catalog host certificate pin (optional, enterprise):" Margin="0,4,0,2"/>
    <WrapPanel>
      <CheckBox x:Name="ChkCertPin" Content="Enable certificate pinning for catalog host" Margin="0,0,12,0"/>
      <TextBlock Text="Thumbprint:" VerticalAlignment="Center"/>
      <TextBox x:Name="TxtCertPin" Width="260" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="6,0,0,0"/>
    </WrapPanel>

<WrapPanel>
      <Button x:Name="BtnSaveSigning" Content="Save signing settings" Margin="0,0,8,8"/>
      <Button x:Name="BtnOpenUpdatePage" Content="Open update page" Margin="0,0,8,8"/>
    </WrapPanel>
    <TextBlock Text="Logging:" Margin="0,6,0,2"/>
    <WrapPanel>
      <CheckBox x:Name="ChkJsonl" Content="Write JSONL log" Margin="0,0,12,0"/>
      <CheckBox x:Name="ChkEvent" Content="Write Windows Event Log" Margin="0,0,12,0"/>
      <TextBlock Text="Source:" VerticalAlignment="Center"/>
      <TextBox x:Name="TxtEventSource" Width="160" Height="22" Background="#050A05" BorderBrush="#00FF7F" Margin="6,0,0,0"/>
      <Button x:Name="BtnSaveLogging" Content="Save logging" Margin="12,0,0,0"/>
    </WrapPanel>
  </StackPanel>
</TabItem>

    </TabControl>

    <DockPanel Grid.Row="2" Margin="0,10,0,0">
      <TextBlock DockPanel.Dock="Left" Text="Tip: enterprise controls are saved in settings.json -> enterprise" Opacity="0.75"/>
      <Button DockPanel.Dock="Right" x:Name="BtnClose" Content="Close" Width="120"/>
    </DockPanel>
  </Grid>
</Window>
"@

    $r = New-Object System.Xml.XmlNodeReader ([xml]$x)
    $w = [Windows.Markup.XamlReader]::Load($r)

    $find2 = { param($n) $w.FindName($n) }
    $BtnSysInvCsv = & $find2 'BtnSysInvCsv'
    $BtnSysInvJson = & $find2 'BtnSysInvJson'
    $BtnOpenExports = & $find2 'BtnOpenExports'
    $BtnExportSBOM = & $find2 'BtnExportSBOM'
    $TxtInvOut = & $find2 'TxtInvOut'
    $CmbBaseline = & $find2 'CmbBaseline'
    $BtnGenCompliance = & $find2 'BtnGenCompliance'
    $BtnExportCompJson = & $find2 'BtnExportCompJson'
    $BtnExportCompCsv = & $find2 'BtnExportCompCsv'
    $TxtCompOut = & $find2 'TxtCompOut'
    $TxtCompSummary = & $find2 'TxtCompSummary'
    $ChkLock = & $find2 'ChkLock'
    $ChkM_Winget = & $find2 'ChkM_Winget'
    $ChkM_Choco  = & $find2 'ChkM_Choco'
    $ChkM_Download = & $find2 'ChkM_Download'
    $ChkM_Portable = & $find2 'ChkM_Portable'
    $ChkStrictAllow = & $find2 'ChkStrictAllow'
    $TxtAllow = & $find2 'TxtAllow'
    $TxtDeny  = & $find2 'TxtDeny'
    $BtnSavePolicy = & $find2 'BtnSavePolicy'
    $BtnReloadPolicy = & $find2 'BtnReloadPolicy'
    $TxtMirror = & $find2 'TxtMirror'
    $TxtProxy = & $find2 'TxtProxy'
    $ChkSysProxy = & $find2 'ChkSysProxy'
    $BtnSaveNet = & $find2 'BtnSaveNet'
    $BtnClose = & $find2 'BtnClose'

    # extra Enterprise Center controls
    $BtnWingetSources = & $find2 'BtnWingetSources'
    $BtnWingetReset   = & $find2 'BtnWingetReset'
    $BtnChocoSources  = & $find2 'BtnChocoSources'
    $TxtSourcesOut    = & $find2 'TxtSourcesOut'
    $BtnWingetRepair  = & $find2 'BtnWingetRepair'
    $BtnExportBundle  = & $find2 'BtnExportBundle'
    $BtnImportBundle  = & $find2 'BtnImportBundle'
    $BtnOpenBaseDir   = & $find2 'BtnOpenBaseDir'
    $TxtBundleOut     = & $find2 'TxtBundleOut'
    $BtnSaveSigning   = & $find2 'BtnSaveSigning'
    $BtnOpenUpdatePage = & $find2 'BtnOpenUpdatePage'
    $TxtPubKey        = & $find2 'TxtPubKey'
    $ChkRequireSignedCatalog = & $find2 'ChkRequireSignedCatalog'
    $ChkRequireApproval = & $find2 'ChkRequireApproval'
    $ChkJsonl         = & $find2 'ChkJsonl'
    $TxtPolicyFile    = & $find2 'TxtPolicyFile'
    $BtnExportPolicyFile = & $find2 'BtnExportPolicyFile'
    $BtnApplyPolicyFile  = & $find2 'BtnApplyPolicyFile'
    $TxtRepoShare     = & $find2 'TxtRepoShare'
    $BtnSaveRepo      = & $find2 'BtnSaveRepo'
    $BtnSaveLogging   = & $find2 'BtnSaveLogging'
    $BtnGeneratePlan  = & $find2 'BtnGeneratePlan'
    $BtnApprovePlan   = & $find2 'BtnApprovePlan'
    $BtnBuildRepo     = & $find2 'BtnBuildRepo'
    $BtnExportIntunePack = & $find2 'BtnExportIntunePack'
    $BtnOpenIntunePack   = & $find2 'BtnOpenIntunePack'


    # populate baseline profiles
    $CmbBaseline.Items.Clear()
    foreach($p in (Get-BuiltinProfiles)){ [void]$CmbBaseline.Items.Add($p) }
    $CmbBaseline.SelectedItem = 'None'

    $script:LastCompliance = $null

    function _ReloadEnterpriseUI {
      $ChkLock.IsChecked = [bool]$script:Enterprise.lock
      $allow = @($script:Enterprise.allowedMethods | ForEach-Object { ([string]$_).ToLowerInvariant() })
      $ChkM_Winget.IsChecked = ($allow -contains 'winget')
      $ChkM_Choco.IsChecked  = ($allow -contains 'choco')
      $ChkM_Download.IsChecked = ($allow -contains 'download')
      $ChkM_Portable.IsChecked = ($allow -contains 'portable')
      $TxtAllow.Text = (@($script:Enterprise.allowlist) -join "`r`n")
      $TxtDeny.Text  = (@($script:Enterprise.denylist) -join "`r`n")
      $TxtMirror.Text = [string]$script:Enterprise.mirrorBase
      $TxtProxy.Text = [string]$script:Enterprise.proxy
      $ChkSysProxy.IsChecked = [bool]$script:Enterprise.useSystemProxy
      try { if($TxtRepoShare){ $TxtRepoShare.Text = [string]$script:Enterprise.repoShare } } catch {}
      try { if($ChkRequireApproval){ $ChkRequireApproval.IsChecked = [bool]$script:Enterprise.requireApproval } } catch {}
      try { if($ChkRequireSignedCatalog){ $ChkRequireSignedCatalog.IsChecked = [bool]$script:Enterprise.requireSignedCatalog } } catch {}
      try { if($TxtPubKey){ $TxtPubKey.Text = [string]$script:Enterprise.catalogPublicKeyXml } } catch {}
      try { if($ChkCertPin){ $ChkCertPin.IsChecked = [bool]$script:Enterprise.certPinEnabled } } catch {}
      try { if($TxtCertPin){ $TxtCertPin.Text = [string]$script:Enterprise.certPinThumbprint } } catch {}
      try { if($TxtPolicyFile){ $TxtPolicyFile.Text = [string]$script:Enterprise.policyFile } } catch {}
      try { if($ChkJsonl){ $ChkJsonl.IsChecked = [bool]$script:Enterprise.logJsonl } } catch {}
      try { if($ChkEvent){ $ChkEvent.IsChecked = [bool]$script:Enterprise.writeEventLog } } catch {}
      try { if($TxtEventSource){ $TxtEventSource.Text = [string]$script:Enterprise.eventSource } } catch {}
    }
    _ReloadEnterpriseUI

    $BtnSysInvCsv.Add_Click({
      try {
        $path = Join-Path $ExportsDir ("system-inventory-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".csv")
        Export-SystemInventory -Path $path -Format csv | Out-Null
        $TxtInvOut.Text = $path
        UI-Log "System inventory CSV: $path"
      } catch { UI-Log "System inventory export failed: $($_.Exception.Message)" }
    }) | Out-Null

    $BtnSysInvJson.Add_Click({
      try {
        $path = Join-Path $ExportsDir ("system-inventory-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
        Export-SystemInventory -Path $path -Format json | Out-Null
        $TxtInvOut.Text = $path
        UI-Log "System inventory JSON: $path"
      } catch { UI-Log "System inventory export failed: $($_.Exception.Message)" }
    }) | Out-Null
    if($BtnExportSBOM){
      $BtnExportSBOM.Add_Click({
        try {
          $base = ("sbom-lite-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
          $csv = Join-Path $ExportsDir ($base + ".csv")
          $js  = Join-Path $ExportsDir ($base + ".json")
          Export-SBOMLite -CsvPath $csv -JsonPath $js | Out-Null
          $TxtInvOut.Text = $csv
          UI-Log "SBOM-lite exported: $csv and $js"
          [System.Windows.MessageBox]::Show("SBOM-lite exported:`r`n$csv`r`n$js", '47Project', 'OK', 'Information') | Out-Null
        } catch { UI-Log "SBOM export failed: $($_.Exception.Message)" }
      }) | Out-Null
    }


    $BtnOpenExports.Add_Click({ Open-Explorer $ExportsDir }) | Out-Null

    $BtnGenCompliance.Add_Click({
      try {
        $p = [string]$CmbBaseline.SelectedItem
        $rep = Build-ComplianceReport -Items $items -Profile $p -AllowList $script:Enterprise.allowlist -DenyList $script:Enterprise.denylist
        $script:LastCompliance = $rep
        $TxtCompSummary.Text = ("Baseline: " + $rep.BaselineType + "`r`n" +
                                "Missing: " + ($rep.Missing.Count) + "`r`n" +
                                "Extra managed installed: " + ($rep.ExtraManagedInstalled.Count) + "`r`n" +
                                "Denied installed: " + ($rep.DeniedInstalled.Count))
        $TxtCompOut.Text = "Ready (use Export)"
      } catch { UI-Log "Compliance report failed: $($_.Exception.Message)" }
    }) | Out-Null

    $BtnExportCompJson.Add_Click({
      try {
        if(-not $script:LastCompliance){ throw "Generate report first." }
        $path = Join-Path $ExportsDir ("compliance-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
        Export-ComplianceReport -Report $script:LastCompliance -Path $path -Format json | Out-Null
        $TxtCompOut.Text = $path
        UI-Log "Compliance JSON: $path"
      } catch { UI-Log "Compliance export failed: $($_.Exception.Message)" }
    }) | Out-Null

    $BtnExportCompCsv.Add_Click({
      try {
        if(-not $script:LastCompliance){ throw "Generate report first." }
        $path = Join-Path $ExportsDir ("compliance-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".csv")
        Export-ComplianceReport -Report $script:LastCompliance -Path $path -Format csv | Out-Null
        $TxtCompOut.Text = $path
        UI-Log "Compliance CSV: $path"
      } catch { UI-Log "Compliance export failed: $($_.Exception.Message)" }
    }) | Out-Null

    $BtnSavePolicy.Add_Click({
      try {
        $script:Enterprise.lock = [bool]$ChkLock.IsChecked
        $am = @()
        if($ChkM_Winget.IsChecked){ $am += 'winget' }
        if($ChkM_Choco.IsChecked){ $am += 'choco' }
        if($ChkM_Download.IsChecked){ $am += 'download' }
        if($ChkM_Portable.IsChecked){ $am += 'portable' }
        $script:Enterprise.allowedMethods = $am
        $script:Enterprise.allowlist = @($TxtAllow.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $script:Enterprise.strictAllowlist = [bool]$ChkStrictAllow.IsChecked
        $script:Enterprise.denylist  = @($TxtDeny.Text  -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        Save-Settings
        UI-Log "Enterprise policy saved to settings.json."
      } catch { UI-Log "Enterprise policy save failed: $($_.Exception.Message)" }
    }) | Out-Null

    $BtnReloadPolicy.Add_Click({
      try { Load-Settings; _ReloadEnterpriseUI; UI-Log "Enterprise policy reloaded." } catch {}
    }) | Out-Null

    $BtnSaveNet.Add_Click({
      try {
        $script:Enterprise.mirrorBase = [string]$TxtMirror.Text
        $script:Enterprise.proxy = [string]$TxtProxy.Text
        $script:Enterprise.useSystemProxy = [bool]$ChkSysProxy.IsChecked
        Save-Settings
        UI-Log "Enterprise network settings saved."
      } catch { UI-Log "Enterprise network save failed: $($_.Exception.Message)" }
    }) | Out-Null



if($BtnWingetSources){ $BtnWingetSources.Add_Click({ try { $TxtSourcesOut.Text = Get-WingetSourcesText } catch {} }) | Out-Null }
if($BtnWingetReset){ $BtnWingetReset.Add_Click({ try { $TxtSourcesOut.Text = Reset-WingetSourcesText } catch {} }) | Out-Null
    if($BtnWingetRepair){
      $BtnWingetRepair.Add_Click({
        try {
          UI-Log "Opening App Installer (winget provider) page..."
          Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1" | Out-Null
        } catch {
          try { Start-Process "https://apps.microsoft.com/detail/9nblggh4nns1" | Out-Null } catch {}
        }
      }) | Out-Null
    }
 }
if($BtnChocoSources){ $BtnChocoSources.Add_Click({ try { $TxtSourcesOut.Text = Get-ChocoSourcesText } catch {} }) | Out-Null }

if($BtnExportBundle){ $BtnExportBundle.Add_Click({
  try {
    $path = Join-Path $ExportsDir ("enterprise-bundle-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".zip")
    Export-EnterpriseBundle -Path $path | Out-Null
    if($TxtBundleOut){ $TxtBundleOut.Text = $path }
    UI-Log "Enterprise bundle exported: $path"
  } catch { UI-Log "Bundle export failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnImportBundle){ $BtnImportBundle.Add_Click({
  try {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "Zip (*.zip)|*.zip"
    if($dlg.ShowDialog()){
      Import-EnterpriseBundle -Path $dlg.FileName
      if($TxtBundleOut){ $TxtBundleOut.Text = $dlg.FileName }
      UI-Log "Enterprise bundle imported: $($dlg.FileName)"
      Load-Settings
      _ReloadEnterpriseUI
    }
  } catch { UI-Log "Bundle import failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnOpenBaseDir){ $BtnOpenBaseDir.Add_Click({ Open-Explorer $BaseDir }) | Out-Null }

if($BtnExportPolicyFile){ $BtnExportPolicyFile.Add_Click({
  try {
    $path = [string]$TxtPolicyFile.Text
    if([string]::IsNullOrWhiteSpace($path)){ $path = Join-Path $BaseDir 'enterprise.policy.json' }
    Export-EnterprisePolicyFile -Path $path | Out-Null
    $TxtPolicyFile.Text = $path
    UI-Log "Policy file exported: $path"
  } catch { UI-Log "Policy export failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnApplyPolicyFile){ $BtnApplyPolicyFile.Add_Click({
  try {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = "JSON (*.json)|*.json"
    if($dlg.ShowDialog()){
      Apply-EnterprisePolicyFile -Path $dlg.FileName
      Load-Settings
      _ReloadEnterpriseUI
      UI-Log "Policy file applied: $($dlg.FileName)"
    }
  } catch { UI-Log "Policy apply failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnSaveRepo){ $BtnSaveRepo.Add_Click({
  try { $script:Enterprise.repoShare = [string]$TxtRepoShare.Text; Save-Settings; UI-Log 'Repo share saved.' } catch {}
}) | Out-Null }

if($BtnBuildRepo){ $BtnBuildRepo.Add_Click({
  try {
    $repo = Join-Path $BaseDir ('repo-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $idx = Build-OfflineRepoFromDownloads -RepoRoot $repo
    if($TxtRepoOut){ $TxtRepoOut.Text = $idx }
    UI-Log "Offline repo built: $idx"
  } catch { UI-Log "Repo build failed: $($_.Exception.Message)" }
}) | Out-Null }

if($ChkRequireApproval){ $ChkRequireApproval.Add_Checked({ try { $script:Enterprise.requireApproval = $true; Save-Settings } catch {} }) | Out-Null }
if($ChkRequireApproval){ $ChkRequireApproval.Add_Unchecked({ try { $script:Enterprise.requireApproval = $false; Save-Settings } catch {} }) | Out-Null }

if($BtnGeneratePlan){ $BtnGeneratePlan.Add_Click({
  try {
    $queue = @($script:LastQueue | ForEach-Object { $_ })
    if($queue.Count -eq 0){ throw 'Queue is empty.' }
    $path = Join-Path $ExportsDir ("run_plan_" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    Write-RunPlan -Queue $queue -Path $path | Out-Null
    $script:LastPlanPath = $path
    if($TxtPlanOut){ $TxtPlanOut.Text = $path }
    UI-Log "Run plan generated: $path"
  } catch { UI-Log "Run plan failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnApprovePlan){ $BtnApprovePlan.Add_Click({
  try {
    if(-not $script:LastPlanPath -or -not (Test-Path -LiteralPath $script:LastPlanPath)){ throw 'No plan generated yet.' }
    $h = Hash-FileSHA256 $script:LastPlanPath
    $script:Enterprise.approvedPlanHash = $h
    Save-Settings
    if($TxtPlanOut){ $TxtPlanOut.Text = $script:LastPlanPath + ' (approved)' }
    UI-Log "Run plan approved (hash stored)."
  } catch { UI-Log "Approve failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnSaveSigning){ $BtnSaveSigning.Add_Click({
  try {
    $script:Enterprise.requireSignedCatalog = [bool]$ChkRequireSignedCatalog.IsChecked
    $script:Enterprise.catalogPublicKeyXml = [string]$TxtPubKey.Text
    $script:Enterprise.certPinEnabled = [bool]$ChkCertPin.IsChecked
    $script:Enterprise.certPinThumbprint = [string]$TxtCertPin.Text
    Save-Settings
    UI-Log 'Signing settings saved.'
  } catch { UI-Log "Signing save failed: $($_.Exception.Message)" }
}) | Out-Null }

if($BtnOpenUpdatePage){ $BtnOpenUpdatePage.Add_Click({
  try { Start-Process ($script:Enterprise.scriptUpdateBase) | Out-Null } catch {}
}) | Out-Null }

if($BtnSaveLogging){ $BtnSaveLogging.Add_Click({
  try {
    $script:Enterprise.logJsonl = [bool]$ChkJsonl.IsChecked
    $script:Enterprise.writeEventLog = [bool]$ChkEvent.IsChecked
    $script:Enterprise.eventSource = [string]$TxtEventSource.Text
    Save-Settings
    UI-Log 'Logging settings saved.'
  } catch { UI-Log "Logging save failed: $($_.Exception.Message)" }
}) | Out-Null }

    
    if($BtnExportIntunePack){
      $BtnExportIntunePack.Add_Click({
        try {
          $dir = Join-Path $ExportsDir ("intune-pack-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
          Ensure-Dir $dir
          $readme = @"
Project47 Suite - Intune/SCCM Helper Pack
This folder contains safe templates to help package apps for enterprise tools.
- detection_registry.ps1 : detection script template
- install_headless.ps1   : calls Project47 suite headless mode (example)
- uninstall_headless.ps1 : calls Project47 suite headless mode (example)
- app_manifest.json      : metadata template (fill in)
"@
          Set-Content -LiteralPath (Join-Path $dir "README.txt") -Value $readme -Encoding UTF8

          $detect = @"
# Detection script template (edit values)
param([string]`$DisplayNameContains = 'APPNAME')
`$keys = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach(`$k in `$keys){
  try {
    Get-ItemProperty `$k -ErrorAction SilentlyContinue | Where-Object {
      (`$_.DisplayName -and `$_.DisplayName -like ('*' + `$DisplayNameContains + '*'))
    } | ForEach-Object { exit 0 }
  } catch {}
}
exit 1
"@
          Set-Content -LiteralPath (Join-Path $dir "detection_registry.ps1") -Value $detect -Encoding UTF8

          $install = @"
# Example: headless install using Project47 Suite
param([string]`$Profile='Office')
`$here = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$suite = Join-Path `$here '..\Project47_AppCrawler_Suite.ps1'
powershell -ExecutionPolicy Bypass -File `$suite -NoUI -ApplyProfile `$Profile -Action install -InstallMode auto -ReportPath (Join-Path `$here 'report.json')
"@
          Set-Content -LiteralPath (Join-Path $dir "install_headless.ps1") -Value $install -Encoding UTF8

          $uninstall = @"
# Example: headless uninstall using Project47 Suite (managed only)
param([string]`$Profile='Office')
`$here = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$suite = Join-Path `$here '..\Project47_Appcrawler_Suite.ps1'
powershell -ExecutionPolicy Bypass -File `$suite -NoUI -ApplyProfile `$Profile -Action uninstall -ReportPath (Join-Path `$here 'report.json')
"@
          Set-Content -LiteralPath (Join-Path $dir "uninstall_headless.ps1") -Value $uninstall -Encoding UTF8

          $manifest = @{
            name = "APPNAME"
            publisher = "PUBLISHER"
            version = "0.0.0"
            notes = "Fill in and attach the suite/headless scripts or direct installers."
          } | ConvertTo-Json -Depth 5
          Set-Content -LiteralPath (Join-Path $dir "app_manifest.json") -Value $manifest -Encoding UTF8

          $TxtIntuneOut.Text = $dir
          $TxtIntuneHelp.Text = $readme
          $script:LastIntunePackDir = $dir
          UI-Log "Intune/SCCM helper pack exported: $dir"
          Open-Explorer $dir | Out-Null
        } catch { UI-Log "Intune export failed: $($_.Exception.Message)" }
      }) | Out-Null
    }
    if($BtnOpenIntunePack){
      $BtnOpenIntunePack.Add_Click({
        try {
          if($script:LastIntunePackDir -and (Test-Path -LiteralPath $script:LastIntunePackDir)){
            Open-Explorer $script:LastIntunePackDir | Out-Null
          } else {
            [System.Windows.MessageBox]::Show("No Intune pack exported yet.", '47Project', 'OK', 'Information') | Out-Null
          }
        } catch {}
      }) | Out-Null
    }
$BtnClose.Add_Click({ $w.Close() }) | Out-Null
    $w.Owner = $window
    $w.ShowDialog() | Out-Null
  } catch {
    UI-Log "Enterprise Center failed: $($_.Exception.Message)"
    Show-Message ("Enterprise Center failed:`r`n" + $_.Exception.Message) '47Project' 'Warn'
  }
}



function Refresh-HistoryUI {
  if(-not $LstHistory){ return }
  try {
    $LstHistory.Items.Clear()
    if(-not (Test-Path -LiteralPath $ExportsDir)){ return }
    $files = Get-ChildItem -LiteralPath $ExportsDir -Filter 'run_report_*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    foreach($f in $files){
      [void]$LstHistory.Items.Add($f.FullName)
    }
    if($TxtHistoryInfo){
      $TxtHistoryInfo.Text = "Reports: $($files.Count) (stored in exports)."
    }
  } catch {}
}

function Refresh-CatalogSourcesUI {
  if(-not $LstCatalogSources){ return }
  try {
    $LstCatalogSources.Items.Clear()
    [void]$LstCatalogSources.Items.Add("embedded: base catalog (always on)")
    if(Test-Path -LiteralPath $CatalogDir){
      $fs = Get-ChildItem -LiteralPath $CatalogDir -Filter *.json -ErrorAction SilentlyContinue | Sort-Object Name
      foreach($f in $fs){
        [void]$LstCatalogSources.Items.Add("file: " + $f.FullName)
      }
      if($TxtCatalogInfo){
        $TxtCatalogInfo.Text = "catalog.d: $($fs.Count) file(s)."
      }
    } else {
      if($TxtCatalogInfo){ $TxtCatalogInfo.Text = "catalog.d folder not found." }
    }
  } catch {}
}

function Invoke-CatalogOnlineUpdate {
  # Downloads a remote catalog JSON to catalog.d and reloads it.
  # Note: if the host also exposes a .sha256 file, we will verify it (best-effort).
  try {
    # Optional certificate pinning for catalog host (Enterprise)
    $pinOldCb = $null
    $pinEnabled = $false
    $pinThumb = ''
    try { $pinEnabled = [bool]$script:Enterprise.certPinEnabled } catch {}
    try { $pinThumb = ([string]$script:Enterprise.certPinThumbprint).Replace(' ','').ToUpperInvariant() } catch {}
    if($pinEnabled -and $pinThumb){
      try {
        $pinOldCb = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { param($sender,$cert,$chain,$errors)
          try { return ($cert.GetCertHashString().ToUpperInvariant() -eq $pinThumb) } catch { return $false }
        }
        UI-Log "Enterprise cert pinning enabled for catalog update."
      } catch { UI-Log "Cert pinning init failed: $($_.Exception.Message)" }
    }

    if(-not (Test-Path -LiteralPath $CatalogDir)) { New-Item -ItemType Directory -Force -Path $CatalogDir | Out-Null }

    $baseUrl = 'https://47.bearguard.cloud/project47/47crawler'
    $url     = $baseUrl.TrimEnd('/') + '/catalog.json'
    $shaUrl  = $url + '.sha256'
    $sigUrl  = $url + '.sig'

    UI-Log "Catalog online update: fetching $url"
    if($TxtCatalogInfo){ $TxtCatalogInfo.Text = 'Fetching online catalog...' }

    $tmp = Join-Path $env:TEMP ('47catalog_' + [Guid]::NewGuid().ToString('N') + '.json')
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 20
    [IO.File]::WriteAllText($tmp, $resp.Content, [Text.Encoding]::UTF8)

    $localHash = Hash-FileSHA256 $tmp
    $remoteHash = $null
    try {
      $h = (Invoke-WebRequest -UseBasicParsing -Uri $shaUrl -TimeoutSec 10).Content
      if($h){ $remoteHash = ($h -split '\s+')[0].Trim() }
    } catch { }

    if($remoteHash -and $localHash -and ($remoteHash.ToLowerInvariant() -ne $localHash.ToLowerInvariant())) {
      UI-Log "Catalog online update: hash mismatch (remote=$remoteHash local=$localHash)"
      [System.Windows.MessageBox]::Show("Online catalog was downloaded but failed hash verification.

Remote: $remoteHash
Local:  $localHash

The file will NOT be applied.", '47Project', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      if($TxtCatalogInfo){ $TxtCatalogInfo.Text = 'Online catalog hash mismatch (not applied).' }
      return
    }



# Optional signature verification (.sig) using enterprise public key (RSA XML)
$sigB64 = $null
try { $sigB64 = (Invoke-WebRequest -UseBasicParsing -Uri $sigUrl -TimeoutSec 10).Content } catch {}
$requireSig = $false
try { $requireSig = [bool]$script:Enterprise.requireSignedCatalog } catch {}
$pub = ''
try { $pub = [string]$script:Enterprise.catalogPublicKeyXml } catch {}
if($sigB64 -or $requireSig){
  if([string]::IsNullOrWhiteSpace($pub)){
    if($requireSig){
      UI-Log 'Catalog signature required but no public key configured.'
      [System.Windows.MessageBox]::Show("Signed catalog is required, but no public key is configured in Enterprise Center -> Signing.", '47Project', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
      return
    }
  } else {
    $dataBytes = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($tmp,[Text.Encoding]::UTF8))
    $okSig = Verify-RsaSHA256Signature -Data $dataBytes -SignatureBase64 ([string]$sigB64) -PublicKeyXml $pub
    if(-not $okSig){
      UI-Log 'Catalog signature verification FAILED.'
      if($requireSig){
        [System.Windows.MessageBox]::Show("Catalog signature verification failed. The file will NOT be applied.", '47Project', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        return
      }
    } else {
      UI-Log 'Catalog signature verified.'
    }
  }
}
    $dest = Join-Path $CatalogDir 'remote_catalog.json'
    Copy-Item -LiteralPath $tmp -Destination $dest -Force
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

    UI-Log ("Catalog online update: saved to $dest" + (if($remoteHash){' (verified)'}else{' (no hash available)'}))
    if($TxtCatalogInfo){ $TxtCatalogInfo.Text = 'Online catalog saved: remote_catalog.json' + (if($remoteHash){' (verified)'}else{' (no hash provided)'}) }

    # Rebuild app list from new catalog
    $raw2 = Get-BaseCatalog
    if($null -ne $items){
      try { $items.Clear() } catch {}
      foreach($a in $raw2){
        try { $items.Add((New-AppItem $a)) | Out-Null } catch {}
      }
    }

    # Refresh categories
    try {
      $keep = [string]$CmbCategory.SelectedItem
      $CmbCategory.Items.Clear()
      $cats = @($items | Select-Object -ExpandProperty Category -Unique | Sort-Object)
      [void]$CmbCategory.Items.Add($L.CategoryAll)
      foreach($c in $cats){ [void]$CmbCategory.Items.Add($c) }
      if($keep -and ($CmbCategory.Items -contains $keep)){
        $CmbCategory.SelectedItem = $keep
      } else {
        $CmbCategory.SelectedIndex = 0
      }
    } catch {}

    try { Apply-Sort } catch {}
    try { Update-FilterAndStats } catch {}

    Refresh-CatalogSourcesUI

    # Re-scan installed status in background
    try { Start-Scan } catch {}

    [System.Windows.MessageBox]::Show("Online catalog updated.

File: $dest", '47Project', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
  } catch {
    UI-Log "Catalog online update failed: $($_.Exception.Message)"
    if($TxtCatalogInfo){ $TxtCatalogInfo.Text = "Online update failed: $($_.Exception.Message)" }
    [System.Windows.MessageBox]::Show("Online catalog update failed:
$($_.Exception.Message)", '47Project', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
  }
}


function Refresh-PolicyPreview {
  if(-not $TxtPolicyPreview){ return }
  try {
    $p = Get-PolicyObject
    $TxtPolicyPreview.Text = ($p | ConvertTo-Json -Depth 5)
  } catch {}
}

function Ensure-Winget {
  if(Get-Command winget -ErrorAction SilentlyContinue){ return $true }
  try {
    # App Installer is the canonical winget delivery on Windows; open Store page
    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" | Out-Null
  } catch {}
  return $false
}

function Ensure-Choco {
  if(Get-Command choco -ErrorAction SilentlyContinue){ return $true }
  try {
    Set-ExecutionPolicy Bypass -Scope Process -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    return (Get-Command choco -ErrorAction SilentlyContinue) -ne $null
  } catch { return $false }
}

function Try-CreateRestorePoint([string]$label){
  try {
    if(-not $ChkCreateRestorePoint -or -not $ChkCreateRestorePoint.IsChecked){ return }
    if(-not (Test-IsAdmin)){ UI-Log "Restore point skipped (admin required)."; return }
    Checkpoint-Computer -Description $label -RestorePointType "MODIFY_SETTINGS" | Out-Null
    UI-Log "Restore point created: $label"
  } catch { UI-Log "Restore point failed: $($_.Exception.Message)" }
}

function Hash-FileSHA256([string]$path){
  try {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs  = [System.IO.File]::OpenRead($path)
    try {
      $bytes = $sha.ComputeHash($fs)
      return -join ($bytes | ForEach-Object { $_.ToString('x2') })
    } finally { $fs.Dispose(); $sha.Dispose() }
  } catch { return $null }
}



# -------------------------
# Enterprise helpers (signing, bundles, sources, repo)
# -------------------------
function Verify-RsaSHA256Signature {
  param(
    [Parameter(Mandatory)] [byte[]]$Data,
    [Parameter(Mandatory)] [string]$SignatureBase64,
    [Parameter(Mandatory)] [string]$PublicKeyXml
  )
  try {
    if([string]::IsNullOrWhiteSpace($SignatureBase64)) { return $false }
    if([string]::IsNullOrWhiteSpace($PublicKeyXml)) { return $false }
    $sig = [Convert]::FromBase64String($SignatureBase64.Trim())
    $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
    $rsa.FromXmlString($PublicKeyXml)
    try {
      return $rsa.VerifyData($Data, 'SHA256', $sig)
    } finally {
      $rsa.Dispose()
    }
  } catch {
    return $false
  }
}

function Export-EnterpriseBundle {
  param([Parameter(Mandatory)][string]$Path)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  if(Test-Path -LiteralPath $Path){ Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
  $tmp = Join-Path $env:TEMP ('47bundle_' + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  foreach($f in @($SettingsPath)){
    if(Test-Path -LiteralPath $f){ Copy-Item -LiteralPath $f -Destination (Join-Path $tmp (Split-Path $f -Leaf)) -Force }
  }
  foreach($dir in @($ProfilesDir,$CatalogDir)){
    if(Test-Path -LiteralPath $dir){ Copy-Item -LiteralPath $dir -Destination (Join-Path $tmp (Split-Path $dir -Leaf)) -Recurse -Force }
  }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp,$Path)
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  return $Path
}

function Import-EnterpriseBundle {
  param([Parameter(Mandatory)][string]$Path)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $tmp = Join-Path $env:TEMP ('47bundle_in_' + [Guid]::NewGuid().ToString('N'))
  if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  [System.IO.Compression.ZipFile]::ExtractToDirectory($Path,$tmp)

  $s = Join-Path $tmp (Split-Path $SettingsPath -Leaf)
  if(Test-Path -LiteralPath $s){ Copy-Item -LiteralPath $s -Destination $SettingsPath -Force }

  $p = Join-Path $tmp (Split-Path $ProfilesDir -Leaf)
  if(Test-Path -LiteralPath $p){ Copy-Item -LiteralPath (Join-Path $p '*') -Destination $ProfilesDir -Recurse -Force -ErrorAction SilentlyContinue }

  $c = Join-Path $tmp (Split-Path $CatalogDir -Leaf)
  if(Test-Path -LiteralPath $c){ Copy-Item -LiteralPath (Join-Path $c '*') -Destination $CatalogDir -Recurse -Force -ErrorAction SilentlyContinue }

  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

function Export-EnterprisePolicyFile {
  param([Parameter(Mandatory)][string]$Path)
  $obj = [pscustomobject]@{ schema = 1; enterprise = $script:Enterprise }
  $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
  return $Path
}

function Apply-EnterprisePolicyFile {
  param([Parameter(Mandatory)][string]$Path)
  $p = Read-JsonFile $Path
  if($p -and $p.enterprise){
    foreach($k in $p.enterprise.PSObject.Properties.Name){
      try { $script:Enterprise[$k] = $p.enterprise.$k } catch { }
    }
    Save-Settings
  }
}

function Build-OfflineRepoFromDownloads {
  param([Parameter(Mandatory)][string]$RepoRoot)
  # Creates: RepoRoot\index.json + RepoRoot\packages\<filename>
  if(-not (Test-Path -LiteralPath $RepoRoot)){ New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null }
  $pkgRoot = Join-Path $RepoRoot 'packages'
  if(-not (Test-Path -LiteralPath $pkgRoot)){ New-Item -ItemType Directory -Path $pkgRoot -Force | Out-Null }

  $index = New-Object System.Collections.Generic.List[object]
  if(Test-Path -LiteralPath $MetaDir){
    $metas = Get-ChildItem -LiteralPath $MetaDir -Filter '*.json' -ErrorAction SilentlyContinue
    foreach($m in $metas){
      try {
        $j = Read-JsonFile $m.FullName
        if(-not $j -or -not $j.file){ continue }
        $file = [string]$j.file
        if(-not (Test-Path -LiteralPath $file)){ continue }
        $leaf = Split-Path $file -Leaf
        $dest = Join-Path $pkgRoot $leaf
        Copy-Item -LiteralPath $file -Destination $dest -Force
        $h = Hash-FileSHA256 $dest
        $index.Add([pscustomobject]@{
          file = $leaf
          sha256 = $h
          size = (Get-Item -LiteralPath $dest).Length
          source = $file
          timestamp = (Get-Date).ToString('o')
        }) | Out-Null
      } catch { }
    }
  }
  ($index | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath (Join-Path $RepoRoot 'index.json') -Encoding UTF8
  return (Join-Path $RepoRoot 'index.json')
}

function Get-WingetSourcesText {
  try {
    if(Get-Command winget -ErrorAction SilentlyContinue){
      return (winget source list 2>&1 | Out-String)
    }
    return 'winget not found.'
  } catch { return $_.Exception.Message }
}

function Reset-WingetSourcesText {
  try {
    if(Get-Command winget -ErrorAction SilentlyContinue){
      return (winget source reset --force 2>&1 | Out-String)
    }
    return 'winget not found.'
  } catch { return $_.Exception.Message }
}

function Get-ChocoSourcesText {
  try {
    if(Get-Command choco -ErrorAction SilentlyContinue){
      return (choco source list 2>&1 | Out-String)
    }
    return 'choco not found.'
  } catch { return $_.Exception.Message }
}

function Write-RunPlan {
  param([Parameter(Mandatory)][object[]]$Queue,[Parameter(Mandatory)][string]$Path)
  $plan = [pscustomobject]@{
    schema = 1
    created = (Get-Date).ToString('o')
    machine = $env:COMPUTERNAME
    user = $env:USERNAME
    queue = $Queue
  }
  ($plan | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $Path -Encoding UTF8
  return $Path
}

# -----------
# Chocolatey bootstrap (prompt + admin)
# -----------
function Ensure-Choco([ScriptBlock]$Log, [ScriptBlock]$Ui){
  if(Get-Command choco -ErrorAction SilentlyContinue){ return $true }

  $msg = "Chocolatey (choco) is not installed. Some selected actions require it.`n`nInstall Chocolatey now? (Admin required)"
  $res = [System.Windows.MessageBox]::Show($msg,'47Project',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
  if($res -ne [System.Windows.MessageBoxResult]::Yes){ return $false }

  if(-not (Test-IsAdmin)){
    [System.Windows.MessageBox]::Show("Please run the suite as Administrator to install Chocolatey.",'47Project',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) | Out-Null
    return $false
  }

  try {
    $Log.Invoke("Installing Chocolatey...")
    # Official install: https://chocolatey.org/install
    $cmd = "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command $cmd | Out-Null
    Start-Sleep -Seconds 2
    if(Get-Command choco -ErrorAction SilentlyContinue){
      $Log.Invoke("Chocolatey installed.")
      return $true
    }
    $Log.Invoke("Chocolatey install attempted but choco not detected.")
    return $false
  } catch {
    $Log.Invoke("Chocolatey install failed: $($_.Exception.Message)")
    return $false
  }
}

# -----------------------
# Data model (PS objects)
# -----------------------
# NOTE: We intentionally avoid Add-Type/C# model classes here.
# Broken %TEMP%/%TMP% environments and session type-caching can cause startup failures.
# Using plain PowerShell objects keeps the suite resilient.
function Get-AppField($obj, [string[]]$names){
  if($null -eq $obj){ return $null }

  foreach($n in $names){
    if([string]::IsNullOrWhiteSpace($n)){ continue }

    # IDictionary / hashtable support
    if($obj -is [System.Collections.IDictionary]){
      if($obj.Contains($n)){ return $obj[$n] }
      # try case-insensitive scan (covers some dictionary types)
      foreach($k in $obj.Keys){
        if([string]$k -ieq $n){ return $obj[$k] }
      }
      continue
    }

    # PSObject property support (pscustomobject, etc.)
    $p = $obj.PSObject.Properties[$n]
    if($p){ return $p.Value }

    # case-insensitive property fallback
    foreach($pp in $obj.PSObject.Properties){
      if($pp.Name -ieq $n){ return $pp.Value }
    }
  }
  return $null
}


function Infer-ProfilesForApp {
  param($Name,$Category,$Method,$Notes)
  $name = [string]$Name
  $cat  = [string]$Category
  $meth = ([string]$Method).ToLowerInvariant()
  $n    = [string]$Notes
  $t = ($name + ' ' + $cat + ' ' + $meth + ' ' + $n).ToLowerInvariant()

  $p = New-Object System.Collections.Generic.List[string]

  if($meth -eq 'portable'){ $p.Add('Portable') | Out-Null }

  if($t -match 'browser|chrome|firefox|edge|brave'){ $p.Add('Minimal') | Out-Null; $p.Add('Office') | Out-Null }
  if($t -match 'office|word|excel|powerpoint|libreoffice|thunderbird|pdf|sumatrapdf|acrobat'){ $p.Add('Office') | Out-Null }
  if($t -match 'dev|development|sdk|git|python|node|java|jdk|dotnet|visual studio|vscode|docker|postman|terminal'){ $p.Add('Dev') | Out-Null }
  if($t -match 'game|gaming|steam|epic|battle\.net|gog|ubisoft|ea app|xbox|playnite|afterburner|ryzen|nvidia|logitech'){ $p.Add('Gaming') | Out-Null }
  if($t -match 'media|vlc|spotify|obs|handbrake|audacity|stream|sunshine'){ $p.Add('Creator') | Out-Null }
  if($t -match 'graphics|gimp|inkscape|blender|photoshop|davinci|krita'){ $p.Add('Creator') | Out-Null }
  if($t -match 'network|vpn|wireguard|tailscale|wireshark|winscp|putty|ssh|filezilla|remotedesktop|anydesk'){ $p.Add('Sysadmin') | Out-Null }
  if($t -match 'iso|usb|rufus|ventoy|etcher|wincdemu'){ $p.Add('Sysadmin') | Out-Null }
  if($t -match 'virtual|vmware|virtualbox|qemu|virtio'){ $p.Add('Sysadmin') | Out-Null }
  if($t -match 'security|password|bitwarden|keepass|malware|defender'){ $p.Add('Minimal') | Out-Null; $p.Add('Office') | Out-Null; $p.Add('Dev') | Out-Null }

  # Always keep at least one bucket for discoverability
  if($p.Count -eq 0){ $p.Add('Minimal') | Out-Null }

  # unique
  return @($p | Select-Object -Unique)
}


function New-AppItem($a){
  # Accept catalog entries as hashtables OR pscustomobjects.
  $method = [string](Get-AppField $a @('Method','method'))
  $isPortable = ($method -and $method.Trim().ToLowerInvariant() -eq 'portable')

  $wing = [string](Get-AppField $a @('WingetId','WinGetId','Winget','WingetID','Id','ID'))
  $choc = [string](Get-AppField $a @('ChocoId','ChocolateyId','Choco','ChocoID'))
  $updateable = (-not [string]::IsNullOrWhiteSpace($wing)) -or (-not [string]::IsNullOrWhiteSpace($choc))

  $obj = [pscustomobject]@{
    Name          = [string](Get-AppField $a @('Name'))
    Category      = [string](Get-AppField $a @('Category','Cat'))
    Notes         = [string](Get-AppField $a @('Notes','Note','Description'))
    Default       = [bool](Get-AppField $a @('Default','IsDefault'))
    Method        = $method
    WingetId      = $wing
    ChocoId       = $choc
    Url           = [string](Get-AppField $a @('Url','URL','DownloadUrl','Link'))
    UrlFallbacks = @()
    File          = [string](Get-AppField $a @('File','Filename'))
    InstallerType = [string](Get-AppField $a @('InstallerType','Type'))
    SilentArgs    = [string](Get-AppField $a @('SilentArgs','InstallArgs','Args'))
    NeedsAdmin    = [bool](Get-AppField $a @('NeedsAdmin','Admin','RequiresAdmin'))
    Profiles      = @()
    IsInstalled   = $false
    IncludeInstalledFlag = $false
    IsSelected    = [bool](Get-AppField $a @('Default','IsDefault'))
    IsFavorite    = $false
    IsPortable    = $isPortable
    IsUpdateable  = $updateable
    IsSelectable  = $true
    PreferredMethod = "Auto"
    PinnedVersion   = ""    
    
    UserNote        = ""
    Skip            = $false
    ExcludeUpdate   = $false
    Dependencies    = @()
    RecommendedMethod = "Auto"
    InstalledVersion  = ""
    AvailableVersion  = ""
    DetectReason     = ''
    BlockReason      = ''
    StatusTip        = ''
    UpdateAvailable  = $false
  }

  # Profiles tags from catalog (optional)
  $prof = Get-AppField $a @('Profiles','ProfileTags','Tags')
  if($prof){
    if($prof -is [string]){ $obj.Profiles = @($prof) }
    elseif($prof -is [System.Collections.IEnumerable]){ $obj.Profiles = @($prof) }
  }

  # URL fallbacks (optional) for direct downloads
  $fb = Get-AppField $a @('UrlFallbacks','FallbackUrls','Fallbacks','Mirrors')
  if($fb){
    if($fb -is [string]){
      $obj.UrlFallbacks = @(([string]$fb) -split '[;,]\s*' | Where-Object { $_ })
    } elseif($fb -is [System.Collections.IEnumerable]){
      $obj.UrlFallbacks = @($fb | ForEach-Object { [string]$_ } | Where-Object { $_ })
    }
  }


  # If no profiles were provided by the catalog, infer them from category/name/method.
# Dependencies from catalog (optional): array of names/ids
  $deps = Get-AppField $a @('Dependencies','DependsOn','Depends','Requires')
  if($deps){
    if($deps -is [string]){ $obj.Dependencies = @($deps) }
    elseif($deps -is [System.Collections.IEnumerable]){ $obj.Dependencies = @($deps) }
  }

  # Recommended method (simple reliability scoring)
  if($obj.WingetId){ $obj.RecommendedMethod = 'winget' }
  elseif($obj.ChocoId){ $obj.RecommendedMethod = 'choco' }
  elseif($obj.IsPortable -or ($obj.Method -eq 'portable')){ $obj.RecommendedMethod = 'portable' }
  elseif($obj.Method){ $obj.RecommendedMethod = $obj.Method } else { $obj.RecommendedMethod = 'download' }

  if(-not $obj.Profiles -or $obj.Profiles.Count -eq 0){
    $obj.Profiles = Infer-ProfilesForApp -Name $obj.Name -Category $obj.Category -Method $obj.Method -Notes $obj.Notes
  }

  return $obj
}


# -----------------------
# Catalog (base + extras)
# -----------------------
function Get-BaseCatalog {
  # Base catalog is embedded (JSON, ASCII-safe) so the suite works offline and without extra files.
  $BaseCatalogJson = @'
[{"Name": "Bitwarden", "Category": "Password & Security", "Default": true, "Method": "download", "WingetId": "Bitwarden.Bitwarden", "ChocoId": "", "Url":
"https://bitwarden.com/download/?app=desktop&platform=windows&variant=exe", "File": "Bitwarden.exe", "Notes": ""}, {"Name": "Brave", "Category": "Browsers",
"Default": true, "Method": "download", "WingetId": "Brave.Brave", "ChocoId": "", "Url": "https://laptop-updates.brave.com/latest/winx64", "File":
"BraveBrowserSetup.exe", "Notes": ""}, {"Name": "Google Chrome", "Category": "Browsers", "Default": false, "Method": "download", "WingetId": "Google.Chrome",
"ChocoId": "", "Url": "https://dl.google.com/chrome/install/latest/chrome_installer.exe", "File": "ChromeSetup.exe", "Notes": ""}, {"Name": "Mozilla Firefox",
"Category": "Browsers", "Default": false, "Method": "download", "WingetId": "Mozilla.Firefox", "ChocoId": "", "Url":
"https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US", "File": "FirefoxSetup.exe", "Notes": ""}, {"Name": "Firefox Developer Edition",
"Category": "Browsers", "Default": true, "Method": "download", "WingetId": "Mozilla.Firefox.DeveloperEdition", "ChocoId": "", "Url":
"https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=win64&lang=en-US", "File": "FirefoxDevSetup.exe", "Notes": ""}, {"Name": "AnyDesk",
"Category": "Remote", "Default": false, "Method": "download", "WingetId": "AnyDeskSoftwareGmbH.AnyDesk", "ChocoId": "", "Url":
"https://anydesk.com/en/downloads/thank-you?dv=win_exe", "File": "AnyDesk.exe", "Notes": ""}, {"Name": "Notepad++", "Category": "Notes", "Default": false,
"Method": "download", "WingetId": "Notepad++.Notepad++", "ChocoId": "", "Url": "https://github.com/notepad-plus-plus/notepad-plus-
plus/releases/latest/download/npp.8.8.9.Installer.x64.exe", "File": "NotepadPlusPlus.exe", "Notes": ""}, {"Name": "Python Manager (MSIX)", "Category":
"Development", "Default": false, "Method": "download", "WingetId": "Python.PythonManager", "ChocoId": "", "Url":
"https://www.python.org/ftp/python/pymanager/python-manager-25.2.msix", "File": "python-manager.msix", "Notes": ""}, {"Name": "Python Standalone", "Category":
"Development", "Default": false, "Method": "download", "WingetId": "Python.Python.3.14", "ChocoId": "", "Url":
"https://www.python.org/ftp/python/3.14.2/python-3.14.2-amd64.exe", "File": "python-amd64.exe", "Notes": ""}, {"Name": "VirtIO Guest Agent", "Category":
"Virtualization", "Default": true, "Method": "download", "WingetId": "", "ChocoId": "", "Url": "file:C:\\47\\Installers\\Virtualizing\\qemu-ga-x86_64.msi",
"File": "qemu-ga-x86_64.msi", "Notes": ""}, {"Name": "VirtIO Guest Tools", "Category": "Virtualization", "Default": true, "Method": "download", "WingetId": "",
"ChocoId": "", "Url": "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-gt-x64.msi", "File":
"virtio-win-gt-x64.msi", "Notes": ""}, {"Name": "WinSCP", "Category": "Development", "Default": false, "Method": "download", "WingetId": "WinSCP.WinSCP",
"ChocoId": "", "Url": "https://winscp.net/download/WinSCP-Setup.exe", "File": "WinSCP-Setup.exe", "Notes": ""}, {"Name": "Battle.net", "Category": "Game
Launchers", "Default": true, "Method": "download", "WingetId": "Blizzard.BattleNet", "ChocoId": "", "Url":
"https://downloader.battle.net//download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live", "File": "Battle.net-Setup.exe", "Notes": ""},
{"Name": "Epic Games Launcher", "Category": "Game Launchers", "Default": true, "Method": "download", "WingetId": "EpicGames.EpicGamesLauncher", "ChocoId": "",
"Url": "https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi", "File":
"EpicGamesLauncherInstaller.msi", "Notes": ""}, {"Name": "Steam", "Category": "Game Launchers", "Default": true, "Method": "download", "WingetId":
"Valve.Steam", "ChocoId": "", "Url": "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe", "File": "SteamSetup.exe", "Notes": ""}, {"Name":
"Xbox Installer", "Category": "Game Launchers", "Default": false, "Method": "download", "WingetId": "Microsoft.XboxApp", "ChocoId": "", "Url":
"https://aka.ms/xboxinstaller", "File": "XboxInstaller.exe", "Notes": ""}, {"Name": "AMD Ryzen Master (Auto)", "Category": "Hardware", "Default": false,
"Method": "download", "WingetId": "", "ChocoId": "", "Url": "https://download.amd.com/Desktop/amd_ryzen_master.exe", "File": "amd_ryzen_master.exe", "Notes":
"CARE"}, {"Name": "Logitech G HUB", "Category": "Gaming", "Default": false, "Method": "download", "WingetId": "Logitech.GHUB", "ChocoId": "", "Url":
"https://download01.logi.com/web/ftp/pub/techsupport/gaming/lghub_installer.exe", "File": "lghub_installer.exe", "Notes": ""}, {"Name": "NVIDIA App",
"Category": "Hardware", "Default": false, "Method": "download", "WingetId": "NVIDIA.NVIDIAApp", "ChocoId": "", "Url":
"https://uk.download.nvidia.com/nvapp/client/11.0.5.420/NVIDIA_app_v11.0.5.420.exe", "File": "NVIDIA_App.exe", "Notes": "CARE"}, {"Name": "Samsung Magician",
"Category": "Storage", "Default": false, "Method": "download", "WingetId": "Samsung.Magician", "ChocoId": "", "Url":
"https://download.semiconductor.samsung.com/resources/software-resources/Samsung_Magician_Installer_Official_9.0.0.910.exe", "File": "Samsung_Magician.exe",
"Notes": ""}, {"Name": "Microsoft 365 / Office (C2R)", "Category": "Office", "Default": true, "Method": "download", "WingetId": "Microsoft.Office", "ChocoId":
"", "Url": "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA", "File":
"OfficeSetup.exe", "Notes": "CARE"}, {"Name": "Sunshine", "Category": "Streaming", "Default": false, "Method": "download", "WingetId": "LizardByte.Sunshine",
"ChocoId": "", "Url": "https://github.com/LizardByte/Sunshine/releases/latest/download/Sunshine-Windows-AMD64-installer.exe", "File": "Sunshine.exe", "Notes":
""}, {"Name": "CrystalDiskMark", "Category": "Storage", "Default": false, "Method": "download", "WingetId": "CrystalDewWorld.CrystalDiskMark", "ChocoId": "",
"Url": "https://sourceforge.net/projects/crystaldiskmark/files/latest/download", "File": "CrystalDiskMark.exe", "Notes": ""}, {"Name": "Rufus", "Category": "ISO
& USB", "Default": false, "Method": "download", "WingetId": "Rufus.Rufus", "ChocoId": "", "Url":
"https://github.com/pbatard/rufus/releases/latest/download/rufus.exe", "File": "rufus.exe", "Notes": ""}, {"Name": "NVCleanstall", "Category": "Drivers",
"Default": false, "Method": "winget", "WingetId": "TechPowerUp.NVCleanstall", "ChocoId": "", "Url": "https://www.techpowerup.com/download/techpowerup-
nvcleanstall/", "File": "NVCleanstall.exe", "Notes": "ADV"}, {"Name": "LocalSend", "Category": "File Sharing", "Default": true, "Method": "download",
"WingetId": "LocalSend.LocalSend", "ChocoId": "", "Url": "https://github.com/localsend/localsend/releases/latest/download/LocalSend-windows-x86-64.exe", "File":
"LocalSend.exe", "Notes": ""}, {"Name": "Obsidian", "Category": "Notes", "Default": true, "Method": "download", "WingetId": "Obsidian.Obsidian", "ChocoId": "",
"Url": "https://github.com/obsidianmd/obsidian-releases/releases/latest/download/Obsidian.exe", "File": "Obsidian.exe", "Notes": ""}, {"Name": "7-Zip (x64)",
"Category": "Utilities", "Default": true, "Method": "download", "WingetId": "7zip.7zip", "ChocoId": "", "Url": "https://www.7-zip.org/a/7z2501-x64.exe", "File":
"7zip-x64.exe", "Notes": ""}, {"Name": "Microsoft Edge", "Category": "Browsers", "Default": false, "Method": "winget", "WingetId": "Microsoft.Edge", "ChocoId":
"", "Url": "", "File": "", "Notes": ""}, {"Name": "Edge Beta", "Category": "Browsers", "Default": false, "Method": "winget", "WingetId": "Microsoft.Edge.Beta",
"ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Edge Dev", "Category": "Browsers", "Default": false, "Method": "winget", "WingetId":
"Microsoft.Edge.Dev", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Vivaldi", "Category": "Browsers", "Default": false, "Method": "winget",
"WingetId": "Vivaldi.Vivaldi", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Opera", "Category": "Browsers", "Default": false, "Method":
"winget", "WingetId": "Opera.Opera", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Opera GX", "Category": "Browsers", "Default": false,
"Method": "winget", "WingetId": "Opera.OperaGX", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Tor Browser", "Category": "Browsers", "Default":
false, "Method": "winget", "WingetId": "TorProject.TorBrowser", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Telegram Desktop", "Category":
"Communication", "Default": false, "Method": "winget", "WingetId": "Telegram.TelegramDesktop", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name":
"Signal", "Category": "Communication", "Default": false, "Method": "winget", "WingetId": "OpenWhisperSystems.Signal", "ChocoId": "", "Url": "", "File": "",
"Notes": ""}, {"Name": "WhatsApp", "Category": "Communication", "Default": false, "Method": "winget", "WingetId": "WhatsApp.WhatsApp", "ChocoId": "", "Url": "",
"File": "", "Notes": ""}, {"Name": "Zoom", "Category": "Communication", "Default": false, "Method": "winget", "WingetId": "Zoom.Zoom", "ChocoId": "", "Url": "",
"File": "", "Notes": ""}, {"Name": "Slack", "Category": "Communication", "Default": false, "Method": "winget", "WingetId": "SlackTechnologies.Slack", "ChocoId":
"", "Url": "", "File": "", "Notes": ""}, {"Name": "Microsoft Teams", "Category": "Communication", "Default": false, "Method": "winget", "WingetId":
"Microsoft.Teams", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Discord", "Category": "Communication", "Default": false, "Method":
"winget", "WingetId": "Discord.Discord", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Thunderbird", "Category": "Communication", "Default":
false, "Method": "winget", "WingetId": "Mozilla.Thunderbird", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Everything (Voidtools)", "Category":
"Utilities", "Default": false, "Method": "winget", "WingetId": "voidtools.Everything", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "PowerToys",
"Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Microsoft.PowerToys", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name":
"ShareX", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "ShareX.ShareX", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "WizTree", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "AntibodySoftware.WizTree", "ChocoId": "", "Url": "", "File": "",
"Notes": ""}, {"Name": "SumatraPDF", "Category": "PDF", "Default": false, "Method": "winget", "WingetId": "SumatraPDF.SumatraPDF", "ChocoId": "", "Url": "",
"File": "", "Notes": ""}, {"Name": "WinMerge", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "WinMerge.WinMerge", "ChocoId": "",
"Url": "", "File": "", "Notes": ""}, {"Name": "OBS Studio", "Category": "Media", "Default": false, "Method": "winget", "WingetId": "OBSProject.OBSStudio",
"ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Spotify", "Category": "Media", "Default": false, "Method": "winget", "WingetId":
"Spotify.Spotify", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "VLC Media Player", "Category": "Media", "Default": false, "Method": "winget",
"WingetId": "VideoLAN.VLC", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Git", "Category": "Development", "Default": false, "Method": "winget",
"WingetId": "Git.Git", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "GitHub Desktop", "Category": "Development", "Default": false, "Method":
"winget", "WingetId": "GitHub.GitHubDesktop", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Visual Studio Code", "Category": "Development",
"Default": false, "Method": "winget", "WingetId": "Microsoft.VisualStudioCode", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "PowerShell 7",
"Category": "Development", "Default": false, "Method": "winget", "WingetId": "Microsoft.PowerShell", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "Windows Terminal", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Microsoft.WindowsTerminal", "ChocoId": "", "Url": "",
"File": "", "Notes": ""}, {"Name": "Node.js LTS", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "OpenJS.NodeJS.LTS", "ChocoId":
"", "Url": "", "File": "", "Notes": ""}, {"Name": "Temurin JDK (OpenJDK)", "Category": "Development", "Default": false, "Method": "winget", "WingetId":
"EclipseAdoptium.Temurin.21.JDK", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": ".NET SDK", "Category": "Development", "Default": false,
"Method": "winget", "WingetId": "Microsoft.DotNet.SDK.8", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Docker Desktop", "Category":
"Development", "Default": false, "Method": "winget", "WingetId": "Docker.DockerDesktop", "ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name":
"Postman", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Postman.Postman", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "PuTTY", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "PuTTY.PuTTY", "ChocoId": "", "Url": "", "File": "", "Notes":
""}, {"Name": "FileZilla Client", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "FileZilla.FileZilla.Client", "ChocoId": "",
"Url": "", "File": "", "Notes": ""}, {"Name": "GOG Galaxy", "Category": "Game Launchers", "Default": false, "Method": "winget", "WingetId": "GOG.Galaxy",
"ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Ubisoft Connect", "Category": "Game Launchers", "Default": false, "Method": "winget", "WingetId":
"Ubisoft.Connect", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "EA App", "Category": "Game Launchers", "Default": false, "Method": "winget",
"WingetId": "ElectronicArts.EADesktop", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Playnite", "Category": "Game Launchers", "Default": false,
"Method": "winget", "WingetId": "Playnite.Playnite", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "HWiNFO", "Category": "Hardware", "Default":
false, "Method": "winget", "WingetId": "REALiX.HWiNFO", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "CPU-Z", "Category": "Hardware", "Default":
false, "Method": "winget", "WingetId": "CPUID.CPU-Z", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "GPU-Z", "Category": "Hardware", "Default":
false, "Method": "winget", "WingetId": "TechPowerUp.GPU-Z", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "MSI Afterburner", "Category":
"Gaming", "Default": false, "Method": "winget", "WingetId": "MSI.Afterburner", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "FanControl",
"Category": "Hardware", "Default": false, "Method": "winget", "WingetId": "Rem0o.FanControl", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name":
"DDU (Display Driver Uninstaller)", "Category": "Drivers", "Default": false, "Method": "winget", "WingetId": "Wagnardsoft.DDU", "ChocoId": "", "Url": "",
"File": "", "Notes": "ADV"}, {"Name": "VirtualBox", "Category": "Virtualization", "Default": false, "Method": "winget", "WingetId": "Oracle.VirtualBox",
"ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "VMware Workstation Player", "Category": "Virtualization", "Default": false, "Method": "winget",
"WingetId": "VMware.WorkstationPlayer", "ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "Ventoy", "Category": "ISO & USB", "Default": false,
"Method": "winget", "WingetId": "Ventoy.Ventoy", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "balenaEtcher", "Category": "ISO & USB",
"Default": false, "Method": "winget", "WingetId": "Balena.Etcher", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "WinCDEmu", "Category": "ISO &
USB", "Default": false, "Method": "winget", "WingetId": "Sysprogs.WinCDEmu", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Autoruns",
"Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Microsoft.Sysinternals.Autoruns", "ChocoId": "", "Url": "", "File": "", "Notes":
"ADV"}, {"Name": "Process Explorer", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Microsoft.Sysinternals.ProcessExplorer",
"ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "Process Monitor", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId":
"Microsoft.Sysinternals.ProcessMonitor", "ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "Sysinternals Suite", "Category": "Utilities",
"Default": false, "Method": "winget", "WingetId": "Microsoft.Sysinternals.Suite", "ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "Revo
Uninstaller", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "RevoUninstaller.RevoUninstaller", "ChocoId": "", "Url": "", "File":
"", "Notes": "CARE"}, {"Name": "TreeSize Free", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "JAMSoftware.TreeSize.Free",
"ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "HandBrake", "Category": "Media", "Default": false, "Method": "winget", "WingetId":
"HandBrake.HandBrake", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Audacity", "Category": "Media", "Default": false, "Method": "winget",
"WingetId": "Audacity.Audacity", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "K-Lite Codec Pack (Standard)", "Category": "Media", "Default":
false, "Method": "winget", "WingetId": "CodecGuide.K-LiteCodecPack.Standard", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Kodi",
"Category": "Media", "Default": false, "Method": "winget", "WingetId": "XBMCFoundation.Kodi", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name":
"GIMP", "Category": "Graphics", "Default": false, "Method": "winget", "WingetId": "GIMP.GIMP.3", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name":
"Inkscape", "Category": "Graphics", "Default": false, "Method": "winget", "WingetId": "Inkscape.Inkscape", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "Krita", "Category": "Graphics", "Default": false, "Method": "winget", "WingetId": "KDE.Krita", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "Blender", "Category": "Graphics", "Default": false, "Method": "winget", "WingetId": "BlenderFoundation.Blender", "ChocoId": "", "Url": "", "File": "",
"Notes": ""}, {"Name": "Paint.NET", "Category": "Graphics", "Default": false, "Method": "winget", "WingetId": "dotPDNLLC.paintdotnet", "ChocoId": "", "Url": "",
"File": "", "Notes": ""}, {"Name": "KeePassXC", "Category": "Password & Security", "Default": false, "Method": "winget", "WingetId": "KeePassXCTeam.KeePassXC",
"ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "VeraCrypt", "Category": "Password & Security", "Default": false, "Method": "winget", "WingetId":
"IDRIX.VeraCrypt", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "WireGuard", "Category": "Network", "Default": false, "Method": "winget",
"WingetId": "WireGuard.WireGuard", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Tailscale", "Category": "Network", "Default": false,
"Method": "winget", "WingetId": "Tailscale.Tailscale", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Wireshark", "Category": "Network",
"Default": false, "Method": "winget", "WingetId": "WiresharkFoundation.Wireshark", "ChocoId": "", "Url": "", "File": "", "Notes": "ADV"}, {"Name": "JetBrains
Toolbox", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "JetBrains.Toolbox", "ChocoId": "", "Url": "", "File": "", "Notes": ""},
{"Name": "Android Studio", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Google.AndroidStudio", "ChocoId": "", "Url": "",
"File": "", "Notes": "ADV"}, {"Name": "DBeaver Community", "Category": "Development", "Default": false, "Method": "winget", "WingetId":
"DBeaver.DBeaver.Community", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "HeidiSQL", "Category": "Development", "Default": false, "Method":
"winget", "WingetId": "HeidiSQL.HeidiSQL", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "DB Browser for SQLite", "Category": "Development",
"Default": false, "Method": "winget", "WingetId": "DBBrowserForSQLite.DBBrowserForSQLite", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Visual
Studio 2022 Community", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Microsoft.VisualStudio.2022.Community", "ChocoId": "",
"Url": "", "File": "", "Notes": "ADV"}, {"Name": "LibreOffice", "Category": "Office", "Default": false, "Method": "winget", "WingetId":
"TheDocumentFoundation.LibreOffice", "ChocoId": "", "Url": "", "File": "", "Notes": ""}, {"Name": "Syncthing", "Category": "Backup & Sync", "Default": false,
"Method": "winget", "WingetId": "Syncthing.Syncthing", "ChocoId": "", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "7-Zip", "Category": "Utilities",
"Default": false, "Method": "winget", "WingetId": "7zip.7zip", "ChocoId": "7zip", "Url": "", "File": "", "Notes": ""}, {"Name": "NanaZip", "Category":
"Utilities", "Default": false, "Method": "winget", "WingetId": "M2Team.NanaZip", "ChocoId": "nanazip", "Url": "", "File": "", "Notes": ""}, {"Name": "PeaZip",
"Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Giorgiotani.Peazip", "ChocoId": "peazip", "Url": "", "File": "", "Notes": ""},
{"Name": "Rufus", "Category": "ISO & USB", "Default": false, "Method": "winget", "WingetId": "Rufus.Rufus", "ChocoId": "rufus", "Url": "", "File": "", "Notes":
"CARE"}, {"Name": "Greenshot", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Greenshot.Greenshot", "ChocoId": "greenshot", "Url":
"", "File": "", "Notes": ""}, {"Name": "Ditto Clipboard", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId": "Ditto.Ditto", "ChocoId":
"ditto", "Url": "", "File": "", "Notes": ""}, {"Name": "AutoHotkey", "Category": "Utilities", "Default": false, "Method": "winget", "WingetId":
"AutoHotkey.AutoHotkey", "ChocoId": "autohotkey", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "CrystalDiskInfo", "Category": "Hardware", "Default": false,
"Method": "winget", "WingetId": "CrystalDewWorld.CrystalDiskInfo", "ChocoId": "crystaldiskinfo", "Url": "", "File": "", "Notes": ""}, {"Name":
"CrystalDiskMark", "Category": "Hardware", "Default": false, "Method": "winget", "WingetId": "CrystalDewWorld.CrystalDiskMark", "ChocoId": "crystaldiskmark",
"Url": "", "File": "", "Notes": ""}, {"Name": "HWMonitor", "Category": "Hardware", "Default": false, "Method": "winget", "WingetId": "CPUID.HWMonitor",
"ChocoId": "hwmonitor", "Url": "", "File": "", "Notes": ""}, {"Name": "RustDesk", "Category": "Remote", "Default": false, "Method": "winget", "WingetId":
"RustDesk.RustDesk", "ChocoId": "rustdesk", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "TeamViewer", "Category": "Remote", "Default": false, "Method":
"winget", "WingetId": "TeamViewer.TeamViewer", "ChocoId": "teamviewer", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Obsidian", "Category": "Notes",
"Default": false, "Method": "winget", "WingetId": "Obsidian.Obsidian", "ChocoId": "obsidian", "Url": "", "File": "", "Notes": ""}, {"Name": "Notion",
"Category": "Notes", "Default": false, "Method": "winget", "WingetId": "Notion.Notion", "ChocoId": "notion", "Url": "", "File": "", "Notes": ""}, {"Name":
"Joplin", "Category": "Notes", "Default": false, "Method": "winget", "WingetId": "Joplin.Joplin", "ChocoId": "joplin", "Url": "", "File": "", "Notes": ""},
{"Name": "ONLYOFFICE Desktop Editors", "Category": "Office", "Default": false, "Method": "winget", "WingetId": "ONLYOFFICE.DesktopEditors", "ChocoId":
"onlyoffice", "Url": "", "File": "", "Notes": ""}, {"Name": "Adobe Acrobat Reader", "Category": "PDF", "Default": false, "Method": "winget", "WingetId":
"Adobe.Acrobat.Reader.64-bit", "ChocoId": "adobereader", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "qBittorrent", "Category": "Media", "Default": false,
"Method": "winget", "WingetId": "qBittorrent.qBittorrent", "ChocoId": "qbittorrent", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "foobar2000", "Category":
"Media", "Default": false, "Method": "winget", "WingetId": "PeterPawlowski.foobar2000", "ChocoId": "foobar2000", "Url": "", "File": "", "Notes": ""}, {"Name":
"MusicBee", "Category": "Media", "Default": false, "Method": "winget", "WingetId": "MusicBee.MusicBee", "ChocoId": "musicbee", "Url": "", "File": "", "Notes":
""}, {"Name": "Cloudflare WARP", "Category": "Network", "Default": false, "Method": "winget", "WingetId": "Cloudflare.Warp", "ChocoId": "cloudflare-warp",
"Url": "", "File": "", "Notes": "CARE"}, {"Name": "OpenVPN Connect", "Category": "Network", "Default": false, "Method": "winget", "WingetId":
"OpenVPNTechnologies.OpenVPNConnect", "ChocoId": "openvpn-connect", "Url": "", "File": "", "Notes": "CARE"}, {"Name": "Go (Golang)", "Category": "Development",
"Default": false, "Method": "winget", "WingetId": "GoLang.Go", "ChocoId": "golang", "Url": "", "File": "", "Notes": ""}, {"Name": "Rustup", "Category":
"Development", "Default": false, "Method": "winget", "WingetId": "Rustlang.Rustup", "ChocoId": "rustup.install", "Url": "", "File": "", "Notes": ""}, {"Name":
"Neovim", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Neovim.Neovim", "ChocoId": "neovim", "Url": "", "File": "", "Notes":
""}, {"Name": "WezTerm", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "wez.wezterm", "ChocoId": "wezterm", "Url": "", "File":
"", "Notes": ""}, {"Name": "Starship Prompt", "Category": "Development", "Default": false, "Method": "winget", "WingetId": "Starship.Starship", "ChocoId":
"starship", "Url": "", "File": "", "Notes": ""}, {"Name": "Oh My Posh", "Category": "Development", "Default": false, "Method": "winget", "WingetId":
"JanDeDobbeleer.OhMyPosh", "ChocoId": "oh-my-posh", "Url": "", "File": "", "Notes": ""}, {"Name": "Chocolatey GUI", "Category": "Utilities", "Default": false,
"Method": "choco", "WingetId": "", "ChocoId": "chocolateygui", "Url": "", "File": "", "Notes": "CARE"}]
'@

  $apps = @()
  try {
    $apps = $BaseCatalogJson | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $apps = @()
  }

  # Suite extras (choco + portable examples)
  $apps += @(
    @{ Name='Chocolatey GUI'; Category='Utilities'; Notes='GUI for Chocolatey'; Default=$false; Method='choco'; ChocoId='chocolateygui' },
    @{ Name='Sysinternals Suite (portable zip)'; Category='Utilities'; Notes='Portable toolkit (zip)'; Default=$false; Method='portable'; Url='https://download.sysinternals.com/files/SysinternalsSuite.zip'; File='SysinternalsSuite.zip'; InstallerType='zip' }
    ,@{ Name='Raspberry Pi Imager'; Category='ISO & USB'; Notes='Flash OS images to SD/USB'; Default=$false; Method='winget'; WingetId='RaspberryPiFoundation.RaspberryPiImager' }
    ,@{ Name='GitKraken'; Category='Development'; Notes='Git GUI'; Default=$false; Method='winget'; WingetId='Axosoft.GitKraken' }
    ,@{ Name='Kdenlive'; Category='Media'; Notes='Video editor'; Default=$false; Method='winget'; WingetId='KDE.Kdenlive' }
    ,@{ Name='VSCodium'; Category='Development'; Notes='VS Code (community build)'; Default=$false; Method='winget'; WingetId='VSCodium.VSCodium' }
    ,@{ Name='Insomnia'; Category='Development'; Notes='API client'; Default=$false; Method='winget'; WingetId='Insomnia.Insomnia' }
  )

  # Load catalog extensions (optional JSON files) from catalog.d
  if(Test-Path -LiteralPath $CatalogDir) {
    Get-ChildItem -LiteralPath $CatalogDir -Filter *.json -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        $ext = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        if($ext -is [System.Array]) {
          foreach($e in $ext) { $apps += @($e) }
        } elseif($null -ne $ext) {
          $apps += @($ext)
        }
      } catch {
        # ignore broken extension files
      }
    }
  }


  # Deduplicate catalog by WingetId/ChocoId/Name (prefer winget/choco entries over download/portable duplicates)
  try {
    $bWinget   = @()
    $bChoco    = @()
    $bDownload = @()
    $bPortable = @()
    $bOther    = @()

    foreach($a in $apps){
      $m = [string](Get-AppField $a @('Method','method'))
      $ml = if($m){ $m.Trim().ToLowerInvariant() } else { '' }
      switch($ml){
        'winget'   { $bWinget   += @($a) }
        'choco'    { $bChoco    += @($a) }
        'download' { $bDownload += @($a) }
        'portable' { $bPortable += @($a) }
        default    { $bOther    += @($a) }
      }
    }

    $apps = @($bWinget + $bChoco + $bDownload + $bPortable + $bOther)

    $seen = @{}
    $dedup = @()
    foreach($a in $apps){
      $wing = [string](Get-AppField $a @('WingetId','WinGetId','Winget','WingetID','Id','ID'))
      $choc = [string](Get-AppField $a @('ChocoId','ChocolateyId','Choco','ChocoID'))
      $name = [string](Get-AppField $a @('Name'))
      $k = if(-not [string]::IsNullOrWhiteSpace($wing)){
        'w:' + $wing.Trim().ToLowerInvariant()
      } elseif(-not [string]::IsNullOrWhiteSpace($choc)){
        'c:' + $choc.Trim().ToLowerInvariant()
      } else {
        'n:' + $name.Trim().ToLowerInvariant()
      }
      if(-not $seen.ContainsKey($k)){
        $seen[$k] = $true
        $dedup += @($a)
      }
    }
    $apps = $dedup
  } catch {}

  return $apps
}




# -----------------------
# Dependencies + ordering
# -----------------------
function Expand-Dependencies {
  param(
    [Parameter(Mandatory=$true)] [object[]]$Target,
    [Parameter(Mandatory=$true)] [object[]]$AllItems
  )
  $added = New-Object System.Collections.Generic.List[object]
  $byKey = @{}
  foreach($it in $AllItems){
    $key = ($it.WingetId, $it.ChocoId, $it.Name) | Where-Object { $_ } | Select-Object -First 1
    if($key){ $byKey[$key.ToString().ToLowerInvariant()] = $it }
  }
  $set = @{}
  foreach($t in $Target){
    $k = ($t.WingetId, $t.ChocoId, $t.Name) | Where-Object { $_ } | Select-Object -First 1
    if($k){ $set[$k.ToString().ToLowerInvariant()] = $true }
  }
  $queue = New-Object System.Collections.Generic.Queue[object]
  foreach($t in $Target){ $queue.Enqueue($t) }

  while($queue.Count -gt 0){
    $cur = $queue.Dequeue()
    foreach($d in @($cur.Dependencies)){
      if(-not $d){ continue }
      $dk = $d.ToString().ToLowerInvariant()
      if($set.ContainsKey($dk)){ continue }
      if($byKey.ContainsKey($dk)){
        $dep = $byKey[$dk]
        $set[$dk] = $true
        $added.Add($dep) | Out-Null
        $queue.Enqueue($dep)
      } else {
        # try match by name
        $dep = $AllItems | Where-Object { $_.Name -and $_.Name.ToLowerInvariant() -eq $dk } | Select-Object -First 1
        if($dep){
          $key2 = ($dep.WingetId,$dep.ChocoId,$dep.Name) | Where-Object {$_} | Select-Object -First 1
          $k2 = $key2.ToString().ToLowerInvariant()
          if(-not $set.ContainsKey($k2)){
            $set[$k2] = $true
            $added.Add($dep) | Out-Null
            $queue.Enqueue($dep)
          }
        }
      }
    }
  }

  $newTarget = @()
  foreach($it in $Target){ $newTarget += $it }
  foreach($it in $added){ $newTarget += $it }
  # unique preserve order
  $seen=@{}
  $ded=@()
  foreach($it in $newTarget){
    $k = ($it.WingetId,$it.ChocoId,$it.Name) | Where-Object {$_} | Select-Object -First 1
    $kk = $k.ToString().ToLowerInvariant()
    if(-not $seen.ContainsKey($kk)){ $seen[$kk]=$true; $ded += $it }
  }
  return [pscustomobject]@{ Target=$ded; Added=$added }
}

function Sort-ByDependencies {
  param([object[]]$Target,[object[]]$AllItems)
  # simple topo sort by provided Dependencies (names/ids). If cycles, falls back to original order.
  $keyOf = {
    param($it)
    (($it.WingetId,$it.ChocoId,$it.Name) | Where-Object {$_} | Select-Object -First 1).ToString().ToLowerInvariant()
  }
  $nodes = @{}
  foreach($it in $Target){ $nodes[(& $keyOf $it)] = $it }
  $inDeg = @{}
  $edges = @{}
  foreach($k in $nodes.Keys){ $inDeg[$k]=0; $edges[$k]=New-Object System.Collections.Generic.List[string] }
  foreach($it in $Target){
    $k = & $keyOf $it
    foreach($d in @($it.Dependencies)){
      if(-not $d){ continue }
      $dk = $d.ToString().ToLowerInvariant()
      if($nodes.ContainsKey($dk)){
        $edges[$dk].Add($k) | Out-Null
        $inDeg[$k] = [int]$inDeg[$k] + 1
      }
    }
  }
  $q = New-Object System.Collections.Generic.Queue[string]
  foreach($k in $inDeg.Keys){ if([int]$inDeg[$k] -eq 0){ $q.Enqueue($k) } }
  $out = New-Object System.Collections.Generic.List[object]
  while($q.Count -gt 0){
    $k = $q.Dequeue()
    $out.Add($nodes[$k]) | Out-Null
    foreach($to in $edges[$k]){
      $inDeg[$to] = [int]$inDeg[$to] - 1
      if([int]$inDeg[$to] -eq 0){ $q.Enqueue($to) }
    }
  }
  if($out.Count -ne $nodes.Count){ return $Target } # cycle
  return $out.ToArray()
}

# -----------------------
# Installed caches (winget/choco)
# -----------------------
function Invoke-WithTimeout {
  param(
    [Parameter(Mandatory)] [scriptblock]$Script,
    [int]$TimeoutSec = 15
  )
  $job = Start-Job -ScriptBlock $Script
  try {
    if(Wait-Job $job -Timeout $TimeoutSec){
      return Receive-Job $job
    } else {
      Stop-Job $job -Force | Out-Null
      return $null
    }
  } finally {
    Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
  }
}

function Get-WingetInstalledMap {
  if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ return @{} }
  $out = Invoke-WithTimeout -TimeoutSec 15 -Script {
    & winget list --disable-interactivity 2>$null
  }
  if(-not $out){ return @{} }

  # Parse: try to locate "Id" column by splitting lines; fall back to regex
  $map = @{}
  foreach($line in ($out -split "`r?`n")){
    if($line -match '^\s*$'){ continue }
    # Many winget list formats: Name Id Version Available Source
    # Heuristic: find sequences with dots and no spaces (Id)
    if($line -match '\s([A-Za-z0-9]+\.[A-Za-z0-9\.\-]+)\s+([0-9][0-9A-Za-z\.\-\+]+)'){
      $id = $Matches[1]
      if($id){ $map[$id.ToLowerInvariant()] = $true }
    }
  }
  return $map
}

function Get-ChocoInstalledMap {
  if(-not (Get-Command choco -ErrorAction SilentlyContinue)){ return @{} }
  $out = Invoke-WithTimeout -TimeoutSec 15 -Script {
    & choco list --local-only --limit-output 2>$null
  }
  if(-not $out){ return @{} }
  $map = @{}
  foreach($line in ($out -split "`r?`n")){
    # id|version
    if($line -match '^([A-Za-z0-9\.\-_]+)\|(.+)$'){
      $id = $Matches[1]
      $map[$id.ToLowerInvariant()] = $true
    }
  }
  return $map
}

# -----------------------
# Profiles / share token / snapshots
# -----------------------
function Get-BuiltinProfiles {
  @(
    'None','Minimal','Gaming','Office','Dev','Creator','Sysadmin','Portable'
  )
}


function Get-ProfileDescription([string]$p){
  switch($p){
    'Minimal'  { return $L.ProfileDesc_Minimal }
    'Gaming'   { return $L.ProfileDesc_Gaming }
    'Office'   { return $L.ProfileDesc_Office }
    'Dev'      { return $L.ProfileDesc_Dev }
    'Creator'  { return $L.ProfileDesc_Creator }
    'Sysadmin' { return $L.ProfileDesc_Sysadmin }
    'Portable' { return $L.ProfileDesc_Portable }
    default    { return $L.ProfileDesc_None }
  }
}


function Profile-Path([string]$name){
  if(-not $name){ return $null }
  $safe = ($name -replace '[^A-Za-z0-9_\- ]','').Trim()
  if(-not $safe){ return $null }
  return Join-Path $ProfilesDir ($safe + '.json')
}

function Export-SelectionObject($items){
  # stable ids: prefer WingetId/ChocoId else Name
  $sel = @()
  foreach($it in $items | Where-Object { $_.IsSelected }){
    $sel += [pscustomobject]@{
      Name = $it.Name
      WingetId = $it.WingetId
      ChocoId  = $it.ChocoId
      Method   = $it.Method
      Category = $it.Category
    }
  }
  return [pscustomobject]@{
    schema = 1
    created = (Get-Date).ToString('s')
    selected = $sel
  }
}

function Apply-SelectionObject($items, $obj, [switch]$ClearFirst){
  $script:SuppressSelectionEvents = $true
  try {

  if($ClearFirst){
    foreach($it in $items){ $it.IsSelected = $false }
  }
  if(-not $obj -or -not $obj.selected){ return }
  $set = @{}
  foreach($s in $obj.selected){
    $key = ($s.WingetId, $s.ChocoId, $s.Name) | Where-Object { $_ } | Select-Object -First 1
    if($key){ $set[$key.ToString().ToLowerInvariant()] = $true }
  }
  foreach($it in $items){
    $key = ($it.WingetId, $it.ChocoId, $it.Name) | Where-Object { $_ } | Select-Object -First 1
    if($key -and $set.ContainsKey($key.ToLowerInvariant())){
      $it.IsSelected = $true
    }
  }

  } finally { $script:SuppressSelectionEvents = $false }
}

function Encode-ShareToken($obj){
  # gzip + base64url
  $json = ($obj | ConvertTo-Json -Depth 6)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $ms = New-Object System.IO.MemoryStream
  $gz = New-Object System.IO.Compression.GZipStream($ms,[System.IO.Compression.CompressionMode]::Compress)
  $gz.Write($bytes,0,$bytes.Length); $gz.Close()
  $b64 = [Convert]::ToBase64String($ms.ToArray())
  $b64url = $b64.TrimEnd('=') -replace '\+','-' -replace '/','_'
  return $b64url
}

# QR generation: online fallback (safe) - can be replaced later with offline library.
function Get-QRImageFromToken([string]$token){
  try {
    $enc = [System.Web.HttpUtility]::UrlEncode($token)
    $url = "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=$enc"
    $tmp = Join-Path $env:TEMP ("47qr_" + (Get-NowStamp) + ".png")
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -TimeoutSec 10 | Out-Null
    if(Test-Path -LiteralPath $tmp){ return $tmp }
  } catch {}
  return $null
}

# -------------
# Job engine
# -------------
function New-JobStep([string]$kind,[string]$detail,[scriptblock]$action,[int]$timeout=1800){
  [pscustomobject]@{ Kind=$kind; Detail=$detail; Action=$action; TimeoutSec=$timeout }
}
function New-AppJob($app,[string]$mode){
  # mode: download/install/update/uninstall
  $steps = @()
  $idText = if($app.WingetId){ "winget:$($app.WingetId)" } elseif($app.ChocoId){ "choco:$($app.ChocoId)" } else { $app.Name }

  if($mode -eq 'download'){
    if($app.Method -in @('download','portable')){
      $steps += New-JobStep 'Download' $idText { param($ctx) Invoke-DownloadStep -Ctx $ctx } 1800
      if($app.Method -eq 'portable' -and $app.InstallerType -eq 'zip'){
        $steps += New-JobStep 'Extract' $idText { param($ctx) Invoke-PortableExtractStep -Ctx $ctx } 600
      }
    }
  }
  elseif($mode -eq 'install'){
    if($app.Method -eq 'winget' -and $app.WingetId){
      $steps += New-JobStep 'Install(winget)' $idText { param($ctx) Invoke-WingetInstall -Ctx $ctx } 1800
    } elseif($app.Method -eq 'choco' -and $app.ChocoId){
      $steps += New-JobStep 'Install(choco)' $idText { param($ctx) Invoke-ChocoInstall -Ctx $ctx } 1800
    } elseif($app.Method -in @('download','portable')){
      $steps += New-JobStep 'Download' $idText { param($ctx) Invoke-DownloadStep -Ctx $ctx } 1800
      if($app.Method -eq 'portable' -and $app.InstallerType -eq 'zip'){
        $steps += New-JobStep 'Extract' $idText { param($ctx) Invoke-PortableExtractStep -Ctx $ctx } 600
      } else {
        $steps += New-JobStep 'Run(installer)' $idText { param($ctx) Invoke-RunInstallerStep -Ctx $ctx } 1800
      }
    }
  }
  elseif($mode -eq 'update'){
    if($app.WingetId){
      $steps += New-JobStep 'Update(winget)' $idText { param($ctx) Invoke-WingetUpgrade -Ctx $ctx } 1800
    } elseif($app.ChocoId){
      $steps += New-JobStep 'Update(choco)' $idText { param($ctx) Invoke-ChocoUpgrade -Ctx $ctx } 1800
    }
  }
  elseif($mode -eq 'uninstall'){
    if($app.WingetId){
      $steps += New-JobStep 'Uninstall(winget)' $idText { param($ctx) Invoke-WingetUninstall -Ctx $ctx } 1800
    } elseif($app.ChocoId){
      $steps += New-JobStep 'Uninstall(choco)' $idText { param($ctx) Invoke-ChocoUninstall -Ctx $ctx } 1800
    }
  }

  return [pscustomobject]@{
    App = $app
    Mode = $mode
    Steps = $steps
    Status = 'Queued'
    Started = $null
    Ended = $null
    Error = $null
  }
}

# Execution helpers (dry-run supported by ctx.DryRun)
function Invoke-External([string]$file,[string]$args,[int]$timeoutSec,[scriptblock]$Log,[switch]$IgnoreExitCode){
  $Log.Invoke("RUN: $file $args")
  if($script:CurrentCtx.DryRun){ return 0 }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $file
  $psi.Arguments = $args
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $null = $p.Start()
  if(-not $p.WaitForExit($timeoutSec*1000)){
    try { $p.Kill() } catch {}
    throw "Process timeout after ${timeoutSec}s: $file"
  }
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  if($out){ $Log.Invoke($out.Trim()) }
  if($err){ $Log.Invoke($err.Trim()) }
  if((-not $IgnoreExitCode) -and $p.ExitCode -ne 0){
    throw "ExitCode $($p.ExitCode) from $file"
  }
  return $p.ExitCode
}

function Ensure-DownloadMeta([string]$filePath){
  if(-not (Test-Path -LiteralPath $filePath)){ return }
  $hash = Hash-FileSHA256 $filePath
  $size = (Get-Item -LiteralPath $filePath).Length
  $rel  = ''
  try {
    if($filePath -like ($DownloadsDir + '*')){
      $rel = $filePath.Substring($DownloadsDir.Length).TrimStart('\')
    }
  } catch {}

  $meta = [pscustomobject]@{
    file = (Split-Path -Leaf $filePath)
    path = $filePath
    rel  = $rel
    sha256 = $hash
    size = $size
    time = (Get-Date).ToString('s')
  }

  $leaf = (Split-Path -Leaf $filePath)
  $tag = if($hash -and $hash.Length -ge 12){ $hash.Substring(0,12) } else { (Get-Random -Minimum 100000 -Maximum 999999).ToString() }
  $metaName = "$leaf.$tag.json"
  $metaPath = Join-Path $MetaDir $metaName
  Write-JsonFile $metaPath $meta
}


# -----------------------
# Download management / integrity
# -----------------------
function Find-DownloadedFileForApp {
  param([Parameter(Mandatory)]$App,[string]$Root = $DownloadsDir)
  $leafs = @()
  if($App.File){ $leafs += [string]$App.File }
  if($App.Url){ 
    try { $leafs += [IO.Path]::GetFileName([string]$App.Url) } catch {}
  }
  $leafs = @($leafs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
  foreach($leaf in $leafs){
    $p = Join-Path $Root $leaf
    if(Test-Path -LiteralPath $p){ return $p }
    # recursive search (in case category/app folders)
    try {
      $found = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue | Select-Object -First 1
      if($found){ return $found.FullName }
    } catch {}
  }
  return $null
}

function Read-DownloadMetaIndex {
  $list = @()
  if(Test-Path -LiteralPath $MetaDir){
    try {
      $list = Get-ChildItem -LiteralPath $MetaDir -File -Filter '*.json' -ErrorAction SilentlyContinue
    } catch { $list = @() }
  }
  return $list
}

function Verify-Downloads {
  param([switch]$Quiet,[switch]$Return)
  $results = New-Object System.Collections.Generic.List[object]
  foreach($f in (Read-DownloadMetaIndex)){
    $m = Read-JsonFile $f.FullName
    if(-not $m){ continue }
    $path = [string]$m.path
    $ok = $false
    $why = ''
    if(-not (Test-Path -LiteralPath $path)){
      $why = 'missing'
    } else {
      try {
        $h = Hash-FileSHA256 $path
        $sz = (Get-Item -LiteralPath $path).Length
        if($m.sha256 -and $h -ne [string]$m.sha256){ $why = 'hash-mismatch' }
        elseif($m.size -and [int64]$sz -ne [int64]$m.size){ $why = 'size-mismatch' }
        else { $ok = $true }
      } catch { $why = 'verify-failed' }
    }
    $results.Add([pscustomobject]@{
      file = [string]$m.file
      path = $path
      sha256 = [string]$m.sha256
      size = $m.size
      ok = $ok
      issue = $why
      meta = $f.FullName
    }) | Out-Null
  }

  $bad = @($results | Where-Object { -not $_.ok })
  $good = @($results | Where-Object { $_.ok })
  $script:CorruptDownloads = $bad

  if(-not $Quiet){
    $msg = "Downloads verified.`n`nOK: $($good.Count)`nIssues: $($bad.Count)"
    if($bad.Count -gt 0){
      $top = ($bad | Select-Object -First 10 | ForEach-Object { "$($_.issue): $($_.file)" }) -join "`n"
      $msg += "`n`nTop issues:`n$top"
    }
    Show-Message $msg '47Project' 'Info'
  }
  if($Return){ return $results }
}

function Clear-DownloadsAll {
  try {
    if(Test-Path -LiteralPath $DownloadsDir){
      Get-ChildItem -LiteralPath $DownloadsDir -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne '_meta' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    if(Test-Path -LiteralPath $MetaDir){
      Get-ChildItem -LiteralPath $MetaDir -File -Filter '*.json' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

function Clear-DownloadsForApps {
  param([Parameter(Mandatory)]$Apps)
  foreach($a in @($Apps)){
    $p = Find-DownloadedFileForApp -App $a
    if($p -and (Test-Path -LiteralPath $p)){
      try { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } catch {}
    }
    # remove matching meta entries
    foreach($mf in (Read-DownloadMetaIndex)){
      $m = Read-JsonFile $mf.FullName
      if($m -and $m.file -and $a.File -and ([string]$m.file -ieq [string]$a.File)){
        try { Remove-Item -LiteralPath $mf.FullName -Force -ErrorAction SilentlyContinue } catch {}
      }
    }
  }
}

function Export-OfflineManifest {
  param([Parameter(Mandatory)]$Apps)
  $list = @()
  foreach($a in @($Apps)){
    $filePath = Find-DownloadedFileForApp -App $a
    $hash = ''
    $size = 0
    if($filePath -and (Test-Path -LiteralPath $filePath)){
      try { $hash = Hash-FileSHA256 $filePath } catch {}
      try { $size = (Get-Item -LiteralPath $filePath).Length } catch {}
    }
    $list += [pscustomobject]@{
      Name = $a.Name
      Category = $a.Category
      Method = $a.Method
      WingetId = $a.WingetId
      ChocoId = $a.ChocoId
      Url = $a.Url
      UrlFallbacks = @($a.UrlFallbacks)
      File = $a.File
      DownloadedPath = $filePath
      Sha256 = $hash
      Size = $size
      Profiles = @($a.Profiles)
    }
  }
  $obj = [pscustomobject]@{
    schema = 1
    created = (Get-Date).ToString('s')
    baseDir = $BaseDir
    downloadsDir = $DownloadsDir
    installRoot = $InstallRoot
    apps = $list
  }
  $p = Join-Path $ExportsDir ("offline_manifest_" + (Get-NowStamp) + ".json")
  Write-JsonFile $p $obj
  UI-Log "Offline manifest: $p"
  Open-ExplorerSelect $p
}

function Redownload-Corrupted {
  param([switch]$DryRun)
  Verify-Downloads -Quiet
  $bad = @($script:CorruptDownloads)
  if($bad.Count -eq 0){
    Show-Message "No corrupted downloads detected." '47Project' 'Info'
    return
  }
  $appsToDl = New-Object System.Collections.Generic.List[object]
  foreach($b in $bad){
    $leaf = [string]$b.file
    $hit = $items | Where-Object { $_.File -and ([string]$_.File -ieq $leaf) } | Select-Object -First 1
    if($hit){ $appsToDl.Add($hit) | Out-Null }
  }
  if($appsToDl.Count -eq 0){
    Show-Message "Corrupted files found, but none map to catalog entries. Use Clear downloads (all) or re-download manually." '47Project' 'Warn'
    return
  }
  foreach($a in $appsToDl){
    $ctx = [pscustomobject]@{
      DownloadDir = $DownloadsDir
      DownloadByCategory = [bool]$ChkDownloadByCategory.IsChecked
      InstallRoot = $InstallRoot
      DryRun = $DryRun
      InstallMode = 'interactive'
      Log = ${function:UI-Log}
      Ui  = { param($t) }
      LastDownloaded = $null
      App = $a
    }
    try { Invoke-DownloadStep -Ctx $ctx } catch { UI-Log "Re-download failed: $($a.Name): $($_.Exception.Message)" }
  }
  Show-Message "Re-download attempt finished. Check Logs tab for details." '47Project' 'Info'
}

function Invoke-DownloadStep {
  param([Parameter(Mandatory)]$Ctx)
  $app = $Ctx.App
  if(-not $app.Url){ throw "No download URL for $($app.Name)" }

  $urls = @()
  $urls += [string]$app.Url
  if($app.PSObject.Properties['UrlFallbacks'] -and $app.UrlFallbacks){
    $urls += @($app.UrlFallbacks | ForEach-Object { [string]$_ })
  }
  $urls = @($urls | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

  $fileName = if($app.File){ $app.File } else { [IO.Path]::GetFileName($urls[0]) }
  if(-not $fileName){ $fileName = ($app.Name -replace '[^A-Za-z0-9_\-]','') + '.bin' }

  # Enterprise mirror base (optional): try internal mirror first
  try {
    if($script:Enterprise -and $script:Enterprise.mirrorBase){
      $mb = ([string]$script:Enterprise.mirrorBase).Trim()
      if($mb){
        $mb = $mb.TrimEnd('/')
        $urls = @("$mb/$fileName") + $urls
      }
    }
  } catch {}


  $destDir = $Ctx.DownloadDir
  if($Ctx.PSObject.Properties['DownloadByCategory'] -and $Ctx.DownloadByCategory){
    $cat = ([string]$app.Category -replace '[:\\\/\*\?\"<>|]','_')
    if([string]::IsNullOrWhiteSpace($cat)){ $cat = 'Uncategorized' }
    $appn = ([string]$app.Name -replace '[:\\\/\*\?\"<>|]','_')
    if([string]::IsNullOrWhiteSpace($appn)){ $appn = 'App' }
    $destDir = Join-Path (Join-Path $Ctx.DownloadDir $cat) $appn
  }

  $dest = Join-Path $destDir $fileName
  $Ctx.Log.Invoke("Downloading to: $dest")
  if($Ctx.DryRun){ return }

  # RepoShare copy-first (Enterprise): if installer exists on internal share/repo, copy instead of downloading
  try {
    $rs = ([string]$script:Enterprise.repoShare).Trim()
    if($rs){
      $candidates = @()
      $candidates += (Join-Path $rs $fileName)
      $candidates += (Join-Path (Join-Path $rs "packages") $fileName)
      foreach($cand in $candidates){
        if(Test-Path -LiteralPath $cand){
          if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
          Copy-Item -LiteralPath $cand -Destination $dest -Force
          $Ctx.Log.Invoke("RepoShare HIT: copied $cand")
          Ensure-DownloadMeta $dest
          $Ctx.LastDownloaded = $dest
          return
        }
      }
    }
  } catch {}

  if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

  $wc = New-Object System.Net.WebClient

  # Enterprise network settings (TLS/proxy)
  try {
    if($script:Enterprise -and $script:Enterprise.tls){
      $t = [string]$script:Enterprise.tls
      if($t -match '13'){
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor ([Net.SecurityProtocolType]::Tls13) } catch { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }
      } else {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      }
    } else {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    if($script:Enterprise -and $script:Enterprise.proxy -and -not [string]::IsNullOrWhiteSpace([string]$script:Enterprise.proxy)){
      $wc.Proxy = New-Object System.Net.WebProxy([string]$script:Enterprise.proxy,$true)
    } elseif($script:Enterprise -and ($script:Enterprise.useSystemProxy -eq $false)){
      $wc.Proxy = $null
    } else {
      $wc.Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    }
  } catch {}

  try {
    $ok = $false
    foreach($u in $urls){
      try {
        $Ctx.Log.Invoke("GET: $u")
        $wc.DownloadFile($u, $dest)
        $ok = $true
        break
      } catch {
        $Ctx.Log.Invoke("Mirror failed: $u ($($_.Exception.Message))")
      }
    }
    if(-not $ok){ throw "All mirrors failed for $($app.Name)" }
  } finally { $wc.Dispose() }

  Ensure-DownloadMeta $dest
  $Ctx.LastDownloaded = $dest
}

function Invoke-PortableExtractStep {
  param([Parameter(Mandatory)]$Ctx)
  $app = $Ctx.App
  $zip = $Ctx.LastDownloaded
  if(-not $zip -or -not (Test-Path -LiteralPath $zip)){ throw "Portable ZIP missing for $($app.Name)" }
  $dest = Join-Path $Ctx.InstallRoot ($app.Name -replace '[:\\\/\*\?\"<>|]','_')
  $Ctx.Log.Invoke("Extracting to: $dest")
  if($Ctx.DryRun){ return }
  if(Test-Path -LiteralPath $dest){ } else { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
  Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
}

function Invoke-RunInstallerStep {
  param([Parameter(Mandatory)]$Ctx)
  $app = $Ctx.App
  $installer = $Ctx.LastDownloaded
  if(-not $installer -or -not (Test-Path -LiteralPath $installer)){ throw "Installer missing for $($app.Name)" }
  $targetDir = Join-Path $Ctx.InstallRoot ($app.Name -replace '[:\\\/\*\?\"<>|]','_')

  if($Ctx.InstallMode -eq 'auto'){
    # best-effort silent installs; fall back to interactive if unknown
    if($app.InstallerType -eq 'msi'){
      $args = "/i `"$installer`" /qn /norestart INSTALLDIR=`"$targetDir`""
      Invoke-External "msiexec.exe" $args 1800 $Ctx.Log
      return
    }
    if($app.InstallerType -eq 'inno'){
      $args = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$targetDir`""
      Invoke-External $installer $args 1800 $Ctx.Log -IgnoreExitCode
      return
    }
    if($app.InstallerType -eq 'nsis'){
      $args = "/S"
      Invoke-External $installer $args 1800 $Ctx.Log -IgnoreExitCode
      return
    }
    if($app.SilentArgs){
      $args = $app.SilentArgs -replace '\{INSTALLDIR\}', [Regex]::Escape($targetDir)
      Invoke-External $installer $args 1800 $Ctx.Log -IgnoreExitCode
      return
    }
    $Ctx.Log.Invoke("Auto mode: no known silent args for $($app.Name). Falling back to interactive.")
  }

  $Ctx.Log.Invoke("Launching installer (interactive): $installer")
  if($Ctx.DryRun){ return }
  Start-Process -FilePath $installer -WorkingDirectory (Split-Path -Parent $installer) | Out-Null
}

function Invoke-WingetInstall { param($Ctx)
  if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ throw "winget not found" }
  $id = $Ctx.App.WingetId
  $args = "install --id `"$id`" -e --accept-package-agreements --accept-source-agreements --disable-interactivity"
  Invoke-External "winget.exe" $args 1800 $Ctx.Log
}
function Invoke-WingetUpgrade { param($Ctx)
  if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ throw "winget not found" }
  $id = $Ctx.App.WingetId
  $args = "upgrade --id `"$id`" -e --accept-package-agreements --accept-source-agreements --disable-interactivity"
  Invoke-External "winget.exe" $args 1800 $Ctx.Log -IgnoreExitCode
}
function Invoke-WingetUninstall { param($Ctx)
  if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ throw "winget not found" }
  $id = $Ctx.App.WingetId
  $args = "uninstall --id `"$id`" -e --disable-interactivity"
  Invoke-External "winget.exe" $args 1800 $Ctx.Log -IgnoreExitCode
}

function Invoke-ChocoInstall { param($Ctx)
  if(-not (Ensure-Choco -Log $Ctx.Log -Ui $Ctx.Ui)){ throw "choco missing" }
  $id = $Ctx.App.ChocoId
  Invoke-External "choco.exe" "install $id -y --no-progress" 1800 $Ctx.Log
}
function Invoke-ChocoUpgrade { param($Ctx)
  if(-not (Ensure-Choco -Log $Ctx.Log -Ui $Ctx.Ui)){ throw "choco missing" }
  $id = $Ctx.App.ChocoId
  Invoke-External "choco.exe" "upgrade $id -y --no-progress" 1800 $Ctx.Log -IgnoreExitCode
}
function Invoke-ChocoUninstall { param($Ctx)
  if(-not (Ensure-Choco -Log $Ctx.Log -Ui $Ctx.Ui)){ throw "choco missing" }
  $id = $Ctx.App.ChocoId
  Invoke-External "choco.exe" "uninstall $id -y --no-progress" 1800 $Ctx.Log -IgnoreExitCode
}

# -----------------------
# Parallel downloads (runspace pool)
# -----------------------
function Start-ParallelDownloads {
  param(
    [Parameter(Mandatory)] [System.Collections.IEnumerable]$Apps,
    [Parameter(Mandatory)] [string]$DownloadDir,
    [switch]$ByCategory,
    [int]$Throttle = 3,
    [switch]$DryRun,
    [scriptblock]$Log,
    [scriptblock]$UiProgress
  )
  $dlApps = @($Apps | Where-Object { $_.Method -in @('download','portable') -and $_.Url })
  if($dlApps.Count -eq 0){ return }

  $Log.Invoke("Parallel download: $($dlApps.Count) items, throttle=$Throttle")
  if($DryRun){
    foreach($a in $dlApps){ $Log.Invoke("DRYRUN download: $($a.Name) -> $($a.Url)") }
    return
  }

  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Throttle,$iss,$Host)
  $pool.Open()

  $handles = @()
  $i = 0
  foreach($a in $dlApps){
    $i++
    $UiProgress.Invoke($i,$dlApps.Count,$a.Name)
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $pool
    $ps.AddScript({
      param($name,$urls,$file,$destDir)
      $fileName = if($file){ $file } else { [IO.Path]::GetFileName([string]($urls | Select-Object -First 1)) }
      if(-not $fileName){ $fileName = ($name -replace '[^A-Za-z0-9_\-]','') + '.bin' }
      $dest = Join-Path $destDir $fileName
      if(-not (Test-Path -LiteralPath $destDir)){ New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

      $wc = New-Object System.Net.WebClient
      try {
        foreach($u in @($urls)){
          if([string]::IsNullOrWhiteSpace([string]$u)){ continue }
          try {
            $wc.DownloadFile([string]$u,$dest)
            return $dest
          } catch {
            # try next
          }
        }
        throw "All mirrors failed."
      } finally { $wc.Dispose() }
    }) | Out-Null    $destDir = $DownloadDir
    if($ByCategory){
      $cat = ([string]$a.Category -replace '[:\\/\*\?\"<>|]','_')
      if([string]::IsNullOrWhiteSpace($cat)){ $cat = 'Uncategorized' }
      $appn = ([string]$a.Name -replace '[:\\/\*\?\"<>|]','_')
      if([string]::IsNullOrWhiteSpace($appn)){ $appn = 'App' }
      $destDir = Join-Path (Join-Path $DownloadDir $cat) $appn
    }

    $ps.AddArgument($a.Name) | Out-Null
    $ps.AddArgument(@(@($a.Url) + @($a.UrlFallbacks))) | Out-Null
    $ps.AddArgument($a.File) | Out-Null
    $ps.AddArgument($destDir) | Out-Null
    $handle = $ps.BeginInvoke()
    $handles += [pscustomobject]@{ PS=$ps; Handle=$handle; App=$a }
  }

  foreach($h in $handles){
    try {
      $res = $h.PS.EndInvoke($h.Handle)
      if($res){
        Ensure-DownloadMeta $res
        $Log.Invoke("Downloaded: $($h.App.Name) -> $res")
      }
    } catch {
      $Log.Invoke("Download failed: $($h.App.Name): $($_.Exception.Message)")
    } finally {
      $h.PS.Dispose()
    }
  }
  $pool.Close(); $pool.Dispose()
}

# -----------------------
# Readiness check
# -----------------------
function Run-Preflight([scriptblock]$Log){
  $report = New-Object System.Collections.Generic.List[object]
  function Add([string]$name,[string]$status,[string]$detail){ $report.Add([pscustomobject]@{Check=$name; Status=$status; Detail=$detail}) }

  # Disk space (best-effort)
  try {
    $drive = Get-PSDrive -Name 'C'
    $freeGB = [math]::Round($drive.Free/1GB,1)
    Add 'Disk space (C:)' (if($freeGB -gt 5){'OK'} elseif($freeGB -gt 1){'WARN'} else {'FAIL'}) "$freeGB GB free"
  } catch { Add 'Disk space' 'WARN' 'Unknown' }

  Add 'winget' (if(Get-Command winget -EA SilentlyContinue){'OK'} else {'WARN'}) (if(Get-Command winget -EA SilentlyContinue){'Available'} else {'Not found'})
  Add 'choco' (if(Get-Command choco -EA SilentlyContinue){'OK'} else {'WARN'}) (if(Get-Command choco -EA SilentlyContinue){'Available'} else {'Not installed'})
  Add 'Admin' (if(Test-IsAdmin){'OK'} else {'WARN'}) (if(Test-IsAdmin){'Running elevated'} else {'Not elevated (some actions may fail)'})

  try {
    $ping = Test-Connection -ComputerName '1.1.1.1' -Count 1 -Quiet -ErrorAction SilentlyContinue
    Add 'Internet' (if($ping){'OK'} else {'WARN'}) (if($ping){'Reachable'} else {'Uncertain'})
  } catch { Add 'Internet' 'WARN' 'Uncertain' }

  foreach($r in $report){ $Log.Invoke(("Preflight: {0} => {1} ({2})" -f $r.Check,$r.Status,$r.Detail)) }
  return $report
}

# -----------------------
# Scheduled maintenance (opt-in)
# -----------------------
function Ensure-ScheduledTask([switch]$Remove,[scriptblock]$Log){
  $taskName = "47Project-AppCrawler-WeeklyUpdate"
  if($Remove){
    $Log.Invoke("Removing scheduled task: $taskName")
    if($script:CurrentCtx.DryRun){ return }
    schtasks.exe /Delete /TN $taskName /F | Out-Null
    return
  }

  $msg = "Create a weekly scheduled task to run 'Update All Installed (Catalog)' and write a report?`n`nThis will run with highest privileges."
  $res = [System.Windows.MessageBox]::Show($msg,'47Project',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
  if($res -ne [System.Windows.MessageBoxResult]::Yes){ return }

  if(-not (Test-IsAdmin)){
    Show-Message "Please run as Administrator to create scheduled tasks." '47Project' 'Warning'
    return
  }

  $self = $MyInvocation.MyCommand.Path
  $ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
  $cmd = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -STA -File `"$self`" -RunUI"
  # Weekly Sunday 03:00
  $Log.Invoke("Creating task: $taskName")
  if($script:CurrentCtx.DryRun){ return }
  schtasks.exe /Create /TN $taskName /SC WEEKLY /D SUN /ST 03:00 /RL HIGHEST /TR $cmd /F | Out-Null
}

# -----------------------
# Self-update (manual safe)
# -----------------------
$SelfUpdatePage = 'https://47.bearguard.cloud/project47/47crawler'
function Do-SelfUpdate([scriptblock]$Log){
  $Log.Invoke("Opening update page: $SelfUpdatePage")
  Start-Process $SelfUpdatePage | Out-Null
  Show-Message "Update page opened.`n`nFor safety, this build uses a manual update flow: download the new script and replace this file yourself." '47Project' 'Info'
}

# -----------------------
# Help (offline)
# -----------------------
$HelpText = @"
47Project AppS Crawler - Installer Suite

Basics:
- Scan builds installed caches (winget/choco) without freezing.
- Use filters/search/sort to find apps.
- Select apps and choose Download / Install / Update / Uninstall.
- Dry run + Actions Preview shows commands before running.

Profiles:
- Built-in profiles: Minimal/Gaming/Office/Dev/Creator/Sysadmin/Portable
- Save profiles to: $ProfilesDir
- Share Profile creates a token + QR (QR may require internet in this build).

Packs:
- Export pack copies downloads + profiles + exports + settings to a folder/USB.
- Import pack loads profiles and can point downloads to the pack.

Uninstall:
- Managed uninstall works best for winget/choco apps only.
- Uninstall can remove user data. Use carefully.
"@

# -----------------------
# UI XAML
# -----------------------
# -----------------------
# Headless mode (enterprise/labs) - optional, does not affect UI startup
# -----------------------
if($NoUI){
  try {
    Write-Host "[47Project] Headless mode active. Action=$Action Profile=$ApplyProfile Mode=$InstallMode" -ForegroundColor Green

    # Apply profile/default selection
    if($ApplyProfile){
      foreach($it in $items){
        $it.IsSelected = ($it.Profiles -and ($it.Profiles -contains $ApplyProfile))
      }
    } else {
      foreach($it in $items){
        $it.IsSelected = [bool]$it.Default
      }
    }

    # Lightweight installed scan (winget/choco/registry-name)
    $wg = Get-WingetInstalledMap
    $ch = Get-ChocoInstalledMap
    $reg = @()
    try { $reg = @(Get-RegistryInventory) } catch {}
    $regKeys = @{}
    foreach($r in $reg){
      $k = (_NormKey ([string]$r.Name))
      if($k){ $regKeys[$k] = $true }
    }
    foreach($it in $items){
      $it.IsInstalled = $false
      $it.InstalledVersion = ''
      if($it.WingetId -and $wg.ContainsKey([string]$it.WingetId)){
        $it.IsInstalled = $true
        $it.InstalledVersion = [string]$wg[[string]$it.WingetId]
      } elseif($it.ChocoId -and $ch.ContainsKey([string]$it.ChocoId)){
        $it.IsInstalled = $true
        $it.InstalledVersion = [string]$ch[[string]$it.ChocoId]
      } else {
        $nk = _NormKey ([string]$it.Name)
        if($nk -and $regKeys.ContainsKey($nk)){ $it.IsInstalled = $true }
      }
    }

    # inventory-only
    if($Action -eq 'inventory'){
      $path = Join-Path $ExportsDir ("system-inventory-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "." + $Format)
      Export-SystemInventory -Path $path -Format $Format | Out-Null
      Write-Host "[47Project] Inventory exported: $path"
      return
    }

    $target = @($items | Where-Object { $_.IsSelected })
    if(-not $target -or $target.Count -eq 0){
      Write-Host "[47Project] No items selected." -ForegroundColor Yellow
      return
    }

    foreach($app in $target){
      $ctx = [pscustomobject]@{
        App = $app
        DownloadsDir = $DownloadsDir
        InstallRoot  = $InstallRoot
        InstallMode  = $InstallMode
        MirrorBase   = [string]$script:Enterprise.mirrorBase
        Log = { param($m) Write-Host ("[" + $app.Name + "] " + $m) }
      }

      switch($Action){
        'download' {
          if($app.Method -in @('download','portable')){ Invoke-DownloadStep -Ctx $ctx | Out-Null }
        }
        'install' {
          if($app.Method -eq 'winget'){ Invoke-WingetInstall -Ctx $ctx | Out-Null }
          elseif($app.Method -eq 'choco'){ Invoke-ChocoInstall -Ctx $ctx | Out-Null }
          else {
            # download/portable
            Invoke-DownloadStep -Ctx $ctx | Out-Null
            if($app.Method -eq 'download'){ Invoke-DirectInstaller -Ctx $ctx | Out-Null }
            if($app.Method -eq 'portable'){ Invoke-PortableStep -Ctx $ctx | Out-Null }
          }
        }
        'update' {
          if($app.Method -eq 'winget'){ Invoke-WingetUpdate -Ctx $ctx | Out-Null }
          elseif($app.Method -eq 'choco'){ Invoke-ChocoUpdate -Ctx $ctx | Out-Null }
        }
        'uninstall' {
          if($app.Method -eq 'winget'){ Invoke-WingetUninstall -Ctx $ctx | Out-Null }
          elseif($app.Method -eq 'choco'){ Invoke-ChocoUninstall -Ctx $ctx | Out-Null }
        }
        'scanupdates' {
          # no-op per app
        }
        Default {
          # If no action specified, just print summary
          Write-Host ("- " + $app.Name + " (" + $app.Method + ") installed=" + $app.IsInstalled)
        }
      }
    }

    if($Action -eq 'scanupdates'){
      Write-Host "[47Project] Scanning available updates (winget/choco)..." -ForegroundColor Cyan
      if(Get-Command winget -EA SilentlyContinue){ & winget upgrade --disable-interactivity }
      if(Get-Command choco -EA SilentlyContinue){ & choco outdated -r }
    }
  } catch {
    Write-Host "[47Project] Headless error: $($_.Exception.Message)" -ForegroundColor Red
  }
  return
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="47Project AppS Crawler (v1_56)" Height="820" Width="1360" MinWidth="1200" MinHeight="760"
        WindowStartupLocation="CenterScreen" Background="#070A07" Foreground="#00FF7F"
        FontFamily="Consolas">
  <Window.Resources>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#D6FFE6"/>
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Margin" Value="8,2"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    
      <Style.Triggers>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Foreground" Value="#69C98C"/>
          <Setter Property="Opacity" Value="0.75"/>
        </Trigger>
      </Style.Triggers>
    </Style>

<Style TargetType="Button">
      <Setter Property="Background" Value="#0B120B"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="Margin" Value="4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#102810"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="CaretBrush" Value="#00FF7F"/>
    </Style>

    <Style x:Key="MatrixComboBox" TargetType="ComboBox">
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="6,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border CornerRadius="4" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                <DockPanel>
                  <ToggleButton x:Name="ToggleButton" DockPanel.Dock="Right" Width="20" Background="Transparent" BorderThickness="0"
                                IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                    <Path Fill="#00FF7F" Data="M 0 0 L 4 4 L 8 0 Z" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </ToggleButton>
                  <ContentPresenter Margin="6,1,2,1" VerticalAlignment="Center" Content="{TemplateBinding SelectionBoxItem}"
                                    TextElement.Foreground="{TemplateBinding Foreground}"/>
                </DockPanel>
              </Border>

              <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False"
                     PlacementTarget="{Binding RelativeSource={RelativeSource TemplatedParent}}">
                <Border Background="#050A05" BorderBrush="#00FF7F" BorderThickness="1" CornerRadius="4">
                  <ScrollViewer CanContentScroll="True" MaxHeight="260">
                    <Border Background="#050A05">
                      <ItemsPresenter/>
                    </Border>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ComboBoxItem">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="Padding" Value="6,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter Property="Background" Value="#103010"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Background" Value="#154015"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="RowBackground" Value="#050A05"/>
      <Setter Property="AlternatingRowBackground" Value="#070E07"/>
      <Setter Property="GridLinesVisibility" Value="None"/>
      <Setter Property="AutoGenerateColumns" Value="False"/>
      <Setter Property="CanUserAddRows" Value="False"/>
      <Setter Property="IsReadOnly" Value="False"/>
      <Setter Property="SelectionMode" Value="Single"/>
      <Setter Property="EnableRowVirtualization" Value="True"/>
      <Setter Property="EnableColumnVirtualization" Value="True"/>
      <Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/>
      <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
    </Style>

    <!-- DataGrid headers: force Matrix dark theme (prevents white header strip) -->
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#0B120B"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/>
    </Style>

    <!-- Cells: keep consistent dark background, remove default white focus visuals -->
    <Style TargetType="DataGridCell">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="6,2"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#103010"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Tabs: dark Matrix look (prevents white tab header background) -->
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="#050A05"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
    </Style>

    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#00FF7F"/>
      <Setter Property="Background" Value="#0B120B"/>
      <Setter Property="BorderBrush" Value="#00FF7F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,5"/>
      <Setter Property="MinWidth" Value="78"/>
      <Setter Property="Margin" Value="6,0,6,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6,6,0,0">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Background" Value="#102810"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#0F250F"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  
    <!-- Dark Matrix ScrollBars -->
    <Style TargetType="{x:Type Thumb}">
      <Setter Property="Height" Value="20"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type Thumb}">
            <Border Background="#0D2A12" BorderBrush="#00FF7F" BorderThickness="1" CornerRadius="4"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="{x:Type ScrollBar}">
      <Setter Property="Background" Value="#071007"/>
      <Setter Property="Width" Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ScrollBar}">
            <Grid Background="{TemplateBinding Background}">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.LineUpCommand" Opacity="0" IsTabStop="False"/>
                </Track.DecreaseRepeatButton>
                <Track.Thumb>
                  <Thumb/>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.LineDownCommand" Opacity="0" IsTabStop="False"/>
                </Track.IncreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
</Window.Resources>

  <Grid>
  <Canvas x:Name="MatrixCanvasBG" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" IsHitTestVisible="False" Opacity="0.55" Panel.ZIndex="0"/>
  <Grid Margin="10" Panel.ZIndex="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Grid Grid.Row="0" Margin="0,0,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <StackPanel Orientation="Vertical">
        <TextBlock x:Name="HdrTitle" FontSize="22" FontWeight="Bold" Text="47 - AppS - Crawler"/>
        <TextBlock x:Name="HdrSub" FontSize="12" Opacity="0.9" Text="Select apps -> download / winget / choco -> install/update/uninstall (suite)"/>
        <TextBlock x:Name="HdrNotice" FontSize="11" Opacity="0.85" TextWrapping="Wrap"
                   Text="Copyright (c) 2025 47Project &amp; More&#10;License: MIT (keep this notice for credit)&#10;Third-party apps are owned by their publishers"/>
      </StackPanel>

      <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
        <Button x:Name="Btn47Project" Content="47Project" />
        <Button x:Name="BtnSelfUpdate" Content="Check for updates" />
        <Button x:Name="BtnEnterpriseTop" Content="Enterprise &amp; Labs/IT" MinWidth="240" Padding="10,3" Margin="6,0,0,0" ToolTip="Labs/IT: inventory, compliance, policy, repo, headless, signing" />
        <Button x:Name="BtnHelp" Content="Help" />
      </StackPanel>
    </Grid>

    <!-- Controls row -->
    <Grid Grid.Row="1" Margin="0,0,0,8">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="2*"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <!-- Search with clear -->
      <Grid Grid.Column="0" Margin="0,0,8,0">
        <TextBox x:Name="TxtSearch" Height="30" />
        <TextBlock x:Name="TxtSearchHint" Margin="10,0,30,0" VerticalAlignment="Center" Opacity="0.45" IsHitTestVisible="False" Text="Search apps..."/>
        <Button x:Name="BtnClearSearch" Content="X" Width="24" Height="24" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,4,0"/>
      </Grid>

      <ComboBox x:Name="CmbCategory" Grid.Column="1" Width="140" Height="30" Style="{StaticResource MatrixComboBox}" Margin="0,0,8,0"/>
      <ComboBox x:Name="CmbSort" Grid.Column="2" Width="150" Height="30" Style="{StaticResource MatrixComboBox}" Margin="0,0,8,0"/>
      <ComboBox x:Name="CmbProfile" Grid.Column="3" Width="170" Height="30" Style="{StaticResource MatrixComboBox}" Margin="0,0,8,0"/>
      <Button x:Name="BtnScan" Grid.Column="4" Content="Scan" Height="30" Margin="0,0,8,0"/>
      <CheckBox x:Name="ChkCompact" Grid.Column="5" Content="Compact mode" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <CheckBox x:Name="ChkSafeMode" Grid.Column="6" Content="Safe mode" VerticalAlignment="Center" Margin="0,0,8,0"/>
      <Button x:Name="BtnResetUI" Grid.Column="7" Content="Reset UI" Height="30"/>

    </Grid>

    <!-- Main content -->
    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="3*"/>
        <ColumnDefinition Width="2*"/>
      </Grid.ColumnDefinitions>

      <Grid Grid.Column="0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>


        <!-- Filter + Options (grouped for readability) -->
        <Grid Grid.Row="0" Margin="0,0,0,6">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="3*"/>
            <ColumnDefinition Width="2*"/>
          </Grid.ColumnDefinitions>

          <GroupBox Grid.Column="0" Header="Filters" Margin="0,0,8,0" BorderBrush="#00FF7F" Foreground="#00FF7F">
            <Border Background="#071007" CornerRadius="8" Padding="8">
              <WrapPanel>
                <CheckBox x:Name="ChkIncludeInstalled" Content="Include installed (reinstall/update)" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkInstalledOnly" Content="Installed only" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkMissingOnly" Content="Missing only" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkSelectedOnly" Content="Selected only" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkFavoritesOnly" Content="Favorites only" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkPortableOnly" Content="Portable only" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkUpdateableOnly" Content="Updateable only" Margin="0,0,12,6"/>
              </WrapPanel>
            </Border>
          </GroupBox>

          <GroupBox Grid.Column="1" Header="Run options" BorderBrush="#00FF7F" Foreground="#00FF7F">
            <Border Background="#071007" CornerRadius="8" Padding="8">
              <WrapPanel>
                <CheckBox x:Name="ChkDryRun" Content="Dry run" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkOnlyUpdateInstalled" Content="Only update if installed" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkContinueOnErrors" Content="Continue on errors" Margin="0,0,12,6"/>
                <CheckBox x:Name="ChkSkipAdmin" Content="Skip admin-needed (best effort)" Margin="0,0,12,6"/>
                <TextBlock x:Name="TxtStats" Margin="12,2,0,0" VerticalAlignment="Center" FontSize="12" TextTrimming="None" TextWrapping="NoWrap"/>
              </WrapPanel>
            </Border>
          </GroupBox>
        </Grid>

        <DataGrid x:Name="GridApps" Grid.Row="1" Margin="0,0,0,6" HeadersVisibility="Column" SelectionUnit="FullRow">
          <DataGrid.RowStyle>
            <Style TargetType="DataGridRow">
              <Setter Property="ToolTip" Value="{Binding StatusTip}"/>
            </Style>
          </DataGrid.RowStyle>
          <DataGrid.Columns>
            <DataGridTemplateColumn Header="Sel" Width="45">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <CheckBox Tag="Select" IsChecked="{Binding IsSelected, Mode=TwoWay}" IsEnabled="{Binding IsSelectable}" HorizontalAlignment="Center"/>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>

            <DataGridTemplateColumn Header="Fav" Width="45">
              <DataGridTemplateColumn.CellTemplate>
                <DataTemplate>
                  <CheckBox Tag="Fav" IsChecked="{Binding IsFavorite, Mode=TwoWay}" HorizontalAlignment="Center"/>
                </DataTemplate>
              </DataGridTemplateColumn.CellTemplate>
            </DataGridTemplateColumn>

            <DataGridTextColumn Header="Name" Width="*" Binding="{Binding Name}"/>
            <DataGridTextColumn Header="Category" Width="110" Binding="{Binding Category}"/>
            <DataGridTextColumn Header="Method" Width="85" Binding="{Binding Method}"/>
            <DataGridTextColumn Header="Installed" Width="75" Binding="{Binding IsInstalled}"/>
            <DataGridTextColumn Header="Notes" Width="260" Binding="{Binding Notes}"/>
          </DataGrid.Columns>
        </DataGrid>

        <!-- Quick actions (left pane) -->
        <Border Grid.Row="2" Background="#071007" CornerRadius="8" BorderBrush="#00FF7F" BorderThickness="1" Padding="6">
          <WrapPanel>
            <Button x:Name="BtnSelectVisible" Content="Select visible"/>
            <Button x:Name="BtnSelectMissing" Content="Select missing"/>
            <Button x:Name="BtnInvertVisible" Content="Invert visible"/>
            <Button x:Name="BtnClearVisible" Content="Clear visible"/>
            <Button x:Name="BtnExportSelected" Content="Export selected"/>
            <Button x:Name="BtnCopySelected" Content="Copy selected"/>
            <Button x:Name="BtnOpenLogs" Content="Open logs"/>
            <Button x:Name="BtnValidateCatalog" Content="Validate catalog"/>
          </WrapPanel>
        </Border>

      </Grid>

      <!-- Right side: tabs -->
      <TabControl Grid.Column="1" Background="#050A05" BorderBrush="#00FF7F" BorderThickness="1" Padding="6">
        <TabItem Header="Suite">
          <Grid Margin="4">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <WrapPanel Grid.Row="0">
              <Button x:Name="BtnPreflight" Content="Readiness check"/>
              <CheckBox x:Name="ChkParallelDl" Content="Parallel downloads" Margin="12,0,0,0" VerticalAlignment="Center"/>
              <TextBlock Text="Concurrency" Margin="10,0,4,0" VerticalAlignment="Center" Opacity="0.8"/>
              <ComboBox x:Name="CmbConcurrency" Width="60" Height="26" Style="{StaticResource MatrixComboBox}"/>
            </WrapPanel>

            <Grid Grid.Row="1" Margin="0,4,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>

              <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,10,0">
                <TextBlock Text="Install mode:" VerticalAlignment="Center" Opacity="0.8"/>
                <ComboBox x:Name="CmbInstallMode" Width="140" Height="28" Style="{StaticResource MatrixComboBox}" Margin="8,0,0,0"/>
              </StackPanel>

              
              
<Grid Grid.Column="1" Margin="6,0,0,0">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*"/>
  </Grid.RowDefinitions>

  <WrapPanel Grid.Row="0" Margin="0,0,0,6">
    <CheckBox x:Name="ChkCreateRestorePoint" Content="Create restore point before run (optional)" Margin="0,0,12,0"/>
    <CheckBox x:Name="ChkCreateShortcuts" Content="Create Start Menu shortcuts for portable apps (optional)" Margin="0,0,12,0"/>
    <CheckBox x:Name="ChkLaunchAfterInstall" Content="Launch apps after install (optional)" Margin="0,0,12,0"/>
  </WrapPanel>

  <TabControl x:Name="MainTabs" Grid.Row="1" Background="#050A05" BorderBrush="#00FF7F" BorderThickness="1" Padding="6">
    <TabItem Header="Install / Download">
<Grid Margin="4">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
  </Grid.RowDefinitions>

  <UniformGrid Grid.Row="0" Columns="2" Margin="0,0,0,6">
    <Button x:Name="BtnDownload" Height="34" Margin="4">
      <TextBlock Text="Download Selected" TextAlignment="Center"/>
    </Button>
    <Button x:Name="BtnInstall" Height="34" Margin="4">
      <TextBlock Text="Install Selected" TextAlignment="Center"/>
    </Button>
  </UniformGrid>

  <TextBlock Grid.Row="1" Margin="4,2,4,0" Opacity="0.85" TextWrapping="Wrap"
             Text="Auto mode attempts silent install when known; otherwise it falls back to interactive."/>
</Grid>
    </TabItem>

    <TabItem Header="Update">
  <Grid Margin="4">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Button x:Name="BtnUpdate" Grid.Row="0" Height="34" Margin="4">
      <TextBlock Text="Update Selected" TextAlignment="Center"/>
    </Button>

    <Button x:Name="BtnUpdateAllInstalled" Grid.Row="1" Height="34" Margin="4">
      <TextBlock Text="Update All Installed (Catalog)" TextWrapping="Wrap" TextAlignment="Center"/>
    </Button>

    <WrapPanel Grid.Row="2" Margin="4,6,4,6">
      <Button x:Name="BtnScanUpdates" Content="Scan available updates" Height="30" Margin="0,0,10,0"/>
      <Button x:Name="BtnUpdateAllAvailable" Content="Update All Available (Scan)" Height="30" Margin="0,0,10,0"/>
      <Button x:Name="BtnExportUpdateReport" Content="Export update report" Height="30" Margin="0,0,10,0"/>
      <Button x:Name="BtnPreviewUpdateCommands" Content="Preview update commands (Dry run)" Height="30"/>
      <CheckBox x:Name="ChkUpdatesAvailableOnly" Content="Show updates only" Margin="12,4,0,0"/>
    </WrapPanel>

    <ListBox x:Name="LstUpdates" Grid.Row="3" Background="#050A05" Foreground="#00FF7F" BorderBrush="#00FF7F" Margin="4"/>

    <TextBlock Grid.Row="4" Opacity="0.85" TextWrapping="Wrap" Margin="4,6,4,0"
               Text="Scan is optional and runs in the background. Updates use winget/choco when available."/>
  </Grid>
</TabItem>

    <TabItem Header="Uninstall">
      <Grid Margin="4">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <UniformGrid Grid.Row="0" Columns="2" Margin="0,0,0,6">
          <Button x:Name="BtnUninstall" Content="Uninstall Selected (Managed)"/>
          <Button x:Name="BtnUninstallAll" Content="Uninstall All Installed (Catalog, Managed)"/>
        </UniformGrid>

        <Border Grid.Row="1" CornerRadius="6" BorderThickness="1" BorderBrush="#00FF7F" Background="#060A07" Padding="8" Margin="0,2,0,6">
          <TextBlock Opacity="0.90" TextWrapping="Wrap" Foreground="#FFCC66"
                     Text="Warning: Uninstall is supported only for winget/choco-managed apps. Direct downloads may not uninstall safely."/>
        </Border>
      </Grid>
    </TabItem>

    <TabItem Header="Tools">
      <Grid Margin="4">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <GroupBox Header="Policy / Inventory" Grid.Row="0" Margin="0,0,0,8">
          <StackPanel Margin="8">
            <UniformGrid Columns="2" Margin="0,0,0,6">
              <Button x:Name="BtnExportInventoryCsv" Content="Export inventory CSV"/>
              <Button x:Name="BtnExportPolicy" Content="Export policy JSON"/>
            </UniformGrid>
            <UniformGrid Columns="2">
              <Button x:Name="BtnImportPolicy" Content="Import policy JSON"/>
              <Button x:Name="BtnDiagnostics" Content="Diagnostics bundle"/>
            </UniformGrid>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Downloads" Grid.Row="1" Margin="0,0,0,8">
          <StackPanel Margin="8">
            <UniformGrid Columns="2" Margin="0,0,0,6">
              <Button x:Name="BtnOpenDownloadsFolder" Content="Open downloads folder"/>
              <Button x:Name="BtnVerifyDownloads" Content="Verify downloads (hash)"/>
            </UniformGrid>
            <UniformGrid Columns="2" Margin="0,0,0,6">
              <Button x:Name="BtnClearDownloadsSelected" Content="Clear downloads (selected)"/>
              <Button x:Name="BtnClearDownloadsAll" Content="Clear downloads (all)"/>
            </UniformGrid>
            <UniformGrid Columns="2">
              <Button x:Name="BtnRedownloadCorrupted" Content="Re-download corrupted"/>
              <CheckBox x:Name="ChkDownloadByCategory" Content="Store downloads by category/app folders"/>
            </UniformGrid>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Suite" Grid.Row="2">
          <StackPanel Margin="8">
            <UniformGrid Columns="2" Margin="0,0,0,6">
              <Button x:Name="BtnInstallChocoNow" Content="Install Chocolatey"/>
              <Button x:Name="BtnOpenExportsFolder" Content="Open exports folder"/>
            </UniformGrid>
            <Button x:Name="BtnEnterpriseCenter" Visibility="Collapsed" Content="ENTERPRISE Center (Labs/IT)" FontWeight="Bold" Foreground="#FFCC66" Background="#0B120B" BorderBrush="#FFCC66" BorderThickness="1" Padding="10,6" ToolTip="Labs/IT: Policy lock, inventory, compliance, mirrors, headless, signing"/></StackPanel>
        </GroupBox>
      </Grid>
    </TabItem>

  </TabControl>
</Grid>
</Grid>

            <TextBlock Grid.Row="3" x:Name="TxtStatus" Text="Ready." Opacity="0.9" Margin="4,8,4,6"/>

            <GroupBox Grid.Row="4" Header="Actions Preview / Queue" BorderBrush="#00FF7F" Foreground="#00FF7F">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="*"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <ListBox x:Name="LstPreview" Grid.Row="0" Background="#050A05" Foreground="#00FF7F" BorderBrush="#00FF7F"/>
                <ProgressBar x:Name="Prg" Grid.Row="1" Height="16" Margin="4" Minimum="0" Maximum="100"/>
              </Grid>
            </GroupBox>
          </Grid>
        </TabItem>

        
<TabItem Header="Details">
  <ScrollViewer VerticalScrollBarVisibility="Auto">
    <StackPanel Margin="10" >
      <TextBlock Text="Selected app details" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>

      <Border Background="#071007" CornerRadius="8" BorderBrush="#00FF7F" BorderThickness="1" Padding="8" Margin="0,0,0,10">
        <StackPanel>
          <TextBlock x:Name="DetName" FontSize="13" FontWeight="SemiBold"/>
          <TextBlock x:Name="DetCat" Margin="0,4,0,0"/>
          <TextBlock x:Name="DetMethod" Margin="0,2,0,0"/>
          <TextBlock x:Name="DetIds" Margin="0,2,0,0"/>
          <TextBlock x:Name="DetUrl" TextWrapping="Wrap" Margin="0,6,0,0"/>
          <TextBlock x:Name="DetBadges" TextWrapping="Wrap" Margin="0,8,0,0"/>
          <TextBlock x:Name="DetWarn" TextWrapping="Wrap" Foreground="#FFCC66" Margin="0,8,0,0"/>
        </StackPanel>
      </Border>

      <GroupBox Header="Profile tags &amp; overrides" BorderBrush="#00FF7F" Foreground="#D6FFE6" Margin="0,0,0,10">
        <Border Background="#071007" CornerRadius="8" Padding="8">
          <StackPanel>
            <TextBlock Text="Tags (used by auto profiles):" Opacity="0.85" Margin="0,0,0,6"/>
            <WrapPanel x:Name="WrapTags" Margin="0,0,0,10">
              <CheckBox x:Name="TagMinimal" Content="Minimal"/>
              <CheckBox x:Name="TagGaming" Content="Gaming"/>
              <CheckBox x:Name="TagOffice" Content="Office"/>
              <CheckBox x:Name="TagDev" Content="Dev"/>
              <CheckBox x:Name="TagCreator" Content="Creator"/>
              <CheckBox x:Name="TagSysadmin" Content="Sysadmin"/>
              <CheckBox x:Name="TagPortable" Content="Portable"/>
            </WrapPanel>

            <WrapPanel Margin="0,0,0,10">
              <TextBlock Text="Preferred method:" VerticalAlignment="Center" Opacity="0.85" Margin="0,0,8,0"/>
              <ComboBox x:Name="CmbPreferredMethod" Width="170" Height="28" Style="{StaticResource MatrixComboBox}" Margin="0,0,12,0"/>
              <CheckBox x:Name="ChkSkipApp" Content="Skip always (blacklist)" VerticalAlignment="Center"/>
              <CheckBox x:Name="ChkExcludeUpdate" Content="Exclude from auto-update" VerticalAlignment="Center" Margin="12,0,0,0"/>
            </WrapPanel>

            <TextBlock Text="Note (saved in profiles/policy):" Opacity="0.85"/>
            <TextBox x:Name="TxtAppNote" Height="70" AcceptsReturn="True" TextWrapping="Wrap" Margin="0,6,0,10"/>

            <WrapPanel>
              <Button x:Name="BtnApplyTagsToSelected" Content="Apply tags to selected"/>
              <Button x:Name="BtnSaveAppOverrides" Content="Save overrides"/>
            </WrapPanel>
          </StackPanel>
        </Border>
      </GroupBox>

      <WrapPanel>
        <Button x:Name="BtnCopyName" Content="Copy name"/>
        <Button x:Name="BtnCopyId" Content="Copy id"/>
        <Button x:Name="BtnCopyUrl" Content="Copy url"/>
        <Button x:Name="BtnOpenInstallFolder" Content="Open install folder"/>
      </WrapPanel>
    </StackPanel>
  </ScrollViewer>
</TabItem>


<TabItem Header="Profiles">
  <ScrollViewer VerticalScrollBarVisibility="Auto">
    <StackPanel Margin="10">
      <TextBlock Text="Profiles" FontWeight="Bold" FontSize="14" Margin="0,0,0,10"/>

      <GroupBox Header="Auto profiles" Margin="0,0,0,10" BorderBrush="#00FF7F" Foreground="#D6FFE6">
        <Border Background="#071007" CornerRadius="8" Padding="10">
          <StackPanel>
            <WrapPanel Margin="0,0,0,8">
              <ComboBox x:Name="CmbAutoProfile" Width="190" Height="30" Style="{StaticResource MatrixComboBox}" Margin="0,0,10,0"/>
              <Button x:Name="BtnApplyAutoProfile" Content="Apply" Height="30" Margin="0,0,14,0"/>
              <CheckBox x:Name="ChkProfileClearFirst" Content="Clear first" Margin="0,0,14,0"/>
              <CheckBox x:Name="ChkProfileOnlyMissing" Content="Only missing" Margin="0,0,14,0"/>
            </WrapPanel>

            <WrapPanel Margin="0,0,0,8">
              <Button x:Name="BtnSelectRecommendedMissing" Content="Select recommended missing" Height="30" Margin="0,0,10,0"/>
              <Button x:Name="BtnSmartRecommend" Content="Smart recommend for this PC" Height="30"/>
            </WrapPanel>

            <TextBlock x:Name="TxtAutoProfileDesc" TextWrapping="Wrap" Opacity="0.9"/>
          </StackPanel>
        </Border>
      </GroupBox>

      <GroupBox Header="Custom profiles" Margin="0,0,0,10" BorderBrush="#00FF7F" Foreground="#D6FFE6">
        <Border Background="#071007" CornerRadius="8" Padding="10">
          <StackPanel>
            <WrapPanel Margin="0,0,0,8">
              <Button x:Name="BtnSaveProfile" Content="Save profile" Margin="0,0,8,0"/>
              <Button x:Name="BtnLoadProfile" Content="Load profile" Margin="0,0,8,0"/>
              <Button x:Name="BtnOverwriteProfile" Content="Overwrite profile" Margin="0,0,8,0"/>
              <Button x:Name="BtnDeleteProfile" Content="Delete profile" Margin="0,0,8,0"/>
              <Button x:Name="BtnOpenProfiles" Content="Open profiles folder"/>
            </WrapPanel>

            <WrapPanel Margin="0,0,0,8">
              <Button x:Name="BtnCompareProfiles" Content="Compare/Merge" Margin="0,0,8,0"/>
              <Button x:Name="BtnSnapshotSave" Content="Save snapshot" Margin="0,0,8,0"/>
              <Button x:Name="BtnSnapshotLoad" Content="Load snapshot"/>
            </WrapPanel>

            <TextBlock x:Name="TxtProfileInfo" TextWrapping="Wrap" Opacity="0.9"/>
          </StackPanel>
        </Border>
      </GroupBox>

      <GroupBox Header="Profile editor (quick)" BorderBrush="#00FF7F" Foreground="#D6FFE6">
        <Border Background="#071007" CornerRadius="8" Padding="10">
          <StackPanel>
            <TextBlock TextWrapping="Wrap" Opacity="0.85" Text="Tip: Use the Details tab to tag apps (Gaming/Office/Dev/etc.) and set per-app overrides. Those tags drive auto profiles."/>
          </StackPanel>
        </Border>
      </GroupBox>

    </StackPanel>
  </ScrollViewer>
</TabItem>

<TabItem Header="Share">

          <StackPanel Margin="6">
            <TextBlock Text="Share Profile" FontWeight="Bold" FontSize="14"/>
            <WrapPanel Margin="0,8,0,0">
              <Button x:Name="BtnShare" Content="Generate token + QR"/>
              <Button x:Name="BtnOpenProfileFile" Content="Open current profile file"/>
            </WrapPanel>

            <TextBlock Text="Share token:" Margin="0,10,0,0" Opacity="0.9"/>
            <TextBox x:Name="TxtShareToken" Height="70" TextWrapping="Wrap" AcceptsReturn="True" IsReadOnly="True"/>

            <TextBlock Text="cutur.link placeholder (future):" Margin="0,8,0,0" Opacity="0.9"/>
            <TextBox x:Name="TxtShareUrl" Height="30" IsReadOnly="True"/>

            <Image x:Name="ImgQR" Height="220" Width="220" Margin="0,10,0,0"/>

            <WrapPanel>
              <Button x:Name="BtnCopyToken" Content="Copy token"/>
              <Button x:Name="BtnCopyLink" Content="Copy link"/>
              <Button x:Name="BtnSaveSharePayload" Content="Save share payload"/>
              <Button x:Name="BtnOpenProfiles2" Content="Open profiles folder"/>
            </WrapPanel>

            <TextBlock Text="QR generation may require internet in this build." Opacity="0.7" Margin="0,8,0,0"/>
          </StackPanel>
        </TabItem>

        <TabItem Header="Pack">
          <StackPanel Margin="6">
            <TextBlock Text="USB / Offline Pack" FontWeight="Bold" FontSize="14"/>
            <TextBlock TextWrapping="Wrap" Opacity="0.85" Margin="0,6,0,10"
                       Text="Export pack copies downloads + profile/policy to a folder (USB). Import loads profiles and can point downloads to the pack folder."/>
            <WrapPanel>
              <Button x:Name="BtnExportPack" Content="Export pack"/>
              <Button x:Name="BtnImportPack" Content="Import pack"/>
              <Button x:Name="BtnExportOfflineManifest" Content="Export offline manifest"/>
            </WrapPanel>
          </StackPanel>
        </TabItem>

        
        <TabItem Header="Catalog">
          <StackPanel Margin="10">
            <TextBlock Text="Catalog Manager" FontWeight="Bold" FontSize="14" Margin="0,0,0,8"/>
            <TextBlock TextWrapping="Wrap" Opacity="0.85" Text="Manage catalog sources (embedded + catalog.d JSON files). You can disable a source, export a merged catalog, or open the folder."/>
            <ListBox x:Name="LstCatalogSources" Height="240" Margin="0,8,0,8" Background="#050A05" Foreground="#D6FFE6" BorderBrush="#00FF7F"/>
            <WrapPanel>
              <Button x:Name="BtnCatalogRefresh" Content="Refresh sources"/>
              <Button x:Name="BtnCatalogOpenFolder" Content="Open catalog.d folder"/>
              <Button x:Name="BtnCatalogExportMerged" Content="Export merged catalog.json"/>
              <Button x:Name="BtnCatalogFixDupes" Content="Fix duplicates (safe)"/>
              <Button x:Name="BtnCatalogOnlineUpdate" Content="Check online catalog update"/>
            </WrapPanel>
            <TextBlock x:Name="TxtCatalogInfo" Margin="0,10,0,0" TextWrapping="Wrap" Opacity="0.9"/>
          </StackPanel>
        </TabItem>

        <TabItem Header="History">
          <StackPanel Margin="10">
            <TextBlock Text="Run History" FontWeight="Bold" FontSize="14" Margin="0,0,0,8"/>
            <ListBox x:Name="LstHistory" Height="360" Background="#050A05" Foreground="#D6FFE6" BorderBrush="#00FF7F"/>
            <WrapPanel Margin="0,8,0,0">
              <Button x:Name="BtnOpenHistoryReport" Content="Open selected report"/>
              <Button x:Name="BtnOpenHistoryFolder" Content="Open history folder"/>
            </WrapPanel>
            <TextBlock x:Name="TxtHistoryInfo" Margin="0,10,0,0" Opacity="0.9" TextWrapping="Wrap"/>
          </StackPanel>
        </TabItem>

        <TabItem Header="Policy">
          <StackPanel Margin="10">
            <TextBlock Text="Policy / Deployment" FontWeight="Bold" FontSize="14" Margin="0,0,0,8"/>
            <TextBlock TextWrapping="Wrap" Opacity="0.85" Text="Policy exports preferred methods, pinned versions (if any), skip list, and per-app notes. Useful for multi-machine deployments."/>
            <WrapPanel Margin="0,8,0,8">
              <Button x:Name="BtnExportPolicy2" Content="Export policy JSON"/>
              <Button x:Name="BtnImportPolicy2" Content="Import policy JSON"/>
              <Button x:Name="BtnExportPackScript" Content="Export runnable pack script"/>
            </WrapPanel>
            <TextBox x:Name="TxtPolicyPreview" Height="380" AcceptsReturn="True" TextWrapping="Wrap" IsReadOnly="True" VerticalScrollBarVisibility="Auto"/>
          </StackPanel>
        </TabItem>

<TabItem Header="Logs">
          <StackPanel Margin="6">
            <TextBlock Text="Live log (tail)" FontWeight="Bold" FontSize="14"/>
            <TextBox x:Name="TxtLog" Height="520" AcceptsReturn="True" TextWrapping="Wrap" IsReadOnly="True" VerticalScrollBarVisibility="Auto"/>
            <WrapPanel>
              <Button x:Name="BtnCopyLog" Content="Copy log"/>
              <Button x:Name="BtnDiagBundle" Content="Diagnostics bundle"/>
              <Button x:Name="BtnSchedTask" Content="Create weekly update task"/>
              <Button x:Name="BtnRemoveTask" Content="Remove update task"/>
            </WrapPanel>
          </StackPanel>
        </TabItem>

        <TabItem Header="About">
          <StackPanel Margin="6">
            <TextBlock Text="About" FontWeight="Bold" FontSize="14"/>
            <TextBlock x:Name="TxtAbout" TextWrapping="Wrap" Margin="0,8,0,0" Opacity="0.9"/>
            <TextBlock Text="Changelog (optional):" Margin="0,10,0,0" Opacity="0.8"/>
            <TextBox x:Name="TxtChangelog" Height="340" AcceptsReturn="True" TextWrapping="Wrap" IsReadOnly="True" VerticalScrollBarVisibility="Auto"/>
          </StackPanel>
        </TabItem>

      </TabControl>

    </Grid>

    <!-- Footer -->
    <Grid Grid.Row="3" Margin="0,10,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="Footer" Grid.Column="0" Opacity="0.85" />
      <TextBlock x:Name="FooterBadges" Grid.Column="1" Opacity="0.85" />
    </Grid>
  </Grid>
  <Canvas x:Name="MatrixCanvasFG" HorizontalAlignment="Stretch" VerticalAlignment="Stretch" IsHitTestVisible="False" Opacity="0.75" Panel.ZIndex="99999"/>
</Grid>
</Window>
"@

# -----------------------
# Build UI, wire logic
# -----------------------
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Find controls
$find = { param($n) $window.FindName($n) }
$HdrTitle = & $find 'HdrTitle'
$HdrSub   = & $find 'HdrSub'
$HdrNotice = & $find 'HdrNotice'
$Btn47Project = & $find 'Btn47Project'
$BtnSelfUpdate = & $find 'BtnSelfUpdate'
$BtnHelp = & $find 'BtnHelp'


$BtnEnterpriseTop = & $find 'BtnEnterpriseTop'
$MainTabs = & $find 'MainTabs'
$TxtSearch = & $find 'TxtSearch'
$TxtSearchHint = & $find 'TxtSearchHint'
$BtnClearSearch = & $find 'BtnClearSearch'
$CmbCategory = & $find 'CmbCategory'
$CmbSort = & $find 'CmbSort'
$CmbProfile = & $find 'CmbProfile'
$BtnScan = & $find 'BtnScan'
$ChkCompact = & $find 'ChkCompact'
$ChkSafeMode = & $find 'ChkSafeMode'
$BtnResetUI = & $find 'BtnResetUI'

$ChkIncludeInstalled = & $find 'ChkIncludeInstalled'
$ChkInstalledOnly = & $find 'ChkInstalledOnly'
$ChkMissingOnly = & $find 'ChkMissingOnly'
$ChkSelectedOnly = & $find 'ChkSelectedOnly'
$ChkFavoritesOnly = & $find 'ChkFavoritesOnly'
$ChkPortableOnly = & $find 'ChkPortableOnly'
$ChkUpdateableOnly = & $find 'ChkUpdateableOnly'

$ChkDryRun = & $find 'ChkDryRun'
$ChkOnlyUpdateInstalled = & $find 'ChkOnlyUpdateInstalled'
$ChkContinueOnErrors = & $find 'ChkContinueOnErrors'
$ChkSkipAdmin = & $find 'ChkSkipAdmin'

$TxtStats = & $find 'TxtStats'
$GridApps = & $find 'GridApps'

$BtnSelectVisible = & $find 'BtnSelectVisible'
$BtnSelectMissing = & $find 'BtnSelectMissing'
$BtnInvertVisible = & $find 'BtnInvertVisible'
$BtnClearVisible = & $find 'BtnClearVisible'
$BtnExportSelected = & $find 'BtnExportSelected'
$BtnCopySelected = & $find 'BtnCopySelected'
$BtnOpenLogs = & $find 'BtnOpenLogs'
$BtnValidateCatalog = & $find 'BtnValidateCatalog'

# Optional/new controls (safe find)
$ChkCreateRestorePoint = & $find 'ChkCreateRestorePoint'
$ChkCreateShortcuts    = & $find 'ChkCreateShortcuts'
$ChkLaunchAfterInstall = & $find 'ChkLaunchAfterInstall'
$BtnExportInventoryCsv = & $find 'BtnExportInventoryCsv'
$BtnExportPolicy       = & $find 'BtnExportPolicy'
$BtnImportPolicy       = & $find 'BtnImportPolicy'
$BtnDiagnostics        = & $find 'BtnDiagnostics'
$BtnInstallChocoNow     = & $find 'BtnInstallChocoNow'
$BtnOpenExportsFolder   = & $find 'BtnOpenExportsFolder'

$BtnEnterpriseCenter   = & $find 'BtnEnterpriseCenter'
$BtnOpenDownloadsFolder  = & $find 'BtnOpenDownloadsFolder'
$BtnVerifyDownloads      = & $find 'BtnVerifyDownloads'
$BtnClearDownloadsSelected = & $find 'BtnClearDownloadsSelected'
$BtnClearDownloadsAll    = & $find 'BtnClearDownloadsAll'
$BtnRedownloadCorrupted  = & $find 'BtnRedownloadCorrupted'
$ChkDownloadByCategory   = & $find 'ChkDownloadByCategory'
$BtnExportOfflineManifest = & $find 'BtnExportOfflineManifest'
# Details extras
$TagMinimal = & $find 'TagMinimal'
$TagGaming  = & $find 'TagGaming'
$TagOffice  = & $find 'TagOffice'
$TagDev     = & $find 'TagDev'
$TagCreator = & $find 'TagCreator'
$TagSysadmin= & $find 'TagSysadmin'
$TagPortable= & $find 'TagPortable'
$CmbPreferredMethod = & $find 'CmbPreferredMethod'
$ChkSkipApp         = & $find 'ChkSkipApp'
$ChkExcludeUpdate   = & $find 'ChkExcludeUpdate'
$TxtAppNote         = & $find 'TxtAppNote'
$BtnApplyTagsToSelected = & $find 'BtnApplyTagsToSelected'
$BtnSaveAppOverrides    = & $find 'BtnSaveAppOverrides'

# Profiles extras
$BtnSmartRecommend = & $find 'BtnSmartRecommend'

# Catalog tab
$LstCatalogSources = & $find 'LstCatalogSources'
$BtnCatalogRefresh = & $find 'BtnCatalogRefresh'
$BtnCatalogOpenFolder = & $find 'BtnCatalogOpenFolder'
$BtnCatalogExportMerged = & $find 'BtnCatalogExportMerged'
$BtnCatalogFixDupes = & $find 'BtnCatalogFixDupes'
$BtnCatalogOnlineUpdate = & $find 'BtnCatalogOnlineUpdate'
$TxtCatalogInfo = & $find 'TxtCatalogInfo'

# History tab
$LstHistory = & $find 'LstHistory'
$BtnOpenHistoryReport = & $find 'BtnOpenHistoryReport'
$BtnOpenHistoryFolder = & $find 'BtnOpenHistoryFolder'
$TxtHistoryInfo = & $find 'TxtHistoryInfo'

# Policy tab
$BtnExportPolicy2 = & $find 'BtnExportPolicy2'
$BtnImportPolicy2 = & $find 'BtnImportPolicy2'
$BtnExportPackScript = & $find 'BtnExportPackScript'
$TxtPolicyPreview = & $find 'TxtPolicyPreview'

# Suite tab
$BtnPreflight = & $find 'BtnPreflight'
$ChkParallelDl = & $find 'ChkParallelDl'
$CmbConcurrency = & $find 'CmbConcurrency'
$CmbInstallMode = & $find 'CmbInstallMode'
$BtnDownload = & $find 'BtnDownload'
$BtnInstall  = & $find 'BtnInstall'
$BtnUpdate   = & $find 'BtnUpdate'
$BtnUpdateAllInstalled = & $find 'BtnUpdateAllInstalled'
$BtnScanUpdates = & $find 'BtnScanUpdates'
$BtnUpdateAllAvailable = & $find 'BtnUpdateAllAvailable'
$BtnExportUpdateReport = & $find 'BtnExportUpdateReport'
$BtnPreviewUpdateCommands = & $find 'BtnPreviewUpdateCommands'
$ChkUpdatesAvailableOnly = & $find 'ChkUpdatesAvailableOnly'
$LstUpdates = & $find 'LstUpdates'
$BtnUninstall = & $find 'BtnUninstall'
$BtnUninstallAll = & $find 'BtnUninstallAll'
$TxtStatus = & $find 'TxtStatus'
$LstPreview = & $find 'LstPreview'
$Prg = & $find 'Prg'

# Details
$DetName = & $find 'DetName'
$DetCat  = & $find 'DetCat'
$DetMethod = & $find 'DetMethod'
$DetIds = & $find 'DetIds'
$DetUrl = & $find 'DetUrl'
$DetBadges = & $find 'DetBadges'
$DetWarn = & $find 'DetWarn'
$BtnCopyName = & $find 'BtnCopyName'
$BtnCopyId = & $find 'BtnCopyId'
$BtnCopyUrl = & $find 'BtnCopyUrl'
$BtnOpenInstallFolder = & $find 'BtnOpenInstallFolder'

# Profiles
$BtnSaveProfile = & $find 'BtnSaveProfile'
$BtnLoadProfile = & $find 'BtnLoadProfile'
$BtnOverwriteProfile = & $find 'BtnOverwriteProfile'
$BtnDeleteProfile = & $find 'BtnDeleteProfile'
$BtnOpenProfiles = & $find 'BtnOpenProfiles'
$TxtProfileInfo = & $find 'TxtProfileInfo'

$CmbAutoProfile = & $find 'CmbAutoProfile'
$BtnApplyAutoProfile = & $find 'BtnApplyAutoProfile'
$ChkProfileClearFirst = & $find 'ChkProfileClearFirst'
$ChkProfileOnlyMissing = & $find 'ChkProfileOnlyMissing'
$BtnSelectRecommendedMissing = & $find 'BtnSelectRecommendedMissing'
$TxtAutoProfileDesc = & $find 'TxtAutoProfileDesc'
$BtnCompareProfiles = & $find 'BtnCompareProfiles'
$BtnSnapshotSave = & $find 'BtnSnapshotSave'
$BtnSnapshotLoad = & $find 'BtnSnapshotLoad'

# Share
$BtnShare = & $find 'BtnShare'
$TxtShareToken = & $find 'TxtShareToken'
$TxtShareUrl = & $find 'TxtShareUrl'
$ImgQR = & $find 'ImgQR'
$BtnCopyToken = & $find 'BtnCopyToken'
$BtnCopyLink = & $find 'BtnCopyLink'
$BtnSaveSharePayload = & $find 'BtnSaveSharePayload'
$BtnOpenProfiles2 = & $find 'BtnOpenProfiles2'
$BtnOpenProfileFile = & $find 'BtnOpenProfileFile'

# Pack
$BtnExportPack = & $find 'BtnExportPack'
$BtnImportPack = & $find 'BtnImportPack'

# Logs
$TxtLog = & $find 'TxtLog'
$BtnCopyLog = & $find 'BtnCopyLog'
$BtnDiagBundle = & $find 'BtnDiagBundle'
$BtnSchedTask = & $find 'BtnSchedTask'
$BtnRemoveTask = & $find 'BtnRemoveTask'

# About
$TxtAbout = & $find 'TxtAbout'
$TxtChangelog = & $find 'TxtChangelog'

# Footer
$Footer = & $find 'Footer'
$FooterBadges = & $find 'FooterBadges'

# Apply localized text (ASCII-only)
$HdrTitle.Text = $L.Title
$HdrSub.Text = $L.SubTitle
$HdrNotice.Text = $L.Notice1 + "`n" + $L.Notice2 + "`n" + $L.Notice3
$TxtSearchHint.Text = $L.SearchPlaceholder

$Btn47Project.Content = '47Project'
$BtnSelfUpdate.Content = $L.BtnSelfUpdate
$BtnHelp.Content = $L.BtnHelp

$BtnScan.Content = $L.BtnScan
$ChkCompact.Content = $L.CompactMode
$ChkSafeMode.Content = $L.SafeMode
$BtnResetUI.Content = $L.BtnResetUI

$ChkIncludeInstalled.Content = $L.IncludeInstalled
$ChkInstalledOnly.Content = $L.InstalledOnly
$ChkMissingOnly.Content = $L.MissingOnly
$ChkSelectedOnly.Content = $L.SelectedOnly
$ChkFavoritesOnly.Content = $L.FavoritesOnly
$ChkPortableOnly.Content = $L.PortableOnly
$ChkUpdateableOnly.Content = $L.UpdateableOnly

$ChkDryRun.Content = $L.BtnDryRun
$ChkOnlyUpdateInstalled.Content = $L.OnlyUpdateIfInstalled
$ChkContinueOnErrors.Content = $L.ContinueOnErrors
$ChkSkipAdmin.Content = $L.SkipAdminNeeded

$BtnSelectVisible.Content = $L.BtnSelectVisible
$BtnSelectMissing.Content = $L.BtnSelectMissing
$BtnInvertVisible.Content = $L.BtnInvertVisible
$BtnClearVisible.Content = $L.BtnClearVisible
$BtnExportSelected.Content = $L.BtnExportSelected
$BtnCopySelected.Content = $L.BtnCopySelected
$BtnOpenLogs.Content = $L.BtnOpenLogs
$BtnValidateCatalog.Content = $L.BtnValidateCatalog

$BtnPreflight.Content = $L.BtnPreflight
$ChkParallelDl.Content = $L.ParallelDownloads
$BtnDownload.Content = $L.BtnDownload
$BtnInstall.Content = $L.BtnInstall
$BtnUpdate.Content  = $L.BtnUpdate
$BtnUpdateAllInstalled.Content = $L.BtnUpdateAllInstalled
$BtnUninstall.Content = $L.BtnUninstall
$BtnUninstallAll.Content = $L.BtnUninstallAll

$BtnSaveProfile.Content = $L.BtnSaveProfile
$BtnLoadProfile.Content = $L.BtnLoadProfile
$BtnOverwriteProfile.Content = $L.BtnOverwriteProfile
$BtnDeleteProfile.Content = $L.BtnDeleteProfile
$BtnOpenProfiles.Content = $L.BtnOpenProfiles

# Auto profiles UI text
if($null -ne $BtnApplyAutoProfile){ $BtnApplyAutoProfile.Content = $L.BtnApplyAutoProfile }
if($null -ne $ChkProfileClearFirst){ $ChkProfileClearFirst.Content = $L.ChkProfileClearFirst }
if($null -ne $ChkProfileOnlyMissing){ $ChkProfileOnlyMissing.Content = $L.ChkProfileOnlyMissing }
if($null -ne $BtnSelectRecommendedMissing){ $BtnSelectRecommendedMissing.Content = $L.BtnSelectRecommendedMissing }
$BtnCompareProfiles.Content = $L.BtnCompareProfiles
$BtnSnapshotSave.Content = $L.BtnSnapshotSave
$BtnSnapshotLoad.Content = $L.BtnSnapshotLoad

$BtnShare.Content = $L.BtnShare
$BtnCopyToken.Content = 'Copy token'
$BtnCopyLink.Content = 'Copy link'
$BtnSaveSharePayload.Content = 'Save payload'
$BtnOpenProfiles2.Content = $L.BtnOpenProfiles
$BtnOpenProfileFile.Content = $L.BtnOpenProfileFile

$BtnExportPack.Content = $L.BtnExportPack
$BtnImportPack.Content = $L.BtnImportPack

$BtnCopyLog.Content = 'Copy log'
$BtnDiagBundle.Content = 'Diagnostics bundle'
$BtnSchedTask.Content = 'Create weekly update task'
$BtnRemoveTask.Content = 'Remove update task'

# About text
$scriptVersion = 'v1.13-suite'
$buildDate = (Get-Date).ToString('yyyy-MM-dd')
$TxtAbout.Text = @"
47Project AppS Crawler - Installer Suite
Version: $scriptVersion  Build: $buildDate

Update page:
$SelfUpdatePage

Folders:
Downloads: $DownloadsDir
Install root: $InstallRoot
Profiles: $ProfilesDir
Exports: $ExportsDir
Logs: $LogsDir

Notes:
- Uninstall is supported for winget/choco managed apps only.
- Auto silent installs are best-effort; unknown installers fall back to interactive.
"@

if(Test-Path -LiteralPath $ChangelogPath){
  try { $TxtChangelog.Text = Get-Content -LiteralPath $ChangelogPath -Raw -Encoding UTF8 } catch { $TxtChangelog.Text = '' }
} else {
  $TxtChangelog.Text = "No changelog found at: $ChangelogPath"
}

# ------------
# Logging
# ------------
$script:LogBuffer = New-Object System.Collections.Generic.List[string]
function UI-Log([string]$line){
  $ts = (Get-Date).ToString('HH:mm:ss')
  $msg = "[$ts] $line"
  $script:LogBuffer.Add($msg)
  # keep last 300 lines
  if($script:LogBuffer.Count -gt 300){ $script:LogBuffer.RemoveRange(0,$script:LogBuffer.Count-300) }
  # write disk
  try { Add-Content -LiteralPath (Join-Path $LogsDir '47-AppCrawler.log') -Value $msg -Encoding UTF8 } catch {}
  # optional JSONL (enterprise)
  try {
    if($script:Enterprise -and $script:Enterprise.logJsonl){
      $o = @{ ts = (Get-Date).ToString('o'); msg = $line } | ConvertTo-Json -Compress
      Add-Content -LiteralPath (Join-Path $LogsDir '47-AppCrawler.jsonl') -Value $o -Encoding UTF8
    }
  } catch {}
  # update UI
  $window.Dispatcher.BeginInvoke([Action]{
    $TxtLog.Text = ($script:LogBuffer -join "`r`n")
    $TxtLog.ScrollToEnd()
  }, [Windows.Threading.DispatcherPriority]::Background) | Out-Null
}

# ------------
# Data model setup
# ------------
$raw = Get-BaseCatalog
$items = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
foreach($a in $raw){
  $items.Add((New-AppItem $a)) | Out-Null
}
  # Load overrides from settings (deferred until functions are defined)
  # Load-OverridesFromSettings
# Categories
$cats = @($items | Select-Object -ExpandProperty Category -Unique | Sort-Object)
$CmbCategory.Items.Add($L.CategoryAll) | Out-Null
foreach($c in $cats){ $CmbCategory.Items.Add($c) | Out-Null }
$CmbCategory.SelectedIndex = 0

# Sort options
foreach($s in @('Name','Category','Installed','Selected')){ $CmbSort.Items.Add($s) | Out-Null }
$CmbSort.SelectedItem = 'Name'

# Profiles dropdown
foreach($p in Get-BuiltinProfiles){ $CmbProfile.Items.Add($p) | Out-Null }
$CmbProfile.SelectedItem = 'None'
if($TxtAutoProfileDesc){ $TxtAutoProfileDesc.Text = Get-ProfileDescription 'None' }
if($CmbAutoProfile){ foreach($p in Get-BuiltinProfiles){ $CmbAutoProfile.Items.Add($p) | Out-Null }; $CmbAutoProfile.SelectedItem = 'None' }

# Concurrency
foreach($n in 1..6){ $CmbConcurrency.Items.Add([string]$n) | Out-Null }
$CmbConcurrency.SelectedItem = '3'

# Install mode
foreach($m in @('interactive','auto')){ $CmbInstallMode.Items.Add($m) | Out-Null }
$CmbInstallMode.SelectedItem = 'interactive'

# Preferred method overrides (Details tab)
if($CmbPreferredMethod){
  foreach($opt in @('Auto','winget','choco','download','portable')){
    [void]$CmbPreferredMethod.Items.Add($opt)
  }
  $CmbPreferredMethod.SelectedIndex = 0
}

# Bind grid
$GridApps.ItemsSource = $items
$view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($GridApps.ItemsSource)

# Mutual exclusive toggles
$ChkInstalledOnly.Add_Checked({ $ChkMissingOnly.IsChecked = $false }) | Out-Null
$ChkMissingOnly.Add_Checked({ $ChkInstalledOnly.IsChecked = $false }) | Out-Null
$ChkContinueOnErrors.Add_Checked({ }) | Out-Null

# Search hint logic
$TxtSearch.Add_TextChanged({
  $TxtSearchHint.Visibility = if([string]::IsNullOrWhiteSpace($TxtSearch.Text)){'Visible'} else {'Collapsed'}
  Update-FilterAndStats
}) | Out-Null

$BtnClearSearch.Add_Click({ $TxtSearch.Text = '' }) | Out-Null
$window.Add_KeyDown({
  param($s,$e)
  if($e.Key -eq 'Escape'){ $TxtSearch.Text = '' }
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'F'){ $TxtSearch.Focus() | Out-Null }
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'A'){ Select-Visible -Mode 'all' }
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'I'){ Select-Visible -Mode 'invert' }
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'S'){ Save-Profile }
}) | Out-Null

# Debounced search/filter
$script:FilterTimer = New-Object Windows.Threading.DispatcherTimer
$script:FilterTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$script:FilterTimer.Add_Tick({
  $script:FilterTimer.Stop()
  try { $view.Refresh() } catch {}
  Update-StatsOnly
}) | Out-Null

function Update-FilterAndStats {
  $script:FilterTimer.Stop()
  $script:FilterTimer.Start()
}

# Filter predicate
$view.Filter = {
  param($obj)
  $it = $obj
  # Category
  $cat = [string]$CmbCategory.SelectedItem
  if($cat -and $cat -ne $L.CategoryAll -and $it.Category -ne $cat){ return $false }

  # Search
  $q = [string]$TxtSearch.Text
  if($q -and $q.Trim().Length -gt 0){
    $q = $q.Trim().ToLowerInvariant()
    $hay = ("$($it.Name) $($it.Notes) $($it.Category) $($it.WingetId) $($it.ChocoId) $($it.Method)").ToLowerInvariant()
    if($hay -notlike "*$q*"){ return $false }
  }

  # Toggles
  if($ChkInstalledOnly.IsChecked -and -not $it.IsInstalled){ return $false }
  if($ChkMissingOnly.IsChecked -and $it.IsInstalled){ return $false }
  if($ChkSelectedOnly.IsChecked -and -not $it.IsSelected){ return $false }
  if($ChkFavoritesOnly.IsChecked -and -not $it.IsFavorite){ return $false }
  if($ChkPortableOnly.IsChecked -and -not $it.IsPortable){ return $false }
  if($ChkUpdateableOnly.IsChecked -and -not $it.IsUpdateable){ return $false }
  if($ChkUpdatesAvailableOnly -and $ChkUpdatesAvailableOnly.IsChecked -and -not $it.UpdateAvailable){ return $false }

  return $true
}

# Sorting
function Apply-Sort {
  $view.SortDescriptions.Clear()
  $sel = [string]$CmbSort.SelectedItem
  switch($sel){
    'Category' { $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('Category',[System.ComponentModel.ListSortDirection]::Ascending))) }
    'Installed' { $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('IsInstalled',[System.ComponentModel.ListSortDirection]::Descending))) }
    'Selected' { $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('IsSelected',[System.ComponentModel.ListSortDirection]::Descending))) }
    default { $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('Name',[System.ComponentModel.ListSortDirection]::Ascending))) }
  }
  # Tie-breaker
  $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription('Name',[System.ComponentModel.ListSortDirection]::Ascending)))
}

$CmbSort.Add_SelectionChanged({ Apply-Sort; Update-FilterAndStats }) | Out-Null

# Include installed affects selectability
$ChkIncludeInstalled.Add_Checked({
  foreach($it in $items){
    $it.IncludeInstalledFlag = $true
    $it.IsSelectable = $true
  }
  Update-FilterAndStats
}) | Out-Null
$ChkIncludeInstalled.Add_Unchecked({
  foreach($it in $items){
    $it.IncludeInstalledFlag = $false
    if($it.IsInstalled){
      $it.IsSelected = $false
      $it.IsSelectable = $false
    } else {
      $it.IsSelectable = $true
    }
  }
  Update-FilterAndStats
}) | Out-Null

# Other filter toggles
foreach($cb in @($ChkInstalledOnly,$ChkMissingOnly,$ChkSelectedOnly,$ChkFavoritesOnly,$ChkPortableOnly,$ChkUpdateableOnly,$ChkUpdatesAvailableOnly) | Where-Object { $_ }){
  $cb.Add_Checked({ Update-FilterAndStats }) | Out-Null
  $cb.Add_Unchecked({ Update-FilterAndStats }) | Out-Null
}
$CmbCategory.Add_SelectionChanged({ Update-FilterAndStats }) | Out-Null

# Compact mode
function Apply-Compact {
  if($ChkCompact.IsChecked){
    $GridApps.RowHeight = 22
    $GridApps.FontSize = 12
  } else {
    $GridApps.RowHeight = [double]::NaN
    $GridApps.FontSize = 13
  }
}
$ChkCompact.Add_Checked({ Apply-Compact }) | Out-Null
$ChkCompact.Add_Unchecked({ Apply-Compact }) | Out-Null

# Safe mode toggle
$ChkSafeMode.IsChecked = $SafeMode
$ChkSafeMode.Add_Checked({
  $script:SafeModeOn = $true
  try { if($BtnUninstall){ $BtnUninstall.IsEnabled = $false }; if($BtnUninstallAll){ $BtnUninstallAll.IsEnabled = $false } } catch {}
}) | Out-Null
$ChkSafeMode.Add_Unchecked({
  $script:SafeModeOn = $false
  try { if($BtnUninstall){ $BtnUninstall.IsEnabled = $true }; if($BtnUninstallAll){ $BtnUninstallAll.IsEnabled = $true } } catch {}
}) | Out-Null
$script:SafeModeOn = [bool]$SafeMode

# Settings persistence
function Load-Settings {
  $s = Read-JsonFile $SettingsPath
  if(-not $s){ return }
  try {
    if($s.search -ne $null){ $TxtSearch.Text = [string]$s.search }
    if($s.category -ne $null){
      $idx = $CmbCategory.Items.IndexOf([string]$s.category)
      if($idx -ge 0){ $CmbCategory.SelectedIndex = $idx }
    }
    if($s.sort -ne $null){
      $idx = $CmbSort.Items.IndexOf([string]$s.sort)
      if($idx -ge 0){ $CmbSort.SelectedIndex = $idx }
    }

    # Session restore (tab + selection) - applied after scan for stability
    try {
      if($s.mainTabIndex -ne $null -and $MainTabs){ $MainTabs.SelectedIndex = [int]$s.mainTabIndex }
    } catch {}
    try {
      if($s.selectedKeys){ $script:SessionSelectedKeys = @($s.selectedKeys | ForEach-Object { [string]$_ }) } else { $script:SessionSelectedKeys = @() }
    } catch { $script:SessionSelectedKeys = @() }
    if($s.includeInstalled -ne $null){ $ChkIncludeInstalled.IsChecked = [bool]$s.includeInstalled }
    if($s.compact -ne $null){ $ChkCompact.IsChecked = [bool]$s.compact }
    if($s.safeMode -ne $null){ $ChkSafeMode.IsChecked = [bool]$s.safeMode }
    if($s.enterprise){
      try {
        if($s.enterprise.lock -ne $null){ $script:Enterprise.lock = [bool]$s.enterprise.lock }
        if($s.enterprise.allowedMethods){ $script:Enterprise.allowedMethods = @($s.enterprise.allowedMethods | ForEach-Object { [string]$_ }) }
        if($s.enterprise.mirrorBase -ne $null){ $script:Enterprise.mirrorBase = [string]$s.enterprise.mirrorBase }
        if($s.enterprise.proxy -ne $null){ $script:Enterprise.proxy = [string]$s.enterprise.proxy }
        if($s.enterprise.useSystemProxy -ne $null){ $script:Enterprise.useSystemProxy = [bool]$s.enterprise.useSystemProxy }
        if($s.enterprise.tls -ne $null){ $script:Enterprise.tls = [string]$s.enterprise.tls }
        if($s.enterprise.allowlist){ $script:Enterprise.allowlist = @($s.enterprise.allowlist | ForEach-Object { [string]$_ }) }
        if($s.enterprise.denylist){ $script:Enterprise.denylist = @($s.enterprise.denylist | ForEach-Object { [string]$_ }) }
        if($s.enterprise.strictAllowlist -ne $null){ $script:Enterprise.strictAllowlist = [bool]$s.enterprise.strictAllowlist }
        if($s.enterprise.certPinEnabled -ne $null){ $script:Enterprise.certPinEnabled = [bool]$s.enterprise.certPinEnabled }
        if($s.enterprise.certPinThumbprint -ne $null){ $script:Enterprise.certPinThumbprint = [string]$s.enterprise.certPinThumbprint }
      } catch {}
    }
    if($s.downloadByCategory -ne $null){ $ChkDownloadByCategory.IsChecked = [bool]$s.downloadByCategory; $script:DownloadByCategory = [bool]$s.downloadByCategory }
    if($s.flags){
      $ChkInstalledOnly.IsChecked = [bool]$s.flags.installedOnly
      $ChkMissingOnly.IsChecked = [bool]$s.flags.missingOnly
      $ChkSelectedOnly.IsChecked = [bool]$s.flags.selectedOnly
      $ChkFavoritesOnly.IsChecked = [bool]$s.flags.favoritesOnly
      $ChkPortableOnly.IsChecked = [bool]$s.flags.portableOnly
      $ChkUpdateableOnly.IsChecked = [bool]$s.flags.updateableOnly
    }
    if($s.window){
      if($s.window.width){ $window.Width = [double]$s.window.width }
      if($s.window.height){ $window.Height = [double]$s.window.height }
      if($s.window.left){ $window.Left = [double]$s.window.left }
      if($s.window.top){ $window.Top = [double]$s.window.top }
      if($s.window.state){ $window.WindowState = [System.Windows.WindowState]::$($s.window.state) }
    }
    if($s.favorites){
      $fav = @{}
      foreach($f in $s.favorites){ $fav[[string]$f] = $true }
      foreach($it in $items){
        $key = ($it.WingetId, $it.ChocoId, $it.Name) | Where-Object { $_ } | Select-Object -First 1
        if($key -and $fav.ContainsKey($key.ToString())){ $it.IsFavorite = $true }
      }
    }
  } catch {}
}

function Save-Settings {
  try {
    $fav = @()
    foreach($it in $items | Where-Object { $_.IsFavorite }){
      $fav += (($it.WingetId, $it.ChocoId, $it.Name) | Where-Object { $_ } | Select-Object -First 1)
    }
    
    $selKeys = @()
    foreach($it in $items | Where-Object { $_.IsSelected }){
      $k = $null
      if($it.WingetId){ $k = 'winget:' + ([string]$it.WingetId).ToLowerInvariant() }
      elseif($it.ChocoId){ $k = 'choco:' + ([string]$it.ChocoId).ToLowerInvariant() }
      else { $k = 'name:' + (Normalize-AppKey ([string]$it.Name)) }
      if($k){ $selKeys += $k }
    }
    $tabIdx = 0
    try { if($MainTabs){ $tabIdx = [int]$MainTabs.SelectedIndex } } catch {}
$obj = [pscustomobject]@{
      schema = 1
      search = [string]$TxtSearch.Text
      mainTabIndex = $tabIdx
      selectedKeys = $selKeys
      category = [string]$CmbCategory.SelectedItem
      sort = [string]$CmbSort.SelectedItem
      includeInstalled = [bool]$ChkIncludeInstalled.IsChecked
      compact = [bool]$ChkCompact.IsChecked
      safeMode = [bool]$ChkSafeMode.IsChecked
      downloadByCategory = [bool]$ChkDownloadByCategory.IsChecked
      enterprise = $script:Enterprise
      flags = [pscustomobject]@{
        installedOnly = [bool]$ChkInstalledOnly.IsChecked
        missingOnly = [bool]$ChkMissingOnly.IsChecked
        selectedOnly = [bool]$ChkSelectedOnly.IsChecked
        favoritesOnly = [bool]$ChkFavoritesOnly.IsChecked
        portableOnly = [bool]$ChkPortableOnly.IsChecked
        updateableOnly = [bool]$ChkUpdateableOnly.IsChecked
      }
      favorites = $fav
      window = [pscustomobject]@{
        width = $window.Width
        height = $window.Height
        left = $window.Left
        top = $window.Top
        state = $window.WindowState.ToString()
      }
    }
    Write-JsonFile $SettingsPath $obj
  } catch {}
}

# Stats
function Update-StatsOnly {
  try {
    $total = $items.Count
    $selected = @($items | Where-Object { $_.IsSelected }).Count
    $visible = @($view | ForEach-Object { $_ }).Count
    $selectable = @($items | Where-Object { $_.IsSelectable }).Count
    $TxtStats.Text = "Selected: $selected | Total: $total | Visible: $visible | Selectable: $selectable"
  } catch {
    $TxtStats.Text = ""
  }
}

# Selection change tracking + undo/redo
$script:UndoStack = New-Object System.Collections.Generic.List[object]
$script:RedoStack = New-Object System.Collections.Generic.List[object]
$script:LastSnapshotTime = Get-Date

function Push-SelectionSnapshot {
  $now = Get-Date
  if(($now - $script:LastSnapshotTime).TotalMilliseconds -lt 200){ return }
  $script:LastSnapshotTime = $now
  $snap = Export-SelectionObject $items
  $script:UndoStack.Add($snap)
  if($script:UndoStack.Count -gt 40){ $script:UndoStack.RemoveAt(0) }
  $script:RedoStack.Clear()
}

function Undo-Selection {
  if($script:UndoStack.Count -lt 2){ return }
  $current = $script:UndoStack[$script:UndoStack.Count-1]
  $script:UndoStack.RemoveAt($script:UndoStack.Count-1)
  $prev = $script:UndoStack[$script:UndoStack.Count-1]
  $script:RedoStack.Add($current)
  Apply-SelectionObject $items $prev -ClearFirst
  Update-FilterAndStats
}
function Redo-Selection {
  if($script:RedoStack.Count -lt 1){ return }
  $next = $script:RedoStack[$script:RedoStack.Count-1]
  $script:RedoStack.RemoveAt($script:RedoStack.Count-1)
  $script:UndoStack.Add($next)
  Apply-SelectionObject $items $next -ClearFirst
  Update-FilterAndStats
}

# Keyboard undo/redo
$window.Add_KeyDown({
  param($s,$e)
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'Z'){ Undo-Selection; $e.Handled=$true }
  if($e.KeyboardDevice.Modifiers -eq 'Control' -and $e.Key -eq 'Y'){ Redo-Selection; $e.Handled=$true }
}) | Out-Null

# Selection change hooks (works with plain PS objects)
$script:SuppressSelectionEvents = $false
$dg = $window.FindName('GridApps')
if($dg){
  $handler = [System.Windows.RoutedEventHandler]{
    param($s,$e)
    try{
      $src = $e.OriginalSource -as [System.Windows.Controls.CheckBox]
      if(-not $src){ return }
      if($src.Tag -ne 'Select' -and $src.Tag -ne 'Fav'){ return }
      if(-not $script:SuppressSelectionEvents){ Push-SelectionSnapshot }
      Update-StatsOnly
      Update-Preview
    } catch {}
  }
  $dg.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent, $handler, $true) | Out-Null
  $dg.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, $handler, $true) | Out-Null
}

# Clickable chips are represented by checkboxes; we already have toggles. (Could be improved later.)

# Selection helper on visible list
function Select-Visible([string]$Mode){
  $script:SuppressSelectionEvents = $true
  try {

  $visibleItems = @($view | ForEach-Object { $_ })
  switch($Mode){
    'all' { foreach($it in $visibleItems){ if($it.IsSelectable){ $it.IsSelected=$true } } }
    'missing' { foreach($it in $visibleItems){ if(-not $it.IsInstalled -and $it.IsSelectable){ $it.IsSelected=$true } } }
    'invert' { foreach($it in $visibleItems){ if($it.IsSelectable){ $it.IsSelected = -not $it.IsSelected } } }
    'clear' { foreach($it in $visibleItems){ $it.IsSelected=$false } }
  }
  Update-FilterAndStats

  } finally { $script:SuppressSelectionEvents = $false }
}
$BtnSelectVisible.Add_Click({ Select-Visible -Mode 'all' }) | Out-Null
$BtnSelectMissing.Add_Click({ Select-Visible -Mode 'missing' }) | Out-Null
$BtnInvertVisible.Add_Click({ Select-Visible -Mode 'invert' }) | Out-Null
$BtnClearVisible.Add_Click({ Select-Visible -Mode 'clear' }) | Out-Null

# Reset UI
$BtnResetUI.Add_Click({
  $TxtSearch.Text = ''
  $CmbCategory.SelectedIndex = 0
  $CmbSort.SelectedItem = 'Name'
  $CmbProfile.SelectedItem = 'None'
  $ChkInstalledOnly.IsChecked = $false
  $ChkMissingOnly.IsChecked = $false
  $ChkSelectedOnly.IsChecked = $false
  $ChkFavoritesOnly.IsChecked = $false
  $ChkPortableOnly.IsChecked = $false
  $ChkUpdateableOnly.IsChecked = $false
  $ChkIncludeInstalled.IsChecked = $false
  $ChkDryRun.IsChecked = $false
  $ChkOnlyUpdateInstalled.IsChecked = $true
  $ChkContinueOnErrors.IsChecked = $true
  $ChkSkipAdmin.IsChecked = $false
  Update-FilterAndStats
}) | Out-Null

# Footer badges (winget/choco presence + signature status)
function Get-SignatureStatus {
  try {
    $sig = Get-AuthenticodeSignature -FilePath $MyInvocation.MyCommand.Path
    switch ($sig.Status) {
      'Valid'     { return 'Signed' }
      'NotSigned' { return 'Unsigned' }
      default     { return $sig.Status.ToString() }
    }
  } catch { return 'Unknown' }
}
function Update-FooterBadges {
  $wing = if(Get-Command winget -EA SilentlyContinue){ 'winget:OK' } else { 'winget:Missing' }
  $ch   = if(Get-Command choco -EA SilentlyContinue){ 'choco:OK' } else { 'choco:Missing' }
  $sig  = "sig:" + (Get-SignatureStatus)

  # StrictMode-safe: variable may not exist until the user runs "Scan available updates"
  $uVar = Get-Variable -Name UpdatesAvailableCount -Scope Script -EA SilentlyContinue
  $u    = if($uVar){ [int]$uVar.Value } else { -1 }
  $upd  = if($u -ge 0){ "updates:$u" } else { "updates:NotScanned" }

  $FooterBadges.Text = "$wing  $ch  $upd  $sig"
}
Update-FooterBadges

# Details panel update
$GridApps.Add_SelectionChanged({
  $it = $GridApps.SelectedItem
  if(-not $it){ return }
  $script:CurrentItem = $it

  $DetName.Text = "Name: $($it.Name)"
  $DetCat.Text = "Category: $($it.Category)"
  $DetMethod.Text = "Method: $($it.Method)"
  $DetIds.Text = "Ids: winget=$($it.WingetId)  choco=$($it.ChocoId)"
  $DetUrl.Text = "Url: $($it.Url)"
  # badges
  $badges = @()
  if($it.IsInstalled){ $badges += 'Installed' } else { $badges += 'Missing' }
  if($it.IsUpdateable){ $badges += 'Updateable' }
  if($it.IsPortable){ $badges += 'Portable' }
  if($it.NeedsAdmin){ $badges += 'NeedsAdmin' }
  if($it.PSObject.Properties.Match('PreferredMethod').Count -gt 0 -and $it.PreferredMethod){ $badges += ("Prefer:" + $it.PreferredMethod) }
  if($it.PSObject.Properties.Match('Skip').Count -gt 0 -and $it.Skip){ $badges += "Skipped" }
  $DetBadges.Text = "Badges: " + ($badges -join ', ')
  # warning
  $warn = @()
  if($it.IsInstalled -and -not $it.IsSelectable){ $warn += "Installed (locked). Enable 'Include installed' to reinstall/update." }
  $DetWarn.Text = ($warn -join "`n")

  # --- Details editor sync (tags/overrides) ---
  $script:InDetailSync = $true
  try {
    $tags = @()
    if($it.PSObject.Properties['Profiles']){ $tags = @($it.Profiles) }
    foreach($p in @(
      @{C=$TagMinimal; N='Minimal'},
      @{C=$TagGaming; N='Gaming'},
      @{C=$TagOffice; N='Office'},
      @{C=$TagDev; N='Dev'},
      @{C=$TagCreator; N='Creator'},
      @{C=$TagSysadmin; N='Sysadmin'},
      @{C=$TagPortable; N='Portable'}
    )){
      if($p.C){
        $p.C.IsChecked = ($tags -contains $p.N)
      }
    }

    if($TxtAppNote){
      $TxtAppNote.Text = if($it.PSObject.Properties['UserNote']){ [string]$it.UserNote } else { '' }
    }
    if($CmbPreferredMethod){
      $val = if($it.PSObject.Properties['PreferredMethod']){ [string]$it.PreferredMethod } else { 'Auto' }
      $idx = $CmbPreferredMethod.Items.IndexOf($val)
      if($idx -ge 0){ $CmbPreferredMethod.SelectedIndex = $idx } else { $CmbPreferredMethod.SelectedIndex = 0 }
    }
    if($ChkSkipApp){
      $ChkSkipApp.IsChecked = ($it.PSObject.Properties['Skip'] -and [bool]$it.Skip)
    }
    if($ChkExcludeUpdate){
      $ChkExcludeUpdate.IsChecked = ($it.PSObject.Properties['ExcludeUpdate'] -and [bool]$it.ExcludeUpdate)
    }

  } catch {}
  $script:InDetailSync = $false
}) | Out-Null

# Details editor: tag toggles and overrides (works with PSCustomObject items)
function Set-ItemTags {
  param($item, [string[]]$tags)
  if(-not $item){ return }
  $item.Profiles = @($tags | Where-Object { $_ } | Select-Object -Unique)
}

function Get-CheckedTags {
  $t = @()
  foreach($p in @(
    @{C=$TagMinimal; N='Minimal'},
    @{C=$TagGaming; N='Gaming'},
    @{C=$TagOffice; N='Office'},
    @{C=$TagDev; N='Dev'},
    @{C=$TagCreator; N='Creator'},
    @{C=$TagSysadmin; N='Sysadmin'},
    @{C=$TagPortable; N='Portable'}
  )){
    if($p.C -and $p.C.IsChecked){ $t += $p.N }
  }
  return @($t | Select-Object -Unique)
}

$tagControls = @($TagMinimal,$TagGaming,$TagOffice,$TagDev,$TagCreator,$TagSysadmin,$TagPortable) | Where-Object { $_ }
foreach($tc in $tagControls){
  $tc.Add_Checked({
    if($script:InDetailSync){ return }
    $it = $script:CurrentItem
    if(-not $it){ return }
    Set-ItemTags -item $it -tags (Get-CheckedTags)
    Update-FilterAndStats
  }) | Out-Null
  $tc.Add_Unchecked({
    if($script:InDetailSync){ return }
    $it = $script:CurrentItem
    if(-not $it){ return }
    Set-ItemTags -item $it -tags (Get-CheckedTags)
    Update-FilterAndStats
  }) | Out-Null
}

if($CmbPreferredMethod){
  $CmbPreferredMethod.Add_SelectionChanged({
    if($script:InDetailSync){ return }
    $it = $script:CurrentItem
    if(-not $it){ return }
    $it.PreferredMethod = [string]$CmbPreferredMethod.SelectedItem
  }) | Out-Null
}

if($ChkSkipApp){
  $ChkSkipApp.Add_Checked({ if($script:InDetailSync){return}; if($script:CurrentItem){ $script:CurrentItem.Skip = $true } }) | Out-Null
  $ChkSkipApp.Add_Unchecked({ if($script:InDetailSync){return}; if($script:CurrentItem){ $script:CurrentItem.Skip = $false } }) | Out-Null
}

if($ChkExcludeUpdate){
  $ChkExcludeUpdate.Add_Checked({ if($script:InDetailSync){return}; if($script:CurrentItem){ $script:CurrentItem.ExcludeUpdate = $true } }) | Out-Null
  $ChkExcludeUpdate.Add_Unchecked({ if($script:InDetailSync){return}; if($script:CurrentItem){ $script:CurrentItem.ExcludeUpdate = $false } }) | Out-Null
}

if($TxtAppNote){
  $TxtAppNote.Add_LostFocus({
    if($script:InDetailSync){ return }
    if($script:CurrentItem){
      $script:CurrentItem.UserNote = [string]$TxtAppNote.Text
    }
  }) | Out-Null
}

if($BtnApplyTagsToSelected){
  $BtnApplyTagsToSelected.Add_Click({
    $tags = Get-CheckedTags
    foreach($it in $items){
      if($it.IsSelected){ Set-ItemTags -item $it -tags $tags }
    }
    Update-FilterAndStats
    Log "Applied tags to selected apps: $($tags -join ', ')"
  }) | Out-Null
}

# Persist overrides to settings.json (lightweight)
function Save-OverridesToSettings {
  try {
    $ov = @{}
    foreach($it in $items){
      $ov[$it.Name] = @{
        PreferredMethod = $it.PreferredMethod
        PinnedVersion   = $it.PinnedVersion
        Skip            = [bool]$it.Skip
        ExcludeUpdate   = [bool]$it.ExcludeUpdate
        UserNote        = [string]$it.UserNote
        Profiles        = @($it.Profiles)
      }
    }
    $s = Read-JsonFile $SettingsPath
    if(-not $s){ $s = @{} }
    $s.overrides = $ov
    $s | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
  } catch {}
}

function Load-OverridesFromSettings {
  try {
    $s = Read-JsonFile $SettingsPath
    if(-not $s -or -not $s.overrides){ return }
    foreach($it in $items){
      $o = $s.overrides[$it.Name]
      if(-not $o){ continue }
      if($o.PreferredMethod){ $it.PreferredMethod = [string]$o.PreferredMethod }
      if($o.PinnedVersion -ne $null){ $it.PinnedVersion = [string]$o.PinnedVersion }
      if($o.Skip -ne $null){ $it.Skip = [bool]$o.Skip }
      if($o.ExcludeUpdate -ne $null){ $it.ExcludeUpdate = [bool]$o.ExcludeUpdate }
      if($o.UserNote -ne $null){ $it.UserNote = [string]$o.UserNote }
      if($o.Profiles){ $it.Profiles = @($o.Profiles) }
    }

# Apply overrides now that functions are defined
try { Load-OverridesFromSettings } catch {}
try { if(Get-Command Update-FilterAndStats -ErrorAction SilentlyContinue){ Update-FilterAndStats } } catch {}
  } catch {}
}

# Deferred: now that Load-OverridesFromSettings exists, apply overrides
try { Load-OverridesFromSettings } catch {}
try { if (Get-Command Update-FilterAndStats -ErrorAction SilentlyContinue) { Update-FilterAndStats } } catch {}

if($BtnSaveAppOverrides){
  $BtnSaveAppOverrides.Add_Click({
    Save-OverridesToSettings
    [System.Windows.MessageBox]::Show("Overrides saved to settings.json (under overrides).","47Project", 'OK','Information') | Out-Null
  }) | Out-Null
}



$BtnCopyName.Add_Click({
  if($GridApps.SelectedItem){ [System.Windows.Clipboard]::SetText([string]$GridApps.SelectedItem.Name) }
}) | Out-Null
$BtnCopyId.Add_Click({
  if($GridApps.SelectedItem){
    $it = $GridApps.SelectedItem
    $id = if($it.WingetId){ $it.WingetId } elseif($it.ChocoId){ $it.ChocoId } else { $it.Name }
    [System.Windows.Clipboard]::SetText([string]$id)
  }
}) | Out-Null
$BtnCopyUrl.Add_Click({
  if($GridApps.SelectedItem){ [System.Windows.Clipboard]::SetText([string]$GridApps.SelectedItem.Url) }
}) | Out-Null
$BtnOpenInstallFolder.Add_Click({
  if($GridApps.SelectedItem){
    $it = $GridApps.SelectedItem
    $dir = Join-Path $InstallRoot ($it.Name -replace '[:\\\/\*\?\"<>|]','_')
    Open-Explorer $dir
  }
}) | Out-Null

# Export selected
$BtnExportSelected.Add_Click({
  $obj = Export-SelectionObject $items
  $stamp = Get-NowStamp
  $jsonPath = Join-Path $ExportsDir ("selected_$stamp.json")
  $txtPath  = Join-Path $ExportsDir ("selected_$stamp.txt")
  Write-JsonFile $jsonPath $obj
  $names = ($obj.selected | ForEach-Object { $_.Name }) -join "`r`n"
  Set-Content -LiteralPath $txtPath -Value $names -Encoding UTF8
  UI-Log "Exported selection: $jsonPath"
  Open-ExplorerSelect $jsonPath
}) | Out-Null

# Copy selected
$BtnCopySelected.Add_Click({
  $names = @($items | Where-Object { $_.IsSelected } | ForEach-Object { $_.Name })
  [System.Windows.Clipboard]::SetText(($names -join "`r`n"))
  UI-Log "Copied $($names.Count) selected apps to clipboard."
}) | Out-Null

# Open logs
$BtnOpenLogs.Add_Click({ Open-Explorer $LogsDir }) | Out-Null

# Copy log
$BtnCopyLog.Add_Click({ [System.Windows.Clipboard]::SetText($TxtLog.Text) }) | Out-Null

# Diagnostics bundle
$BtnDiagBundle.Add_Click({
  $stamp = Get-NowStamp
  $zip = Join-Path $DiagDir ("diag_$stamp.zip")
  $tmp = Join-Path $env:TEMP ("diag_$stamp")
  if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Recurse -Force }
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  foreach($p in @($LogsDir,$ProfilesDir,$ExportsDir,$SettingsPath)){
    try {
      if(Test-Path -LiteralPath $p){
        Copy-Item -LiteralPath $p -Destination $tmp -Recurse -Force
      }
    } catch {}
  }
  try {
    Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip -Force
    UI-Log "Diagnostics bundle created: $zip"
    Open-ExplorerSelect $zip
  } catch {
    Show-Message "Diagnostics bundle failed: $($_.Exception.Message)" '47Project' 'Error'
  } finally {
    try { Remove-Item -LiteralPath $tmp -Recurse -Force } catch {}
  }
}) | Out-Null

# Mirror diag button in Suite->Tools (optional)
if($BtnDiagnostics){
  $BtnDiagnostics.Add_Click({ $BtnDiagBundle.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }) | Out-Null
}

# Export inventory CSV
if($BtnExportInventoryCsv){
  $BtnExportInventoryCsv.Add_Click({
    try {
      $stamp = Get-NowStamp
      $path = Join-Path $ExportsDir ("inventory_$stamp.csv")
      Export-InventoryCsv $path | Out-Null
      UI-Log "Inventory CSV: $path"
      Open-ExplorerSelect $path
    } catch { UI-Log "Inventory export failed: $($_.Exception.Message)" }
  }) | Out-Null
}

function Do-ExportPolicy {
  try {
    $stamp = Get-NowStamp
    $path = Join-Path $ExportsDir ("policy_$stamp.json")
    Export-Policy $path | Out-Null
    Refresh-PolicyPreview
    UI-Log "Policy exported: $path"
    Open-ExplorerSelect $path
  } catch { UI-Log "Policy export failed: $($_.Exception.Message)" }
}

function Do-ImportPolicy {
  try {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.InitialDirectory = $ExportsDir
    $dlg.Filter = "Policy JSON (*.json)|*.json|All files (*.*)|*.*"
    $dlg.Title = "Import policy JSON"
    if($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
    Import-Policy $dlg.FileName
    Refresh-PolicyPreview
    Update-FilterAndStats
    UI-Log "Policy imported: $($dlg.FileName)"
  } catch { UI-Log "Policy import failed: $($_.Exception.Message)" }
}

if($BtnExportPolicy){ $BtnExportPolicy.Add_Click({ Do-ExportPolicy }) | Out-Null }
if($BtnExportPolicy2){ $BtnExportPolicy2.Add_Click({ Do-ExportPolicy }) | Out-Null }
if($BtnImportPolicy){ $BtnImportPolicy.Add_Click({ Do-ImportPolicy }) | Out-Null }
if($BtnImportPolicy2){ $BtnImportPolicy2.Add_Click({ Do-ImportPolicy }) | Out-Null }

if($BtnOpenHistoryFolder){
  $BtnOpenHistoryFolder.Add_Click({ Open-Explorer $ExportsDir }) | Out-Null
}
if($BtnOpenHistoryReport){
  $BtnOpenHistoryReport.Add_Click({
    if($LstHistory -and $LstHistory.SelectedItem){ Start-Process -FilePath "notepad.exe" -ArgumentList @($LstHistory.SelectedItem) | Out-Null }
  }) | Out-Null
}

# Catalog tab actions
if($BtnCatalogRefresh){ $BtnCatalogRefresh.Add_Click({ Refresh-CatalogSourcesUI; UI-Log "Catalog sources refreshed." }) | Out-Null }
if($BtnCatalogOpenFolder){ $BtnCatalogOpenFolder.Add_Click({ Ensure-Dir $CatalogDir; Open-Explorer $CatalogDir }) | Out-Null }
if($BtnCatalogExportMerged){
  $BtnCatalogExportMerged.Add_Click({
    try {
      $path = Join-Path $ExportsDir ("catalog_merged_" + (Get-NowStamp) + ".json")
      $raw = Get-BaseCatalog
      Write-JsonFile $path $raw
      UI-Log "Merged catalog exported: $path"
      Open-ExplorerSelect $path
    } catch { UI-Log "Export merged failed: $($_.Exception.Message)" }
  }) | Out-Null
}
if($BtnCatalogFixDupes){
if($BtnCatalogOnlineUpdate){ $BtnCatalogOnlineUpdate.Add_Click({ Invoke-CatalogOnlineUpdate }) | Out-Null }
  $BtnCatalogFixDupes.Add_Click({
    try {
      # Safe: just run validation and show a summary; no destructive changes
      # Safe duplicate check (no modifications)
      $issues = New-Object System.Collections.Generic.List[string]
      $byWinget = @{}
      $byChoco = @{}
      foreach($it in $items){
        if($it.WingetId){
          $k = $it.WingetId.ToLowerInvariant(); if($byWinget.ContainsKey($k)){ $issues.Add("Duplicate wingetId: $($it.WingetId) -> $($byWinget[$k]) and $($it.Name)") | Out-Null } else { $byWinget[$k] = $it.Name }
        }
        if($it.ChocoId){
          $k = $it.ChocoId.ToLowerInvariant(); if($byChoco.ContainsKey($k)){ $issues.Add("Duplicate chocoId: $($it.ChocoId) -> $($byChoco[$k]) and $($it.Name)") | Out-Null } else { $byChoco[$k] = $it.Name }
        }
      }
      if($issues.Count -eq 0){ Show-Message "No obvious duplicates found." 'Catalog check' 'Info' }
      else { Show-Message (($issues -join "`n") + "`n`nTip: Edit your catalog.d JSON files to remove duplicates.") 'Catalog check' 'Warn' }
    } catch { UI-Log "Fix dupes failed: $($_.Exception.Message)" }
  }) | Out-Null
}

# Policy: export runnable pack script (portable - generates a .ps1 that calls this suite with profile)
if($BtnExportPackScript){
  $BtnExportPackScript.Add_Click({
    try {
      $stamp = Get-NowStamp
      $out = Join-Path $ExportsDir ("pack_" + $stamp + ".ps1")
      $policyPath = Join-Path $ExportsDir ("policy_" + $stamp + ".json")
      Export-Policy $policyPath | Out-Null
      $self = $MyInvocation.MyCommand.Path
      $content = @"
# 47Project pack runner (generated)
# Requires: PowerShell 5.1, Windows 10/11
`$policy = '$policyPath'
`$suite = '$self'
powershell -NoProfile -ExecutionPolicy Bypass -STA -File `"$suite`" -RunUI
# Import policy from UI -> Policy tab, then run Install/Update.
"@
      Set-Content -LiteralPath $out -Value $content -Encoding UTF8
      UI-Log "Pack script exported: $out"
      Open-ExplorerSelect $out
    } catch { UI-Log "Export pack script failed: $($_.Exception.Message)" }
  }) | Out-Null
}



# Scheduled maintenance
$BtnSchedTask.Add_Click({ Ensure-ScheduledTask -Log ${function:UI-Log} }) | Out-Null
$BtnRemoveTask.Add_Click({ Ensure-ScheduledTask -Remove -Log ${function:UI-Log} }) | Out-Null

# Validate catalog
$BtnValidateCatalog.Add_Click({
  try {
    $issues = New-Object System.Collections.Generic.List[string]
    $wing = @{}
    $cho  = @{}
    foreach($it in $items){
      if([string]::IsNullOrWhiteSpace($it.Name)){ $issues.Add("Missing name") }
      if($it.Method -eq 'winget' -and [string]::IsNullOrWhiteSpace($it.WingetId)){ $issues.Add("Missing WingetId: $($it.Name)") }
      if($it.Method -eq 'choco' -and [string]::IsNullOrWhiteSpace($it.ChocoId)){ $issues.Add("Missing ChocoId: $($it.Name)") }
      if($it.Method -in @('download','portable') -and [string]::IsNullOrWhiteSpace($it.Url)){ $issues.Add("Missing Url: $($it.Name)") }
      if($it.WingetId){
        $k = $it.WingetId.ToLowerInvariant()
        if($wing.ContainsKey($k)){ $issues.Add("Duplicate WingetId: $($it.WingetId) (e.g., $($it.Name))") } else { $wing[$k]=$true }
      }
      if($it.ChocoId){
        $k = $it.ChocoId.ToLowerInvariant()
        if($cho.ContainsKey($k)){ $issues.Add("Duplicate ChocoId: $($it.ChocoId) (e.g., $($it.Name))") } else { $cho[$k]=$true }
      }
      if($it.Method -eq 'portable' -and $it.InstallerType -ne 'zip'){ $issues.Add("Portable non-zip (download-only): $($it.Name)") }
    }
    if($issues.Count -eq 0){
      Show-Message "Catalog OK." '47Project' 'Info'
    } else {
      $text = ($issues | Select-Object -First 80) -join "`n"
      Show-Message "Catalog issues (showing up to 80):`n`n$text" '47Project' 'Warning'
    }
  } catch {
    Show-Message "Catalog validation failed: $($_.Exception.Message)" '47Project' 'Error'
  }
}) | Out-Null

# Preflight
$BtnPreflight.Add_Click({
  $rep = Run-Preflight -Log ${function:UI-Log}
  # basic UI status
  $TxtStatus.Text = "Preflight complete. Check Logs tab for details."
}) | Out-Null

# ------------
# Profiles save/load + compare/merge + snapshots
# ------------
$script:CurrentProfileName = $null

function Prompt-Input([string]$title,[string]$prompt,[string]$default=''){
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $title
  $form.Width = 420
  $form.Height = 160
  $form.StartPosition = 'CenterScreen'
  $lbl = New-Object System.Windows.Forms.Label
  $lbl.Text = $prompt
  $lbl.Left = 10; $lbl.Top = 10; $lbl.Width = 380
  $txt = New-Object System.Windows.Forms.TextBox
  $txt.Left = 10; $txt.Top = 40; $txt.Width = 380
  $txt.Text = $default
  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = 'OK'; $ok.Left = 230; $ok.Top = 75; $ok.Width = 75
  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = 'Cancel'; $cancel.Left = 315; $cancel.Top = 75; $cancel.Width = 75
  $ok.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::OK; $form.Close() })
  $cancel.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
  $form.Controls.AddRange(@($lbl,$txt,$ok,$cancel))
  $form.AcceptButton = $ok
  $form.CancelButton = $cancel
  $res = $form.ShowDialog()
  if($res -eq [System.Windows.Forms.DialogResult]::OK){ return $txt.Text }
  return $null
}

function Save-Profile {
  try {
    $defaultName = ''
    if ($script:CurrentProfileName) { $defaultName = [string]$script:CurrentProfileName }
    $name = Prompt-Input 'Save profile' 'Profile name:' $defaultName
    if(-not $name){ return }
    $path = Profile-Path $name
    if(-not $path){ return }
    $obj = Export-SelectionObject $items
    Write-JsonFile $path $obj
    $script:CurrentProfileName = $name
    if ($TxtProfileInfo) { $TxtProfileInfo.Text = "Saved profile: $name`n$path" }
    UI-Log "Profile saved: $path"
  } catch {
    UI-Log ("Profile save failed: " + $_.Exception.Message)
    Show-Message ("Failed to save profile.`n" + $_.Exception.Message) '47Project' 'Error'
  }
}

function Load-ProfileByPath([string]$path){
  $obj = Read-JsonFile $path
  if(-not $obj){ Show-Message "Failed to load profile." '47Project' 'Error'; return }
  # diff preview
  $before = @($items | Where-Object { $_.IsSelected } | ForEach-Object { ($_.WingetId,$_.ChocoId,$_.Name) | Where-Object { $_ } | Select-Object -First 1 })
  Apply-SelectionObject $items $obj -ClearFirst
  $after = @($items | Where-Object { $_.IsSelected } | ForEach-Object { ($_.WingetId,$_.ChocoId,$_.Name) | Where-Object { $_ } | Select-Object -First 1 })
  $add = @($after | Where-Object { $before -notcontains $_ }).Count
  $rem = @($before | Where-Object { $after -notcontains $_ }).Count
  $TxtProfileInfo.Text = "Loaded profile:`n$path`nDiff: +$add / -$rem"
  UI-Log "Profile loaded: $path"
}

function Load-Profile {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $ProfilesDir
  $dlg.Filter = "JSON profiles (*.json)|*.json"
  if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
    $path = $dlg.FileName
    Load-ProfileByPath $path
    $script:CurrentProfileName = [IO.Path]::GetFileNameWithoutExtension($path)
  }
}

function Overwrite-Profile {
  if(-not $script:CurrentProfileName){ Show-Message "No current profile name. Use Save profile first." '47Project' 'Warning'; return }
  $path = Profile-Path $script:CurrentProfileName
  if(-not $path){ return }
  $obj = Export-SelectionObject $items
  Write-JsonFile $path $obj
  UI-Log "Profile overwritten: $path"
}

function Delete-Profile {
  $name = Prompt-Input 'Delete profile' 'Profile name to delete:' (if($script:CurrentProfileName){$script:CurrentProfileName}else{''})
  if(-not $name){ return }
  $path = Profile-Path $name
  if(Test-Path -LiteralPath $path){
    Remove-Item -LiteralPath $path -Force
    UI-Log "Profile deleted: $path"
    if($script:CurrentProfileName -eq $name){ $script:CurrentProfileName = $null }
  }
}

$BtnSaveProfile.Add_Click({ Save-Profile }) | Out-Null
$BtnLoadProfile.Add_Click({ Load-Profile }) | Out-Null
$BtnOverwriteProfile.Add_Click({ Overwrite-Profile }) | Out-Null
$BtnDeleteProfile.Add_Click({ Delete-Profile }) | Out-Null
$BtnOpenProfiles.Add_Click({ Open-Explorer $ProfilesDir }) | Out-Null
$BtnOpenProfiles2.Add_Click({ Open-Explorer $ProfilesDir }) | Out-Null
$BtnOpenProfileFile.Add_Click({
  if($script:CurrentProfileName){
    $path = Profile-Path $script:CurrentProfileName
    Open-ExplorerSelect $path
  } else {
    Open-Explorer $ProfilesDir
  }
}) | Out-Null

# Compare/Merge profiles (simple)
$BtnCompareProfiles.Add_Click({
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $ProfilesDir
  $dlg.Filter = "JSON profiles (*.json)|*.json"
  $dlg.Title = "Select first profile"
  if($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
  $p1 = $dlg.FileName
  $dlg.Title = "Select second profile"
  if($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
  $p2 = $dlg.FileName
  $o1 = Read-JsonFile $p1
  $o2 = Read-JsonFile $p2
  if(-not $o1 -or -not $o2){ return }
  $k1 = @($o1.selected | ForEach-Object { ($_.WingetId,$_.ChocoId,$_.Name) | Where-Object { $_ } | Select-Object -First 1 })
  $k2 = @($o2.selected | ForEach-Object { ($_.WingetId,$_.ChocoId,$_.Name) | Where-Object { $_ } | Select-Object -First 1 })
  $only1 = @($k1 | Where-Object { $k2 -notcontains $_ })
  $only2 = @($k2 | Where-Object { $k1 -notcontains $_ })
  $msg = "Profile A: $([IO.Path]::GetFileName($p1))`nProfile B: $([IO.Path]::GetFileName($p2))`n`nOnly in A: $($only1.Count)`nOnly in B: $($only2.Count)`n`nMerge into a new profile?"
  $res = [System.Windows.MessageBox]::Show($msg,'47Project',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
  if($res -eq [System.Windows.MessageBoxResult]::Yes){
    $merged = [pscustomobject]@{ schema=1; created=(Get-Date).ToString('s'); selected=@() }
    $set = @{}
    foreach($s in ($o1.selected + $o2.selected)){
      $key = ($s.WingetId,$s.ChocoId,$s.Name) | Where-Object { $_ } | Select-Object -First 1
      if($key -and -not $set.ContainsKey($key.ToLowerInvariant())){
        $set[$key.ToLowerInvariant()] = $true
        $merged.selected += $s
      }
    }
    $name = Prompt-Input 'Merge profile' 'New profile name:' 'Merged'
    if($name){
      $path = Profile-Path $name
      Write-JsonFile $path $merged
      UI-Log "Merged profile saved: $path"
      Open-ExplorerSelect $path
    }
  }
}) | Out-Null

# Snapshots (session state)
function Save-Snapshot {
  $name = Prompt-Input 'Save snapshot' 'Snapshot name:' ('snap_' + (Get-NowStamp))
  if(-not $name){ return }
  $path = Join-Path $SnapshotsDir ($name + '.json')
  $obj = [pscustomobject]@{
    schema=1
    created=(Get-Date).ToString('s')
    ui = Read-JsonFile $SettingsPath
    selection = Export-SelectionObject $items
  }
  Write-JsonFile $path $obj
  UI-Log "Snapshot saved: $path"
  Open-ExplorerSelect $path
}
function Load-Snapshot {
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $SnapshotsDir
  $dlg.Filter = "JSON snapshots (*.json)|*.json"
  if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
    $obj = Read-JsonFile $dlg.FileName
    if($obj.selection){ Apply-SelectionObject $items $obj.selection -ClearFirst }
    UI-Log "Snapshot loaded: $($dlg.FileName)"
  }
}
$BtnSnapshotSave.Add_Click({ Save-Snapshot }) | Out-Null
$BtnSnapshotLoad.Add_Click({ Load-Snapshot }) | Out-Null

# Built-in profile selection (no auto-select; use Apply button in Profiles tab)
$CmbProfile.Add_SelectionChanged({
  $p = [string]$CmbProfile.SelectedItem
  if($CmbAutoProfile -and $p){ $CmbAutoProfile.SelectedItem = $p }
  if($TxtAutoProfileDesc){ $TxtAutoProfileDesc.Text = Get-ProfileDescription $p }
  if($TxtProfileInfo){ $TxtProfileInfo.Text = ("Selected built-in profile: " + $p) }
}) | Out-Null


function Apply-AutoProfileSelection([string]$p,[switch]$ClearFirst,[switch]$OnlyMissing){
  if(-not $p -or $p -eq 'None'){ return }
  $script:SuppressSelectionEvents = $true
  try {
    if($ClearFirst){
      foreach($it in $items){ $it.IsSelected = $false }
    }
    foreach($it in $items){
      if(-not $it.IsSelectable){ continue }
      if($OnlyMissing -and $it.IsInstalled){ continue }
      if($it.Profiles -and ($it.Profiles -contains $p)){
        $it.IsSelected = $true
      }
    }
  } finally { $script:SuppressSelectionEvents = $false }
  UI-Log "Applied auto profile: $p (clearFirst=$ClearFirst, onlyMissing=$OnlyMissing)"
  Update-FilterAndStats
}

if($CmbAutoProfile){
  $CmbAutoProfile.Add_SelectionChanged({
    $p = [string]$CmbAutoProfile.SelectedItem
    if($TxtAutoProfileDesc){ $TxtAutoProfileDesc.Text = Get-ProfileDescription $p }
  }) | Out-Null
}

if($BtnApplyAutoProfile){
  $BtnApplyAutoProfile.Add_Click({
    $p = [string]$CmbAutoProfile.SelectedItem
    Apply-AutoProfileSelection -p $p -ClearFirst:([bool]$ChkProfileClearFirst.IsChecked) -OnlyMissing:([bool]$ChkProfileOnlyMissing.IsChecked)
  }) | Out-Null
}

if($BtnSelectRecommendedMissing){
  $BtnSelectRecommendedMissing.Add_Click({
    $script:SuppressSelectionEvents = $true
    try {
      foreach($it in $items){
        if($it.Default -and (-not $it.IsInstalled) -and $it.IsSelectable){
          $it.IsSelected = $true
        }
      }
    } finally { $script:SuppressSelectionEvents = $false }
    UI-Log "Selected recommended missing apps (Default=true & not installed)."
    Update-FilterAndStats
  }) | Out-Null

if($BtnSmartRecommend){
  $BtnSmartRecommend.Add_Click({
    $script:SuppressSelectionEvents = $true
    try {
      # baseline essentials
      $want = New-Object System.Collections.Generic.HashSet[string]
      foreach($p in @('Minimal')){ [void]$want.Add($p) }

      # light heuristics
      try {
        if(Get-Command code -ErrorAction SilentlyContinue){ [void]$want.Add('Dev') }
        if(Get-Command git -ErrorAction SilentlyContinue){ [void]$want.Add('Dev') }
        if(Test-Path "$env:ProgramFiles(x86)\Steam" -or (Test-Path "$env:ProgramFiles\Steam")){ [void]$want.Add('Gaming') }
        if(Test-Path "$env:ProgramFiles\Microsoft Office" -or (Test-Path "$env:ProgramFiles(x86)\Microsoft Office")){ [void]$want.Add('Office') }
        if(Get-Command obs64 -ErrorAction SilentlyContinue){ [void]$want.Add('Creator') }
      } catch {}

      foreach($it in $items){
        if($it.IsInstalled){ continue }
        if(-not $it.IsSelectable){ continue }
        if($it.Skip){ continue }
        $tags = @($it.Profiles)
        $match = $false
        foreach($t in $want){ if($tags -contains $t){ $match = $true; break } }
        if($match -and ($it.Default -or ($it.Category -match 'Browsers|Utilities|Password|Notes|Media|Development|Remote'))){
          $it.IsSelected = $true
        }
      }
    } finally { $script:SuppressSelectionEvents = $false }

    UI-Log ("Smart recommend selected missing apps for: " + (($want | Sort-Object) -join ', '))
    Update-FilterAndStats
  }) | Out-Null
}
}

# ------------
# Share profile token + QR + placeholder link
# ------------
$script:LastShareObj = $null
$BtnShare.Add_Click({
  $obj = Export-SelectionObject $items
  $token = Encode-ShareToken $obj
  $TxtShareToken.Text = $token
  # Placeholder link stub (future cutur.link integration)
  $TxtShareUrl.Text = "https://cutur.link/<placeholder>"
  $script:LastShareObj = $obj

  UI-Log "Share token generated (len=$($token.Length))."
  $qrPath = Get-QRImageFromToken $token
  if($qrPath){
    try {
      $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
      $bmp.BeginInit()
      $bmp.UriSource = New-Object Uri($qrPath)
      $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $bmp.EndInit()
      $ImgQR.Source = $bmp
    } catch {}
  } else {
    $ImgQR.Source = $null
    UI-Log "QR image not available (offline or request blocked)."
  }
}) | Out-Null

$BtnCopyToken.Add_Click({ if($TxtShareToken.Text){ [System.Windows.Clipboard]::SetText($TxtShareToken.Text) } }) | Out-Null
$BtnCopyLink.Add_Click({ if($TxtShareUrl.Text){ [System.Windows.Clipboard]::SetText($TxtShareUrl.Text) } }) | Out-Null
$BtnSaveSharePayload.Add_Click({
  if(-not $script:LastShareObj){ Show-Message "Generate a token first." '47Project' 'Warning'; return }
  $stamp = Get-NowStamp
  $path = Join-Path $ExportsDir ("share_payload_$stamp.json")
  Write-JsonFile $path $script:LastShareObj
  UI-Log "Share payload saved: $path"
  Open-ExplorerSelect $path
}) | Out-Null

# ------------
# USB Pack export/import
# ------------
function Choose-Folder([string]$desc){
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = $desc
  if($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ return $dlg.SelectedPath }
  return $null
}

$BtnExportPack.Add_Click({
  $dest = Choose-Folder "Choose destination folder/USB for pack export"
  if(-not $dest){ return }
  $pack = Join-Path $dest ("47Project_AppPack_" + (Get-NowStamp))
  New-Item -ItemType Directory -Path $pack -Force | Out-Null
  foreach($p in @(@{src=$DownloadsDir; name='downloads'}, @{src=$ProfilesDir; name='profiles'}, @{src=$ExportsDir; name='exports'}, @{src=$SettingsPath; name='settings.json'}, @{src=$MetaDir; name='hashes'})){
    try {
      $target = Join-Path $pack $p.name
      if(Test-Path -LiteralPath $p.src){
        Copy-Item -LiteralPath $p.src -Destination $target -Recurse -Force
      }
    } catch {}
  }
  Set-Content -LiteralPath (Join-Path $pack 'README.txt') -Value "47Project AppS Crawler Pack. Import it via the Pack tab." -Encoding UTF8
  UI-Log "Pack exported: $pack"
  Open-Explorer $pack
}) | Out-Null

$BtnImportPack.Add_Click({
  $src = Choose-Folder "Choose a previously exported pack folder"
  if(-not $src){ return }
  $profiles = Join-Path $src 'profiles'
  if(Test-Path -LiteralPath $profiles){
    Copy-Item -LiteralPath (Join-Path $profiles '*') -Destination $ProfilesDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  $dl = Join-Path $src 'downloads'
  if(Test-Path -LiteralPath $dl){
    $msg = "Use pack downloads folder as current downloads folder?`n$dl"
    $res = [System.Windows.MessageBox]::Show($msg,'47Project',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
    if($res -eq [System.Windows.MessageBoxResult]::Yes){
      $script:OverrideDownloadDir = $dl
      UI-Log "Downloads source set to pack folder: $dl"
    }
  }
  UI-Log "Pack imported."
  Open-Explorer $ProfilesDir
}) | Out-Null

# ------------
# Help, SelfUpdate, Project link
# ------------
$Btn47Project.Add_Click({ Start-Process "https://47.bearguard.cloud/47project" | Out-Null }) | Out-Null
$BtnSelfUpdate.Add_Click({ Do-SelfUpdate -Log ${function:UI-Log} }) | Out-Null
$BtnHelp.Add_Click({ Show-Message $HelpText '47Project' 'Info' }) | Out-Null

# ------------
# Scan installed apps (background, freeze-safe)
# ------------
$script:WingetMap = @{}
$script:ChocoMap  = @{}
$script:RegNameMap = @{}
$script:RegNormMap = @{}

function Normalize-AppKey([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return "" }
  return ($s -replace '[^a-zA-Z0-9]','').ToLowerInvariant()
}

function Apply-InstalledStatus {
  foreach($it in $items){
    $installed = $false
    $reason = 'Not detected'

    $ver = ""
    if($it.WingetId){
      $k = $it.WingetId.ToLowerInvariant()
      if($script:WingetMap.ContainsKey($k)){
        $installed = $true; $reason = 'winget list match'
        $v = $script:WingetMap[$k]
        if($v -and -not ($v -is [bool])){ $ver = [string]$v }
      }
    }
    if(-not $installed -and $it.ChocoId){
      $k = $it.ChocoId.ToLowerInvariant()
      if($script:ChocoMap.ContainsKey($k)){
        $installed = $true; $reason = 'choco list match'
        $v = $script:ChocoMap[$k]
        if($v -and -not ($v -is [bool])){ $ver = [string]$v }
      }
    }
    if(-not $installed){
      # Registry uninstall detection (enterprise-safe fallback)
      $nm = [string]$it.Name
      if($nm){
        $k1 = $nm.ToLowerInvariant()
        if($script:RegNameMap -and $script:RegNameMap.ContainsKey($k1)){
          $installed = $true; $reason = 'registry display-name exact'
          $ver = [string]$script:RegNameMap[$k1]
        } else {
          $nk = Normalize-AppKey $nm
          if($nk -and $script:RegNormMap -and $script:RegNormMap.ContainsKey($nk)){
            $installed = $true; $reason = 'registry normalized match'
            $info = $script:RegNormMap[$nk]
            if($info -and $info.PSObject.Properties['Version']){ $ver = [string]$info.Version }
          } elseif($k1.Length -ge 5 -and $script:RegNameMap){
            $re = '\\b' + [regex]::Escape($k1) + '\\b'
            foreach($dn in $script:RegNameMap.Keys){
              if($dn -match $re){
                $installed = $true; $reason = 'registry word-boundary match'
                $ver = [string]$script:RegNameMap[$dn]
                break
              }
            }
          }
        }
      }
    }

    # Extra fuzzy registry match (helps cases like 'Brave Browser' vs 'Brave')
    if(-not $installed){
      try {
        $nm2 = [string]$it.Name
        $nk2 = Normalize-AppKey $nm2
        if($nk2 -and $script:RegNormMap){
          foreach($rk in $script:RegNormMap.Keys){
            if([string]::IsNullOrWhiteSpace($rk)){ continue }
            if(($rk.Length -ge 4 -and $nk2.Length -ge 4) -and (($rk -like ('*' + $nk2 + '*')) -or ($nk2 -like ('*' + $rk + '*')))) {
              $installed = $true
              $reason = 'registry fuzzy match'
              $info2 = $script:RegNormMap[$rk]
              if($info2 -and $info2.PSObject.Properties['Version']){ $ver = [string]$info2.Version }
              break
            }
          }
        }
      } catch {}
    }
    $it.DetectReason = $reason
    $it.IsInstalled = $installed
    $it.InstalledVersion = $ver
    try { $it.StatusTip = ('Installed: ' + $installed + ' | ' + $reason + ($(if($ver){' | Version: ' + $ver}else{''}))) } catch {}
# keep include-installed flag synced with the UI and compute selectability
$inc = [bool]$ChkIncludeInstalled.IsChecked
$it.IncludeInstalledFlag = $inc
$it.IsSelectable = ($inc -or (-not $installed))

# auto-uncheck defaults (and any installed) if installed apps are locked
if($installed -and (-not $inc)){ $it.IsSelected = $false }
if($it.Default -and $installed){ $it.IsSelected = $false }
  }
  Apply-SessionSelection
  Update-FilterAndStats
  Update-Preview
}

function Apply-SessionSelection {
  try {
    if(-not $script:SessionSelectedKeys){ return }
    if($script:SessionSelectedKeys.Count -eq 0){ return }
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach($k in $script:SessionSelectedKeys){ if($k){ [void]$set.Add(([string]$k).ToLowerInvariant()) } }
    foreach($it in $items){
      $key = $null
      if($it.WingetId){ $key = 'winget:' + ([string]$it.WingetId).ToLowerInvariant() }
      elseif($it.ChocoId){ $key = 'choco:' + ([string]$it.ChocoId).ToLowerInvariant() }
      else { $key = 'name:' + (Normalize-AppKey ([string]$it.Name)) }

      if($key -and $set.Contains($key)){
        if($it.IsSelectable){ $it.IsSelected = $true }
      } else {
        # don't force false if user is actively interacting; only restore positives
      }
    }
    Update-FilterAndStats
    Update-Preview
  } catch {}
}


function Start-Scan {
  $TxtStatus.Text = "Scanning installed apps..."
  UI-Log "Scan start."
  $Prg.Value = 0
  $Prg.Maximum = 100

  # Ensure script-scoped holders exist (avoids StrictMode '$handle' errors)
  if (-not (Get-Variable -Name ScanPS -Scope Script -EA SilentlyContinue))      { $script:ScanPS = $null }
  if (-not (Get-Variable -Name ScanHandle -Scope Script -EA SilentlyContinue))  { $script:ScanHandle = $null }
  if (-not (Get-Variable -Name ScanTimer -Scope Script -EA SilentlyContinue))   { $script:ScanTimer = $null }

  # Clean any previous scan
  try {
    if ($script:ScanTimer) { $script:ScanTimer.Stop(); $script:ScanTimer = $null }
  } catch {}
  try {
    if ($script:ScanPS) { $script:ScanPS.Dispose() }
  } catch {}
  $script:ScanPS = $null
  $script:ScanHandle = $null

  $script:ScanPS = [PowerShell]::Create()
  $script:ScanPS.AddScript({
      param($hasWinget,$hasChoco,$doReg)
      $res = [pscustomobject]@{ wing=@{}; choco=@{}; regName=@{}; regNorm=@{} }

      if($hasWinget){
        try {
          $out = & winget list --disable-interactivity 2>$null
          foreach($line in ($out -split "`r?`n")){
            if($line -match '\s([A-Za-z0-9]+\.[A-Za-z0-9\.\-]+)\s+([0-9][0-9A-Za-z\.\-\+]+)'){
              $id = $Matches[1]
              $ver = $Matches[2]
              if($id){ $res.wing[$id.ToLowerInvariant()] = $ver }
            }
          }
        } catch {}
      }

      if($hasChoco){
        try {
          $out = & choco list --local-only --limit-output 2>$null
          foreach($line in ($out -split "`r?`n")){
            if($line -match '^([A-Za-z0-9\.\-_]+)\|(.+)$'){
              $id = $Matches[1]
              $ver = $Matches[2]
              $res.choco[$id.ToLowerInvariant()] = $ver
            }
          }
        } catch {}
      }

      if($doReg){
        function _norm([string]$s){
          if([string]::IsNullOrWhiteSpace($s)){ return "" }
          return (($s -replace '[^a-zA-Z0-9]','').ToLowerInvariant())
        }
        $paths = @(
          'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
          'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        foreach($p in $paths){
          try {
            $rows = Get-ItemProperty -Path $p -EA SilentlyContinue
            foreach($r in $rows){
              $dn = [string]$r.DisplayName
              if([string]::IsNullOrWhiteSpace($dn)){ continue }
              $ver = [string]$r.DisplayVersion
              $k = $dn.ToLowerInvariant()
              if(-not $res.regName.ContainsKey($k)){ $res.regName[$k] = $ver }
              $nk = _norm $dn
              if($nk -and -not $res.regNorm.ContainsKey($nk)){
                $res.regNorm[$nk] = [pscustomobject]@{
                  Name = $dn
                  Version = $ver
                  Publisher = [string]$r.Publisher
                  InstallLocation = [string]$r.InstallLocation
                }
              }
            }
          } catch {}
        }
      }

      return $res
    }) | Out-Null
  $script:ScanPS.AddArgument([bool](Get-Command winget -EA SilentlyContinue)) | Out-Null
  $script:ScanPS.AddArgument([bool](Get-Command choco -EA SilentlyContinue)) | Out-Null
  $script:ScanPS.AddArgument($true) | Out-Null

  $script:ScanHandle = $script:ScanPS.BeginInvoke()

  $script:ScanTimer = New-Object Windows.Threading.DispatcherTimer
  $script:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(200)
  $script:ScanTimer.Add_Tick({
    # Use script scope to avoid closure/StrictMode edge cases
    if(($null -ne $script:ScanHandle) -and $script:ScanHandle.IsCompleted){
      $script:ScanTimer.Stop()
      try {
        $r = $script:ScanPS.EndInvoke($script:ScanHandle)
        $script:WingetMap = $r.wing
        $script:ChocoMap  = $r.choco
        $script:RegNameMap = $r.regName
        $script:RegNormMap = $r.regNorm
        UI-Log "Scan complete: winget=$($script:WingetMap.Count) choco=$($script:ChocoMap.Count) reg=$($script:RegNameMap.Count)"
      } catch {
        UI-Log "Scan failed: $($_.Exception.Message)"
      } finally {
        try { $script:ScanPS.Dispose() } catch {}
        $script:ScanPS = $null
        $script:ScanHandle = $null
      }

      Apply-InstalledStatus
      $TxtStatus.Text = "Ready."
      $Prg.Value = 0
      Update-FilterAndStats
      Update-Preview
    } else {
      $Prg.Value = ($Prg.Value + 3) % 100
    }
  }) | Out-Null

  $script:ScanTimer.Start()
}


# ------------
# Scan available updates (optional; runs on-demand; cached)
# ------------
$script:UpdatesAvailableCount = -1
$script:UpdateScanResults = @()
$script:UpdateScanCacheTime = $null

$script:DownloadByCategory = $false
function Get-EffectiveMethod([object]$it){
  $pref = ''
  if($it -and $it.PSObject.Properties['PreferredMethod']){ $pref = [string]$it.PreferredMethod }
  if($pref -and $pref -ne 'Auto'){ return $pref.Trim().ToLowerInvariant() }
  if($it -and $it.PSObject.Properties['RecommendedMethod'] -and $it.RecommendedMethod){ return ([string]$it.RecommendedMethod).Trim().ToLowerInvariant() }
  if($it -and $it.PSObject.Properties['Method'] -and $it.Method){ return ([string]$it.Method).Trim().ToLowerInvariant() }
  if($it -and $it.WingetId){ return 'winget' }
  if($it -and $it.ChocoId){ return 'choco' }
  return 'download'
}

function Apply-UpdateScanResults {
  param($results)
  if($null -eq $results){ $results = @() }
  $script:UpdateScanResults = @($results)

  foreach($it in $items){
    $it.UpdateAvailable = $false
    $it.AvailableVersion = ""
  }

  $mapWing = @{}
  $mapChoco = @{}
  foreach($u in $script:UpdateScanResults){
    if($u -and $u.Method -eq 'winget' -and $u.Id){ $mapWing[[string]$u.Id.ToLowerInvariant()] = $u }
    if($u -and $u.Method -eq 'choco' -and $u.Id){ $mapChoco[[string]$u.Id.ToLowerInvariant()] = $u }
  }

  foreach($it in $items){
    if($it.WingetId){
      $k = [string]$it.WingetId.ToLowerInvariant()
      if($mapWing.ContainsKey($k)){
        $it.UpdateAvailable = $true
        $it.AvailableVersion = [string]$mapWing[$k].Available
      }
    } elseif($it.ChocoId){
      $k = [string]$it.ChocoId.ToLowerInvariant()
      if($mapChoco.ContainsKey($k)){
        $it.UpdateAvailable = $true
        $it.AvailableVersion = [string]$mapChoco[$k].Available
      }
    }
  }

  $script:UpdatesAvailableCount = @($items | Where-Object { $_.UpdateAvailable }).Count
  try { Update-FooterBadges } catch {}
  try { Update-FilterAndStats } catch {}

  if($LstUpdates){
    $lines = New-Object System.Collections.Generic.List[string]
    if($script:UpdateScanResults.Count -eq 0){
      $lines.Add("No updates found (or scan not run).")
    } else {
      foreach($u in $script:UpdateScanResults | Sort-Object Method,Name){
        $m = [string]$u.Method
        $lines.Add(("{0}  {1}  {2} -> {3}" -f $m.PadRight(6), $u.Name, $u.Current, $u.Available))
      }
    }
    $LstUpdates.ItemsSource = $lines
  }
}

function Start-UpdateScan {
  param([switch]$Force)

  $hasWing = [bool](Get-Command winget -ErrorAction SilentlyContinue)
  $hasCh  = [bool](Get-Command choco  -ErrorAction SilentlyContinue)

  if(-not $hasWing -and -not $hasCh){
    Show-Message "Neither winget nor chocolatey were found. Install one of them, then scan again." '47Project' 'Info'
    return
  }

  if($TxtStatus){ $TxtStatus.Text = "Scanning available updates..." }
  UI-Log "Update scan start."

  if(-not $Force -and $script:UpdateScanCacheTime -and ((Get-Date) - $script:UpdateScanCacheTime).TotalMinutes -lt 10){
    UI-Log "Update scan: using cache."
    Apply-UpdateScanResults $script:UpdateScanResults
    if($TxtStatus){ $TxtStatus.Text = "Ready." }
    return
  }

  try { if($script:UpdScanTimer){ $script:UpdScanTimer.Stop(); $script:UpdScanTimer = $null } } catch {}
  try { if($script:UpdScanPS){ $script:UpdScanPS.Dispose() } } catch {}
  $script:UpdScanPS = $null
  $script:UpdScanHandle = $null

  $script:UpdScanPS = [PowerShell]::Create()
  $script:UpdScanPS.AddScript({
    param($hasWinget,$hasChoco)

    function Run-ExeTimeout([string]$exe, [string]$args, [int]$timeoutSec){
      try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = $args
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while(-not $p.HasExited){
          Start-Sleep -Milliseconds 150
          if($sw.Elapsed.TotalSeconds -ge $timeoutSec){
            try { $p.Kill() } catch {}
            break
          }
        }

        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        return ($out + "`n" + $err)
      } catch { return "" }
    }

    $results = New-Object System.Collections.Generic.List[object]

    if($hasWinget){
      $txt = Run-ExeTimeout "winget" "upgrade --disable-interactivity --accept-source-agreements" 25
      $lines = $txt -split "`r?`n"
      $started = $false
      foreach($ln in $lines){
        if(-not $started){
          if($ln -match '^-{3,}'){ $started = $true; continue }
          if($ln -match '^\s*Name\s+Id\s+Version'){ continue }
          continue
        }
        if([string]::IsNullOrWhiteSpace($ln)){ continue }
        $parts = $ln -split '\s{2,}'
        if($parts.Count -ge 4){
          $name = $parts[0].Trim()
          $id   = $parts[1].Trim()
          $cur  = $parts[2].Trim()
          $av   = $parts[3].Trim()
          if($id){
            $results.Add([pscustomobject]@{ Method='winget'; Name=$name; Id=$id; Current=$cur; Available=$av })
          }
        }
      }
    }

    if($hasChoco){
      $txt = Run-ExeTimeout "choco" "outdated --limit-output" 25
      foreach($ln in ($txt -split "`r?`n")){
        if($ln -match '^([A-Za-z0-9\.\-_]+)\|([^|]+)\|([^|]+)'){
          $id = $Matches[1]; $cur=$Matches[2]; $av=$Matches[3]
          $results.Add([pscustomobject]@{ Method='choco'; Name=$id; Id=$id; Current=$cur; Available=$av })
        }
      }
    }

    return ,$results
  }) | Out-Null

  $script:UpdScanPS.AddArgument($hasWing) | Out-Null
  $script:UpdScanPS.AddArgument($hasCh)  | Out-Null
  $script:UpdScanHandle = $script:UpdScanPS.BeginInvoke()

  $script:UpdScanTimer = New-Object Windows.Threading.DispatcherTimer
  $script:UpdScanTimer.Interval = [TimeSpan]::FromMilliseconds(250)
  $script:UpdScanTimer.Add_Tick({
    if(($null -ne $script:UpdScanHandle) -and $script:UpdScanHandle.IsCompleted){
      $script:UpdScanTimer.Stop()
      try {
        $r = $script:UpdScanPS.EndInvoke($script:UpdScanHandle)
        $arr = @($r)
        $script:UpdateScanCacheTime = Get-Date
        UI-Log "Update scan complete: $($arr.Count) items"
        Apply-UpdateScanResults $arr
      } catch {
        UI-Log "Update scan failed: $($_.Exception.Message)"
        Apply-UpdateScanResults @()
      } finally {
        try { $script:UpdScanPS.Dispose() } catch {}
        $script:UpdScanPS = $null
        $script:UpdScanHandle = $null
      }
      if($TxtStatus){ $TxtStatus.Text = "Ready." }
      if($Prg){ $Prg.Value = 0 }
    } else {
      if($Prg){ $Prg.Value = ($Prg.Value + 5) % 100 }
    }
  }) | Out-Null
  $script:UpdScanTimer.Start()
}

function Export-UpdateReport {
  if(-not $script:UpdateScanResults -or $script:UpdateScanResults.Count -eq 0){
    Show-Message "No update scan results yet. Click 'Scan available updates' first." '47Project' 'Info'
    return
  }
  $stamp = Get-NowStamp
  $jsonPath = Join-Path $ExportsDir ("updates_" + $stamp + ".json")
  $csvPath  = Join-Path $ExportsDir ("updates_" + $stamp + ".csv")
  Write-JsonFile $jsonPath @{ scannedAt = (Get-Date).ToString("s"); results = @($script:UpdateScanResults) }
  $script:UpdateScanResults | Select-Object Method,Name,Id,Current,Available | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $csvPath
  UI-Log "Exported update report: $jsonPath"
  Open-ExplorerSelect $jsonPath
}

function Preview-UpdateCommands {
  if(-not $script:UpdateScanResults -or $script:UpdateScanResults.Count -eq 0){
    Show-Message "No update scan results yet. Click 'Scan available updates' first." '47Project' 'Info'
    return
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $targets = @($items | Where-Object { $_.UpdateAvailable -and -not $_.ExcludeUpdate })

  if($targets.Count -eq 0){
    $lines.Add("No updatable targets (or excluded).")
    $LstUpdates.ItemsSource = $lines
    return
  }

  foreach($it in ($targets | Sort-Object Name)){
    $method = Get-EffectiveMethod $it
    if($method -eq 'winget' -and $it.WingetId){
      $lines.Add("winget upgrade --id " + $it.WingetId + " --disable-interactivity --accept-package-agreements --accept-source-agreements")
    } elseif($method -eq 'choco' -and $it.ChocoId){
      $lines.Add("choco upgrade " + $it.ChocoId + " -y")
    } else {
      $lines.Add("UPDATE (manual): " + $it.Name)
    }
  }

  $LstUpdates.ItemsSource = $lines
}

# Buttons
if($BtnScanUpdates){ $BtnScanUpdates.Add_Click({ Start-UpdateScan }) | Out-Null }
if($BtnExportUpdateReport){ $BtnExportUpdateReport.Add_Click({ Export-UpdateReport }) | Out-Null }
if($BtnPreviewUpdateCommands){ $BtnPreviewUpdateCommands.Add_Click({ Preview-UpdateCommands }) | Out-Null }

if($BtnUpdateAllAvailable){
  $BtnUpdateAllAvailable.Add_Click({
    if(-not $script:UpdateScanResults -or $script:UpdateScanResults.Count -eq 0){
      Show-Message "No update scan results yet. Click 'Scan available updates' first." '47Project' 'Info'
      return
    }

    if(-not $ChkIncludeInstalled.IsChecked){ $ChkIncludeInstalled.IsChecked = $true }

    $script:SuppressSelectionEvents = $true
    try {
      foreach($it in $items){
        $it.IsSelected = ($it.UpdateAvailable -and -not $it.ExcludeUpdate)
      }
    } finally { $script:SuppressSelectionEvents = $false }

    Update-FilterAndStats
    Update-Preview
    Run-Queue -mode 'update'
  }) | Out-Null
}

# Tools: install choco now
if($BtnInstallChocoNow){
  $BtnInstallChocoNow.Add_Click({
    $ok = Ensure-Choco ${function:UI-Log} ${function:UI-Log}
    if($ok){ UI-Log "Chocolatey ready."; } else { UI-Log "Chocolatey not installed." }
    try { Update-FooterBadges } catch {}
  }) | Out-Null
}

if($BtnOpenExportsFolder){
  $BtnOpenExportsFolder.Add_Click({ Open-Explorer $ExportsDir }) | Out-Null
}

if($BtnEnterpriseCenter){
  $BtnEnterpriseCenter.Add_Click({ Show-EnterpriseCenter }) | Out-Null
}



if($BtnEnterpriseTop){
  $BtnEnterpriseTop.Add_Click({ Show-EnterpriseCenter }) | Out-Null
}
# Tools: downloads management
if($BtnOpenDownloadsFolder){
  $BtnOpenDownloadsFolder.Add_Click({ Open-Explorer $DownloadsDir }) | Out-Null
}
if($BtnVerifyDownloads){
  $BtnVerifyDownloads.Add_Click({ Verify-Downloads }) | Out-Null
}
if($BtnClearDownloadsAll){
  $BtnClearDownloadsAll.Add_Click({
    $res = [System.Windows.MessageBox]::Show("Clear ALL downloaded files and metadata?`n`nThis deletes everything under:`n$DownloadsDir","47Project",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
    if($res -eq [System.Windows.MessageBoxResult]::Yes){
      Clear-DownloadsAll
      UI-Log "Downloads cleared (all)."
    }
  }) | Out-Null
}
if($BtnClearDownloadsSelected){
  $BtnClearDownloadsSelected.Add_Click({
    $sel = @($items | Where-Object { $_.IsSelected })
    if($sel.Count -eq 0){ Show-Message "No apps selected." '47Project' 'Info'; return }
    $res = [System.Windows.MessageBox]::Show("Clear downloads for $($sel.Count) selected app(s)?","47Project",[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question)
    if($res -eq [System.Windows.MessageBoxResult]::Yes){
      Clear-DownloadsForApps -Apps $sel
      UI-Log "Downloads cleared (selected)."
    }
  }) | Out-Null
}
if($BtnRedownloadCorrupted){
  $BtnRedownloadCorrupted.Add_Click({
    $dry = $false
    if($ChkDryRun){ $dry = [bool]$ChkDryRun.IsChecked }
    Redownload-Corrupted -DryRun:$dry
  }) | Out-Null
}
if($ChkDownloadByCategory){
  # Keep in sync with settings + runtime flag
  $ChkDownloadByCategory.Add_Checked({ $script:DownloadByCategory = $true; Save-Settings }) | Out-Null
  $ChkDownloadByCategory.Add_Unchecked({ $script:DownloadByCategory = $false; Save-Settings }) | Out-Null
}

# Pack: offline manifest
if($BtnExportOfflineManifest){
  $BtnExportOfflineManifest.Add_Click({
    $sel = @($items | Where-Object { $_.IsSelected })
    if($sel.Count -eq 0){ Show-Message "Select apps first." '47Project' 'Info'; return }
    Export-OfflineManifest -Apps $sel
  }) | Out-Null
}



$BtnScan.Add_Click({ if(-not $script:SafeModeOn){ Start-Scan } else { Show-Message "Safe mode: click Scan when ready (or disable safe mode)." '47Project' 'Info'; Start-Scan } }) | Out-Null

# ------------
# Actions Preview
# ------------
function Build-PreviewLines([string]$mode){
  $lines = New-Object System.Collections.Generic.List[string]
  $sel = @($items | Where-Object { $_.IsSelected })
  if($sel.Count -eq 0){ $lines.Add("No apps selected."); return $lines }

  foreach($it in $sel){
    $verNote = ""
    if($it.IsInstalled -and $it.InstalledVersion){ $verNote = " v:$($it.InstalledVersion)" }
    $recNote = ""
    if($it.RecommendedMethod){ $recNote = " rec:$($it.RecommendedMethod)" }

    switch($mode){
      'install'   { $lines.Add("$($it.Name)$recNote$verNote") }
      'update'    { $lines.Add("UPDATE: $($it.Name)$verNote") }
      'download'  { $lines.Add("DOWNLOAD: $($it.Name)") }
      'uninstall' { $lines.Add("UNINSTALL(managed): $($it.Name)") }
      default     { $lines.Add("$($it.Name)") }
    }
  }
  return $lines
}

function Update-Preview {
  # infer current mode from last clicked? show generic
  $lines = New-Object System.Collections.Generic.List[string]
  $sel = @($items | Where-Object { $_.IsSelected })
  $lines.Add("Selected apps: $($sel.Count)")
  $lines.Add("DryRun: $([bool]$ChkDryRun.IsChecked)  InstallMode: $([string]$CmbInstallMode.SelectedItem)")
  $lines.Add("----")
  foreach($it in $sel | Select-Object -First 120){
    $id = if($it.WingetId){ "winget:$($it.WingetId)" } elseif($it.ChocoId){ "choco:$($it.ChocoId)" } else { $it.Method }
    $lines.Add("$($it.Name) [$id]")
  }
  if($sel.Count -gt 120){ $lines.Add("...") }
  $LstPreview.ItemsSource = $lines
}
Update-Preview
Update-StatsOnly
Apply-Sort

# ------------
# Run queue (install/update/download/uninstall)
# ------------
function Get-SelectedApps([switch]$IncludeInstalledForUpdate){
  $sel = @($items | Where-Object { $_.IsSelected })
  if($IncludeInstalledForUpdate){
    # allow installed when include installed off for updates: user asked update system, so we can keep them selectable via toggle
    return $sel
  }
  return $sel
}

function Run-Queue([string]$mode,[switch]$AllInstalledCatalog){
  if($script:SafeModeOn -and $mode -eq 'uninstall'){ Show-Message 'Safe mode: Uninstall is disabled.' '47Project' 'Warning'; return }
  $dry = [bool]$ChkDryRun.IsChecked
  $installMode = [string]$CmbInstallMode.SelectedItem
  $onlyUpdInstalled = [bool]$ChkOnlyUpdateInstalled.IsChecked
  $contErrors = [bool]$ChkContinueOnErrors.IsChecked
  $skipAdmin = [bool]$ChkSkipAdmin.IsChecked
  $parallelDl = [bool]$ChkParallelDl.IsChecked
  $thr = [int]([string]$CmbConcurrency.SelectedItem)

  $downloadDir = if($script:OverrideDownloadDir){ $script:OverrideDownloadDir } else { $DownloadsDir }

  $target = @()
  if($AllInstalledCatalog){
    if($mode -eq 'update'){
      $target = @($items | Where-Object { $_.IsInstalled -and $_.IsUpdateable })
    } elseif($mode -eq 'uninstall'){
      $target = @($items | Where-Object { $_.IsInstalled -and $_.IsUpdateable })
    } else {
      $target = @($items | Where-Object { $_.IsInstalled })
    }
  } else {
    $target = @($items | Where-Object { $_.IsSelected })
  }

  if($target.Count -eq 0){
    Show-Message "Nothing to run." '47Project' 'Info'
    return
  }


  # Expand dependencies (safe) and order queue so dependencies run first
  try {
    $exp = Expand-Dependencies -Target $target -AllItems $items
    if($exp.Added.Count -gt 0){
      UI-Log ("Dependencies auto-added: " + (($exp.Added | Select-Object -ExpandProperty Name) -join ', '))
    }
    $target = @($exp.Target)
    $target = @(Sort-ByDependencies -Target $target -AllItems $items)
  } catch {}
  # Mode-specific filtering
  if($script:SafeModeOn){ $target = @($target | Where-Object { $_.Method -match '^(winget|choco)$' }) }
  if($mode -eq 'update' -and $onlyUpdInstalled){
    $target = @($target | Where-Object { $_.IsInstalled })
  }
  if($mode -eq 'update'){
    $target = @($target | Where-Object { -not $_.ExcludeUpdate })
  }
  if($mode -eq 'uninstall'){
    # managed only: require winget/choco id
    $target = @($target | Where-Object { $_.IsInstalled -and $_.IsUpdateable })
    if($target.Count -eq 0){
      Show-Message "No managed installed apps to uninstall (winget/choco only)." '47Project' 'Warning'
      return
    }
    $warn = "WARNING: Uninstall can remove user data or shared components.`n`nProceed?"
    $res = [System.Windows.MessageBox]::Show($warn,'47Project',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
    if($res -ne [System.Windows.MessageBoxResult]::Yes){ return }
  }

  # Admin-needed skip
  if($skipAdmin -and -not (Test-IsAdmin)){
    $target = @($target | Where-Object { -not $_.NeedsAdmin })
  }

  # Tool availability checks (best-effort)
  $needWinget = @($target | Where-Object { ($_.Method -eq 'winget') -or ($_.PreferredMethod -eq 'winget') -or $_.WingetId }).Count -gt 0
  $needChoco  = @($target | Where-Object { ($_.Method -eq 'choco') -or ($_.PreferredMethod -eq 'choco') -or $_.ChocoId }).Count -gt 0
  if($needWinget){
    if(-not (Ensure-Winget)){
      Show-Message "winget not detected. Install 'App Installer' from Microsoft Store, then retry." '47Project' 'Warn'
      # Remove winget-only apps from queue
      $target = @($target | Where-Object { -not (($_.Method -eq 'winget') -or ($_.PreferredMethod -eq 'winget')) })
    }
  }
  if($needChoco){
    if(-not (Get-Command choco -ErrorAction SilentlyContinue)){
      UI-Log "Chocolatey missing. Attempting install..."
      if(-not (Ensure-Choco)){
        Show-Message "Chocolatey install failed. Choco actions will be skipped." '47Project' 'Warn'
        $target = @($target | Where-Object { -not (($_.Method -eq 'choco') -or ($_.PreferredMethod -eq 'choco')) })
      }
    }
  }
  # Enterprise controls: denylist / method lock (keeps main UI safe)
  try {
    if($script:Enterprise){
      # Denylist blocks (name/id fragments)
      if($script:Enterprise.denylist -and $script:Enterprise.denylist.Count -gt 0){
        $deny = @($script:Enterprise.denylist | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
        if($deny.Count -gt 0){
          $target = @($target | Where-Object {
            $k = ("$($_.Name) $($_.WingetId) $($_.ChocoId)").ToLowerInvariant()
            -not ($deny | Where-Object { $k -like ("*" + $_ + "*") } | Select-Object -First 1)
          })
        }
      }

      # Lock mode: allow only specific methods
      if([bool]$script:Enterprise.lock){
        $allowed = @($script:Enterprise.allowedMethods | ForEach-Object { ([string]$_).ToLowerInvariant().Trim() } | Where-Object { $_ })
        if($allowed.Count -gt 0){
          $before = $target.Count
          $target = @($target | Where-Object {
            $m = $_.Method
            if($_.PreferredMethod -and $_.PreferredMethod -ne 'auto'){ $m = $_.PreferredMethod }
            $m = ([string]$m).ToLowerInvariant()
            $allowed -contains $m
          })
          $skipped = $before - $target.Count
          if($skipped -gt 0){ UI-Log "Enterprise lock: skipped $skipped items due to method policy." }
        }
      }
    }
  } catch {}



  # Optional restore point
  Try-CreateRestorePoint "47Project AppCrawler - $mode"

  # Build jobs
  $jobs = @()
  foreach($app in $target){
    $jobs += New-AppJob $app $mode
  }

  # Preview
  $LstPreview.ItemsSource = @("Queue: $mode ($($jobs.Count) jobs)") + ($jobs | ForEach-Object { "$($_.Mode.ToUpper()): $($_.App.Name)" })
  $TxtStatus.Text = "Running queue: $mode ($($jobs.Count))"
  UI-Log "Queue start: mode=$mode count=$($jobs.Count) dry=$dry installMode=$installMode"

  # Context template
  $ctxBase = [pscustomobject]@{
    DownloadDir = $downloadDir
    DownloadByCategory = [bool]$ChkDownloadByCategory.IsChecked
    InstallRoot = $InstallRoot
    DryRun = $dry
    InstallMode = $installMode
    Log = ${function:UI-Log}
    Ui  = { param($t) }
    LastDownloaded = $null
    App = $null
  }
  $script:CurrentCtx = $ctxBase

  # Parallel downloads stage (optional) for download/install modes
  if(($mode -eq 'download' -or $mode -eq 'install') -and $parallelDl){
    Start-ParallelDownloads -Apps $target -DownloadDir $downloadDir -Throttle $thr -ByCategory:([bool]$ChkDownloadByCategory.IsChecked) -DryRun:$dry -Log ${function:UI-Log} -UiProgress {
      param($i,$n,$name)
      $window.Dispatcher.Invoke([Action]{ $TxtStatus.Text = "Downloading ($i/$n): $name"; $Prg.Value = ($i*100.0)/$n }, [Windows.Threading.DispatcherPriority]::Background)
    }
  }

  # Run sequential job steps (safe)
  $Prg.Value = 0
  $Prg.Maximum = $jobs.Count
  $idx = 0
  $report = New-Object System.Collections.Generic.List[object]
  foreach($job in $jobs){
    $idx++
    $app = $job.App
    $script:CurrentCtx.App = $app
    $job.Started = Get-Date
    $job.Status = 'Running'
    $window.Dispatcher.Invoke([Action]{ 
      $TxtStatus.Text = "[$idx/$($jobs.Count)] $($mode.ToUpper()): $($app.Name)"
      $Prg.Value = $idx-1
    }, [Windows.Threading.DispatcherPriority]::Background)

    $ok = $true
    try {
      foreach($step in $job.Steps){
        UI-Log "Step: $($step.Kind) - $($app.Name)"
        $action = $step.Action
        $action.Invoke($script:CurrentCtx)
      }
      $job.Status = 'Succeeded'
    } catch {
      $ok = $false
      $job.Status = 'Failed'
      $job.Error = $_.Exception.Message
      UI-Log "Job failed: $($app.Name): $($job.Error)"
      if(-not $contErrors){ break }
    } finally {
      $job.Ended = Get-Date
      $report.Add([pscustomobject]@{
        app = $app.Name
        mode = $mode
        status = $job.Status
        error = $job.Error
        start = $job.Started.ToString('s')
        end   = $job.Ended.ToString('s')
      })
    }
  }

  $Prg.Value = $Prg.Maximum
  $TxtStatus.Text = "Queue done: $mode"
  UI-Log "Queue done: $mode"

  # Save run report
  $stamp = Get-NowStamp
  $repPath = Join-Path $ExportsDir ("run_report_$mode" + "_$stamp.json")
  Write-JsonFile $repPath $report
  UI-Log "Run report: $repPath"
  Open-ExplorerSelect $repPath

  # Refresh installed status after install/update/uninstall
  if(-not $script:SafeModeOn){ Start-Scan }
}

$BtnDownload.Add_Click({ Run-Queue -mode 'download' }) | Out-Null
$BtnInstall.Add_Click({ Run-Queue -mode 'install' }) | Out-Null
$BtnUpdate.Add_Click({ Run-Queue -mode 'update' }) | Out-Null
$BtnUpdateAllInstalled.Add_Click({ Run-Queue -mode 'update' -AllInstalledCatalog }) | Out-Null
$BtnUninstall.Add_Click({ Run-Queue -mode 'uninstall' }) | Out-Null
$BtnUninstallAll.Add_Click({ Run-Queue -mode 'uninstall' -AllInstalledCatalog }) | Out-Null

# Recommendations engine (local heuristic)
function Suggest-Apps {
  $selCats = @($items | Where-Object { $_.IsSelected } | Select-Object -ExpandProperty Category -Unique)
  $sug = @()
  if($selCats -contains 'Dev'){ $sug += 'Git'; $sug += 'Visual Studio Code' }
  if($selCats -contains 'Gaming'){ $sug += 'Discord'; $sug += 'Steam' }
  $sug = $sug | Select-Object -Unique
  return $sug
}

# Conflict guard (basic)
function Check-Conflicts([System.Collections.IEnumerable]$apps){
  $names = @($apps | ForEach-Object { $_.Name })
  $conf = @()
  if($names -contains 'Google Chrome' -and $names -contains 'Mozilla Firefox'){ $conf += "Multiple browsers selected (ok, just FYI)." }
  return $conf
}

# Before run, show conflicts (optional)
function PreRun-Warnings([string]$mode){
  $sel = @($items | Where-Object { $_.IsSelected })
  $conf = Check-Conflicts $sel
  if($conf.Count -gt 0){
    UI-Log ("Warnings: " + ($conf -join ' | '))
  }
}

# Hook run buttons to warnings
foreach($b in @($BtnDownload,$BtnInstall,$BtnUpdate,$BtnUninstall)){
  $b.Add_Click({ PreRun-Warnings -mode 'any' }) | Out-Null
}

# Safe mode behavior: disable auto scan on start
if(-not $script:SafeModeOn){
  Start-Scan
} else {
  UI-Log "Safe mode enabled. Scan is manual."
  $TxtStatus.Text = "Safe mode: click Scan when ready."
}

# Save settings on close
$window.Add_Closing({
  Save-Settings
}) | Out-Null

# Load settings at start
Load-Settings
Update-FilterAndStats
Apply-Compact

# Initial snapshot baseline for undo
$script:UndoStack.Add((Export-SelectionObject $items)) | Out-Null

# First run tour (simple)
$firstRunFlag = Join-Path $BaseDir '.firstrun'
if(-not (Test-Path -LiteralPath $firstRunFlag)){
  try {
    Set-Content -LiteralPath $firstRunFlag -Value "seen" -Encoding ASCII
    Show-Message "Welcome to 47Project AppS Crawler Suite.`n`nTip: Use Dry run + Actions Preview before running installs/updates." '47Project' 'Info'
  } catch {}
}

# Show window
try {
  $window.Topmost = $true
  $window.Add_ContentRendered({ Start-MatrixRain -Window $window; Refresh-CatalogSourcesUI; Refresh-HistoryUI; Refresh-PolicyPreview })
$window.Show()
  $window.Topmost = $false
  $window.Activate() | Out-Null
  $app = [System.Windows.Application]::Current
if(-not $app){ $app = New-Object System.Windows.Application }
$null = $app.Run($window)
} catch {
  try { Show-Message "Fatal UI error: $($_.Exception.Message)" '47Project' 'Error' } catch {}
}
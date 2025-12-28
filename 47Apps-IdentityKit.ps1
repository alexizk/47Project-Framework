#requires -Version 5.1
<#
47Apps - Identity Kit (CyberGlass Ultimate)
Local account friendly. Safe-first design (HKCU by default), with optional admin-only enhancements.
Profiles are stored under: %SystemDrive%\47Project\IdentityKit\Profiles

Run:
  powershell -ExecutionPolicy Bypass -File .\47Apps-IdentityKit-v2.4.43-PATCH-ScrollbarStyle-Standalone.ps1

Optional (silent apply):
  -ApplyProfile "MyProfile"
  -ApplyBaseline
  -DryRun
  -NoUI
#>

[CmdletBinding()]
param(
  [string]$ApplyProfile,
  [switch]$ApplyBaseline,
  [switch]$DryRun,
  [switch]$NoUI,
  [switch]$Standalone,
  [switch]$Portable
)


# --- Standalone launcher (detach from the parent PowerShell) ---
# When you run the script from an existing console, it will relaunch itself in a new process and exit the caller.
# Pass -Standalone to skip relaunch (used internally and for schedulers).
if (-not $Standalone) {
  try {
    $ps = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","`"$PSCommandPath`"","-Standalone")

    if ($ApplyProfile) { $args += @("-ApplyProfile","`"$ApplyProfile`"") }
    if ($ApplyBaseline) { $args += "-ApplyBaseline" }
    if ($DryRun) { $args += "-DryRun" }
    if ($NoUI) { $args += "-NoUI" }

    
    if ($Portable) { $args += "-Portable" }
Start-Process -FilePath $ps -ArgumentList $args | Out-Null
    exit
  } catch {
    # If relaunch fails, continue in-process (best effort)
  }
}
# --- end standalone launcher ---

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# -------------------------
# Globals / paths
# -------------------------
$Script:AppName    = '47Apps - Identity Kit'
$Script:AppVersion = 'v2.4.43-PATCH'
$Script:ScriptPath = $MyInvocation.MyCommand.Path
if (-not $Script:ScriptPath) { $Script:ScriptPath = $PSCommandPath }
if (-not $Script:ScriptPath) { $Script:ScriptPath = (Get-Process -Id $PID).Path }
$Script:ScriptDir  = Split-Path -Parent $Script:ScriptPath

$Script:ScriptRoot   = Split-Path -Parent $PSCommandPath
$Script:PortableFlag = Join-Path $Script:ScriptRoot ".identitykit-portable"
$Script:IsPortable   = [bool]$Portable -or (Test-Path $Script:PortableFlag)

if ($Script:IsPortable) {
  # Portable data lives next to the script (USB / zip-friendly)
  $Script:BasePath = Join-Path $Script:ScriptRoot "IdentityKitData"
} else {
  $Script:BasePath = Join-Path $env:SystemDrive '47Project\IdentityKit'
}

# Fallbacks if environment variables are missing (e.g. some special shells)
if ([string]::IsNullOrWhiteSpace($Script:BasePath) -or $Script:BasePath -eq '47Project\IdentityKit') {
  $drv = $env:SystemDrive
  if ([string]::IsNullOrWhiteSpace($drv)) { try { $drv = (Split-Path $env:SystemRoot -Qualifier) } catch {} }
  if ([string]::IsNullOrWhiteSpace($drv)) { $drv = 'C:' }
  $Script:BasePath = Join-Path $drv '47Project\IdentityKit'
}
$Script:BaseDir    = $Script:BasePath # backward compat for older UI strings
$Script:ProfilesDir= Join-Path $Script:BasePath 'Profiles'
$Script:LogsDir    = Join-Path $Script:BasePath 'Logs'
$Script:BackupsDir = Join-Path $Script:BasePath 'Backups'
$Script:CacheDir   = Join-Path $Script:BasePath 'Cache'
$Script:TempDir    = Join-Path $Script:BasePath 'Temp'
$Script:LibDir     = Join-Path $env:SystemDrive '47Project\Wallpapers'
$Script:LocalLibDir= Join-Path $Script:BasePath 'Library'

$null = New-Item -ItemType Directory -Force -Path $Script:BasePath, $Script:ProfilesDir, $Script:LogsDir, $Script:BackupsDir, $Script:CacheDir, $Script:LocalLibDir -ErrorAction SilentlyContinue
$null = New-Item -ItemType Directory -Force -Path $Script:LibDir -ErrorAction SilentlyContinue

$Script:IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$Script:LogFile = Join-Path $Script:LogsDir ("IdentityKit-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Log-Line {
  param([ValidateSet('INFO','OK','WARN','ERR','FATAL')][string]$Level, [string]$Message)
  $ts = (Get-Date -Format 'HH:mm:ss')
  $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message
  if ([string]::IsNullOrWhiteSpace($Script:LogFile)) { return }
  try { Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8 } catch {}
  if ($script:TxtLog) {
    try {
      $script:TxtLog.AppendText($line + "`r`n")
      $script:TxtLog.ScrollToEnd()
    } catch {}
  }
  if ($script:TxtFooter) { try { $script:TxtFooter.Text = $Message } catch {} }
}

function Test-PathSafe {
  [CmdletBinding(DefaultParameterSetName='Path')]
  param(
    [Parameter(ParameterSetName='Path', Position=0)][string]$Path,
    [Parameter(ParameterSetName='Literal', Position=0)][string]$LiteralPath
  )
  try {
    $p = if ($PSCmdlet.ParameterSetName -eq 'Literal') { $LiteralPath } else { $Path }
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    if ($PSCmdlet.ParameterSetName -eq 'Literal') { return (Test-Path -LiteralPath $p) }
    return (Test-Path -Path $p)
  } catch { return $false }
}

function Ensure-Folder([Parameter(Mandatory=$true)][string]$Path) {
  try {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path)) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    try { return (Resolve-Path -LiteralPath $Path).Path } catch { return $Path }
  } catch {
    return $Path
  }
}




function Show-Error {
  param([string]$Title = "$($Script:AppName) error", [string]$Message)
  try {
    [System.Windows.MessageBox]::Show(
      $Message,
      $Title,
      [System.Windows.MessageBoxButton]::OK,
      [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
  } catch {}
}

function Set-ClipboardText {
  param([string]$Text)
  try {
    Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue | Out-Null
    [System.Windows.Clipboard]::SetText([string]$Text)
    return $true
  } catch { return $false }
}
function Show-Info {
  param([string]$Title = $Script:AppName, [string]$Message)
  try {
    [System.Windows.MessageBox]::Show(
      $Message,
      $Title,
      [System.Windows.MessageBoxButton]::OK,
      [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
  } catch {}
}

function Ask-YesNo {
  param([string]$Title, [string]$Message, [string]$Default = 'No')
  try {
    $btn = [System.Windows.MessageBoxButton]::YesNo
    $icon = [System.Windows.MessageBoxImage]::Question
    $res = [System.Windows.MessageBox]::Show($Message, $Title, $btn, $icon)
    return ($res -eq [System.Windows.MessageBoxResult]::Yes)
  } catch { return ($Default -eq 'Yes') }
}

function Restart-IdentityKit {
  param(
    [switch]$PortableMode
  )
  try {
    $ps = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-WindowStyle","Hidden","-File","`"$PSCommandPath`"","-Standalone")
    if ($PortableMode) { $args += "-Portable" }
    Start-Process -FilePath $ps -ArgumentList $args | Out-Null
  } catch { }
  try { if($script:Window){ $script:Window.Close() } } catch {}
}

function Get-LatestSnapshotFile {
  param([string]$Dir = $Script:BackupsDir)
  try {
    if (-not (Test-Path $Dir)) { return $null }
    $f = Get-ChildItem -LiteralPath $Dir -Filter "snapshot-*.json" -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($f) { return $f.FullName }
  } catch { }
  return $null
}
function Test-AdminHint {
  param([string]$What)
  if (-not $Script:IsAdmin) {
    Log-Line WARN "$What requires Admin for best results. (You can still use HKCU-safe options.)"
  }
}

# -------------------------
# JSON helpers
# -------------------------
function Read-JsonFile([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-PathSafe $Path)) { return $null }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
  return $raw | ConvertFrom-Json
}


function Get-Opt {
  param(
    $Obj,
    [string]$Name,
    $Default = $null
  )
  if ($null -eq $Obj) { return $Default }

  if ($Obj -is [hashtable]) {
    if ($Obj.ContainsKey($Name)) {
      $v = $Obj[$Name]
      if ($null -ne $v -and "$v".Trim().Length -gt 0) { return $v }
    }
    return $Default
  }

  $p = $Obj.PSObject.Properties[$Name]
  if ($null -ne $p) {
    $v = $p.Value
    if ($null -ne $v -and "$v".Trim().Length -gt 0) { return $v }
  }
  return $Default
}

function Get-ComboValue {
  param(
    [System.Windows.Controls.ComboBox]$Combo,
    [string]$Default = ''
  )
  if ($null -eq $Combo) { return $Default }
  try {
    $v = $null
    if ($Combo.SelectedItem -ne $null -and $Combo.SelectedItem.PSObject.Properties.Match('Content').Count -gt 0) {
      $v = [string]$Combo.SelectedItem.Content
    }
    if ([string]::IsNullOrWhiteSpace($v)) { $v = [string]$Combo.Text }
    if ([string]::IsNullOrWhiteSpace($v)) { $v = $Default }
    return $v
  } catch {
    return $Default
  }
}
function Write-JsonFile([string]$Path, [object]$Obj) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  $dir = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($dir)) {
    $null = New-Item -ItemType Directory -Force -Path $dir -ErrorAction SilentlyContinue
  }
  ($Obj | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $Path -Encoding UTF8
}

# -------------------------
# Image helpers
# -------------------------
function Get-ImageBitmap([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-PathSafe -LiteralPath $Path)) { return $null }
  # Loads images including GIF; for GIF this returns first frame.
  $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $img = [System.Drawing.Image]::FromStream($fs, $true, $true)
    # clone to detach from stream
    $bmp = New-Object System.Drawing.Bitmap $img
    $img.Dispose()
    return $bmp
  } finally {
    $fs.Dispose()
  }
}

function Save-ProfilePng448 {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestPath,
    [ValidateSet('Center','TopLeft','TopRight','BottomLeft','BottomRight')][string]$Crop = 'Center',
    [switch]$EnableCrop
  )
  $bmp = Get-ImageBitmap -Path $SourcePath
  try {
    $w = $bmp.Width; $h = $bmp.Height
    $side = [Math]::Min($w,$h)
    if ($EnableCrop) {
      switch ($Crop) {
        'TopLeft'     { $x=0; $y=0 }
        'TopRight'    { $x=$w-$side; $y=0 }
        'BottomLeft'  { $x=0; $y=$h-$side }
        'BottomRight' { $x=$w-$side; $y=$h-$side }
        default       { $x=[int](($w-$side)/2); $y=[int](($h-$side)/2) }
      }
    } else {
      $x=0; $y=0; $side = $w; if ($h -lt $w) { $side = $h }
      $x=[int](($w-$side)/2); $y=[int](($h-$side)/2)
    }
    $srcRect = New-Object System.Drawing.Rectangle($x,$y,$side,$side)
    $dstBmp = New-Object System.Drawing.Bitmap 448,448
    try {
      $g = [System.Drawing.Graphics]::FromImage($dstBmp)
      try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,448,448)), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
      } finally { $g.Dispose() }
      $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DestPath) -ErrorAction SilentlyContinue
      $dstBmp.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $dstBmp.Dispose() }
  } finally { $bmp.Dispose() }
}

function Convert-ToJpg {
  param(
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$DestPath,
    [int]$Quality = 92
  )
  $bmp = Get-ImageBitmap -Path $SourcePath
  try {
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DestPath) -ErrorAction SilentlyContinue
    $bmp.Save($DestPath, $codec, $ep)
  } finally { $bmp.Dispose() }
}
function Get-PrimaryScreenSize {
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue | Out-Null
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return @{ Width = [int]$b.Width; Height = [int]$b.Height }
  } catch {
    return @{ Width = 1920; Height = 1080 }
  }
}

function Convert-ImageToJpgFitCover {
  param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidateSet('Cover','Contain')][string]$Mode = 'Cover',
    [int]$Width = 0,
    [int]$Height = 0,
    [int]$Quality = 92
  )
  Ensure-Folder (Split-Path -Parent $OutputPath) | Out-Null
  if ($Width -le 0 -or $Height -le 0) {
    $sz = Get-PrimaryScreenSize
    $Width = $sz.Width
    $Height = $sz.Height
  }

  Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue | Out-Null

  $src = $null; $bmp = $null; $g = $null
  try {
    $src = [System.Drawing.Image]::FromFile($InputPath)
    $scaleW = $Width / [double]$src.Width
    $scaleH = $Height / [double]$src.Height
    $scale = if ($Mode -eq 'Cover') { [Math]::Max($scaleW,$scaleH) } else { [Math]::Min($scaleW,$scaleH) }

    $newW = [int][Math]::Ceiling($src.Width * $scale)
    $newH = [int][Math]::Ceiling($src.Height * $scale)

    $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Black)

    $dstX = [int][Math]::Round(($Width  - $newW) / 2.0)
    $dstY = [int][Math]::Round(($Height - $newH) / 2.0)

    $g.DrawImage($src, $dstX, $dstY, $newW, $newH)

    # Save JPG with quality
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1
    $enc = New-Object System.Drawing.Imaging.EncoderParameters 1
    $enc.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)
    $bmp.Save($OutputPath, $codec, $enc)
  } finally {
    if ($g)   { $g.Dispose() }
    if ($bmp) { $bmp.Dispose() }
    if ($src) { $src.Dispose() }
  }
}
function Invoke-WinRT-LockScreenSet {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ImagePath)

  # Best-effort user-mode lockscreen via WinRT (Windows 10/11).
  # PowerShell 5.1 sometimes projects WinRT async types as __ComObject without GetAwaiter().
  # We use Invoke-WinRTAsync to robustly wait for completion.

  if (-not (Test-Path -LiteralPath $ImagePath)) { throw "File not found: $ImagePath" }

  # Load WinRT projection support
  Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue | Out-Null

  # Touch WinRT types (loads metadata). Avoid referencing Windows.Foundation generic types directly.
  $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
  $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType=WindowsRuntime]

  $fileAsync = [Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)

  # Prefer robust waiter; if it can't observe the async object, fall back to retrying GetResults().
  $file = Invoke-WinRTAsync -Async $fileAsync -TimeoutMs 30000
  if ($null -eq $file) {
    $file = Try-GetWinRTResults -Async $fileAsync -TimeoutMs 30000
  }
  if ($null -eq $file) { throw "WinRT did not return a StorageFile." }

$setAsync = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($file)
  Invoke-WinRTAsync -Async $setAsync -TimeoutMs 30000 | Out-Null
}





function Load-BitmapImageToWpf([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-PathSafe $Path)) { return $null }
  try {
    $bi = New-Object System.Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    $bi.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    $bi.UriSource = New-Object System.Uri($Path)
    $bi.EndInit()
    $bi.Freeze()
    return $bi
  } catch { return $null }
}

# -------------------------
# Windows apply helpers
# -------------------------

function Set-LockScreenCSP {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ImagePath)

  # MDM-style CSP registry (often works even when the classic policy key is ignored).
  # Requires Admin. Values live under:
  # HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP

  if (-not (Test-Path -LiteralPath $ImagePath)) { throw "File not found: $ImagePath" }

  $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
  $null = New-Item -Path $k -Force -ErrorAction SilentlyContinue

  # LockScreenImageUrl isn't required but some builds like it set too.
  Set-RegString -Path $k -Name "LockScreenImagePath"  -Value $ImagePath -WhatIf:$false
  Set-RegString -Path $k -Name "LockScreenImageUrl"   -Value $ImagePath -WhatIf:$false
  Set-RegDword  -Path $k -Name "LockScreenImageStatus" -Value 1 -WhatIf:$false
}

function Replace-SystemLockScreenImages {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ImagePath)

  # Nuclear fallback: replace Windows default lock screen images in %WINDIR%\Web\Screen
  # This affects all users and typically requires Admin.
  try {
    if (-not (Test-Path -LiteralPath $ImagePath)) { throw "File not found: $ImagePath" }
    $screenDir = Join-Path $env:WINDIR "Web\Screen"
    if (-not (Test-Path -LiteralPath $screenDir)) { throw "Screen folder not found: $screenDir" }

    $targets = Get-ChildItem -LiteralPath $screenDir -Filter *.jpg -ErrorAction SilentlyContinue
    if (-not $targets) { throw "No lock screen jpg targets found in: $screenDir" }

    foreach($t in $targets){
      $bak = ($t.FullName + ".bak47")
      try {
        if (-not (Test-Path -LiteralPath $bak)) {
          Copy-Item -LiteralPath $t.FullName -Destination $bak -Force -ErrorAction SilentlyContinue | Out-Null
        }
      } catch {}

      # Ensure we can overwrite
      try { & takeown.exe /F "$($t.FullName)" /A | Out-Null } catch {}
      try { & icacls.exe "$($t.FullName)" /grant "*S-1-5-32-544:(F)" /C | Out-Null } catch {}  # Administrators

      Copy-Item -LiteralPath $ImagePath -Destination $t.FullName -Force -ErrorAction SilentlyContinue
    }

    Log-Line "OK" "System lock screen assets replaced (%WINDIR%\\Web\\Screen). Reboot may be required."
  } catch {
    Log-Line "WARN" ("System lock screen asset replace failed: " + $_.Exception.Message)
  }
}

function Invoke-SystemTaskOnce {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$TaskName,
    [Parameter(Mandatory=$true)][string]$Ps1Path
  )

  # Runs a .ps1 once as SYSTEM via Task Scheduler.
  # NOTE: We DO NOT delete the task here (to avoid racing a running task).
  # The SYSTEM job script deletes the task itself at the end.

  $dt = Get-Date
  $runAt = $dt.AddMinutes(2)
  $st = $runAt.ToString('HH:mm')

  $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Ps1Path`""

  try {
    & schtasks.exe /Create /F /TN $TaskName /SC ONCE /ST $st /RL HIGHEST /RU SYSTEM /TR $tr | Out-Null
    & schtasks.exe /Run /TN $TaskName | Out-Null
    Start-Sleep -Seconds 1
  } catch {
    Log-Line "WARN" ("SYSTEM task launch failed: " + $_.Exception.Message)
  }
}


function Force-SystemDataLockScreenRefresh {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ImagePath)

  # Final boss: SystemData cache (used by lock screen on many builds).
  # We run as SYSTEM and:
  #  - Disable Spotlight-ish content for the user via registry already (elsewhere).
  #  - Replace any LockScreen* image files found under ProgramData\Microsoft\Windows\SystemData\*\ReadOnly
  #  - Purge obvious lock screen cache folders to force reload.

  if (-not (Test-Path -LiteralPath $ImagePath)) { throw "File not found: $ImagePath" }

  $root = Join-Path $env:ProgramData "Microsoft\Windows\SystemData"
  if (-not (Test-Path -LiteralPath $root)) { throw "SystemData root not found: $root" }

  $sidDirs = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'S-1-5-21-*' }
  if (-not $sidDirs) { throw "No SID folders found in SystemData." }

  foreach($sid in $sidDirs){
    $ro = Join-Path $sid.FullName "ReadOnly"
    if (-not (Test-Path -LiteralPath $ro)) { continue }

    # Replace any existing LockScreen*.jpg/png files (safe + broad).
    $files = Get-ChildItem -LiteralPath $ro -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^LockScreen.*\.(jpg|jpeg|png|bmp)$' }

    foreach($f in $files){
      try {
        Copy-Item -LiteralPath $ImagePath -Destination $f.FullName -Force -ErrorAction SilentlyContinue
      } catch {}
    }

    # Drop our own obvious candidates too
    foreach($name in @("LockScreen.jpg","LockScreen.png","LockScreen.jpeg")){
      try { Copy-Item -LiteralPath $ImagePath -Destination (Join-Path $ro $name) -Force -ErrorAction SilentlyContinue } catch {}
    }

    # Purge common cache folders (names vary by build; we remove only inside ReadOnly to be safer)
    $dirs = Get-ChildItem -LiteralPath $ro -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match 'LockScreen|Wallpaper|Cache' }

    foreach($d in $dirs){
      try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction SilentlyContinue } catch {}
    }
  }
}

function Apply-SystemDataLockScreen {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ImagePath)

  $tmpDir = $Script:TempDir
  Ensure-Folder $tmpDir | Out-Null
  $job = Join-Path $tmpDir "47-systemdata-lockscreen.ps1"

  $log = Join-Path $tmpDir "systemdata-lockscreen-lastrun.log"
  $taskName = "47IdentityKit_SystemDataLockScreen"

  $jobText = @"
`$ErrorActionPreference = 'SilentlyContinue'
`$img = `"$ImagePath`"
`$log = `"$log`"
`$task = `"$taskName`"

`$replaced = 0
`$deletedDirs = 0

try { "`$(Get-Date -Format o)  START  img=`$img" | Out-File -FilePath `$log -Encoding UTF8 } catch {}

`$root = Join-Path `$env:ProgramData 'Microsoft\Windows\SystemData'
`$sidDirs = Get-ChildItem -LiteralPath `$root -Directory | Where-Object { `$_.Name -like 'S-1-5-21-*' }

foreach(`$sid in `$sidDirs){
  `$ro = Join-Path `$sid.FullName 'ReadOnly'
  if(-not (Test-Path -LiteralPath `$ro)) { continue }

  `$files = Get-ChildItem -LiteralPath `$ro -Recurse -File | Where-Object { `$_.Name -match '^LockScreen.*\.(jpg|jpeg|png|bmp)$' }
  foreach(`$f in `$files){
    Copy-Item -LiteralPath `$img -Destination `$f.FullName -Force
    `$replaced++
  }

  foreach(`$name in @('LockScreen.jpg','LockScreen.png','LockScreen.jpeg')){
    Copy-Item -LiteralPath `$img -Destination (Join-Path `$ro `$name) -Force
  }

  `$dirs = Get-ChildItem -LiteralPath `$ro -Directory | Where-Object { `$_.Name -match 'LockScreen|Wallpaper|Cache' }
  foreach(`$d in `$dirs){
    Remove-Item -LiteralPath `$d.FullName -Recurse -Force
    `$deletedDirs++
  }
}

try { "`$(Get-Date -Format o)  DONE  replaced=`$replaced  deletedDirs=`$deletedDirs" | Out-File -FilePath `$log -Append -Encoding UTF8 } catch {}

try { schtasks.exe /Delete /F /TN `$task | Out-Null } catch {}
"@

Set-Content -LiteralPath $job -Value $jobText -Encoding UTF8 -Force

  Invoke-SystemTaskOnce -TaskName "47IdentityKit_SystemDataLockScreen" -Ps1Path $job
  Log-Line "OK" "SYSTEM SystemData refresh triggered. Reboot is recommended."
}



function Set-RegDword {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][int]$Value,
    [switch]$WhatIf
  )
  if ($WhatIf) {
    Log-Line "INFO" ("[DRY] REG DWORD " + $Path + " \\ " + $Name + " = " + $Value)
    return
  }
  $null = New-Item -Path $Path -Force -ErrorAction SilentlyContinue
  try {
    if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
      Set-ItemProperty -Path $Path -Name $Name -Value ([int]$Value) -ErrorAction SilentlyContinue
    } else {
      New-ItemProperty -Path $Path -Name $Name -Value ([int]$Value) -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
  } catch {
    Set-ItemProperty -Path $Path -Name $Name -Value ([int]$Value) -ErrorAction SilentlyContinue
  }
}
function Set-RegString {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Value,
    [switch]$WhatIf
  )
  if ($WhatIf) {
    Log-Line "INFO" ("[DRY] REG SZ " + $Path + " \\ " + $Name + " = " + $Value)
    return
  }
  $null = New-Item -Path $Path -Force -ErrorAction SilentlyContinue
  try {
    if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
      Set-ItemProperty -Path $Path -Name $Name -Value ([string]$Value) -ErrorAction SilentlyContinue
    } else {
      New-ItemProperty -Path $Path -Name $Name -Value ([string]$Value) -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    }
  } catch {
    Set-ItemProperty -Path $Path -Name $Name -Value ([string]$Value) -ErrorAction SilentlyContinue
  }
}



Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

function Invoke-WinRTAsync {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][object]$Async,
    [int]$TimeoutMs = 30000
  )

  # Robust WinRT async wait for PowerShell 5.1.
  # Prefer IAsyncInfo polling (works when the object can be cast to Windows.Foundation.IAsyncInfo).
  # If we cannot observe status, we DO NOT fail the whole operation; we warn and continue best-effort.

  try { Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue } catch {}

  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  $info = $null
  try { $info = [Windows.Foundation.IAsyncInfo]$Async } catch { $info = $null }

  if($info){
    while($true){
      if($sw.ElapsedMilliseconds -gt $TimeoutMs){
        throw "WinRT async timeout after ${TimeoutMs}ms."
      }

      $st = $info.Status
      # Windows.Foundation.AsyncStatus enum: Started=0, Completed=1, Canceled=2, Error=3
      if($st -eq [Windows.Foundation.AsyncStatus]::Completed){ break }
      if($st -eq [Windows.Foundation.AsyncStatus]::Canceled){ throw "WinRT async canceled." }
      if($st -eq [Windows.Foundation.AsyncStatus]::Error){
        $err = $info.ErrorCode
        if($err){ throw "WinRT async error: $($err.Message)" }
        throw "WinRT async error."
      }
      Start-Sleep -Milliseconds 50
    }
  } else {
    # Try AsTask() (may work if the object is a proper WinRT interface).
    $task = $null
    try {
      $task = [System.WindowsRuntimeSystemExtensions]::AsTask($Async)
    } catch {
      try { $task = [System.WindowsRuntimeSystemExtensions]::AsTask([Windows.Foundation.IAsyncAction]$Async) } catch {}
    }

    if($task){
      if(-not $task.Wait($TimeoutMs)){
        throw "WinRT async timeout after ${TimeoutMs}ms."
      }
      if($task.IsFaulted -and $task.Exception){
        throw "WinRT async error: $($task.Exception.InnerException.Message)"
      }
    } else {
      Log-Line "WARN" "WinRT async object not observable (no IAsyncInfo/AsTask). Continuing best-effort."
    }
  }

  # IAsyncOperation<T> may expose GetResults(); IAsyncAction typically does not.
  try {
    if($Async.PSObject -and $Async.PSObject.Methods -and ($Async.PSObject.Methods.Name -contains 'GetResults')){
      return $Async.GetResults()
    }
  } catch {}
  return $null
}


function Try-GetWinRTResults {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][object]$Async,
    [int]$TimeoutMs = 30000,
    [int]$SleepMs = 50
  )

  # Fallback for WinRT async projections that don't expose Status/AsTask.
  # We repeatedly try GetResults() until it succeeds or we time out.
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  while($sw.ElapsedMilliseconds -lt $TimeoutMs){
    try {
      if($Async.PSObject -and $Async.PSObject.Methods -and ($Async.PSObject.Methods.Name -contains 'GetResults')){
        $r = $Async.GetResults()
        if($null -ne $r){ return $r }
      } else {
        return $null
      }
    } catch {
      Start-Sleep -Milliseconds $SleepMs
    }
  }
  return $null
}



function Apply-Wallpaper {
  param(
    [Parameter(Mandatory=$true)][string]$ImagePath,
    [ValidateSet('Fill','Fit','Stretch','Tile','Center','Span')][string]$Style = 'Fill',
    [switch]$WhatIf
  )
  if (-not (Test-Path -LiteralPath $ImagePath)) { throw "Wallpaper path not found: $ImagePath" }

  # Normalize -> local cache & monitor-fit (prevents stretching)
  $cacheDir = $Script:CacheDir
  Ensure-Folder $cacheDir | Out-Null
  $cachePath = Join-Path $cacheDir "wallpaper.jpg"

  $mode = if ($Style -eq 'Fit' -or $Style -eq 'Center') { 'Contain' } else { 'Cover' }
  try {
    Convert-ImageToJpgFitCover -InputPath $ImagePath -OutputPath $cachePath -Mode $mode -Quality 92
  } catch {
    try { Convert-ToJpg -InputPath $ImagePath -OutputPath $cachePath -Quality 92 } catch { Copy-Item -LiteralPath $ImagePath -Destination $cachePath -Force }
  }

  if ($WhatIf) {
    Log-Line "INFO" ("[DRY] Would set Wallpaper: " + $cachePath + " (Style=" + $Style + ")")
    return
  }

  $styleMap = @{
    Fill    = @{ WS='10'; TW='0' }
    Fit     = @{ WS='6';  TW='0' }
    Stretch = @{ WS='2';  TW='0' }
    Tile    = @{ WS='0';  TW='1' }
    Center  = @{ WS='0';  TW='0' }
    Span    = @{ WS='22'; TW='0' }
  }
  $s = $styleMap[$Style]
  Set-RegString 'HKCU:\Control Panel\Desktop' 'Wallpaper' $cachePath
  Set-RegString 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' $s.WS
  Set-RegString 'HKCU:\Control Panel\Desktop' 'TileWallpaper' $s.TW

  try { rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True | Out-Null } catch { }
}

function Restart-Explorer([switch]$WhatIf) {
  # Restarting Explorer closes open File Explorer windows. We only do this when explicitly needed.
  if ($WhatIf) { return }
  try {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 900
    # Restart the shell (taskbar/desktop). Avoid launching folder windows.
    $sh = $null
    try { $sh = New-Object -ComObject Shell.Application } catch { }
    Start-Process "$env:WINDIR\explorer.exe" | Out-Null
    Start-Sleep -Milliseconds 800
    if ($sh) {
      foreach ($w in @($sh.Windows())) {
        try {
          $full = [string]$w.FullName
          if ($full -match 'explorer\.exe$') {
            $locUrl = ""; $locName = ""
            try { $locUrl  = [string]$w.LocationURL } catch { }
            try { $locName = [string]$w.LocationName } catch { }
            if ($locUrl -match 'shell:|Home|quickaccess|recent' -or $locName -match 'Home|Quick|Recent') { $w.Quit() }
          }
        } catch { }
      }
    }
  } catch {
    Log-Line "WARN" ("Explorer restart failed: " + $_.Exception.Message)
  }
}


function Apply-ProfilePicture {
  param([string]$SourcePath,[switch]$EnableCrop,[string]$CropMode='Center',[switch]$UpdateProgramData,[switch]$WriteHKCU,[switch]$WhatIf)
  if (-not (Test-Path -LiteralPath $SourcePath)) { throw "Profile picture source not found: $SourcePath" }

  $outPng = Join-Path $Script:CacheDir 'profile_448.png'
  Save-ProfilePng448 -SourcePath $SourcePath -DestPath $outPng -EnableCrop:$EnableCrop -Crop $CropMode

  if ($WhatIf) { return }

  if ($UpdateProgramData) {
    Test-AdminHint "Updating ProgramData account picture"
    $pd = Join-Path $env:ProgramData 'Microsoft\User Account Pictures'
    $dst = Join-Path $pd 'user.png'
    try {
      if (Test-Path -LiteralPath $dst) {
        Copy-Item -LiteralPath $dst -Destination ($dst + '.bak') -Force -ErrorAction SilentlyContinue
      }
      Copy-Item -LiteralPath $outPng -Destination $dst -Force
      Log-Line OK "ProgramData updated: $dst"
    } catch {
      Log-Line WARN "ProgramData update failed: $($_.Exception.Message)"
    }
  }

  if ($WriteHKCU) {
    # Best-effort: map current user SID to the png paths.
    try {
      $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
      $base = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$sid"
      $null = New-Item -Path $base -Force -ErrorAction SilentlyContinue
      Set-RegString $base 'Image448' $outPng
      Set-RegString $base 'Image192' $outPng
      Set-RegString $base 'Image96'  $outPng
      Log-Line OK "HKCU account-picture mapping updated."
    } catch {
      Log-Line WARN "HKCU account-picture mapping failed: $($_.Exception.Message)"
    }
  }
}

function Apply-LockScreen {
  param(
    [string]$ImagePath,
    [ValidateSet('User','Enforced')][string]$Mode = 'User',
    [switch]$NoChange,
    [switch]$WhatIf
  )

  if ([string]::IsNullOrWhiteSpace($ImagePath)) { return }

  # Prepare a stable local path (policy + WinRT prefer local files)
  $cacheDir = $Script:CacheDir
  Ensure-Folder $cacheDir | Out-Null
  $cachePath = Join-Path $cacheDir "lockscreen.jpg"

  try {
    Convert-ImageToJpgFitCover -InputPath $ImagePath -OutputPath $cachePath -Mode Cover -Quality 92
  } catch {
    # fallback: just copy as-is
    Copy-Item -LiteralPath $ImagePath -Destination $cachePath -Force -ErrorAction SilentlyContinue
  }

  if ($WhatIf) {
    Log-Line "INFO" ("[DRY] Would set Lock screen: " + $cachePath + " (Mode=" + $Mode + ")")
    return
  }

  
  # Reduce interference from Spotlight/rotating lock screen (current user)
  try {
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $null = New-Item -Path $cdm -Force -ErrorAction SilentlyContinue
    foreach($n in @('RotatingLockScreenEnabled','RotatingLockScreenOverlayEnabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled')){
      try { Set-RegDword $cdm $n 0 } catch {}
    }
  } catch {}
$winrtOk = $false
  try {
    # best-effort current-user lock screen (no admin required)
    Invoke-WinRT-LockScreenSet -ImagePath $cachePath
    $winrtOk = $true
    Log-Line "OK" "Lock screen set (current user, WinRT)."
  } catch {
    Log-Line "WARN" ("WinRT lock screen set failed: " + $_.Exception.Message)
  }

  if ($Mode -eq 'Enforced') {
    # Enforced lock screen uses policy (admin).
    $polKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    try {
      $null = New-Item -Path $polKey -Force -ErrorAction SilentlyContinue
      Set-RegString -Path $polKey -Name "LockScreenImage" -Value $cachePath -WhatIf:$false
      Set-RegDword  -Path $polKey -Name "LockScreenImageStatus" -Value 1 -WhatIf:$false
      if ($NoChange) {
        Set-RegDword -Path $polKey -Name "NoChangingLockScreen" -Value 1 -WhatIf:$false
      } else {
        Remove-ItemProperty -Path $polKey -Name "NoChangingLockScreen" -ErrorAction SilentlyContinue
      }
      
      # Extra fallback: also write PersonalizationCSP values (MDM-style). Improves compatibility on some builds.
      try {
        Set-LockScreenCSP -ImagePath $cachePath
      } catch {
        Log-Line "WARN" ("PersonalizationCSP lock screen set failed: " + $_.Exception.Message)
      }


      # Last resort: replace default system lock screen assets (works even when policy is ignored).
      Replace-SystemLockScreenImages -ImagePath $cachePath


      # Final fallback: refresh SystemData lock screen caches via a one-shot SYSTEM task.
      try {
        Apply-SystemDataLockScreen -ImagePath $cachePath
      } catch {
        Log-Line "WARN" ("SystemData refresh failed: " + $_.Exception.Message)
      }

      Log-Line "OK" "Lock screen policy applied (enforced). Lock/Sign-out may be required (Win+L)."
    } catch {
      Log-Line "ERROR" ("Failed to apply lock screen policy (needs Admin): " + $_.Exception.Message)
      throw
    }
  } else {
    # User mode: if WinRT failed, keep the cached file ready but don't force policy.
    if (-not $winrtOk) {
      Log-Line "WARN" "Lock screen not changed (WinRT failed). Try running as Admin and use Enforced mode."
    }
    if ($NoChange) {
      # user requested to disable changing: best-effort policy in HKCU (not always honored), but harmless
      try {
        $polKeyCU = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
        $null = New-Item -Path $polKeyCU -Force -ErrorAction SilentlyContinue
        Set-RegDword -Path $polKeyCU -Name "NoChangingLockScreen" -Value 1 -WhatIf:$false
      } catch { }
    }
  }
}


# -------------------------
# Safe UX toggles (HKCU)
# -------------------------
function Apply-AdvancedHKCU {
  param([hashtable]$Cfg,[switch]$WhatIf,[bool]$ApplyAdvanced=$true)
  $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  $pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
  $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
  $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
  $dwm = 'HKCU:\Software\Microsoft\Windows\DWM'

  if ($WhatIf) { return }  # Theme (do not change unless explicitly selected)
  if ($Cfg.Theme -eq 'Dark') {
    Set-RegDword $pers 'AppsUseLightTheme' 0
    Set-RegDword $pers 'SystemUsesLightTheme' 0
  }
  elseif ($Cfg.Theme -eq 'Light') {
    Set-RegDword $pers 'AppsUseLightTheme' 1
    Set-RegDword $pers 'SystemUsesLightTheme' 1
  }
  else {
    # No change
  }
# Transparency
  if ($null -ne $Cfg.Transparency) { Set-RegDword $pers 'EnableTransparency' ([int]([bool]$Cfg.Transparency)) }

  # Taskbar size / align (Win11)
  if ($Cfg.TaskbarSize) {
    $map = @{ Small=0; Default=1; Large=2 }
    if ($map.ContainsKey($Cfg.TaskbarSize)) { Set-RegDword $adv 'TaskbarSi' $map[$Cfg.TaskbarSize] }
  }
  if ($Cfg.TaskbarAlign) {
    $map = @{ Left=0; Center=1 }
    if ($map.ContainsKey($Cfg.TaskbarAlign)) { Set-RegDword $adv 'TaskbarAl' $map[$Cfg.TaskbarAlign] }
  }

  # Search box mode
  if ($Cfg.Search) {
    $map = @{ Hidden=0; Icon=1; Box=2 }
    if ($map.ContainsKey($Cfg.Search)) { Set-RegDword $search 'SearchboxTaskbarMode' $map[$Cfg.Search] }
  }

  # Combine
  if ($Cfg.Combine) {
    $map = @{ Always=0; WhenFull=1; Never=2 }
    if ($map.ContainsKey($Cfg.Combine)) { Set-RegDword $adv 'TaskbarGlomLevel' $map[$Cfg.Combine] }
  }

  # Explorer
  if ($null -ne $Cfg.ShowExtensions) { Set-RegDword $adv 'HideFileExt' $(if($Cfg.ShowExtensions){0}else{1}) }
  if ($null -ne $Cfg.ShowHidden) { Set-RegDword $adv 'Hidden' $(if($Cfg.ShowHidden){1}else{2}) }
  if ($null -ne $Cfg.ShowProtectedOS) { Set-RegDword $adv 'ShowSuperHidden' $(if($Cfg.ShowProtectedOS){1}else{0}) }
  if ($Cfg.ExplorerLaunch) {
    $map = @{ Home=1; QuickAccess=1; ThisPC=2 }
    if ($map.ContainsKey($Cfg.ExplorerLaunch)) { Set-RegDword $adv 'LaunchTo' $map[$Cfg.ExplorerLaunch] }
  }

  # Spotlight/tips reduce noise
  if ($null -ne $Cfg.DisableTips) {
    if ($Cfg.DisableTips) {
      foreach($n in @('SubscribedContent-338388Enabled','SubscribedContent-310093Enabled','SubscribedContent-353694Enabled','RotatingLockScreenEnabled','RotatingLockScreenOverlayEnabled')) {
        Set-RegDword $cdm $n 0
      }
    }
  }

  # Enterprise-ish extras
  # Stored in $Cfg.Enterprise (hashtable). Defaults to 'No change'.
  $e = $Cfg.Enterprise

  $widgets = Get-Opt $e 'Widgets' 'No change'
  if ($widgets -ne 'No change') {
    $v = $(if ($widgets -eq 'Hide') { 0 } else { 1 })
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $taskView = Get-Opt $e 'TaskView' 'No change'
  if ($taskView -ne 'No change') {
    $v = $(if ($taskView -eq 'Hide') { 0 } else { 1 })
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $chat = Get-Opt $e 'Chat' 'No change'
  if ($chat -ne 'No change') {
    $v = $(if ($chat -eq 'Hide') { 0 } else { 1 })
    # Windows 11 Chat / Copilot (best-effort; varies by build)
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Type DWord -Value $v -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $anim = Get-Opt $e 'TaskbarAnim' 'No change'
  if ($anim -ne 'No change') {
    $v = $(if ($anim -eq 'Disable') { 0 } else { 1 })
    Set-ItemProperty -Path $adv -Name 'TaskbarAnimations' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $desk = Get-Opt $e 'DesktopIcons' 'No change'
  if ($desk -ne 'No change') {
    $v = $(if ($desk -eq 'Hide') { 1 } else { 0 })
    Set-ItemProperty -Path $adv -Name 'HideIcons' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $wall = Get-Opt $e 'WallComp' 'No change'
  if ($wall -ne 'No change') {
    $v = $(if ($wall -eq 'Disable compression') { 100 } else { 0 })
    Set-ItemProperty -Path $deskPath -Name 'JPEGImportQuality' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $accentBars = Get-Opt $e 'AccentBars' 'No change'
  if ($accentBars -ne 'No change') {
    $v = $(if ($accentBars -eq 'Enable') { 1 } else { 0 })
    Set-ItemProperty -Path $pers -Name 'EnableColorPrevalence' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $fullPath = Get-Opt $e 'FullPath' 'No change'
  if ($fullPath -ne 'No change') {
    $v = $(if ($fullPath -eq 'Enable') { 1 } else { 0 })
    Set-ItemProperty -Path $adv -Name 'FullPath' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $compact = Get-Opt $e 'Compact' 'No change'
  if ($compact -ne 'No change') {
    $v = $(if ($compact -eq 'Enable') { 1 } else { 0 })
    Set-ItemProperty -Path $adv -Name 'UseCompactMode' -Type DWord -Value $v -ErrorAction SilentlyContinue
  }

  $classic = Get-Opt $e 'ClassicMenu' 'No change'
  if ($classic -ne 'No change') {
    $v = $(if ($classic -eq 'Enable') { 1 } else { 0 })
    $k = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if ($v -eq 1) {
      New-Item -Path $k -Force | Out-Null
      Set-ItemProperty -Path $k -Name '(Default)' -Value '' -Force | Out-Null
    } else {
      Remove-Item -Path ('HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}') -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

}

# -------------------------
# Profiles
# -------------------------
function Get-ProfileList {
  $profiles = @()
  if (Test-Path -LiteralPath $Script:ProfilesDir) {
    Get-ChildItem -LiteralPath $Script:ProfilesDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $pj = Join-Path $_.FullName 'profile.json'
      if (Test-Path -LiteralPath $pj) {
        $obj = Read-JsonFile $pj
        $fav = $false
        try { $fav = [bool]$obj.Meta.Favorite } catch {}
        $profiles += [pscustomobject]@{
          Name = $_.Name
          Path = $_.FullName
          Favorite = $fav
          Updated = $_.LastWriteTime
        }
      }
    }
  }
  $profiles | Sort-Object @{Expression='Favorite';Descending=$true}, @{Expression='Updated';Descending=$true}, Name
}

function Profile-Path([string]$Name) { Join-Path $Script:ProfilesDir $Name }

function Write-Profile {
  param([string]$Name,[hashtable]$Cfg)
  $p = Profile-Path $Name
  $null = New-Item -ItemType Directory -Force -Path $p -ErrorAction SilentlyContinue

  # optional managed storage: copy selected images into profile folder
  if ($Cfg.ManagedStorage) {
    $assets = Join-Path $p 'Assets'
    $null = New-Item -ItemType Directory -Force -Path $assets -ErrorAction SilentlyContinue
    foreach($k in @('ProfileImage','WallpaperImage','LockImage')) {
      if ($Cfg.$k -and (Test-Path -LiteralPath $Cfg.$k)) {
        $dst = Join-Path $assets ([IO.Path]::GetFileName($Cfg.$k))
        Copy-Item -LiteralPath $Cfg.$k -Destination $dst -Force
        $Cfg.$k = $dst
      }
    }
  }

  Write-JsonFile -Path (Join-Path $p 'profile.json') -Obj $Cfg
  Log-Line OK "Saved profile: $Name"
}

function Read-ProfileCfg([string]$Name) {
  $p = Profile-Path $Name
  $pj = Join-Path $p 'profile.json'
  if (-not (Test-Path -LiteralPath $pj)) { return $null }
  $obj = Read-JsonFile $pj
  # ConvertFrom-Json returns PSCustomObject; normalize to hashtable for simpler apply
  $ht = @{}
  foreach($prop in $obj.PSObject.Properties) { $ht[$prop.Name] = $prop.Value }
  return $ht
}

function Toggle-Favorite([string]$Name) {
  $cfg = Read-ProfileCfg $Name
  if (-not $cfg) { return }
  if (-not $cfg.Meta) { $cfg.Meta = @{} }
  $cfg.Meta.Favorite = -not [bool]$cfg.Meta.Favorite
  Write-Profile -Name $Name -Cfg $cfg
}

function Set-Baseline([string]$Name) {
  $cfg = Read-ProfileCfg $Name
  if (-not $cfg) { return }
  if (-not $cfg.Meta) { $cfg.Meta = @{} }
  $cfg.Meta.IsBaseline = $true
  # Save baseline pointer
  Write-JsonFile -Path (Join-Path $Script:BasePath 'baseline.json') -Obj @{ Baseline = $Name; Updated = (Get-Date) }
  Log-Line OK "Baseline set: $Name"
}

function Get-BaselineName {
  $b = Read-JsonFile (Join-Path $Script:BasePath 'baseline.json')
  if ($b -and $b.Baseline) { return [string]$b.Baseline }
  return $null
}

function Snapshot-Now([hashtable]$Cfg) {
  $snap = Join-Path $Script:BackupsDir ("snapshot-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
  Write-JsonFile -Path $snap -Obj $Cfg
  Log-Line OK "Snapshot created: $(Split-Path -Leaf $snap)"
}

# -------------------------
# Enterprise dialog (separate popup, SAFE HKCU)
# -------------------------
function Show-EnterpriseDialog {
  param([hashtable]$Current)

  $x = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Enterprise / Extra toggles" Width="860" Height="620"
        WindowStartupLocation="CenterOwner" Background="#040A0D" Foreground="#CFFDF6">
  <Window.Resources>
    <SolidColorBrush x:Key="Stroke" Color="#00FFD0"/>
    <SolidColorBrush x:Key="Stroke2" Color="#FF00D4"/>
    <SolidColorBrush x:Key="Glass" Color="#55101818"/>
    <SolidColorBrush x:Key="Glass2" Color="#33101818"/>
    <SolidColorBrush x:Key="GlassText" Color="#CFFDF6"/>
    <SolidColorBrush x:Key="GlassTextDim" Color="#86CFC6"/>
    <SolidColorBrush x:Key="GlassBG" Color="#55101818"/>
    <SolidColorBrush x:Key="GlassBG_H" Color="#7720282A"/>
    <SolidColorBrush x:Key="GlassBorderDim" Color="#224A4444"/>
    <SolidColorBrush x:Key="GlassFocus" Color="#00FFD0"/>
    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="{StaticResource GlassText}"/>
      <Setter Property="Background" Value="{StaticResource GlassBG}"/>
      <Setter Property="BorderBrush" Value="{StaticResource GlassBorderDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Margin" Value="0,2,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border x:Name="Bd" CornerRadius="10"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}">
                <DockPanel>
                  <ToggleButton x:Name="ToggleButton" DockPanel.Dock="Right" Focusable="False"
                                IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"
                                Background="Transparent" BorderThickness="0" Width="28">
                    <Path Data="M 0 0 L 6 6 L 12 0 Z" Fill="{StaticResource GlassTextDim}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </ToggleButton>
                  <ContentPresenter Margin="2,0,0,0" VerticalAlignment="Center" HorizontalAlignment="Left"
                                    Content="{TemplateBinding SelectionBoxItem}"
                                    ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                    ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}"/>
                </DockPanel>
              </Border>
              <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                <Border CornerRadius="10" Background="#CC050B0D" BorderBrush="{StaticResource GlassBorderDim}" BorderThickness="1" Padding="6" SnapsToDevicePixels="True">
                  <ScrollViewer Margin="0" SnapsToDevicePixels="True" CanContentScroll="True">
                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Opacity" Value="0.45"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocusWithin" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource GlassFocus}"/>
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource GlassBG_H}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ComboBoxItem">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="Foreground" Value="{StaticResource GlassText}"/>
      <Setter Property="Background" Value="#07161A"/>
      <Setter Property="Padding" Value="6,4"/>
      <Style.Triggers>
        <Trigger Property="IsHighlighted" Value="True">
          <Setter Property="Background" Value="#003B33"/>
          <Setter Property="Foreground" Value="#E8FFFA"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="Button">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#CFFDF6"/>
      <Setter Property="Background" Value="#001412"/>
      <Setter Property="BorderBrush" Value="#00FFD0"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
    </Style>
  </Window.Resources>

  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border CornerRadius="12" BorderThickness="1" BorderBrush="{StaticResource Stroke}" Background="{StaticResource Glass2}" Padding="12">
      <StackPanel>
        <TextBlock Text="Enterprise / Extra toggles" FontSize="18" FontWeight="Bold" Foreground="{StaticResource Stroke}"/>
        <TextBlock Text="Safe HKCU switches that improve UX consistency. Nothing applies until you click OK." Opacity="0.85" TextWrapping="Wrap" Margin="0,6,0,0"/>
      </StackPanel>
    </Border>

    <ScrollViewer Grid.Row="1" Margin="0,12,0,12" VerticalScrollBarVisibility="Auto">
      <StackPanel>

        <Border CornerRadius="12" BorderThickness="1" BorderBrush="#22324A44" Background="{StaticResource Glass2}" Padding="12" Margin="0,0,0,10">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="180"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="220"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Grid.Column="0" Text="Widgets"/>
            <TextBlock Grid.Row="0" Grid.Column="1" Text="Show or hide the Widgets button." Opacity="0.75"/>
            <ComboBox Grid.Row="0" Grid.Column="2" Name="CmbWidgets">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Show"/>
              <ComboBoxItem Content="Hide"/>
            </ComboBox>

            <TextBlock Grid.Row="1" Grid.Column="0" Text="Task View"/>
            <TextBlock Grid.Row="1" Grid.Column="1" Text="Show or hide the Task View button." Opacity="0.75"/>
            <ComboBox Grid.Row="1" Grid.Column="2" Name="CmbTaskView">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Show"/>
              <ComboBoxItem Content="Hide"/>
            </ComboBox>

            <TextBlock Grid.Row="2" Grid.Column="0" Text="Chat / Copilot"/>
            <TextBlock Grid.Row="2" Grid.Column="1" Text="Show or hide the Chat button (availability depends on build)." Opacity="0.75"/>
            <ComboBox Grid.Row="2" Grid.Column="2" Name="CmbChat">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Show"/>
              <ComboBoxItem Content="Hide"/>
            </ComboBox>

            <TextBlock Grid.Row="3" Grid.Column="0" Text="Seconds in clock"/>
            <TextBlock Grid.Row="3" Grid.Column="1" Text="Show seconds in system tray clock (Win11)." Opacity="0.75"/>
            <ComboBox Grid.Row="3" Grid.Column="2" Name="CmbSeconds">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Enable"/>
              <ComboBoxItem Content="Disable"/>
            </ComboBox>
          </Grid>
        </Border>

        <Border CornerRadius="12" BorderThickness="1" BorderBrush="#22324A44" Background="{StaticResource Glass2}" Padding="12" Margin="0,0,0,10">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="180"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="220"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Grid.Column="0" Text="Desktop icons"/>
            <TextBlock Grid.Row="0" Grid.Column="1" Text="Show or hide all desktop icons." Opacity="0.75"/>
            <ComboBox Grid.Row="0" Grid.Column="2" Name="CmbDesktopIcons">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Show"/>
              <ComboBoxItem Content="Hide"/>
            </ComboBox>

            <TextBlock Grid.Row="1" Grid.Column="0" Text="Wallpaper compression"/>
            <TextBlock Grid.Row="1" Grid.Column="1" Text="Disable JPEG compression to preserve wallpaper quality (may use more disk)." Opacity="0.75"/>
            <ComboBox Grid.Row="1" Grid.Column="2" Name="CmbWallComp">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Disable compression"/>
              <ComboBoxItem Content="Default"/>
            </ComboBox>

            <TextBlock Grid.Row="2" Grid.Column="0" Text="Accent bars"/>
            <TextBlock Grid.Row="2" Grid.Column="1" Text="Use accent color on title bars." Opacity="0.75"/>
            <ComboBox Grid.Row="2" Grid.Column="2" Name="CmbAccentBars">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Enable"/>
              <ComboBoxItem Content="Disable"/>
            </ComboBox>

            <TextBlock Grid.Row="3" Grid.Column="0" Text="Classic context menu"/>
            <TextBlock Grid.Row="3" Grid.Column="1" Text="Enable Windows 10-style classic context menu (Win11)." Opacity="0.75"/>
            <ComboBox Grid.Row="3" Grid.Column="2" Name="CmbClassicMenu">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Enable"/>
              <ComboBoxItem Content="Disable"/>
            </ComboBox>
          </Grid>
        </Border>

        <Border CornerRadius="12" BorderThickness="1" BorderBrush="#22324A44" Background="{StaticResource Glass2}" Padding="12">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="180"/>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="220"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <TextBlock Grid.Row="0" Grid.Column="0" Text="Explorer full path"/>
            <TextBlock Grid.Row="0" Grid.Column="1" Text="Show full path in title bar (Explorer)." Opacity="0.75"/>
            <ComboBox Grid.Row="0" Grid.Column="2" Name="CmbFullPath">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Enable"/>
              <ComboBoxItem Content="Disable"/>
            </ComboBox>

            <TextBlock Grid.Row="1" Grid.Column="0" Text="Compact mode"/>
            <TextBlock Grid.Row="1" Grid.Column="1" Text="Enable compact spacing in Explorer (Win11)." Opacity="0.75"/>
            <ComboBox Grid.Row="1" Grid.Column="2" Name="CmbCompact">
              <ComboBoxItem Content="No change"/>
              <ComboBoxItem Content="Enable"/>
              <ComboBoxItem Content="Disable"/>
            </ComboBox>
          </Grid>
        </Border>

      </StackPanel>
    </ScrollViewer>

    <DockPanel Grid.Row="2">
      <TextBlock Text="These are applied via registry (mostly HKCU). Explorer restart may be required." Opacity="0.7" VerticalAlignment="Center"/>
      <StackPanel Orientation="Horizontal" DockPanel.Dock="Right">
        <Button Name="BtnOk" Content="OK" BorderBrush="{StaticResource Stroke}" Background="#001C18"/>
        <Button Name="BtnCancel" Content="Cancel" BorderBrush="{StaticResource Stroke2}" Background="#1A001014" Margin="10,0,0,0"/>
      </StackPanel>
    </DockPanel>
  </Grid>
</Window>
"@

  # sanitize control chars (some environments inject 0x02 etc.)
  $x = $x -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]',''

  
  # Escape any accidental XML entities in dialog XAML
  try { $x = [regex]::Replace($x,'&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9A-Fa-f]+;)','&amp;') } catch {}
try {
    $w = [System.Windows.Markup.XamlReader]::Parse($x)

    if ($null -eq $w) { throw "Dialog XAML loader returned null." }
  } catch {
    throw "Enterprise dialog failed: $($_.Exception.Message)"
  }

  $f = @{
    Widgets = $w.FindName('CmbWidgets')
    TaskView = $w.FindName('CmbTaskView')
    Chat = $w.FindName('CmbChat')
    Seconds = $w.FindName('CmbSeconds')
    DesktopIcons = $w.FindName('CmbDesktopIcons')
    WallComp = $w.FindName('CmbWallComp')
    AccentBars = $w.FindName('CmbAccentBars')
    ClassicMenu = $w.FindName('CmbClassicMenu')
    FullPath = $w.FindName('CmbFullPath')
    Compact = $w.FindName('CmbCompact')
    Ok = $w.FindName('BtnOk')
    Cancel = $w.FindName('BtnCancel')
  }

  # set initial selections
  function _Sel([System.Windows.Controls.ComboBox]$cmb, [string]$val) {
    if (-not $cmb) { return }
    if (-not $val) { $val = 'No change' }
    for($i=0;$i -lt $cmb.Items.Count;$i++){
      $item = $cmb.Items[$i]
      $c = [string]($item.Content)
      if ($c -eq $val) { $cmb.SelectedIndex = $i; return }
    }
    $cmb.SelectedIndex = 0
  }

  if (-not $Current) { $Current = @{} }

  function _Get([object]$o,[string]$k){
    if($null -eq $o){ return $null }
    if($o -is [hashtable]){ return $o[$k] }
    try { return ($o | Select-Object -ExpandProperty $k -ErrorAction Stop) } catch { return $null }
  }

  _Sel $f.Widgets (_Get $Current 'Widgets')
  _Sel $f.TaskView (_Get $Current 'TaskView')
  _Sel $f.Chat (_Get $Current 'Chat')
  _Sel $f.Seconds (_Get $Current 'SecondsClock')
  _Sel $f.DesktopIcons (_Get $Current 'DesktopIcons')
  _Sel $f.WallComp (_Get $Current 'WallpaperCompression')
  _Sel $f.AccentBars (_Get $Current 'AccentBars')
  _Sel $f.ClassicMenu (_Get $Current 'ClassicMenu')
  _Sel $f.FullPath (_Get $Current 'FullPath')
  _Sel $f.Compact (_Get $Current 'CompactMode')

  $result = $null
  $f.Ok.Add_Click({
    $result = @{
      Widgets = [string]$f.Widgets.Text
      TaskView = [string]$f.TaskView.Text
      Chat = [string]$f.Chat.Text
      SecondsClock = [string]$f.Seconds.Text
      DesktopIcons = [string]$f.DesktopIcons.Text
      WallpaperCompression = [string]$f.WallComp.Text
      AccentBars = [string]$f.AccentBars.Text
      ClassicMenu = [string]$f.ClassicMenu.Text
      FullPath = [string]$f.FullPath.Text
      CompactMode = [string]$f.Compact.Text
    }
    $w.DialogResult = $true
    $w.Close()
  })
  $f.Cancel.Add_Click({ $w.DialogResult = $false; $w.Close() })

  $w.Owner = $script:Window
  $null = $w.ShowDialog()
  return $result
}

# -------------------------
# Privacy dialog (always available; not nested)
# -------------------------
function Show-PrivacyDialog {
  $msg = @"
Identity Kit stores only local configuration:

• Profiles: $Script:ProfilesDir
• Logs:     $Script:LogsDir
• Backups:  $Script:BackupsDir
• Cache:    $Script:CacheDir

No telemetry, no network calls.
If you enable “Managed storage”, selected images are copied into each profile folder for portability.

Tip: Use “Open IdentityKit” to review files.
"@
  Show-Info -Title "Privacy (local only)" -Message $msg
}

# -------------------------
# Main UI (XAML)
# -------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="47Apps - Identity Kit" Width="1240" Height="760"
        WindowStartupLocation="CenterScreen" Background="#05090B" Foreground="#CFFDF6">
  <Window.Resources>
    <SolidColorBrush x:Key="BG" Color="#05090B"/>
    <SolidColorBrush x:Key="PanelA" Color="#33071013"/>
    <SolidColorBrush x:Key="PanelB" Color="#33070D11"/>
    <SolidColorBrush x:Key="PanelC" Color="#330A070D"/>

    <SolidColorBrush x:Key="StrokeA" Color="#00FFD0"/>
    <SolidColorBrush x:Key="StrokeB" Color="#00FF8A"/>
    <SolidColorBrush x:Key="StrokeC" Color="#FF00D4"/>

    <SolidColorBrush x:Key="GlassBG" Color="#55101818"/>
    <SolidColorBrush x:Key="GlassBG_H" Color="#7720282A"/>
    <SolidColorBrush x:Key="GlassBorder" Color="#22324A44"/>
    <SolidColorBrush x:Key="GlassBorderDim" Color="#22324A44"/>
    <SolidColorBrush x:Key="GlassFocus" Color="#8800FFD0"/>
    <SolidColorBrush x:Key="GlassText" Color="#E8FFFA"/>
    <SolidColorBrush x:Key="GlassTextDim" Color="#A0C9C3"/>

    <Style TargetType="TextBlock">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>

    <Style TargetType="CheckBox">
                      <Setter Property="FontFamily" Value="Consolas"/>
                      <Setter Property="FontSize" Value="12"/>
                      <Setter Property="Foreground" Value="#CFFDF6"/>
                      <Setter Property="Margin" Value="0,1,2,0"/>
                      <Setter Property="VerticalAlignment" Value="Center"/>
                      <Setter Property="SnapsToDevicePixels" Value="True"/>
                      <Setter Property="ToolTip" Value="Click cycles: No change (dash) → Off (empty) → On (check)"/>
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="CheckBox">
                            <DockPanel LastChildFill="True" Background="Transparent">
                              <Border x:Name="Box"
                                      Width="16" Height="16"
                                      CornerRadius="3"
                                      Background="{StaticResource GlassBG_H}"
                                      BorderBrush="{StaticResource GlassBorder}"
                                      BorderThickness="1"
                                      Margin="0,0,8,0"
                                      VerticalAlignment="Center">
                                <Grid>
                                  <Path x:Name="Mark"
                                        Data="M 2 8 L 6 12 L 14 3"
                                        Stroke="{StaticResource StrokeA}"
                                        StrokeThickness="2.2"
                                        StrokeEndLineCap="Round"
                                        StrokeStartLineCap="Round"
                                        Visibility="Collapsed"/>
                                  <Path x:Name="Dash"
                                        Data="M 3 8 L 13 8"
                                        Stroke="{StaticResource StrokeA}"
                                        StrokeThickness="2.2"
                                        StrokeEndLineCap="Round"
                                        StrokeStartLineCap="Round"
                                        Visibility="Collapsed"/>
                                </Grid>
                              </Border>

                              <ContentPresenter VerticalAlignment="Center"/>
                            </DockPanel>

                            <ControlTemplate.Triggers>
                              <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="Dash" Property="Visibility" Value="Collapsed"/>
                                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource StrokeA}"/>
                                <Setter TargetName="Box" Property="BorderThickness" Value="2"/>
                                <Setter Property="ToolTip" Value="ON (will be applied)"/>
                              </Trigger>

                              <Trigger Property="IsChecked" Value="False">
                                <Setter TargetName="Mark" Property="Visibility" Value="Collapsed"/>
                                <Setter TargetName="Dash" Property="Visibility" Value="Collapsed"/>
                                <Setter Property="ToolTip" Value="OFF (will be applied)"/>
                              </Trigger>

                              <Trigger Property="IsChecked" Value="{x:Null}">
                                <Setter TargetName="Mark" Property="Visibility" Value="Collapsed"/>
                                <Setter TargetName="Dash" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource GlassFocus}"/>
                                <Setter TargetName="Box" Property="BorderThickness" Value="2"/>
                                <Setter Property="ToolTip" Value="NO CHANGE (will not modify this setting)"/>
                              </Trigger>

                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource GlassFocus}"/>
                              </Trigger>

                              <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Box" Property="BorderBrush" Value="{StaticResource GlassFocus}"/>
                              </Trigger>

                              <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>

    <Style TargetType="Button">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#CFFDF6"/>
      <Setter Property="Background" Value="#001412"/>
      <Setter Property="BorderBrush" Value="{StaticResource StrokeA}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
    </Style>

    <Style TargetType="ComboBox">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="{StaticResource GlassText}"/>
      <Setter Property="Background" Value="{StaticResource GlassBG}"/>
      <Setter Property="BorderBrush" Value="{StaticResource GlassBorderDim}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Margin" Value="0,2,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <Border x:Name="Bd" CornerRadius="10"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}">
                <DockPanel>
                  <ToggleButton x:Name="ToggleButton" DockPanel.Dock="Right" Focusable="False"
                                IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"
                                Background="Transparent" BorderThickness="0" Width="28">
                    <Path Data="M 0 0 L 6 6 L 12 0 Z" Fill="{StaticResource GlassTextDim}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </ToggleButton>
                  <ContentPresenter Margin="6,0,0,0" VerticalAlignment="Center" HorizontalAlignment="Left"
                                    Content="{TemplateBinding SelectionBoxItem}"/>
                </DockPanel>
              </Border>
              <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                <Border CornerRadius="10" Background="#CC050B0D" BorderBrush="{StaticResource GlassBorderDim}" BorderThickness="1" Padding="6" SnapsToDevicePixels="True">
                  <ScrollViewer Margin="0" SnapsToDevicePixels="True" CanContentScroll="True">
                    <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Opacity" Value="0.45"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocusWithin" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource GlassFocus}"/>
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource GlassBG_H}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
                    <!-- Scrollbars (dark + cyan) -->
                    <Style x:Key="CyanScrollBarThumb" TargetType="Thumb">
                      <Setter Property="Height" Value="20"/>
                      <Setter Property="MinHeight" Value="20"/>
                      <Setter Property="MinWidth" Value="8"/>
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="Thumb">
                            <Border CornerRadius="6"
                                    Background="{StaticResource StrokeA}"
                                    Opacity="0.65"
                                    Margin="2"/>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                      <Style.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter Property="Opacity" Value="0.95"/>
                        </Trigger>
                        <Trigger Property="IsDragging" Value="True">
                          <Setter Property="Opacity" Value="1.0"/>
                        </Trigger>
                      </Style.Triggers>
                    </Style>

                    <Style TargetType="ScrollBar">
                      <Setter Property="Width" Value="10"/>
                      <Setter Property="Background" Value="Transparent"/>
                      <Setter Property="Foreground" Value="{StaticResource StrokeA}"/>
                      <Setter Property="Template">
                        <Setter.Value>
                          <ControlTemplate TargetType="ScrollBar">
                            <Grid Margin="2">
                              <Border CornerRadius="6"
                                      Background="{StaticResource GlassBG}"
                                      BorderBrush="{StaticResource GlassBorderDim}"
                                      BorderThickness="1"
                                      Opacity="0.55"/>
                              <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                  <RepeatButton Command="ScrollBar.LineUpCommand" Opacity="0" IsHitTestVisible="False"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                  <Thumb Style="{StaticResource CyanScrollBarThumb}"/>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                  <RepeatButton Command="ScrollBar.LineDownCommand" Opacity="0" IsHitTestVisible="False"/>
                                </Track.IncreaseRepeatButton>
                              </Track>
                            </Grid>
                            <ControlTemplate.Triggers>
                              <Trigger Property="Orientation" Value="Horizontal">
                                <Setter Property="Width" Value="Auto"/>
                                <Setter Property="Height" Value="10"/>
                              </Trigger>
                              <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Opacity" Value="1.0"/>
                              </Trigger>
                              <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.35"/>
                              </Trigger>
                            </ControlTemplate.Triggers>
                          </ControlTemplate>
                        </Setter.Value>
                      </Setter>
                    </Style>

                    <Style TargetType="ScrollViewer">
                      <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
                      <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
                    </Style>


    <Style TargetType="ComboBoxItem">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="Foreground" Value="{StaticResource GlassText}"/>
      <Setter Property="Background" Value="#07161A"/>
      <Setter Property="Padding" Value="6,4"/>
      <Style.Triggers>
        <Trigger Property="IsHighlighted" Value="True">
          <Setter Property="Background" Value="#003B33"/>
          <Setter Property="Foreground" Value="#E8FFFA"/>
        </Trigger>
      </Style.Triggers>
    </Style>

<Style TargetType="TextBox">
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="{StaticResource GlassText}"/>
      <Setter Property="Background" Value="{StaticResource GlassBG}"/>
      <Setter Property="BorderBrush" Value="{StaticResource GlassBorder}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="Margin" Value="0,2,0,2"/>
    </Style>

    <Style TargetType="Slider">
      <Setter Property="Foreground" Value="{StaticResource GlassTextDim}"/>
      <Setter Property="Margin" Value="0,2,0,2"/>
    </Style>
  </Window.Resources>

  <Grid Background="{StaticResource BG}">
    <!-- Matrix rain -->
    <Canvas Name="MatrixCanvas" IsHitTestVisible="False" Opacity="0.45"/>

    <Grid Margin="16">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Header -->
      <Border Grid.Row="0" CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="#04080A">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel>
            <TextBlock Text="47Apps - Identity Kit" FontSize="28" FontWeight="Bold" Foreground="{StaticResource StrokeA}"/>
            <TextBlock Name="TxtMeta" Margin="0,4,0,0" Opacity="0.9" Foreground="{StaticResource GlassTextDim}"/>
            
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,4,0,0">
            <Border CornerRadius="8" BorderBrush="{StaticResource GlassBorderDim}" BorderThickness="1" Background="{StaticResource GlassBG}" Padding="8,2" Margin="0,0,8,0">
              <TextBlock Name="LblAdmin" Text="Admin: ?" Foreground="#CFFDF6"/>
            </Border>
            <Border CornerRadius="8" BorderBrush="{StaticResource GlassBorderDim}" BorderThickness="1" Background="{StaticResource GlassBG}" Padding="8,2">
              <TextBlock Name="LblMode" Text="Mode: ?" Foreground="#CFFDF6"/>
            </Border>
          </StackPanel>
<TextBlock Text="47 PROTOCOL ACTIVE" Margin="0,8,0,0" Foreground="#7CFFE9" Opacity="0.85"/>
          </StackPanel>

          <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
            <CheckBox Name="ChkMatrix" Content="Matrix rain" IsChecked="True" Margin="0,0,18,0" Visibility="Collapsed"/>
            <CheckBox Name="ChkAdvMode" Content="Advanced mode" IsChecked="True" Margin="0,0,12,0" Visibility="Collapsed" ToolTip="Advanced is always available in this build."/>

            <Button Name="BtnPrivacy" Content="Privacy" Margin="0,0,10,0"/>
            <Button Name="BtnEnterprise" Content="Enterprise &amp; Labs/IT" Margin="0,0,10,0"/>
            <Button Name="BtnOpenProject" Content="47Project" Margin="0,0,10,0"/>
            <Button Name="BtnOpenBase" Content="Open IdentityKit"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Main -->
      <Grid Grid.Row="1" Margin="0,14,0,14">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="2.2*"/>
          <ColumnDefinition Width="1*"/>
        </Grid.ColumnDefinitions>

        <!-- Left -->
        <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel>

            <!-- Profiles -->
            <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="{StaticResource PanelA}">
              <StackPanel>
                <TextBlock Text="Profiles" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeA}"/>

                <DockPanel Margin="0,10,0,0">
                  <ComboBox Name="CmbProfiles" Width="420" ToolTip="Select a saved profile from IdentityKit\Profiles"/>
                  <Button Name="BtnRefresh" Content="Refresh" ToolTip="Reload profiles from disk."/>
                  <Button Name="BtnLoad" Content="Load" ToolTip="Load the selected profile into the UI (no changes applied yet)."/>
                </DockPanel>

                <Separator Margin="0,10,0,10" Opacity="0.45"/>

                <TextBlock Text="Profile management" Opacity="0.75" Margin="0,0,0,6"/>
                <WrapPanel>
                  <Button Name="BtnSave" Content="Save As..." ToolTip="Save current selections as a new profile."/>
                  <Button Name="BtnDelete" Content="Delete" BorderBrush="#FF4D4D" ToolTip="Delete selected profile (cannot be undone)."/>
                  <Button Name="BtnFav" Content="★ Favorite" ToolTip="Toggle favorite for selected profile."/>
                  <Button Name="BtnBaseline" Content="Set Baseline" ToolTip="Mark selected profile as baseline."/>
                </WrapPanel>

                <TextBlock Text="Apply actions" Opacity="0.75" Margin="0,10,0,6"/>
                <WrapPanel>
                  <Button Name="BtnApplyProfile" Content="Apply selected profile" ToolTip="Apply selected profile immediately."/>
                  <Button Name="BtnApplyBaseline" Content="Apply baseline" ToolTip="Apply the baseline profile."/>
                  <Button Name="BtnSnapshot" Content="Snapshot now" ToolTip="Create a snapshot JSON under Backups."/>
                </WrapPanel>

                <TextBlock Text="Packs + automation" Opacity="0.75" Margin="0,10,0,6"/>
                <WrapPanel>
                  <Button Name="BtnExport" Content="Export Pack (.zip)" ToolTip="Export selected profile folder into a zip."/>
                  <Button Name="BtnImport" Content="Import Pack (.zip)" ToolTip="Import a profile zip into Profiles."/>
                  <Button Name="BtnEnableLogon" Content="Apply at logon (enable)" ToolTip="Create a scheduled task to apply selected profile at logon."/>
                  <Button Name="BtnDisableLogon" Content="Disable logon apply" ToolTip="Remove the scheduled task."/>
                  <TextBlock Name="LblLogon" VerticalAlignment="Center" Opacity="0.8" Margin="10,0,0,0"/>
                </WrapPanel>
</StackPanel>
            </Border>

            <!-- Advanced -->
            <Expander Name="ExpAdvanced" Header="System Tweaks: Windows / Taskbar / Explorer" Foreground="{StaticResource StrokeA}" Margin="0,14,0,0" IsExpanded="True" Visibility="Visible">
              <StackPanel>

                <!-- Windows -->
                <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="{StaticResource PanelA}" Margin="0,10,0,0">
                  <StackPanel>
                    <TextBlock Text="Windows" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeA}" Margin="0,0,0,8"/>
                    <TextBlock Text="These affect system look/UX. Defaults are 'No change'." Opacity="0.75" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="140"/>
                        <ColumnDefinition Width="220"/>
                        <ColumnDefinition Width="180"/>
                        <ColumnDefinition Width="220"/>
                      </Grid.ColumnDefinitions>
                      <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                      </Grid.RowDefinitions>

                      <TextBlock Grid.Row="0" Grid.Column="0" Text="Theme:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="0" Grid.Column="1" Name="CmbTheme">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Dark"/>
                        <ComboBoxItem Content="Light"/>
                      </ComboBox>

                      <TextBlock Grid.Row="0" Grid.Column="2" Text="Transparency:" VerticalAlignment="Center"/>
                      <CheckBox Grid.Row="0" Grid.Column="3" Name="ChkTransparency" Content="Enable" Margin="0" IsThreeState="True" IsChecked="{x:Null}"/>

                      <TextBlock Grid.Row="1" Grid.Column="0" Text="Tips &amp; suggestions:" VerticalAlignment="Center"/>
                      <CheckBox Grid.Row="1" Grid.Column="1" Name="ChkDisableTips" Content="Disable" Margin="0" IsThreeState="True" IsChecked="{x:Null}"/>
                    </Grid>
                  </StackPanel>
                </Border>

                <!-- Taskbar -->
                <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="{StaticResource PanelB}" Margin="0,10,0,0">
                  <StackPanel>
                    <TextBlock Text="Taskbar" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeA}" Margin="0,0,0,8"/>
                    <TextBlock Text="Size, alignment and search. Defaults are 'No change'." Opacity="0.75" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="140"/>
                        <ColumnDefinition Width="220"/>
                        <ColumnDefinition Width="140"/>
                        <ColumnDefinition Width="220"/>
                      </Grid.ColumnDefinitions>
                      <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                      </Grid.RowDefinitions>

                      <TextBlock Grid.Row="0" Grid.Column="0" Text="Taskbar size:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="0" Grid.Column="1" Name="CmbTaskbarSize">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Default"/>
                        <ComboBoxItem Content="Small"/>
                        <ComboBoxItem Content="Large"/>
                      </ComboBox>

                      <TextBlock Grid.Row="0" Grid.Column="2" Text="Taskbar align:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="0" Grid.Column="3" Name="CmbTaskbarAlign">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Center"/>
                        <ComboBoxItem Content="Left"/>
                      </ComboBox>

                      <TextBlock Grid.Row="1" Grid.Column="0" Text="Search:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="1" Grid.Column="1" Name="CmbSearch">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Hidden"/>
                        <ComboBoxItem Content="Icon"/>
                        <ComboBoxItem Content="Box"/>
                      </ComboBox>

                      <TextBlock Grid.Row="1" Grid.Column="2" Text="Combine:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="1" Grid.Column="3" Name="CmbCombine">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Always"/>
                        <ComboBoxItem Content="When full"/>
                        <ComboBoxItem Content="Never"/>
                      </ComboBox>
                    </Grid>
                  </StackPanel>
                </Border>

                <!-- Explorer -->
                <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="{StaticResource PanelC}" Margin="0,10,0,0">
                  <StackPanel>
                    <TextBlock Text="Explorer" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeA}" Margin="0,0,0,8"/>
                    <TextBlock Text="File extensions, hidden files and launch behavior. Defaults are 'No change'." Opacity="0.75" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <Grid>
                      <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="1*"/>
                        <ColumnDefinition Width="1*"/>
                      </Grid.ColumnDefinitions>
                      <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                      </Grid.RowDefinitions>

                      <CheckBox Name="ChkExt" Grid.Row="0" Grid.Column="0" Content="Show file extensions" ToolTip="HKCU: HideFileExt" IsThreeState="True" IsChecked="{x:Null}"/>
                      <CheckBox Name="ChkHidden" Grid.Row="0" Grid.Column="1" Content="Show hidden files" ToolTip="HKCU: Hidden" IsThreeState="True" IsChecked="{x:Null}"/>
                      <CheckBox Name="ChkSuper" Grid.Row="1" Grid.Column="0" Content="Show protected OS files" ToolTip="HKCU: ShowSuperHidden" IsThreeState="True" IsChecked="{x:Null}"/>

                      <TextBlock Grid.Row="2" Grid.Column="0" Text="Explorer launch:" VerticalAlignment="Center"/>
                      <ComboBox Grid.Row="2" Grid.Column="1" Name="CmbLaunch" Width="220">
                        <ComboBoxItem Content="No change" IsSelected="True"/>
                        <ComboBoxItem Content="Quick access"/>
                        <ComboBoxItem Content="This PC"/>
                      </ComboBox>
                    </Grid>
                  </StackPanel>
                </Border>

                <!-- Labs/IT -->
                <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="#020507" Margin="0,10,0,0">
                  <StackPanel>
                    <TextBlock Text="Labs/IT" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeA}" Margin="0,0,0,8"/>
                    <TextBlock Text="Apply behavior and maintenance toggles." Opacity="0.75" TextWrapping="Wrap" Margin="0,0,0,10"/>

                    <WrapPanel>
                      <CheckBox Name="ChkRestartExplorer" Content="Restart Explorer after apply" IsChecked="True" Margin="0,0,18,8"/>
                      <CheckBox Name="ChkSnapshotBefore" Content="Snapshot before apply" IsChecked="True" Margin="0,0,18,8"/>
                      <CheckBox Name="ChkWriteHKCU" Content="Write HKCU tweaks" IsChecked="True" Margin="0,0,18,8"/>
                      <CheckBox Name="ChkProgramData" Content="Use ProgramData cache" IsChecked="True" Margin="0,0,18,8"/>
                      <CheckBox Name="ChkHealthAutoFix" Content="Health check: auto-fix when possible" Margin="0,0,18,8"/>
                      <CheckBox Name="ChkManagedStorage" Content="Manage Storage Sense" Margin="0,0,18,8" IsThreeState="True" IsChecked="{x:Null}"/>
                    </WrapPanel>
                    <DockPanel Margin="0,6,0,0">
                      <Button Name="BtnOpenData" Content="Open data folder" Margin="0,0,10,0" ToolTip="Open the IdentityKit data directory."/>
                      <Button Name="BtnEnablePortable" Content="Enable portable mode" Margin="0,0,10,0" ToolTip="Use a local IdentityKitData folder next to the script (requires restart)."/>
                      <Button Name="BtnDisablePortable" Content="Disable portable mode" ToolTip="Return to the default %SystemDrive%\47Project\IdentityKit location (requires restart)."/>
                    </DockPanel>

                  </StackPanel>
                </Border>

              </StackPanel>
            </Expander>

            <!-- Identity -->
            <Border CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeB}" Background="{StaticResource PanelB}" Margin="0,14,0,0">
              <StackPanel>
                <TextBlock Text="Identity" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeB}" Margin="0,0,0,10"/>
                <TextBlock Text="Pick images -> preview -> Apply. PNG/JPG/BMP/GIF are supported (GIF uses first frame)." Opacity="0.75" TextWrapping="Wrap"/>

                <!-- Profile picture -->
                <Border CornerRadius="12" Padding="12" BorderThickness="1" BorderBrush="{StaticResource StrokeB}" Background="#22040A08" Margin="0,12,0,10">
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="110"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Grid Width="96" Height="96">
                      <Border CornerRadius="12" BorderThickness="1" BorderBrush="{StaticResource GlassBorder}" Background="#11000000"/>
                      <Image Name="ImgProfile" Stretch="UniformToFill" Width="96" Height="96"/>
                      <TextBlock Name="PhProfile" Text="No profile image" Foreground="{StaticResource GlassTextDim}"
                                 HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" Margin="6"/>
                    </Grid>

                    <StackPanel Grid.Column="1">
                      <WrapPanel>
                        <CheckBox Name="ChkProfile" Content="Profile picture" Margin="0,0,18,0"/>
                        <Button Name="BtnPickProfile" Content="Browse..." Margin="0,0,10,0"/>
                        <Button Name="BtnClearProfile" Content="Clear" Margin="0,0,10,0"/>
                        <Button Name="BtnOpenProfile" Content="Open" Margin="0,0,10,0"/>
                        <Button Name="BtnRevealProfile" Content="Reveal"/>
                      </WrapPanel>

                      <WrapPanel Margin="0,8,0,0">
                        <CheckBox Name="ChkCrop" Content="Crop" Margin="0,0,18,0"/>
                        <TextBlock Text="Crop mode:" VerticalAlignment="Center" Opacity="0.8" Margin="0,0,6,0"/>
                        <ComboBox Name="CmbCrop" Width="180">
                          <ComboBoxItem Content="Center"/>
                          <ComboBoxItem Content="TopLeft"/>
                          <ComboBoxItem Content="TopRight"/>
                          <ComboBoxItem Content="BottomLeft"/>
                          <ComboBoxItem Content="BottomRight"/>
                        </ComboBox>
                      </WrapPanel>

                      <TextBlock Name="LblProfileState" Opacity="0.85" Margin="0,8,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                  </Grid>
                </Border>

                <!-- Lock screen -->
                <Border CornerRadius="12" Padding="12" BorderThickness="1" BorderBrush="{StaticResource StrokeB}" Background="#22040A08" Margin="0,0,0,10">
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="110"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Grid Width="96" Height="96">
                      <Border CornerRadius="12" BorderThickness="1" BorderBrush="{StaticResource GlassBorder}" Background="#11000000"/>
                      <Image Name="ImgLock" Stretch="UniformToFill" Width="96" Height="96"/>
                      <TextBlock Name="PhLock" Text="No lock image" Foreground="{StaticResource GlassTextDim}"
                                 HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" Margin="6"/>
                    </Grid>

                    <StackPanel Grid.Column="1">
                      <WrapPanel>
                        <CheckBox Name="ChkLock" Content="Lock screen" Margin="0,0,18,0"/>
                        <Button Name="BtnPickLock" Content="Browse..." Margin="0,0,10,0"/>
                        <Button Name="BtnClearLock" Content="Clear" Margin="0,0,10,0"/>
                        <Button Name="BtnOpenLock" Content="Open" Margin="0,0,10,0"/>
                        <Button Name="BtnRevealLock" Content="Reveal"/>
                      </WrapPanel>

                      <WrapPanel Margin="0,8,0,0">
                        <TextBlock Text="Mode:" VerticalAlignment="Center" Opacity="0.8" Margin="0,0,6,0"/>
                        <ComboBox Name="CmbLockMode" Width="210" SelectedIndex="0">
                          <ComboBoxItem Content="User"/>
                          <ComboBoxItem Content="Enforced"/>
                        </ComboBox>
                        <CheckBox Name="ChkNoChange" Content="Disable changing (enforced)" Margin="18,0,0,0"/>
                      </WrapPanel>

                      <TextBlock Name="LblLockState" Opacity="0.85" Margin="0,8,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                  </Grid>
                </Border>

                <!-- Wallpaper -->
                <Border CornerRadius="12" Padding="12" BorderThickness="1" BorderBrush="{StaticResource StrokeB}" Background="#22040A08">
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="110"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Grid Width="96" Height="96">
                      <Border CornerRadius="12" BorderThickness="1" BorderBrush="{StaticResource GlassBorder}" Background="#11000000"/>
                      <Image Name="ImgWall" Stretch="UniformToFill" Width="96" Height="96"/>
                      <TextBlock Name="PhWall" Text="No wallpaper" Foreground="{StaticResource GlassTextDim}"
                                 HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" Margin="6"/>
                    </Grid>

                    <StackPanel Grid.Column="1">
                      <WrapPanel>
                        <CheckBox Name="ChkWall" Content="Desktop wallpaper" Margin="0,0,18,0"/>
                        <Button Name="BtnPickWall" Content="Browse..." Margin="0,0,10,0"/>
                        <Button Name="BtnWallFromLib" Content="From Library" Margin="0,0,10,0"/>
                        <Button Name="BtnAddLib" Content="Add to Library" Margin="0,0,10,0"/>
                        <Button Name="BtnClearWall" Content="Clear" Margin="0,0,10,0"/>
                        <Button Name="BtnOpenWall" Content="Open" Margin="0,0,10,0"/>
                        <Button Name="BtnRevealWall" Content="Reveal"/>
                      </WrapPanel>

                      <WrapPanel Margin="0,8,0,0">
                        <TextBlock Text="Style:" VerticalAlignment="Center" Opacity="0.8" Margin="0,0,6,0"/>
                        <ComboBox Name="CmbWallStyle" Width="140">
                          <ComboBoxItem Content="Fill"/>
                          <ComboBoxItem Content="Fit"/>
                          <ComboBoxItem Content="Stretch"/>
                          <ComboBoxItem Content="Tile"/>
                          <ComboBoxItem Content="Center"/>
                          <ComboBoxItem Content="Span"/>
                        </ComboBox>
                        <TextBlock Text="Library:" VerticalAlignment="Center" Opacity="0.7" Margin="18,0,6,0"/>
                        <TextBlock Name="LblLib" VerticalAlignment="Center" Opacity="0.7"/>
                      </WrapPanel>

                      <TextBlock Name="LblWallState" Opacity="0.85" Margin="0,8,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                  </Grid>
                </Border>

              </StackPanel>
            </Border>

          </StackPanel>
        </ScrollViewer>

        <!-- Right -->
        <Border Grid.Column="1" CornerRadius="14" Padding="14" BorderThickness="1" BorderBrush="{StaticResource StrokeC}" Background="{StaticResource PanelC}" Margin="14,0,0,0">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel Grid.Row="0">
              <TextBlock Text="Log / Preview" FontSize="16" FontWeight="Bold" Foreground="{StaticResource StrokeC}"/>
              <TextBlock Name="TxtLogPath" Opacity="0.7" Margin="0,6,0,0"/>
            </StackPanel>

            <TextBox Grid.Row="1" Name="TxtLog" Margin="0,10,0,0" IsReadOnly="True"
                     TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>

            <TextBox Grid.Row="2" Name="TxtPreview" Margin="0,10,0,0" IsReadOnly="True"
                     TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Height="140"/>

            <DockPanel Grid.Row="3" Margin="0,10,0,0">
              <Button Name="BtnOpenLogs" Content="Open logs" Margin="0,0,10,0"/>
                            <Button Name="BtnCopyLog" Content="Copy log" Margin="0,0,10,0" ToolTip="Copy log text to clipboard."/>
              <Button Name="BtnOpenSnapshots" Content="Open snapshots" Margin="0,0,10,0" ToolTip="Open the Snapshots folder."/>
<Button Name="BtnOpenBase2" Content="Open IdentityKit"/>
              <Button Name="BtnUndoLast" Content="Undo last apply" Margin="10,0,0,0" ToolTip="Restore the most recent snapshot (before the last apply)."/>
              <Button Name="BtnRestoreSnap" Content="Restore snapshot" Margin="10,0,0,0" BorderBrush="#FF00D4"/>
            </DockPanel>
          </Grid>
        </Border>
      </Grid>

      <!-- Footer -->
      <Border Grid.Row="2" CornerRadius="14" Padding="12" BorderThickness="1" BorderBrush="{StaticResource StrokeA}" Background="#04080A">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <DockPanel>
            <TextBlock Name="TxtFooter" Text="Ready." Opacity="0.9" VerticalAlignment="Center"/>
            <CheckBox Name="ChkDryRun" Content="Dry run (preview only)" Margin="18,0,0,0" VerticalAlignment="Center"/>
              <TextBlock Text="Apply mode:" Margin="18,0,6,0" VerticalAlignment="Center" Opacity="0.75"/>
              <ComboBox Name="CmbApplyMode" Width="230" ToolTip="Choose how Apply behaves." SelectedIndex="0">
                <ComboBoxItem Content="Apply selected items"/>
                <ComboBoxItem Content="Apply current profile (all)"/>
                <ComboBoxItem Content="Revert to baseline"/>
              </ComboBox>
            <Button Name="BtnHealth" Content="Health check" Margin="18,0,0,0"/>
            <Button Name="BtnCleanup" Content="Cleanup cache" Margin="10,0,0,0"/>
          </DockPanel>

          <StackPanel Grid.Column="1" Orientation="Horizontal">
            <Button Name="BtnQuickProfile" Content="Profile" Margin="0,0,10,0" ToolTip="Quick apply: Profile picture only"/>
            <Button Name="BtnQuickLock" Content="Lock" Margin="0,0,10,0" ToolTip="Quick apply: Lock screen only"/>
            <Button Name="BtnQuickWall" Content="Wallpaper" Margin="0,0,10,0" ToolTip="Quick apply: Wallpaper only"/>
            <Button Name="BtnResetNoChange" Content="Reset No change" Margin="0,0,10,0" ToolTip="Set tri-state toggles back to No change (dash)."/>
            <Button Name="BtnApply" Content="Apply" Margin="0,0,10,0"/>
            <Button Name="BtnExit" Content="Exit" Margin="0"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Grid>
</Window>
"@

# Sanitize control chars to avoid rare XAML parse failures
$xaml = $xaml -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]',''

# Escape any accidental XML entities (avoid 'parsing EntityName' errors)
try {
  $xaml = [regex]::Replace($xaml,'&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9A-Fa-f]+;)','&amp;')
} catch {}

try {
  # Prefer Parse(): avoids XmlReader/Stream conversion quirks in some PS/WPF environments
  $Window = [System.Windows.Markup.XamlReader]::Parse($xaml)
} catch {
  try {
    # Robust fallback: parse via an XmlReader over the string (no [xml] casting)
    $sr = New-Object System.IO.StringReader($xaml)

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null

    $xr = [System.Xml.XmlReader]::Create($sr, $settings)
    try { $null = $xr.MoveToContent() } catch {}
    $Window = [System.Windows.Markup.XamlReader]::Load($xr)

    try { $xr.Close() } catch {}
    try { $sr.Close() } catch {}
  } catch {
    Show-Error -Title "FATAL ERROR" -Message ("XAML load failed: " + $_.Exception.Message)
    exit 1
  }
}

# Safety: ensure we actually got a Window instance
if ($null -eq $Window) {
  Show-Error -Title "FATAL ERROR" -Message "XAML loader returned null Window. (This usually means the XAML string was empty or invalid after sanitization.)"
  exit 1
}
if (-not ($Window -is [System.Windows.Window])) {
  $t = $Window.GetType().FullName
  Show-Error -Title "FATAL ERROR" -Message ("XAML root is not a Window (got: " + $t + ").")
  exit 1
}
# Expose commonly used controls
$script:Window = $Window
$script:TxtLog = $Window.FindName('TxtLog')
$script:TxtPreview = $Window.FindName('TxtPreview')
$script:TxtFooter = $Window.FindName('TxtFooter')
$script:TxtMeta = $Window.FindName('TxtMeta')
$script:TxtLogPath = $Window.FindName('TxtLogPath')

# Header badges
try {
  $a = $Window.FindName('LblAdmin')
  if ($a) { $a.Text = ("Admin: " + ($(if($Script:IsAdmin){'Yes'}else{'No'}))) }
  $m = $Window.FindName('LblMode')
  if ($m) { $m.Text = ("Mode: " + ($(if($Script:IsPortable){'Portable'}else{'Standard'}))) }
} catch {}



Log-Line INFO "$Script:AppName $Script:AppVersion starting..."
$script:TxtLogPath.Text = "Log: $Script:LogFile"
$script:TxtMeta.Text = "Version $Script:AppVersion | Admin: $Script:IsAdmin | Base: $Script:BasePath"
$Window.FindName('LblLib').Text = $Script:LibDir

# -------------------------
# State
# -------------------------
$script:State = @{
  ProfileImage = $null
  LockImage    = $null
  WallpaperImage = $null
    Enterprise = @{ Widgets='No change'; TaskView='No change'; Chat='No change'; TaskbarAnim='No change'; DesktopIcons='No change'; WallComp='No change'; AccentBars='No change'; FullPath='No change'; Compact='No change'; ClassicMenu='No change' }
}

function Update-Placeholders {
  $Window.FindName('PhProfile').Visibility = if($script:State.ProfileImage){'Collapsed'}else{'Visible'}
  $Window.FindName('PhLock').Visibility    = if($script:State.LockImage){'Collapsed'}else{'Visible'}
  $Window.FindName('PhWall').Visibility    = if($script:State.WallpaperImage){'Collapsed'}else{'Visible'}
}

function Update-Thumbs {
  $img = Load-BitmapImageToWpf $script:State.ProfileImage
  $Window.FindName('ImgProfile').Source = $img
  $img = Load-BitmapImageToWpf $script:State.LockImage
  $Window.FindName('ImgLock').Source = $img
  $img = Load-BitmapImageToWpf $script:State.WallpaperImage
  $Window.FindName('ImgWall').Source = $img
  Update-Placeholders
}

function Set-StateLabel {
  param([string]$which,[string]$text)
  switch($which){
    'Profile'{ $Window.FindName('LblProfileState').Text = $text }
    'Lock'{ $Window.FindName('LblLockState').Text = $text }
    'Wall'{ $Window.FindName('LblWallState').Text = $text }
  }
}

function Select-ImageFile {
  param([string]$Title="Select image")
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Title = $Title
  $dlg.Filter = "Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*"
  $dlg.Multiselect = $false
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
  return $null
}

function Reveal-File([string]$Path) {
  if (-not $Path) { return }
  try { Start-Process explorer.exe "/select,`"$Path`"" | Out-Null } catch {}
}
function Open-Path([string]$Path) {
  if (-not $Path) { return }
  try { Start-Process $Path | Out-Null } catch {}
}

# -------------------------
# Planned changes preview
# -------------------------

function Reset-NoChange {
  param([System.Windows.Window]$Window)

  $names = @(
    'ChkTaskbarAlign','ChkTaskView','ChkWidgets','ChkSearchBox','ChkExplorerClassic','ChkExplorerCompact',
    'ChkThemeDark','ChkThemeLight','ChkAccentCyan','ChkAccentMagenta',
    'ChkManagedStorage','ChkTelemetry','ChkDefender','ChkSmartScreen'
  )

  foreach($n in $names){
    try {
      $c = $Window.FindName($n)
      if ($c -and ($c -is [System.Windows.Controls.CheckBox]) -and $c.IsThreeState) {
        $c.IsChecked = $null
      }
    } catch {}
  }
}

function Build-ConfigFromUI {
  $cfg = @{
    Meta = @{
      Name = $Window.FindName('CmbProfiles').Text
      Version = $Script:AppVersion
      Updated = (Get-Date).ToString('o')
    }

    # Identity
    ProfileImage = $script:State.ProfileImage
    LockImage = $script:State.LockImage
    WallpaperImage = $script:State.WallpaperImage
    EnableProfile = [bool]$Window.FindName('ChkProfile').IsChecked
    EnableLock = [bool]$Window.FindName('ChkLock').IsChecked
    EnableWall = [bool]$Window.FindName('ChkWall').IsChecked

    CropEnabled = [bool]$Window.FindName('ChkCrop').IsChecked
    CropMode = (Get-ComboValue ($Window.FindName('CmbCrop')) 'Center')
    LockMode = (Get-ComboValue ($Window.FindName('CmbLockMode')) 'User')
    LockDisableChanging = [bool]$Window.FindName('ChkNoChange').IsChecked
    WallStyle = (Get-ComboValue ($Window.FindName('CmbWallStyle')) 'Fill')

    # Advanced
    Theme = (Get-ComboValue ($Window.FindName('CmbTheme')) 'No change')
    Transparency = $Window.FindName('ChkTransparency').IsChecked
    TaskbarSize = (Get-ComboValue ($Window.FindName('CmbTaskbarSize')) 'Default')
    TaskbarAlign = (Get-ComboValue ($Window.FindName('CmbTaskbarAlign')) 'Center')
    Search = (Get-ComboValue ($Window.FindName('CmbSearch')) 'Icon')
    Combine = (Get-ComboValue ($Window.FindName('CmbCombine')) 'Always')
    ShowExtensions = $Window.FindName('ChkExt').IsChecked
    ShowHidden = $Window.FindName('ChkHidden').IsChecked
    ShowProtectedOS = $Window.FindName('ChkSuper').IsChecked
    ExplorerLaunch = (Get-ComboValue ($Window.FindName('CmbLaunch')) 'Home')

    DisableTips = [bool]$Window.FindName('ChkDisableTips').IsChecked
    ManagedStorage = [bool]$Window.FindName('ChkManagedStorage').IsChecked

    ApplyBehavior = @{
      WriteHKCU = [bool]$Window.FindName('ChkWriteHKCU').IsChecked
      UpdateProgramData = [bool]$Window.FindName('ChkProgramData').IsChecked
      RestartExplorer = [bool]$Window.FindName('ChkRestartExplorer').IsChecked
      SnapshotBefore = [bool]$Window.FindName('ChkSnapshotBefore').IsChecked
    }

    Matrix = @{ Enabled = $true; Intensity = 60; SpeedMs = 50 }

    Enterprise = $script:State.Enterprise
  }

  # ---- Normalize UI values (avoid ValidateSet / null issues) ----
  $lm = $cfg.LockMode
  if ([string]::IsNullOrWhiteSpace($lm)) { $lm = 'User' }
  elseif ($lm -match 'Enforced') { $lm = 'Enforced' }
  else { $lm = 'User' }
  $cfg.LockMode = $lm
  if ([bool]$cfg.LockDisableChanging) { $cfg.LockMode = 'Enforced' }

  $ws = $cfg.WallStyle
  if ([string]::IsNullOrWhiteSpace($ws)) { $ws = 'Fill' }
  $wsTok = ($ws -split '\s+')[0]
  if (@('Fill','Fit','Stretch','Tile','Center','Span') -contains $wsTok) { $cfg.WallStyle = $wsTok } else { $cfg.WallStyle = 'Fill' }

  if (-not $cfg.Enterprise) { $cfg.Enterprise = @{} }
  $entDefaults = @{
    Widgets      = 'No change'
    TaskView     = 'No change'
    Chat         = 'No change'
    TaskbarAnim  = 'No change'
    DesktopIcons = 'No change'
    WallpaperComp= 'No change'
  }
  foreach ($k in $entDefaults.Keys) {
    if (-not $cfg.Enterprise.ContainsKey($k) -or [string]::IsNullOrWhiteSpace([string]$cfg.Enterprise[$k])) {
      $cfg.Enterprise[$k] = $entDefaults[$k]
    }
  }

  return $cfg
}



function Update-Preview {
  $cfg = Build-ConfigFromUI
  $lines = New-Object System.Collections.Generic.List[string]

  $lines.Add("Planned changes (preview):")
  $lines.Add(("Theme: {0} | Transparency: {1}" -f $cfg.Theme, $cfg.Transparency))
  $lines.Add(("Taskbar: Size={0}, Align={1} | Search={2} | Combine={3}" -f $cfg.TaskbarSize, $cfg.TaskbarAlign, $cfg.Search, $cfg.Combine))
  $lines.Add(("Explorer: Ext={0}, Hidden={1}, ProtectedOS={2}, Launch={3}" -f $cfg.ShowExtensions, $cfg.ShowHidden, $cfg.ShowProtectedOS, $cfg.ExplorerLaunch))

  if ($cfg.EnableProfile -and $cfg.ProfileImage) { $lines.Add("Profile picture: YES (" + (Split-Path -Leaf $cfg.ProfileImage) + ")") }
  else { $lines.Add("Profile picture: (no change)") }

  if ($cfg.EnableLock -and $cfg.LockImage) { $lines.Add("Lock screen: YES (" + $cfg.LockMode + ")") }
  else { $lines.Add("Lock screen: (no change)") }

  if ($cfg.EnableWall -and $cfg.WallpaperImage) { $lines.Add("Wallpaper: YES (" + $cfg.WallStyle + ")") }
  else { $lines.Add("Wallpaper: (no change)") }

  if ($cfg.Enterprise -and $cfg.Enterprise.Count -gt 0) {
    $lines.Add("Enterprise/Extras: configured")
  } else {
    $lines.Add("Enterprise/Extras: (none)")
  }

  $lines.Add(("Apply behavior: HKCUMap={0}, ProgramData={1}, RestartExplorer={2}, SnapshotBefore={3}" -f
    $cfg.ApplyBehavior.WriteHKCU, $cfg.ApplyBehavior.UpdateProgramData, $cfg.ApplyBehavior.RestartExplorer, $cfg.ApplyBehavior.SnapshotBefore))

  $script:TxtPreview.Text = ($lines -join "`r`n")
}

# -------------------------
# Matrix rain engine (simple + lightweight)
# -------------------------
$script:MatrixTimer = New-Object Windows.Threading.DispatcherTimer
$script:MatrixTimer.Interval = [TimeSpan]::FromMilliseconds(45)
$script:Rand = New-Object System.Random
$script:MatrixDrops = @()

function Matrix-Init {
  $c = $Window.FindName('MatrixCanvas')
  $c.Children.Clear()
  $script:MatrixDrops = @()
  $width = [int]$Window.ActualWidth
  if ($width -le 0) { $width = 1200 }
  $cols = [Math]::Max(10,[int]($width / 18))
  for ($i=0;$i -lt $cols;$i++){
    $script:MatrixDrops += [pscustomobject]@{ X = $i*18; Y = $script:Rand.Next(-600,0); Speed = $script:Rand.Next(10,35) }
  }
}
function Matrix-Tick {
  $cfg = Build-ConfigFromUI
  $enabled = [bool]$cfg.Matrix.Enabled
  $canvas = $Window.FindName('MatrixCanvas')
  if (-not $enabled) { $canvas.Visibility='Collapsed'; return } else { $canvas.Visibility='Visible' }
  $canvas.Opacity = [Math]::Min(0.85, [Math]::Max(0.25, $cfg.Matrix.Intensity / 110.0))

  # clear a bit (keep some trails)
  if ($canvas.Children.Count -gt 400) {
    $toRemove = [Math]::Min(100, $canvas.Children.Count)
    for($ri=0; $ri -lt $toRemove; $ri++){ $canvas.Children.RemoveAt(0) }
  }
  $h = [int]$Window.ActualHeight
  if ($h -le 0) { $h = 760 }

  $chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ47"
  foreach($d in $script:MatrixDrops){
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $chars[$script:Rand.Next(0,$chars.Length)]
    $tb.FontFamily = 'Consolas'
    $tb.FontSize = 14
    $tb.Foreground = [System.Windows.Media.Brushes]::Aquamarine
    $tb.Opacity = 0.35 + ($script:Rand.NextDouble()*0.35)
    [System.Windows.Controls.Canvas]::SetLeft($tb, $d.X)
    [System.Windows.Controls.Canvas]::SetTop($tb, $d.Y)
    $canvas.Children.Add($tb) | Out-Null

    $d.Y += $d.Speed
    if ($d.Y -gt $h) { $d.Y = $script:Rand.Next(-600,0) }
  }
}

$script:MatrixTimer.Add_Tick({ try { Matrix-Tick } catch {} })

# -------------------------
# Profiles UI actions
# -------------------------
function Refresh-ProfilesUI {
  $cmb = $Window.FindName('CmbProfiles')
  $cmb.Items.Clear()
  $list = Get-ProfileList
  foreach($p in $list){
    $tag = if($p.Favorite){"★ " + $p.Name}else{$p.Name}
    $null = $cmb.Items.Add($tag)
  }
  if ($cmb.Items.Count -gt 0 -and $cmb.SelectedIndex -lt 0) { $cmb.SelectedIndex = 0 }
}

function Get-SelectedProfileName {
  $raw = [string]$Window.FindName('CmbProfiles').Text
  if ($raw.StartsWith('★ ')) { return $raw.Substring(2) }
  return $raw.Trim()
}

function Load-ProfileIntoUI([string]$Name) {
  $cfg = Read-ProfileCfg $Name
  if (-not $cfg) { Log-Line WARN "Profile not found: $Name"; return }

  # Identity
  $script:State.ProfileImage = $cfg.ProfileImage
  $script:State.LockImage = $cfg.LockImage
  $script:State.WallpaperImage = $cfg.WallpaperImage
  $Window.FindName('ChkProfile').IsChecked = [bool]$cfg.EnableProfile
  $Window.FindName('ChkLock').IsChecked = [bool]$cfg.EnableLock
  $Window.FindName('ChkWall').IsChecked = [bool]$cfg.EnableWall
  $Window.FindName('ChkCrop').IsChecked = [bool]$cfg.CropEnabled
  $Window.FindName('CmbCrop').Text = [string]$cfg.CropMode
  $Window.FindName('CmbLockMode').Text = [string]$cfg.LockMode
  $Window.FindName('ChkNoChange').IsChecked = [bool]$cfg.LockDisableChanging
  $Window.FindName('CmbWallStyle').Text = [string]$cfg.WallStyle

  # Advanced
  $Window.FindName('CmbTheme').Text = [string]$cfg.Theme
  $Window.FindName('ChkTransparency').IsChecked = $cfg.Transparency
  $Window.FindName('CmbTaskbarSize').Text = [string]$cfg.TaskbarSize
  $Window.FindName('CmbTaskbarAlign').Text = [string]$cfg.TaskbarAlign
  $Window.FindName('CmbSearch').Text = [string]$cfg.Search
  $Window.FindName('CmbCombine').Text = [string]$cfg.Combine
  $Window.FindName('ChkExt').IsChecked = $cfg.ShowExtensions
  $Window.FindName('ChkHidden').IsChecked = $cfg.ShowHidden
  $Window.FindName('ChkSuper').IsChecked = $cfg.ShowProtectedOS
  $Window.FindName('CmbLaunch').Text = [string]$cfg.ExplorerLaunch

  $Window.FindName('ChkDisableTips').IsChecked = [bool]$cfg.DisableTips
  $Window.FindName('ChkManagedStorage').IsChecked = [bool]$cfg.ManagedStorage

  $Window.FindName('ChkWriteHKCU').IsChecked = [bool]$cfg.ApplyBehavior.WriteHKCU
  $Window.FindName('ChkProgramData').IsChecked = [bool]$cfg.ApplyBehavior.UpdateProgramData
  $Window.FindName('ChkRestartExplorer').IsChecked = [bool]$cfg.ApplyBehavior.RestartExplorer
  $Window.FindName('ChkSnapshotBefore').IsChecked = [bool]$cfg.ApplyBehavior.SnapshotBefore

  $Window.FindName('ChkMatrix').IsChecked = [bool]$cfg.Matrix.Enabled
  $sInt = $Window.FindName('SldIntensity'); if($sInt -and ($sInt.PSObject.Properties.Name -contains 'Value')){ $sInt.Value = 60 }  # default; Matrix is auto
  $sSpd = $Window.FindName('SldSpeed'); if($sSpd -and ($sSpd.PSObject.Properties.Name -contains 'Value')){ $sSpd.Value = 50 }  # default; Matrix is auto

    $script:State.Enterprise = @{ Widgets='No change'; TaskView='No change'; Chat='No change'; TaskbarAnim='No change'; DesktopIcons='No change'; WallComp='No change'; AccentBars='No change'; FullPath='No change'; Compact='No change'; ClassicMenu='No change' }
  try {
    if ($cfg.Enterprise) {
      if ($cfg.Enterprise -is [hashtable]) {
        foreach($k in $cfg.Enterprise.Keys) { $script:State.Enterprise[$k] = $cfg.Enterprise[$k] }
      } else {
        foreach($p in $cfg.Enterprise.PSObject.Properties) { $script:State.Enterprise[$p.Name] = $p.Value }
      }
    }
  } catch {}
  Update-Thumbs
  Update-Preview
  Log-Line OK "Loaded profile: $Name"
}

function Prompt-ProfileName([string]$Default='MyProfile') {
  $input = [Microsoft.VisualBasic.Interaction]::InputBox("Profile name:", "Save profile", $Default)
  if ([string]::IsNullOrWhiteSpace($input)) { return $null }
  # sanitize
  $safe = ($input -replace '[\\/:*?"<>|]', '').Trim()
  if ([string]::IsNullOrWhiteSpace($safe)) { return $null }
  return $safe
}

# -------------------------
# Apply config
# -------------------------

function Apply-Config {
  param(
    [Parameter(Mandatory=$true)][hashtable]$Cfg,
    [switch]$WhatIf,
    [bool]$ApplyAdvanced = $false
  )

  if ($Cfg.ApplyBehavior -and $Cfg.ApplyBehavior.SnapshotBefore) {
    try { Snapshot-Now $Cfg } catch { }
  }

  $didAdvanced = $false
  if ($ApplyAdvanced) {
    try {
      Apply-AdvancedHKCU -Cfg $Cfg -WhatIf:$WhatIf
      $didAdvanced = $true
    } catch {
      if (-not $WhatIf) { throw }
    }
  }

  # Identity (selected items)
  if ($Cfg.EnableProfile -and $Cfg.ProfileImage) {
    Apply-ProfilePicture -SourcePath $Cfg.ProfileImage -EnableCrop:$Cfg.CropEnabled -CropMode:$Cfg.CropMode `
      -UpdateProgramData:$Cfg.ApplyBehavior.UpdateProgramData -WriteHKCU:$Cfg.ApplyBehavior.WriteHKCU -WhatIf:$WhatIf
  }

  if ($Cfg.EnableLock -and $Cfg.LockImage) {
    $lm = $Cfg.LockMode
    if ([string]::IsNullOrWhiteSpace($lm)) { $lm = 'User' }
    Apply-LockScreen -ImagePath $Cfg.LockImage -Mode $lm -NoChange:([bool]$Cfg.LockDisableChanging) -WhatIf:$WhatIf
  }

  if ($Cfg.EnableWall -and $Cfg.WallpaperImage) {
    $ws = $Cfg.WallStyle
    if ([string]::IsNullOrWhiteSpace($ws)) { $ws = 'Fill' }
    Apply-Wallpaper -ImagePath $Cfg.WallpaperImage -Style $ws -WhatIf:$WhatIf
  }

  # Explorer restart (only when advanced tweaks were applied)
  if (-not $WhatIf -and $Cfg.ApplyBehavior -and $Cfg.ApplyBehavior.RestartExplorer -and $didAdvanced) {
    Restart-Explorer
  }
}


# -------------------------
# Scheduled task: apply at logon
# -------------------------
$Script:TaskName = "47Apps-IdentityKit-Apply"
function Enable-LogonApply([string]$ProfileName) {
  if (-not $ProfileName) { return }
  $cmd = "powershell.exe -ExecutionPolicy Bypass -File `"$Script:ScriptPath`" -ApplyProfile `"$ProfileName`" -NoUI"
  try {
    schtasks.exe /Create /F /SC ONLOGON /TN $Script:TaskName /TR $cmd /RL HIGHEST | Out-Null
    Log-Line OK "Logon apply enabled for profile: $ProfileName"
  } catch {
    Log-Line WARN "Failed to create scheduled task: $($_.Exception.Message)"
  }
}
function Disable-LogonApply {
  try { schtasks.exe /Delete /F /TN $Script:TaskName | Out-Null; Log-Line OK "Logon apply disabled." } catch { Log-Line WARN "Failed to remove scheduled task." }
}
function Update-LogonStatusLabel {
  $lbl = $Window.FindName('LblLogon')
  try {
    $out = schtasks.exe /Query /TN $Script:TaskName 2>$null
    if ($LASTEXITCODE -eq 0) { $lbl.Text = "Logon apply: Enabled" } else { $lbl.Text = "Logon apply: Disabled" }
  } catch { $lbl.Text = "Logon apply: Unknown" }
}

# -------------------------
# Buttons / events
# -------------------------
# sliders
# sliders (optional; may be hidden/removed)
$sInt = $Window.FindName('SldIntensity')
$lInt = $Window.FindName('LblIntensity')
if($sInt -and $lInt){ $sInt.Add_ValueChanged({ $lInt.Text = ("{0}%" -f [int]$sInt.Value); Update-Preview }) }
$sSpd = $Window.FindName('SldSpeed')
$lSpd = $Window.FindName('LblSpeed')
if($sSpd -and $lSpd){ $sSpd.Add_ValueChanged({ $lSpd.Text = ("{0}ms" -f [int]$sSpd.Value); if($script:MatrixTimer){ $script:MatrixTimer.Interval=[TimeSpan]::FromMilliseconds([int]$sSpd.Value) }; Update-Preview }) }

# basic UI changes trigger preview
foreach($n in @('ChkProfile','ChkLock','ChkWall','ChkCrop','CmbCrop','CmbLockMode','ChkNoChange','CmbWallStyle','CmbTheme','ChkTransparency','CmbTaskbarSize','CmbTaskbarAlign','CmbSearch','CmbCombine','ChkExt','ChkHidden','ChkSuper','CmbLaunch','ChkDisableTips','ChkManagedStorage','ChkWriteHKCU','ChkProgramData','ChkRestartExplorer','ChkSnapshotBefore','ChkMatrix')){
  $c = $Window.FindName($n)
  if ($c -is [System.Windows.Controls.ComboBox]) { $c.Add_SelectionChanged({ Update-Preview }) }
  elseif ($c -is [System.Windows.Controls.CheckBox]) { $c.Add_Click({ Update-Preview }) }
}

# file pickers
$Window.FindName('BtnPickProfile').Add_Click({
  try {
    $p = Select-ImageFile "Select profile picture"
    if ($p) { $script:State.ProfileImage = $p; Set-StateLabel Profile ("Selected: " + $p); Update-Thumbs; Update-Preview }
  } catch { Log-Line ERR $_.Exception.Message; Show-Error -Title "Error" -Message $_.Exception.Message }
})
$Window.FindName('BtnClearProfile').Add_Click({ $script:State.ProfileImage=$null; Set-StateLabel Profile "Cleared."; Update-Thumbs; Update-Preview })
$Window.FindName('BtnOpenProfile').Add_Click({ Open-Path $script:State.ProfileImage })
$Window.FindName('BtnRevealProfile').Add_Click({ Reveal-File $script:State.ProfileImage })

$Window.FindName('BtnPickLock').Add_Click({
  try {
    $p = Select-ImageFile "Select lock screen image"
    if ($p) { $script:State.LockImage = $p; Set-StateLabel Lock ("Selected: " + $p); Update-Thumbs; Update-Preview }
  } catch { Log-Line ERR $_.Exception.Message; Show-Error -Title "Error" -Message $_.Exception.Message }
})
$Window.FindName('BtnClearLock').Add_Click({ $script:State.LockImage=$null; Set-StateLabel Lock "Cleared."; Update-Thumbs; Update-Preview })
$Window.FindName('BtnOpenLock').Add_Click({ Open-Path $script:State.LockImage })
$Window.FindName('BtnRevealLock').Add_Click({ Reveal-File $script:State.LockImage })

$Window.FindName('BtnPickWall').Add_Click({
  try {
    $p = Select-ImageFile "Select wallpaper image"
    if ($p) { $script:State.WallpaperImage = $p; Set-StateLabel Wall ("Selected: " + $p); Update-Thumbs; Update-Preview }
  } catch { Log-Line ERR $_.Exception.Message; Show-Error -Title "Error" -Message $_.Exception.Message }
})
$Window.FindName('BtnClearWall').Add_Click({ $script:State.WallpaperImage=$null; Set-StateLabel Wall "Cleared."; Update-Thumbs; Update-Preview })
$Window.FindName('BtnOpenWall').Add_Click({ Open-Path $script:State.WallpaperImage })
$Window.FindName('BtnRevealWall').Add_Click({ Reveal-File $script:State.WallpaperImage })

$Window.FindName('BtnAddLib').Add_Click({
  try {
    if (-not $script:State.WallpaperImage) { Show-Info -Message "Pick a wallpaper first."; return }
    $dst = Join-Path $Script:LibDir ([IO.Path]::GetFileName($script:State.WallpaperImage))
    Copy-Item -LiteralPath $script:State.WallpaperImage -Destination $dst -Force
    Log-Line OK "Added to library: $dst"
  } catch { Log-Line WARN $_.Exception.Message }
})

$Window.FindName('BtnWallFromLib').Add_Click({
  try {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Pick from library ($Script:LibDir)"
    $dlg.InitialDirectory = $Script:LibDir
    $dlg.Filter = "Images|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      $script:State.WallpaperImage = $dlg.FileName
      Set-StateLabel Wall ("Selected: " + $dlg.FileName)
      Update-Thumbs; Update-Preview
    }
  } catch { Log-Line WARN $_.Exception.Message }
})

# header
$Window.FindName('BtnOpenBase').Add_Click({ try { Start-Process $Script:BasePath | Out-Null } catch {} })
$Window.FindName('BtnOpenBase2').Add_Click({ try { Start-Process $Script:BasePath | Out-Null } catch {} })
$Window.FindName('BtnOpenProject').Add_Click({ try { Start-Process (Split-Path -Parent $Script:BasePath) | Out-Null } catch {} })
$Window.FindName('BtnOpenLogs').Add_Click({ try { Start-Process $Script:LogsDir | Out-Null } catch {} })
$Window.FindName('BtnPrivacy').Add_Click({ try { Show-PrivacyDialog } catch {} })

$Window.FindName('BtnEnterprise').Add_Click({
  try {
    $res = Show-EnterpriseDialog -Current $script:State.Enterprise
    if ($res) {
      $script:State.Enterprise = $res
      Log-Line OK "Enterprise/Extras updated."
      Update-Preview
    }
  } catch {
    Log-Line WARN $_.Exception.Message
    Show-Error -Title "Enterprise features" -Message $_.Exception.Message
  }
})

$__c = $Window.FindName('BtnCopyLog'); if ($__c) { $__c.Add_Click({
  try {
    $t = ""
    try { $t = [string]$script:TxtLog.Text } catch {}
    if ([string]::IsNullOrWhiteSpace($t)) { $t = (Get-Content -LiteralPath $Script:LogFile -ErrorAction SilentlyContinue | Out-String) }
    if (Set-ClipboardText $t) { Log-Line OK "Log copied to clipboard." } else { Show-Info -Title "Copy Log" -Message "Could not access clipboard." }
  } catch {}
}) }

$__c = $Window.FindName('BtnOpenSnapshots'); if ($__c) { $__c.Add_Click({
  try { Start-Process -FilePath $Script:BackupsDir | Out-Null } catch {}
}) }

$__c = $Window.FindName('BtnResetNoChange'); if ($__c) { $__c.Add_Click({
  try { Reset-NoChange -Window $Window; Log-Line OK "Reset: No change (dash) applied to tri-state toggles."; Update-Preview } catch {}
}) }

# profiles buttons
$Window.FindName('BtnRefresh').Add_Click({ try { Refresh-ProfilesUI; Update-LogonStatusLabel; Log-Line OK "Profiles refreshed." } catch {} })
$Window.FindName('BtnLoad').Add_Click({ try { $n=Get-SelectedProfileName; if($n){ Load-ProfileIntoUI $n } } catch { Show-Error -Title "Load failed" -Message $_.Exception.Message } })
$Window.FindName('BtnSave').Add_Click({
  try {
    $default = Get-SelectedProfileName
    if (-not $default) { $default = 'MyProfile' }
    $name = Prompt-ProfileName $default
    if (-not $name) { return }
    $cfg = Build-ConfigFromUI
    $cfg.Meta.Name = $name
    Write-Profile -Name $name -Cfg $cfg
    Refresh-ProfilesUI
  } catch { Show-Error -Title "Save failed" -Message $_.Exception.Message }
})
$Window.FindName('BtnDelete').Add_Click({
  try {
    $n=Get-SelectedProfileName
    if (-not $n) { return }
    $p = Profile-Path $n
    if (-not (Test-Path -LiteralPath $p)) { return }
    $r = [System.Windows.MessageBox]::Show("Delete profile '$n'? This cannot be undone.", $Script:AppName, 'YesNo', 'Warning')
    if ($r -eq 'Yes') { Remove-Item -LiteralPath $p -Recurse -Force; Log-Line OK "Deleted: $n"; Refresh-ProfilesUI }
  } catch { Show-Error -Title "Delete failed" -Message $_.Exception.Message }
})
$Window.FindName('BtnFav').Add_Click({ try { $n=Get-SelectedProfileName; if($n){ Toggle-Favorite $n; Refresh-ProfilesUI } } catch {} })
$Window.FindName('BtnBaseline').Add_Click({ try { $n=Get-SelectedProfileName; if($n){ Set-Baseline $n } } catch {} })
$Window.FindName('BtnSnapshot').Add_Click({ try { Snapshot-Now (Build-ConfigFromUI) } catch {} })

$Window.FindName('BtnApplyProfile').Add_Click({ try { $n=Get-SelectedProfileName; if($n){ Apply-Config -Cfg (Read-ProfileCfg $n) -WhatIf:[bool]$Window.FindName('ChkDryRun').IsChecked -ApplyAdvanced:$true } } catch { Show-Error -Title "Apply failed" -Message $_.Exception.Message } })
$Window.FindName('BtnApplyBaseline').Add_Click({
  try {
    $bn = Get-BaselineName
    if (-not $bn) { Show-Info -Message "No baseline is set yet."; return }
    Apply-Config -Cfg (Read-ProfileCfg $bn) -WhatIf:[bool]$Window.FindName('ChkDryRun').IsChecked -ApplyAdvanced:$true
  } catch { Show-Error -Title "Apply baseline failed" -Message $_.Exception.Message }
})

$Window.FindName('BtnExport').Add_Click({
  try {
    $n=Get-SelectedProfileName
    if (-not $n) { return }
    $p = Profile-Path $n
    if (-not (Test-Path -LiteralPath $p)) { return }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Title = "Export profile pack"
    $dlg.Filter = "Zip (*.zip)|*.zip"
    $dlg.FileName = "$n.zip"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      if (Test-Path -LiteralPath $dlg.FileName) { Remove-Item -LiteralPath $dlg.FileName -Force }
      Compress-Archive -Path (Join-Path $p '*') -DestinationPath $dlg.FileName -Force
      Log-Line OK "Exported: $($dlg.FileName)"
    }
  } catch { Show-Error -Title "Export failed" -Message $_.Exception.Message }
})

$Window.FindName('BtnImport').Add_Click({
  try {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Import profile pack"
    $dlg.Filter = "Zip (*.zip)|*.zip"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      $tmp = Join-Path $Script:CacheDir ("import-" + [IO.Path]::GetFileNameWithoutExtension($dlg.FileName))
      Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
      $null = New-Item -ItemType Directory -Force -Path $tmp
      Expand-Archive -LiteralPath $dlg.FileName -DestinationPath $tmp -Force
      # Determine profile name
      $name = [IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
      $dest = Profile-Path $name
      Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
      $null = New-Item -ItemType Directory -Force -Path $dest
      Copy-Item -LiteralPath (Join-Path $tmp '*') -Destination $dest -Recurse -Force
      Log-Line OK "Imported: $name"
      Refresh-ProfilesUI
    }
  } catch { Show-Error -Title "Import failed" -Message $_.Exception.Message }
})

$Window.FindName('BtnEnableLogon').Add_Click({ try { Enable-LogonApply (Get-SelectedProfileName); Update-LogonStatusLabel } catch {} })
$Window.FindName('BtnDisableLogon').Add_Click({ try { Disable-LogonApply; Update-LogonStatusLabel } catch {} })

$Window.FindName('BtnRestoreSnap').Add_Click({
  try {
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Select snapshot JSON to restore"
    $dlg.InitialDirectory = $Script:BackupsDir
    $dlg.Filter = "JSON (*.json)|*.json"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      $cfg = Read-JsonFile $dlg.FileName
      if (-not $cfg) { return }
      # apply snapshot as config
      $ht=@{}; foreach($p in $cfg.PSObject.Properties){$ht[$p.Name]=$p.Value}
      Apply-Config -Cfg $ht -WhatIf:[bool]$Window.FindName('ChkDryRun').IsChecked -ApplyAdvanced:$true
    }
  } catch { Show-Error -Title "Restore failed" -Message $_.Exception.Message }
})

$__c = $Window.FindName('BtnUndoLast'); if ($__c) { $__c.Add_Click({
  try {
    $whatIf = [bool]$Window.FindName('ChkDryRun').IsChecked
    $last = Get-LatestSnapshotFile
    if (-not $last) { Show-Info -Title "Undo last apply" -Message "No snapshots found in: $Script:BackupsDir"; return }
    $cfg = Read-JsonFile $last
    if (-not $cfg) { Show-Info -Title "Undo last apply" -Message "Snapshot could not be read."; return }
    $ht=@{}; foreach($p in $cfg.PSObject.Properties){$ht[$p.Name]=$p.Value}
    Apply-Config -Cfg $ht -WhatIf:$whatIf -ApplyAdvanced:$true
    Log-Line OK ("Undo applied from snapshot: " + (Split-Path $last -Leaf))
  } catch { Show-Error -Title "Undo failed" -Message $_.Exception.Message }
}) }

$__c = $Window.FindName('BtnQuickProfile'); if ($__c) { $__c.Add_Click({
  try {
    $whatIf = [bool]$Window.FindName('ChkDryRun').IsChecked
    if ([string]::IsNullOrWhiteSpace($script:State.ProfileImage)) { Show-Info -Title "Quick apply" -Message "Pick a profile picture first."; return }
    if ([bool]$Window.FindName('ChkSnapshotBefore').IsChecked) { try { Snapshot-Now (Build-ConfigFromUI) } catch {} }
    Apply-ProfilePicture -SourcePath $script:State.ProfileImage -EnableCrop:[bool]$Window.FindName('ChkCrop').IsChecked `
      -CropMode (Get-ComboValue ($Window.FindName('CmbCrop')) 'Center') `
      -UpdateProgramData:[bool]$Window.FindName('ChkProgramData').IsChecked -WriteHKCU:[bool]$Window.FindName('ChkWriteHKCU').IsChecked -WhatIf:$whatIf
    Log-Line OK "Quick apply: profile picture"
  } catch { Show-Error -Title "Quick apply failed" -Message $_.Exception.Message }
}) }

$__c = $Window.FindName('BtnQuickLock'); if ($__c) { $__c.Add_Click({
  try {
    $whatIf = [bool]$Window.FindName('ChkDryRun').IsChecked
    if ([string]::IsNullOrWhiteSpace($script:State.LockImage)) { Show-Info -Title "Quick apply" -Message "Pick a lock screen image first."; return }
    if ([bool]$Window.FindName('ChkSnapshotBefore').IsChecked) { try { Snapshot-Now (Build-ConfigFromUI) } catch {} }
    $lm = (Get-ComboValue ($Window.FindName('CmbLockMode')) 'User')
    if ([bool]$Window.FindName('ChkNoChange').IsChecked) { $lm = 'Enforced' }
    Apply-LockScreen -ImagePath $script:State.LockImage -Mode $lm -NoChange:([bool]$Window.FindName('ChkNoChange').IsChecked) -WhatIf:$whatIf
    Log-Line OK "Quick apply: lock screen"
  } catch { Show-Error -Title "Quick apply failed" -Message $_.Exception.Message }
}) }

$__c = $Window.FindName('BtnQuickWall'); if ($__c) { $__c.Add_Click({
  try {
    $whatIf = [bool]$Window.FindName('ChkDryRun').IsChecked
    if ([string]::IsNullOrWhiteSpace($script:State.WallpaperImage)) { Show-Info -Title "Quick apply" -Message "Pick a wallpaper image first."; return }
    if ([bool]$Window.FindName('ChkSnapshotBefore').IsChecked) { try { Snapshot-Now (Build-ConfigFromUI) } catch {} }
    $ws = (Get-ComboValue ($Window.FindName('CmbWallStyle')) 'Fill')
    Apply-Wallpaper -ImagePath $script:State.WallpaperImage -Style $ws -WhatIf:$whatIf
    Log-Line OK "Quick apply: wallpaper"
  } catch { Show-Error -Title "Quick apply failed" -Message $_.Exception.Message }
}) }

$__c = $Window.FindName('BtnOpenData'); if ($__c) { $__c.Add_Click({
  try { Start-Process -FilePath $Script:BasePath | Out-Null } catch {}
}) }

$__c = $Window.FindName('BtnEnablePortable'); if ($__c) { $__c.Add_Click({
  try {
    Set-Content -LiteralPath $Script:PortableFlag -Value "portable=1" -Encoding ASCII -Force
    Restart-IdentityKit -PortableMode
  } catch { Show-Error -Title "Portable mode" -Message $_.Exception.Message }
}) }

$__c = $Window.FindName('BtnDisablePortable'); if ($__c) { $__c.Add_Click({
  try {
    if (Test-Path $Script:PortableFlag) { Remove-Item -LiteralPath $Script:PortableFlag -Force -ErrorAction SilentlyContinue }
    Restart-IdentityKit
  } catch { Show-Error -Title "Portable mode" -Message $_.Exception.Message }
}) }

$Window.FindName('BtnHealth').Add_Click({
  try {
    $warn = New-Object System.Collections.Generic.List[string]
    $fixes = New-Object System.Collections.Generic.List[scriptblock]

    if (-not (Test-Path $Script:BasePath)) {
      $warn.Add("Base path missing: $Script:BasePath")
      $fixes.Add({ Ensure-Folder $Script:BasePath | Out-Null })
    }

    foreach($d in @($Script:ProfilesDir,$Script:LogsDir,$Script:BackupsDir,$Script:CacheDir,$Script:TempDir)){
      if (-not (Test-Path $d)) {
        $warn.Add("Missing folder: $d")
        $fixes.Add({ Ensure-Folder $d | Out-Null })
      }
    }

    # Write access check
    try {
      $probe = Join-Path $Script:BasePath "._write_test"
      Set-Content -LiteralPath $probe -Value "ok" -Encoding ASCII -Force
      Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    } catch {
      $warn.Add("No write access to Base path (run as Admin or pick a writable location).")
    }

    if (-not $Script:IsAdmin) { $warn.Add("Not running as Admin (some enforced options are best-effort).") }

    if ($warn.Count -eq 0) {
      Show-Info -Title "Health check" -Message "Health check OK."
      return
    }

    $msg = ($warn | ForEach-Object { "• " + $_ }) -join "`r`n"
    $auto = $false
    try { $auto = [bool]$Window.FindName('ChkHealthAutoFix').IsChecked } catch { $auto = $false }

    $doFix = $false
    if ($fixes.Count -gt 0) {
      if ($auto) { $doFix = $true }
      else { $doFix = Ask-YesNo -Title "Health check" -Message ($msg + "`r`n`r`nFix what I can now?") }
    }

    if ($doFix -and $fixes.Count -gt 0) {
      foreach($fx in $fixes){ try { & $fx } catch {} }
      Show-Info -Title "Health check" -Message "Fixes applied. Re-run Health check if needed."
    } else {
      Show-Info -Title "Health check" -Message $msg
    }
  } catch { }
})

$Window.FindName('BtnCleanup').Add_Click({
  try {
    Remove-Item -LiteralPath (Join-Path $Script:CacheDir '*') -Recurse -Force -ErrorAction SilentlyContinue
    Log-Line OK "Cache cleaned."
  } catch { Log-Line WARN "Cache cleanup failed." }
})

$Window.FindName('BtnApply').Add_Click({
  try {
    $cfg = Build-ConfigFromUI
    $whatIf = [bool]$Window.FindName('ChkDryRun').IsChecked
    $applyModeCtl = $Window.FindName('CmbApplyMode')
    $mode = $null
    if ($applyModeCtl) {
      try { if ($applyModeCtl.SelectedItem -and $applyModeCtl.SelectedItem.Content) { $mode = [string]$applyModeCtl.SelectedItem.Content } } catch {}
      if (-not $mode) { try { $mode = [string]$applyModeCtl.Text } catch {} }
    }
    if (-not $mode) { $mode = 'Apply selected items' }
    $expAdv = $Window.FindName('ExpAdvanced')
    # For 'Apply selected items', do NOT touch shell/theme settings unless the user opened Advanced.
    $applyAdv = $true
    if ($mode -eq 'Apply selected items') { $applyAdv = [bool]$expAdv.IsExpanded }

    # If enterprise options were set (anything not 'No change'), treat it as intent to apply advanced tweaks (requires Advanced mode).
    try {
      $ent = $script:State.Enterprise
      if ($ent -is [hashtable]) {
        foreach ($k in $ent.Keys) {
          if ($ent[$k] -and $ent[$k] -ne 'No change') { $applyAdv = $true; break }
        }
      } elseif ($ent) {
        foreach ($p in $ent.PSObject.Properties) {
          if ($p.Value -and $p.Value -ne 'No change') { $applyAdv = $true; break }
        }
      }
    } catch {}

    Apply-Config -Cfg $cfg -WhatIf:$whatIf -ApplyAdvanced:$applyAdv
  } catch {
    Show-Error -Title "Apply failed" -Message $_.Exception.Message
  }
})

$Window.FindName('BtnExit').Add_Click({ $Window.Close() })

# Window events
$Window.Add_Loaded({
  # Advanced is always available in this build (no "unlock" required).
  $script:ChkAdvMode  = $Window.FindName('ChkAdvMode')
  $script:ExpAdvanced = $Window.FindName('ExpAdvanced')
  if ($script:ChkAdvMode) {
    try { $script:ChkAdvMode.IsChecked = $true } catch {}
    try { $script:ChkAdvMode.Visibility = 'Collapsed' } catch {}
  }
  if ($script:ExpAdvanced) {
    try { $script:ExpAdvanced.Visibility = 'Visible' } catch {}
  }

  try {
    Refresh-ProfilesUI
    Update-LogonStatusLabel
    Update-Thumbs
    Update-Preview
    Matrix-Init
    $script:MatrixTimer.Interval = [TimeSpan]::FromMilliseconds(50)  # default; Matrix is auto
    $script:MatrixTimer.Start()
    Log-Line OK "$Script:AppName ready."
  } catch {
    Log-Line FATAL ("Startup error: " + $_.Exception.Message)
    Show-Error -Title "Startup error (Identity Kit)" -Message $_.Exception.Message
  }
})

$Window.Add_SizeChanged({ try { Matrix-Init } catch {} })

# -------------------------
# CLI silent mode (ApplyProfile / ApplyBaseline)
# -------------------------
function Apply-FromArgs {
  if ($ApplyBaseline) {
    $bn = Get-BaselineName
    if (-not $bn) { throw "No baseline is set." }
    $cfg = Read-ProfileCfg $bn
    if (-not $cfg) { throw "Baseline profile not found: $bn" }
    Apply-Config -Cfg $cfg -WhatIf:$DryRun -ApplyAdvanced:$true
    return $true
  }
  if ($ApplyProfile) {
    $cfg = Read-ProfileCfg $ApplyProfile
    if (-not $cfg) { throw "Profile not found: $ApplyProfile" }
    Apply-Config -Cfg $cfg -WhatIf:$DryRun -ApplyAdvanced:$true
    return $true
  }
  return $false
}

try {
  if (Apply-FromArgs) {
    if (-not $NoUI) { Show-Info -Message "Applied via CLI args." }
    if ($NoUI) { exit 0 }
  }
} catch {
  Log-Line FATAL $_.Exception.Message
  Show-Error -Title "Apply failed" -Message $_.Exception.Message
  if ($NoUI) { exit 1 }
}

if (-not $NoUI) {
  $null = $Window.ShowDialog()
}
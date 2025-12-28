
<#
.SYNOPSIS
  Bootstrap entry point for 47Project Framework (cross-platform).
.DESCRIPTION
  Ensures required PowerShell modules (Pester optional) and launches the framework.
.PARAMETER NoGui
  Launch CLI shell instead of GUI.
.PARAMETER InstallTestDeps
  Install Pester 5+ before launching.
#>
[CmdletBinding()]
param(
  [switch]$NoGui,
  [switch]$InstallTestDeps,
  [switch]$Unblock,
  [switch]$Bypass,
  [switch]$NoPause
)

Set-StrictMode -Version Latest
# PowerShell 5.1 doesn't define $IsWindows/$IsLinux/$IsMacOS. Use a robust check.
$isWindowsHost = $false
try {
  if ($PSVersionTable.PSEdition -eq 'Core') {
    $isWindowsHost = ($PSVersionTable.Platform -eq 'Win32NT') -or ($env:OS -eq 'Windows_NT')
  } else {
    $isWindowsHost = ($env:OS -eq 'Windows_NT')
  }
} catch {
  $isWindowsHost = ($env:OS -eq 'Windows_NT')
}


function Find-47Pwsh {
  $paths = @(
    "$env:ProgramW6432\PowerShell\7\pwsh.exe",
    "$env:ProgramFiles\PowerShell\7\pwsh.exe",
    "C:\Program Files\PowerShell\7\pwsh.exe",
    "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
  )
  foreach ($p in $paths) {
    try { if ($p -and (Test-Path -LiteralPath $p)) { return $p } } catch { }
  }
  try {
    $pkgs = @(Get-AppxPackage -Name Microsoft.PowerShell* -ErrorAction SilentlyContinue)
    foreach ($pkg in $pkgs) {
      try {
        if ($pkg.InstallLocation) {
          $p = Join-Path $pkg.InstallLocation 'pwsh.exe'
          if (Test-Path -LiteralPath $p) { return $p }
        }
      } catch { }
    }
  } catch { }
  try {
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c -and $c.Source) { return $c.Source }
  } catch { }
  return $null
}

function Install-47Pwsh {
  [CmdletBinding()]
  param(
    [ValidateSet('x64','x86','arm64')][string]$Arch = 'x64'
  )

  # PowerShell 5.1 needs TLS 1.2 for GitHub.
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

  Write-Host "Attempting to provision PowerShell 7 (pwsh)..." -ForegroundColor Cyan

  $found = Find-47Pwsh
  if ($found) {
    Write-Host ("Found pwsh: " + $found) -ForegroundColor Green
    return $found
  }

  # Preferred: portable ZIP (no admin required, avoids MSI 1603 and Store/winget issues)
  try {
    Write-Host "Downloading portable pwsh ZIP from GitHub releases..." -ForegroundColor Cyan
    $api = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $r = Invoke-RestMethod -Uri $api -UseBasicParsing
    $asset = $null
    foreach ($a in @($r.assets)) {
      if ($a.name -match ("win-" + $Arch + "\.zip$")) { $asset = $a; break }
    }
    if (-not $asset) { throw ("No ZIP asset found for arch " + $Arch) }

    $zip = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing -ErrorAction Stop
    try {
      $len = (Get-Item -LiteralPath $zip).Length
      Write-Host ("Downloaded ZIP: " + $zip + " (" + $len + " bytes)")
    } catch { }

    $dest = Join-Path $PSScriptRoot ".runtime\pwsh"
    if (Test-Path -LiteralPath $dest) { Remove-Item -Recurse -Force -LiteralPath $dest }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null

    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force -ErrorAction Stop

    $portable = Get-ChildItem -Recurse -File -LiteralPath $dest -Filter pwsh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portable -and $portable.FullName -and (Test-Path -LiteralPath $portable.FullName)) {
      Write-Host ("Portable pwsh ready: " + $portable.FullName) -ForegroundColor Green
      return $portable.FullName
    }

    throw "Portable ZIP extracted, but pwsh.exe not found."
  } catch {
    Write-Host ("Portable ZIP provisioning failed: " + $_.Exception.Message) -ForegroundColor Yellow
  }

  # Winget (may fail on locked-down / Store-disabled environments)
  $winget = $null
  try { $winget = (Get-Command winget -ErrorAction SilentlyContinue).Source } catch { }
  if ($winget) {
    try {
      Write-Host "Running winget install Microsoft.PowerShell..." -ForegroundColor Cyan
      & $winget install --id Microsoft.PowerShell --source winget -e --accept-package-agreements --accept-source-agreements
      Write-Host ("winget exit code: " + $LASTEXITCODE)
    } catch {
      Write-Host ("winget failed: " + $_.Exception.Message) -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
    $found = Find-47Pwsh
    if ($found) { Write-Host ("Found pwsh after winget: " + $found) -ForegroundColor Green; return $found }
  }

  # MSI fallback (may require admin, can fail with 1603). We keep it last.
  try {
    Write-Host "Downloading pwsh MSI from GitHub releases..." -ForegroundColor Cyan
    $api = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    $r = Invoke-RestMethod -Uri $api -UseBasicParsing
    $asset = $null
    foreach ($a in @($r.assets)) {
      if ($a.name -match ("win-" + $Arch + "\.msi$")) { $asset = $a; break }
    }
    if (-not $asset) { throw ("No MSI asset found for arch " + $Arch) }

    $tmp = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
    Write-Host ("Downloaded MSI: " + $tmp)
    $log = Join-Path $env:TEMP ("pwsh_install_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".log")
    Write-Host ("Installing MSI (silent). Log: " + $log) -ForegroundColor Cyan
    $p = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", $tmp, "/qn", "/norestart", "/l*v", $log) -Wait -PassThru
    Write-Host ("msiexec exit code: " + $p.ExitCode)
    Start-Sleep -Seconds 2
    $found = Find-47Pwsh
    if ($found) { Write-Host ("Found pwsh after MSI: " + $found) -ForegroundColor Green; return $found }
  } catch {
    Write-Host ("MSI provisioning failed: " + $_.Exception.Message) -ForegroundColor Yellow
  }

  return $null
}




# If pwsh exists, always relaunch the bootstrap under pwsh to avoid Windows PowerShell 5.1 quirks.
try {
  $pw = Find-47Pwsh
  if (-not $pw) {
    # Determine arch
    $arch = 'x64'
    try {
      if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { $arch = 'arm64' }
      elseif ($env:PROCESSOR_ARCHITECTURE -eq 'x86' -and $env:PROCESSOR_ARCHITEW6432) { $arch = 'x64' }
      elseif ($env:PROCESSOR_ARCHITECTURE -eq 'x86') { $arch = 'x86' }
    } catch { }
    $pw = Install-47Pwsh -Arch $arch
  }

  $isCore = ($PSVersionTable.PSEdition -eq 'Core')
  if ($pw -and -not $isCore) {
    $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $PSCommandPath)
    if ($NoGui) { $args += '-NoGui' }
    if ($InstallTestDeps) { $args += '-InstallTestDeps' }
    if ($Unblock) { $args += '-Unblock' }
    & $pw @args
    exit $LASTEXITCODE
  }
} catch { }

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

# Boot log
try {
  $logDir = Join-Path $root '.runtime\logs'
  if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
  $bootLog = Join-Path $logDir ("boot_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".log")
  Start-Transcript -LiteralPath $bootLog -Force | Out-Null
  Write-Host ("Boot log: " + $bootLog) -ForegroundColor DarkGray
} catch { }


# Windows: downloaded zips may carry Mark-of-the-Web (MOTW) causing security prompts.
# Use -Bypass to launch with ExecutionPolicy Bypass, or -Unblock to remove MOTW from this folder.
if ($isWindowsHost) {
  try {
    if ($Unblock) {
      Get-ChildItem -Recurse -File -LiteralPath $root -Include *.ps1,*.psm1,*.psd1 | ForEach-Object {
        try { Unblock-File -LiteralPath $_.FullName } catch { }
      }
      Write-Host "Unblocked scripts in: $root"
    }
  } catch { }
}


if ($InstallTestDeps) {
  & (Join-Path $root 'tools\install_pester.ps1') | Out-Null
}

$launch = Join-Path $root '47Project.Framework.Launch.ps1'

if ($Bypass) {
  # Relaunch this bootstrap with Bypass to avoid MOTW prompts in interactive sessions.
  $hostExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
  $args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $root 'start.ps1'))
  if ($NoGui) { $args += '-NoGui' }
  if ($InstallTestDeps) { $args += '-InstallTestDeps' }
  if ($Unblock) { $args += '-Unblock' }
  & $hostExe @args
  exit $LASTEXITCODE
}

if ($NoGui) {
  try {
    if ($pw) { $env:P47_PWSH_PATH = $pw }
    & $launch -NoGui
  } catch {
    Write-Host ($_.Exception.Message) -ForegroundColor Red
    try { Write-Host ($_.ScriptStackTrace) -ForegroundColor DarkGray } catch { }
    if ($env:ComSpec -and $env:PROMPT) {
      Write-Host 'Press Enter to exit...'
      [void][System.Console]::ReadLine()
    }
    exit 1
  }
} else {
  try {
    & $launch
  } catch {
    Write-Host ($_.Exception.Message) -ForegroundColor Red
    try { Write-Host ($_.ScriptStackTrace) -ForegroundColor DarkGray } catch { }
    if ($env:ComSpec -and $env:PROMPT) {
      Write-Host 'Press Enter to exit...'
      [void][System.Console]::ReadLine()
    }
    exit 1
  }
}


# (internal) no-op


try { Stop-Transcript | Out-Null } catch { }

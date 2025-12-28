<#
.SYNOPSIS
  Export a diagnostics support bundle (zip) with logs, policy, and module manifests.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$OutPath,
  [switch]$Redact = $true,
  [switch]$IncludeDist = $true,
  [switch]$IncludeCaptures = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')


function Invoke-47RedactFile {
  param([string]$Path)
  try {
    $txt = Get-Content -Raw -LiteralPath $Path -ErrorAction Stop
  } catch { return }

  $patterns = @(
    '(?i)(api[_-]?key)\s*[:=]\s*["'']?[^"''\r\n\s]+',
    '(?i)(token)\s*[:=]\s*["'']?[^"''\r\n\s]+',
    '(?i)(secret)\s*[:=]\s*["'']?[^"''\r\n\s]+',
    '(?i)(password)\s*[:=]\s*["'']?[^"''\r\n\s]+',
    '(?i)(authorization)\s*[:=]\s*["'']?Bearer\s+[^"''\r\n]+'
  )

  foreach ($p in $patterns) {
    $txt = [regex]::Replace($txt, $p, '$1=<redacted>')
  }

  Set-Content -LiteralPath $Path -Value $txt -Encoding utf8
}


$paths = Get-47Paths
if (-not $OutPath) {
  $OutPath = Join-Path $paths.LocalAppDataRoot ("SupportBundle-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".zip")
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("47support-" + [Guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null

# Logs
foreach ($src in @($paths.LogsRootUser, $paths.LogsRootMachine)) {
  if (Test-Path -LiteralPath $src) {
    $dst = Join-Path $temp ("logs-" + (Split-Path -Leaf $src))
    Copy-Item -Recurse -Force -LiteralPath $src -Destination $dst
  }
}

# Policy
foreach ($p in @($paths.PolicyMachinePath, $paths.PolicyUserPath)) {
  if (Test-Path -LiteralPath $p) {
    Copy-Item -Force -LiteralPath $p -Destination (Join-Path $temp (Split-Path -Leaf $p))
  }
}

# Module manifests
$modsDir = Join-Path $temp 'modules'
New-Item -ItemType Directory -Force -Path $modsDir | Out-Null
Get-47Modules | ForEach-Object {
  $dst = Join-Path $modsDir ($_.ModuleId + ".module.json")
  Copy-Item -Force -LiteralPath $_.ManifestPath -Destination $dst
}


# Captures (stdout/stderr)
if ($IncludeCaptures) {
  $cap = Join-Path $paths.LogsRootUser 'captures'
  if (Test-Path -LiteralPath $cap) {
    $dst = Join-Path $temp 'captures'
    Copy-Item -Recurse -Force -LiteralPath $cap -Destination $dst
  }
}

# dist integrity (if present)
if ($IncludeDist) {
  foreach ($p in @(
    (Join-Path $packRoot 'dist_manifest.json'),
    (Join-Path $packRoot 'dist_manifest.json.sig'),
    (Join-Path $packRoot 'dist_manifest.json.sha256'),
    (Join-Path $packRoot 'dist_manifest.json.txt'),
    (Join-Path $packRoot 'dist_manifest.json.md')
  )) { if (Test-Path -LiteralPath $p) { Copy-Item -Force -LiteralPath $p -Destination (Join-Path $temp (Split-Path -Leaf $p)) } }

  $distDir = Join-Path $packRoot 'dist'
  if (Test-Path -LiteralPath $distDir) {
    $dst = Join-Path $temp 'dist'
    Copy-Item -Recurse -Force -LiteralPath $distDir -Destination $dst
  }
}

# Modules list + effective policy
try {
  (Get-47Modules | Select-Object ModuleId, Name, Version, Path, Entrypoint, Capabilities, Risk, RunType, Publisher | ConvertTo-Json -Depth 6) |
    Set-Content -LiteralPath (Join-Path $temp 'modules_list.json') -Encoding utf8
} catch { }

try {
  (Get-47EffectivePolicy | ConvertTo-Json -Depth 10) |
    Set-Content -LiteralPath (Join-Path $temp 'effective_policy.json') -Encoding utf8
} catch { }

# Environment snapshot
$envObj = [pscustomobject]@{
  createdUtc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  os = [System.Environment]::OSVersion.VersionString
  psVersion = $PSVersionTable.PSVersion.ToString()
  machine = $env:COMPUTERNAME
  user = $env:USERNAME
}
$envJson = ConvertTo-47CanonicalJson -InputObject $envObj
[System.IO.File]::WriteAllText((Join-Path $temp 'env.json'), $envJson, [System.Text.Encoding]::UTF8)


# Redaction pass (best-effort)
if ($Redact) {
  Get-ChildItem -Recurse -File -LiteralPath $temp | ForEach-Object {
    $ext = $_.Extension.ToLowerInvariant()
    if ($ext -in @('.txt','.log','.json','.ps1','.psd1','.psm1','.md','.yml','.yaml')) {
      Invoke-47RedactFile -Path $_.FullName
    }
  }
}

if ($PSCmdlet.ShouldProcess($OutPath, 'Create support bundle')) {
  if (Test-Path -LiteralPath $OutPath) { Remove-Item -Force -LiteralPath $OutPath }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($temp, $OutPath)
  Write-Host "Wrote support bundle: $OutPath"
}

Remove-Item -Recurse -Force -LiteralPath $temp

# New-47Module.ps1
# Golden path module generator (scaffolds a new module folder under /modules).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [Parameter(Mandatory)]
  [string]$ModuleId,

  [string]$DisplayName,
  [string]$Author = '47Project',
  [string]$Description = 'New 47Project module',
  [string]$OutRoot
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here '..\Framework\Core\47.Core.psd1')

$paths = Get-47Paths
if (-not $OutRoot) { $OutRoot = $paths.ModulesRoot }

if (-not $DisplayName) { $DisplayName = $ModuleId }

# Folder name: last segment of moduleId (after last dot), fallback to safe string
$short = ($ModuleId -split '\.')[-1]
$folderName = ($short -replace '[^A-Za-z0-9_-]','')
if (-not $folderName) { $folderName = 'NewModule' }

$dest = Join-Path $OutRoot $folderName
if (Test-Path -LiteralPath $dest) { throw "Destination already exists: $dest" }

New-Item -ItemType Directory -Force -Path $dest | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $dest 'assets') | Out-Null

$tpl = $paths.TemplatesRoot
if (-not (Test-Path -LiteralPath $tpl)) { throw "TemplatesRoot not found: $tpl" }

function Apply-Template([string]$src, [string]$dst) {
  $t = Get-Content -Raw -LiteralPath $src
  $t = $t.Replace('{{ModuleId}}', $ModuleId)
  $t = $t.Replace('{{DisplayName}}', $DisplayName)
  $t = $t.Replace('{{Author}}', $Author)
  $t = $t.Replace('{{Description}}', $Description)
  $t = $t.Replace('{{ModuleShort}}', $folderName)
  Set-Content -LiteralPath $dst -Value $t -Encoding utf8
}

Apply-Template (Join-Path $tpl 'module\module.json.template') (Join-Path $dest 'module.json')
Apply-Template (Join-Path $tpl 'module\module.psm1.template') (Join-Path $dest 'module.psm1')
Apply-Template (Join-Path $tpl 'module\README.md.template') (Join-Path $dest 'README.md')

Copy-Item -LiteralPath (Join-Path $tpl 'module\icon.png') -Destination (Join-Path $dest 'assets\icon.png') -Force

Write-Host "Created module scaffold:"
Write-Host " - $dest"
Write-Host ""
Write-Host "Next:"
Write-Host " - Edit module.json (capabilities, risk, metadata)"
Write-Host " - Implement commands in module.psm1"

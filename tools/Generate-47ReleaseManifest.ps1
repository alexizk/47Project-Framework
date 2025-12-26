\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Framework\Core\47.Core.psm1')

param(
  [Parameter()][string]$OutPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts\release.manifest.json')
)

$ctx = Get-47Context
$root = $ctx.Paths.PackRoot

$files = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
  $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\runs\\' -and $_.FullName -notmatch '\\cache\\' -and $_.FullName -notmatch '\\snapshots\\'
}

$art = @()
foreach ($f in $files) {
  $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
  $sha = Get-47Sha256Hex -Path $f.FullName
  $art += [ordered]@{ path=$rel; sha256=$sha }
}

$manifest = [ordered]@{
  schemaVersion = 1
  version = $ctx.Config.frameworkVersion
  createdAt = (Get-Date).ToUniversalTime().ToString('o')
  artifacts = $art
  sha256 = ''
  signature = $null
}

# compute manifest sha256 over canonical json
$canon = ConvertTo-47CanonicalJson -InputObject $manifest
$tmp = Join-Path (Split-Path -Parent $OutPath) 'release.manifest.canon.json'
$canon | Set-Content -LiteralPath $tmp -Encoding UTF8
$manifest.sha256 = Get-47Sha256Hex -Path $tmp
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

($manifest | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $OutPath -Encoding UTF8
Write-Host "Wrote: $OutPath"

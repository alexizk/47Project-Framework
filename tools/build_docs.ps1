
<#
.SYNOPSIS
  Builds offline HTML documentation from docs/*.md.
.DESCRIPTION
  Uses ConvertFrom-Markdown (PowerShell 7+) to generate docs/site/*.html.
.PARAMETER Root
  Root folder of the pack (default: inferred).
#>
[CmdletBinding()]
param(
  [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $Root 'docs'))) {
  $Root = Split-Path -Parent $Root
}

$docs = Join-Path $Root 'docs'
$out = Join-Path $docs 'site'
New-Item -ItemType Directory -Path $out -Force | Out-Null

$md = Get-ChildItem -LiteralPath $docs -File -Filter '*.md' -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'site' } | Sort-Object Name
$links = @()

foreach ($f in $md) {
  $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
  $htmlPath = Join-Path $out ($name + '.html')
  $m = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
  $body = (ConvertFrom-Markdown -Markdown $m).Html
  $page = @()
  $page += '<!doctype html>'
  $page += '<html><head><meta charset="utf-8"><title>' + $f.Name + '</title>'
  $page += '<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;max-width:980px} pre{overflow:auto;background:#111;padding:12px;color:#ddd} code{background:#eee;padding:1px 4px;border-radius:4px}</style>'
  $page += '</head><body>'
  $page += '<div style="margin-bottom:14px"><a href="index.html">Docs index</a></div>'
  $page += $body
  $page += '</body></html>'
  ($page -join "`r`n") | Set-Content -LiteralPath $htmlPath -Encoding utf8
  $links += ('<li><a href="' + $name + '.html">' + $f.Name + '</a></li>')
}

$idx = @()
$idx += '<!doctype html>'
$idx += '<html><head><meta charset="utf-8"><title>47Project Framework Docs</title>'
$idx += '<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;max-width:980px} ul{line-height:1.8}</style>'
$idx += '</head><body>'
$idx += '<h1>47Project Framework Docs</h1>'
$idx += '<ul>' + ($links -join "`r`n") + '</ul>'
$idx += '<p>Generated: ' + (Get-Date -Format 's') + '</p>'
$idx += '</body></html>'
($idx -join "`r`n") | Set-Content -LiteralPath (Join-Path $out 'index.html') -Encoding utf8

Write-Host ("Docs built: " + $out)

# Build-47Docs.ps1
# Builds a lightweight offline HTML docs bundle under /docs_offline.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$docsRoot = Join-Path $PackRoot 'docs'
$outRoot  = Join-Path $PackRoot 'docs_offline'

if (-not (Test-Path -LiteralPath $docsRoot)) { throw "Docs not found: $docsRoot" }
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

function Convert-MarkdownToHtml {
  param(
    [Parameter(Mandatory)][string]$mdPath,
    [Parameter(Mandatory)][string]$htmlPath,
    [string]$Title = (Split-Path -Leaf $mdPath)
  )

  $md = Get-Content -Raw -LiteralPath $mdPath

  if (Get-Command ConvertFrom-Markdown -ErrorAction SilentlyContinue) {
    $htmlBody = (ConvertFrom-Markdown -Markdown $md).Html
  } else {
    # Fallback (PowerShell 5.1 / minimal environments)
    $escaped = [System.Net.WebUtility]::HtmlEncode($md)
    $htmlBody = "<pre>$escaped</pre>"
  }

  $doc = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$Title</title>
  <style>
    body { font-family: system-ui, Segoe UI, Arial, sans-serif; margin: 2rem; line-height: 1.5; max-width: 1100px; }
    pre { white-space: pre-wrap; word-wrap: break-word; background: #f6f8fa; padding: 1rem; border-radius: 12px; }
    code { background: #f6f8fa; padding: 0.1rem 0.2rem; border-radius: 6px; }
    a { color: #0b57d0; }
  </style>
</head>
<body>
$htmlBody
</body>
</html>
"@

  $outDir = Split-Path -Parent $htmlPath
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
  Set-Content -LiteralPath $htmlPath -Value $doc -Encoding utf8
}

$files = Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter *.md | Sort-Object FullName
$links = New-Object System.Collections.Generic.List[string]

foreach ($f in $files) {
  $rel = $f.FullName.Substring($docsRoot.Length).TrimStart('\','/')
  $relHtml = ($rel -replace '\.md$','.html')
  $htmlPath = Join-Path $outRoot $relHtml
  Convert-MarkdownToHtml -mdPath $f.FullName -htmlPath $htmlPath -Title $rel
  $href = $relHtml -replace '\\','/'
  $links.Add("<li><a href=""$href"">$rel</a></li>")
}

$index = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>47Project Framework Offline Docs</title>
  <style>
    body { font-family: system-ui, Segoe UI, Arial, sans-serif; margin: 2rem; line-height: 1.5; max-width: 1100px; }
    a { color: #0b57d0; }
  </style>
</head>
<body>
<h1>47Project Framework Offline Docs</h1>
<ul>
$($links -join "`n")
</ul>
</body>
</html>
"@
Set-Content -LiteralPath (Join-Path $outRoot 'index.html') -Value $index -Encoding utf8
Write-Host "Built offline docs at: $outRoot"

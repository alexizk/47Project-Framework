# Project47 - AppS - Crawler (Wrapper)
# This wrapper forwards all args to the engine script in the same folder.
# Engine: Project47_AppCrawler_base.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engine = Join-Path $PSScriptRoot 'Project47_AppCrawler_base.ps1'
if (-not (Test-Path -LiteralPath $engine)) { throw "Engine not found: $engine" }

& $engine @args
exit $LASTEXITCODE

# Generate-47Changelog.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$Since = '',
  [string]$OutputPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'CHANGELOG.generated.md')
)

function Has-Git { try { git --version *> $null; return $true } catch { return $false } }

if (-not (Has-Git)) {
  Write-Warning "git not found; writing placeholder changelog."
  "# Changelog`n`n- (git not available) Add entries manually." | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  Write-Host "Wrote: $OutputPath"
  exit 0
}

$range = if ($Since) { "$Since..HEAD" } else { "" }
$log = git log $range --pretty=format:"%h|%ad|%s" --date=short
$lines = $log -split "`n" | Where-Object { $_ -and $_.Trim() -ne '' }

$out = New-Object System.Collections.Generic.List[string]
$out.Add("# Changelog")
$out.Add("")
$out.Add("Generated on $(Get-Date -Format 'yyyy-MM-dd').")
$out.Add("")
foreach ($l in $lines) {
  $parts = $l -split "\|",3
  if ($parts.Count -ge 3) {
    $out.Add("- $($parts[1]) [$($parts[0])] $($parts[2])")
  }
}
$outText = ($out -join "`n")
$outText | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Wrote: $OutputPath"

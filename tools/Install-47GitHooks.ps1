# Install-47GitHooks.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$gitDir = Join-Path $RepoRoot '.git'
if (-not (Test-Path -LiteralPath $gitDir)) {
  Write-Warning "No .git folder found at: $RepoRoot (skipping hooks install)"
  exit 0
}

$hooks = Join-Path $gitDir 'hooks'
New-Item -ItemType Directory -Force -Path $hooks | Out-Null

$preCommit = Join-Path $hooks 'pre-commit'
$prePush   = Join-Path $hooks 'pre-push'

# Use bash for maximum Git compatibility on Windows/macOS/Linux.
$preCommitContent = @'
#!/usr/bin/env bash
set -euo pipefail
echo "[47] pre-commit: style + quick tests"
pwsh -NoProfile -File tools/Invoke-47StyleCheck.ps1
pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -Tag Unit -CI" || true
'@

$prePushContent = @'
#!/usr/bin/env bash
set -euo pipefail
echo "[47] pre-push: full tests + security scan"
pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -CI"
pwsh -NoProfile -File tools/Invoke-47SecurityScan.ps1 -FailOnFindings
'@

Set-Content -LiteralPath $preCommit -Value $preCommitContent -Encoding UTF8
Set-Content -LiteralPath $prePush -Value $prePushContent -Encoding UTF8

try {
  if (Get-Command chmod -ErrorAction SilentlyContinue) {
    chmod +x $preCommit
    chmod +x $prePush
  }
} catch { }

Write-Host "Installed Git hooks to: $hooks"

# Invoke-47DevSetup.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
  [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SkipGitHooks
)

Write-Host "== 47Project Framework Dev Setup =="

# PowerShell version check (recommendation only)
$psv = $PSVersionTable.PSVersion
Write-Host ("PowerShell: {0}" -f $psv)

# Install dev modules (best-effort)
try {
  if (Get-Command Set-PSRepository -ErrorAction SilentlyContinue) {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted | Out-Null
  }
  if (-not (Get-Module -ListAvailable Pester)) {
    Write-Host "Installing Pester..."
    Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0.0
  }
  if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Write-Host "Installing PSScriptAnalyzer..."
    Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
  }
} catch {
  Write-Warning "Dev module install failed (ok on offline/locked machines): $($_.Exception.Message)"
}

# Create default config/policy if missing
Import-Module -Force (Join-Path $PackRoot 'Framework\Core\47.Core.psd1')
$paths = Get-47Paths
if (-not (Test-Path -LiteralPath $paths.ConfigUserPath)) {
  $cfg = Get-47DefaultConfig
  $cfg | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $paths.ConfigUserPath -Encoding UTF8
  Write-Host "Created user config: $($paths.ConfigUserPath)"
}
if (-not (Test-Path -LiteralPath $paths.PolicyUserPath)) {
  $pol = Get-47EffectivePolicy
  $pol | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $paths.PolicyUserPath -Encoding UTF8
  Write-Host "Created user policy: $($paths.PolicyUserPath)"
}

if (-not $SkipGitHooks) {
  & (Join-Path $PackRoot 'tools\Install-47GitHooks.ps1') -RepoRoot $PackRoot
}

Write-Host "Dev setup complete."

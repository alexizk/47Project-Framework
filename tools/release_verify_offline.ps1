<#
.SYNOPSIS
  Verify an offline release (zip or extracted folder) using embedded _integrity metadata.

.PARAMETER ZipPath
  Path to offline zip built by tools/release_build.ps1

.PARAMETER FolderPath
  Path to extracted offline folder (root containing Framework/ etc)

.PARAMETER PublicKeyPath
  Optional RSA public key (XML). If provided and signatures exist, verify them.

.EXAMPLE
  pwsh -File tools/release_verify_offline.ps1 -ZipPath ./dist/47Project_Framework_v30_offline.zip

.EXAMPLE
  pwsh -File tools/release_verify_offline.ps1 -FolderPath ./extracted -PublicKeyPath ./keys/release_public.xml
#>
[CmdletBinding()]
param(
  [string]$ZipPath = '',
  [string]$FolderPath = '',
  [string]$PublicKeyPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

# best-effort state recording
try {
  $repoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $PSCommandPath) '..')).Path
  Import-Module (Join-Path (Join-Path $repoRoot 'Framework') 'Core/47.Core.psd1') -Force | Out-Null
} catch { }

function Ensure-Dir([string]$p) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null } }

function Hash-File([string]$path) {
  (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
}

function Verify-ShaSums([string]$root,[string]$sumFile) {
  $lines = Get-Content -LiteralPath $sumFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  $bad = @()
  foreach ($ln in $lines) {
    $parts = $ln -split '\s{2,}', 2
    if ($parts.Count -ne 2) { continue }
    $h = $parts[0].Trim().ToLowerInvariant()
    $rel = $parts[1].Trim()
    $fp = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $fp)) { $bad += ("MISSING " + $rel); continue }
    $calc = Hash-File $fp
    if ($calc -ne $h) { $bad += ("HASH " + $rel) }
  }
  return $bad
}

function Verify-OptionalSig([string]$integrityDir,[string]$fileName,[string]$pubKey) {
  if ([string]::IsNullOrWhiteSpace($pubKey)) { return $true }
  $f = Join-Path $integrityDir $fileName
  $sig = Join-Path $integrityDir ($fileName + ".sig")
  if (-not (Test-Path -LiteralPath $sig)) { return $true } # signature optional
  & (Join-Path (Split-Path -Parent $PSCommandPath) 'release_verify.ps1') -PublicKeyPath $pubKey -InputPath $f | Out-Null
  return $true
}

$root = $null
$temp = $null

try {
  if ([string]::IsNullOrWhiteSpace($ZipPath) -and [string]::IsNullOrWhiteSpace($FolderPath)) {
    throw "Provide -ZipPath or -FolderPath."
  }

  if (-not [string]::IsNullOrWhiteSpace($ZipPath)) {
    if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Zip not found: $ZipPath" }
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("p47_verify_" + (Get-Date -Format 'yyyyMMdd_HHmmss_ffff'))
    Ensure-Dir $temp
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $temp)
    $root = $temp
  } else {
    $root = (Resolve-Path $FolderPath).Path
  }

  $intDir = Join-Path $root '_integrity'
  if (-not (Test-Path -LiteralPath $intDir)) { throw "Missing _integrity folder in: $root" }

  $sumFile = Join-Path $intDir 'SHA256SUMS.txt'
  if (-not (Test-Path -LiteralPath $sumFile)) { throw "Missing SHA256SUMS.txt in _integrity" }

  # Verify signatures (optional)
  Verify-OptionalSig -integrityDir $intDir -fileName 'manifest.json' -pubKey $PublicKeyPath | Out-Null
  Verify-OptionalSig -integrityDir $intDir -fileName 'SHA256SUMS.txt' -pubKey $PublicKeyPath | Out-Null

  # Verify hashes
  $bad = Verify-ShaSums -root $root -sumFile $sumFile
  if ($bad.Count -gt 0) {
    throw ("Verification failed: " + ($bad -join '; '))
  }

  # Record last verification (success)
  try {
    if (Get-Command Set-47StateRecord -ErrorAction SilentlyContinue) {
      $rec = [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        zipPath = $ZipPath
        folderPath = $FolderPath
        publicKeyPath = $PublicKeyPath
        ok = $true
        status = 'ok'
      }
      Set-47StateRecord -Name 'last_verify' -Value $rec | Out-Null
    }
  } catch { }

  Write-Host "OK"
} catch {
  # Record last verification (failure)
  try {
    if (Get-Command Set-47StateRecord -ErrorAction SilentlyContinue) {
      $rec = [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        zipPath = $ZipPath
        folderPath = $FolderPath
        publicKeyPath = $PublicKeyPath
        ok = $false
        status = 'failed'
        error = $_.Exception.Message
      }
      Set-47StateRecord -Name 'last_verify' -Value $rec | Out-Null
    }
  } catch { }
  throw
} finally {
  if ($temp) {
    try { Remove-Item -Recurse -Force -LiteralPath $temp } catch { }
  }
}

    <#
      Validate-47ArtifactManifest.ps1
      Recomputes SHA-256 for listed files and reports mismatches.
    #>
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    param(
      [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
      [string]$ManifestPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\manifest.json')
    )

    if (!(Test-Path -LiteralPath $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
    $m = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json

    $bad = @()
    foreach ($entry in $m.files) {
      $p = Join-Path $PackRoot ($entry.path -replace '/','\')
      if (!(Test-Path -LiteralPath $p)) { $bad += "Missing: $($entry.path)"; continue }
      $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLowerInvariant()
      if ($h -ne $entry.sha256) { $bad += "Hash mismatch: $($entry.path)" }
    }

    if ($bad.Count -gt 0) {
      $bad | ForEach-Object { Write-Error $_ }
      exit 2
    }

    Write-Host "Manifest OK"

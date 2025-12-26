    <#
      Generate-47ArtifactManifest.ps1
      Generates artifacts/manifest.json listing pack files with SHA-256.
    #>
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    param(
      [string]$PackRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
      [string]$OutPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'artifacts\manifest.json'),
      [string]$VersionTag = 'dev'
    )

    function Get-FileSha256([string]$Path) {
      return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    }

    $files = Get-ChildItem -LiteralPath $PackRoot -Recurse -File | Where-Object {
      # Exclude dist outputs if present
      $_.FullName -notmatch '\\dist\\' -and $_.FullName -notmatch '\\\.git\\'
    }

    $out = [ordered]@{
      versionTag  = $VersionTag
      generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
      files       = @()
    }

    foreach ($f in $files) {
      $rel = $f.FullName.Substring($PackRoot.Length).TrimStart('\','/')
      $out.files += [ordered]@{
        path = $rel -replace '\\','/'
        size = $f.Length
        sha256 = (Get-FileSha256 $f.FullName)
      }
    }

    $json = $out | ConvertTo-Json -Depth 6
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
    $json | Set-Content -Encoding utf8 -LiteralPath $OutPath
    Write-Host "Wrote manifest: $OutPath"

\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Framework\Core\47.Core.psm1')

param([Parameter(Mandatory)][string]$Sha256Hex)

$ctx = Get-47Context
$storePath = Join-Path $ctx.Paths.PackRoot 'trust\publishers.json'
$store = Read-47TrustStore

if (-not $store.trustedArtifactHashes) { $store.trustedArtifactHashes = @() }
if ($store.trustedArtifactHashes -notcontains $Sha256Hex) { $store.trustedArtifactHashes += $Sha256Hex }

$store.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
($store | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $storePath -Encoding UTF8

Write-Host ("Pinned trusted artifact hash: " + $Sha256Hex)

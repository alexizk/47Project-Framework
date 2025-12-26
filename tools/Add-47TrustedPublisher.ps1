\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Framework\Core\47.Core.psm1')

param(
  [Parameter(Mandatory)][string]$PublisherId,
  [Parameter(Mandatory)][string]$CertPath,
  [Parameter()][string]$KeyId = 'default',
  [Parameter()][ValidateSet('active','retired','revoked')][string]$Status = 'active'
)

$ctx = Get-47Context
if (-not (Test-Path -LiteralPath $CertPath)) { throw "Cert not found: $CertPath" }

$thumb = (Get-PfxCertificate -FilePath $CertPath).Thumbprint
$storePath = Join-Path $ctx.Paths.PackRoot 'trust\publishers.json'
$store = Read-47TrustStore

$pub = $store.publishers | Where-Object { $_.publisherId -eq $PublisherId } | Select-Object -First 1
if (-not $pub) {
  $pub = [ordered]@{ publisherId=$PublisherId; title=$PublisherId; keys=@() }
  $store.publishers += $pub
}

if (-not $pub.keys) { $pub.keys = @() }
$existing = $pub.keys | Where-Object { $_.thumbprint -eq $thumb } | Select-Object -First 1
if (-not $existing) {
  $pub.keys += [ordered]@{ keyId=$KeyId; thumbprint=$thumb; status=$Status; validFrom=$null; validTo=$null }
}

$store.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
($store | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $storePath -Encoding UTF8

Write-Host ("Trusted publisher added/updated: " + $PublisherId + " (" + $thumb + ")")

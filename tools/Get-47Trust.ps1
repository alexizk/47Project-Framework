\
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\Framework\Core\47.Core.psm1')

$store = Read-47TrustStore
$store | ConvertTo-Json -Depth 20

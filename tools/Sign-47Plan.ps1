<#
.SYNOPSIS
  Sign a plan file (RS256) and embed a signature block into the JSON.

.DESCRIPTION
  - Canonicalizes the plan excluding the "signature" property (if present)
  - Computes SHA-256 over canonical UTF-8 bytes
  - Signs the hash using an RSA private key from a PFX
  - Writes the signature back into the plan as:
      "signature": { "alg":"RS256", "kid":"<thumbprint>", "sig":"<base64>" }
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)][string]$PlanPath,
  [Parameter(Mandatory)][string]$PfxPath,
  [Parameter()][string]$PfxPassword,
  [string]$KeyId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packRoot = Split-Path -Parent $PSScriptRoot
Import-Module -Force (Join-Path $packRoot 'Framework\Core\47.Core.psd1')

if (-not (Test-Path -LiteralPath $PlanPath)) { throw "Plan not found: $PlanPath" }
if (-not (Test-Path -LiteralPath $PfxPath)) { throw "PFX not found: $PfxPath" }

# Load cert
$secure = $null
if ($PfxPassword) { $secure = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force }
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$cert.Import($PfxPath, $secure, 'Exportable,PersistKeySet')

$rsa = $cert.GetRSAPrivateKey()
if (-not $rsa) { throw "No RSA private key available in PFX: $PfxPath" }

$plan = Read-47Json -Path $PlanPath
if ($plan.PSObject.Properties.Name -contains 'planHash') { $plan.planHash = $null }
if ($plan.PSObject.Properties.Name -contains 'signature') { $plan.signature = $null }

$bytes = Get-47CanonicalBytes -InputObject $plan
$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)

$sigBytes = $rsa.SignHash($hash, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
$sigB64 = [Convert]::ToBase64String($sigBytes)

$kid = if ($KeyId) { $KeyId } else { $cert.Thumbprint }

$plan2 = Read-47Json -Path $PlanPath
$plan2 | Add-Member -Force -NotePropertyName signature -NotePropertyValue ([pscustomobject]@{
  alg = 'RS256'
  kid = $kid
  sig = $sigB64
})

if ($PSCmdlet.ShouldProcess($PlanPath, 'Write signed plan')) {
  $json = ConvertTo-47CanonicalJson -InputObject $plan2
  [System.IO.File]::WriteAllText((Resolve-Path $PlanPath), $json, [System.Text.Encoding]::UTF8)
  Write-Host "Signed: $PlanPath (kid=$kid)"
}

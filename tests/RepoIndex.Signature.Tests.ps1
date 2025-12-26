# Pester tests: repo index signing and verification (RS256)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
  $packRoot = Split-Path -Parent $PSScriptRoot
  Import-Module (Join-Path $packRoot 'Framework\Core\47.Core.psd1') -Force | Out-Null
}

Describe "Repo index signature" {

  It "Signs and verifies an index, and fails when tampered" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("47repo_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
      # Create self-signed cert (cross-platform) using CertificateRequest
      $rsa = [System.Security.Cryptography.RSA]::Create(2048)
      $dn = New-Object System.Security.Cryptography.X509Certificates.X500DistinguishedName("CN=47RepoTest")
      $req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest($dn, $rsa, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
      $cert = $req.CreateSelfSigned([DateTimeOffset]::UtcNow.AddMinutes(-1), [DateTimeOffset]::UtcNow.AddDays(1))

      $pfxPath = Join-Path $tmp 'test.pfx'
      $cerPath = Join-Path $tmp 'test.cer'
      [System.IO.File]::WriteAllBytes($pfxPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx))
      [System.IO.File]::WriteAllBytes($cerPath, $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))

      $idxPath = Join-Path $tmp 'index.json'
      @{
        schemaVersion='1.0.0'
        repositoryId='repo.test'
        displayName='Repo Test'
        channel='stable'
        updatedAt=[DateTime]::UtcNow.ToString("o")
        packages=@()
      } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $idxPath -Encoding UTF8

      & (Join-Path $packRoot 'tools\Sign-47RepoIndex.ps1') -IndexPath $idxPath -PfxPath $pfxPath | Out-Null
      & (Join-Path $packRoot 'tools\Verify-47RepoIndex.ps1') -IndexPath $idxPath -CertPath $cerPath | Out-Null

      # Tamper
      $j = Get-Content -Raw -LiteralPath $idxPath | ConvertFrom-Json -Depth 50
      $j.displayName = "tampered"
      ($j | ConvertTo-Json -Depth 50) | Set-Content -LiteralPath $idxPath -Encoding UTF8

      { & (Join-Path $packRoot 'tools\Verify-47RepoIndex.ps1') -IndexPath $idxPath -CertPath $cerPath } | Should -Throw
    }
    finally {
      Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
  }
}

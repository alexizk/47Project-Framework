# SignatureVerification.Tests.ps1
# Verifies that plan signing + verification works end-to-end (Windows CI).

BeforeAll {
  $here = Split-Path -Parent $PSCommandPath
  $repo = Resolve-Path (Join-Path $here '..\..')
  $tools = Join-Path $repo 'tools'
  $sample = Join-Path $repo 'examples\plans\sample_install.plan.json'
  $tmp = Join-Path $env:TEMP ('47sig-' + [Guid]::NewGuid().ToString('n'))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null

  $plan = Join-Path $tmp 'plan.json'
  Copy-Item -LiteralPath $sample -Destination $plan -Force

  $pfx = Join-Path $tmp 'dev.pfx'
  $cer = Join-Path $tmp 'dev.cer'
  $pw  = 'dev'

  # Create signing cert (Windows)
  & (Join-Path $tools 'New-47DevCert.ps1') -OutPfxPath $pfx -OutCerPath $cer -Password $pw | Out-Null

  # Sign
  & (Join-Path $tools 'Sign-47Plan.ps1') -PlanPath $plan -PfxPath $pfx -PfxPassword $pw | Out-Null

  $script:PlanPath = $plan
  $script:CertPath = $cer
  $script:Tools = $tools
}

Describe "Plan signature verification" {
  It "verifies a valid signature" {
    { & (Join-Path $script:Tools 'Verify-47Signature.ps1') -PlanPath $script:PlanPath -CertPath $script:CertPath | Out-Null } | Should -Not -Throw
  }

  It "fails if the plan is modified after signing" {
    $p = Get-Content -Raw -LiteralPath $script:PlanPath
    $p2 = $p -replace '"7zip\.7zip"', '"7zip.7zip_modified"'
    Set-Content -LiteralPath $script:PlanPath -Value $p2 -Encoding UTF8
    { & (Join-Path $script:Tools 'Verify-47Signature.ps1') -PlanPath $script:PlanPath -CertPath $script:CertPath | Out-Null } | Should -Throw
  }
}

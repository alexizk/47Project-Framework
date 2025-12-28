@{
  RootModule = '47.Core.psm1'
  ModuleVersion = '1.0.0'
  GUID = '9e339a4acfb4f1312e21537e2b71e462'
  Author = '47Project'
  CompanyName = '47Project'
  Copyright = '(c) 2025 47Project'
  PowerShellVersion = '5.1'
  FunctionsToExport = @(
  'Invoke-47SandboxPwsh',
  'Write-47RunHistory',
  'Invoke-47ExternalTool',
  'Assert-47ReleaseVerified',
  'Test-47ReleaseVerified',
  'Set-47StateRecord',
  'Get-47StateRecord',
  'Grant-47ModuleCapabilities','*',
  'Invoke-47ModuleRun',
  'Resolve-47Runtime',
  'Test-47ExternalRuntimeAllowed',
  'Assert-47ExternalRuntimeAllowed'
)
  CmdletsToExport = @()
  VariablesToExport = @()
  AliasesToExport = @()
}

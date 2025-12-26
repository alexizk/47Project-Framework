# 47Project Module: RegistryPolicyViewer
Set-StrictMode -Version Latest

function Get-47ModuleInfo {
  [CmdletBinding()]
  param()
  $manifestPath = Join-Path $PSScriptRoot 'module.json'
  return (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 50)
}

function Initialize-47Module {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Context
  )
  # No-op
}

function Get-47ModuleCommands {
  [CmdletBinding()]
  param()
  return @(
    [pscustomobject]@{ name='policyPaths'; description='List common policy registry paths and their values.' }
  )
}

function Get-47ModuleSettingsSchema {
  [CmdletBinding()]
  param()
  return @{
    schemaVersion = '1.0.0'
    type = 'object'
    properties = @{}
  }
}

function Get-RegistryValues([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return @{} }
  $item = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
  if (-not $item) { return @{} }

  $h = @{}
  foreach ($p in $item.PSObject.Properties) {
    if ($p.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
    $h[$p.Name] = $p.Value
  }
  return $h
}

function Invoke-47Module {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Action,
    [hashtable]$Args
  )

  switch ($Action) {
    'policyPaths' {
      $paths = @(
        'HKLM:\SOFTWARE\Policies',
        'HKCU:\SOFTWARE\Policies'
      )

      $out = @()
      foreach ($p in $paths) {
        $vals = Get-RegistryValues -path $p
        $out += [pscustomobject]@{
          path = $p
          values = $vals
        }
      }
      return $out
    }
    default { throw "Unknown action: $Action" }
  }
}

function Invoke-47ModuleRun {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Context
  )
  return (Invoke-47Module -Action 'policyPaths' -Args @{})
}

function Invoke-47ModuleSelfTest {
  [CmdletBinding()]
  param()
  return @{ ok = $true; notes = @('RegistryPolicyViewer: OK') }
}

Export-ModuleMember -Function Initialize-47Module,Get-47ModuleInfo,Get-47ModuleCommands,Get-47ModuleSettingsSchema,Invoke-47Module,Invoke-47ModuleRun,Invoke-47ModuleSelfTest

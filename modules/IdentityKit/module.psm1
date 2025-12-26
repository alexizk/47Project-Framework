# 47Project Module: IdentityKit
Set-StrictMode -Version Latest

function Get-47ModuleInfo {
  [CmdletBinding()]
  param()
  $manifestPath = Join-Path $PSScriptRoot 'module.json'
  $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 50
  return $manifest
}

function Invoke-47Module {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Action,
    [hashtable]$Args
  )
  switch ($Action) {
    'about' {
      $m = Get-47ModuleInfo
      [pscustomobject]@{ moduleId = $m.moduleId; version = $m.version; description = $m.description }
    }
    default {
      throw "Action '$Action' is not implemented for module 'IdentityKit'."
    }
  }
}

Export-ModuleMember -Function Get-47ModuleInfo, Invoke-47Module


function Initialize-47Module {
  [CmdletBinding()]
  param()
  return @{ status = 'ok' }
}

function Get-47ModuleCommands {
  [CmdletBinding()]
  param()
  return @()
}

function Get-47ModuleSettingsSchema {
  [CmdletBinding()]
  param()
  return $null
}

function Invoke-47ModuleRun {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Context
  )
  throw "Invoke-47ModuleRun not implemented for this module."
}

function Invoke-47ModuleSelfTest {
  [CmdletBinding()]
  param()
  return @{ ok = $true; notes = @('SelfTest stub') }
}

Export-ModuleMember -Function Initialize-47Module,Get-47ModuleCommands,Get-47ModuleSettingsSchema,Invoke-47ModuleRun,Invoke-47ModuleSelfTest

# 47Project Module: SystemInfo
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
    [pscustomobject]@{ name='summary'; description='Get basic system summary.' }
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

function Invoke-47Module {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Action,
    [hashtable]$Args
  )

  switch ($Action) {
    'summary' {
      $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
      $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
      $memGB = if ($os) { [math]::Round(($os.TotalVisibleMemorySize * 1KB)/1GB, 2) } else { $null }
      return [pscustomobject]@{
        computerName = $env:COMPUTERNAME
        userName     = $env:USERNAME
        osCaption    = $os.Caption
        osVersion    = $os.Version
        psVersion    = $PSVersionTable.PSVersion.ToString()
        cpuName      = $cpu.Name
        cpuCores     = $cpu.NumberOfCores
        ramGB        = $memGB
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
      }
    }
    default { throw "Unknown action: $Action" }
  }
}

function Invoke-47ModuleRun {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$Context
  )
  return (Invoke-47Module -Action 'summary' -Args @{})
}

function Invoke-47ModuleSelfTest {
  [CmdletBinding()]
  param()
  return @{ ok = $true; notes = @('SystemInfo: OK') }
}

Export-ModuleMember -Function Initialize-47Module,Get-47ModuleInfo,Get-47ModuleCommands,Get-47ModuleSettingsSchema,Invoke-47Module,Invoke-47ModuleRun,Invoke-47ModuleSelfTest

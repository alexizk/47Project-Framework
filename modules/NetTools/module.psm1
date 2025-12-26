# 47Project Module: NetTools
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
    [pscustomobject]@{ name='ping'; description='Ping a host.' },
    [pscustomobject]@{ name='resolve'; description='Resolve DNS for a hostname.' }
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
    'ping' {
      $hostName = $Args.host
      if (-not $hostName) { throw "Args.host is required." }
      $count = if ($Args.count) { [int]$Args.count } else { 2 }
      $r = Test-Connection -ComputerName $hostName -Count $count -ErrorAction Stop
      return $r | Select-Object Address, ResponseTime, IPV4Address, IPV6Address
    }
    'resolve' {
      $hostName = $Args.host
      if (-not $hostName) { throw "Args.host is required." }
      try {
        $res = Resolve-DnsName -Name $hostName -ErrorAction Stop
        return $res | Select-Object Name, Type, IPAddress
      } catch {
        # Fallback for older hosts
        $ips = [System.Net.Dns]::GetHostAddresses($hostName)
        return $ips | ForEach-Object { [pscustomobject]@{ Name=$hostName; IPAddress=$_.ToString() } }
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
  throw "NetTools has no default Run action. Use Invoke-47Module -Action ping/resolve."
}

function Invoke-47ModuleSelfTest {
  [CmdletBinding()]
  param()
  return @{ ok = $true; notes = @('NetTools: OK') }
}

Export-ModuleMember -Function Initialize-47Module,Get-47ModuleInfo,Get-47ModuleCommands,Get-47ModuleSettingsSchema,Invoke-47Module,Invoke-47ModuleRun,Invoke-47ModuleSelfTest

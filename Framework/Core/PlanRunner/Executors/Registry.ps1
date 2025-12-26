# Registry step executor for 47 Plan Runner (Windows)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-47RegistryBaseKey {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Hive)

  switch ($Hive.ToUpperInvariant()) {
    'HKLM' { return [Microsoft.Win32.Registry]::LocalMachine }
    'HKCU' { return [Microsoft.Win32.Registry]::CurrentUser }
    'HKCR' { return [Microsoft.Win32.Registry]::ClassesRoot }
    'HKU'  { return [Microsoft.Win32.Registry]::Users }
    'HKCC' { return [Microsoft.Win32.Registry]::CurrentConfig }
    default { throw "Registry: unsupported hive: $Hive (use HKLM/HKCU/HKCR/HKU/HKCC)" }
  }
}

function Register-47RegistryStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($Step, $Mode, $ctx, $Plan)

    if (-not $IsWindows) { throw "Registry executor is only supported on Windows." }

    $stepId = $Step.stepId
    if (-not $stepId) { $stepId = $Step.id }

    $spec = $Step.registry
    if (-not $spec) { throw "Registry: missing 'registry' payload for step $stepId" }

    $hive = if ($spec.hive) { $spec.hive } else { throw "Registry: missing hive" }
    $path = if ($spec.path) { $spec.path } else { throw "Registry: missing path" }
    $action = if ($spec.action) { $spec.action } else { 'setValue' }
    $name = $spec.name
    $valueType = $spec.valueType
    $value = $spec.value

    if ($Mode -eq 'WhatIf') {
      return [ordered]@{
        status='whatif'
        message=("Would apply registry action=$action at $hive:\$path" + $(if($name){ " name=$name"} else {""}))
        hive=$hive; path=$path; action=$action; name=$name
      }
    }

    $base = Get-47RegistryBaseKey -Hive $hive

    if ($action -eq 'ensureKey') {
      $k = $base.CreateSubKey($path, $true)
      $k.Dispose()
      return [ordered]@{ status='ok'; message='Registry key ensured.'; hive=$hive; path=$path; action=$action }
    }

    if ($action -eq 'removeKey') {
      $existing = $base.OpenSubKey($path, $false)
      if ($null -eq $existing) {
        return [ordered]@{ status='skip'; message='Registry key already absent.'; hive=$hive; path=$path; action=$action }
      }
      $existing.Dispose()
      $base.DeleteSubKeyTree($path, $false)
      return [ordered]@{ status='ok'; message='Registry key removed.'; hive=$hive; path=$path; action=$action }
    }

    # For value operations, ensure key exists
    $key = $base.CreateSubKey($path, $true)
    if ($null -eq $key) { throw "Registry: failed to open/create key $hive:\$path" }

    try {
      if ($action -eq 'removeValue') {
        if (-not $name) { throw "Registry: removeValue requires name" }
        $cur = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
        if ($null -eq $cur) {
          return [ordered]@{ status='skip'; message='Registry value already absent.'; hive=$hive; path=$path; action=$action; name=$name }
        }
        $key.DeleteValue($name, $false)
        return [ordered]@{ status='ok'; message='Registry value removed.'; hive=$hive; path=$path; action=$action; name=$name }
      }

      # setValue (default)
      if (-not $name) { throw "Registry: setValue requires name" }
      if (-not $valueType) { $valueType = 'String' }

      # Map to RegistryValueKind
      $kind = [Microsoft.Win32.RegistryValueKind]::$valueType
      $existing = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
      $existingKind = $null
      try { $existingKind = $key.GetValueKind($name) } catch { }

      $same = $false
      if ($null -ne $existing) {
        # Compare by string representation to keep it simple for now
        if (($existingKind -eq $kind) -and ("$existing" -eq "$value")) { $same = $true }
      }

      if ($same) {
        return [ordered]@{ status='skip'; message='Registry value already set.'; hive=$hive; path=$path; action='setValue'; name=$name; valueType=$valueType; value=$value }
      }

      $key.SetValue($name, $value, $kind)
      return [ordered]@{ status='ok'; message='Registry value set.'; hive=$hive; path=$path; action='setValue'; name=$name; valueType=$valueType; value=$value }
    }
    finally {
      $key.Dispose()
    }
  }

  Register-47StepExecutor -Context $Context -Type 'registry' -Executor $executor
}

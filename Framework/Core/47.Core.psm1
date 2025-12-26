# 47Project Framework Core
Set-StrictMode -Version Latest

function Get-47PackRoot {
  [CmdletBinding()]
  param()
  # Core folder: <PackRoot>\Framework\Core
  $core = $PSScriptRoot
  return (Resolve-Path (Join-Path $core '..\..')).Path
}

function Get-47FrameworkRoot {
  [CmdletBinding()]
  param()
  return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-47Paths {
  [CmdletBinding()]
  param()
  $company = '47Project'
  $product = 'Framework'

  $programData = if ($env:ProgramData) { $env:ProgramData } else { [Environment]::GetFolderPath('CommonApplicationData') }
  $localAppData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }

  $paths = [ordered]@{
    PackRoot            = Get-47PackRoot
    FrameworkRoot       = Get-47FrameworkRoot
    ModulesRoot         = Join-Path (Get-47PackRoot) 'modules'
    SchemasRoot         = Join-Path (Get-47PackRoot) 'schemas'
    DocsRoot            = Join-Path (Get-47PackRoot) 'docs'
    DocsOfflineRoot     = Join-Path (Get-47PackRoot) 'docs_offline'
    ExamplesRoot        = Join-Path (Get-47PackRoot) 'examples'
    ToolsRoot           = Join-Path (Get-47PackRoot) 'tools'
    TemplatesRoot       = Join-Path (Get-47PackRoot) 'templates'
    StyleRoot           = Join-Path (Get-47PackRoot) 'style'
    TrustRoot           = Join-Path (Get-47PackRoot) 'trust'
    RepositoriesRoot    = Join-Path (Get-47PackRoot) 'repositories'

    ProgramDataRoot     = Join-Path $programData $company
    LocalAppDataRoot    = Join-Path $localAppData "$company\$product"

    # Data files
    ConfigMachinePath   = Join-Path (Join-Path $programData $company) 'config.json'
    ConfigUserPath      = Join-Path (Join-Path $localAppData "$company\$product") 'config.json'

    PolicyMachinePath   = Join-Path (Join-Path $programData $company) 'policy.json'
    PolicyUserPath      = Join-Path (Join-Path $localAppData "$company\$product") 'policy.json'

    LogsRoot            = Join-Path (Join-Path $localAppData "$company\$product") 'Logs'
    DataRootUser         = Join-Path $localAppData "$company\$product"

    LogsRootMachine     = Join-Path (Join-Path $programData $company) 'Logs'
    LogsRootUser        = Join-Path (Join-Path $localAppData "$company\$product") 'Logs'
    CacheRootUser       = Join-Path (Join-Path $localAppData "$company\$product") 'Cache'

    SnapshotsRootUser   = Join-Path (Join-Path $localAppData "$company\$product") 'Snapshots'
    StagingRootUser     = Join-Path (Join-Path $localAppData "$company\$product") 'Staging'
  }

  foreach ($k in @('ProgramDataRoot','LocalAppDataRoot','LogsRoot','LogsRootMachine','LogsRootUser','CacheRootUser','SnapshotsRootUser','StagingRootUser')) {
    if (-not (Test-Path -LiteralPath $paths[$k])) { New-Item -ItemType Directory -Force -Path $paths[$k] | Out-Null }
  }

  return [pscustomobject]$paths
}

function Write-47Log {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
    [string]$Component = 'Framework',
    [hashtable]$Data
  )
  if ($PSBoundParameters.ContainsKey('Data') -and $null -ne $Data) { $Data = Redact-47Object -InputObject $Data }
  $paths = Get-47Paths
  $ts = (Get-Date).ToString('s')
  $line = "$ts [$Level] [$Component] $Message"
  $logPath = Join-Path $paths.LogsRootUser 'framework.log'
  Add-Content -LiteralPath $logPath -Value $line
  if ($Level -in @('ERROR','WARN')) { Write-Warning $Message } else { Write-Host $Message }
}

function Read-47Json {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [int]$Depth = 100
  )
  if (-not (Test-Path -LiteralPath $Path)) { throw "JSON file not found: $Path" }
  return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth $Depth)
}

function ConvertTo-47CanonicalObject {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$InputObject
  )

  if ($null -eq $InputObject) { return $null }

  # PSCustomObject / Hashtable
  if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [pscustomobject]) {
    $dict = @{}
    if ($InputObject -is [pscustomobject]) {
      foreach ($p in $InputObject.PSObject.Properties) { $dict[$p.Name] = $p.Value }
    } else {
      foreach ($k in $InputObject.Keys) { $dict[$k] = $InputObject[$k] }
    }

    $ordered = [ordered]@{}
    foreach ($k in ($dict.Keys | Sort-Object)) {
      $ordered[$k] = ConvertTo-47CanonicalObject -InputObject $dict[$k]
    }
    return $ordered
  }

  # Array / List
  if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
    $arr = @()
    foreach ($i in $InputObject) { $arr += ,(ConvertTo-47CanonicalObject -InputObject $i) }
    return $arr
  }

  # Primitive
  return $InputObject
}

function ConvertTo-47CanonicalJson {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$InputObject,
    [int]$Depth = 100
  )
  $canon = ConvertTo-47CanonicalObject -InputObject $InputObject
  # ConvertTo-Json respects ordered hashtables insertion order.
  return ($canon | ConvertTo-Json -Depth $Depth -Compress)
}

function Get-47CanonicalBytes {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][object]$InputObject
  )
  $json = ConvertTo-47CanonicalJson -InputObject $InputObject
  return [System.Text.Encoding]::UTF8.GetBytes($json)
}

function Get-47Sha256Hex {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][byte[]]$Bytes
  )
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash($Bytes)
    return ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
  } finally { $sha.Dispose() }
}
function Get-47PlanHash {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$PlanPath
  )
  $plan = Read-47Json -Path $PlanPath
  # Exclude mutable fields from the hash.
  if ($plan.PSObject.Properties.Name -contains 'planHash') { $plan.planHash = $null }
  if ($plan.PSObject.Properties.Name -contains 'signature') { $plan.signature = $null }
  $bytes = Get-47CanonicalBytes -InputObject $plan
  Get-47Sha256Hex -Bytes $bytes
}


function Get-47CapabilityCatalog {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  $catPath = Join-Path $paths.SchemasRoot 'Capability_Catalog_v1.json'
  return Read-47Json -Path $catPath
}

function Get-47Modules {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  if (-not (Test-Path -LiteralPath $paths.ModulesRoot)) { return @() }
  Get-ChildItem -LiteralPath $paths.ModulesRoot -Directory | ForEach-Object {
    $manifestPath = Join-Path $_.FullName 'module.json'
    if (Test-Path -LiteralPath $manifestPath) {
      $m = Read-47Json -Path $manifestPath
      [pscustomobject]@{
        ModuleId = $m.moduleId
        DisplayName = $m.displayName
        Version = $m.version
        Path = $_.FullName
        ManifestPath = $manifestPath
        Entrypoint = $m.entrypoint
        Capabilities = @($m.capabilities)
      }
    }
  }
}

function Import-47Module {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$ModulePath
  )
  $manifestPath = Join-Path $ModulePath 'module.json'
  $m = Read-47Json -Path $manifestPath
  if (-not $m.entrypoint) { return $false }
  $entry = Join-Path $ModulePath $m.entrypoint
  if (-not (Test-Path -LiteralPath $entry)) { throw "Module entrypoint not found: $entry" }
  Import-Module -Force -Name $entry -Scope Global
  return $true
}

function Get-47EffectivePolicy {
  [CmdletBinding()]
  param(
    [string]$PolicyPath
  )
  $paths = Get-47Paths
  $default = [pscustomobject]@{
    schemaVersion = 1
    allowUnsafe = $false
    unsafeGates = @{ unsafe_requires_admin = $false; unsafe_requires_explicit_policy = $false; blocked = $false }
    capabilityGrants = @{
      global = @()
      modules = @{}
    }
    ui = @{
      warnOnUnsafe = $true
      showAdvancedByDefault = $false
    }
  }

  $merge = {
    param($base, $overlay)
    if ($null -eq $overlay) { return $base }
    foreach ($p in $overlay.PSObject.Properties) {
      if ($p.Value -is [pscustomobject] -and $base.$($p.Name) -is [pscustomobject]) {
        $base.$($p.Name) = & $merge $base.$($p.Name) $p.Value
      } else {
        $base | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value
      }
    }
    return $base
  }

  $policy = $default
  # Machine policy (optional)
  if (Test-Path -LiteralPath $paths.PolicyMachinePath) {
    $policy = & $merge $policy (Read-47Json -Path $paths.PolicyMachinePath)
  }
  # User policy (optional)
  if (Test-Path -LiteralPath $paths.PolicyUserPath) {
    $policy = & $merge $policy (Read-47Json -Path $paths.PolicyUserPath)
  }
  # Explicit path override
  if ($PolicyPath) {
    $policy = & $merge $policy (Read-47Json -Path $PolicyPath)
  }

  return $policy
}

function Test-47CapabilityAllowed {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$CapabilityId,
    [Parameter()][string]$ModuleId = '*',
    [object]$Policy
  )
  if (-not $Policy) { $Policy = Get-47EffectivePolicy }
  $grants = @()
  if ($Policy.capabilityGrants -and $Policy.capabilityGrants.global) { $grants += $Policy.capabilityGrants.global }
  if ($ModuleId -and $ModuleId -ne '*' -and $Policy.capabilityGrants -and $Policy.capabilityGrants.modules -and $Policy.capabilityGrants.modules.$ModuleId) {
    $grants += $Policy.capabilityGrants.modules.$ModuleId
  }
  return ($grants -contains $CapabilityId) -or ($grants -contains '*')
}



function Test-47RiskAllowed {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Risk,
    [object]$Policy
  )
  if (-not $Policy) { $Policy = Get-47EffectivePolicy }

  $r = $Risk.ToLowerInvariant()

  # Normalize legacy / user-facing risk labels
  switch ($r) {
    'safe' { $r = 'safe' }
    'caution' { $r = 'unsafe_requires_explicit_policy' }
    'unsafe' { $r = 'unsafe_requires_admin' }
  }

  if ($r -eq 'safe') { return $true }

  # Legacy switch
  if ($Policy.allowUnsafe -eq $true) { return $true }

  # Fine-grained gates
  if ($Policy.unsafeGates) {
    switch ($r) {
      'unsafe_requires_admin' { return [bool]$Policy.unsafeGates.unsafe_requires_admin }
      'unsafe_requires_explicit_policy' { return [bool]$Policy.unsafeGates.unsafe_requires_explicit_policy }
      'blocked' { return $false }
      default { return $false }
    }
  }

  return $false
}





function New-47TempDirectory {
  [CmdletBinding()]
  param(
    [string]$Prefix = 'stage'
  )
  $paths = Get-47Paths
  $id = [guid]::NewGuid().ToString('n')
  $p = Join-Path $paths.StagingRootUser ("{0}_{1}" -f $Prefix, $id)
  New-Item -ItemType Directory -Force -Path $p | Out-Null
  return $p
}

function Expand-47ZipSafe {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$ZipPath,

    [Parameter(Mandatory)]
    [string]$DestinationPath
  )

  if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Zip not found: $ZipPath" }
  New-Item -ItemType Directory -Force -Path $DestinationPath | Out-Null

  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue | Out-Null
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $destFull = [System.IO.Path]::GetFullPath($DestinationPath)
    foreach ($entry in $zip.Entries) {
      if ([string]::IsNullOrWhiteSpace($entry.FullName)) { continue }
      if ($entry.FullName.EndsWith('/')) { continue } # directory marker

      $target = Join-Path $DestinationPath $entry.FullName
      $targetFull = [System.IO.Path]::GetFullPath($target)

      # ZipSlip protection: ensure all targets stay under destination
      if (-not $targetFull.StartsWith($destFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe zip entry path (zip-slip): $($entry.FullName)"
      }

      $dir = Split-Path -Parent $targetFull
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

      $entryStream = $entry.Open()
      try {
        $outStream = [System.IO.File]::Open($targetFull, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $entryStream.CopyTo($outStream) } finally { $outStream.Dispose() }
      } finally {
        $entryStream.Dispose()
      }
    }
  } finally {
    $zip.Dispose()
  }
}

function Invoke-47External {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [string[]]$ArgumentList = @(),
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds = 300,
    [hashtable]$Environment = @{} ,

    # Optional streaming capture
    [string]$StdOutFile,
    [string]$StdErrFile,
    [int]$CaptureMaxKB = 256
  )

  if (-not (Test-Path -LiteralPath $FilePath)) { throw "External not found: $FilePath" }

  # Ensure parent directories exist for streaming outputs
  if ($StdOutFile) {
    $pdir = Split-Path -Parent $StdOutFile
    if ($pdir) { New-Item -ItemType Directory -Force -Path $pdir | Out-Null }
    if (-not (Test-Path -LiteralPath $StdOutFile)) { New-Item -ItemType File -Force -Path $StdOutFile | Out-Null }
  }
  if ($StdErrFile) {
    $pdir = Split-Path -Parent $StdErrFile
    if ($pdir) { New-Item -ItemType Directory -Force -Path $pdir | Out-Null }
    if (-not (Test-Path -LiteralPath $StdErrFile)) { New-Item -ItemType File -Force -Path $StdErrFile | Out-Null }
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.Arguments = ($ArgumentList -join ' ')
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

  foreach ($k in $Environment.Keys) {
    $psi.Environment[$k] = [string]$Environment[$k]
  }

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi

  $captureMaxChars = [Math]::Max(0, $CaptureMaxKB * 1024)
  $sbOut = New-Object System.Text.StringBuilder
  $sbErr = New-Object System.Text.StringBuilder

  $cts = New-Object System.Threading.CancellationTokenSource
  $token = $cts.Token

  $appendLimited = {
    param([System.Text.StringBuilder]$sb,[string]$text,[int]$maxChars)
    if ($null -eq $text) { return }
    if ($maxChars -le 0) { return }
    $remain = $maxChars - $sb.Length
    if ($remain -le 0) { return }
    if ($text.Length -le $remain) { [void]$sb.Append($text) }
    else { [void]$sb.Append($text.Substring(0,$remain)) }
  }

  $startOk = $p.Start()
  if (-not $startOk) { throw "Failed to start external process: $FilePath" }

  # Stream readers (line-based) to avoid deadlocks and enable live tailing.
  $taskOut = [System.Threading.Tasks.Task]::Run([Action]{
    try {
      $sw = $null
      if ($StdOutFile) { $sw = New-Object System.IO.StreamWriter($StdOutFile,$true,[System.Text.Encoding]::UTF8); $sw.AutoFlush = $true }
      while (-not $token.IsCancellationRequested) {
        $line = $p.StandardOutput.ReadLine()
        if ($null -eq $line) { break }
        if ($sw) { $sw.WriteLine($line) }
        & $appendLimited $sbOut ($line + "`n") $captureMaxChars
      }
      if ($sw) { $sw.Dispose() }
    } catch { }
  }, $token)

  $taskErr = [System.Threading.Tasks.Task]::Run([Action]{
    try {
      $sw = $null
      if ($StdErrFile) { $sw = New-Object System.IO.StreamWriter($StdErrFile,$true,[System.Text.Encoding]::UTF8); $sw.AutoFlush = $true }
      while (-not $token.IsCancellationRequested) {
        $line = $p.StandardError.ReadLine()
        if ($null -eq $line) { break }
        if ($sw) { $sw.WriteLine($line) }
        & $appendLimited $sbErr ($line + "`n") $captureMaxChars
      }
      if ($sw) { $sw.Dispose() }
    } catch { }
  }, $token)

  $exited = $p.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try { $cts.Cancel() } catch {}
    try { $p.Kill($true) } catch {}
    throw "External process timed out after $TimeoutSeconds seconds: $FilePath"
  }

  try { $cts.Cancel() } catch {}
  try { [System.Threading.Tasks.Task]::WaitAll(@($taskOut,$taskErr), 2000) } catch {}

  # If streaming was not enabled, read remaining buffers now.
  if (-not $StdOutFile) {
    try { & $appendLimited $sbOut ($p.StandardOutput.ReadToEnd()) $captureMaxChars } catch {}
  }
  if (-not $StdErrFile) {
    try { & $appendLimited $sbErr ($p.StandardError.ReadToEnd()) $captureMaxChars } catch {}
  }

  return [pscustomobject]@{
    ExitCode = $p.ExitCode
    StdOut   = $sbOut.ToString()
    StdErr   = $sbErr.ToString()
  }
}


function Get-47DefaultConfig {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  $p = Join-Path $paths.FrameworkRoot 'default.config.json'
  if (Test-Path -LiteralPath $p) { return (Read-47Json -Path $p) }
  return [pscustomobject]@{
    configVersion = 1
    repo = @{ id = 'repo.local.default'; channel = 'stable' }
    logging = @{ level = 'info'; retentionDays = 14 }
    safety = @{ mode = 'safe' }
  }
}

function Merge-47Object {
  param([object]$Base, [object]$Overlay)
  if ($null -eq $Base) { return $Overlay }
  if ($null -eq $Overlay) { return $Base }

  # Hashtable / PSCustomObject merge
  if (($Base -is [hashtable] -or $Base -is [pscustomobject]) -and ($Overlay -is [hashtable] -or $Overlay -is [pscustomobject])) {
    $b = @{}
    foreach ($p in $Base.PSObject.Properties) { $b[$p.Name] = $p.Value }
    foreach ($p in $Overlay.PSObject.Properties) { $b[$p.Name] = Merge-47Object -Base $b[$p.Name] -Overlay $p.Value }
    return [pscustomobject]$b
  }

  # Arrays: overlay wins
  return $Overlay
}

function Get-47EffectiveConfig {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  $cfg = Get-47DefaultConfig

  if (Test-Path -LiteralPath $paths.ConfigMachinePath) {
    $cfg = Merge-47Object -Base $cfg -Overlay (Read-47Json -Path $paths.ConfigMachinePath)
  }
  if (Test-Path -LiteralPath $paths.ConfigUserPath) {
    $cfg = Merge-47Object -Base $cfg -Overlay (Read-47Json -Path $paths.ConfigUserPath)
  }
  return $cfg
}

function Invoke-47Migrations {
  [CmdletBinding()]
  param(
    [int]$TargetConfigVersion = 1
  )
  $paths = Get-47Paths
  $cfgPath = $paths.ConfigUserPath
  if (-not (Test-Path -LiteralPath $cfgPath)) { return $false }

  $cfg = Read-47Json -Path $cfgPath
  $current = [int]($cfg.configVersion | ForEach-Object { $_ })
  if ($current -ge $TargetConfigVersion) { return $true }

  $migRoot = Join-Path $paths.FrameworkRoot 'Core\Migrations'
  if (-not (Test-Path -LiteralPath $migRoot)) { return $false }

  for ($v = $current + 1; $v -le $TargetConfigVersion; $v++) {
    $script = Join-Path $migRoot ("migrate_to_{0}.ps1" -f $v)
    if (Test-Path -LiteralPath $script) {
      Write-47Log -Level 'info' -EventId 'FWK0301' -Message "Applying migration to v$v" -Data @{ script=$script }
      & $script -ConfigPath $cfgPath
    } else {
      Write-47Log -Level 'warning' -EventId 'FWK0302' -Message "Missing migration script for v$v" -Data @{ expected=$script }
      throw "Cannot migrate: missing $script"
    }
  }

  return $true
}

function Read-47TrustStore {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  $p = Join-Path $paths.TrustRoot 'publishers.json'
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  return (Read-47Json -Path $p)
}

function Test-47ArtifactHashTrusted {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$Sha256Hex
  )
  $store = Read-47TrustStore
  if ($null -eq $store) { return $false }
  return ($store.trustedArtifactHashes -contains $Sha256Hex.ToLowerInvariant())
}

function Save-47Snapshot {
  [CmdletBinding()]
  param(
    [string]$Name = 'snapshot',
    [switch]$IncludePack,
    [switch]$IncludeMachine
  )

  $paths = Get-47Paths
  New-Item -ItemType Directory -Force -Path $paths.SnapshotsRootUser | Out-Null

  $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
  $safeName = ($Name -replace '[^A-Za-z0-9_\-]','_')
  $snapId = "{0}_{1}" -f $ts, $safeName
  $snapZip = Join-Path $paths.SnapshotsRootUser ("{0}.zip" -f $snapId)

  $stage = New-47TempDirectory -Prefix 'snapshot'
  $stageRoot = Join-Path $stage 'snapshot_payload'
  New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

  $manifest = [ordered]@{
    schemaVersion = '1.0.0'
    snapshotId    = $snapId
    createdAt     = (Get-Date).ToUniversalTime().ToString('o')
    includePack   = [bool]$IncludePack
    includeMachine= [bool]$IncludeMachine
    items         = @()
  }

  # User data
  $userRoot = $paths.LocalAppDataRoot
  if (Test-Path -LiteralPath $userRoot) {
    $dst = Join-Path $stageRoot 'user'
    Copy-Item -Recurse -Force -LiteralPath $userRoot -Destination $dst
    $manifest.items += [pscustomobject]@{ type='userData'; path='user' }
  }

  # Machine data (best-effort)
  if ($IncludeMachine) {
    $machRoot = $paths.ProgramDataRoot
    if (Test-Path -LiteralPath $machRoot) {
      $dst = Join-Path $stageRoot 'machine'
      Copy-Item -Recurse -Force -LiteralPath $machRoot -Destination $dst
      $manifest.items += [pscustomobject]@{ type='machineData'; path='machine' }
    }
  }

  # Pack folder snapshot (for update rollback)
  if ($IncludePack) {
    $pack = $paths.PackRoot
    $dst = Join-Path $stageRoot 'pack'
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    # Copy everything except user snapshot/staging folders if inside pack (portable setups)
    Get-ChildItem -LiteralPath $pack -Force | Where-Object { $_.Name -notin @('dist') } | ForEach-Object {
      Copy-Item -Recurse -Force -LiteralPath $_.FullName -Destination (Join-Path $dst $_.Name)
    }
    $manifest.items += [pscustomobject]@{ type='pack'; path='pack' }
  }

  ($manifest | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath (Join-Path $stageRoot 'manifest.json') -Encoding UTF8

  if (Test-Path -LiteralPath $snapZip) { Remove-Item -Force -LiteralPath $snapZip }
  Compress-Archive -Path (Join-Path $stageRoot '*') -DestinationPath $snapZip -Force

  # cleanup
  Remove-Item -Recurse -Force -LiteralPath $stage

  Write-47Log -Level 'info' -EventId 'FWK0401' -Message "Snapshot created" -Data @{ snapshot=$snapZip; includePack=[bool]$IncludePack }
  return $snapZip
}

function Get-47Snapshots {
  [CmdletBinding()]
  param()
  $paths = Get-47Paths
  if (-not (Test-Path -LiteralPath $paths.SnapshotsRootUser)) { return @() }
  return Get-ChildItem -LiteralPath $paths.SnapshotsRootUser -Filter *.zip -File | Sort-Object LastWriteTime -Descending
}

function Restore-47Snapshot {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$SnapshotPath,

    [switch]$RestorePack,
    [switch]$RestoreMachine
  )

  if (-not (Test-Path -LiteralPath $SnapshotPath)) { throw "Snapshot not found: $SnapshotPath" }
  $paths = Get-47Paths

  $stage = New-47TempDirectory -Prefix 'restore'
  Expand-47ZipSafe -ZipPath $SnapshotPath -DestinationPath $stage

  $manifestPath = Join-Path $stage 'manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Invalid snapshot (manifest missing)." }

  if ($PSCmdlet.ShouldProcess("Restore from $SnapshotPath")) {
    # User data restore
    $userPayload = Join-Path $stage 'user'
    if (Test-Path -LiteralPath $userPayload) {
      if (Test-Path -LiteralPath $paths.LocalAppDataRoot) {
        Remove-Item -Recurse -Force -LiteralPath $paths.LocalAppDataRoot
      }
      Copy-Item -Recurse -Force -LiteralPath $userPayload -Destination $paths.LocalAppDataRoot
    }

    # Machine data restore (best-effort)
    if ($RestoreMachine) {
      $machPayload = Join-Path $stage 'machine'
      if (Test-Path -LiteralPath $machPayload) {
        try {
          if (Test-Path -LiteralPath $paths.ProgramDataRoot) {
            Remove-Item -Recurse -Force -LiteralPath $paths.ProgramDataRoot
          }
          Copy-Item -Recurse -Force -LiteralPath $machPayload -Destination $paths.ProgramDataRoot
        } catch {
          Write-47Log -Level 'warning' -EventId 'FWK0403' -Message "Machine restore failed (permissions?)" -Data @{ error=$_ | Out-String }
        }
      }
    }

    # Pack restore is staged to a separate folder (safer than overwriting the running pack)
    if ($RestorePack) {
      $packPayload = Join-Path $stage 'pack'
      if (Test-Path -LiteralPath $packPayload) {
        $restored = (Join-Path (Split-Path -Parent $paths.PackRoot) ("PackRestored_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
        Copy-Item -Recurse -Force -LiteralPath $packPayload -Destination $restored
        Write-Host ""
        Write-Host "Pack restore staged at:"
        Write-Host " - $restored"
        Write-Host "Swap to it manually (recommended) or re-run tools from that folder."
      }
    }
  }

  Remove-Item -Recurse -Force -LiteralPath $stage
  Write-47Log -Level 'info' -EventId 'FWK0402' -Message "Snapshot restored" -Data @{ snapshot=$SnapshotPath; restorePack=[bool]$RestorePack }
}

function Invoke-47FirstRunWizard {
  [CmdletBinding()]
  param()

  $paths = Get-47Paths

  $needsCfg = -not (Test-Path -LiteralPath $paths.ConfigUserPath)
  $needsPol = -not (Test-Path -LiteralPath $paths.PolicyUserPath)

  if (-not ($needsCfg -or $needsPol)) { return $false }

  Write-Host ""
  Write-Host "First run setup"
  Write-Host "--------------"

  $cfg = Get-47DefaultConfig

  $channel = Read-Host "Default repo channel (stable/beta/nightly) [stable]"
  if ($channel -in @('stable','beta','nightly')) { $cfg.repo.channel = $channel }

  $mode = Read-Host "Safety mode (safe/unsafe) [safe]"
  if ($mode -eq 'unsafe') {
    # still require explicit policy gates for the strongest items
    $cfg.safety.mode = 'unsafe'
  }

  if ($needsCfg) {
    ($cfg | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $paths.ConfigUserPath -Encoding UTF8
    Write-Host "Wrote config: $($paths.ConfigUserPath)"
  }

  if ($needsPol) {
    $policy = [ordered]@{
      schemaVersion = '1.0.0'
      policyLevel   = 'default'
      allowUnsafe   = $false
      unsafeGates   = [ordered]@{
        unsafe_requires_admin = $false
        unsafe_requires_explicit_policy = $false
      }
    }
    ($policy | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $paths.PolicyUserPath -Encoding UTF8
    Write-Host "Wrote policy: $($paths.PolicyUserPath)"
  }

  Write-Host "Done."
  return $true
}



# Load Plan Runner (skeleton)
. (Join-Path $PSScriptRoot 'PlanRunner\47.PlanRunner.psm1')

Export-ModuleMember -Function `
  Get-47PackRoot, Get-47FrameworkRoot, Get-47Paths, Write-47Log, `
  Read-47Json, ConvertTo-47CanonicalObject, ConvertTo-47CanonicalJson, Get-47CanonicalBytes, Get-47Sha256Hex, `
  Get-47PlanHash, Get-47CapabilityCatalog, Get-47Modules, Import-47Module, `
  Get-47EffectivePolicy, Test-47CapabilityAllowed, Test-47RiskAllowed, `
  New-47TempDirectory, Expand-47ZipSafe, Invoke-47External, `
  Get-47DefaultConfig, Get-47EffectiveConfig, Invoke-47Migrations, `
  Read-47TrustStore, Test-47ArtifactHashTrusted, `
  Save-47Snapshot, Get-47Snapshots, Restore-47Snapshot, `
  Invoke-47FirstRunWizard, `
  New-47RunId, New-47RunContext, Register-47StepExecutor, Register-47DefaultStepExecutors, Write-47JournalEntry, Invoke-47PlanStep, Invoke-47PlanRun


# ---- Strings / Localization ----
function Get-47StringTable {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Locale,
    [Parameter(Mandatory)][hashtable]$Paths
  )
  $tables = @()

  $rootTable = Join-Path $Paths.PackRoot ("localization\$Locale.json")
  if (Test-Path -LiteralPath $rootTable) {
    $tables += (Get-Content -LiteralPath $rootTable -Raw | ConvertFrom-Json -AsHashtable)
  }

  # Module string tables (optional): modules/<id>/localization/<locale>.json
  $modRoot = $Paths.ModulesRoot
  if (Test-Path -LiteralPath $modRoot) {
    Get-ChildItem -LiteralPath $modRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $p = Join-Path $_.FullName ("localization\$Locale.json")
      if (Test-Path -LiteralPath $p) {
        $tables += (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable)
      }
    }
  }

  # Merge later tables over earlier ones
  $merged = @{}
  foreach ($t in $tables) {
    foreach ($k in $t.Keys) { $merged[$k] = $t[$k] }
  }
  return $merged
}

function Get-47Text {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][string]$Key,
    [Parameter()][object[]]$Args
  )
  $s = $Context.Strings[$Key]
  if ([string]::IsNullOrWhiteSpace($s)) { $s = $Key }
  if ($Args) {
    try { return [string]::Format($s, $Args) } catch { return $s }
  }
  return $s
}

# ---- Redaction ----
function Redact-47String {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Value)

  $v = $Value

  # common key=value leaks
  $v = $v -replace '(?i)(password|passwd|secret|token|apikey|api_key|access_key|private_key)\s*=\s*[^\s;]+', '$1=<redacted>'

  # JWT-ish token
  $v = $v -replace 'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}', '<redacted.jwt>'

  # long base64-ish blobs
  $v = $v -replace '[A-Za-z0-9+/]{40,}={0,2}', '<redacted.blob>'

  return $v
}

function Redact-47Object {
  [CmdletBinding()]
  param([Parameter(Mandatory)][object]$InputObject)

  if ($null -eq $InputObject) { return $null }

  if ($InputObject -is [string]) { return (Redact-47String -Value $InputObject) }

  if ($InputObject -is [hashtable]) {
    $out = @{}
    foreach ($k in $InputObject.Keys) {
      $keyStr = [string]$k
      $val = $InputObject[$k]
      if ($keyStr -match '(?i)(password|passwd|secret|token|apikey|api_key|access_key|private_key)') {
        $out[$k] = '<redacted>'
      } else {
        $out[$k] = Redact-47Object -InputObject $val
      }
    }
    return $out
  }

  if ($InputObject -is [System.Collections.IDictionary]) {
    $ht = @{}
    foreach ($k in $InputObject.Keys) { $ht[$k] = $InputObject[$k] }
    return (Redact-47Object -InputObject $ht)
  }

  if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
    $arr = @()
    foreach ($x in $InputObject) { $arr += (Redact-47Object -InputObject $x) }
    return $arr
  }

  return $InputObject
}

# ---- Context / Policy assertion ----
function Get-47Context {
  [CmdletBinding()]
  param(
    [Parameter()][string]$Locale = 'en-US'
  )

  $paths = Get-47Paths
  $config = Get-47EffectiveConfig
  $policy = Get-47EffectivePolicy
  $trust = Read-47TrustStore
  $strings = Get-47StringTable -Locale $Locale -Paths $paths

  return [ordered]@{
    Locale = $Locale
    Paths  = $paths
    Config = $config
    Policy = $policy
    Trust  = $trust
    Strings = $strings
  }
}

function Assert-47Policy {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter()][string]$Capability,
    [Parameter()][string]$Risk,
    [Parameter()][string]$Reason = ''
  )

  if ($Capability) {
    if (-not (Test-47CapabilityAllowed -Policy $Context.Policy -CapabilityId $Capability)) {
      $msg = "PolicyDenied: capability '$Capability'. $Reason"
      throw $msg
    }
  }

  if ($Risk) {
    if (-not (Test-47RiskAllowed -Policy $Context.Policy -Risk $Risk)) {
      $msg = "PolicyDenied: risk '$Risk'. $Reason"
      throw $msg
    }
  }
}

# ---- Telemetry (opt-in, local only) ----
function Write-47Telemetry {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][string]$Event,
    [Parameter()][hashtable]$Data
  )

  if (-not $Context.Config.telemetry) { return }
  if (-not $Context.Config.telemetry.enabled) { return }

  $p = Join-Path $Context.Paths.LocalAppDataRoot 'telemetry'
  if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  $file = Join-Path $p 'telemetry.jsonl'

  $entry = [ordered]@{
    ts = (Get-Date).ToUniversalTime().ToString('o')
    event = $Event
    data = (Redact-47Object -InputObject $Data)
  }
  ($entry | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $file -Encoding UTF8
}

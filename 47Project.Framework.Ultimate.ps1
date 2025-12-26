#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
47Project Framework (Nexus Shell) - Ultimate Framework Script
- WPF Nexus Shell UI + CLI
- Module discovery + module settings UI generator
- Plan Engine (step runner) + reports
- Trust Center enforcement (Authenticode allowlist + hash allowlist)
- Safe extraction + quarantine
- Inventory snapshots + diff
- Support bundle export
- AppCrawler bridging (launch + optional helper calls)

Recommended folder layout next to this script:
  .\modules\...\module.json
  .\schemas\...\*.json
  .\policy\...\*.json
  .\data\...
#>

#region Paths / Globals
$script:P47 = [ordered]@{}
$script:P47.Root = Split-Path -Parent $PSCommandPath
$script:P47.DataRoot = Join-Path $script:P47.Root 'data'
$script:P47.LogRoot  = Join-Path $script:P47.DataRoot 'logs'
$script:P47.QuarantineRoot = Join-Path $script:P47.DataRoot 'quarantine'
$script:P47.SnapshotsRoot  = Join-Path $script:P47.DataRoot 'snapshots'
$script:P47.SupportRoot    = Join-Path $script:P47.DataRoot 'support'
$script:P47.PolicyRoot     = Join-Path $script:P47.Root 'policy'
$script:P47.ModulesRoot    = Join-Path $script:P47.Root 'modules'
$script:P47.SchemasRoot    = Join-Path $script:P47.Root 'schemas'
$script:P47.CacheRoot      = Join-Path $script:P47.DataRoot 'cache'

$script:P47.Context = [ordered]@{
  Policy      = $null
  Settings    = $null
  Capabilities= $null
  Modules     = @()
  Ui          = $null
  LogPath     = $null
}
#endregion

#region Utils
function P47-EnsureDirectory {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function P47-Timestamp { (Get-Date).ToString('yyyyMMdd_HHmmss') }

function P47-GetBytesUtf8([string]$s) { [System.Text.Encoding]::UTF8.GetBytes($s) }

function P47-GetSha256Hex {
  param([Parameter(Mandatory)][byte[]]$Bytes)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
  } finally { $sha.Dispose() }
}

function P47-ReadJsonFile {
  param([Parameter(Mandatory)][string]$Path, $Default = $null)
  if (-not (Test-Path -LiteralPath $Path)) { return $Default }
  $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) { return $Default }
  return ($raw | ConvertFrom-Json -Depth 64)
}

function P47-WriteJsonFile {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Object)
  $json = $Object | ConvertTo-Json -Depth 64
  $dir = Split-Path -Parent $Path
  if ($dir) { P47-EnsureDirectory $dir }
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function P47-MergeHashtable {
  param(
    [Parameter(Mandatory)][hashtable]$Base,
    [Parameter(Mandatory)][hashtable]$Overlay
  )
  foreach ($k in $Overlay.Keys) {
    if ($Base.ContainsKey($k) -and ($Base[$k] -is [hashtable]) -and ($Overlay[$k] -is [hashtable])) {
      $Base[$k] = P47-MergeHashtable -Base $Base[$k] -Overlay $Overlay[$k]
    } else {
      $Base[$k] = $Overlay[$k]
    }
  }
  return $Base
}
#endregion

#region Logging
function P47-InitLogging {
  P47-EnsureDirectory $script:P47.LogRoot
  $lp = Join-Path $script:P47.LogRoot ("framework_{0}.log" -f (P47-Timestamp))
  $script:P47.Context.LogPath = $lp
  "=== 47Project Framework ===`nStarted: $(Get-Date -Format o)`nRoot: $($script:P47.Root)`n" | Out-File -FilePath $lp -Encoding UTF8
}

function P47-Log {
  param(
    [Parameter(Mandatory)][ValidateSet('DEBUG','INFO','WARN','ERROR')][string]$Level,
    [Parameter(Mandatory)][string]$Message,
    [hashtable]$Data = $null
  )
  $ts = (Get-Date).ToString('o')
  $line = "[{0}] [{1}] {2}" -f $ts, $Level, $Message
  if ($Data) {
    try { $line += " | " + ($Data | ConvertTo-Json -Compress -Depth 16) } catch { }
  }
  Add-Content -LiteralPath $script:P47.Context.LogPath -Value $line -Encoding UTF8
}
#endregion

#region Policy + Settings (3-tier)
function P47-ReadRegistryPolicyTree {
  param([string]$BaseKey = 'HKLM:\Software\47Project\Framework\Policy')
  $out = @{}
  if (-not (Test-Path $BaseKey)) { return $out }
  $items = Get-ChildItem -Path $BaseKey -Recurse -ErrorAction SilentlyContinue
  foreach ($it in $items) {
    try {
      $props = Get-ItemProperty -Path $it.PSPath -ErrorAction SilentlyContinue
      foreach ($p in $props.PSObject.Properties) {
        if ($p.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') { continue }
        $rel = $it.PSPath.Substring($BaseKey.Length).TrimStart('\')
        $key = if ($rel) { "$rel/$($p.Name)" } else { $p.Name }
        $out[$key] = $p.Value
      }
    } catch { }
  }
  return $out
}

function P47-LoadPolicy {
  $policy = @{}
  if (Test-Path -LiteralPath $script:P47.PolicyRoot) {
    Get-ChildItem -LiteralPath $script:P47.PolicyRoot -Filter *.json -File -ErrorAction SilentlyContinue |
      Sort-Object Name | ForEach-Object {
        try {
          $obj = P47-ReadJsonFile -Path $_.FullName -Default $null
          if ($obj) { $policy[$_.BaseName] = $obj }
        } catch {
          P47-Log WARN "Failed reading policy json: $($_.Name)" @{ error=$_.Exception.Message }
        }
      }
  }
  $reg = P47-ReadRegistryPolicyTree
  $policy['registry'] = [pscustomobject]@{ values = $reg }
  $script:P47.Context.Policy = $policy
  return $policy
}

function P47-LoadSettingsStore {
  P47-EnsureDirectory $script:P47.DataRoot
  $userPath = Join-Path $script:P47.DataRoot 'settings.user.json'
  $machinePath = Join-Path $script:P47.DataRoot 'settings.machine.json'
  $policyPath = Join-Path $script:P47.DataRoot 'settings.policy.json'

  $store = [ordered]@{
    user   = (P47-ReadJsonFile -Path $userPath -Default (@{}))
    machine= (P47-ReadJsonFile -Path $machinePath -Default (@{}))
    policy = (P47-ReadJsonFile -Path $policyPath -Default (@{}))
    paths  = @{ user=$userPath; machine=$machinePath; policy=$policyPath }
  }
  $script:P47.Context.Settings = $store
  return $store
}

function P47-SaveSettingsStore {
  param([ValidateSet('user','machine','policy')][string]$Scope)
  $paths = $script:P47.Context.Settings.paths
  $obj = $script:P47.Context.Settings[$Scope]
  P47-WriteJsonFile -Path $paths[$Scope] -Object $obj
}

function P47-GetSetting {
  param([Parameter(Mandatory)][string]$Key, [ValidateSet('user','machine','policy')][string]$Scope='user', $Default=$null)
  $s = $script:P47.Context.Settings[$Scope]
  if ($s.ContainsKey($Key)) { return $s[$Key] }
  return $Default
}

function P47-SetSetting {
  param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)]$Value, [ValidateSet('user','machine','policy')][string]$Scope='user')
  $script:P47.Context.Settings[$Scope][$Key] = $Value
  P47-SaveSettingsStore -Scope $Scope
}

function P47-GetEffectiveSetting {
  param([Parameter(Mandatory)][string]$Key, $Default=$null)
  $p = $script:P47.Context.Settings.policy
  $m = $script:P47.Context.Settings.machine
  $u = $script:P47.Context.Settings.user
  if ($p.ContainsKey($Key)) { return $p[$Key] }
  if ($m.ContainsKey($Key)) { return $m[$Key] }
  if ($u.ContainsKey($Key)) { return $u[$Key] }
  return $Default
}
#endregion

#region Capabilities
function P47-LoadCapabilities {
  $capPath = Join-Path $script:P47.SchemasRoot 'Capability_Catalog_v1.json'
  $caps = P47-ReadJsonFile -Path $capPath -Default $null
  if (-not $caps) { $caps = [pscustomobject]@{ version='1.0'; capabilities=@() } }
  $script:P47.Context.Capabilities = $caps
  return $caps
}
#endregion

#region Trust Center
function P47-GetSignatureStatus {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    return [pscustomobject]@{ exists=$false; status='Missing'; isTrusted=$false; thumbprint=$null; subject=$null }
  }
  try {
    $sig = Get-AuthenticodeSignature -FilePath $Path
    $thumb = $null; $subj = $null
    if ($sig.SignerCertificate) {
      $thumb = $sig.SignerCertificate.Thumbprint
      $subj = $sig.SignerCertificate.Subject
    }
    $trusted = ($sig.Status -eq 'Valid')
    return [pscustomobject]@{
      exists=$true
      status= [string]$sig.Status
      statusMessage = [string]$sig.StatusMessage
      isTrusted = $trusted
      thumbprint = $thumb
      subject = $subj
    }
  } catch {
    return [pscustomobject]@{ exists=$true; status='Error'; isTrusted=$false; thumbprint=$null; subject=$null; statusMessage=$_.Exception.Message }
  }
}

function P47-TrustGetPolicy {
  $defaults = @{
    requireSignedModules = $false
    requireSignedBundles = $false
    allowedThumbprints   = @()
    allowUnsignedInDev   = $true
    allowedModuleFingerprints = @()
    allowedBundleHashes       = @()
  }

  $trust = $null
  try {
    $trustPath = Join-Path $script:P47.PolicyRoot 'trust.json'
    $trust = P47-ReadJsonFile -Path $trustPath -Default $null
  } catch { $trust = $null }

  $effective = $defaults.Clone()
  if ($trust) {
    foreach ($k in $trust.PSObject.Properties.Name) { $effective[$k] = $trust.$k }
  }

  foreach ($k in $defaults.Keys) {
    $sk = "trust.$k"
    $v = P47-GetEffectiveSetting -Key $sk -Default $null
    if ($null -ne $v) { $effective[$k] = $v }
  }
  return $effective
}

function P47-TrustAssertFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][hashtable]$Trust,
    [ValidateSet('Module','Bundle','Other')][string]$Kind = 'Other'
  )
  if (-not (Test-Path -LiteralPath $Path)) { throw "$Kind missing: $Path" }

  $requireSigned = $false
  if ($Kind -eq 'Module') { $requireSigned = [bool]$Trust.requireSignedModules }
  if ($Kind -eq 'Bundle') { $requireSigned = [bool]$Trust.requireSignedBundles }

  $sig = P47-GetSignatureStatus -Path $Path

  if ($requireSigned) {
    if (-not $sig.isTrusted) { throw "$Kind signature invalid: $($sig.status) ($($sig.statusMessage))" }
    if ($Trust.allowedThumbprints -and $sig.thumbprint) {
      if ($sig.thumbprint -notin @($Trust.allowedThumbprints)) {
        throw "$Kind signer thumbprint not allowlisted: $($sig.thumbprint)"
      }
    }
  }
  return $sig
}

function P47-ComputeFileSha256 {
  param([Parameter(Mandatory)][string]$Path)
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function P47-TrustComputeModuleFingerprint {
  param([Parameter(Mandatory)][string]$ModuleJsonPath)
  $obj = P47-ReadJsonFile -Path $ModuleJsonPath -Default $null
  if (-not $obj) { throw "module.json empty: $ModuleJsonPath" }
  $canon = P47-ToCanonicalJson -Object $obj
  return (P47-GetSha256Hex -Bytes (P47-GetBytesUtf8 $canon))
}

function P47-TrustAssertModule {
  param(
    [Parameter(Mandatory)][pscustomobject]$Module,
    [Parameter(Mandatory)][hashtable]$Trust
  )
  if (-not (Test-Path -LiteralPath $Module.manifestPath)) { throw "Module manifest missing: $($Module.manifestPath)" }

  if ([bool]$Trust.requireSignedModules) {
    foreach ($candidate in @($Module.entryScript, $Module.manifestPath)) {
      if ($candidate -and (Test-Path -LiteralPath $candidate)) {
        P47-TrustAssertFile -Path $candidate -Trust $Trust -Kind Module | Out-Null
      }
    }
  }

  $fp = P47-TrustComputeModuleFingerprint -ModuleJsonPath $Module.manifestPath
  $Module | Add-Member -NotePropertyName fingerprint -NotePropertyValue $fp -Force

  if ($Trust.allowedModuleFingerprints -and ($fp -notin @($Trust.allowedModuleFingerprints))) {
    throw "Module fingerprint not allowlisted: $($Module.id) $fp"
  }
  return $true
}
#endregion

#region Modules
function P47-ReadModuleManifest {
  param([Parameter(Mandatory)][string]$Path)
  $obj = P47-ReadJsonFile -Path $Path -Default $null
  if (-not $obj) { throw "Invalid module.json: $Path" }
  return $obj
}

function P47-ValidateModuleManifest {
  param([Parameter(Mandatory)]$Manifest)
  foreach ($k in @('id','name','version')) {
    if (-not ($Manifest.PSObject.Properties.Name -contains $k)) { throw "module.json missing required: $k" }
  }
  return $true
}

function P47-DiscoverModules {
  $mods = @()
  if (-not (Test-Path -LiteralPath $script:P47.ModulesRoot)) { $script:P47.Context.Modules = @(); return @() }

  Get-ChildItem -LiteralPath $script:P47.ModulesRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $mPath = Join-Path $_.FullName 'module.json'
    if (-not (Test-Path -LiteralPath $mPath)) { return }
    try {
      $m = P47-ReadModuleManifest -Path $mPath
      P47-ValidateModuleManifest -Manifest $m | Out-Null

      $entry = $null
      if ($m.PSObject.Properties.Name -contains 'entryScript') {
        $entry = Join-Path $_.FullName $m.entryScript
        if (-not (Test-Path -LiteralPath $entry)) { $entry = $null }
      }

      $mods += [pscustomobject]@{
        id=$m.id
        name=$m.name
        version=$m.version
        description=($m.description)
        root=$_.FullName
        manifestPath=$mPath
        entryScript=$entry
        manifest=$m
        fingerprint=$null
      }
    } catch {
      P47-Log WARN "Module discovery failed: $($_.Name)" @{ error=$_.Exception.Message }
    }
  }

  try {
    $trust = P47-TrustGetPolicy
    foreach ($mm in $mods) {
      try {
        P47-TrustAssertModule -Module $mm -Trust $trust | Out-Null
      } catch {
        $mm | Add-Member -NotePropertyName trustError -NotePropertyValue $_.Exception.Message -Force
        P47-Log ERROR "Module trust failed" @{ module=$mm.id; error=$_.Exception.Message }
      }
    }
  } catch {
    P47-Log WARN "Trust check skipped due to error" @{ error=$_.Exception.Message }
  }

  $script:P47.Context.Modules = $mods
  return $mods
}

function P47-LoadModuleEntry {
  param([Parameter(Mandatory)][pscustomobject]$Module)
  if ($Module.entryScript -and (Test-Path -LiteralPath $Module.entryScript)) {
    . $Module.entryScript
    P47-Log INFO "Module entry loaded" @{ module=$Module.id; entry=$Module.entryScript }
    return $true
  }
  return $false
}

function P47-GetModuleById {
  param([Parameter(Mandatory)][string]$Id)
  ($script:P47.Context.Modules | Where-Object { $_.id -eq $Id } | Select-Object -First 1)
}

function P47-InvokeModuleAction {
  param(
    [Parameter(Mandatory)][string]$ModuleId,
    [Parameter(Mandatory)][string]$Action,
    [hashtable]$Inputs = @{},
    [hashtable]$Context = @{}
  )

  if ($ModuleId -in @('core','framework')) {
    switch ($Action) {
      'app.install.winget' {
        if (-not $Inputs.id) { throw "winget install requires inputs.id" }
        return (P47-WingetInstall -Id $Inputs.id -ExtraArgs $Inputs.args)
      }
      'app.uninstall.winget' {
        if (-not $Inputs.id) { throw "winget uninstall requires inputs.id" }
        return (P47-WingetUninstall -Id $Inputs.id -ExtraArgs $Inputs.args)
      }
      'exec' {
        if (-not $Inputs.file) { throw "exec requires inputs.file" }
        return (P47-ExecProcess -File $Inputs.file -Args $Inputs.args -WorkingDir $Inputs.workingDir -Wait ([bool]($Inputs.wait -ne $false)))
      }
      'download' {
        if (-not $Inputs.url -or -not $Inputs.outFile) { throw "download requires inputs.url + inputs.outFile" }
        return (P47-DownloadFile -Url $Inputs.url -OutFile $Inputs.outFile)
      }
      'extract' {
        if (-not $Inputs.archive -or -not $Inputs.dest) { throw "extract requires inputs.archive + inputs.dest" }
        return (P47-ExpandArchiveSafely -ZipPath $Inputs.archive -Destination $Inputs.dest)
      }
      default { throw "Unknown core action: $Action" }
    }
  }

  $m = P47-GetModuleById -Id $ModuleId
  if (-not $m) { throw "Module not found: $ModuleId" }
  if ($m.PSObject.Properties.Name -contains 'trustError' -and $m.trustError) { throw "Module disabled (trust): $($m.trustError)" }

  P47-LoadModuleEntry -Module $m | Out-Null

  $man = $m.manifest
  if ($man.PSObject.Properties.Name -contains 'actions') {
    $a = $man.actions | Where-Object { $_.id -eq $Action } | Select-Object -First 1
    if ($a) {
      if ($a.type -eq 'powershellFunction' -and $a.name) {
        if (-not (Get-Command -Name $a.name -ErrorAction SilentlyContinue)) { throw "Handler function not found: $($a.name)" }
        return & $a.name -Inputs $Inputs -Context $Context
      }
      if ($a.type -eq 'powershellScript' -and $a.path) {
        $p = Join-Path $m.root $a.path
        if (-not (Test-Path -LiteralPath $p)) { throw "Handler script missing: $p" }
        return & $p -Inputs $Inputs -Context $Context
      }
    }
  }

  throw "Action not found in module manifest: $ModuleId::$Action"
}
#endregion

#region Canonical JSON + Plan Hash
function P47-JsonEscape([string]$s) {
  ($s -replace '\\','\\\\' -replace '"','\"' -replace "`r",'\\r' -replace "`n",'\\n' -replace "`t",'\\t')
}

function P47-ToCanonicalJson {
  param([Parameter(Mandatory)]$Object)

  function _canon($o) {
    if ($null -eq $o) { return 'null' }
    if ($o -is [string]) { return '"' + (P47-JsonEscape $o) + '"' }
    if ($o -is [bool]) { return ($o.ToString().ToLowerInvariant()) }
    if ($o -is [int] -or $o -is [long] -or $o -is [double] -or $o -is [decimal]) { return ([string]$o) }
    if ($o -is [datetime]) { return '"' + $o.ToString('o') + '"' }

    if ($o -is [System.Collections.IEnumerable] -and -not ($o -is [hashtable]) -and -not ($o -is [pscustomobject])) {
      $items = @()
      foreach ($it in $o) { $items += (_canon $it) }
      return '[' + ($items -join ',') + ']'
    }

    $pairs = @()
    $props = @()
    if ($o -is [hashtable]) { $props = $o.Keys } else { $props = $o.PSObject.Properties.Name }
    foreach ($k in ($props | Sort-Object)) {
      $v = if ($o -is [hashtable]) { $o[$k] } else { $o.$k }
      $pairs += ('"' + (P47-JsonEscape $k) + '":' + (_canon $v))
    }
    return '{' + ($pairs -join ',') + '}'
  }

  (_canon $Object)
}

function P47-GetPlanHash {
  param([Parameter(Mandatory)]$PlanObject)
  $canon = P47-ToCanonicalJson -Object $PlanObject
  $hash = P47-GetSha256Hex -Bytes (P47-GetBytesUtf8 $canon)
  [pscustomobject]@{ hash=$hash; canonicalJson=$canon }
}
#endregion

#region Safe extraction + Quarantine
function P47-ExpandArchiveSafely {
  param(
    [Parameter(Mandatory)][string]$ZipPath,
    [Parameter(Mandatory)][string]$Destination
  )
  if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Archive missing: $ZipPath" }
  P47-EnsureDirectory $Destination

  Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    foreach ($e in $zip.Entries) {
      $target = Join-Path $Destination $e.FullName
      $full = [System.IO.Path]::GetFullPath($target)
      $root = [System.IO.Path]::GetFullPath($Destination)
      if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe zip entry (ZipSlip): $($e.FullName)"
      }
    }
  } finally { $zip.Dispose() }

  Expand-Archive -LiteralPath $ZipPath -DestinationPath $Destination -Force
  P47-Log INFO "Archive extracted safely" @{ zip=$ZipPath; dest=$Destination }
  [pscustomobject]@{ ok=$true; zip=$ZipPath; dest=$Destination }
}

function P47-QuarantineFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Reason = 'quarantine'
  )
  P47-EnsureDirectory $script:P47.QuarantineRoot
  $name = Split-Path -Leaf $Path
  $dst = Join-Path $script:P47.QuarantineRoot ("{0}_{1}_{2}" -f (P47-Timestamp), $Reason, $name)
  Move-Item -LiteralPath $Path -Destination $dst -Force
  P47-Log WARN "File quarantined" @{ src=$Path; dst=$dst; reason=$Reason }
  $dst
}
#endregion

#region Offline Bundle Verification (47bundle)
function P47-ReadZipEntryText {
  param([Parameter(Mandatory)][string]$ZipPath, [Parameter(Mandatory)][string]$EntryPath)
  Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    $e = $zip.GetEntry($EntryPath)
    if (-not $e) { return $null }
    $sr = New-Object System.IO.StreamReader($e.Open(), [System.Text.Encoding]::UTF8)
    try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
  } finally { $zip.Dispose() }
}

function P47-ComputeStreamSha256Hex {
  param([Parameter(Mandatory)][System.IO.Stream]$Stream)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash($Stream)
    return ($hash | ForEach-Object { $_.ToString('x2') }) -join ''
  } finally { $sha.Dispose() }
}

function P47-VerifyBundleZip {
  param(
    [Parameter(Mandatory)][string]$ZipPath,
    [string]$ManifestEntry = 'bundle.manifest.json'
  )
  if (-not (Test-Path -LiteralPath $ZipPath)) { throw "Bundle not found: $ZipPath" }

  $trust = P47-TrustGetPolicy
  # signature + allowlist hash checks (best-effort)
  try { P47-TrustAssertFile -Path $ZipPath -Trust $trust -Kind Bundle | Out-Null } catch { throw $_ }
  $bundleHash = $null
  try { $bundleHash = P47-ComputeFileSha256 -Path $ZipPath } catch { }

  if ($trust.allowedBundleHashes -and $bundleHash -and ($bundleHash -notin @($trust.allowedBundleHashes))) {
    throw "Bundle hash not allowlisted: $bundleHash"
  }

  $raw = P47-ReadZipEntryText -ZipPath $ZipPath -EntryPath $ManifestEntry
  if (-not $raw) { throw "Bundle missing manifest: $ManifestEntry" }

  $manifest = $raw | ConvertFrom-Json -Depth 64
  if (-not ($manifest.PSObject.Properties.Name -contains 'files')) { throw "Manifest missing: files" }

  Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  $results = @()
  try {
    foreach ($f in $manifest.files) {
      $p = [string]$f.path
      $expected = ([string]$f.sha256).ToLowerInvariant()
      $e = $zip.GetEntry($p)
      if (-not $e) {
        $results += [pscustomobject]@{ path=$p; ok=$false; reason='missing-in-zip'; expected=$expected; actual=$null }
        continue
      }
      $s = $e.Open()
      try {
        $actual = (P47-ComputeStreamSha256Hex -Stream $s).ToLowerInvariant()
      } finally { $s.Dispose() }
      $ok = ($actual -eq $expected)
      $results += [pscustomobject]@{ path=$p; ok=$ok; reason=($(if($ok){'ok'}else{'hash-mismatch'})); expected=$expected; actual=$actual }
    }
  } finally { $zip.Dispose() }

  $allOk = -not ($results | Where-Object { -not $_.ok } | Select-Object -First 1)
  return [pscustomobject]@{
    ok = [bool]$allOk
    bundleHash = $bundleHash
    manifestEntry = $ManifestEntry
    fileResults = $results
  }
}

function P47-SafeExtractBundle {
  param(
    [Parameter(Mandatory)][string]$ZipPath,
    [Parameter(Mandatory)][string]$Destination,
    [string]$ManifestEntry = 'bundle.manifest.json'
  )
  $verify = P47-VerifyBundleZip -ZipPath $ZipPath -ManifestEntry $ManifestEntry
  if (-not $verify.ok) { throw "Bundle verification failed (pre-extract)" }

  # extract with ZipSlip protection
  $tmp = Join-Path $script:P47.CacheRoot ("extract_{0}" -f (P47-Timestamp))
  P47-EnsureDirectory $tmp
  P47-ExpandArchiveSafely -ZipPath $ZipPath -Destination $tmp | Out-Null

  # post-extract hash verification against manifest
  $raw = Get-Content -LiteralPath (Join-Path $tmp $ManifestEntry) -Raw -Encoding UTF8
  $manifest = $raw | ConvertFrom-Json -Depth 64

  foreach ($f in $manifest.files) {
    $p = [string]$f.path
    $expected = ([string]$f.sha256).ToLowerInvariant()
    $fp = Join-Path $tmp $p
    if (-not (Test-Path -LiteralPath $fp)) { throw "Extracted file missing: $p" }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $fp).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
      try { P47-QuarantineFile -Path $fp -Reason 'bundle_hash_mismatch' | Out-Null } catch { }
      throw "Hash mismatch after extract: $p"
    }
  }

  # move into destination
  P47-EnsureDirectory $Destination
  Copy-Item -LiteralPath (Join-Path $tmp '*') -Destination $Destination -Recurse -Force
  P47-Log INFO "Bundle safe-extracted" @{ zip=$ZipPath; dest=$Destination }
  return [pscustomobject]@{ ok=$true; dest=$Destination; bundleHash=$verify.bundleHash }
}
#endregion



#region Inventory Snapshots
function P47-GetInstalledAppsRegistry {
  $paths = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  $apps = @()
  foreach ($p in $paths) {
    try {
      Get-ItemProperty -Path $p -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.DisplayName) {
          $apps += [pscustomobject]@{
            name=$_.DisplayName
            version=$_.DisplayVersion
            publisher=$_.Publisher
            uninstall=$_.UninstallString
            source='registry'
          }
        }
      }
    } catch { }
  }
  $apps | Sort-Object name -Unique
}

function P47-TakeInventorySnapshot {
  param([string]$Name = $null)
  P47-EnsureDirectory $script:P47.SnapshotsRoot
  if (-not $Name) { $Name = "inv_{0}" -f (P47-Timestamp) }
  $path = Join-Path $script:P47.SnapshotsRoot ("{0}.json" -f $Name)

  $apps = P47-GetInstalledAppsRegistry
  $snap = [pscustomobject]@{
    kind='inventorySnapshot'
    version='1.0'
    created=(Get-Date).ToString('o')
    apps=$apps
  }
  P47-WriteJsonFile -Path $path -Object $snap
  P47-Log INFO "Inventory snapshot taken" @{ name=$Name; path=$path; count=$apps.Count }
  [pscustomobject]@{ name=$Name; path=$path; count=$apps.Count }
}

function P47-DiffInventorySnapshots {
  param([Parameter(Mandatory)][string]$APath, [Parameter(Mandatory)][string]$BPath)
  $a = P47-ReadJsonFile -Path $APath -Default $null
  $b = P47-ReadJsonFile -Path $BPath -Default $null
  if (-not $a -or -not $b) { throw "Invalid snapshots" }

  $aMap = @{}; foreach ($x in $a.apps) { $aMap[$x.name] = $x }
  $bMap = @{}; foreach ($x in $b.apps) { $bMap[$x.name] = $x }

  $added=@(); $removed=@(); $changed=@()
  foreach ($k in $bMap.Keys) {
    if (-not $aMap.ContainsKey($k)) { $added += $bMap[$k]; continue }
    if ($aMap[$k].version -ne $bMap[$k].version) {
      $changed += [pscustomobject]@{ name=$k; from=$aMap[$k].version; to=$bMap[$k].version }
    }
  }
  foreach ($k in $aMap.Keys) { if (-not $bMap.ContainsKey($k)) { $removed += $aMap[$k] } }

  [pscustomobject]@{ added=$added; removed=$removed; changed=$changed }
}
#endregion

#region Support Bundle
function P47-ExportSupportBundle {
  param([Parameter(Mandatory)][string]$OutZipPath)

  P47-EnsureDirectory $script:P47.SupportRoot
  $tmp = Join-Path $script:P47.SupportRoot ("bundle_{0}" -f (P47-Timestamp))
  P47-EnsureDirectory $tmp

  try { Copy-Item -LiteralPath $script:P47.Context.LogPath -Destination (Join-Path $tmp 'framework.log') -Force } catch { }
  foreach ($f in @('settings.user.json','settings.machine.json','settings.policy.json')) {
    try { Copy-Item -LiteralPath (Join-Path $script:P47.DataRoot $f) -Destination (Join-Path $tmp $f) -Force } catch { }
  }
  try { if (Test-Path $script:P47.PolicyRoot) { Copy-Item -LiteralPath $script:P47.PolicyRoot -Destination (Join-Path $tmp 'policy') -Recurse -Force } } catch { }

  try {
    $inv = P47-TakeInventorySnapshot -Name ("support_inv_{0}" -f (P47-Timestamp))
    Copy-Item -LiteralPath $inv.path -Destination (Join-Path $tmp 'inventory.json') -Force
  } catch { }

  if (Test-Path -LiteralPath $OutZipPath) { Remove-Item -LiteralPath $OutZipPath -Force }
  Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $OutZipPath -Force
  P47-Log INFO "Support bundle exported" @{ out=$OutZipPath }
  $OutZipPath
}
#endregion

#region Core Actions
function P47-ExecProcess {
  param(
    [Parameter(Mandatory)][string]$File,
    [string]$Args = $null,
    [string]$WorkingDir = $null,
    [bool]$Wait = $true
  )
  $cmd = Get-Command $File -ErrorAction SilentlyContinue
  if (-not $cmd -and -not (Test-Path -LiteralPath $File)) { throw "Executable not found: $File" }
  $exe = if ($cmd) { $cmd.Source } else { $File }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe
  if ($Args) { $psi.Arguments = $Args }
  if ($WorkingDir) { $psi.WorkingDirectory = $WorkingDir }
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $null = $p.Start()
  if ($Wait) {
    $p.WaitForExit()
    [pscustomobject]@{
      exitCode=$p.ExitCode
      stdout=$p.StandardOutput.ReadToEnd()
      stderr=$p.StandardError.ReadToEnd()
    }
  } else {
    [pscustomobject]@{ started=$true }
  }
}

function P47-DownloadFile {
  param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)][string]$OutFile)
  $dir = Split-Path -Parent $OutFile
  if ($dir) { P47-EnsureDirectory $dir }
  Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
  P47-Log INFO "Downloaded file" @{ url=$Url; out=$OutFile }
  [pscustomobject]@{ ok=$true; out=$OutFile }
}

function P47-WingetInstall {
  param([Parameter(Mandatory)][string]$Id, [string]$ExtraArgs = $null)
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget not found" }
  $args = "install --id `"$Id`" -e --accept-source-agreements --accept-package-agreements"
  if ($ExtraArgs) { $args += " $ExtraArgs" }
  P47-ExecProcess -File 'winget' -Args $args -Wait $true
}

function P47-WingetUninstall {
  param([Parameter(Mandatory)][string]$Id, [string]$ExtraArgs = $null)
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "winget not found" }
  $args = "uninstall --id `"$Id`" -e"
  if ($ExtraArgs) { $args += " $ExtraArgs" }
  P47-ExecProcess -File 'winget' -Args $args -Wait $true
}
#endregion

#region AppCrawler Bridge
function P47-AppCrawler-ResolvePath {
  $p = P47-GetEffectiveSetting -Key 'modules.appcrawler.path' -Default $null
  if ($p -and (Test-Path -LiteralPath $p)) { return $p }
  $local = Join-Path $script:P47.Root 'Project47_AppCrawler_base.ps1'
  if (Test-Path -LiteralPath $local) { return $local }
  $null
}

function P47-AppCrawler-Launch {
  $p = P47-AppCrawler-ResolvePath
  if (-not $p) { throw "AppCrawler script not found. Set modules.appcrawler.path or place Project47_AppCrawler_base.ps1 next to the framework." }
  P47-Log INFO "Launching AppCrawler (bridge)" @{ path=$p }
  Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$p`""
  [pscustomobject]@{ ok=$true; launched=$true; path=$p }
}

function P47-AppCrawler-GetInventoryBestEffort {
  P47-TakeInventorySnapshot -Name ("appcrawler_inv_{0}" -f (P47-Timestamp))
}
#endregion

#region Plan Engine
function P47-PlanValidate {
  param([Parameter(Mandatory)]$Plan)
  if (-not ($Plan.PSObject.Properties.Name -contains 'kind')) { throw "Plan missing: kind" }
  if (-not ($Plan.PSObject.Properties.Name -contains 'steps')) { throw "Plan missing: steps" }
  foreach ($s in $Plan.steps) {
    if (-not ($s.PSObject.Properties.Name -contains 'module')) { throw "Step missing: module" }
    if (-not ($s.PSObject.Properties.Name -contains 'action')) { throw "Step missing: action" }
  }
  $true
}

function P47-PlanGateCheck {
  param([pscustomobject]$Step)
  $g = $null
  if ($Step.PSObject.Properties.Name -contains 'gates') { $g = $Step.gates }
  if (-not $g) { return $true }

  if ($g.PSObject.Properties.Name -contains 'requireAdmin' -and [bool]$g.requireAdmin) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw "Gate failed: requireAdmin" }
  }
  if ($g.PSObject.Properties.Name -contains 'requireNetwork' -and [bool]$g.requireNetwork) {
    if (-not (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
      throw "Gate failed: requireNetwork"
    }
  }
  $true
}

function P47-TryCreateRestorePoint {
  param([string]$Description = '47Project Framework Plan')
  try {
    $cmd = Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue
    if (-not $cmd) { return [pscustomobject]@{ attempted=$false; ok=$false; reason='Checkpoint-Computer not available' } }

    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      return [pscustomobject]@{ attempted=$true; ok=$false; reason='Administrator required' }
    }

    Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' | Out-Null
    return [pscustomobject]@{ attempted=$true; ok=$true; reason='' }
  } catch {
    return [pscustomobject]@{ attempted=$true; ok=$false; reason=$_.Exception.Message }
  }
}

function P47-InvokeUndoForExecutedSteps {
  param(
    [Parameter(Mandatory)][object[]]$ExecutedSteps,   # list of [pscustomobject] with undo def + stepId
    [Parameter(Mandatory)][hashtable]$Context
  )
  $undoReport = @()
  for ($i = $ExecutedSteps.Count - 1; $i -ge 0; $i--) {
    $es = $ExecutedSteps[$i]
    if (-not $es.undo) { continue }
    try {
      $u = $es.undo
      $inputs = @{}
      if ($u.PSObject.Properties.Name -contains 'inputs' -and $u.inputs) {
        foreach ($p in $u.inputs.PSObject.Properties) { $inputs[$p.Name] = $p.Value }
      }
      $out = P47-InvokeModuleAction -ModuleId $u.module -Action $u.action -Inputs $inputs -Context $Context
      $undoReport += [pscustomobject]@{ stepId=$es.stepId; undo="$($u.module)::$($u.action)"; status='Ok'; output=$out; error=$null }
    } catch {
      $undoReport += [pscustomobject]@{ stepId=$es.stepId; undo="$($es.undo.module)::$($es.undo.action)"; status='Failed'; output=$null; error=$_.Exception.Message }
      P47-Log ERROR "Undo step failed" @{ step=$es.stepId; error=$_.Exception.Message }
    }
  }
  return $undoReport
}

function P47-PlanRun {
  param([Parameter(Mandatory)]$Plan, [switch]$DryRun, [string]$RunName = $null)

  P47-PlanValidate -Plan $Plan | Out-Null
  if (-not $RunName) { $RunName = "planrun_{0}" -f (P47-Timestamp) }
  $reportPath = Join-Path $script:P47.DataRoot ("report_{0}.json" -f $RunName)

  $report = [ordered]@{
    kind='planReport'
    version='1.1'
    created=(Get-Date).ToString('o')
    runName=$RunName
    dryRun=[bool]$DryRun
    planName=$Plan.name
    planId=$Plan.id
    planHash=(P47-GetPlanHash -PlanObject $Plan).hash
    rollback=@{}
    preSnapshots=@()
    steps=@()
    status='Running'
    undo=@()
  }

  # Rollback config
  $rb = $null
  if ($Plan.PSObject.Properties.Name -contains 'rollback') { $rb = $Plan.rollback }
  $doInv = $true
  $doRestorePoint = $false
  $doUndoOnFailure = $true

  if ($rb) {
    if ($rb.PSObject.Properties.Name -contains 'takeInventorySnapshot') { $doInv = [bool]$rb.takeInventorySnapshot }
    if ($rb.PSObject.Properties.Name -contains 'createRestorePoint') { $doRestorePoint = [bool]$rb.createRestorePoint }
    if ($rb.PSObject.Properties.Name -contains 'undoOnFailure') { $doUndoOnFailure = [bool]$rb.undoOnFailure }
  }

  if ($doRestorePoint -and -not $DryRun) {
    $rp = P47-TryCreateRestorePoint -Description ("47Plan {0}" -f ($Plan.name ?? $Plan.id))
    $report.rollback.restorePoint = $rp
    P47-WriteJsonFile -Path $reportPath -Object $report
  }

  if ($doInv) {
    try {
      $snap = P47-TakeInventorySnapshot -Name ("{0}_pre" -f $RunName)
      $report.preSnapshots += [ordered]@{ type='inventory'; path=$snap.path; name=$snap.name }
    } catch { P47-Log WARN "Pre snapshot failed" @{ error=$_.Exception.Message } }
  }

  $ctx = @{ runName=$RunName; reportPath=$reportPath; frameworkRoot=$script:P47.Root; dataRoot=$script:P47.DataRoot }
  $executed = @()

  $idx = 0
  foreach ($step in $Plan.steps) {
    $idx++
    $sid = if ($step.PSObject.Properties.Name -contains 'id' -and $step.id) { $step.id } else { "step$idx" }
    $entry = [ordered]@{
      id=$sid; module=$step.module; action=$step.action
      started=(Get-Date).ToString('o'); status='Running'
      inputs=$step.inputs; output=$null; error=$null
    }

    try {
      P47-PlanGateCheck -Step $step | Out-Null
      if ($DryRun) {
        $entry.status='DryRun'
        $entry.output=[ordered]@{ note='Dry run; not executed.' }
      } else {
        $inputs = @{}
        if ($step.PSObject.Properties.Name -contains 'inputs' -and $step.inputs) {
          foreach ($p in $step.inputs.PSObject.Properties) { $inputs[$p.Name] = $p.Value }
        }
        $entry.output = P47-InvokeModuleAction -ModuleId $step.module -Action $step.action -Inputs $inputs -Context $ctx
        $entry.status='Ok'

        # record executed for undo
        $u = $null
        if ($step.PSObject.Properties.Name -contains 'undo') { $u = $step.undo }
        $executed += [pscustomobject]@{ stepId=$sid; module=$step.module; action=$step.action; undo=$u }
      }
    } catch {
      $entry.status='Failed'
      $entry.error=$_.Exception.Message
      $entry.ended=(Get-Date).ToString('o')
      $report.steps += $entry
      $report.status='Failed'

      # Undo-on-failure (best-effort)
      if ($doUndoOnFailure -and -not $DryRun -and $executed.Count -gt 0) {
        try {
          $report.undo = @(P47-InvokeUndoForExecutedSteps -ExecutedSteps $executed -Context $ctx)
        } catch { }
      }

      P47-WriteJsonFile -Path $reportPath -Object $report
      P47-Log ERROR "Plan step failed" @{ step=$sid; error=$_.Exception.Message }
      return [pscustomobject]$report
    }

    $entry.ended=(Get-Date).ToString('o')
    $report.steps += $entry
    P47-WriteJsonFile -Path $reportPath -Object $report
  }

  $report.status='Ok'

  if ($doInv -and $report.preSnapshots.Count -gt 0) {
    try {
      $snap2 = P47-TakeInventorySnapshot -Name ("{0}_post" -f $RunName)
      $report.postSnapshot=[ordered]@{ type='inventory'; path=$snap2.path; name=$snap2.name }
      $report.diff = P47-DiffInventorySnapshots -APath $report.preSnapshots[0].path -BPath $snap2.path
    } catch { P47-Log WARN "Post snapshot/diff failed" @{ error=$_.Exception.Message } }
  }

  P47-WriteJsonFile -Path $reportPath -Object $report
  P47-Log INFO "Plan run completed" @{ run=$RunName; status=$report.status; report=$reportPath }
  [pscustomobject]$report
}
#endregion

#region WPF UI
function P47-LoadWpfAssemblies {
  Add-Type -AssemblyName PresentationFramework | Out-Null
  Add-Type -AssemblyName PresentationCore | Out-Null
  Add-Type -AssemblyName WindowsBase | Out-Null
}

function P47-NewTextBlock {
  param([Parameter(Mandatory)][string]$Text, [int]$FontSize = 14, [bool]$Bold = $false)
  $tb = New-Object System.Windows.Controls.TextBlock
  $tb.Text = $Text
  $tb.FontSize = $FontSize
  $tb.TextWrapping = 'Wrap'
  if ($Bold) { $tb.FontWeight = 'Bold' }
  $tb
}

function P47-NewButton {
  param([Parameter(Mandatory)][string]$Text, [scriptblock]$OnClick = $null)
  $b = New-Object System.Windows.Controls.Button
  $b.Content = $Text
  $b.Margin = '0,6,0,0'
  $b.Padding = '10,6,10,6'
  if ($OnClick) { $b.Add_Click($OnClick) }
  $b
}

function P47-ShowMessage {
  param([Parameter(Mandatory)][string]$Text, [string]$Title = '47Project Framework')
  [System.Windows.MessageBox]::Show($Text, $Title) | Out-Null
}

function P47-RenderSettingsPage {
  param([pscustomobject]$Module)
  $sp = New-Object System.Windows.Controls.StackPanel
  $sp.Margin = '16'
  $sp.Children.Add((P47-NewTextBlock -Text ("Settings: {0}" -f $Module.name) -FontSize 20 -Bold $true)) | Out-Null
  $sp.Children.Add((P47-NewTextBlock -Text ("Module ID: {0}" -f $Module.id) -FontSize 12)) | Out-Null

  $items = @()
  if ($Module.manifest.PSObject.Properties.Name -contains 'settings') { $items = $Module.manifest.settings }

  foreach ($s in $items) {
    $row = New-Object System.Windows.Controls.StackPanel
    $row.Margin = '0,10,0,0'
    $row.Children.Add((P47-NewTextBlock -Text ($s.label ?? $s.key) -FontSize 14 -Bold $true)) | Out-Null

    $key = [string]$s.key
    $type = [string]$s.type
    $def = $s.default
    $cur = P47-GetEffectiveSetting -Key $key -Default $def

    if ($type -eq 'bool') {
      $cb = New-Object System.Windows.Controls.CheckBox
      $cb.IsChecked = [bool]$cur
      $cb.Add_Checked({ P47-SetSetting -Key $key -Value $true -Scope 'user' })
      $cb.Add_Unchecked({ P47-SetSetting -Key $key -Value $false -Scope 'user' })
      $row.Children.Add($cb) | Out-Null
    } else {
      $tb = New-Object System.Windows.Controls.TextBox
      $tb.Text = [string]$cur
      $tb.MinWidth = 360
      $row.Children.Add($tb) | Out-Null
      $row.Children.Add((P47-NewButton -Text 'Save' -OnClick {
        P47-SetSetting -Key $key -Value $tb.Text -Scope 'user'
        P47-ShowMessage "Saved: $key"
      })) | Out-Null
    }
    $sp.Children.Add($row) | Out-Null
  }
  $sp
}

function P47-BuildRouteMap {
  $routes = @{}

  $routes['/home'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text '47Project Framework' -FontSize 24 -Bold $true)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text 'Nexus Shell (Ultimate). Modules + Plans + Trust Center.' -FontSize 12)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text ("Modules detected: {0}" -f ($script:P47.Context.Modules.Count)) -FontSize 12)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text ("Log: {0}" -f $script:P47.Context.LogPath) -FontSize 11)) | Out-Null
    $sp.Children.Add((P47-NewButton -Text 'Open AppCrawler (bridge)' -OnClick {
      try { P47-AppCrawler-Launch | Out-Null } catch { P47-ShowMessage $_.Exception.Message }
    })) | Out-Null
    $sp
  }

  $routes['/modules'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text 'Modules' -FontSize 22 -Bold $true)) | Out-Null
    foreach ($m in $script:P47.Context.Modules) {
      $card = New-Object System.Windows.Controls.Border
      $card.BorderThickness = '1'
      $card.CornerRadius = '8'
      $card.Margin = '0,10,0,0'
      $card.Padding = '12'

      $inner = New-Object System.Windows.Controls.StackPanel
      $inner.Children.Add((P47-NewTextBlock -Text ("{0}  ({1})" -f $m.name, $m.version) -FontSize 16 -Bold $true)) | Out-Null
      $inner.Children.Add((P47-NewTextBlock -Text ("id: {0}" -f $m.id) -FontSize 11)) | Out-Null
      if ($m.description) { $inner.Children.Add((P47-NewTextBlock -Text $m.description -FontSize 12)) | Out-Null }
      if ($m.fingerprint) { $inner.Children.Add((P47-NewTextBlock -Text ("fingerprint: {0}" -f $m.fingerprint) -FontSize 10)) | Out-Null }
      if ($m.PSObject.Properties.Name -contains 'trustError' -and $m.trustError) {
        $t = P47-NewTextBlock -Text ("TRUST BLOCKED: {0}" -f $m.trustError) -FontSize 11 -Bold $true
        $t.Foreground = 'DarkRed'
        $inner.Children.Add($t) | Out-Null
      }

      $inner.Children.Add((P47-NewButton -Text 'Settings' -OnClick { $script:P47.Context.Ui.NavigateTo.Invoke("/settings?module=$($m.id)") })) | Out-Null
      $card.Child = $inner
      $sp.Children.Add($card) | Out-Null
    }
    $sp
  }

  $routes['/planhub'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text 'Plan Hub' -FontSize 22 -Bold $true)) | Out-Null

    $pathBox = New-Object System.Windows.Controls.TextBox
    $pathBox.MinWidth = 520
    $sp.Children.Add($pathBox) | Out-Null

    $sp.Children.Add((P47-NewButton -Text 'Browse' -OnClick {
      $dlg = New-Object Microsoft.Win32.OpenFileDialog
      $dlg.Filter = 'JSON (*.json)|*.json|All files (*.*)|*.*'
      if ($dlg.ShowDialog()) { $pathBox.Text = $dlg.FileName }
    })) | Out-Null

    $hashOut = New-Object System.Windows.Controls.TextBox
    $hashOut.IsReadOnly = $true
    $hashOut.Margin = '0,10,0,0'
    $hashOut.MinWidth = 520
    $sp.Children.Add((P47-NewTextBlock -Text 'Plan Hash' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($hashOut) | Out-Null

    $runOut = New-Object System.Windows.Controls.TextBox
    $runOut.IsReadOnly = $true
    $runOut.Margin = '0,10,0,0'
    $runOut.TextWrapping = 'Wrap'
    $runOut.VerticalScrollBarVisibility = 'Auto'
    $runOut.Height = 240
    $sp.Children.Add((P47-NewTextBlock -Text 'Run Output' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($runOut) | Out-Null

    $load = {
      $p = $pathBox.Text
      if (-not (Test-Path -LiteralPath $p)) { P47-ShowMessage 'Select a valid plan file.'; return $null }
      $obj = P47-ReadJsonFile -Path $p -Default $null
      if (-not $obj) { P47-ShowMessage 'Empty plan.'; return $null }
      $hashOut.Text = (P47-GetPlanHash -PlanObject $obj).hash
      $obj
    }

    $sp.Children.Add((P47-NewButton -Text 'Dry Run' -OnClick {
      try {
        $pl = & $load
        if (-not $pl) { return }
        $rep = P47-PlanRun -Plan $pl -DryRun
        $runOut.Text = ($rep | ConvertTo-Json -Depth 16)
      } catch { P47-ShowMessage $_.Exception.Message }
    })) | Out-Null

    $sp.Children.Add((P47-NewButton -Text 'Execute' -OnClick {
      $pl = & $load
      if (-not $pl) { return }
      $res = [System.Windows.MessageBox]::Show('Execute this plan now?', 'Confirm', 'YesNo', 'Warning')
      if ($res -ne 'Yes') { return }
      try {
        $rep = P47-PlanRun -Plan $pl
        $runOut.Text = ($rep | ConvertTo-Json -Depth 16)
      } catch { P47-ShowMessage $_.Exception.Message }
    })) | Out-Null

    $sp
  }

  
  $routes['/planbuilder'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text 'Plan Builder' -FontSize 22 -Bold $true)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text 'Build a 47plan by selecting module actions and saving to JSON.' -FontSize 12)) | Out-Null

    # Plan fields
    $pid = New-Object System.Windows.Controls.TextBox
    $pid.MinWidth = 520
    $pid.Text = "plan_{0}" -f (P47-Timestamp)
    $pname = New-Object System.Windows.Controls.TextBox
    $pname.MinWidth = 520
    $pname.Text = "New Plan"

    $sp.Children.Add((P47-NewTextBlock -Text 'Plan ID' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($pid) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text 'Plan Name' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($pname) | Out-Null

    # Module/action picker
    $modBox = New-Object System.Windows.Controls.ComboBox
    $modBox.MinWidth = 360
    $actBox = New-Object System.Windows.Controls.ComboBox
    $actBox.MinWidth = 520

    $catalog = New-Object System.Collections.ArrayList
    # Core actions
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='exec' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='download' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='extract' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='bundle.verify' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='bundle.safeExtract' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='app.install.winget' })
    $null = $catalog.Add([pscustomobject]@{ module='core'; action='app.uninstall.winget' })

    foreach ($m in $script:P47.Context.Modules) {
      if ($m.PSObject.Properties.Name -contains 'trustError' -and $m.trustError) { continue }
      if ($m.manifest.PSObject.Properties.Name -contains 'actions') {
        foreach ($a in $m.manifest.actions) {
          $null = $catalog.Add([pscustomobject]@{ module=$m.id; action=$a.id })
        }
      }
    }

    $modsUnique = $catalog | Select-Object -ExpandProperty module -Unique
    foreach ($m in $modsUnique) { [void]$modBox.Items.Add($m) }

    $refreshActions = {
      $actBox.Items.Clear()
      $sel = [string]$modBox.SelectedItem
      foreach ($x in $catalog | Where-Object { $_.module -eq $sel }) {
        [void]$actBox.Items.Add($x.action)
      }
      if ($actBox.Items.Count -gt 0) { $actBox.SelectedIndex = 0 }
    }
    $modBox.Add_SelectionChanged({ & $refreshActions })
    if ($modBox.Items.Count -gt 0) { $modBox.SelectedIndex = 0 }

    $sp.Children.Add((P47-NewTextBlock -Text 'Step Module' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($modBox) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text 'Step Action' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($actBox) | Out-Null

    $inputsBox = New-Object System.Windows.Controls.TextBox
    $inputsBox.MinWidth = 520
    $inputsBox.Height = 90
    $inputsBox.TextWrapping = 'Wrap'
    $inputsBox.VerticalScrollBarVisibility = 'Auto'
    $inputsBox.Text = '{ }'
    $sp.Children.Add((P47-NewTextBlock -Text 'Inputs (JSON object)' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($inputsBox) | Out-Null

    $steps = New-Object System.Collections.ArrayList
    $stepsList = New-Object System.Windows.Controls.ListBox
    $stepsList.MinWidth = 520
    $stepsList.Height = 160

    $addStep = {
      try {
        $inp = $inputsBox.Text
        $obj = $null
        if ([string]::IsNullOrWhiteSpace($inp)) { $obj = [pscustomobject]@{} }
        else { $obj = $inp | ConvertFrom-Json -Depth 64 }
        $sid = "step{0}" -f ($steps.Count + 1)
        $stepObj = [pscustomobject]@{ id=$sid; module=[string]$modBox.SelectedItem; action=[string]$actBox.SelectedItem; inputs=$obj }
        $null = $steps.Add($stepObj)
        $stepsList.Items.Add("{0}: {1}::{2}" -f $sid, $stepObj.module, $stepObj.action) | Out-Null
      } catch {
        P47-ShowMessage "Invalid inputs JSON: $($_.Exception.Message)"
      }
    }

    $sp.Children.Add((P47-NewButton -Text 'Add Step' -OnClick $addStep)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text 'Steps' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($stepsList) | Out-Null

    $save = {
      if ($steps.Count -eq 0) { P47-ShowMessage 'Add at least one step.'; return }
      $dlg = New-Object Microsoft.Win32.SaveFileDialog
      $dlg.Filter = 'JSON (*.json)|*.json|All files (*.*)|*.*'
      $dlg.FileName = "$($pid.Text).plan.json"
      if (-not $dlg.ShowDialog()) { return }

      $plan = [pscustomobject]@{
        kind='47plan'
        version='1.1'
        id=$pid.Text
        name=$pname.Text
        created=(Get-Date).ToString('o')
        rollback=[pscustomobject]@{ takeInventorySnapshot=$true; createRestorePoint=$false; undoOnFailure=$true }
        steps=@($steps)
      }

      $json = $plan | ConvertTo-Json -Depth 64
      Set-Content -LiteralPath $dlg.FileName -Value $json -Encoding UTF8
      $h = (P47-GetPlanHash -PlanObject $plan).hash
      P47-ShowMessage "Saved plan.`nHash: $h"
    }

    $sp.Children.Add((P47-NewButton -Text 'Save Plan JSON' -OnClick $save)) | Out-Null
    return $sp
  }


$routes['/diagnostics'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text 'Diagnostics' -FontSize 22 -Bold $true)) | Out-Null
    $sp.Children.Add((P47-NewButton -Text 'Take Inventory Snapshot' -OnClick {
      try { $snap = P47-TakeInventorySnapshot; P47-ShowMessage "Snapshot: $($snap.path)" } catch { P47-ShowMessage $_.Exception.Message }
    })) | Out-Null
    $sp.Children.Add((P47-NewButton -Text 'Export Support Bundle (Desktop)' -OnClick {
      try {
        $out = Join-Path $env:USERPROFILE ("Desktop\47support_{0}.zip" -f (P47-Timestamp))
        $p = P47-ExportSupportBundle -OutZipPath $out
        P47-ShowMessage "Exported: $p"
      } catch { P47-ShowMessage $_.Exception.Message }
    })) | Out-Null
    $sp
  }

  $routes['/trust'] = {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '16'
    $sp.Children.Add((P47-NewTextBlock -Text 'Trust Center' -FontSize 22 -Bold $true)) | Out-Null
    $trust = P47-TrustGetPolicy
    $sp.Children.Add((P47-NewTextBlock -Text ("requireSignedModules: {0}" -f $trust.requireSignedModules) -FontSize 12)) | Out-Null
    $sp.Children.Add((P47-NewTextBlock -Text ("requireSignedBundles: {0}" -f $trust.requireSignedBundles) -FontSize 12)) | Out-Null

    $pathBox = New-Object System.Windows.Controls.TextBox
    $pathBox.MinWidth = 520
    $sp.Children.Add((P47-NewTextBlock -Text 'Verify file signature' -FontSize 12 -Bold $true)) | Out-Null
    $sp.Children.Add($pathBox) | Out-Null

    $sp.Children.Add((P47-NewButton -Text 'Browse' -OnClick {
      $dlg = New-Object Microsoft.Win32.OpenFileDialog
      $dlg.Filter = 'All files (*.*)|*.*'
      if ($dlg.ShowDialog()) { $pathBox.Text = $dlg.FileName }
    })) | Out-Null

    $out = New-Object System.Windows.Controls.TextBox
    $out.IsReadOnly = $true
    $out.Margin = '0,10,0,0'
    $out.TextWrapping = 'Wrap'
    $out.VerticalScrollBarVisibility = 'Auto'
    $out.Height = 200
    $sp.Children.Add($out) | Out-Null

    $sp.Children.Add((P47-NewButton -Text 'Verify' -OnClick {
      try {
        $sig = P47-TrustAssertFile -Path $pathBox.Text -Trust $trust -Kind Other
        $out.Text = ($sig | ConvertTo-Json -Depth 8)
      } catch { $out.Text = "FAILED: $($_.Exception.Message)" }
    })) | Out-Null
    $sp
  }

  $routes['/settings'] = {
    $uri = $script:P47.Context.Ui.CurrentUri
    $mid = $null
    if ($uri -match 'module=([^&]+)') { $mid = $Matches[1] }
    if (-not $mid) {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Margin = '16'
      $sp.Children.Add((P47-NewTextBlock -Text 'Framework Settings' -FontSize 22 -Bold $true)) | Out-Null
      $sp.Children.Add((P47-NewTextBlock -Text ("modules.appcrawler.path = {0}" -f (P47-GetEffectiveSetting -Key 'modules.appcrawler.path' -Default '')) -FontSize 12)) | Out-Null
      $sp.Children.Add((P47-NewButton -Text 'Set AppCrawler Path' -OnClick {
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = 'PowerShell script (*.ps1)|*.ps1|All files (*.*)|*.*'
        if ($dlg.ShowDialog()) {
          P47-SetSetting -Key 'modules.appcrawler.path' -Value $dlg.FileName -Scope 'user'
          P47-ShowMessage 'Saved.'
          $script:P47.Context.Ui.NavigateTo.Invoke('/settings')
        }
      })) | Out-Null
      $sp
    } else {
      $m = P47-GetModuleById -Id $mid
      if (-not $m) {
        $sp = New-Object System.Windows.Controls.StackPanel
        $sp.Margin = '16'
        $sp.Children.Add((P47-NewTextBlock -Text 'Module not found.' -FontSize 14 -Bold $true)) | Out-Null
        $sp
      } else {
        P47-RenderSettingsPage -Module $m
      }
    }
  }

  $routes
}

function P47-StartUi {
  P47-LoadWpfAssemblies

  $win = New-Object System.Windows.Window
  $win.Title = '47Project Framework'
  $win.Width = 1024
  $win.Height = 720
  $win.WindowStartupLocation = 'CenterScreen'

  $grid = New-Object System.Windows.Controls.Grid
  $cd1 = New-Object System.Windows.Controls.ColumnDefinition
  $cd1.Width = '220'
  $cd2 = New-Object System.Windows.Controls.ColumnDefinition
  $cd2.Width = '*'
  $grid.ColumnDefinitions.Add($cd1) | Out-Null
  $grid.ColumnDefinitions.Add($cd2) | Out-Null

  $side = New-Object System.Windows.Controls.StackPanel
  $side.Margin = '12'
  $side.Children.Add((P47-NewTextBlock -Text 'Nexus' -FontSize 22 -Bold $true)) | Out-Null
  $side.Children.Add((P47-NewTextBlock -Text '47Project Framework' -FontSize 12)) | Out-Null

  $contentHost = New-Object System.Windows.Controls.ContentControl
  [System.Windows.Controls.Grid]::SetColumn($contentHost, 1)

  $routes = P47-BuildRouteMap
  $ui = [ordered]@{ Window=$win; Routes=$routes; CurrentUri='/home'; NavigateTo=$null }

  $navTo = {
    param([string]$Uri)
    $ui.CurrentUri = $Uri
    $base = $Uri.Split('?')[0]
    if (-not $routes.ContainsKey($base)) { $base = '/home' }
    $script:P47.Context.Ui = $ui
    $contentHost.Content = & $routes[$base]
  }
  $ui.NavigateTo = $navTo

  foreach ($item in @(
    @{ label='Home'; uri='/home' },
    @{ label='Modules'; uri='/modules' },
    @{ label='Plan Hub'; uri='/planhub' },
    @{ label='Diagnostics'; uri='/diagnostics' },
    @{ label='Trust Center'; uri='/trust' },
    @{ label='Settings'; uri='/settings' }
  )) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = $item.label
    $btn.Margin = '0,8,0,0'
    $btn.Padding = '10,6,10,6'
    $u = $item.uri
    $btn.Add_Click({ $navTo.Invoke($u) })
    $side.Children.Add($btn) | Out-Null
  }

  [System.Windows.Controls.Grid]::SetColumn($side, 0)
  $grid.Children.Add($side) | Out-Null
  $grid.Children.Add($contentHost) | Out-Null

  $win.Content = $grid
  $navTo.Invoke('/home')
  $win.ShowDialog() | Out-Null
}
#endregion

#region CLI
function P47-PrintHelp {
@"
47Project Framework (Nexus Shell)

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\47Project.Framework.Ultimate.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\47Project.Framework.Ultimate.ps1 --cli <command> [args]

CLI Commands:
  modules list
  plan hash --file <path>
  plan run --file <path> [--dryrun]
  trust verify --file <path>
  bundle verify --file <zipPath>
  bundle extract --file <zipPath> --dest <folder>
  support export --out <zipPath>
  inventory snapshot [--name <name>]

"@
}

function P47-RunCli {
  param([string[]]$Args)
  if ($Args.Count -eq 0) { P47-PrintHelp; return }
  $cmd = $Args[0]
  $rest = @(); if ($Args.Count -gt 1) { $rest = $Args[1..($Args.Count-1)] }

  switch ($cmd) {
    'modules' { $script:P47.Context.Modules | Select-Object id,name,version,root,fingerprint,trustError | Format-Table -AutoSize; return }
    'plan' {
      if ($rest.Count -lt 1) { throw "plan requires subcommand" }
      $sub = $rest[0]
      if ($sub -eq 'hash') {
        $file = $rest[($rest.IndexOf('--file') + 1)]
        $obj = P47-ReadJsonFile -Path $file -Default $null
        (P47-GetPlanHash -PlanObject $obj) | Select-Object hash | Format-List
        return
      }
      if ($sub -eq 'run') {
        $file = $rest[($rest.IndexOf('--file') + 1)]
        $dry = ($rest -contains '--dryrun')
        $obj = P47-ReadJsonFile -Path $file -Default $null
        $rep = if ($dry) { P47-PlanRun -Plan $obj -DryRun } else { P47-PlanRun -Plan $obj }
        $rep | ConvertTo-Json -Depth 16
        return
      }
      throw "Unknown plan subcommand"
    }
    'trust' {
      if ($rest.Count -lt 1 -or $rest[0] -ne 'verify') { throw "trust verify required" }
      $file = $rest[($rest.IndexOf('--file') + 1)]
      $trust = P47-TrustGetPolicy
      (P47-TrustAssertFile -Path $file -Trust $trust -Kind Other) | ConvertTo-Json -Depth 8
      return
    }
    'support' {
      if ($rest.Count -lt 1 -or $rest[0] -ne 'export') { throw "support export required" }
      $out = $rest[($rest.IndexOf('--out') + 1)]
      Write-Host (P47-ExportSupportBundle -OutZipPath $out)
      return
    }
    'inventory' {
      if ($rest.Count -lt 1 -or $rest[0] -ne 'snapshot') { throw "inventory snapshot required" }
      $name = $null
      if ($rest -contains '--name') { $name = $rest[($rest.IndexOf('--name') + 1)] }
      (P47-TakeInventorySnapshot -Name $name) | ConvertTo-Json -Depth 6
      return
    }
    
    'bundle' {
      if ($rest.Count -lt 1) { throw "bundle requires subcommand" }
      $sub = $rest[0]
      if ($sub -eq 'verify') {
        $file = $rest[($rest.IndexOf('--file') + 1)]
        (P47-VerifyBundleZip -ZipPath $file) | ConvertTo-Json -Depth 8
        return
      }
      if ($sub -eq 'extract') {
        $file = $rest[($rest.IndexOf('--file') + 1)]
        $dest = $rest[($rest.IndexOf('--dest') + 1)]
        (P47-SafeExtractBundle -ZipPath $file -Destination $dest) | ConvertTo-Json -Depth 6
        return
      }
      throw "Unknown bundle subcommand"
    }

    default { throw "Unknown command: $cmd" }
  }
}
#endregion

#region Boot
function P47-Boot {
  P47-EnsureDirectory $script:P47.DataRoot
  P47-EnsureDirectory $script:P47.CacheRoot
  P47-EnsureDirectory $script:P47.QuarantineRoot
  P47-EnsureDirectory $script:P47.SnapshotsRoot
  P47-InitLogging
  P47-LoadPolicy | Out-Null
  P47-LoadSettingsStore | Out-Null
  P47-LoadCapabilities | Out-Null
  P47-DiscoverModules | Out-Null

  try {
    $cur = P47-GetEffectiveSetting -Key 'modules.appcrawler.path' -Default $null
    if (-not $cur) {
      $local = Join-Path $script:P47.Root 'Project47_AppCrawler_base.ps1'
      if (Test-Path -LiteralPath $local) { P47-SetSetting -Key 'modules.appcrawler.path' -Value $local -Scope 'user' }
    }
  } catch { }

  $argsList = @($args)
  if ($argsList.Count -gt 0 -and $argsList[0] -eq '--cli') {
    $cliArgs = @(); if ($argsList.Count -gt 1) { $cliArgs = $argsList[1..($argsList.Count-1)] }
    P47-RunCli -Args $cliArgs
    return
  }

  P47-StartUi
}

P47-Boot
#endregion

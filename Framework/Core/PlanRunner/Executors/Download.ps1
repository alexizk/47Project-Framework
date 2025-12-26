# Download step executor for 47 Plan Runner
Set-StrictMode -Version Latest

function Limit-47Text {
  param(
    [AllowNull()][string]$Text,
    [int]$MaxChars = 262144
  )
  if ($null -eq $Text) { return $null }
  if ($Text.Length -le $MaxChars) { return $Text }
  return ($Text.Substring(0, $MaxChars) + "`n[TRUNCATED]")
}

function Get-47Sha256Hex {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)

  $h = Get-FileHash -Algorithm SHA256 -LiteralPath $Path
  return ($h.Hash.ToLowerInvariant())
}

function Resolve-47DownloadSource {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$PlanDir
  )

  # Allow local paths for offline/portable plans
  if (Test-Path -LiteralPath $Url) { return [pscustomobject]@{ Kind='LocalPath'; Value=(Resolve-Path -LiteralPath $Url).Path } }

  if ($Url -match '^(file://)(.+)$') {
    $raw = $Matches[2]
    # file:///C:/path or file:///home/user/path
    $p = $raw -replace '^/+','/'
    if ($IsWindows -and ($p -match '^/([A-Za-z]:/)')) { $p = $Matches[1] + $p.Substring(4) }
    $p = $p -replace '/', [System.IO.Path]::DirectorySeparatorChar
    if (Test-Path -LiteralPath $p) { return [pscustomobject]@{ Kind='LocalPath'; Value=(Resolve-Path -LiteralPath $p).Path } }
  }

  # Relative "url" treated as local path relative to plan dir
  if (-not ($Url -match '^[a-zA-Z][a-zA-Z0-9+\-.]*://')) {
    $p2 = Join-Path $PlanDir $Url
    if (Test-Path -LiteralPath $p2) { return [pscustomobject]@{ Kind='LocalPath'; Value=(Resolve-Path -LiteralPath $p2).Path } }
  }

  return [pscustomobject]@{ Kind='RemoteUrl'; Value=$Url }
}

function Resolve-47DownloadDestination {
  [CmdletBinding()]
  param(
    [Parameter()][AllowNull()][string]$Dest,
    [Parameter(Mandatory)][string]$PlanDir,
    [Parameter(Mandatory)][string]$StepDir
  )

  if (-not $Dest) {
    # Default: keep in step artifacts folder
    return Join-Path $StepDir 'download.bin'
  }

  if ([System.IO.Path]::IsPathRooted($Dest)) { return $Dest }
  return Join-Path $PlanDir $Dest
}

function Get-47DownloadCachePath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][string]$Url,
    [Parameter()][AllowNull()][string]$Sha256,
    [Parameter()][AllowNull()][string]$DestPath
  )

  $cacheRoot = Join-Path $Context.Paths.CacheRootUser 'downloads'
  New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

  $key = $null
  if ($Sha256) { $key = $Sha256.ToLowerInvariant() }
  else {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Url)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-','').ToLowerInvariant() } finally { $sha.Dispose() }
  }

  $ext = ''
  if ($DestPath) { $ext = [System.IO.Path]::GetExtension($DestPath) }
  if (-not $ext) {
    try {
      $u = [Uri]$Url
      $ext = [System.IO.Path]::GetExtension($u.AbsolutePath)
    } catch { }
  }
  if (-not $ext) { $ext = '.bin' }

  $filePath = Join-Path $cacheRoot ($key + $ext)
  $metaPath = $filePath + '.meta.json'
  return [pscustomobject]@{ File=$filePath; Meta=$metaPath; Key=$key; Ext=$ext }
}

function Test-47DownloadCheckSatisfied {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][hashtable]$Step,
    [Parameter(Mandatory)][string]$PlanDir,
    [Parameter(Mandatory)][string]$DestPath,
    [Parameter(Mandatory)][ValidateSet('WhatIf','Apply')][string]$Mode
  )

  if (-not $Step.check) { return [pscustomobject]@{ HasCheck=$false; Satisfied=$false; Detail=$null } }

  $check = $Step.check
  $ctype = $check.type
  if (-not $ctype) { throw "Download: step.check.type is required when check is present." }

  switch ($ctype) {
    'pathExists' {
      $p = $check.path
      if (-not $p) { $p = $DestPath }
      if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $PlanDir $p }
      $ok = Test-Path -LiteralPath $p
      return [pscustomobject]@{ HasCheck=$true; Satisfied=$ok; Detail=("pathExists: " + $p) }
    }
    'fileHashEquals' {
      $expect = $check.sha256
      if (-not $expect) { throw "Download: check.sha256 is required for fileHashEquals." }
      $p = $check.path
      if (-not $p) { $p = $DestPath }
      if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $PlanDir $p }
      if (-not (Test-Path -LiteralPath $p)) { return [pscustomobject]@{ HasCheck=$true; Satisfied=$false; Detail=("fileHashEquals: missing " + $p) } }
      $actual = Get-47Sha256Hex -Path $p
      $ok = ($actual -eq $expect.ToLowerInvariant())
      return [pscustomobject]@{ HasCheck=$true; Satisfied=$ok; Detail=("fileHashEquals: " + $p) }
    }
    default {
      throw "Download: unsupported check.type '$ctype'. Supported: pathExists, fileHashEquals."
    }
  }
}

function Invoke-47DownloadStepInternal {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Context,
    [Parameter(Mandatory)][hashtable]$Plan,
    [Parameter(Mandatory)][hashtable]$Step,
    [Parameter(Mandatory)][ValidateSet('WhatIf','Apply')][string]$Mode
  )

  $dl = $Step.download
  if (-not $dl) { throw "Download: step.download payload is required when type=='download'." }

  $url = $dl.url
  if (-not $url) { throw "Download: download.url is required." }

  $planDir = $Context.PlanDir
  $stepId = if ($Step.stepId) { $Step.stepId } elseif ($Step.id) { $Step.id } else { "step" }
  $stepDir = Join-Path $Context.StepsRoot $stepId
  New-Item -ItemType Directory -Force -Path $stepDir | Out-Null

  $dest = Resolve-47DownloadDestination -Dest $dl.dest -PlanDir $planDir -StepDir $stepDir
  $destDir = Split-Path -Parent $dest
  if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }

  $expected = $null
  if ($dl.sha256) { $expected = ($dl.sha256.ToLowerInvariant()) }

  # Idempotency via check
  $chk = Test-47DownloadCheckSatisfied -Context $Context -Step $Step -PlanDir $planDir -DestPath $dest -Mode $Mode
  if ($chk.HasCheck -and $chk.Satisfied) {
    return [ordered]@{
      status='skipped'
      message=('Download check satisfied (' + $chk.Detail + ').')
      url=$url
      dest=$dest
    }
  }

  $useCache = $true
  if ($null -ne $dl.useCache) { $useCache = [bool]$dl.useCache }

  $overwrite = $false
  if ($null -ne $dl.overwrite) { $overwrite = [bool]$dl.overwrite }

  $cache = Get-47DownloadCachePath -Context $Context -Url $url -Sha256 $expected -DestPath $dest
  $cachedOk = $false

  if ($useCache -and (Test-Path -LiteralPath $cache.File)) {
    if ($expected) {
      $h = Get-47Sha256Hex -Path $cache.File
      if ($h -ne $expected) {
        # cache poisoned or outdated
        Remove-Item -LiteralPath $cache.File -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $cache.Meta -Force -ErrorAction SilentlyContinue
      } else {
        $cachedOk = $true
      }
    } else {
      $cachedOk = $true
    }
  }

  if ($Mode -eq 'WhatIf') {
    return [ordered]@{
      status='whatif'
      message=('Would download ' + $url + ' -> ' + $dest + (if($useCache){' (cache enabled)'}else{''}))
      url=$url
      dest=$dest
      cacheFile=$cache.File
      expectedSha256=$expected
      cachedHit=$cachedOk
    }
  }

  # Apply
  if ((Test-Path -LiteralPath $dest) -and (-not $overwrite)) {
    # if expected hash matches, treat as satisfied
    if ($expected) {
      $dh = Get-47Sha256Hex -Path $dest
      if ($dh -eq $expected) {
        return [ordered]@{ status='skipped'; message='Destination already present with expected hash.'; url=$url; dest=$dest; sha256=$dh }
      }
    }
    throw "Download: destination exists and overwrite=false: $dest"
  }

  $finalSource = $null
  if ($cachedOk) {
    $finalSource = $cache.File
  }
  else {
    $stageRoot = Join-Path $Context.Paths.StagingRootUser 'downloads'
    $stageRun  = Join-Path $stageRoot $Context.RunId
    New-Item -ItemType Directory -Force -Path $stageRun | Out-Null

    $qDir = Join-Path $stepDir 'quarantine'
    New-Item -ItemType Directory -Force -Path $qDir | Out-Null

    $tmpPath = Join-Path $qDir ('payload' + $cache.Ext)

    $src = Resolve-47DownloadSource -Url $url -PlanDir $planDir
    if ($src.Kind -eq 'LocalPath') {
      Copy-Item -LiteralPath $src.Value -Destination $tmpPath -Force
    } else {
      $headers = @{}
      if ($dl.headers) { $headers = $dl.headers }

      $timeout = 60
      if ($dl.timeoutSec) { $timeout = [int]$dl.timeoutSec }

      $iwr = Get-Command Invoke-WebRequest -ErrorAction Stop
      $params = @{
        Uri = $src.Value
        OutFile = $tmpPath
        Headers = $headers
        ErrorAction = 'Stop'
      }
      if ($iwr.Parameters.ContainsKey('TimeoutSec')) { $params.TimeoutSec = $timeout }
      if ($iwr.Parameters.ContainsKey('UseBasicParsing')) { $params.UseBasicParsing = $true }

      Invoke-WebRequest @params | Out-Null
    }

    $actual = Get-47Sha256Hex -Path $tmpPath
    if ($expected -and ($actual -ne $expected)) {
      throw "Download: SHA256 mismatch. Expected $expected, got $actual."
    }

    if ($useCache) {
      Copy-Item -LiteralPath $tmpPath -Destination $cache.File -Force
      $meta = [ordered]@{
        url=$url
        cachedAtUtc=[DateTime]::UtcNow.ToString('o')
        sha256=$actual
        size=(Get-Item -LiteralPath $cache.File).Length
      }
      $meta | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $cache.Meta -Encoding utf8
      $finalSource = $cache.File
    } else {
      $finalSource = $tmpPath
    }
  }

  Copy-Item -LiteralPath $finalSource -Destination $dest -Force

  $sha = Get-47Sha256Hex -Path $dest

  # Optional extraction
  $didExtract = $false
  $extractTo = $null
  if ($dl.extract) {
    $extractTo = $dl.extractTo
    if (-not $extractTo) { throw "Download: download.extractTo is required when download.extract is true." }
    if (-not [System.IO.Path]::IsPathRooted($extractTo)) { $extractTo = Join-Path $planDir $extractTo }
    Expand-47ZipSafe -ZipPath $dest -DestinationPath $extractTo
    $didExtract = $true
  }

  return [ordered]@{
    status='ok'
    message='Download completed.'
    url=$url
    dest=$dest
    sha256=$sha
    cacheFile=(if($useCache){$cache.File}else{$null})
    cachedHit=$cachedOk
    extracted=$didExtract
    extractTo=$extractTo
  }
}

function Register-47DownloadStepExecutor {
  [CmdletBinding()]
  param([Parameter(Mandatory)][hashtable]$Context)

  $executor = {
    param($ctx,$plan,$step,$mode)
    return (Invoke-47DownloadStepInternal -Context $ctx -Plan $plan -Step $step -Mode $mode)
  }

  Register-47StepExecutor -Context $Context -Type 'download' -Executor $executor
}

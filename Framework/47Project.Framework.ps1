param(
  [switch]$SafeMode
)

if ($SafeMode) { $env:P47_SAFE_MODE = '1' }

function Show-47OutputViewer {
  param(
    [string]$Title = 'Output',
    [string]$StdOut = '',
    [string]$StdErr = ''
  )
  try {
    $w = New-Object System.Windows.Window
    $w.Title = $Title
    $w.Width = 820
    $w.Height = 520
    $w.WindowStartupLocation = 'CenterOwner'
    try { $w.Owner = $win } catch { }

    $grid = New-Object System.Windows.Controls.Grid
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='*' })) | Out-Null
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='Auto' })) | Out-Null

    $tabs = New-Object System.Windows.Controls.TabControl

    $tab1 = New-Object System.Windows.Controls.TabItem
    $tab1.Header = 'StdOut'
    $tb1 = New-Object System.Windows.Controls.TextBox
    $tb1.Text = $StdOut
    $tb1.AcceptsReturn = $true
    $tb1.AcceptsTab = $true
    $tb1.VerticalScrollBarVisibility = 'Auto'
    $tb1.HorizontalScrollBarVisibility = 'Auto'
    $tb1.IsReadOnly = $true
    $tab1.Content = $tb1

    $tab2 = New-Object System.Windows.Controls.TabItem
    $tab2.Header = 'StdErr'
    $tb2 = New-Object System.Windows.Controls.TextBox
    $tb2.Text = $StdErr
    $tb2.AcceptsReturn = $true
    $tb2.AcceptsTab = $true
    $tb2.VerticalScrollBarVisibility = 'Auto'
    $tb2.HorizontalScrollBarVisibility = 'Auto'
    $tb2.IsReadOnly = $true
    $tab2.Content = $tb2

    $tabs.Items.Add($tab1) | Out-Null
    $tabs.Items.Add($tab2) | Out-Null

    [System.Windows.Controls.Grid]::SetRow($tabs,0)
    $grid.Children.Add($tabs) | Out-Null

    $btns = New-Object System.Windows.Controls.WrapPanel
    $btns.Margin = '10'
    $bCopy = New-Object System.Windows.Controls.Button
    $bCopy.Content = 'Copy StdOut'
    $bCopy.Margin = '0,0,8,0'
    $bCopy.Add_Click({ try { [System.Windows.Clipboard]::SetText($tb1.Text) } catch { } })
    $bCopy2 = New-Object System.Windows.Controls.Button
    $bCopy2.Content = 'Copy StdErr'
    $bCopy2.Add_Click({ try { [System.Windows.Clipboard]::SetText($tb2.Text) } catch { } })
    $bClose = New-Object System.Windows.Controls.Button
    $bClose.Content = 'Close'
    $bClose.Margin = '10,0,0,0'
    $bClose.Add_Click({ $w.Close() })

    $btns.Children.Add($bCopy) | Out-Null
    $btns.Children.Add($bCopy2) | Out-Null
    $btns.Children.Add($bClose) | Out-Null
    [System.Windows.Controls.Grid]::SetRow($btns,1)
    $grid.Children.Add($btns) | Out-Null

    $w.Content = $grid
    $w.ShowDialog() | Out-Null
  } catch { }
}

  $script:SplashWin = Show-47Splash -Title ('47Project Framework ' + (Get-47PackVersion)) -Subtitle 'Initializing UI...'


function Get-47SupportInfoText {
  try {
    $st = Get-47HostStatus
    $v = Get-47PackVersion
    $d = Get-47PackDate
    $paths = $null
    try { $paths = Get-47Paths } catch { }

    $lines = @()
    $lines += "47Project Framework Support Info"
    $lines += ("Version: " + $v + " (" + $d + ")")
    $lines += ("OS: " + [System.Environment]::OSVersion.VersionString)
    $lines += ("IsWindows: " + $st.IsWindows + "  IsAdmin: " + $st.IsAdmin)
    $lines += ("PowerShell: " + $PSVersionTable.PSVersion.ToString())
    $lines += ("WPF: " + $st.WpfAvailable)
    $lines += ("SafeMode: " + (Get-47SafeMode))
    if ($paths) { $lines += ("DataRoot: " + $paths.DataRoot) }
    $lines += ("Time: " + (Get-Date).ToString("s"))
    return ($lines -join "`r`n")
  } catch {
    return ("Support info failed: " + $_.Exception.Message)
  }
}

function Copy-47SupportInfo {
  try {
    $txt = Get-47SupportInfoText
    try { [System.Windows.Clipboard]::SetText($txt) } catch { }
    return $txt
  } catch { return $null }
}

<#
  
$pages['Activity'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    
    # Dashboard blocks (state)
    $dash = New-Object System.Windows.Controls.StackPanel
    $dash.Margin = '0,0,0,10'

    $tTest = New-Object System.Windows.Controls.TextBlock
    $tTest.Foreground = $fg
    $tRelease = New-Object System.Windows.Controls.TextBlock
    $tRelease.Foreground = $fg
    $tVerify = New-Object System.Windows.Controls.TextBlock
    $tVerify.Foreground = $fg

    $dash.Children.Add($tTest) | Out-Null
    $dash.Children.Add($tRelease) | Out-Null
    $dash.Children.Add($tVerify) | Out-Null

$tb = New-Object System.Windows.Controls.TextBox
    $tb.AcceptsReturn = $true
    $tb.AcceptsTab = $true
    $tb.VerticalScrollBarVisibility = 'Auto'
    $tb.HorizontalScrollBarVisibility = 'Auto'
    $tb.IsReadOnly = $true
    $tb.Height = 340
    $tb.Background = $panel
    $tb.Foreground = $fg
    $tb.BorderBrush = $accent
    $tb.BorderThickness = '1'
    function Append-47ActivityLine {
      param([string]$Line)
      try {
        if ($null -eq $Line) { return }
        $tb.Dispatcher.Invoke([action]{
          $tb.AppendText(($Line + "`r`n"))
          $tb.ScrollToEnd()
        }) | Out-Null
      } catch { }
    }

    function Invoke-47ActivityTool {
      param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$ToolName,
        [hashtable]$Args = @{}
      )

      GuiRun $Title {
        Append-47ActivityLine ("=== " + $Title + " ===")
        $rootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        $toolPath = Join-Path (Join-Path $rootPath 'tools') $ToolName
        if (-not (Test-Path -LiteralPath $toolPath)) { throw ("Tool not found: " + $toolPath) }

        $argList = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $toolPath)
        foreach ($k in $Args.Keys) {
          $v = $Args[$k]
          if ($v -is [bool]) {
            if ($v) { $argList += ("-" + $k) }
          } elseif ($null -ne $v -and -not [string]::IsNullOrWhiteSpace([string]$v)) {
            $argList += ("-" + $k)
            $argList += [string]$v
          }
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'pwsh'
        $psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi

        $p.add_OutputDataReceived({
          if ($_.Data) { Append-47ActivityLine $_.Data }
        })
        $p.add_ErrorDataReceived({
          if ($_.Data) { Append-47ActivityLine ("[err] " + $_.Data) }
        })

        [void]$p.Start()
        $p.BeginOutputReadLine()
        $p.BeginErrorReadLine()
        $p.WaitForExit()

        Append-47ActivityLine ("=== ExitCode: " + $p.ExitCode + " ===")
        & $refresh
      }
    }


    $refresh = {
      try {
        # State dashboard
        $lt = Get-47StateRecord -Name 'last_test'
        if ($lt) {
          $tTest.Text = ("Last tests: {0} (ok={1}) passed={2} failed={3} skipped={4}" -f $lt.timestamp, $lt.ok, $lt.passedCount, $lt.failedCount, $lt.skippedCount)
        } else {
          $tTest.Text = "Last tests: (none)"
        }

        $lr = Get-47StateRecord -Name 'last_release'
        if ($lr) {
          $tRelease.Text = ("Last release: {0} tag={1} signed={2}" -f $lr.timestamp, $lr.tag, $lr.signed)
        } else {
          $tRelease.Text = "Last release: (none)"
        }

        $lv = Get-47StateRecord -Name 'last_verify'
        if ($lv) {
          $tVerify.Text = ("Last verify: {0} (ok={1})" -f $lv.timestamp, $lv.ok)
        } else {
          $tVerify.Text = "Last verify: (none)"
        }

        # Log tail
        $paths = Get-47Paths
        $lp = Join-Path $paths.LogsRootUser 'framework.log'
        if (Test-Path -LiteralPath $lp) {
          $lines = Get-Content -LiteralPath $lp -Tail 400
          $tb.Text = ($lines -join "`r`n")
        } else {
          $tb.Text = ('No log yet: ' + $lp)
        }
      } catch {
        $tb.Text = $_.Exception.Message
      }
    }

    $root.Children.Add((New-47Card 'Activity' 'Recent framework activity (tail of framework.log).' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add((New-47Button 'Refresh' { & $refresh })) | Out-Null
      # Quick actions
      $row = New-Object System.Windows.Controls.WrapPanel
      $row.Margin = '0,10,0,10'

      $btnTests = New-Object System.Windows.Controls.Button
      $btnTests.Content = 'Run Tests'
      $btnTests.Margin = '0,0,8,0'
      $btnTests.Add_Click({ Invoke-47ActivityTool -Title 'Run Tests' -ToolName 'Invoke-47Tests.ps1' -Args @{ CI=$false } })

      $btnRelease = New-Object System.Windows.Controls.Button
      $btnRelease.Content = 'Build Offline Release'
      $btnRelease.Margin = '0,0,8,0'
      $btnRelease.Add_Click({ Invoke-47ActivityTool -Title 'Build Offline Release' -ToolName 'release_build.ps1' -Args @{} })

      $btnVerifyLast = New-Object System.Windows.Controls.Button
      $btnVerifyLast.Content = 'Verify Last Release'
      $btnVerifyLast.Margin = '0,0,8,0'
      $btnVerifyLast.Add_Click({
        GuiRun 'Verify Last Release' {
          $lr = Get-47StateRecord -Name 'last_release'
          if (-not $lr -or -not $lr.zipPath) { throw 'No last_release recorded yet. Build a release first.' }
          Invoke-47ActivityTool -Title 'Verify Offline Zip' -ToolName 'release_verify_offline.ps1' -Args @{ ZipPath = [string]$lr.zipPath }
        }
      })

      $row.Children.Add($btnTests) | Out-Null
      $row.Children.Add($btnRelease) | Out-Null
      $row.Children.Add($btnVerifyLast) | Out-Null
      $btnCopy = New-Object System.Windows.Controls.Button
      $btnCopy.Content = 'Copy output'
      $btnCopy.Margin = '0,0,8,0'
      $btnCopy.Add_Click({ try { [System.Windows.Clipboard]::SetText($tb.Text) | Out-Null; Show-47GuiMessage 'Copied.' } catch { } })
      $row.Children.Add($btnCopy) | Out-Null

      # Verify custom zip
      $zipRow = New-Object System.Windows.Controls.WrapPanel
      $zipRow.Margin = '0,0,0,10'
      $zipBox = New-Object System.Windows.Controls.TextBox
      $zipBox.MinWidth = 420
      $zipBox.Background = $panel
      $zipBox.Foreground = $fg
      $zipBox.BorderBrush = $accent
      $zipBox.BorderThickness = '1'

      $btnBrowseZip = New-Object System.Windows.Controls.Button
      $btnBrowseZip.Content = 'Browse zip'
      $btnBrowseZip.Margin = '8,0,0,0'
      $btnBrowseZip.Add_Click({
        try {
          $dlg = New-Object Microsoft.Win32.OpenFileDialog
          $dlg.Filter = 'Zip files (*.zip)|*.zip|All files (*.*)|*.*'
          if ($dlg.ShowDialog()) { $zipBox.Text = $dlg.FileName }
        } catch { }
      })

      $keyBox = New-Object System.Windows.Controls.TextBox
      $keyBox.MinWidth = 420
      $keyBox.Margin = '0,6,0,0'
      $keyBox.Background = $panel
      $keyBox.Foreground = $fg
      $keyBox.BorderBrush = $accent
      $keyBox.BorderThickness = '1'

      $btnBrowseKey = New-Object System.Windows.Controls.Button
      $btnBrowseKey.Content = 'Browse public key'
      $btnBrowseKey.Margin = '8,6,0,0'
      $btnBrowseKey.Add_Click({
        try {
          $dlg = New-Object Microsoft.Win32.OpenFileDialog
          $dlg.Filter = 'XML files (*.xml)|*.xml|All files (*.*)|*.*'
          if ($dlg.ShowDialog()) { $keyBox.Text = $dlg.FileName }
        } catch { }
      })

      $btnVerify = New-Object System.Windows.Controls.Button
      $btnVerify.Content = 'Verify Selected'
      $btnVerify.Margin = '8,0,0,0'
      $btnVerify.Add_Click({
        $zp = $zipBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($zp)) { Show-47GuiMessage 'Select a zip first.'; return }
        $kp = $keyBox.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($kp)) {
          Invoke-47ActivityTool -Title 'Verify Offline Zip' -ToolName 'release_verify_offline.ps1' -Args @{ ZipPath=$zp }
        } else {
          Invoke-47ActivityTool -Title 'Verify Offline Zip' -ToolName 'release_verify_offline.ps1' -Args @{ ZipPath=$zp; PublicKeyPath=$kp }
        }
      })

      $zipRow.Children.Add($zipBox) | Out-Null
      $zipRow.Children.Add($btnBrowseZip) | Out-Null
      $zipRow.Children.Add($btnVerify) | Out-Null

      $sp.Children.Add($row) | Out-Null
      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='Verify offline zip (optional public key below)'; Foreground=$muted })) | Out-Null
      $sp.Children.Add($zipRow) | Out-Null

      $keyRow = New-Object System.Windows.Controls.WrapPanel
      $keyRow.Margin = '0,0,0,10'
      $keyRow.Children.Add($keyBox) | Out-Null
      $keyRow.Children.Add($btnBrowseKey) | Out-Null
      $sp.Children.Add($keyRow) | Out-Null

      $sp.Children.Add($dash) | Out-Null
      $sp.Children.Add($tb) | Out-Null
      $sp.Children.Add((New-47Button 'Open logs folder' {
        try { $paths = Get-47Paths; Start-Process $paths.LogsRootUser | Out-Null } catch { }
      })) | Out-Null
      return $sp
    })) | Out-Null

    & $refresh
    return $root
  }



$pages['Update Center'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Update Center' 'Maintenance, verification, and quality tools.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $btnVerifyPack = New-Object System.Windows.Controls.Button
      $btnVerifyPack.Content = 'Verify current pack (if _integrity exists)'
      $btnVerifyPack.Margin = '0,0,0,8'
      $btnVerifyPack.Add_Click({ Invoke-47GuiToolCapture -Title 'Verify Current Pack' -ToolName 'verify_current_pack.ps1' -Args @{} -ShowViewer })

      $btnPester = New-Object System.Windows.Controls.Button
      $btnPester.Content = 'Verify vendored Pester'
      $btnPester.Margin = '0,0,0,8'
      $btnPester.Add_Click({ Invoke-47GuiToolCapture -Title 'Verify vendored Pester' -ToolName 'verify_vendor_pester.ps1' -Args @{} -ShowViewer })

      $btnLint = New-Object System.Windows.Controls.Button
      $btnLint.Content = 'Lint modules'
      $btnLint.Margin = '0,0,0,8'
      $btnLint.Add_Click({ Invoke-47GuiToolCapture -Title 'Lint modules' -ToolName 'lint_modules.ps1' -Args @{} -ShowViewer })

      $btnIndex = New-Object System.Windows.Controls.Button
      $btnIndex.Content = 'Build module index (modules/index.json)'
      $btnIndex.Margin = '0,0,0,8'
      $btnIndex.Add_Click({ Invoke-47GuiToolCapture -Title 'Build module index' -ToolName 'build_module_index.ps1' -Args @{} -ShowViewer })

      $btnDoctor = New-Object System.Windows.Controls.Button
      $btnDoctor.Content = 'Run Doctor'
      $btnDoctor.Margin = '0,0,0,8'
      $btnDoctor.Add_Click({ Invoke-47GuiToolCapture -Title 'Run Doctor' -ToolName 'Invoke-47Doctor.ps1' -Args @{} -ShowViewer })

      $btnHistory = New-Object System.Windows.Controls.Button
      $btnHistory.Content = 'Open run history (history.jsonl)'
      $btnHistory.Margin = '0,0,0,8'
      $btnHistory.Add_Click({
        try {
          $paths = Get-47Paths
          $p = Join-Path $paths.LogsRootUser 'history.jsonl'
          if (Test-Path -LiteralPath $p) { Start-Process $p | Out-Null } else { Show-47GuiMessage 'No history yet.' }
        } catch { }
      })

            $sp.Children.Add($btnChecklist) | Out-Null
      $sp.Children.Add($btnTag) | Out-Null
$sp.Children.Add($btnVerifyPack) | Out-Null
      $sp.Children.Add($btnPester) | Out-Null
      $sp.Children.Add($btnLint) | Out-Null
      $sp.Children.Add($btnIndex) | Out-Null
      $sp.Children.Add($btnDoctor) | Out-Null
      $sp.Children.Add($btnHistory) | Out-Null

      
      $btnChecklist = New-Object System.Windows.Controls.Button
      $btnChecklist.Content = 'Run release checklist'
      $btnChecklist.Margin = '0,0,0,8'
      $btnChecklist.Add_Click({ Invoke-47GuiToolCapture -Title 'Release checklist' -ToolName 'release_checklist.ps1' -Args @{} -ShowViewer })

      $btnTag = New-Object System.Windows.Controls.Button
      $btnTag.Content = 'Create git tag (after checklist)'
      $btnTag.Margin = '0,0,0,8'
      $btnTag.Add_Click({
        try {
          $dlg = New-Object System.Windows.Controls.InputDialog
        } catch { }
        # simple input via prompt
        try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue } catch { }
        $tag = [Microsoft.VisualBasic.Interaction]::InputBox('Enter tag (e.g., v39)', 'Create tag', '')
        if ([string]::IsNullOrWhiteSpace($tag)) { return }
        Invoke-47GuiToolCapture -Title ('Tag release ' + $tag) -ToolName 'tag_release.ps1' -Args @{ Tag=$tag } -ShowViewer
      })

return $sp
    })) | Out-Null

    return $root
  }

$pages['Store'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Local Module Store' 'Browse modules/index.json (local registry).' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $list = New-Object System.Windows.Controls.ListBox
      $list.Height = 280
      $list.Background = $panel
      $list.Foreground = $fg
      $list.BorderBrush = $accent
      $list.BorderThickness = '1'

      $refresh = {
        $list.Items.Clear()
        $idxPath = Join-Path (Get-47Paths).PackRoot 'modules/index.json'
        $installed = @{}
        foreach ($m in @(Get-47Modules)) {
          try { $installed[$m.ModuleId] = $m } catch { }
        }

        if (-not (Test-Path -LiteralPath $idxPath)) {
          $list.Items.Add('No modules/index.json yet. Click "Build index".') | Out-Null
          return
        }

        $idx = Get-Content -Raw -LiteralPath $idxPath | ConvertFrom-Json
        foreach ($m in @($idx.modules)) {
          $id = [string]$m.moduleId
          $name = [string]$m.name
          $ver = [string]$m.version

          $status = 'not installed'
          $instVer = ''
          $upd = $false
          if ($installed.ContainsKey($id)) {
            $status = 'installed'
            try { $instVer = [string]$installed[$id].Version } catch { }
            try {
              $vIdx = [version]$ver
              $vInst = [version]$instVer
              if ($vIdx -gt $vInst) { $upd = $true }
            } catch { }
          }

          $tag = if ($upd) { 'UPDATE available' } elseif ($status -eq 'installed') { 'installed' } else { 'not installed' }
          $disp = ("{0} — {1} ({2}) [{3}]" -f $id, $name, $ver, $tag)
          $list.Items.Add($disp) | Out-Null
        }
      }

      $btnBuild = New-Object System.Windows.Controls.Button
      $btnBuild.Content = 'Build index'
      $btnBuild.Margin = '0,0,0,8'
      $btnBuild.Add_Click({
        GuiRun 'Build module index' {
          Invoke-47Tool -Name 'build_module_index.ps1' -Args @{} | Out-Null
          & $refresh
          Show-47GuiMessage 'modules/index.json built.'
        }
      })

      
      $btnInstall = New-Object System.Windows.Controls.Button
      $btnInstall.Content = 'Install/Update selected'
      $btnInstall.Margin = '0,6,0,0'
      $btnInstall.Add_Click({
        GuiRun 'Install/Update module' {
          $txt = [string]$list.SelectedItem
          if ([string]::IsNullOrWhiteSpace($txt)) { throw 'Select a module in the list.' }
          $id = $txt.Split('—')[0].Trim()
          Import-47Module -Id $id | Out-Null
          & $refresh
          Show-47GuiMessage ('Installed/updated: ' + $id)
        }
      })

      $btnOpenModule = New-Object System.Windows.Controls.Button
      $btnOpenModule.Content = 'Open module folder'
      $btnOpenModule.Margin = '0,6,0,0'
      $btnOpenModule.Add_Click({
        try {
          $txt = [string]$list.SelectedItem
          if ([string]::IsNullOrWhiteSpace($txt)) { Show-47GuiMessage 'Select a module.'; return }
          $id = $txt.Split('—')[0].Trim()
          $m = Get-47Modules | Where-Object { $_.ModuleId -eq $id } | Select-Object -First 1
          if ($m -and $m.Path) { Start-Process $m.Path | Out-Null } else { Show-47GuiMessage 'Module not imported yet.' }
        } catch { }
      })

$btnImport = New-Object System.Windows.Controls.Button
      $btnImport.Content = 'Import selected by Id'
      $btnImport.Margin = '0,6,0,0'
      $btnImport.Add_Click({
        GuiRun 'Import module' {
          $txt = [string]$list.SelectedItem
          if ([string]::IsNullOrWhiteSpace($txt)) { throw 'Select a module in the list.' }
          $id = $txt.Split('—')[0].Trim()
          Import-47Module -Id $id | Out-Null
          Show-47GuiMessage ('Imported: ' + $id)
        }
      })

      $sp.Children.Add($btnBuild) | Out-Null
      $sp.Children.Add($list) | Out-Null
      $sp.Children.Add($btnInstall) | Out-Null
      $sp.Children.Add($btnImport) | Out-Null
      $sp.Children.Add($btnOpenModule) | Out-Null

      & $refresh
      return $sp
    })) | Out-Null

    return $root
  }

$pages['Search'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Global search' 'Search modules, apps, and plans.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $q = New-Object System.Windows.Controls.TextBox
      $q.MinWidth = 420
      $q.Background = $panel
      $q.Foreground = $fg
      $q.BorderBrush = $accent
      $q.BorderThickness = '1'

      $list = New-Object System.Windows.Controls.ListBox
      $list.Height = 280
      $list.Background = $panel
      $list.Foreground = $fg
      $list.BorderBrush = $accent
      $list.BorderThickness = '1'
      $list.Margin = '0,10,0,0'

      $do = {
        $list.Items.Clear()
        $term = $q.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($term)) { return }

        foreach ($m in @(Get-47Modules | Where-Object { $_.Name -like "*$term*" -or $_.ModuleId -like "*$term*" })) {
          $list.Items.Add(("Module: {0} — {1} ({2})" -f $m.ModuleId,$m.Name,$m.Version)) | Out-Null
        }
        foreach ($a in @(Get-47AppCatalog | Where-Object { $_.DisplayName -like "*$term*" -or $_.Id -like "*$term*" })) {
          $list.Items.Add(("App: {0} — {1}" -f $a.Id,$a.DisplayName)) | Out-Null
        }
        try {
          $plans = Join-Path (Get-47Paths).PackRoot 'plans'
          if (Test-Path -LiteralPath $plans) {
            Get-ChildItem -File -Recurse -LiteralPath $plans -Filter *.json | Where-Object { $_.Name -like "*$term*" } | ForEach-Object {
              $list.Items.Add(("Plan: " + $_.FullName)) | Out-Null
            }
          }
        } catch { }
      }

      $q.Add_TextChanged({ & $do })
      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='Type to search'; Foreground=$muted })) | Out-Null
      $sp.Children.Add($q) | Out-Null
      $sp.Children.Add($list) | Out-Null
      return $sp
    })) | Out-Null

    return $root
  }

$pages['About'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card '47Project Framework' 'Nexus shell for the Project47 toolset.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $v = (Get-47PackVersion)
      $d = (Get-47PackDate)

      $t1 = New-Object System.Windows.Controls.TextBlock
      $t1.Text = ("Version: " + $v + "  (" + $d + ")")
      $t1.Foreground = $fg
      $t1.Margin = '0,0,0,6'
      $sp.Children.Add($t1) | Out-Null

      $t2 = New-Object System.Windows.Controls.TextBlock
      $t2.Text = "No telemetry. Offline-first. Use Safe Mode for demos."
      $t2.Foreground = $muted
      $t2.TextWrapping = 'Wrap'
      $sp.Children.Add($t2) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'

      $btns.Children.Add((New-47Button 'Open Docs Index' {
        try {
          $root2 = Get-47ProjectRoot
          $p = Join-Path $root2 'docs\\INDEX.md'
          if (Test-Path -LiteralPath $p) { Start-Process $p | Out-Null } else { Show-47GuiMessage 'docs/INDEX.md not found.' }
        } catch { }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open Privacy' {
        try {
          $root2 = Get-47ProjectRoot
          $p = Join-Path $root2 'PRIVACY.md'
          if (Test-Path -LiteralPath $p) { Start-Process $p | Out-Null } else { Show-47GuiMessage 'PRIVACY.md not found.' }
        } catch { }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Build Support Bundle' {
        try {
          GuiRun 'Support bundle' { Export-SupportBundle }
        } catch { }
      })) | Out-Null


            $btns.Children.Add((New-47Button 'Copy Support Info' {
        try {
          $t = Copy-47SupportInfo
          if ($t) { Show-47GuiMessage 'Copied support info to clipboard.' }
        } catch { }
      })) | Out-Null

$btns.Children.Add((
      $btns.Children.Add((New-47Button 'Build Docs (HTML)' {
        try {
          $root2 = Get-47ProjectRoot
          $p = Join-Path $root2 'tools\\build_docs.ps1'
          if (Test-Path -LiteralPath $p) {
            GuiRun 'Build docs' { & $p -Root $root2 }
            Show-47GuiMessage 'Docs built to docs/site.'
          } else { Show-47GuiMessage 'build_docs.ps1 not found.' }
        } catch { }
      })) | Out-Null

New-47Button 'Verify Manifest' {
        try {
          $root2 = Get-47ProjectRoot
          $p = Join-Path $root2 'tools\\verify_manifest.ps1'
          if (Test-Path -LiteralPath $p) { GuiRun 'Verify manifest' { & $p -Root $root2 } } else { Show-47GuiMessage 'verify_manifest.ps1 not found.' }
        } catch { }
      })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null

    return $root
  }


.SYNOPSIS
  47Project Framework - Nexus Shell (CLI)

.DESCRIPTION
  Docs: see docs/INDEX.md

  Minimal CLI shell for the 47Project Framework pack.
  Keeps the bootstrap flow stable:
    - Strict mode
    - Import core module
    - First-run wizard (creates default config/policy when missing)

  Then exposes a command-registry-driven menu with validated input handling.

.PARAMETER Help
  Show help/usage and exit.

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Menu

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Command 4 -PlanPath .\examples\plans\sample_install.plan.json -Json

.EXAMPLE
  pwsh -NoLogo -File Framework/47Project.Framework.ps1 -Command 6 -PlanPath .\my.plan.json -Force -Json

$script:JsonMode = [bool]$Json
$script:NonInteractive = [bool](-not [string]::IsNullOrWhiteSpace($Command))

$script:CliArgs = @{
  PlanPath      = $PlanPath
  PolicyPath    = $PolicyPath
  ModuleId      = $ModuleId
  SnapshotIndex = $SnapshotIndex
  SnapshotPath  = $SnapshotPath
  SnapshotName  = $SnapshotName
  OutPath       = $OutPath
  NewModuleId   = $NewModuleId
  DisplayName   = $DisplayName
  Description   = $Description
  Force         = [bool]$Force
}

function Get-47CliArg {
  param([Parameter(Mandatory)][string]$Name, $Default = $null)
  if ($script:CliArgs.ContainsKey($Name)) {
    $v = $script:CliArgs[$Name]
    if ($null -ne $v) {
      if ($v -is [string]) {
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v }
      } else {
        return $v
      }
    }
  }
  return $Default
}

function Write-47Json {
  param([Parameter(Mandatory)]$Object, [int]$Depth = 16)
  ($Object | ConvertTo-Json -Depth $Depth)
}

function Get-47MenuModel {
  param([hashtable]$Registry)
  $Registry.Values | Sort-Object Order, Key | ForEach-Object {
    [pscustomobject]@{ key=$_.Key; label=$_.Label; category=$_.Category; order=$_.Order }
  }
}

function Invoke-47CommandKey {
  param([Parameter(Mandatory)][string]$Key)
  if ($Key -eq '0') { return $null }
  $cmd = $script:CommandRegistry[$Key]
  if (-not $cmd) { throw "Unknown command key: $Key" }
  & $cmd.Handler
}



.PARAMETER Menu
  Print the current menu/command map and exit (useful for non-interactive invocation).

.PARAMETER Command
  Run a single command by key and exit (e.g., -Command 1, -Command b).

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Menu

.EXAMPLE
  pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command 4
#>

[CmdletBinding()]
param(
  [switch]$Help,
  [switch]$Menu,
  [string]$Command,

  # GUI behavior (Windows only)
  [switch]$Gui,
  [switch]$NoGui,

  # Common passthrough args for non-interactive use (-Command)
  [string]$PlanPath,
  [string]$PolicyPath,
  [string]$ModuleId,
  [int]$SnapshotIndex,
  [string]$SnapshotPath,
  [string]$SnapshotName,
  [string]$OutPath,
  [string]$NewModuleId,
  [string]$DisplayName,
  [string]$Description,

  [switch]$Force,
  [switch]$Json
)


Set-StrictMode -Version Latest
if ($SafeMode) { $env:P47_SAFE_MODE = '1' }
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module -Force (Join-Path $here 'Core\47.Core.psd1')

# First-run setup (creates default config/policy if missing)
try { Invoke-47FirstRunWizard | Out-Null } catch { Write-Warning $_ }

#region Helpers
function Write-47Banner {
  Write-Host ''
  Write-Host '47Project Framework (Nexus Shell)'
  Write-Host '--------------------------------'
  Write-Host ("Framework: {0}" -f (Get-47FrameworkRoot))
  Write-Host ("PackRoot : {0}" -f (Get-47PackRoot))
  Write-Host ''
}

function Get-47ToolPath {
  param([Parameter(Mandatory)][string]$Name)
  $paths = Get-47Paths
  $p = Join-Path $paths.ToolsRoot $Name
  if (-not (Test-Path -LiteralPath $p)) { throw "Tool not found: $Name ($p)" }
  $p
}

function Invoke-47GuiToolCapture {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$ToolName,
    [hashtable]$Args = @{},
    [switch]$ShowViewer
  )

  GuiRun $Title {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $rootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $toolPath = Join-Path (Join-Path $rootPath 'tools') $ToolName
    if (-not (Test-Path -LiteralPath $toolPath)) { throw ("Tool not found: " + $toolPath) }

    $paths = $null
    try { $paths = Get-47Paths } catch { }
    $capRoot = if ($paths) { $paths.CapturesRootUser } else { Join-Path $rootPath 'captures' }
    if (-not (Test-Path -LiteralPath $capRoot)) { New-Item -ItemType Directory -Force -Path $capRoot | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_ffff'
    $out = Join-Path $capRoot ("tool_" + $ToolName.Replace('.','_') + "_" + $stamp + "_stdout.txt")
    $err = Join-Path $capRoot ("tool_" + $ToolName.Replace('.','_') + "_" + $stamp + "_stderr.txt")

    $argList = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', $toolPath)
    foreach ($k in $Args.Keys) {
      $v = $Args[$k]
      if ($v -is [bool]) { if ($v) { $argList += ("-" + $k) } }
      elseif ($null -ne $v -and -not [string]::IsNullOrWhiteSpace([string]$v)) { $argList += ("-" + $k); $argList += [string]$v }
    }

    $pw = 'pwsh'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $pw
    $psi.Arguments = ($argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    # ensure files exist
    '' | Set-Content -LiteralPath $out -Encoding utf8
    '' | Set-Content -LiteralPath $err -Encoding utf8

    [void]$p.Start()
    $p.StandardOutput.ReadToEndAsync().ContinueWith([action[object]]{ param($t) try { $t.Result | Add-Content -LiteralPath $out -Encoding utf8 } catch { } }) | Out-Null
    $p.StandardError.ReadToEndAsync().ContinueWith([action[object]]{ param($t) try { $t.Result | Add-Content -LiteralPath $err -Encoding utf8 } catch { } }) | Out-Null
    $p.WaitForExit()

    $sw.Stop()
    try {
      $ctx = Get-47Context
      Write-47RunHistory -Kind 'tool' -Id $ToolName -Context $ctx -Ok ($p.ExitCode -eq 0) -ExitCode ([int]$p.ExitCode) -DurationMs ([int]$sw.ElapsedMilliseconds) -StdOutPath $out -StdErrPath $err
    } catch { }


    if ($ShowViewer) {
      try { Show-47OutputViewer -Title $Title -StdOutPath $out -StdErrPath $err } catch { }
    }
  }
}

function Invoke-47Tool {
  param(
    [Parameter(Mandatory)][string]$Name,
    [hashtable]$Args = @{}
  )
  $p = Get-47ToolPath -Name $Name
  & $p @Args
}

function Read-47Choice {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [Parameter(Mandatory)][string[]]$Valid,
    [string]$Default = $null
  )
  while ($true) {
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $raw = Read-Host ("{0}{1}" -f $Prompt, $suffix)
    $val = if ([string]::IsNullOrWhiteSpace($raw)) { $Default } else { $raw.Trim() }
    if ($null -eq $val) { continue }
    if ($val -in $Valid) { return $val }
    Write-Warning ("Invalid selection. Valid: {0}" -f ($Valid -join ', '))
  }
}

function Read-47Path {
  param(
    [Parameter(Mandatory)][string]$Prompt,
    [string]$Default = $null,
    [switch]$MustExist
  )
  while ($true) {
    $suffix = if ($Default) { " [$Default]" } else { "" }
    $p = Read-Host ("{0}{1}" -f $Prompt, $suffix)
    $p = if ([string]::IsNullOrWhiteSpace($p)) { $Default } else { $p.Trim('"').Trim() }
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if ($MustExist -and -not (Test-Path -LiteralPath $p)) {
      Write-Warning "Path not found: $p"
      continue
    }
    return $p
  }
}

function Confirm-47 {
  param([Parameter(Mandatory)][string]$Message, [switch]$DefaultNo)
  $valid = @('y','n','Y','N')
  $def = if ($DefaultNo) { 'n' } else { 'y' }
  $ans = Read-47Choice -Prompt ("{0} (y/n)" -f $Message) -Valid $valid -Default $def
  return ($ans.ToLowerInvariant() -eq 'y')
}

function Write-47Menu {
  param([hashtable]$Registry)

  Write-Host 'Commands'
  Write-Host '--------'

  $items = $Registry.Values | Sort-Object Order, Key
  $groups = $items | Group-Object Category
  foreach ($g in $groups) {
    if ($g.Name) { Write-Host ("[{0}]" -f $g.Name) }
    foreach ($c in $g.Group | Sort-Object Order, Key) {
      Write-Host ("{0}) {1}" -f $c.Key, $c.Label)
    }
    Write-Host ''
  }

  Write-Host '0) Exit'
  Write-Host ''
}

function Register-47Command {
  param(
    [Parameter(Mandatory)][hashtable]$Registry,
    [Parameter(Mandatory)][string]$Key,
    [Parameter(Mandatory)][string]$Label,
    [Parameter(Mandatory)][string]$Category,
    [Parameter(Mandatory)][int]$Order,
    [Parameter(Mandatory)][scriptblock]$Handler
  )
  $Registry[$Key] = [pscustomobject]@{
    Key=$Key; Label=$Label; Category=$Category; Order=$Order; Handler=$Handler
  }
}
#endregion Helpers

#region Tool wrappers (small functions to keep menu handler clean)
function Invoke-Doctor { Invoke-47Tool -Name 'Invoke-47Doctor.ps1' | Out-Null }
function Build-Docs   { Invoke-47Tool -Name 'Build-47Docs.ps1' | Out-Null }
function Style-Check  { Invoke-47Tool -Name 'Invoke-47StyleCheck.ps1' | Out-Null }
function Export-SupportBundle {
  $out = Get-47CliArg -Name 'OutPath' -Default $null
  if (-not $out) {
    $paths = Get-47Paths
    $out = Join-Path $paths.SupportRoot ("support_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
  }
  $res = Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath=$out }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; outPath=$out; result=$res } }
  Write-Host "Support bundle: $out"
}

function Plan-Validate {
  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt 'Plan file to validate' -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $v = Invoke-47Tool -Name 'Validate-47Plan.ps1' -Args @{ PlanPath=$plan }
  $hash = $null
  try { $hash = Invoke-47Tool -Name 'Get-47PlanHash.ps1' -Args @{ PlanPath=$plan } } catch { }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; planPath=$plan; validated=$true; hash=$hash; toolResult=$v } }
  if ($hash) { Write-Host ("Plan hash: {0}" -f $hash) }
}

function Plan-Run {
  param([ValidateSet('WhatIf','Apply')][string]$Mode)

  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt "Plan file to run ($Mode)" -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $policy = Get-47CliArg -Name 'PolicyPath' -Default $null
  if (-not $policy -and -not $script:NonInteractive) {
    $policy = Read-47Path -Prompt 'Policy file [optional]' -Default ''
  }
  if ($policy -and -not (Test-Path -LiteralPath $policy)) { throw "PolicyPath not found: $policy" }

  if ($Mode -eq 'Apply') {
    if ($script:NonInteractive) {
      if (-not (Get-47CliArg -Name 'Force' -Default $false)) {
        throw "Refusing to apply plan non-interactively without -Force."
      }
    } else {
      if (-not (Confirm-47 -Message "Apply plan now? This can modify the system." -DefaultNo)) { return }
    }
  }

  $args = @{ PlanPath=$plan; Mode=$Mode }
  if ($policy) { $args.PolicyPath = $policy }

  $res = Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; mode=$Mode; planPath=$plan; policyPath=$policy; result=$res } }
}

function Policy-ShowEffective {
  $p = Get-47EffectivePolicy
  $p | ConvertTo-Json -Depth 20
}

function Policy-Simulate {
  $paths = Get-47Paths
  $default = Join-Path $paths.ExamplesRoot 'plans\sample_install.plan.json'

  $plan = Get-47CliArg -Name 'PlanPath' -Default $null
  if (-not $plan) {
    $plan = Read-47Path -Prompt 'Plan file to simulate policy against' -Default $default -MustExist
  } else {
    if (-not (Test-Path -LiteralPath $plan)) { throw "PlanPath not found: $plan" }
  }

  $policy = Get-47CliArg -Name 'PolicyPath' -Default $null
  if (-not $policy) {
    $policy = Read-47Path -Prompt 'Policy file [optional]' -Default ''
  }
  $args = @{ PlanPath=$plan }
  if (-not [string]::IsNullOrWhiteSpace($policy)) {
    if (-not (Test-Path -LiteralPath $policy)) { throw "PolicyPath not found: $policy" }
    $args.PolicyPath = $policy
  }

  $res = Invoke-47Tool -Name 'Simulate-47Policy.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; planPath=$plan; policyPath=$policy; result=$res } }
}

function Modules-List {
  Get-47Modules | Select-Object Id, Name, Version, Description | Format-Table -AutoSize
}

function Modules-Import {
  $mods = @(Get-47Modules)
  if (-not $mods -or $mods.Count -eq 0) { Write-Warning 'No modules found.'; return }

  $mods | Select-Object Id, Name, Version | Format-Table -AutoSize

  $id = Get-47CliArg -Name 'ModuleId' -Default $null
  if (-not $id) {
    $id = Read-Host 'Module Id to import'
    $id = $id.Trim()
  } else { $id = $id.Trim() }

  if ([string]::IsNullOrWhiteSpace($id)) { return }
  if (-not ($mods.Id -contains $id)) { throw "Unknown module id: $id" }

  Import-47Module -Id $id | Out-Null
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; moduleId=$id } }
  Write-Host "Imported: $id"
}

function Snapshots-Save {
  $name = Get-47CliArg -Name 'SnapshotName' -Default $null
  $args = @{ IncludePack=$true }
  if ($name) { $args.Name = $name }
  $res = Invoke-47Tool -Name 'Save-47Snapshot.ps1' -Args $args
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; name=$name; result=$res } }
}

function Snapshots-List {
  Invoke-47Tool -Name 'Get-47Snapshots.ps1' | Out-Null
}

function Snapshots-Restore {
  $path = Get-47CliArg -Name 'SnapshotPath' -Default $null
  $ix = Get-47CliArg -Name 'SnapshotIndex' -Default $null

  if ($path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "SnapshotPath not found: $path" }
    if ($script:NonInteractive -and -not (Get-47CliArg -Name 'Force' -Default $false)) {
      throw "Refusing to restore snapshot non-interactively without -Force."
    }
    if (-not $script:NonInteractive) {
      if (-not (Confirm-47 -Message ("Restore snapshot '{0}'?" -f (Split-Path -Leaf $path)) -DefaultNo)) { return }
    }
    $res = Invoke-47Tool -Name 'Restore-47Snapshot.ps1' -Args @{ SnapshotPath=$path; RestorePack=$true; RestoreMachine=$false; Force=$true }
    if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; snapshotPath=$path; result=$res } }
    return
  }

  $snaps = @(Get-47Snapshots)
  if (-not $snaps -or $snaps.Count -eq 0) { Write-Warning 'No snapshots found.'; return }

  $snaps | Select-Object Index, Name, Created, Path | Format-Table -AutoSize

  if ($null -eq $ix) { $ix = Read-Host 'Snapshot index to restore' }
  if (-not ($ix -as [int] -ge 0)) { throw 'Invalid index.' }

  $sel = $snaps | Where-Object { $_.Index -eq [int]$ix } | Select-Object -First 1
  if (-not $sel) { throw "Snapshot not found: $ix" }

  if ($script:NonInteractive -and -not (Get-47CliArg -Name 'Force' -Default $false)) {
    throw "Refusing to restore snapshot non-interactively without -Force."
  }
  if (-not $script:NonInteractive) {
    if (-not (Confirm-47 -Message ("Restore snapshot '{0}'?" -f $sel.Name) -DefaultNo)) { return }
  }

  $res = Invoke-47Tool -Name 'Restore-47Snapshot.ps1' -Args @{ SnapshotPath=$sel.Path; RestorePack=$true; RestoreMachine=$false; Force=$true }
  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; snapshotIndex=[int]$ix; snapshotPath=$sel.Path; result=$res } }
}

function Modules-Scaffold {
  $moduleId = Get-47CliArg -Name 'NewModuleId' -Default $null
  if (-not $moduleId) { $moduleId = Read-Host "ModuleId (e.g. app.foo)" }
  $moduleId = $moduleId.Trim()

  if (-not ($moduleId -match '^[a-z0-9][a-z0-9\.\-_]{1,60}$')) { throw 'Invalid ModuleId format.' }

  $display = Get-47CliArg -Name 'DisplayName' -Default $null
  if (-not $display -and -not $script:NonInteractive) { $display = Read-Host "DisplayName [optional]" }

  $desc = Get-47CliArg -Name 'Description' -Default $null
  if (-not $desc -and -not $script:NonInteractive) { $desc = Read-Host "Description [optional]" }

  $res = Invoke-47Tool -Name 'New-47Module.ps1' -Args @{
    ModuleId=$moduleId
    DisplayName=$display
    Description=$desc
  }

  if ($script:JsonMode) { return [pscustomobject]@{ ok=$true; moduleId=$moduleId; result=$res } }
}
#endregion Tool wrappers

#region Command registry
$script:CommandRegistry = @{}
Register-47Command -Registry $script:CommandRegistry -Key '1' -Label 'List modules'                    -Category 'Modules'      -Order 10 -Handler { Modules-List }
Register-47Command -Registry $script:CommandRegistry -Key '2' -Label 'Import a module'                 -Category 'Modules'      -Order 20 -Handler { Modules-Import }
Register-47Command -Registry $script:CommandRegistry -Key '3' -Label 'Show effective policy'           -Category 'Policy'       -Order 30 -Handler { Policy-ShowEffective }
Register-47Command -Registry $script:CommandRegistry -Key '4' -Label 'Validate a plan'                 -Category 'Plans'        -Order 40 -Handler { Plan-Validate }
Register-47Command -Registry $script:CommandRegistry -Key '5' -Label 'Run a plan (WhatIf)'             -Category 'Plans'        -Order 50 -Handler { Plan-Run -Mode 'WhatIf' }
Register-47Command -Registry $script:CommandRegistry -Key '6' -Label 'Run a plan (Apply)'              -Category 'Plans'        -Order 60 -Handler { Plan-Run -Mode 'Apply' }
Register-47Command -Registry $script:CommandRegistry -Key '7' -Label 'Simulate policy against a plan'  -Category 'Policy'       -Order 70 -Handler { Policy-Simulate }
Register-47Command -Registry $script:CommandRegistry -Key '8' -Label 'Build a support bundle'          -Category 'Support'      -Order 80 -Handler { Export-SupportBundle }
Register-47Command -Registry $script:CommandRegistry -Key '9' -Label 'Run doctor (diagnostics)'        -Category 'Diagnostics'  -Order 90 -Handler { Invoke-Doctor }
Register-47Command -Registry $script:CommandRegistry -Key '10' -Label 'Save snapshot'                  -Category 'Snapshots'    -Order 100 -Handler { Snapshots-Save }
Register-47Command -Registry $script:CommandRegistry -Key '11' -Label 'List snapshots'                 -Category 'Snapshots'    -Order 110 -Handler { Snapshots-List }
Register-47Command -Registry $script:CommandRegistry -Key '12' -Label 'Restore snapshot'               -Category 'Snapshots'    -Order 120 -Handler { Snapshots-Restore }

Register-47Command -Registry $script:CommandRegistry -Key 'a' -Label 'New module (scaffold)'           -Category 'Dev Tools'    -Order 200 -Handler { Modules-Scaffold }
Register-47Command -Registry $script:CommandRegistry -Key 'b' -Label 'Build offline docs'              -Category 'Dev Tools'    -Order 210 -Handler { Build-Docs }
Register-47Command -Registry $script:CommandRegistry -Key 'c' -Label 'Style check'                     -Category 'Dev Tools'    -Order 220 -Handler { Style-Check }
#endregion Command registry

#region Entrypoints
function Show-Usage {
  Get-Help -Detailed -ErrorAction SilentlyContinue $MyInvocation.MyCommand.Path
  if ($?) { return }
  Write-Host "Usage: pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 [-Help] [-Menu] [-Gui] [-NoGui] [-Command <key>] [-Json] [passthrough args]"
}

#region GUI (Windows / WPF)
function Test-47GuiAvailable {
  if (-not $IsWindows) { return $false }
  try {
    Add-Type -AssemblyName PresentationFramework | Out-Null
    Add-Type -AssemblyName PresentationCore | Out-Null
    Add-Type -AssemblyName WindowsBase | Out-Null
    return $true
  } catch { return $false }
}

function Ensure-47StaAndRelaunchForGui {
  param([string]$ScriptPath)

  try {
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') { return $true }
  } catch { }

  $pwsh = Join-Path $PSHOME 'pwsh.exe'
  if (-not (Test-Path -LiteralPath $pwsh)) { return $false }

  $args = @('-NoLogo','-NoProfile','-STA','-File', $ScriptPath, '-Gui')
  Start-Process -FilePath $pwsh -ArgumentList $args | Out-Null
  return $false
}

function New-47GuiBrush {
  param([string]$Hex)
  return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(
    0xFF,
    [Convert]::ToByte($Hex.Substring(1,2),16),
    [Convert]::ToByte($Hex.Substring(3,2),16),
    [Convert]::ToByte($Hex.Substring(5,2),16)
  )))
}

function Show-47GuiMessage {
  param([string]$Text,[string]$Title='47Project Framework')
  [System.Windows.MessageBox]::Show($Text,$Title) | Out-Null
}


  function Show-47CommandPalette {
  try {
    $dlg = New-Object System.Windows.Window
    $dlg.Title = 'Command Palette (Ctrl+K)'
    $dlg.Width = 580
    $dlg.Height = 480
    $dlg.WindowStartupLocation = 'CenterOwner'
    $dlg.Owner = $win
    $dlg.Background = $bg

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '12'

    $q = New-Object System.Windows.Controls.TextBox
    $q.Background = $panel
    $q.Foreground = $fg
    $q.BorderBrush = $accent
    $q.BorderThickness = '1'
    $q.Margin = '0,0,0,10'
    $q.Text = ''

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = 'Type to search (fuzzy). Double-click to run. Pinned/Recent shown when empty.'
    $hint.Foreground = $muted
    $hint.Margin = '0,0,0,8'

    $list = New-Object System.Windows.Controls.ListBox
    $list.Height = 350
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'

    $btns = New-Object System.Windows.Controls.WrapPanel
    $btns.Margin = '0,10,0,0'

    $btnPin = New-Object System.Windows.Controls.Button
    $btnPin.Content = 'Pin Selected'
    $btnPin.Padding = '10,6,10,6'
    $btnPin.Background = $panel
    $btnPin.Foreground = $fg
    $btnPin.BorderBrush = $accent
    $btnPin.BorderThickness = '1'
    $btnPin.Margin = '0,0,10,0'

    $btnUnpin = New-Object System.Windows.Controls.Button
    $btnUnpin.Content = 'Unpin Selected'
    $btnUnpin.Padding = '10,6,10,6'
    $btnUnpin.Background = $panel
    $btnUnpin.Foreground = $fg
    $btnUnpin.BorderBrush = $accent
    $btnUnpin.BorderThickness = '1'

    $btns.Children.Add($btnPin) | Out-Null
    $btns.Children.Add($btnUnpin) | Out-Null

    $sp.Children.Add($q) | Out-Null
    $sp.Children.Add($hint) | Out-Null
    $sp.Children.Add($list) | Out-Null
    $sp.Children.Add($btns) | Out-Null
    $dlg.Content = $sp

    $all = @()
    foreach ($k in ($pages.Keys | Sort-Object)) {
      $all += [pscustomobject]@{ Kind='Page'; Title=$k; Ref=$k }
    }
    foreach ($a in @(Get-47AppCatalog)) {
      $all += [pscustomobject]@{ Kind='App'; Title=$a.DisplayName; Ref=$a }
    }

    function GetPinnedItems {
      $pinned = @(Get-47PinnedCommands)
      $out = @()
      foreach ($p in $pinned) {
        $pi = $all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $p } | Select-Object -First 1
        if ($pi) { $out += @($pi) }
      }
      return $out
    }

    function Render {
      $list.Items.Clear()
      $s = $q.Text
      $recent = @(Get-47Recent)

      if ([string]::IsNullOrWhiteSpace($s)) {
        foreach ($p in (GetPinnedItems)) { [void]$list.Items.Add(("Pinned: " + $p.Title)) }
        foreach ($r in $recent) { [void]$list.Items.Add(("Recent: " + $r)) }
        foreach ($p2 in ($all | Where-Object { $_.Kind -eq 'Page' } | Sort-Object Title | Select-Object -First 30)) {
          [void]$list.Items.Add(("Page: " + $p2.Title))
        }
        foreach ($a2 in ($all | Where-Object { $_.Kind -eq 'App' } | Sort-Object Title | Select-Object -First 30)) {
          [void]$list.Items.Add(("App: " + $a2.Title))
        }
        return
      }

      $scored = foreach ($it in $all) {
        $t = ($it.Kind + ' ' + $it.Title)
        $score = Get-47FuzzyScore -Text $t -Query $s
        if ($score -gt -9999) { [pscustomobject]@{ Item=$it; Score=$score } }
      }

      foreach ($x in ($scored | Sort-Object Score -Descending | Select-Object -First 90)) {
        [void]$list.Items.Add(("{0}: {1}" -f $x.Item.Kind, $x.Item.Title))
      }
    }

    function ResolveItem([string]$sel) {
      if (-not $sel) { return $null }
      if ($sel.StartsWith('Pinned: ')) {
        $t = $sel.Substring(8)
        return ($all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $t } | Select-Object -First 1)
      }
      if ($sel.StartsWith('Recent: ')) {
        $t = $sel.Substring(8)
        $page = $all | Where-Object { $_.Kind -eq 'Page' -and $_.Title -eq $t } | Select-Object -First 1
        if ($page) { return $page }
        $app = $all | Where-Object { $_.Kind -eq 'App' -and $_.Title -eq $t } | Select-Object -First 1
        if ($app) { return $app }
        return $null
      }
      $kind = $sel.Split(':')[0].Trim()
      $title = ($sel.Substring($sel.IndexOf(':')+1)).Trim()
      return ($all | Where-Object { $_.Kind -eq $kind -and $_.Title -eq $title } | Select-Object -First 1)
    }

    function GoItem($it) {
      if (-not $it) { return }
      Add-47Recent -Entry $it.Title

      if ($it.Kind -eq 'Page') {
        $nav.SelectedItem = $it.Ref
        $dlg.Close()
        return
      }
      if ($it.Kind -eq 'App') {
        $nav.SelectedItem = 'Apps'
        try { Set-SelectedApp $it.Ref } catch { }
        $dlg.Close()
        return
      }
    }

    $q.Add_TextChanged({ Render })
    $dlg.Add_ContentRendered({ $q.Focus() | Out-Null; Render })

    $list.Add_MouseDoubleClick({
      try {
        $sel = [string]$list.SelectedItem
        $it = ResolveItem -sel $sel
        GoItem $it
      } catch { }
    })

    $btnPin.Add_Click({
      try {
        $sel = [string]$list.SelectedItem
        $it = ResolveItem -sel $sel
        if (-not $it) { return }
        if ($it.Kind -ne 'Page') { Show-47GuiMessage 'Only pages can be pinned.'; return }
        $p = @(Get-47PinnedCommands)
        if (-not ($p -contains $it.Title)) { $p = @($it.Title) + $p }
        $p = $p | Select-Object -Unique
        Save-47PinnedCommands -Pinned $p
        Render
      } catch { }
    })

    $btnUnpin.Add_Click({
      try {
        $sel = [string]$list.SelectedItem
        if (-not $sel.StartsWith('Pinned: ')) { return }
        $title = $sel.Substring(8)
        $p = @(Get-47PinnedCommands) | Where-Object { $_ -ne $title }
        Save-47PinnedCommands -Pinned $p
        Render
      } catch { }
    })

    $dlg.ShowDialog() | Out-Null
  } catch { }
}

function Get-47OpenFile {
  param([string]$Title='Select file',[string]$Filter='All files (*.*)|*.*')
  $dlg = New-Object Microsoft.Win32.OpenFileDialog
  $dlg.Title = $Title
  $dlg.Filter = $Filter
  if ($dlg.ShowDialog()) { return $dlg.FileName }
  return $null
}

function Get-47SaveFile {
  param([string]$Title='Save file',[string]$Filter='All files (*.*)|*.*',[string]$DefaultName=$null)
  $dlg = New-Object Microsoft.Win32.SaveFileDialog
  $dlg.Title = $Title
  $dlg.Filter = $Filter
  if ($DefaultName) { $dlg.FileName = $DefaultName }
  if ($dlg.ShowDialog()) { return $dlg.FileName }
  return $null
}

function Get-47FolderPicker {
  param([string]$Description='Select folder')
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = $Description
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
  return $null
}

function Get-47FavoritesPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'favorites.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'favorites.json')
  }
}

function Get-47Favorites {
  $fp = Get-47FavoritesPath
  if (Test-Path -LiteralPath $fp) {
    try {
      $j = Get-Content -LiteralPath $fp -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @()
}

function Save-47Favorites {
  param([Parameter(Mandatory)][string[]]$Favorites)
  $fp = Get-47FavoritesPath
  $dir = Split-Path -Parent $fp
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Favorites | Sort-Object -Unique | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $fp -Encoding utf8
}

function Get-47AppCategory {
  param([Parameter(Mandatory)][string]$Path)
  $p = $Path.ToLowerInvariant()
  if ($p -like "*\\framework\\*") { return "Framework" }
  if ($p -like "*\\tools\\*") { return "Tools" }
  if ($p -like "*\\modules\\*") { return "Modules" }
  if ($p -like "*appcrawler*") { return "AppCrawler" }
  if ($p -like "*launcher*") { return "Launcher" }
  return "Apps"
}


function Find-47IconForApp {
  param(
    [Parameter(Mandatory)][string]$AppPath,
    [string]$ModuleId = $null,
    [string]$DisplayName = $null
  )
  try {
    # module-local icon
    if ($ModuleId -and (Test-Path -LiteralPath $AppPath) -and (Test-Path -LiteralPath (Join-Path $AppPath 'icon.png'))) {
      return (Join-Path $AppPath 'icon.png')
    }
  } catch { }

  try {
    $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $assets = Join-Path $root 'assets\\icons'
    if (-not (Test-Path -LiteralPath $assets)) { return $null }

    $base = [IO.Path]::GetFileNameWithoutExtension($AppPath)
    $candNames = @()
    if ($base) { $candNames += @($base) }
    if ($ModuleId) { $candNames += @($ModuleId -replace '[^a-zA-Z0-9\.\-_]','') }
    if ($DisplayName) { $candNames += @($DisplayName -replace '\s+','') }
    # folder name
    try {
      $d = Split-Path -Parent $AppPath
      $candNames += @([IO.Path]::GetFileName($d))
    } catch { }

    $candNames = $candNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($n in $candNames) {
      foreach ($ext in @('png','jpg','jpeg','ico')) {
        $c = Join-Path $assets ($n + '.' + $ext)
        if (Test-Path -LiteralPath $c) { return $c }
      }
    }
  } catch { }
  return $null
}




function Get-47AppCatalog {
  # Discover scripts and modules in the pack and enrich with metadata.
  $root = Split-Path -Parent $MyInvocation.MyCommand.Path
  $root2 = Split-Path -Parent $root

  $patterns = @(
    '47Project.*.ps1',
    'Project47_*.ps1',
    '*AppCrawler*.ps1',
    '*Launcher*.ps1',
    '*Nexus*.ps1'
  )

  $scriptItems = @()
  foreach ($pat in $patterns) {
    $scriptItems += Get-ChildItem -LiteralPath $root2 -Filter $pat -File -ErrorAction SilentlyContinue
  }
  $scriptItems = $scriptItems | Sort-Object FullName -Unique

  $apps = @()

  foreach ($it in $scriptItems) {
    $m = Get-47AppMetadata -Path $it.FullName
    $apps += [pscustomobject]@{
      Type              = 'script'
      Id                = $it.FullName
      Name              = $m.Name
      DisplayName       = $m.Name
      Description       = $m.Description
      Version           = $m.Version
      Kind              = $m.Kind
      Path              = $it.FullName
      Category          = (Get-47AppCategory -Path $it.FullName)
      ModuleId          = $null
      ModuleDir         = $null
      EntryPath         = $it.FullName
      SupportedPlatforms= $null
      MinPowerShellVersion = $null
      RunSpec           = (try { $j.run } catch { $null })
        RunType           = (try { [string]$j.run.type } catch { $null })
        RequiresAdmin     = $false
    }
  }

  # Modules (modules/<folder>/module.json)
  $modsDir = Join-Path $root2 'modules'
  if (Test-Path -LiteralPath $modsDir) {
    foreach ($d in (Get-ChildItem -LiteralPath $modsDir -Directory -ErrorAction SilentlyContinue)) {
      $j = Read-47ModuleJson -ModuleDir $d.FullName
      if (-not $j) { continue }

      $entry = $null
      try {
        if ($j.entrypoint) {
          $ep = Join-Path $d.FullName ([string]$j.entrypoint)
          if (Test-Path -LiteralPath $ep) { $entry = $ep }
        }
      } catch { }

      $sp = $null
      try { $sp = $j.supportedPlatforms } catch { }
      $minPs = $null
      try { $minPs = $j.minPowerShellVersion } catch { }

      $apps += [pscustomobject]@{
        Type              = 'module'
        Id                = [string]$j.moduleId
        Name              = $d.Name
        DisplayName       = ([string]$j.displayName)
        Description       = ([string]$j.description)
        Version           = ([string]$j.version)
        Kind              = 'Module'
        Path              = $d.FullName
        Category          = 'Modules'
        ModuleId          = ([string]$j.moduleId)
        ModuleDir         = $d.FullName
        EntryPath         = $entry
        SupportedPlatforms= $sp
        MinPowerShellVersion = $minPs
        RunSpec           = (try { $j.run } catch { $null })
        RunType           = (try { [string]$j.run.type } catch { $null })
        RequiresAdmin     = $false
      }
    }
  }

  
  # Decorate apps with badge properties for the UI list (runtime/risk)
  foreach ($a in $apps) {
    try {
      $a | Add-Member -NotePropertyName RuntimeBadgeText -NotePropertyValue '' -Force
      $a | Add-Member -NotePropertyName RuntimeBadgeVisibility -NotePropertyValue ([System.Windows.Visibility]::Collapsed) -Force
      $a | Add-Member -NotePropertyName RuntimeBadgeBg -NotePropertyValue (New-47GuiBrush '#1B2A4A') -Force
      $a | Add-Member -NotePropertyName RuntimeBadgeBorder -NotePropertyValue (New-47GuiBrush '#3A5AA6') -Force
      $a | Add-Member -NotePropertyName RuntimeBadgeFg -NotePropertyValue (New-47GuiBrush '#FFFFFF') -Force

      $a | Add-Member -NotePropertyName RiskBadgeText -NotePropertyValue '' -Force
      $a | Add-Member -NotePropertyName RiskBadgeVisibility -NotePropertyValue ([System.Windows.Visibility]::Collapsed) -Force
      $a | Add-Member -NotePropertyName RiskBadgeBg -NotePropertyValue (New-47GuiBrush '#2B2B2B') -Force
      $a | Add-Member -NotePropertyName RiskBadgeBorder -NotePropertyValue (New-47GuiBrush '#5A5A5A') -Force
      $a | Add-Member -NotePropertyName RiskBadgeFg -NotePropertyValue (New-47GuiBrush '#FFFFFF') -Force
      $a | Add-Member -NotePropertyName CapBadgeText -NotePropertyValue '' -Force
      $a | Add-Member -NotePropertyName CapBadgeVisibility -NotePropertyValue ([System.Windows.Visibility]::Collapsed) -Force
      $a | Add-Member -NotePropertyName CapBadgeBg -NotePropertyValue (New-47GuiBrush '#1F1F26') -Force
      $a | Add-Member -NotePropertyName CapBadgeBorder -NotePropertyValue (New-47GuiBrush '#4A4A66') -Force
      $a | Add-Member -NotePropertyName CapBadgeFg -NotePropertyValue (New-47GuiBrush '#FFFFFF') -Force


      $rt = $null
      try { $rt = [string]$a.RunType } catch { $rt = $null }
      if (-not [string]::IsNullOrWhiteSpace($rt)) {
        $a.RuntimeBadgeText = ('Runtime: ' + $rt)
        $a.RuntimeBadgeVisibility = [System.Windows.Visibility]::Visible
      }

      $rk = $null
      try { $rk = [string]$a.Risk } catch { $rk = $null }
      if (-not [string]::IsNullOrWhiteSpace($rk)) {
        $rkl = $rk.ToLowerInvariant()
        $a.RiskBadgeText = ('Risk: ' + $rk)
        $a.RiskBadgeVisibility = [System.Windows.Visibility]::Visible

        switch ($rkl) {
          'safe' {
            $a.RiskBadgeBg = (New-47GuiBrush '#123A2A')
            $a.RiskBadgeBorder = (New-47GuiBrush '#2E8B57')
            $a.RiskBadgeFg = (New-47GuiBrush '#FFFFFF')
          }
          'caution' {
            $a.RiskBadgeBg = (New-47GuiBrush '#3B2D12')
            $a.RiskBadgeBorder = (New-47GuiBrush '#D4A017')
            $a.RiskBadgeFg = (New-47GuiBrush '#FFFFFF')
          }
          'unsafe' {
            $a.RiskBadgeBg = (New-47GuiBrush '#3A1212')
            $a.RiskBadgeBorder = (New-47GuiBrush '#D64545')
            $a.RiskBadgeFg = (New-47GuiBrush '#FFFFFF')
          }
          default {
            $a.RiskBadgeBg = (New-47GuiBrush '#2B2B2B')
            $a.RiskBadgeBorder = (New-47GuiBrush '#5A5A5A')
            $a.RiskBadgeFg = (New-47GuiBrush '#FFFFFF')
          }
        }
      }      $caps = @()
      try { $caps = @($a.Capabilities) } catch { $caps = @() }
      if ($caps -and $caps.Count -gt 0) {
        $a.CapBadgeText = ('Caps: ' + [string]$caps.Count)
        $a.CapBadgeVisibility = [System.Windows.Visibility]::Visible
      }


    } catch { }
  }

return ($apps | Sort-Object Category, DisplayName)
}



function Read-47Theme {
  # Optional theme file: data/theme.json (created by you later), else defaults
  $t = @{
    Background = '#0F1115'
    Panel      = '#141824'
    Foreground = '#E6EAF2'
    Muted      = '#9AA4B2'
    Accent     = '#00FF7B'
    Warning    = '#FFB020'
  }
  try {
    $paths = Get-47Paths
    $themePath = Join-Path $paths.DataRoot 'theme.json'
    if (Test-Path -LiteralPath $themePath) {
      $j = Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json
      foreach ($k in @('Background','Panel','Foreground','Muted','Accent','Warning')) {
        if ($j.$k) { $t[$k] = [string]$j.$k }
      }
    }
  } catch { }
  return $t
}

function Test-47IsAdmin {
  if (-not $IsWindows) { return $false }
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Test-47HasCommand {
  param([Parameter(Mandatory)][string]$Name)
  try { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) } catch { return $false }
}

function Get-47DockerStatus {
  try {
    if (-not (Test-47HasCommand -Name 'docker')) { return 'missing' }
    $null = & docker info 2>$null
    return 'ok'
  } catch { return 'not-running' }
}

function Get-47WingetStatus {
  if (-not $IsWindows) { return 'n/a' }
  try {
    if (Test-47HasCommand -Name 'winget') { return 'ok' }
    return 'missing'
  } catch { return 'unknown' }
}

function Get-47LastSnapshotInfo {
  try {
    $s = @(Get-47Snapshots) | Sort-Object Created -Descending | Select-Object -First 1
    return $s
  } catch { return $null }
}

function Get-47HostStatus {
  $o = [ordered]@{}
  try { $o.PwshVersion = $PSVersionTable.PSVersion.ToString() } catch { $o.PwshVersion = '' }
  $o.IsWindows = [bool]$IsWindows
  $o.IsAdmin = [bool](Test-47IsAdmin)
  $o.WpfAvailable = [bool](Test-47GuiAvailable)
  $o.Docker = (Get-47DockerStatus)
  $o.Winget = (Get-47WingetStatus)
  $o.LastSnapshot = (Get-47LastSnapshotInfo)
  return [pscustomobject]$o
}

function Get-47AppProfilesPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'app-profiles.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'app-profiles.json')
  }
}

function Get-47AppProfiles {
  $fp = Get-47AppProfilesPath
  if (Test-Path -LiteralPath $fp) {
    try {
      $j = Get-Content -LiteralPath $fp -Raw | ConvertFrom-Json
      if ($j) { return $j }
    } catch { }
  }
  return @{}
}

function Save-47AppProfiles {
  param([Parameter(Mandatory)]$Profiles)
  $fp = Get-47AppProfilesPath
  $dir = Split-Path -Parent $fp
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Profiles | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $fp -Encoding utf8
}

function Get-47ModuleSettingsPath {
  param([Parameter(Mandatory)][string]$ModuleId)
  $paths = Get-47Paths
  $dir = Join-Path $paths.DataRoot 'module-settings'
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  return (Join-Path $dir ($ModuleId + '.json'))
}

function Get-47ModuleSettings {
  param([Parameter(Mandatory)][string]$ModuleId)
  $p = Get-47ModuleSettingsPath -ModuleId $ModuleId
  if (Test-Path -LiteralPath $p) {
    try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { }
  }
  return @{}
}

function Save-47ModuleSettings {
  param([Parameter(Mandatory)][string]$ModuleId,[Parameter(Mandatory)]$Settings)
  $p = Get-47ModuleSettingsPath -ModuleId $ModuleId
  ($Settings | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $p -Encoding utf8
}


function Read-47PsHelpSummary {
  param([Parameter(Mandatory)][string]$Path)

  $syn = ''
  $desc = ''
  try {
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Synopsis=''; Description='' } }
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return [pscustomobject]@{ Synopsis=''; Description='' } }

    $m1 = [regex]::Match($raw, '(?ms)^\s*\.SYNOPSIS\s*$\s*(.+?)\s*(?:\r?\n\s*\.\w+|\r?\n\s*#>)')
    if ($m1.Success) { $syn = ($m1.Groups[1].Value -replace '\s+',' ').Trim() }

    $m2 = [regex]::Match($raw, '(?ms)^\s*\.DESCRIPTION
  Docs: see docs/INDEX.md
\s*$\s*(.+?)\s*(?:\r?\n\s*\.\w+|\r?\n\s*#>)')
    if ($m2.Success) {
      $desc = ($m2.Groups[1].Value -replace '\s+',' ').Trim()
      if ($desc.Length -gt 180) { $desc = $desc.Substring(0,180) + '...' }
    }
  } catch { }

  return [pscustomobject]@{ Synopsis=$syn; Description=$desc }
}

function Read-47ModuleJson {
  param([Parameter(Mandatory)][string]$ModuleDir)

  $mj = Join-Path $ModuleDir 'module.json'
  if (-not (Test-Path -LiteralPath $mj)) { return $null }

  try {
    $j = Get-Content -LiteralPath $mj -Raw | ConvertFrom-Json
    return $j
  } catch { return $null }
}


function Get-47AppMetadata {
  param([Parameter(Mandatory)][string]$Path)

  $name = [IO.Path]::GetFileNameWithoutExtension($Path)
  $desc = ''
  $ver = ''
  $kind = 'PowerShell'
  try {
    $h = Read-47PsHelpSummary -Path $Path
    if ($h.Synopsis) { $desc = $h.Synopsis }
    elseif ($h.Description) { $desc = $h.Description }

    if (-not $ver) {
      $raw = Get-Content -LiteralPath $Path -TotalCount 120 -ErrorAction SilentlyContinue
      if ($raw) {
        $t = ($raw -join "`n")
        $m2 = [regex]::Match($t, '(?m)^\s*\#\s*Version\s*:\s*(.+)$')
        if ($m2.Success) { $ver = $m2.Groups[1].Value.Trim() }
      }
    }
  } catch { }

  return [pscustomobject]@{ Name=$name; Description=$desc; Version=$ver; Kind=$kind; Path=$Path }
}


function Confirm-47Typed {
  param([Parameter(Mandatory)][string]$Title,[Parameter(Mandatory)][string]$Prompt,[Parameter(Mandatory)][string]$Token)
  try {
    $w = New-Object System.Windows.Window
    $w.Title = $Title
    $w.Width = 420
    $w.Height = 200
    $w.WindowStartupLocation = 'CenterOwner'
    $w.ResizeMode = 'NoResize'
    $w.Background = (New-47GuiBrush '#141824')

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '12'

    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Prompt + "`n`nType: " + $Token
    $t.TextWrapping = 'Wrap'
    $t.Foreground = (New-47GuiBrush '#E6EAF2')
    $t.Margin = '0,0,0,10'

    $tb = New-Object System.Windows.Controls.TextBox
    $tb.BorderBrush = (New-47GuiBrush '#00FF7B')
    $tb.BorderThickness = '1'
    $tb.Background = (New-47GuiBrush '#0F1115')
    $tb.Foreground = (New-47GuiBrush '#E6EAF2')
    $tb.Margin = '0,0,0,10'

    $row = New-Object System.Windows.Controls.WrapPanel
    $ok = New-Object System.Windows.Controls.Button
    $ok.Content = 'Confirm'
    $ok.Padding = '12,6,12,6'
    $ok.BorderBrush = (New-47GuiBrush '#00FF7B')
    $ok.BorderThickness = '1'
    $ok.Background = (New-47GuiBrush '#141824')
    $ok.Foreground = (New-47GuiBrush '#E6EAF2')

    $cancel = New-Object System.Windows.Controls.Button
    $cancel.Content = 'Cancel'
    $cancel.Padding = '12,6,12,6'
    $cancel.Margin = '10,0,0,0'
    $cancel.BorderBrush = (New-47GuiBrush '#00FF7B')
    $cancel.BorderThickness = '1'
    $cancel.Background = (New-47GuiBrush '#141824')
    $cancel.Foreground = (New-47GuiBrush '#E6EAF2')

    $result = $false
    $ok.Add_Click({
      if ($tb.Text -eq $Token) { $result = $true; $w.Close() }
      else { [System.Windows.MessageBox]::Show("Token mismatch.","Confirm") | Out-Null }
    })
    $cancel.Add_Click({ $w.Close() })

    $row.Children.Add($ok) | Out-Null
    $row.Children.Add($cancel) | Out-Null

    $sp.Children.Add($t) | Out-Null
    $sp.Children.Add($tb) | Out-Null
    $sp.Children.Add($row) | Out-Null

    $w.Content = $sp
    $w.ShowDialog() | Out-Null
    return $result
  } catch { return $false }
}


function Get-47ProjectRoot {
  $root = Split-Path -Parent $MyInvocation.MyCommand.Path
  return (Split-Path -Parent $root)
}

function Compare-47FolderDiff {
  param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Target)

  $srcFiles = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue
  $tgtFiles = Get-ChildItem -LiteralPath $Target -Recurse -File -ErrorAction SilentlyContinue

  $srcRel = @{}
  foreach ($f in $srcFiles) { $srcRel[$f.FullName.Substring($Source.Length).TrimStart('\','/')] = $f }
  $tgtRel = @{}
  foreach ($f in $tgtFiles) { $tgtRel[$f.FullName.Substring($Target.Length).TrimStart('\','/')] = $f }

  $added = @()
  $changed = @()
  $same = @()
  foreach ($k in $srcRel.Keys) {
    if (-not $tgtRel.ContainsKey($k)) { $added += @($k); continue }
    try {
      $sf = $srcRel[$k]; $tf = $tgtRel[$k]
      if ($sf.Length -ne $tf.Length -or $sf.LastWriteTimeUtc -ne $tf.LastWriteTimeUtc) { $changed += @($k) } else { $same += @($k) }
    } catch { $changed += @($k) }
  }

  $extra = @()
  foreach ($k in $tgtRel.Keys) {
    if (-not $srcRel.ContainsKey($k)) { $extra += @($k) }
  }

  return [pscustomobject]@{
    Added = $added
    Changed = $changed
    Same = $same
    ExtraInTarget = $extra
  }
}

function Compare-47FolderSummary {
  param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Target)
  $srcFiles = Get-ChildItem -LiteralPath $Source -Recurse -File -ErrorAction SilentlyContinue
  $tgtFiles = Get-ChildItem -LiteralPath $Target -Recurse -File -ErrorAction SilentlyContinue
  $srcRel = @{}
  foreach ($f in $srcFiles) { $srcRel[$f.FullName.Substring($Source.Length).TrimStart('\','/')] = $f }
  $tgtRel = @{}
  foreach ($f in $tgtFiles) { $tgtRel[$f.FullName.Substring($Target.Length).TrimStart('\','/')] = $f }

  $new = 0; $changed = 0; $same = 0
  foreach ($k in $srcRel.Keys) {
    if (-not $tgtRel.ContainsKey($k)) { $new++ ; continue }
    try {
      $sf = $srcRel[$k]; $tf = $tgtRel[$k]
      if ($sf.Length -ne $tf.Length -or $sf.LastWriteTimeUtc -ne $tf.LastWriteTimeUtc) { $changed++ } else { $same++ }
    } catch { $changed++ }
  }
  return [pscustomobject]@{ New=$new; Changed=$changed; Same=$same; Source=$Source; Target=$Target }
}

function Apply-47StagedPack {
  param([Parameter(Mandatory)][string]$StageDir)

  $target = Get-47ProjectRoot
  if (-not (Test-Path -LiteralPath $StageDir)) { throw "Stage folder not found." }

  # Safe: copy only new/changed from stage to target, do not delete target files.
  if ($IsWindows -and (Get-Command robocopy -ErrorAction SilentlyContinue)) {
    & robocopy $StageDir $target /E /XO /XN /XC /R:1 /W:1 /NFL /NDL /NP /NJH /NJS | Out-Null
  } else {
    $files = Get-ChildItem -LiteralPath $StageDir -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
      $rel = $f.FullName.Substring($StageDir.Length).TrimStart('\','/')
      $dest = Join-Path $target $rel
      $dir = Split-Path -Parent $dest
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    }
  }
}


function Get-47RecentPath {
  try {
    $paths = Get-47Paths
    return (Join-Path $paths.DataRoot 'recent.json')
  } catch {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
    return (Join-Path $root 'recent.json')
  }
}

function Get-47Recent {
  $p = Get-47RecentPath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @()
}

function Add-47Recent {
  param([Parameter(Mandatory)][string]$Entry)
  try {
    $cur = @(Get-47Recent)
    $cur = @($Entry) + @($cur | Where-Object { $_ -ne $Entry })
    if ($cur.Count -gt 30) { $cur = $cur[0..29] }
    $p = Get-47RecentPath
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($cur | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $p -Encoding utf8
  } catch { }
}

function Get-47FuzzyScore {
  param([Parameter(Mandatory)][string]$Text,[Parameter(Mandatory)][string]$Query)

  $t = $Text.ToLowerInvariant()
  $q = $Query.ToLowerInvariant().Trim()
  if ([string]::IsNullOrWhiteSpace($q)) { return 0 }

  $tokens = $q -split '\s+' | Where-Object { $_ }
  $score = 0
  foreach ($tok in $tokens) {
    $idx = $t.IndexOf($tok)
    if ($idx -lt 0) { return -9999 }
    $score += (200 - [Math]::Min(200,$idx))
    if ($idx -eq 0) { $score += 80 }
  }

  if ($t -like "*$q*") { $score += 60 }
  return $score
}

function Get-47UiStatePath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'ui-state.json')
}

function Get-47SafeModePath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'safe-mode.json')
}

function Get-47UiState {
  $p = Get-47UiStatePath
  if (Test-Path -LiteralPath $p) {
    try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { }
  }
  return [pscustomobject]@{}
}

function Save-47UiState {
  param([Parameter(Mandatory)]$State)
  $p = Get-47UiStatePath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($State | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $p -Encoding utf8
}

function Get-47SafeMode {
  $p = Get-47SafeModePath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -and $j.enabled -ne $null) { return [bool]$j.enabled }
    } catch { }
  }
  return $false
}

function Set-47SafeMode {
  param([Parameter(Mandatory)][bool]$Enabled)
  $p = Get-47SafeModePath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ([pscustomobject]@{ enabled = $Enabled; updated = (Get-Date) } | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $p -Encoding utf8
}

function Export-47UserConfig {
  param([Parameter(Mandatory)][string]$OutZip)
  $paths = Get-47Paths
  $root = $paths.DataRoot

  $tmp = Join-Path $root ('_export_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null

  $items = @(
    'favorites.json',
    'recent.json',
    'ui-state.json',
    'app-profiles.json',
    'safe-mode.json'
  )

  foreach ($i in $items) {
    $src = Join-Path $root $i
    if (Test-Path -LiteralPath $src) {
      Copy-Item -LiteralPath $src -Destination (Join-Path $tmp $i) -Force
    }
  }

  $ms = Join-Path $root 'module-settings'
  if (Test-Path -LiteralPath $ms) {
    Copy-Item -LiteralPath $ms -Destination (Join-Path $tmp 'module-settings') -Recurse -Force
  }

  if (Test-Path -LiteralPath $OutZip) { Remove-Item -LiteralPath $OutZip -Force }
  Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $OutZip -Force
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

function Import-47UserConfig {
  param([Parameter(Mandatory)][string]$InZip)
  $paths = Get-47Paths
  $root = $paths.DataRoot

  $tmp = Join-Path $root ('_import_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  Expand-Archive -LiteralPath $InZip -DestinationPath $tmp -Force

  # Backup current config
  $backup = Join-Path $root ('backup_config_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
  try { Export-47UserConfig -OutZip $backup } catch { }

  foreach ($f in (Get-ChildItem -LiteralPath $tmp -File -ErrorAction SilentlyContinue)) {
    Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $root $f.Name) -Force
  }
  $ms = Join-Path $tmp 'module-settings'
  if (Test-Path -LiteralPath $ms) {
    $dst = Join-Path $root 'module-settings'
    if (-not (Test-Path -LiteralPath $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $ms '*') -Destination $dst -Recurse -Force
  }

  Remove-Item -LiteralPath $tmp -Recurse -Force
  return $backup
}

function Get-47PinnedCommandsPath {
  $paths = Get-47Paths
  return (Join-Path $paths.DataRoot 'pinned-commands.json')
}

function Get-47PinnedCommands {
  $p = Get-47PinnedCommandsPath
  if (Test-Path -LiteralPath $p) {
    try {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -is [System.Array]) { return @($j) }
    } catch { }
  }
  return @('Doctor','Verify','Support','Pack Manager')
}

function Save-47PinnedCommands {
  param([Parameter(Mandatory)]$Pinned)
  $p = Get-47PinnedCommandsPath
  $dir = Split-Path -Parent $p
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  ($Pinned | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $p -Encoding utf8
}

function Get-47PackVersion {
  try {
    $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $p = Join-Path $root 'version.json'
    if (Test-Path -LiteralPath $p) {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -and $j.version) { return [string]$j.version }
    }
  } catch { }
  return 'v?'
}

function Get-47PackDate {
  try {
    $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    $p = Join-Path $root 'version.json'
    if (Test-Path -LiteralPath $p) {
      $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
      if ($j -and $j.date) { return [string]$j.date }
    }
  } catch { }
  return ''
}

function Show-47Splash {
  param(
    [string]$Title = '47Project Framework',
    [string]$Subtitle = 'Loading...'
  )
  try {
    Add-Type -AssemblyName PresentationFramework | Out-Null
    $w = New-Object System.Windows.Window
    $w.Width = 420
    $w.Height = 180
    $w.WindowStartupLocation = 'CenterScreen'
    $w.WindowStyle = 'None'
    $w.ResizeMode = 'NoResize'
    $w.Topmost = $true
    $w.Background = [System.Windows.Media.Brushes]::Black
    $w.AllowsTransparency = $false
    $w.ShowInTaskbar = $false

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '18'

    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $Title
    $t1.FontSize = 22
    $t1.Foreground = [System.Windows.Media.Brushes]::White
    $t1.Margin = '0,0,0,8'

    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $Subtitle
    $t2.FontSize = 14
    $t2.Foreground = [System.Windows.Media.Brushes]::Gray

    $sp.Children.Add($t1) | Out-Null
    $sp.Children.Add($t2) | Out-Null
    $w.Content = $sp

    $w.Show() | Out-Null
    return $w
  } catch { return $null }
}

function Get-47LocalUpdates {
  try {
    $root = Get-47ProjectRoot
    $dir = Join-Path $root 'pack_updates'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $z = Get-ChildItem -LiteralPath $dir -File -Filter '*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    return @($z)
  } catch { return @() }
}

function Show-47Gui {
  if (-not (Test-47GuiAvailable)) { Write-Warning "GUI not available on this platform/host. Falling back to CLI."; return $false }
  $scriptPath = $MyInvocation.MyCommand.Path
  if (-not (Ensure-47StaAndRelaunchForGui -ScriptPath $scriptPath)) { return $true } # relaunched; exit current  # Theme
  $theme = Read-47Theme
  $bg = New-47GuiBrush $theme.Background
  $panel = New-47GuiBrush $theme.Panel
  $fg = New-47GuiBrush $theme.Foreground
  $muted = New-47GuiBrush $theme.Muted
  $accent = New-47GuiBrush $theme.Accent
  $warn = New-47GuiBrush $theme.Warning

  # Window
  $win = New-Object System.Windows.Window
  $win.Title = ('47Project Framework ' + (Get-47PackVersion))

  # Load UI state (size/position/last page/filters)
  $script:UiState = Get-47UiState
  try {
    if ($script:UiState.WindowWidth) { $win.Width = [double]$script:UiState.WindowWidth }
    if ($script:UiState.WindowHeight) { $win.Height = [double]$script:UiState.WindowHeight }
    if ($script:UiState.WindowLeft -ne $null) { $win.Left = [double]$script:UiState.WindowLeft }
    if ($script:UiState.WindowTop -ne $null) { $win.Top = [double]$script:UiState.WindowTop }
    if ($script:UiState.WindowState) { $win.WindowState = $script:UiState.WindowState }
  } catch { }

  $win.Width = 1080
  $win.Height = 720
  $win.Background = $bg
  $win.WindowStartupLocation = 'CenterScreen'

  $grid = New-Object System.Windows.Controls.Grid
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = '56' })) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = '*' })) | Out-Null
  $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = 'Auto' })) | Out-Null

  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '240' })) | Out-Null
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = '*' })) | Out-Null

  # Header
  $hdr = New-Object System.Windows.Controls.Border
  $hdr.Background = $panel
  $hdr.BorderBrush = $accent
  $hdr.BorderThickness = '0,0,0,2'
  [System.Windows.Controls.Grid]::SetRow($hdr,0)
  [System.Windows.Controls.Grid]::SetColumnSpan($hdr,2)

  $hdrGrid = New-Object System.Windows.Controls.Grid
  $hdrGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='*' })) | Out-Null
  $hdrGrid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='Auto' })) | Out-Null

  $title = New-Object System.Windows.Controls.TextBlock
  $title.Text = '47Project Framework'
  $title.Margin = '16,14,0,0'
  $title.FontSize = 18
  $title.FontWeight = 'SemiBold'
  $title.Foreground = $fg

  $sub = New-Object System.Windows.Controls.TextBlock
  $sub.Text = 'Nexus Shell * Plans * Modules * Trust * Bundles * Snapshots'
  $sub.Margin = '16,32,0,0'
  $sub.FontSize = 11
  $sub.Foreground = $muted

  $btnRow = New-Object System.Windows.Controls.StackPanel
  $btnRow.Orientation = 'Horizontal'
  $btnRow.Margin = '0,10,16,0'
  [System.Windows.Controls.Grid]::SetColumn($btnRow,1)

  function New-47TopButton([string]$text,[scriptblock]$onClick) {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $text
    $b.Margin = '8,0,0,0'
    $b.Padding = '12,6,12,6'
    $b.Background = $bg
    $b.Foreground = $fg
    $b.BorderBrush = $accent
    $b.BorderThickness = '1'
    $b.Add_Click({ & $onClick })
    return $b
  }

  $btnRow.Children.Add((New-47TopButton 'Open Data' {
    try { $paths = Get-47Paths; Start-Process $paths.DataRoot | Out-Null } catch { Show-47GuiMessage $_.Exception.Message }
  })) | Out-Null

  $btnRow.Children.Add((New-47TopButton 'Help' {
    Show-47GuiMessage "Use the left navigation.\n\nNon-interactive CLI: -Menu / -Command / -Json.\nDestructive actions require -Force when non-interactive."
  })) | Out-Null

  $btnRow.Children.Add((New-47TopButton 'Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Support' { $nav.SelectedItem = 'Support' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Pack' { $nav.SelectedItem = 'Pack Manager' })) | Out-Null
  $btnRow.Children.Add((New-47TopButton 'Tasks' { $nav.SelectedItem = 'Tasks' })) | Out-Null


  $hdrGrid.Children.Add($title) | Out-Null
  $hdrGrid.Children.Add($sub) | Out-Null
  $hdrGrid.Children.Add($btnRow) | Out-Null

  # Safe Mode toggle (disables destructive actions)
  $script:SafeMode = Get-47SafeMode
  $safeBox = New-Object System.Windows.Controls.CheckBox
  $safeBox.Content = 'Safe Mode'
  $safeBox.Foreground = $fg
  $safeBox.Margin = '12,2,0,0'
  $safeBox.IsChecked = $script:SafeMode
  $safeBox.ToolTip = 'When enabled: disables Apply/Restore/Update actions.'
  $safeBox.Add_Click({
    $script:SafeMode = [bool]$safeBox.IsChecked
    Set-47SafeMode -Enabled $script:SafeMode
    try { Update-47ActionGates } catch { }
  })
  [System.Windows.Controls.Grid]::SetColumn($safeBox,1)
  [System.Windows.Controls.Grid]::SetRow($safeBox,0)
  $hdrGrid.Children.Add($safeBox) | Out-Null

  $hdr.Child = $hdrGrid

  # Left nav
  $navBorder = New-Object System.Windows.Controls.Border
  $navBorder.Background = $panel
  $navBorder.BorderBrush = $panel
  $navBorder.BorderThickness = '0,0,1,0'
  [System.Windows.Controls.Grid]::SetRow($navBorder,1)
  [System.Windows.Controls.Grid]::SetColumn($navBorder,0)

  $navStack = New-Object System.Windows.Controls.StackPanel
  $navStack.Margin = '12'

  $navLabel = New-Object System.Windows.Controls.TextBlock
  $navLabel.Text = 'Nexus'
  $navLabel.Foreground = $accent
  $navLabel.FontSize = 12
  $navLabel.FontWeight = 'SemiBold'
  $navLabel.Margin = '4,0,0,8'
  $navStack.Children.Add($navLabel) | Out-Null

  $nav = New-Object System.Windows.Controls.ListBox
  $nav.Height = 520
  $nav.Background = $panel
  $nav.Foreground = $fg
  $nav.BorderBrush = $bg
  $nav.BorderThickness = '0'
  $navStack.Children.Add($nav) | Out-Null
  $navBorder.Child = $navStack

  # Right content + console
  $rightGrid = New-Object System.Windows.Controls.Grid
  $rightGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='*' })) | Out-Null
  $rightGrid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height='Auto' })) | Out-Null
  [System.Windows.Controls.Grid]::SetRow($rightGrid,1)
  [System.Windows.Controls.Grid]::SetColumn($rightGrid,1)

  $contentBorder = New-Object System.Windows.Controls.Border
  $contentBorder.Background = $bg
  $contentBorder.Padding = '16'
  [System.Windows.Controls.Grid]::SetRow($contentBorder,0)

  $contentHost = New-Object System.Windows.Controls.ContentControl
  $contentBorder.Child = $contentHost

  $consoleExp = New-Object System.Windows.Controls.Expander
  $consoleExp.Header = 'Console'
  $consoleExp.IsExpanded = $false
  $consoleExp.Margin = '16,0,16,12'
  $consoleExp.Foreground = $fg
  [System.Windows.Controls.Grid]::SetRow($consoleExp,1)

  $consoleBox = New-Object System.Windows.Controls.TextBox
  $consoleBox.Height = 140
  $consoleBox.Background = $panel
  $consoleBox.Foreground = $fg
  $consoleBox.IsReadOnly = $true
  $consoleBox.TextWrapping = 'Wrap'
  $consoleBox.VerticalScrollBarVisibility = 'Auto'
  $consoleBox.BorderBrush = $accent
  $consoleBox.BorderThickness = '1'
  $consoleExp.Content = $consoleBox

  $rightGrid.Children.Add($contentBorder) | Out-Null
  $rightGrid.Children.Add($consoleExp) | Out-Null

  # Status bar
  $status = New-Object System.Windows.Controls.Border
  $status.Background = $panel
  $status.Padding = '12,8,12,8'
  [System.Windows.Controls.Grid]::SetRow($status,2)
  [System.Windows.Controls.Grid]::SetColumnSpan($status,2)

  $statusText = New-Object System.Windows.Controls.TextBlock
  $statusText.Foreground = $muted
  $statusText.Text = 'Ready.'
  $status.Child = $statusText

    function Get-47LogFilePath {
    try {
      $paths = Get-47Paths
      $dir = Join-Path $paths.DataRoot 'logs'
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $fn = (Get-Date -Format 'yyyy-MM-dd') + '.log'
      return (Join-Path $dir $fn)
    } catch {
      return $null
    }
  }

  function GuiLog([string]$line,[string]$level='INFO') {
    $ts = Get-Date -Format 'HH:mm:ss'
    $msg = ("[{0}][{1}] {2}" -f $ts, $level, $line)
    $consoleBox.AppendText($msg + "`r`n")
    $consoleBox.ScrollToEnd()

    try {
      $lp = Get-47LogFilePath
      if ($lp) { Add-Content -LiteralPath $lp -Value $msg -Encoding utf8 }
    } catch { }
  }

  function Open-47LatestLog {
    try {
      $paths = Get-47Paths
      $dir = Join-Path $paths.DataRoot 'logs'
      if (-not (Test-Path -LiteralPath $dir)) { return }
      $f = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($f) { Start-Process $f.FullName | Out-Null }
    } catch { }
  }

  function GuiRun([string]$label,[scriptblock]$op) {
    try {
      $statusText.Text = $label
      GuiLog $label 'INFO'
      $r = & $op
      if ($null -ne $r) { GuiLog ($r | Out-String).TrimEnd() 'INFO' }
      $statusText.Text = 'Ready.'
    } catch {
      $statusText.Text = 'Error.'
      GuiLog $_.Exception.Message 'ERROR'
      Show-47GuiMessage $_.Exception.Message
      $statusText.Text = 'Ready.'
    }
  
  # Task runner (non-blocking)
  $script:GuiTasks = @()
  function Add-GuiTaskItem([pscustomobject]$t) {
    # t: Id, Name, State, Started, Ended, CanCancel, Ps
    $script:GuiTasks += @($t)
    try {
      if ($script:TaskList) {
        $script:TaskList.Items.Clear()
        foreach ($x in $script:GuiTasks) {
          [void]$script:TaskList.Items.Add(("{0} | {1} | {2}" -f $x.Id, $x.State, $x.Name))
        }
      }
    } catch { }
  }

  function Refresh-GuiTasks {
    try {
      if ($script:TaskList) {
        $script:TaskList.Items.Clear()
        foreach ($x in $script:GuiTasks) {
          [void]$script:TaskList.Items.Add(("{0} | {1} | {2}" -f $x.Id, $x.State, $x.Name))
        }
      }
    } catch { }
  }

  function Start-47Task([string]$name,[scriptblock]$op) {
    $id = (Get-Date -Format 'HHmmss') + '-' + ([guid]::NewGuid().ToString('N').Substring(0,6))
    $t = [pscustomobject]@{ Id=$id; Name=$name; State='Running'; Started=(Get-Date); Ended=$null; CanCancel=$true; Ps=$null }
    Add-GuiTaskItem $t
    GuiLog ("Task started: " + $name) 'INFO'
    $ps = [PowerShell]::Create()
    $t.Ps = $ps
    $ps.AddScript($op) | Out-Null

    $cb = {
      param($ar)
      try {
        $output = $ps.EndInvoke($ar)
        $t.State = 'Done'
        $t.Ended = Get-Date
        if ($output) { GuiLog (($output | Out-String).TrimEnd()) 'INFO' }
      } catch {
        $t.State = 'Error'
        $t.Ended = Get-Date
        GuiLog $_.Exception.Message 'ERROR'
      } finally {
        $t.CanCancel = $false
        try { $ps.Dispose() } catch { }
        try { $win.Dispatcher.Invoke([action]{ Refresh-GuiTasks }) } catch { }
      }
    }

    $ar = $ps.Beginpages['Settings'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Policy' 'Configure policy knobs stored in your user policy.json.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $paths = Get-47Paths
      $pUser = $paths.PolicyUserPath

      $p = $null
      try { if (Test-Path -LiteralPath $pUser) { $p = Read-47Json -Path $pUser } } catch { $p = $null }
      if (-not $p) { $p = [pscustomobject]@{ schemaVersion = 1; externalRuntimes = [pscustomobject]@{} } }
      if (-not $p.externalRuntimes) { $p | Add-Member -NotePropertyName externalRuntimes -NotePropertyValue ([pscustomobject]@{}) }

      function NewToggle([string]$label,[bool]$value){
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $label
        $cb.IsChecked = $value
        $cb.Foreground = $fg
        $cb.Margin = '0,6,0,0'
        return $cb
      }

      $allow = $true; $py = $true; $node = $true; $go = $true; $exe = $false; $pss = $true
      try { if ($null -ne $p.externalRuntimes.allow) { $allow = [bool]$p.externalRuntimes.allow } } catch { }
      try { if ($null -ne $p.externalRuntimes.allowPython) { $py = [bool]$p.externalRuntimes.allowPython } } catch { }
      try { if ($null -ne $p.externalRuntimes.allowNode) { $node = [bool]$p.externalRuntimes.allowNode } } catch { }
      try { if ($null -ne $p.externalRuntimes.allowGo) { $go = [bool]$p.externalRuntimes.allowGo } } catch { }
      try { if ($null -ne $p.externalRuntimes.allowExe) { $exe = [bool]$p.externalRuntimes.allowExe } } catch { }
      try { if ($null -ne $p.externalRuntimes.allowPwshScript) { $pss = [bool]$p.externalRuntimes.allowPwshScript } } catch { }

      $cbAllow = NewToggle 'Allow external runtimes (global)' $allow
      $cbPy = NewToggle 'Allow Python modules' $py
      $cbNode = NewToggle 'Allow Node modules' $node
      $cbGo = NewToggle 'Allow Go modules' $go
      $cbPss = NewToggle 'Allow pwsh-script modules' $pss
      $cbExe = NewToggle 'Allow EXE modules (highest risk)' $exe

      $sp.Children.Add($cbAllow) | Out-Null
      $sp.Children.Add($cbPy) | Out-Null
      $sp.Children.Add($cbNode) | Out-Null
      $sp.Children.Add($cbGo) | Out-Null
      $sp.Children.Add($cbPss) | Out-Null
      $sp.Children.Add($cbExe) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'

      $btns.Children.Add((New-47Button 'Save Policy' {
        GuiRun 'Save policy' {
          $obj = [ordered]@{
            schemaVersion = 1
            externalRuntimes = [ordered]@{
              allow = [bool]$cbAllow.IsChecked
              allowPython = [bool]$cbPy.IsChecked
              allowNode = [bool]$cbNode.IsChecked
              allowGo = [bool]$cbGo.IsChecked
              allowPwshScript = [bool]$cbPss.IsChecked
              allowExe = [bool]$cbExe.IsChecked
            }
          }
          $dir = Split-Path -Parent $pUser
          if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
          ($obj | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $pUser -Encoding utf8
          Show-47GuiMessage ("Saved: " + $pUser)
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Open policy.json' { try { Start-Process $pUser | Out-Null } catch { Show-47GuiMessage $pUser } })) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      
      # Require verified release
      $chkVerified = New-Object System.Windows.Controls.CheckBox
      $chkVerified.Content = 'Require verified release to run modules'
      $chkVerified.Foreground = $fg
      $chkVerified.Margin = '0,8,0,0'
      try { $pol = Get-47EffectivePolicy; $chkVerified.IsChecked = [bool]$pol.requireVerifiedRelease } catch { }

      $chkVerified.Add_Checked({
        GuiRun 'Enable requireVerifiedRelease' {
          $paths = Get-47Paths
          $pUser = $paths.PolicyUserPath
          $p = $null
          if (Test-Path -LiteralPath $pUser) { $p = Read-47Json -Path $pUser } else { $p = [pscustomobject]@{ schemaVersion = 1 } }
          $p | Add-Member -Force -NotePropertyName requireVerifiedRelease -NotePropertyValue $true
          ($p | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $pUser -Encoding utf8
          Show-47GuiMessage 'requireVerifiedRelease enabled.'
        }
      })
      $chkVerified.Add_Unchecked({
        GuiRun 'Disable requireVerifiedRelease' {
          $paths = Get-47Paths
          $pUser = $paths.PolicyUserPath
          $p = $null
          if (Test-Path -LiteralPath $pUser) { $p = Read-47Json -Path $pUser } else { $p = [pscustomobject]@{ schemaVersion = 1 } }
          $p | Add-Member -Force -NotePropertyName requireVerifiedRelease -NotePropertyValue $false
          ($p | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $pUser -Encoding utf8
          Show-47GuiMessage 'requireVerifiedRelease disabled.'
        }
      })

      # Safe Mode toggle (session)
      $chkSafe = New-Object System.Windows.Controls.CheckBox
      $chkSafe.Content = 'Safe Mode (session) — disables external runtimes'
      $chkSafe.Foreground = $fg
      $chkSafe.Margin = '0,6,0,0'
      $chkSafe.IsChecked = ($env:P47_SAFE_MODE -eq '1')
      $chkSafe.Add_Checked({ $env:P47_SAFE_MODE = '1'; Show-47GuiMessage 'Safe Mode ON (restart may be needed for full effect).' })
      $chkSafe.Add_Unchecked({ $env:P47_SAFE_MODE = $null; Show-47GuiMessage 'Safe Mode OFF.' })

      $btnResetPolicy = New-Object System.Windows.Controls.Button
      $btnResetPolicy.Content = 'Reset policy to defaults'
      $btnResetPolicy.Margin = '0,10,0,0'
      $btnResetPolicy.Add_Click({ GuiRun 'Reset policy' { Invoke-47Tool -Name 'reset_policy.ps1' -Args @{} | Out-Null; Show-47GuiMessage 'Policy reset (user file removed).' } })

      $btnSupport = New-Object System.Windows.Controls.Button
      $btnSupport.Content = 'Create support bundle'
      $btnSupport.Margin = '0,6,0,0'
      $btnSupport.Add_Click({
        GuiRun 'Support bundle' {
          $paths = Get-47Paths
          $out = Join-Path $paths.LogsRootUser ('support_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.zip')
          Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath = $out } | Out-Null
          Show-47GuiMessage ('Created: ' + $out)
        }
      })

      $btnOpenSupport = New-Object System.Windows.Controls.Button
      $btnOpenSupport.Content = 'Open logs folder'
      $btnOpenSupport.Margin = '0,6,0,0'
      $btnOpenSupport.Add_Click({ try { $paths = Get-47Paths; Start-Process $paths.LogsRootUser | Out-Null } catch { } })

      $sp.Children.Add($chkVerified) | Out-Null
      $sp.Children.Add($chkSafe) | Out-Null
      $sp.Children.Add($btnResetPolicy) | Out-Null
      $sp.Children.Add($btnSupport) | Out-Null
      $sp.Children.Add($btnOpenSupport) | Out-Null

return $sp
    })) | Out-Null

    
    $root.Children.Add((New-47Card 'Release verification' 'Verify an offline release zip using embedded checksums and optional signatures.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      Add-Type -AssemblyName PresentationFramework | Out-Null

      $zipRow = New-Object System.Windows.Controls.WrapPanel
      $zipRow.Margin = '0,0,0,8'
      $zipBox = New-Object System.Windows.Controls.TextBox
      $zipBox.MinWidth = 420
      $zipBox.Background = $panel
      $zipBox.Foreground = $fg
      $zipBox.BorderBrush = $accent
      $zipBox.BorderThickness = '1'

      $btnBrowseZip = New-Object System.Windows.Controls.Button
      $btnBrowseZip.Content = 'Browse zip'
      $btnBrowseZip.Margin = '8,0,0,0'
      $btnBrowseZip.Add_Click({
        try {
          $dlg = New-Object Microsoft.Win32.OpenFileDialog
          $dlg.Filter = 'Zip files (*.zip)|*.zip|All files (*.*)|*.*'
          if ($dlg.ShowDialog()) { $zipBox.Text = $dlg.FileName }
        } catch { }
      })

      $zipRow.Children.Add($zipBox) | Out-Null
      $zipRow.Children.Add($btnBrowseZip) | Out-Null

      $keyRow = New-Object System.Windows.Controls.WrapPanel
      $keyRow.Margin = '0,0,0,8'
      $keyBox = New-Object System.Windows.Controls.TextBox
      $keyBox.MinWidth = 420
      $keyBox.Background = $panel
      $keyBox.Foreground = $fg
      $keyBox.BorderBrush = $accent
      $keyBox.BorderThickness = '1'
      $keyBox.Text = '' # optional

      $btnBrowseKey = New-Object System.Windows.Controls.Button
      $btnBrowseKey.Content = 'Browse public key'
      $btnBrowseKey.Margin = '8,0,0,0'
      $btnBrowseKey.Add_Click({
        try {
          $dlg = New-Object Microsoft.Win32.OpenFileDialog
          $dlg.Filter = 'XML files (*.xml)|*.xml|All files (*.*)|*.*'
          if ($dlg.ShowDialog()) { $keyBox.Text = $dlg.FileName }
        } catch { }
      })

      $keyRow.Children.Add($keyBox) | Out-Null
      $keyRow.Children.Add($btnBrowseKey) | Out-Null

      $btnVerify = New-Object System.Windows.Controls.Button
      $btnVerify.Content = 'Verify'
      $btnVerify.Margin = '0,6,0,0'
      $btnVerify.Add_Click({
        GuiRun 'Verify release' {
          $zp = $zipBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($zp)) { throw 'Select an offline zip.' }
          $kp = $keyBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($kp)) {
            $out = Invoke-47Tool -Name 'release_verify_offline.ps1' -Args @{ ZipPath=$zp }
            Show-47GuiMessage 'OK'
          } else {
            $out = Invoke-47Tool -Name 'release_verify_offline.ps1' -Args @{ ZipPath=$zp; PublicKeyPath=$kp }
            Show-47GuiMessage 'OK (sig verified when present)'
          }
        }
      })

      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='Offline zip'; Foreground=$muted })) | Out-Null
      $sp.Children.Add($zipRow) | Out-Null
      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='Public key (optional)'; Foreground=$muted })) | Out-Null
      $sp.Children.Add($keyRow) | Out-Null
      $sp.Children.Add($btnVerify) | Out-Null

      return $sp
    })) | Out-Null

return $root
  }

$pages['Home'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    # Startup health gate (warnings)
    $root.Children.Add((New-47Card 'Startup Health' 'Quick warnings and one-click tools.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $st = Get-47HostStatus
      $warn = @()

      if (-not $st.WpfAvailable) { $warn += 'WPF not available - GUI will fail.' }
      if ($st.IsWindows -and (-not $st.IsAdmin)) { $warn += 'Not running as Admin (some actions need elevation).' }
      $pol = $null
      try { $pol = Get-47EffectivePolicy } catch { }
      if ($pol -and $pol.Mode -and ($pol.Mode -ne 'Permissive')) { $warn += ('Policy mode: ' + $pol.Mode) }

      if ($warn.Count -eq 0) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = 'All checks look good.'
        $t.Foreground = $muted
        $sp.Children.Add($t) | Out-Null
      } else {
        foreach ($w in $warn) {
          $t = New-Object System.Windows.Controls.TextBlock
          $t.Text = ' ' + $w
          $t.Foreground = $fg
          $t.Margin = '0,2,0,2'
          $sp.Children.Add($t) | Out-Null
        }

        $btns = New-Object System.Windows.Controls.WrapPanel
        $btns.Margin = '0,10,0,0'
        $btns.Children.Add((New-47Button 'Run Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
        $btns.Children.Add((New-47Button 'Verify' { $nav.SelectedItem = 'Verify' })) | Out-Null
        $btns.Children.Add((New-47Button 'Policy' { $nav.SelectedItem = 'Trust' })) | Out-Null
        $sp.Children.Add($btns) | Out-Null
      }

      return $sp
    })) | Out-Null

    $root.Children.Add((New-47Card 'Dashboard' 'All core features in one place.' {
      $row = New-Object System.Windows.Controls.WrapPanel
      $row.Margin = '0,6,0,0'
      $row.Children.Add((New-47Button 'Plans' { $nav.SelectedItem = 'Plans' })) | Out-Null
      $row.Children.Add((New-47Button 'Modules' { $nav.SelectedItem = 'Modules' })) | Out-Null
      $row.Children.Add((New-47Button 'Trust & Policy' { $nav.SelectedItem = 'Trust' })) | Out-Null
      $row.Children.Add((New-47Button 'Bundles' { $nav.SelectedItem = 'Bundles' })) | Out-Null
      $row.Children.Add((New-47Button 'Snapshots' { $nav.SelectedItem = 'Snapshots' })) | Out-Null
      $row.Children.Add((New-47Button 'Support' { $nav.SelectedItem = 'Support' })) | Out-Null
      $row.Children.Add((New-47Button 'Doctor' { $nav.SelectedItem = 'Doctor' })) | Out-Null
            $row.Children.Add((New-47Button 'Status' { $nav.SelectedItem = 'Status' })) | Out-Null
      $row.Children.Add((New-47Button 'Settings' { $nav.SelectedItem = 'Settings' })) | Out-Null
      $row.Children.Add((New-47Button 'Pack' { $nav.SelectedItem = 'Pack Manager' })) | Out-Null
      $row.Children.Add((New-47Button 'Tasks' { $nav.SelectedItem = 'Tasks' })) | Out-Null
$row.Children.Add((New-47Button 'Apps' { $nav.SelectedItem = 'Apps' })) | Out-Null
      return $row
    })) | Out-Null
    return $root
  }

  
  $pages['Status'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'System Status' 'Readiness indicators for this host.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $st = Get-47HostStatus

      function AddLine([string]$k,[string]$v) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = ($k + ': ' + $v)
        $tb.Margin = '0,2,0,2'
        $tb.Foreground = $fg
        $sp.Children.Add($tb) | Out-Null
      }

      AddLine 'PowerShell' $st.PwshVersion
      AddLine 'Windows' ([string]$st.IsWindows)
      AddLine 'Admin' ([string]$st.IsAdmin)
      AddLine 'WPF' ([string]$st.WpfAvailable)
      AddLine 'Docker' ([string]$st.Docker)
      AddLine 'Winget' ([string]$st.Winget)
      AddLine 'Safe Mode' ([string](Get-47SafeMode))

      if ($st.LastSnapshot) {
        AddLine 'Last Snapshot' ($st.LastSnapshot.Name + ' @ ' + [string]$st.LastSnapshot.Created)
      } else {
        AddLine 'Last Snapshot' 'none'
      }

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,12,0,0'
      $btns.Children.Add((New-47Button 'Run Doctor' { Start-47Task 'Doctor' { Invoke-47Tool -Name 'Invoke-47Doctor.ps1' -Args @{} } | Out-Null })) | Out-Null
      $btns.Children.Add((New-47Button 'Export Support Bundle' {
        $out = Get-47SaveFile -Title 'Save support bundle' -Filter 'ZIP (*.zip)|*.zip|All files (*.*)|*.*' -DefaultName ("support_{0}.zip" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        if ($out) { Start-47Task 'Support Bundle' { Invoke-47Tool -Name 'Export-47SupportBundle.ps1' -Args @{ OutPath=$out } } | Out-Null }
      })) | Out-Null
      $btns.Children.Add((New-47Button 'Open Logs' {
        try { $paths = Get-47Paths; Start-Process (Join-Path $paths.DataRoot 'logs') | Out-Null } catch { }
      })) | Out-Null
      $sp.Children.Add($btns) | Out-Null

      return $sp
    })) | Out-Null

    return $root
  }

$pages['Plans'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $planPathBox = New-Object System.Windows.Controls.TextBox
    $planPathBox.MinWidth = 520
    $planPathBox.Background = $panel
    $planPathBox.Foreground = $fg
    $planPathBox.BorderBrush = $accent
    $planPathBox.BorderThickness = '1'
    $planPathBox.Text = ''

    $policyBox = New-Object System.Windows.Controls.TextBox
    $policyBox.MinWidth = 520
    $policyBox.Background = $panel
    $policyBox.Foreground = $fg
    $policyBox.BorderBrush = $accent
    $policyBox.BorderThickness = '1'
    $policyBox.Text = ''

    $pickPlan = { 
      $p = Get-47OpenFile -Title 'Select plan JSON' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
      if ($p) { $planPathBox.Text = $p }
    }
    $pickPolicy = {
      $p = Get-47OpenFile -Title 'Select policy JSON (optional)' -Filter 'JSON (*.json)|*.json|All files (*.*)|*.*'
      if ($p) { $policyBox.Text = $p }
    }

    $root.Children.Add((New-47Card 'Plan Runner' 'Validate, WhatIf, or Apply a plan.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='PlanPath'; Foreground=$muted; Margin='0,0,0,6' })) | Out-Null
      $r1 = New-Object System.Windows.Controls.StackPanel
      $r1.Orientation = 'Horizontal'
      $r1.Children.Add($planPathBox) | Out-Null
      $r1.Children.Add((New-47Button 'Browse Plan' $pickPlan)) | Out-Null
      $sp.Children.Add($r1) | Out-Null

      $sp.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{ Text='PolicyPath (optional)'; Foreground=$muted; Margin='0,12,0,6' })) | Out-Null
      $r2 = New-Object System.Windows.Controls.StackPanel
      $r2.Orientation = 'Horizontal'
      $r2.Children.Add($policyBox) | Out-Null
      $r2.Children.Add((New-47Button 'Browse Policy' $pickPolicy)) | Out-Null
      $sp.Children.Add($r2) | Out-Null

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,14,0,0'

      $btns.Children.Add((New-47Button 'Validate' {
        Start-47Task 'Validate plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
          Invoke-47Tool -Name 'Validate-47Plan.ps1' -Args @{ PlanPath=$p } | Out-Null
          $h = $null
          try { $h = Invoke-47Tool -Name 'Get-47PlanHash.ps1' -Args @{ PlanPath=$p } } catch { }
          if ($h) { Show-47GuiMessage "Plan validated.`nHash: $h" } else { Show-47GuiMessage "Plan validated." }
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'WhatIf' {
        Start-47Task 'WhatIf plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
          $args = @{ PlanPath=$p; Mode='WhatIf' }
          if (-not [string]::IsNullOrWhiteSpace($policyBox.Text)) { $args.PolicyPath = $policyBox.Text }
          Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args | Out-Null
          Show-47GuiMessage "WhatIf completed."
        }
      })) | Out-Null

      $btns.Children.Add((New-47Button 'Apply' {
        if ($script:SafeMode) { throw 'Safe Mode is enabled.' }
        Start-47Task 'Apply plan' {
          $p = $planPathBox.Text
          if ([string]::IsNullOrWhiteSpace($p)) { throw 'Select a plan file.' }
                    if (-not (Confirm-47Typed -Title 'Confirm Apply' -Prompt 'Applying a plan can modify the system.' -Token 'APPLY')) { return }
          $args = @{ PlanPath=$p; Mode='Apply' }
          if (-not [string]::IsNullOrWhiteSpace($policyBox.Text)) { $args.PolicyPath = $policyBox.Text }
          Invoke-47Tool -Name 'Run-47Plan.ps1' -Args $args | Out-Null
          Show-47GuiMessage "Apply completed."
        }
      } 'danger')) | Out-Null

      $sp.Children.Add($btns) | Out-Null
      return $sp
    })) | Out-Null

    return $root
  }

  
$pages['Modules'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $list = New-Object System.Windows.Controls.ListView
    $list.Height = 260
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'
    $list.DisplayMemberPath = 'DisplayName'

    $script:SelectedModule = $null
    $list.Add_SelectionChanged({
      try { $script:SelectedModule = $list.SelectedItem } catch { $script:SelectedModule = $null }
    })

    $refresh = {
      $list.Items.Clear()
      foreach ($m in @(Get-47Modules)) { [void]$list.Items.Add($m) }
    }

    $idBox = New-Object System.Windows.Controls.TextBox
    $idBox.MinWidth = 360
    $idBox.Background = $panel
    $idBox.Foreground = $fg
    $idBox.BorderBrush = $accent
    $idBox.BorderThickness = '1'

    $root.Children.Add((New-47Card 'Modules' 'Discover, import, scaffold, and run modules.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      $sp.Children.Add((New-47Button 'Refresh' { GuiRun 'Refresh modules' { & $refresh } })) | Out-Null
      $sp.Children.Add($list) | Out-Null

      $argsLbl = New-Object System.Windows.Controls.TextBlock
      $argsLbl.Text = 'Args (optional, single string)'
      $argsLbl.Foreground = $muted
      $argsLbl.Margin = '0,10,0,4'
      $argsBox = New-Object System.Windows.Controls.TextBox
      $argsBox.Background = $panel
      $argsBox.Foreground = $fg
      $argsBox.BorderBrush = $accent
      $argsBox.BorderThickness = '1'
      $argsBox.MinWidth = 360

      $sp.Children.Add($argsLbl) | Out-Null
      $sp.Children.Add($argsBox) | Out-Null

      $runRow = New-Object System.Windows.Controls.WrapPanel
      $runRow.Margin = '0,10,0,0'

      $runRow.Children.Add((New-47Button 'Run Selected' {
        GuiRun 'Run module' {
          $m = $script:SelectedModule
          if (-not $m) { throw 'Select a module.' }

          $extra = $argsBox.Text
          $ea = @()
          if (-not [string]::IsNullOrWhiteSpace($extra)) { $ea = @($extra.Trim()) }

          $warn = @()
          try { if ($m.RunType) { $warn += ('External runtime: ' + [string]$m.RunType) } } catch { }
          try { if ($m.Risk -and ([string]$m.Risk).ToLowerInvariant() -ne 'safe') { $warn += ('Risk: ' + [string]$m.Risk) } } catch { }
          if ($warn.Count -gt 0) {
            $msg = ($warn -join "`r`n") + "`r`n`r`nProceed?"
            $res = [System.Windows.MessageBox]::Show($msg,'Confirm','YesNo')
            if ($res -ne 'Yes') { return }
          }

          Invoke-47ModuleRun -ModulePath $m.Path -Mode Launch -ExtraArgs $ea | Out-Null
          Show-47GuiMessage ('Started: ' + [string]$m.ModuleId)
        }
      })) | Out-Null

      $runRow.Children.Add((New-47Button 'Run & Capture' {
        GuiRun 'Capture run' {
          $m = $script:SelectedModule
          if (-not $m) { throw 'Select a module.' }

          $extra = $argsBox.Text
          $ea = @()
          if (-not [string]::IsNullOrWhiteSpace($extra)) { $ea = @($extra.Trim()) }

          $warn = @()
          try { if ($m.RunType) { $warn += ('External runtime: ' + [string]$m.RunType) } } catch { }
          try { if ($m.Risk -and ([string]$m.Risk).ToLowerInvariant() -ne 'safe') { $warn += ('Risk: ' + [string]$m.Risk) } } catch { }
          if ($warn.Count -gt 0) {
            $msg = ($warn -join "`r`n") + "`r`n`r`nProceed?"
            $res = [System.Windows.MessageBox]::Show($msg,'Confirm','YesNo')
            if ($res -ne 'Yes') { return }
          }

          $out = Invoke-47ModuleRun -ModulePath $m.Path -Mode Capture -ExtraArgs $ea
          Show-47OutputViewer -Title ('Run: ' + [string]$m.DisplayName) -StdOut ([string]$out.StdOut) -StdErr ([string]$out.StdErr)
        }
      })) | Out-Null

      $sp.Children.Add($runRow) | Out-Null

      $hint = New-Object System.Windows.Controls.TextBlock
      $hint.Margin = '0,10,0,0'
      $hint.Foreground = $muted
      $hint.Text = 'Tip: External runtime allow/deny is controlled in Settings -> Policy.'

      $grantBtn = New-Object System.Windows.Controls.Button
      $grantBtn.Content = 'Grant capabilities (always)'
      $grantBtn.Margin = '0,8,0,0'
      $grantBtn.Add_Click({
        GuiRun 'Grant capabilities' {
          $m = $script:SelectedModule
          if (-not $m) { throw 'Select a module.' }
          $caps = @()
          try { $caps = @($m.Capabilities) } catch { $caps = @() }
          if (-not $caps -or $caps.Count -eq 0) { throw 'No capabilities declared.' }
          $merged = Grant-47ModuleCapabilities -ModuleId $m.ModuleId -Capabilities $caps
          Show-47GuiMessage ('Granted ' + $merged.Count + ' capabilities for ' + $m.ModuleId)
        }
      })
      $sp.Children.Add($grantBtn) | Out-Null

      $sp.Children.Add($hint) | Out-Null

      $row = New-Object System.Windows.Controls.WrapPanel
      $row.Margin = '0,12,0,0'
      $row.Children.Add($idBox) | Out-Null

      $row.Children.Add((New-47Button 'Import by Id' {
        GuiRun 'Import module' {
          $id = $idBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($id)) { throw 'Enter module id.' }
          $paths = Get-47Paths
          $mp = Join-Path $paths.ModulesRoot $id
          if (-not (Test-Path -LiteralPath $mp)) { throw ('Module not found: ' + $mp) }
          Import-47Module -ModulePath $mp | Out-Null
          Show-47GuiMessage ('Imported: ' + $id)
        }
      })) | Out-Null

      $row.Children.Add((New-47Button 'Scaffold Module' {
        GuiRun 'Scaffold module' {
          $mid = $idBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($mid)) { throw 'Enter new module id in the box.' }
          Invoke-47Tool -Name 'New-47Module.ps1' -Args @{ ModuleId=$mid } | Out-Null
          Show-47GuiMessage ('Scaffolded: ' + $mid)
          & $refresh
        }
      })) | Out-Null

      $sp.Children.Add($row) | Out-Null
      return $sp
    })) | Out-Null

    & $refresh
    return $root
  }


$pages['Apps'] = {
    $root = New-Object System.Windows.Controls.Grid
    $root.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='2*' })) | Out-Null
    $root.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width='3*' })) | Out-Null

    $left = New-Object System.Windows.Controls.StackPanel
    $left.Margin = '0,0,12,0'
    [System.Windows.Controls.Grid]::SetColumn($left,0)
    $right = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($right,1)

    $root.Children.Add($left) | Out-Null
    $root.Children.Add($right) | Out-Null

    $apps = @(Get-47AppCatalog)
    $favorites = @(Get-47Favorites)

    $search = New-Object System.Windows.Controls.TextBox
    $search.Background = $panel
    $search.Foreground = $fg
    $search.BorderBrush = $accent
    $search.BorderThickness = '1'
    $search.Padding = '10,6,10,6'
    $search.Margin = '0,0,0,10'
    $search.Text = ''

    $filterRow = New-Object System.Windows.Controls.WrapPanel
    $filterRow.Margin = '0,0,0,10'
    $cat = New-Object System.Windows.Controls.ComboBox
    $cat.MinWidth = 180
    $cat.Background = $panel
    $cat.Foreground = $fg
    $cat.BorderBrush = $accent
    $cat.BorderThickness = '1'
    [void]$cat.Items.Add('All')
    $cats = @($apps | Select-Object -ExpandProperty Category -Unique | Where-Object { $_ } | Sort-Object)
    foreach ($c in $cats) { [void]$cat.Items.Add([string]$c) }
    $cat.SelectedIndex = 0

    $onlyFav = New-Object System.Windows.Controls.CheckBox
    $onlyFav.Content = 'Favorites only'
    $onlyFav.Foreground = $fg
    $onlyFav.Margin = '10,4,0,0'

    $onlyExternal = New-Object System.Windows.Controls.CheckBox
    $onlyExternal.Content = 'Only external runtimes'
    $onlyExternal.Foreground = $fg
    $onlyExternal.Margin = '10,0,0,0'

    $onlyRisky = New-Object System.Windows.Controls.CheckBox
    $onlyRisky.Content = 'Only caution/unsafe'
    $onlyRisky.Foreground = $fg
    $onlyRisky.Margin = '10,0,0,0'

    $filterRow.Children.Add($cat) | Out-Null
    $filterRow.Children.Add($onlyFav) | Out-Null

    $list = New-Object System.Windows.Controls.ListView
    $list.Height = 420
    $list.Background = $panel
    $list.Foreground = $fg
    $list.BorderBrush = $accent
    $list.BorderThickness = '1'
    
    $list.DisplayMemberPath = $null

    $xaml = @"
<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <StackPanel Margin="8,6,8,6">
    <TextBlock Text="{Binding DisplayName}" FontWeight="SemiBold" />
    <TextBlock Text="{Binding Category}" FontSize="11" Opacity="0.7" Margin="0,2,0,0" />
    <WrapPanel Margin="0,4,0,0">
      <Border Visibility="{Binding RuntimeBadgeVisibility}" Background="{Binding RuntimeBadgeBg}" BorderBrush="{Binding RuntimeBadgeBorder}" BorderThickness="1" CornerRadius="10" Padding="7,2" Margin="0,0,6,0">
        <TextBlock Text="{Binding RuntimeBadgeText}" Foreground="{Binding RuntimeBadgeFg}" FontSize="11" />
      </Border>
      <Border Visibility="{Binding RiskBadgeVisibility}" Background="{Binding RiskBadgeBg}" BorderBrush="{Binding RiskBadgeBorder}" BorderThickness="1" CornerRadius="10" Padding="7,2" Margin="0,0,6,0">
        <TextBlock Text="{Binding RiskBadgeText}" Foreground="{Binding RiskBadgeFg}" FontSize="11" />
      </Border>
      <Border Visibility="{Binding CapBadgeVisibility}" Background="{Binding CapBadgeBg}" BorderBrush="{Binding CapBadgeBorder}" BorderThickness="1" CornerRadius="10" Padding="7,2" Margin="0,0,6,0">
        <TextBlock Text="{Binding CapBadgeText}" Foreground="{Binding CapBadgeFg}" FontSize="11" />
      </Border>
    </WrapPanel>
  </StackPanel>
</DataTemplate>
"@

    try { $list.ItemTemplate = [System.Windows.Markup.XamlReader]::Parse($xaml) } catch { }


    $left.Children.Add((New-47Card 'Apps' 'Search and launch tools and modules.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add($search) | Out-Null
      $sp.Children.Add($filterRow) | Out-Null
      $sp.Children.Add($list) | Out-Null
      return $sp
    })) | Out-Null

    # Details panel controls
    $title = New-Object System.Windows.Controls.TextBlock
    $title.FontSize = 20
    $title.FontWeight = 'SemiBold'
    $title.Foreground = $fg
    $meta = New-Object System.Windows.Controls.TextBlock
    $meta.Margin = '0,6,0,0'
    $meta.Foreground = $muted
    $meta.TextWrapping = 'Wrap'

    $pathLbl = New-Object System.Windows.Controls.TextBlock
    $pathLbl.Text = 'Path'
    $pathLbl.Margin = '0,12,0,4'
    $pathLbl.Foreground = $muted
    $pathBox = New-Object System.Windows.Controls.TextBox
    $pathBox.Background = $panel
    $pathBox.Foreground = $fg
    $pathBox.BorderBrush = $accent
    $pathBox.BorderThickness = '1'
    $pathBox.IsReadOnly = $true

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Margin = '0,10,0,0'
    $desc.Foreground = $muted
    $desc.TextWrapping = 'Wrap'

    $argsLbl = New-Object System.Windows.Controls.TextBlock
    $argsLbl.Text = 'Args (optional)'
    $argsLbl.Margin = '0,12,0,4'
    $argsLbl.Foreground = $muted
    $argsBox = New-Object System.Windows.Controls.TextBox
    $argsBox.Background = $panel
    $argsBox.Foreground = $fg
    $argsBox.BorderBrush = $accent
    $argsBox.BorderThickness = '1'

    $btnRow = New-Object System.Windows.Controls.WrapPanel
    $btnRow.Margin = '0,14,0,0'

    $btnLaunch = New-47Button 'Launch' { } 
    $btnCapture = New-47Button 'Run & Capture' { }
    $btnAdmin = New-47Button 'Launch (Admin)' { } 
    $btnFolder = New-47Button 'Open folder' { }
    $btnFav = New-47Button 'Favorite' { }
    $btnCopy = New-47Button 'Copy path' { }
    $btnCopyCli = New-47Button 'Copy CLI' { }

    $btnRow.Children.Add($btnLaunch) | Out-Null
    $btnRow.Children.Add($btnCapture) | Out-Null
    $btnRow.Children.Add($btnAdmin) | Out-Null
    $btnRow.Children.Add($btnFolder) | Out-Null
    $btnRow.Children.Add($btnFav) | Out-Null
    $btnRow.Children.Add($btnCopy) | Out-Null
    $btnRow.Children.Add($btnCopyCli) | Out-Null

    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Margin = '0,10,0,0'
    $hint.Foreground = $muted
    $hint.TextWrapping = 'Wrap'
    $hint.Text = 'Tip: External runtime allow/deny is controlled in Settings -> Policy.'

    $right.Children.Add((New-47Card 'Details' 'Selected app information and actions.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add($title) | Out-Null
      $sp.Children.Add($meta) | Out-Null
      $sp.Children.Add($pathLbl) | Out-Null
      $sp.Children.Add($pathBox) | Out-Null
      $sp.Children.Add($desc) | Out-Null
      $sp.Children.Add($argsLbl) | Out-Null
      $sp.Children.Add($argsBox) | Out-Null
      $sp.Children.Add($btnRow) | Out-Null
      $sp.Children.Add($hint) | Out-Null
      return $sp
    })) | Out-Null

    $script:SelectedApp = $null

    function Update-47AppDetails {
      $a = $script:SelectedApp
      if (-not $a) {
        $title.Text = 'No selection'
        $meta.Text = ''
        $pathBox.Text = ''
        $desc.Text = ''
        $argsBox.Text = ''
        foreach ($b in @($btnLaunch,$btnCapture,$btnAdmin,$btnFolder,$btnFav,$btnCopy,$btnCopyCli)) { $b.IsEnabled = $false }
        return
      }

      $title.Text = [string]$a.DisplayName
      $pathBox.Text = [string]$a.Path
      $desc.Text = [string]$a.Description

      $parts = @()
      try { if ($a.Category) { $parts += ('Category: ' + [string]$a.Category) } } catch { }
      try { if ($a.Kind) { $parts += ('Kind: ' + [string]$a.Kind) } } catch { }
      try { if ($a.Type) { $parts += ('Type: ' + [string]$a.Type) } } catch { }
      try { if ($a.RunType) { $parts += ('Runtime: ' + [string]$a.RunType) } } catch { }
      try { if ($a.Risk) { $parts += ('Risk: ' + [string]$a.Risk) } } catch { }
      try { if ($a.Publisher) { $parts += ('Publisher: ' + [string]$a.Publisher) } } catch { }
      try { if ($a.Capabilities -and @($a.Capabilities).Count -gt 0) { $parts += ('Capabilities: ' + (@($a.Capabilities) -join ', ')) } } catch { }
      $meta.Text = ($parts -join '  |  ')

      $btnLaunch.IsEnabled = $true
      $btnCapture.IsEnabled = $true
      $btnFolder.IsEnabled = $true
      $btnCopy.IsEnabled = $true
      $btnCopyCli.IsEnabled = $true

      $btnAdmin.IsEnabled = ($IsWindows -and ($a.Type -ne 'module'))
      $btnFav.IsEnabled = $true
      $btnFav.Content = ( ($favorites -contains $a.Id) ? 'Unfavorite' : 'Favorite' )
    }

    function Confirm-47Run($a) {
      $warn = @()
      try { if ($a.RunType) { $warn += ('External runtime: ' + [string]$a.RunType) } catch { } } catch { }
      try { if ($a.Risk -and ([string]$a.Risk).ToLowerInvariant() -ne 'safe') { $warn += ('Risk: ' + [string]$a.Risk) } } catch { }
      if ($warn.Count -eq 0) { return $true }
      $msg = ($warn -join "`r`n") + "`r`n`r`nProceed?"
      $res = [System.Windows.MessageBox]::Show($msg,'Confirm','YesNo')
      return ($res -eq 'Yes')
    }

    function Invoke-47AppRun([switch]$Elevated,[switch]$Capture) {
      $a = $script:SelectedApp
      if (-not $a) { return }
      if (-not (Confirm-47Run $a)) { return }

      $extra = $argsBox.Text
      $ea = @()
      if (-not [string]::IsNullOrWhiteSpace($extra)) { $ea = @($extra.Trim()) }

      if ($a.Type -eq 'module') {
        if (-not $a.ModuleDir) { throw 'ModuleDir missing.' }
        if ($Capture) {
          if ($Elevated -and $IsWindows) { throw 'Capture is not supported for elevated runs.' }
          $out = Invoke-47ModuleRun -ModulePath $a.ModuleDir -Mode Capture -ExtraArgs $ea
          Show-47OutputViewer -Title ('Run: ' + [string]$a.DisplayName) -StdOut ([string]$out.StdOut) -StdErr ([string]$out.StdErr)
        } else {
          Invoke-47ModuleRun -ModulePath $a.ModuleDir -Mode Launch -ExtraArgs $ea | Out-Null
        }
        return
      }

      # Script/external file
      if (-not (Test-Path -LiteralPath $a.Path)) { throw ('File not found: ' + [string]$a.Path) }

      $pw = $null
      if ($IsWindows) { try { $pw = Join-Path $PSHOME 'pwsh.exe'; if (-not (Test-Path -LiteralPath $pw)) { $pw = $null } } catch { $pw = $null } }
      if (-not $pw) { try { $pw = Resolve-47Runtime -Name 'pwsh' } catch { $pw = $null } }
      if (-not $pw) { throw 'pwsh not found.' }

      $argList = @('-NoLogo','-NoProfile','-File',$a.Path)
      if ($ea.Count -gt 0) { $argList += $ea[0] }

      if ($Capture) {
        if ($Elevated -and $IsWindows) { throw 'Capture is not supported for elevated runs.' }
        $paths = Get-47Paths
        $capDir = Join-Path $paths.LogsRoot 'captures'
        if (-not (Test-Path -LiteralPath $capDir)) { New-Item -ItemType Directory -Force -Path $capDir | Out-Null }
        $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $outFile = Join-Path $capDir ('app_' + $stamp + '_stdout.txt')
        $errFile = Join-Path $capDir ('app_' + $stamp + '_stderr.txt')
        $out = Invoke-47External -FilePath $pw -ArgumentList $argList -WorkingDirectory (Split-Path -Parent $a.Path) -StdOutFile $outFile -StdErrFile $errFile
        Show-47OutputViewer -Title ('Run: ' + [string]$a.DisplayName) -StdOut ([string]$out.StdOut) -StdErr ([string]$out.StdErr)
        return
      }

      if ($Elevated -and $IsWindows) {
        Start-Process -FilePath $pw -ArgumentList $argList -Verb RunAs | Out-Null
      } else {
        Start-Process -FilePath $pw -ArgumentList $argList | Out-Null
      }
    }

    function Render-47AppsList {
      $list.Items.Clear()
      $apps = @(Get-47AppCatalog)
      $q = $search.Text
      $c = [string]$cat.SelectedItem
      $favOnly = [bool]$onlyFav.IsChecked

      if (-not [string]::IsNullOrWhiteSpace($q)) {
        $apps = $apps | Where-Object { $_.DisplayName -like "*$q*" -or $_.Description -like "*$q*" -or $_.Path -like "*$q*" }
      }
      if ($c -and $c -ne 'All') { $apps = $apps | Where-Object { $_.Category -eq $c } }
      if ($favOnly) { $apps = $apps | Where-Object { $favorites -contains $_.Id } }

      foreach ($a in $apps) { [void]$list.Items.Add($a) }
    }

    $list.Add_SelectionChanged({
      try { $script:SelectedApp = $list.SelectedItem; Update-47AppDetails } catch { }
    })

    $search.Add_TextChanged({ Render-47AppsList })
    $cat.Add_SelectionChanged({ Render-47AppsList })
    $onlyFav.Add_Click({ Render-47AppsList })

    $btnGrant = New-Object System.Windows.Controls.Button
    $btnGrant.Content = 'Grant capabilities'
    $btnGrant.Margin = '0,0,8,0'
    $btnGrant.Add_Click({
      GuiRun 'Grant capabilities' {
        if (-not $script:SelectedApp) { throw 'Select an item.' }
        $a = $script:SelectedApp
        if ($a.Type -ne 'module') { throw 'Only modules declare capabilities.' }
        $caps = @()
        try { $caps = @($a.Capabilities) } catch { $caps = @() }
        if (-not $caps -or $caps.Count -eq 0) { throw 'No capabilities declared.' }
        $merged = Grant-47ModuleCapabilities -ModuleId $a.ModuleId -Capabilities $caps
        Show-47GuiMessage ('Granted ' + $merged.Count + ' capabilities for ' + $a.ModuleId)
      }
    })


    $btnLaunch.Add_Click({ GuiRun 'Launch' { Invoke-47AppRun } })
    $btnCapture.Add_Click({ GuiRun 'Capture' { Invoke-47AppRun -Capture } })
    $btnAdmin.Add_Click({ GuiRun 'Launch (Admin)' { Invoke-47AppRun -Elevated } })

    $btnFolder.Add_Click({
      GuiRun 'Open folder' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        $dir = (Test-Path -LiteralPath $a.Path -PathType Container) ? $a.Path : (Split-Path -Parent $a.Path)
        if ($IsWindows) { Start-Process $dir | Out-Null } else { Show-47GuiMessage $dir }
      }
    })

    $btnFav.Add_Click({
      GuiRun 'Toggle favorite' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        if ($favorites -contains $a.Id) { $favorites = @($favorites | Where-Object { $_ -ne $a.Id }) }
        else { $favorites = @($favorites + @($a.Id)) }
        Save-47Favorites -Favorites $favorites
        Render-47AppsList
        Update-47AppDetails
      }
    })

    $btnCopy.Add_Click({
      try {
        $a = $script:SelectedApp
        if ($a) { [System.Windows.Clipboard]::SetText([string]$a.Path) }
      } catch { }
    })

    $btnCopyCli.Add_Click({
      try {
        $a = $script:SelectedApp
        if (-not $a) { return }
        if ($a.Type -eq 'module' -and $a.ModuleId) {
          [System.Windows.Clipboard]::SetText(("pwsh -NoLogo -NoProfile -File `"{0}`" -Menu" -f (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '47Project.Framework.ps1')))
        } else {
          $cmd = "pwsh -NoLogo -NoProfile -File `"{0}`"" -f $a.Path
          $args = $argsBox.Text
          if (-not [string]::IsNullOrWhiteSpace($args)) { $cmd = $cmd + " " + $args }
          [System.Windows.Clipboard]::SetText($cmd)
        }
      } catch { }
    })

    Render-47AppsList
    Update-47AppDetails
    return $root
  }

$pages['Module Wizard'] = {
    $root = New-Object System.Windows.Controls.StackPanel

    $root.Children.Add((New-47Card 'Module Generator' 'Create a new module skeleton under modules/<id> with module.json and stubs.' {
      $sp = New-Object System.Windows.Controls.StackPanel

      function NewRow([string]$label,[ref]$box) {
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = '0,0,0,8'
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $label
        $t.Foreground = $muted
        $tb = New-Object System.Windows.Controls.TextBox
        $tb.Background = $panel
        $tb.Foreground = $fg
        $tb.BorderBrush = $accent
        $tb.BorderThickness = '1'
        $tb.MinWidth = 360
        $row.Children.Add($t) | Out-Null
        $row.Children.Add($tb) | Out-Null
        $box.Value = $tb
        return $row
      }

      $idBox = $null; $nameBox = $null; $verBox = $null; $descBox = $null; $platBox = $null; $minBox = $null; $catBox = $null
      $sp.Children.Add((NewRow 'Module Id (letters/numbers/dash)' ([ref]$idBox))) | Out-Null
      $sp.Children.Add((NewRow 'Name' ([ref]$nameBox))) | Out-Null
      $sp.Children.Add((NewRow 'Version' ([ref]$verBox))) | Out-Null
      $sp.Children.Add((NewRow 'Category' ([ref]$catBox))) | Out-Null
      $sp.Children.Add((NewRow 'Supported Platforms (comma)' ([ref]$platBox))) | Out-Null
      $sp.Children.Add((NewRow 'Min PowerShell Version' ([ref]$minBox))) | Out-Null

      $drow = New-Object System.Windows.Controls.StackPanel
      $drow.Margin = '0,0,0,8'
      $dt = New-Object System.Windows.Controls.TextBlock
      $dt.Text = 'Description'
      $dt.Foreground = $muted
      $desc = New-Object System.Windows.Controls.TextBox
      $desc.Background = $panel
      $desc.Foreground = $fg
      $desc.BorderBrush = $accent
      $desc.BorderThickness = '1'
      $desc.MinHeight = 70
      $desc.TextWrapping = 'Wrap'
      $desc.AcceptsReturn = $true
      $drow.Children.Add($dt) | Out-Null
      $drow.Children.Add($desc) | Out-Null
      $descBox = $desc
      $sp.Children.Add($drow) | Out-Null

      # defaults
      $verBox.Text = '0.1.0'
      $platBox.Text = 'Windows'
      $minBox.Text = '7.0'
      $catBox.Text = 'Utility'

      $btns = New-Object System.Windows.Controls.WrapPanel
      $btns.Margin = '0,10,0,0'

      $btns.Children.Add((New-47Button 'Generate Module' {
        GuiRun 'Generate module' {
          $id = $idBox.Text.Trim()
          if ([string]::IsNullOrWhiteSpace($id)) { throw 'Module Id required.' }
          if ($id -notmatch '^[a-zA-Z0-9\-]+$') { throw 'Module Id invalid. Use letters, numbers, dash.' }

          $name = $nameBox.Text.Trim(); if ([string]::IsNullOrWhiteSpace($name)) { $name = $id }
          $ver = $verBox.Text.Trim(); if ([string]::IsNullOrWhiteSpace($ver)) { $ver = '0.1.0' }
          $cat = $catBox.Text.Trim(); if ([string]::IsNullOrWhiteSpace($cat)) { $cat = 'Utility' }
          $plats = @(); foreach ($p in ($platBox.Text -split ',')) { $q = $p.Trim(); if ($q) { $plats += $q } }
          if ($plats.Count -eq 0) { $plats = @('Windows') }
          $minps = $minBox.Text.Trim(); if ([string]::IsNullOrWhiteSpace($minps)) { $minps = '7.0' }
          $desc = $descBox.Text.Trim()

          $root2 = Get-47ProjectRoot
          $mods = Join-Path $root2 'modules'
          if (-not (Test-Path -LiteralPath $mods)) { New-Item -ItemType Directory -Path $mods -Force | Out-Null }
          $dir = Join-Path $mods $id
          if (Test-Path -LiteralPath $dir) { throw ('Module folder exists: ' + $dir) }
          New-Item -ItemType Directory -Path $dir -Force | Out-Null

          
          $type = [string]$typeBox.SelectedItem

          $manifest = [ordered]@{
            moduleId = $id
            displayName = $name
            version = $ver
            description = $desc
            category = $cat
            supportedPlatforms = $plats
            minPowerShellVersion = $minps
          }

          if ($type -eq 'PowerShell Module (Import)') {
            $manifest.entrypoint = 'Module.psm1'
            $mod = @()
            $mod += 'function Invoke-' + $id + ' {'
            $mod += '  [CmdletBinding()] param()'
            $mod += '  Write-Host "Module imported: ' + $id + '"'
            $mod += '}'
            $mod += ''
            ($mod -join "`r`n") | Set-Content -LiteralPath (Join-Path $dir 'Module.psm1') -Encoding utf8
          }
          elseif ($type -eq 'PowerShell Script (Run)') {
            $manifest.run = [ordered]@{ type = 'pwsh-script'; entry = 'Invoke.ps1'; args = @(); cwd = '.'; env = @{} }
            $stub = @()
            $stub += '<#'
            $stub += '.SYNOPSIS'
            $stub += ('  ' + $name + ' script entry.')
            $stub += '#>'
            $stub += 'param()'
            $stub += 'Write-Host "Script running: ' + $id + '"'
            ($stub -join "`r`n") | Set-Content -LiteralPath (Join-Path $dir 'Invoke.ps1') -Encoding utf8
          }
          elseif ($type -eq 'Python Script') {
            $manifest.run = [ordered]@{ type = 'python'; entry = 'main.py'; args = @(); cwd = '.'; env = @{} }
            @("print('Python module running: " + $id + "')") | Set-Content -LiteralPath (Join-Path $dir 'main.py') -Encoding utf8
          }
          elseif ($type -eq 'Node Script') {
            $manifest.run = [ordered]@{ type = 'node'; entry = 'main.js'; args = @(); cwd = '.'; env = @{} }
            @("console.log('Node module running: " + $id + "');") | Set-Content -LiteralPath (Join-Path $dir 'main.js') -Encoding utf8
          }
          elseif ($type -eq 'Go Program (go run)') {
            $manifest.run = [ordered]@{ type = 'go'; entry = 'main.go'; args = @(); cwd = '.'; env = @{} }
            $go = @()
            $go += 'package main'
            $go += 'import "fmt"'
            $go += 'func main() {'
            $go += '  fmt.Println("Go module running: ' + $id + '")'
            $go += '}'
            ($go -join "`r`n") | Set-Content -LiteralPath (Join-Path $dir 'main.go') -Encoding utf8
          }
          elseif ($type -eq 'Executable') {
            $manifest.run = [ordered]@{ type = 'exe'; entry = 'bin\\tool.exe'; args = @(); cwd = '.'; env = @{} }
            $note = "Place your executable at modules/" + $id + "/bin/tool.exe and update run.entry as needed."
            $note | Set-Content -LiteralPath (Join-Path $dir 'bin\\README.txt') -Encoding utf8
          }

          ($manifest | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath (Join-Path $dir 'module.json') -Encoding utf8

          Show-47GuiMessage ('Created module: ' + $dir)


      $typeRow = New-Object System.Windows.Controls.StackPanel
      $typeRow.Margin = '0,0,0,10'
      $typeLbl = New-Object System.Windows.Controls.TextBlock
      $typeLbl.Text = 'Module Type'
      $typeLbl.Foreground = $muted
      $typeBox = New-Object System.Windows.Controls.ComboBox
      $typeBox.MinWidth = 360
      $typeBox.Background = $panel
      $typeBox.Foreground = $fg
      $typeBox.BorderBrush = $accent
      $typeBox.BorderThickness = '1'
      $null = $typeBox.Items.Add('PowerShell Module (Import)')
      $null = $typeBox.Items.Add('PowerShell Script (Run)')
      $null = $typeBox.Items.Add('Python Script')
      $null = $typeBox.Items.Add('Node Script')
      $null = $typeBox.Items.Add('Go Program (go run)')
      $null = $typeBox.Items.Add('Executable')
      $typeBox.SelectedIndex = 0
      $typeRow.Children.Add($typeLbl) | Out-Null
      $typeRow.Children.Add($typeBox) | Out-Null
      $sp.Children.Add($typeRow) | Out-Null

      $isExternalModule = ($a.Type -eq 'module' -and $a.RunType -and ($a.RunType -ne 'pwsh-module'))
      $detailsArgs.IsEnabled = ($isScript -or $isExternalModule)
      $btnAdmin.IsEnabled = ($IsWindows -and $isScript)

      $btnFav.IsEnabled = $true
      $btnFav.Content = ( ($favorites -contains $a.Id) ? 'Unfavorite' : 'Favorite' )
    }

    function Toggle-Favorite([string]$id) {
      if ($favorites -contains $id) { $favorites = @($favorites | Where-Object { $_ -ne $id }) }
      else { $favorites = @($favorites + @($id)) }
      Save-47Favorites -Favorites $favorites
    }

    function Launch-Selected([switch]$Elevated, [switch]$Capture) {
      $a = $script:SelectedApp
      if (-not $a) { return }

      
      if ($a.Type -eq 'module') {
        if (-not $a.ModuleDir) { throw 'ModuleDir missing.' }

        $warn = @()
        try { if ($a.RunType) { $warn += ('External runtime: ' + [string]$a.RunType) } } catch { }
        try { if ($a.Risk -and ([string]$a.Risk).ToLowerInvariant() -ne 'safe') { $warn += ('Risk: ' + [string]$a.Risk) } } catch { }
        if ($warn.Count -gt 0) {
          $msg = ($warn -join "`r`n") + "`r`n`r`nProceed?"
          $res = [System.Windows.MessageBox]::Show($msg,'Confirm','YesNo')
          if ($res -ne 'Yes') { return }
        }

        $extra = $detailsArgs.Text
        $ea = @()
        if (-not [string]::IsNullOrWhiteSpace($extra)) { $ea = @($extra.Trim()) }

        $rt = $null
        try { $rt = [string]$a.RunType } catch { }

        if ($Capture) {
          if ($Elevated -and $IsWindows) { throw 'Capture is not supported for elevated runs.' }
          $out = Invoke-47ModuleRun -ModulePath $a.ModuleDir -Mode Capture -ExtraArgs $ea
          Show-47OutputViewer -Title ('Run: ' + [string]$a.DisplayName) -StdOut ([string]$out.StdOut) -StdErr ([string]$out.StdErr)
          return
        }

        if (-not [string]::IsNullOrWhiteSpace($rt)) {
          Invoke-47ModuleRun -ModulePath $a.ModuleDir -Mode Launch -ExtraArgs $ea | Out-Null
          Show-47GuiMessage ("Launched module: " + $a.DisplayName)
        } else {
          if (-not $a.ModuleId) { throw 'ModuleId missing.' }
          Import-47Module -Id $a.ModuleId | Out-Null
          Show-47GuiMessage ("Imported module: " + $a.ModuleId)
        }
        return
      }

      $pw = $null
      if ($IsWindows) {
        try {
          $pw = Join-Path $PSHOME 'pwsh.exe'
          if (-not (Test-Path -LiteralPath $pw)) { $pw = $null }
        } catch { $pw = $null }
      }
      if (-not $pw) {
        try { $pw = Resolve-47Runtime -Name 'pwsh' } catch { $pw = $null }
      }
      if (-not $pw) { throw "pwsh not found." }

      if (-not (Test-Path -LiteralPath $a.Path)) { throw ("File not found: " + $a.Path) }

      $extra = $detailsArgs.Text
      $argList = @('-NoLogo','-NoProfile','-File',$a.Path)
      if (-not [string]::IsNullOrWhiteSpace($extra)) { $argList += $extra }

      if ($Capture) {
        if ($Elevated -and $IsWindows) { throw 'Capture is not supported for elevated runs.' }
        $paths = Get-47Paths
        $capDir = Join-Path $paths.LogsRoot 'captures'
        if (-not (Test-Path -LiteralPath $capDir)) { New-Item -ItemType Directory -Force -Path $capDir | Out-Null }
        $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $outFile = Join-Path $capDir ('app_' + $stamp + '_stdout.txt')
        $errFile = Join-Path $capDir ('app_' + $stamp + '_stderr.txt')
        $out = Invoke-47External -FilePath $pw -ArgumentList $argList -WorkingDirectory (Split-Path -Parent $a.Path) -StdOutFile $outFile -StdErrFile $errFile
        Show-47OutputViewer -Title ('Run: ' + [string]$a.DisplayName) -StdOut ([string]$out.StdOut) -StdErr ([string]$out.StdErr)
        return
      }

      if ($Elevated -and $IsWindows) {
        Start-Process -FilePath $pw -ArgumentList $argList -Verb RunAs | Out-Null
      } else {
        Start-Process -FilePath $pw -ArgumentList $argList | Out-Null
      }
    }
$btnLaunch.Add_Click({ GuiRun 'Launch' { if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) { Launch-Selected -Capture } else { Launch-Selected } } })
    $btnAdmin.Add_Click({ GuiRun 'Launch (Admin)' { if ([System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)) { Launch-Selected -Elevated -Capture } else { Launch-Selected -Elevated } } })
    $btnFolder.Add_Click({
      GuiRun 'Open folder' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        $dir = (Test-Path -LiteralPath $a.Path -PathType Container) ? $a.Path : (Split-Path -Parent $a.Path)
        Start-Process $dir | Out-Null
      }
    })
    $btnFav.Add_Click({
      GuiRun 'Toggle favorite' {
        $a = $script:SelectedApp
        if (-not $a) { return }
        Toggle-Favorite -id $a.Id
        RenderApps
        Set-SelectedApp $a
      }
    })
    $btnCopy.Add_Click({
      try {
        $a = $script:SelectedApp
        if ($a) { [System.Windows.Clipboard]::SetText([string]$a.Path) }
      } catch { }
    })

    function New-47Tile($a,[switch]$Small) {
      $tile = New-Object System.Windows.Controls.Border
      $tile.Background = $panel
      $tile.CornerRadius = '12'
      $tile.Padding = '12'
      $tile.Margin = '0,0,12,12'
      $tile.BorderBrush = $accent
      $tile.BorderThickness = '1'
      $tile.Width = ($Small ? 260 : 320)

      $sp = New-Object System.Windows.Controls.StackPanel

      $hdr = New-Object System.Windows.Controls.StackPanel
      $hdr.Orientation = 'Horizontal'
      $hdr.Margin = '0,0,0,8'

      $iconPath = Find-47IconForApp -AppPath $a.Path -ModuleId $a.ModuleId -DisplayName $a.DisplayName
      $hdr.Children.Add((New-47IconElement -name $a.DisplayName -iconPath $iconPath -size ($Small ? 36 : 44))) | Out-Null

      $titleStack = New-Object System.Windows.Controls.StackPanel

      $t = New-Object System.Windows.Controls.TextBlock
      $t.Text = $a.DisplayName
      $t.FontSize = 14
      $t.FontWeight = 'SemiBold'
      $t.Foreground = $fg

      $meta = New-Object System.Windows.Controls.TextBlock
      $meta.Text = ($a.Category + '  |  ' + $a.Kind + (([string]::IsNullOrWhiteSpace($a.Version)) ? '' : ('  |  v' + $a.Version)))
      $meta.Margin = '0,2,0,0'
      $meta.Foreground = $muted
      $meta.TextWrapping = 'Wrap'

      $titleStack.Children.Add($t) | Out-Null
      $titleStack.Children.Add($meta) | Out-Null
      $hdr.Children.Add($titleStack) | Out-Null

      $sp.Children.Add($hdr) | Out-Null

      if (-not $Small) {
        $d1 = New-Object System.Windows.Controls.TextBlock
        $d1.Text = $a.Description
        $d1.Margin = '0,0,0,8'
        $d1.Foreground = $muted
        $d1.TextWrapping = 'Wrap'
        $sp.Children.Add($d1) | Out-Null
      }

      $tile.Child = $sp

      $tile.Add_MouseLeftButtonUp({
        Set-SelectedApp $a
      })

    $btnCopyCli.Add_Click({
      try {
        $a = $script:SelectedApp
        if (-not $a) { return }
        if ($a.Type -eq 'module') {
          [System.Windows.Clipboard]::SetText(("pwsh -NoLogo -NoProfile -File .\Framework\47Project.Framework.ps1 -Command import-module -ModuleId " + $a.ModuleId))
        } else {
          $args = $detailsArgs.Text
          $cmd = "pwsh -NoLogo -NoProfile -File `"{0}`"" -f $a.Path
          if (-not [string]::IsNullOrWhiteSpace($args)) { $cmd = $cmd + " " + $args }
          [System.Windows.Clipboard]::SetText($cmd)
        }
      } catch { }
    })


      return $tile
    }

    function RenderApps {
      $favWrap.Children.Clear()
      $appsWrap.Children.Clear()

      $q = $search.Text
      $cat = [string]$category.SelectedItem
      $favOnly = [bool]$onlyFav.IsChecked

      $apps = @(Get-47AppCatalog)

      if (-not [string]::IsNullOrWhiteSpace($q)) {
        $apps = $apps | Where-Object { $_.DisplayName -like "*$q*" -or $_.Name -like "*$q*" -or $_.Description -like "*$q*" -or $_.Path -like "*$q*" }
      }
      if ($cat -and $cat -ne 'All') {
        $apps = $apps | Where-Object { $_.Category -eq $cat }
      }
      if ($favOnly) {
        $apps = $apps | Where-Object { $favorites -contains $_.Id }
      }

      # Pinned favorites first (strip), then main list without duplicates
      $favApps = $apps | Where-Object { $favorites -contains $_.Id } | Sort-Object DisplayName
      foreach ($a in $favApps) {
        [void]$favWrap.Children.Add((New-47Tile $a -Small))
      }

      $rest = $apps | Where-Object { -not ($favorites -contains $_.Id) } | Sort-Object Category, DisplayName
      foreach ($a in $rest) {
        [void]$appsWrap.Children.Add((New-47Tile $a))
      }

      $favLabel.Visibility = ($favApps.Count -gt 0) ? 'Visible' : 'Collapsed'
      $favWrap.Visibility = ($favApps.Count -gt 0) ? 'Visible' : 'Collapsed'
    }

    $search.Add_TextChanged({ RenderApps })
    $category.Add_SelectionChanged({ RenderApps })
    $onlyFav.Add_Click({ RenderApps })

    $root.Children.Add((New-47Card 'Apps Hub' 'Favorites strip + details panel. Click a tile to view details and launch.' {
      $sp = New-Object System.Windows.Controls.StackPanel
      $sp.Children.Add($layout) | Out-Null
      return $sp
    })) | Out-Null

    RenderApps
    return $root
  }

foreach ($k in @('Home','Status','Plans','Apps','Modules','Module Wizard','Settings','About')) { [void]$nav.Items.Add($k) }
  $nav.SelectedIndex = 0


  try {
    if ($script:UiState.LastPage) {
      $i = $nav.Items.IndexOf([string]$script:UiState.LastPage)
      if ($i -ge 0) { $nav.SelectedIndex = $i } else { $nav.SelectedIndex = 0 }
    } else { $nav.SelectedIndex = 0 }
  } catch { $nav.SelectedIndex = 0 }

  $nav.Add_SelectionChanged({
    try {
      $key = [string]$nav.SelectedItem
      if (-not $key) { return }
      $statusText.Text = $key
      $contentHost.Content = & $pages[$key]
      $statusText.Text = 'Ready.'
    } catch { Show-47Gu
  $win.Add_Closing({
    try {
      $st = [pscustomobject]@{
        WindowWidth = $win.Width
        WindowHeight = $win.Height
        WindowLeft = $win.Left
        WindowTop = $win.Top
        WindowState = [string]$win.WindowState
        LastPage = [string]$nav.SelectedItem
        AppsSearch = ''
        AppsCategory = ''
        AppsFavOnly = $false
      }

      # capture Apps page filter controls if present
      try {
        if ($script:AppsSearch) { $st.AppsSearch = [string]$script:AppsSearch.Text }
        if ($script:AppsCategory) { $st.AppsCategory = [string]$script:AppsCategory.SelectedItem }
        if ($script:AppsFavOnly) { $st.AppsFavOnly = [bool]$script:AppsFavOnly.IsChecked }
      } catch { }

      Save-47UiState -State $st
    } catch { }
  })


iMessage $_.Exception.Message }
  })

  $grid.Children.Add($hdr) | Out-Null
  $grid.Children.Add($navBorder) | Out-Null
  $grid.Children.Add($rightGrid) | Out-Null
  $grid.Children.Add($status) | Out-Null
  $win.Content = $grid

  GuiLog "GUI started." 'INFO'
  
  # Hotkeys
  $win.Add_KeyDown({
    param($sender,$e)
    try {
      if (($e.Key -eq [System.Windows.Input.Key]::K) -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
        $e.Handled = $true
        Show-47CommandPalette
      }
    } catch { }
  })

  try { Update-47ActionGates } catch { }

  $win.Add_ContentRendered({
    # Close splash
    try { if ($script:SplashWin) { $script:SplashWin.Close() } } catch { }
  })

$win.ShowDialog() | Out-Null
  return $true
}
#endregion

if ($Help) { Show-Usage; return }

# GUI auto-launch (Windows only) unless disabled.
if (-not $NoGui -and -not $Menu -and -not $Command) {
  if ($Gui -or (Test-47GuiAvailable)) {
    $launched = Show-47Gui
    if ($launched) { return }
  }
}


Write-47Banner

if ($Menu) {
  if ($script:JsonMode) {
    Write-Output (Write-47Json -Object (Get-47MenuModel -Registry $script:CommandRegistry))
  } else {
    Write-47Menu -Registry $script:CommandRegistry
  }
  return
}

if ($Command) {
  if ($Command -eq '0') { return }
  try {
    $result = Invoke-47CommandKey -Key $Command
    if ($script:JsonMode) {
      Write-Output (Write-47Json -Object ([pscustomobject]@{ ok=$true; command=$Command; result=$result }))
    } elseif ($null -ne $result) {
      Write-Output $result
    }
  } catch {
    if ($script:JsonMode) {
      Write-Output (Write-47Json -Object ([pscustomobject]@{ ok=$false; command=$Command; error=$_.Exception.Message }))
      exit 1
    }
    throw
  }
  return
}

# Interactive loop
while ($true) {
  Write-47Menu -Registry $script:CommandRegistry

  $validKeys = @('0') + @($script:CommandRegistry.Keys)
  $sel = Read-47Choice -Prompt 'Select option' -Valid $validKeys -Default '0'

  if ($sel -eq '0') { break }

  $cmd = $script:CommandRegistry[$sel]
  if (-not $cmd) { Write-Warning 'Unknown selection.'; continue }

  try {
    & $cmd.Handler
  } catch {
    Write-Warning $_
  }
}
#endregion

    # Auto-verify current pack when requireVerifiedRelease is enabled (best-effort)
    try {
      $pol = Get-47EffectivePolicy
      if ($pol.requireVerifiedRelease -eq $true) {
        if (-not (Test-47ReleaseVerified -Policy $pol)) {
          $rootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
          $int = Join-Path $rootPath '_integrity'
          if (Test-Path -LiteralPath $int) {
            try { Invoke-47Tool -Name 'verify_current_pack.ps1' -Args @{} | Out-Null } catch { }
          }
        }
      }
    } catch { }


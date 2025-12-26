using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using _47Project.Nexus.Models;

namespace _47Project.Nexus.Services;

public sealed class EngineHost
{
    private readonly RunspaceJobDispatcher _ps;
    public string PackRoot { get; }

    public EngineHost(RunspaceJobDispatcher ps)
    {
        _ps = ps;
        PackRoot = FindPackRoot();
    }

    private static string FindPackRoot()
    {
        // Search upward from the executable location until we find Framework/ and 47.ps1.
        var dir = AppContext.BaseDirectory;
        var cur = new DirectoryInfo(dir);

        for (int i = 0; i < 10 && cur is not null; i++)
        {
            var hasFramework = Directory.Exists(Path.Combine(cur.FullName, "Framework"));
            var hasCli = File.Exists(Path.Combine(cur.FullName, "47.ps1"));
            if (hasFramework && hasCli) return cur.FullName;
            cur = cur.Parent;
        }

        // Fallback: current base dir
        return AppContext.BaseDirectory;
    }

    private string ImportScript()
    {
        var core = Path.Combine(PackRoot, "Framework", "Core", "47.Core.psd1");
        var runner = Path.Combine(PackRoot, "Framework", "Core", "PlanRunner", "47.PlanRunner.psm1");

        return $@"
$ErrorActionPreference='Stop';
Import-Module -Force '{core}';
Import-Module -Force '{runner}';
";
    }

    public async Task<IReadOnlyList<DoctorCheck>> DoctorAsync(CancellationToken ct)
    {
        var script = ImportScript() + @"
$results = New-Object 'System.Collections.Generic.List[object]';

function Add-Result([string]$name, [bool]$ok, [string]$details) {
  $results.Add([pscustomobject]@{ name=$name; ok=$ok; details=$details }) | Out-Null
}

try { $psv = $PSVersionTable.PSVersion.ToString(); Add-Result 'PowerShell' $true ('PowerShell ' + $psv) } catch { Add-Result 'PowerShell' $false $_.Exception.Message }

try { $paths = Get-47Paths; Add-Result 'Paths' $true ('PackRoot=' + $paths.PackRoot) } catch { Add-Result 'Paths' $false $_.Exception.Message }

try { $mods = Get-47Modules; Add-Result 'ModuleDiscovery' $true ('Found ' + $mods.Count + ' module(s)') } catch { Add-Result 'ModuleDiscovery' $false $_.Exception.Message }

try { $policy = Get-47EffectivePolicy; Add-Result 'Policy' $true ('allowUnsafe=' + $policy.allowUnsafe) } catch { Add-Result 'Policy' $false $_.Exception.Message }

$results | ConvertTo-Json -Depth 10 -Compress
";
        var rows = await _ps.InvokeAsync(script, null, ct).ConfigureAwait(false);
        var json = rows.FirstOrDefault()?.BaseObject?.ToString() ?? "[]";
        var parsed = JsonSerializer.Deserialize<List<Dictionary<string, object>>>(json) ?? new();

        return parsed.Select(x =>
        {
            var name = x.TryGetValue("name", out var n) ? n?.ToString() ?? "" : "";
            var ok = x.TryGetValue("ok", out var o) && (o?.ToString()?.ToLowerInvariant() == "true");
            var details = x.TryGetValue("details", out var d) ? d?.ToString() ?? "" : "";
            return new DoctorCheck(name, ok, details);
        }).ToList();
    }

    public async Task<string> GetLogsRootAsync(CancellationToken ct)
    {
        var script = ImportScript() + "($p=Get-47Paths; $p.LogsRoot)";
        var rows = await _ps.InvokeAsync(script, null, ct).ConfigureAwait(false);
        return rows.FirstOrDefault()?.BaseObject?.ToString() ?? "";
    }

    public async Task<string> RunPlanAsync(string planPath, string mode, string runId, string? policyPath, bool noSnapshot, bool continueOnError, CancellationToken ct)
    {
        // Returns path to result.json (from the plan runner output).
        var script = ImportScript() + @"
param([string]$PlanPath,[string]$Mode,[string]$RunId,[string]$PolicyPath,[bool]$NoSnapshot,[bool]$ContinueOnError)
$r = Invoke-47PlanRun -PlanPath $PlanPath -Mode $Mode -RunId $RunId -PolicyPath $PolicyPath -NoSnapshot:([bool]$NoSnapshot) -ContinueOnError:([bool]$ContinueOnError)
$r.resultsPath = $r.results  # convenience
$r | ConvertTo-Json -Depth 50 -Compress
";
        var parms = new Dictionary<string, object?>
        {
            ["PlanPath"] = planPath,
            ["Mode"] = mode,
            ["RunId"] = runId,
            ["PolicyPath"] = policyPath ?? "",
            ["NoSnapshot"] = noSnapshot,
            ["ContinueOnError"] = continueOnError
        };
        var rows = await _ps.InvokeAsync(script, parms, ct).ConfigureAwait(false);
        return rows.FirstOrDefault()?.BaseObject?.ToString() ?? "{}";
    }
}

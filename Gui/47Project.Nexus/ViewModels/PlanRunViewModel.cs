using System;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using _47Project.Nexus.Common;
using _47Project.Nexus.Models;
using _47Project.Nexus.Services;
using Microsoft.Win32;

namespace _47Project.Nexus.ViewModels;

public sealed class PlanRunViewModel : ObservableObject
{
    private readonly EngineHost _engine;
    private readonly JournalTailService _tail;
    private readonly TextFileTailService _fileTail;

    private CancellationTokenSource? _stdoutTailCts;
    private CancellationTokenSource? _stderrTailCts;
    private readonly System.Collections.Generic.HashSet<string> _terminalStepIds = new(StringComparer.OrdinalIgnoreCase);

    public ObservableCollection<PlanStepEvent> Events { get; } = new();
    public ObservableCollection<StepTimelineItem> Steps { get; } = new();
    public ObservableCollection<ArtifactFile> SelectedArtifacts { get; } = new();

    private string? _currentRunId;
    private string? _logsRoot;
    private CancellationTokenSource? _runCts;

    private string _planPath = "";
    public string PlanPath
    {
        get => _planPath;
        set
        {
            if (SetProperty(ref _planPath, value))
                RunPlanCommand.RaiseCanExecuteChanged();
        }
    }

    private string _mode = "WhatIf";
    public string Mode { get => _mode; set => SetProperty(ref _mode, value); }

    private string _runStatus = "Idle";
    public string RunStatus { get => _runStatus; set => SetProperty(ref _runStatus, value); }

    private string? _runFolder;
    public string? RunFolder { get => _runFolder; set => SetProperty(ref _runFolder, value); }

    private StepTimelineItem? _selectedStep;
    public StepTimelineItem? SelectedStep
    {
        get => _selectedStep;
        set
        {
            if (SetProperty(ref _selectedStep, value))
            {
                _ = RestartStepOutputAsync();
            }
        }
    }

    private string? _selectedStdout;
    public string? SelectedStdout { get => _selectedStdout; set => SetProperty(ref _selectedStdout, value); }

    private string? _selectedStderr;
    public string? SelectedStderr { get => _selectedStderr; set => SetProperty(ref _selectedStderr, value); }

    private bool _liveTailEnabled = true;
    public bool LiveTailEnabled
    {
        get => _liveTailEnabled;
        set
        {
            if (SetProperty(ref _liveTailEnabled, value))
            {
                _ = RestartStepOutputAsync();
            }
        }
    }

    private bool _autoScrollEnabled = true;
    public bool AutoScrollEnabled { get => _autoScrollEnabled; set => SetProperty(ref _autoScrollEnabled, value); }

    private int _totalSteps;
    public int TotalSteps { get => _totalSteps; set { if (SetProperty(ref _totalSteps, value)) RaisePropertyChanged(nameof(Progress01)); } }

    private int _completedSteps;
    public int CompletedSteps { get => _completedSteps; set { if (SetProperty(ref _completedSteps, value)) RaisePropertyChanged(nameof(Progress01)); } }

    public double Progress01 => TotalSteps <= 0 ? 0 : Math.Clamp((double)CompletedSteps / TotalSteps, 0, 1);



    public RelayCommand BrowsePlanCommand { get; }
    public AsyncRelayCommand RunPlanCommand { get; }
    public AsyncRelayCommand RefreshArtifactsCommand { get; }
    public RelayCommand OpenStepFolderCommand { get; }
    public RelayCommand OpenArtifactCommand { get; }

    public PlanRunViewModel(EngineHost engine, JournalTailService tail, TextFileTailService fileTail)
    {
        _engine = engine;
        _tail = tail;
        _fileTail = fileTail;

        BrowsePlanCommand = new RelayCommand(BrowsePlan);
        RunPlanCommand = new AsyncRelayCommand(async ct => await RunPlanAsync(ct), () => !string.IsNullOrWhiteSpace(PlanPath));

        RefreshArtifactsCommand = new AsyncRelayCommand(async ct => await RefreshArtifactsAsync(ct));
        OpenStepFolderCommand = new RelayCommand(OpenStepFolder, () => SelectedStep is not null && !string.IsNullOrWhiteSpace(RunFolder));
        OpenArtifactCommand = new RelayCommand(param => OpenArtifact(param as string), param => param is string p && File.Exists(p));
    }

    private void BrowsePlan()
    {
        var dlg = new OpenFileDialog
        {
            Filter = "Plan JSON (*.json)|*.json|All Files (*.*)|*.*",
            Title = "Select a plan file"
        };
        if (dlg.ShowDialog() == true)
        {
            PlanPath = dlg.FileName;
        }
    }

    private async Task RunPlanAsync(CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(PlanPath))
            return;

        Events.Clear();
        Steps.Clear();
        SelectedArtifacts.Clear();
        _terminalStepIds.Clear();
        CompletedSteps = 0;
        TotalSteps = CountPlanStepsSafe(PlanPath);

        SelectedStdout = null;
        SelectedStderr = null;
        SelectedStep = null;

        RunStatus = "Starting…";

        var runId = Guid.NewGuid().ToString("N");
        _currentRunId = runId;
        _runCts?.Cancel();
        _runCts?.Dispose();
        _runCts = CancellationTokenSource.CreateLinkedTokenSource(ct);

        _logsRoot = await _engine.GetLogsRootAsync(ct).ConfigureAwait(false);
        var runFolder = Path.Combine(_logsRoot, "runs", runId);
        RunFolder = runFolder;
        OpenStepFolderCommand.RaiseCanExecuteChanged();

        var journalPath = Path.Combine(runFolder, "journal.jsonl");

        using var journalCts = CancellationTokenSource.CreateLinkedTokenSource(_runCts!.Token);
        _tail.OnEvent += OnTailEvent;
        var tailTask = _tail.StartAsync(journalPath, journalCts.Token);
        var durationTask = Task.Run(async () =>
        {
            while (!journalCts.Token.IsCancellationRequested)
            {
                try { await Task.Delay(1000, journalCts.Token).ConfigureAwait(false); } catch { break; }
                Application.Current.Dispatcher.Invoke(() =>
                {
                    foreach (var s in Steps.Where(x => x.StartedUtc is not null && x.EndedUtc is null))
                        s.RefreshDuration();
                });
            }
        }, journalCts.Token);


        try
        {
            RunStatus = $"Running ({Mode})…";

            var json = await _engine.RunPlanAsync(
                planPath: PlanPath,
                mode: Mode,
                runId: runId,
                policyPath: null,
                noSnapshot: false,
                continueOnError: false,
                ct: ct
            ).ConfigureAwait(false);

            // Try to parse and show final summary.
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var endUtc = root.TryGetProperty("endUtc", out var e) ? e.GetString() : null;
            var status = root.TryGetProperty("status", out var st) ? st.GetString() : null;
            RunStatus = $"Finished. status={status ?? "?"} endUtc={endUtc ?? "?"}";
        }
        catch (Exception ex)
        {
            RunStatus = "Error: " + ex.Message;
        }
        finally
        {
            StopTailing();
            journalCts.Cancel();
            _tail.OnEvent -= OnTailEvent;
            try { await tailTask.ConfigureAwait(false); } catch { }
            _runCts?.Cancel();
            _runCts?.Dispose();
            _runCts = null;
        }
    }

    private void OnTailEvent(PlanStepEvent ev)
    {
        // Marshal to UI thread (journal tail runs on background thread)
        Application.Current.Dispatcher.Invoke(() =>
        {
            Events.Add(ev);
            UpdateTimeline(ev);
        });
    }

    private void UpdateTimeline(PlanStepEvent ev)
    {
        if (string.IsNullOrWhiteSpace(ev.StepId))
            return;

        var item = Steps.FirstOrDefault(s => s.StepId == ev.StepId);
        if (item is null)
        {
            item = new StepTimelineItem { StepId = ev.StepId! };
            Steps.Add(item);
        }

        if (!string.IsNullOrWhiteSpace(ev.StepType))
            item.StepType = ev.StepType;

        var st = ev.Status ?? "";
        item.Status = st.Equals("start", StringComparison.OrdinalIgnoreCase) ? "running" : st;
        item.Message = ev.Message;

        if (TryParseUtc(ev.TsUtc, out var ts))
        {
            if (ev.Status.Equals("start", StringComparison.OrdinalIgnoreCase) && item.StartedUtc is null)
                item.StartedUtc = ts;

            if (IsTerminalStatus(ev.Status))
            {
                item.EndedUtc = ts;
            }

            if (IsTerminalStatus(item.Status) && _terminalStepIds.Add(item.StepId))
            {
                CompletedSteps = _terminalStepIds.Count;
            }

            if (SelectedStep is not null && SelectedStep.StepId == item.StepId && IsTerminalStatus(item.Status))
            {
                StopTailing();
                _ = RefreshArtifactsAsync();
            }
        }
    }

    private static bool IsTerminalStatus(string status)
    {
        var s = (status ?? "").ToLowerInvariant();
        return s is "ok" or "error" or "blocked" or "skip" or "whatif" or "end";
    }

    
    private static int CountPlanStepsSafe(string planPath)
    {
        try
        {
            if (!File.Exists(planPath)) return 0;
            using var doc = JsonDocument.Parse(File.ReadAllText(planPath));
            if (doc.RootElement.TryGetProperty("steps", out var steps) && steps.ValueKind == JsonValueKind.Array)
                return steps.GetArrayLength();
        }
        catch { }
        return 0;
    }

private static bool TryParseUtc(string? s, out DateTime dt)
    {
        dt = default;
        if (string.IsNullOrWhiteSpace(s)) return false;

        // journal uses ISO 8601 with Z
        return DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out dt);
    }

    
    private void StopTailing()
    {
        try { _stdoutTailCts?.Cancel(); } catch { }
        try { _stderrTailCts?.Cancel(); } catch { }
        _stdoutTailCts = null;
        _stderrTailCts = null;
    }

    private static bool IsRunningStatus(string status)
    {
        var s = (status ?? "").ToLowerInvariant();
        return s is "start" or "running";
    }

    private static string TrimAppend(string? current, string append, int maxChars = 1_000_000)
    {
        var cur = current ?? "";
        if (append.Length == 0) return cur;
        var combined = cur + append;
        if (combined.Length <= maxChars) return combined;
        return combined.Substring(combined.Length - maxChars);
    }

    private async Task RestartStepOutputAsync()
    {
        StopTailing();

        await RefreshArtifactsAsync().ConfigureAwait(false);

        if (!LiveTailEnabled)
            return;

        if (SelectedStep is null || string.IsNullOrWhiteSpace(_currentRunId) || string.IsNullOrWhiteSpace(_logsRoot))
            return;

        if (!IsRunningStatus(SelectedStep.Status))
            return;

        var stepRoot = Path.Combine(_logsRoot!, "runs", _currentRunId!, "steps", SelectedStep.StepId);
        if (!Directory.Exists(stepRoot))
            return;

        var stdoutPath = Path.Combine(stepRoot, "stdout.txt");
        var stderrPath = Path.Combine(stepRoot, "stderr.txt");

        long stdoutPos = File.Exists(stdoutPath) ? new FileInfo(stdoutPath).Length : 0;
        long stderrPos = File.Exists(stderrPath) ? new FileInfo(stderrPath).Length : 0;

        // Tail in the background and append to the visible text.
        _stdoutTailCts = CancellationTokenSource.CreateLinkedTokenSource(_runCts?.Token ?? CancellationToken.None);
        _stderrTailCts = CancellationTokenSource.CreateLinkedTokenSource(_runCts?.Token ?? CancellationToken.None);

        _ = _fileTail.TailAsync(stdoutPath, chunk =>
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                SelectedStdout = TrimAppend(SelectedStdout, chunk);
            });
        }, _stdoutTailCts.Token, initialPosition: stdoutPos);

        _ = _fileTail.TailAsync(stderrPath, chunk =>
        {
            Application.Current.Dispatcher.Invoke(() =>
            {
                SelectedStderr = TrimAppend(SelectedStderr, chunk);
            });
        }, _stderrTailCts.Token, initialPosition: stderrPos);

        RunStatus = "Live tailing selected step…";
    }

private async Task RefreshArtifactsAsync(CancellationToken ct = default)
    {
        SelectedArtifacts.Clear();
        SelectedStdout = null;
        SelectedStderr = null;

        OpenStepFolderCommand.RaiseCanExecuteChanged();

        if (SelectedStep is null || string.IsNullOrWhiteSpace(_currentRunId) || string.IsNullOrWhiteSpace(_logsRoot))
            return;

        var stepRoot = Path.Combine(_logsRoot!, "runs", _currentRunId!, "steps", SelectedStep.StepId);
        if (!Directory.Exists(stepRoot))
            return;

        try
        {
            var stdoutPath = Path.Combine(stepRoot, "stdout.txt");
            var stderrPath = Path.Combine(stepRoot, "stderr.txt");

            SelectedStdout = await ReadTextSafeAsync(stdoutPath, ct).ConfigureAwait(false);
            SelectedStderr = await ReadTextSafeAsync(stderrPath, ct).ConfigureAwait(false);

            foreach (var f in Directory.GetFiles(stepRoot))
            {
                var fi = new FileInfo(f);
                SelectedArtifacts.Add(new ArtifactFile(fi.Name, fi.FullName, fi.Length, fi.LastWriteTimeUtc));
            }
        }
        catch
        {
            // keep UI resilient; errors can be inspected via framework logs
        }
    }

    private static async Task<string?> ReadTextSafeAsync(string path, CancellationToken ct)
    {
        if (!File.Exists(path)) return null;
        // Avoid huge UI blocks: cap to ~1 MB
        const int maxBytes = 1024 * 1024;
        using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var len = (int)Math.Min(fs.Length, maxBytes);
        var buf = new byte[len];
        var read = await fs.ReadAsync(buf.AsMemory(0, len), ct).ConfigureAwait(false);
        return Encoding.UTF8.GetString(buf, 0, read);
    }

    private void OpenStepFolder()
    {
        if (SelectedStep is null || string.IsNullOrWhiteSpace(_currentRunId) || string.IsNullOrWhiteSpace(_logsRoot))
            return;

        var stepRoot = Path.Combine(_logsRoot!, "runs", _currentRunId!, "steps", SelectedStep.StepId);
        if (!Directory.Exists(stepRoot))
            return;

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = stepRoot,
                UseShellExecute = true
            });
        }
        catch { }
    }

    private void OpenArtifact(string? fullPath)
    {
        if (string.IsNullOrWhiteSpace(fullPath) || !File.Exists(fullPath))
            return;

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = fullPath,
                UseShellExecute = true
            });
        }
        catch { }
    }
}
using System.Collections.ObjectModel;
using System.Threading;
using System.Threading.Tasks;
using _47Project.Nexus.Common;
using _47Project.Nexus.Models;
using _47Project.Nexus.Services;

namespace _47Project.Nexus.ViewModels;

public sealed class DashboardViewModel : ObservableObject
{
    private readonly EngineHost _engine;

    public ObservableCollection<DoctorCheck> Checks { get; } = new();

    private string _status = "Not run";
    public string Status { get => _status; set => SetProperty(ref _status, value); }

    public AsyncRelayCommand RunDoctorCommand { get; }

    public DashboardViewModel(EngineHost engine)
    {
        _engine = engine;
        RunDoctorCommand = new AsyncRelayCommand(async ct => await RunDoctorAsync(ct));
    }

    private async Task RunDoctorAsync(CancellationToken ct)
    {
        Status = "Running…";
        Checks.Clear();

        var items = await _engine.DoctorAsync(ct).ConfigureAwait(false);
        foreach (var c in items) Checks.Add(c);

        var failed = 0;
        foreach (var c in items) if (!c.Ok) failed++;

        Status = failed == 0 ? "All checks passed." : $"{failed} check(s) failed.";
    }
}

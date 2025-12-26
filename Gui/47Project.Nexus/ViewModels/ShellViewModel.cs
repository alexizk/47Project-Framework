using System.Collections.ObjectModel;
using _47Project.Nexus.Common;
using _47Project.Nexus.Models;

namespace _47Project.Nexus.ViewModels;

public sealed class ShellViewModel : ObservableObject
{
    public ObservableCollection<NavItem> NavItems { get; } = new()
    {
        new("dashboard","Dashboard"),
        new("plans","Plans"),
        new("run","Run Plan"),
        new("modules","Modules"),
        new("repo","Repo"),
        new("policy","Policy & Trust"),
        new("snapshots","Snapshots"),
        new("logs","Logs"),
        new("settings","Settings"),
    };

    public DashboardViewModel Dashboard { get; }
    public PlanRunViewModel PlanRun { get; }
    public SettingsViewModel SettingsVm { get; }

    public object Plans { get; } = new PlaceholderViewModel("Plans UI (coming next)");
    public object Modules { get; } = new PlaceholderViewModel("Modules UI (coming next)");
    public object Repo { get; } = new PlaceholderViewModel("Repo UI (coming next)");
    public object PolicyTrust { get; } = new PlaceholderViewModel("Policy & Trust UI (coming next)");
    public object Snapshots { get; } = new PlaceholderViewModel("Snapshots UI (coming next)");
    public object Logs { get; } = new PlaceholderViewModel("Logs UI (coming next)");

    public object Settings => SettingsVm;

    private NavItem _selected = new("dashboard","Dashboard");
    public NavItem Selected
    {
        get => _selected;
        set
        {
            if (_selected == value) return;
            _selected = value;
            OnPropertyChanged();
            Navigate(_selected.Key);
        }
    }

    private object _current = new PlaceholderViewModel("Loading...");
    public object Current
    {
        get => _current;
        private set
        {
            _current = value;
            OnPropertyChanged();
        }
    }

    public ShellViewModel(DashboardViewModel dashboard, PlanRunViewModel planRun, SettingsViewModel settings)
    {
        Dashboard = dashboard;
        PlanRun = planRun;
        SettingsVm = settings;

        Selected = NavItems[0];
    }

    private void Navigate(string key)
    {
        Current = key switch
        {
            "dashboard" => Dashboard,
            "plans" => Plans,
            "run" => PlanRun,
            "modules" => Modules,
            "repo" => Repo,
            "policy" => PolicyTrust,
            "snapshots" => Snapshots,
            "logs" => Logs,
            "settings" => Settings,
            _ => Dashboard
        };
    }
}

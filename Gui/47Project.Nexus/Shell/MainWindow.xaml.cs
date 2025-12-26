using System.ComponentModel;
using System.Windows;
using _47Project.Nexus.Services;
using _47Project.Nexus.ViewModels;

namespace _47Project.Nexus.Shell;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        // Simple DI wiring (replace with a container later if you want).
        var dispatcher = new RunspaceJobDispatcher();
        var engine = new EngineHost(dispatcher);
        var tail = new JournalTailService();
        var fileTail = new TextFileTailService();

        var settingsService = new SettingsService();
        var themeService = new ThemeService();
        var settingsVm = new SettingsViewModel(settingsService, themeService);

        var dashboard = new DashboardViewModel(engine);
        var planRun = new PlanRunViewModel(engine, tail, fileTail)
        {
            AutoScrollEnabled = settingsVm.AutoScrollLogs
        };

        // If user changes Settings default, reflect in Plan Run page toggle (best-effort).
        settingsVm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(SettingsViewModel.AutoScrollLogs))
                planRun.AutoScrollEnabled = settingsVm.AutoScrollLogs;
        };

        DataContext = new ShellViewModel(dashboard, planRun, settingsVm);

        Closed += (_, _) => dispatcher.Dispose();
    }
}

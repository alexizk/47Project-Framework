using System;
using System.Windows.Controls;
using System.Windows.Threading;
using _47Project.Nexus.ViewModels;

namespace _47Project.Nexus.Controls;

public partial class LogViewerControl : UserControl
{
    public LogViewerControl()
    {
        InitializeComponent();

        StdoutBox.TextChanged += (_, _) => MaybeScroll(StdoutBox);
        StderrBox.TextChanged += (_, _) => MaybeScroll(StderrBox);
    }

    private void MaybeScroll(TextBox box)
    {
        if (DataContext is not PlanRunViewModel vm) return;
        if (!vm.AutoScrollEnabled) return;

        // Defer scroll so the layout has time to measure the new content.
        Dispatcher.BeginInvoke(() =>
        {
            try { box.ScrollToEnd(); } catch { }
        }, DispatcherPriority.Background);
    }
}

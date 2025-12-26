# GUI Architecture (Nexus)

GUI stack:
- WPF (.NET 8) + MVVM
- PowerShell engine via `Microsoft.PowerShell.SDK` (RunspacePool)
- Live run rendering via journal tailing (`journal.jsonl`)

Core services:
- `RunspaceJobDispatcher`: executes PowerShell scripts/functions off the UI thread (cancelable).
- `EngineHost`: imports Framework modules and exposes typed wrapper methods (Doctor, RunPlan, etc.).
- `JournalTailService`: tails `journal.jsonl` and publishes step/run events to the UI.

Navigation:
- `ShellViewModel` provides nav items and a `Current` view-model.
- WPF `DataTemplate` mapping renders ViewModels into Views (UserControls).

Recommended evolution:
1. Add a SettingsService (theme/accent/language).
2. Add Repo service (sync/browse/install).
3. Add Modules service (actions/settings schema-driven UI).
4. Add Timeline control (group by stepId with duration/status).

using _47Project.Nexus.Common;

namespace _47Project.Nexus.ViewModels;

public sealed class PlaceholderViewModel : ObservableObject
{
    public string Title { get; }
    public PlaceholderViewModel(string title) => Title = title;
}

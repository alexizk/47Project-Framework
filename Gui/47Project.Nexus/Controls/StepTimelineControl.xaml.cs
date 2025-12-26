using System.Collections;
using System.Windows;
using System.Windows.Controls;

namespace _47Project.Nexus.Controls;

public partial class StepTimelineControl : UserControl
{
    public StepTimelineControl()
    {
        InitializeComponent();
    }

    public static readonly DependencyProperty ItemsSourceProperty =
        DependencyProperty.Register(nameof(ItemsSource), typeof(IEnumerable), typeof(StepTimelineControl), new PropertyMetadata(null));

    public IEnumerable? ItemsSource
    {
        get => (IEnumerable?)GetValue(ItemsSourceProperty);
        set => SetValue(ItemsSourceProperty, value);
    }

    public static readonly DependencyProperty SelectedItemProperty =
        DependencyProperty.Register(nameof(SelectedItem), typeof(object), typeof(StepTimelineControl), new PropertyMetadata(null));

    public object? SelectedItem
    {
        get => (object?)GetValue(SelectedItemProperty);
        set => SetValue(SelectedItemProperty, value);
    }
}

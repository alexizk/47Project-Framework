using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;

namespace _47Project.Nexus.Converters;

public sealed class StatusToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var s = (value as string ?? "").ToLowerInvariant();
        // Keep it subtle: use neutral colors unless resources exist.
        // If theme brushes exist, use them; otherwise fall back to simple colors.
        Brush Try(string key) => (Brush)(App.Current.TryFindResource(key) ?? Brushes.Gray);

        return s switch
        {
            "ok" => Try("App.Success"),
            "error" => Try("App.Error"),
            "blocked" => Try("App.Warning"),
            "skip" => Try("App.SubtleText"),
            "whatif" => Try("App.Accent"),
            "start" => Try("App.Accent"),
            "end" => Try("App.SubtleText"),
            _ => Try("App.SubtleText")
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) => throw new NotSupportedException();
}

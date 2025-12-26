using System;
using System.Globalization;
using System.Windows.Data;

namespace _47Project.Nexus.Converters;

public sealed class StatusToGlyphConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var s = (value?.ToString() ?? "").ToLowerInvariant();
        return s switch
        {
            "running" => "⏳",
            "start" => "⏳",
            "ok" => "✓",
            "error" => "✖",
            "blocked" => "⛔",
            "whatif" => "↷",
            "skip" => "⤼",
            _ => "•"
        };
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => throw new NotSupportedException();
}

using System;
using System.Linq;
using System.Windows;

namespace _47Project.Nexus.Services;

public sealed class ThemeService
{
    // Theme dictionaries live here.
    private static readonly string[] KnownThemes = { "Minimal", "Cyber", "MatrixCyberMinimal" };

    public string CurrentTheme { get; private set; } = "MatrixCyberMinimal";

    public void ApplyTheme(string themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName))
            themeName = "MatrixCyberMinimal";

        // Normalize
        themeName = KnownThemes.Contains(themeName, StringComparer.OrdinalIgnoreCase)
            ? KnownThemes.First(t => t.Equals(themeName, StringComparison.OrdinalIgnoreCase))
            : "MatrixCyberMinimal";

        var app = Application.Current;
        if (app == null) return;

        var merged = app.Resources.MergedDictionaries;

        // Remove any previously-applied theme dictionaries.
        for (int i = merged.Count - 1; i >= 0; i--)
        {
            var src = merged[i].Source?.ToString() ?? "";
            if (KnownThemes.Any(t => src.EndsWith($"/{t}.xaml", StringComparison.OrdinalIgnoreCase) ||
                                     src.EndsWith($"\\{t}.xaml", StringComparison.OrdinalIgnoreCase)))
            {
                merged.RemoveAt(i);
            }
        }

        merged.Add(new ResourceDictionary
        {
            Source = new Uri($"Resources/Themes/{themeName}.xaml", UriKind.Relative)
        });

        CurrentTheme = themeName;
    }
}

using System;
using System.IO;
using System.Text.Json;
using _47Project.Nexus.Models;

namespace _47Project.Nexus.Services;

public sealed class SettingsService
{
    private readonly JsonSerializerOptions _opts = new()
    {
        PropertyNamingPolicy = null,
        WriteIndented = true
    };

    public string SettingsPath { get; }

    public SettingsService()
    {
        var baseDir = AppContext.BaseDirectory;

        // Portable mode if a marker file exists next to the app.
        var portableMarker = Path.Combine(baseDir, "portable.flag");
        if (File.Exists(portableMarker))
        {
            SettingsPath = Path.Combine(baseDir, "ui_settings.json");
            return;
        }

        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var dir = Path.Combine(appData, "47ProjectNexus");
        Directory.CreateDirectory(dir);
        SettingsPath = Path.Combine(dir, "ui_settings.json");
    }

    public UiSettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath))
                return new UiSettings();

            var json = File.ReadAllText(SettingsPath);
            var s = JsonSerializer.Deserialize<UiSettings>(json, _opts);
            return s ?? new UiSettings();
        }
        catch
        {
            return new UiSettings();
        }
    }

    public void Save(UiSettings settings)
    {
        var json = JsonSerializer.Serialize(settings, _opts);
        File.WriteAllText(SettingsPath, json);
    }
}

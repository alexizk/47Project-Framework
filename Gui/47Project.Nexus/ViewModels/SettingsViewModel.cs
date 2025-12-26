using System;
using System.Collections.ObjectModel;
using _47Project.Nexus.Common;
using _47Project.Nexus.Models;
using _47Project.Nexus.Services;

namespace _47Project.Nexus.ViewModels;

public sealed class SettingsViewModel : ObservableObject
{
    private readonly SettingsService _settingsService;
    private readonly ThemeService _themeService;

    public UiSettings Ui { get; }

    public ObservableCollection<string> ThemeOptions { get; } = new()
    {
        "Minimal",
        "Cyber",
        "MatrixCyberMinimal"
    };

    public SettingsViewModel(SettingsService settingsService, ThemeService themeService)
    {
        _settingsService = settingsService;
        _themeService = themeService;

        Ui = _settingsService.Load();

        // Apply theme on startup
        _themeService.ApplyTheme(Ui.Theme);
    }

    public string SelectedTheme
    {
        get => Ui.Theme;
        set
        {
            if (Ui.Theme == value) return;
            Ui.Theme = value;
            OnPropertyChanged();
            _themeService.ApplyTheme(Ui.Theme);
            Save();
        }
    }

    public bool MatrixRainEnabled
    {
        get => Ui.MatrixRainEnabled;
        set
        {
            if (Ui.MatrixRainEnabled == value) return;
            Ui.MatrixRainEnabled = value;
            OnPropertyChanged();
            Save();
        }
    }

    public double MatrixRainIntensity
    {
        get => Ui.MatrixRainIntensity;
        set
        {
            var v = Math.Clamp(value, 0.0, 1.0);
            if (Math.Abs(Ui.MatrixRainIntensity - v) < 0.0001) return;
            Ui.MatrixRainIntensity = v;
            OnPropertyChanged();
            Save();
        }
    }

    public bool AutoScrollLogs
    {
        get => Ui.AutoScrollLogs;
        set
        {
            if (Ui.AutoScrollLogs == value) return;
            Ui.AutoScrollLogs = value;
            OnPropertyChanged();
            Save();
        }
    }

    public string SettingsPath => _settingsService.SettingsPath;

    private void Save()
    {
        try { _settingsService.Save(Ui); }
        catch { /* ignore */ }
    }
}

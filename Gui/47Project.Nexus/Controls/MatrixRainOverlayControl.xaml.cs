using System;
using System.Collections.Generic;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;

namespace _47Project.Nexus.Controls;

public partial class MatrixRainOverlayControl : UserControl
{
    public static readonly DependencyProperty EnabledProperty =
        DependencyProperty.Register(nameof(Enabled), typeof(bool), typeof(MatrixRainOverlayControl),
            new PropertyMetadata(false, (_, __) => { }));

    public static readonly DependencyProperty IntensityProperty =
        DependencyProperty.Register(nameof(Intensity), typeof(double), typeof(MatrixRainOverlayControl),
            new PropertyMetadata(0.22, (_, __) => { }));

    public bool Enabled
    {
        get => (bool)GetValue(EnabledProperty);
        set => SetValue(EnabledProperty, value);
    }

    public double Intensity
    {
        get => (double)GetValue(IntensityProperty);
        set => SetValue(IntensityProperty, value);
    }

    private readonly DispatcherTimer _timer;
    private readonly Random _rng = new();

    private readonly List<Drop> _drops = new();
    private const string Glyphs = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%&*+=<>?";

    public MatrixRainOverlayControl()
    {
        InitializeComponent();

        _timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(60)
        };
        _timer.Tick += (_, _) => Tick();

        Loaded += (_, _) =>
        {
            SizeChanged += (_, _) => RebuildIfNeeded(force: true);
            _timer.Start();
        };

        Unloaded += (_, _) => _timer.Stop();
    }

    private void Tick()
    {
        if (!Enabled)
        {
            RootCanvas.Children.Clear();
            _drops.Clear();
            return;
        }

        RebuildIfNeeded(force: false);

        var h = ActualHeight;
        if (h <= 0) return;

        foreach (var d in _drops)
        {
            d.Y += d.Speed;
            if (d.Y > h + 20)
            {
                d.Y = -_rng.Next(20, 200);
                d.TextBlock.Text = RandomGlyph();
                d.TextBlock.Opacity = 0.25 + _rng.NextDouble() * 0.55;
            }
            else
            {
                // Occasionally change glyph mid-flight for "rain" feel
                if (_rng.NextDouble() < 0.06)
                    d.TextBlock.Text = RandomGlyph();
            }

            Canvas.SetTop(d.TextBlock, d.Y);
        }
    }

    private void RebuildIfNeeded(bool force)
    {
        if (!Enabled) return;

        var w = ActualWidth;
        var h = ActualHeight;
        if (w <= 0 || h <= 0) return;

        // Intensity determines density (roughly 0..1 -> 10..90 drops)
        var target = (int)(10 + Math.Clamp(Intensity, 0.0, 1.0) * 80);

        if (!force && Math.Abs(_drops.Count - target) < 6)
            return;

        RootCanvas.Children.Clear();
        _drops.Clear();

        // Use accent brush if available; fallback to green.
        var accent = TryFindResource("App.Accent") as Brush ?? new SolidColorBrush(Color.FromArgb(255, 0, 255, 102));

        for (int i = 0; i < target; i++)
        {
            var tb = new TextBlock
            {
                Text = RandomGlyph(),
                Foreground = accent,
                FontFamily = new FontFamily("Consolas"),
                FontSize = 12 + _rng.Next(0, 6),
                Opacity = 0.18 + _rng.NextDouble() * 0.45
            };

            var x = _rng.NextDouble() * Math.Max(1, w);
            var y = _rng.NextDouble() * Math.Max(1, h);

            Canvas.SetLeft(tb, x);
            Canvas.SetTop(tb, y);

            RootCanvas.Children.Add(tb);

            _drops.Add(new Drop
            {
                TextBlock = tb,
                Y = y,
                Speed = 1.0 + _rng.NextDouble() * (2.6 + Intensity * 2.0)
            });
        }
    }

    private string RandomGlyph() => Glyphs[_rng.Next(Glyphs.Length)].ToString();

    private sealed class Drop
    {
        public required TextBlock TextBlock;
        public double Y;
        public double Speed;
    }
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using Microsoft.Win32;
using PomodoroTimer.Models;

namespace PomodoroTimer.Services;

/// <summary>
/// Light/dark palette plus two accents: one for focus, one for breaks.
/// Styles only ever reference the "Accent*" keys; <see cref="SetBreakMode"/>
/// swaps those between the focus and break colors at runtime.
/// </summary>
public static class ThemeManager
{
    public static readonly string[] Palette =
    {
        "#FF6B6B", "#FF8E3C", "#F5C542", "#4ECB71", "#38BDF8", "#6C8CFF", "#B07CFF", "#F472B6",
    };

    // Hand-picked companions for the palette; anything else gets a hue rotation.
    private static readonly Dictionary<string, string> Companions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["#FF6B6B"] = "#38BDF8",
        ["#FF8E3C"] = "#6C8CFF",
        ["#F5C542"] = "#B07CFF",
        ["#4ECB71"] = "#F472B6",
        ["#38BDF8"] = "#FF8E3C",
        ["#6C8CFF"] = "#F5C542",
        ["#B07CFF"] = "#4ECB71",
        ["#F472B6"] = "#4ECB71",
    };

    public static bool IsDark { get; private set; } = true;
    public static bool BreakMode { get; private set; }
    public static Color FocusAccent { get; private set; } = Color.FromRgb(0xFF, 0x6B, 0x6B);
    public static Color BreakAccent { get; private set; } = Color.FromRgb(0x38, 0xBD, 0xF8);
    public static SolidColorBrush FocusAccentBrush { get; private set; } = Frozen(Color.FromRgb(0xFF, 0x6B, 0x6B));
    public static SolidColorBrush BreakAccentBrush { get; private set; } = Frozen(Color.FromRgb(0x38, 0xBD, 0xF8));

    public static void Apply(AppSettings settings) => Apply(settings, BreakMode);

    public static void Apply(AppSettings settings, bool breakMode)
    {
        IsDark = settings.Theme switch
        {
            "Dark" => true,
            "Light" => false,
            _ => IsSystemDark(),
        };

        var app = System.Windows.Application.Current;
        var merged = app.Resources.MergedDictionaries;
        var themeDict = new ResourceDictionary
        {
            Source = new Uri($"pack://application:,,,/Themes/{(IsDark ? "Dark" : "Light")}.xaml"),
        };

        var existing = merged.FirstOrDefault(d => d.Source != null && d.Source.OriginalString.Contains("Themes/"));
        if (existing != null) merged[merged.IndexOf(existing)] = themeDict;
        else merged.Insert(0, themeDict);

        FocusAccent = ParseColor(settings.Accent);
        BreakAccent = ResolveBreakAccent(settings);
        FocusAccentBrush = Frozen(FocusAccent);
        BreakAccentBrush = Frozen(BreakAccent);

        app.Resources["FocusAccentColor"] = FocusAccent;
        app.Resources["FocusAccentBrush"] = FocusAccentBrush;
        app.Resources["BreakAccentColor"] = BreakAccent;
        app.Resources["BreakAccentBrush"] = BreakAccentBrush;

        SetBreakMode(breakMode, force: true);
    }

    /// <summary>Points the shared "Accent*" resources at the focus or the break color.</summary>
    public static void SetBreakMode(bool breakMode, bool force = false)
    {
        if (!force && BreakMode == breakMode) return;
        BreakMode = breakMode;

        var accent = breakMode ? BreakAccent : FocusAccent;
        var app = System.Windows.Application.Current;
        app.Resources["AccentColor"] = accent;
        app.Resources["AccentBrush"] = Frozen(accent);
        app.Resources["AccentHoverBrush"] = Frozen(Blend(accent, Colors.White, 0.12));
        app.Resources["AccentPressedBrush"] = Frozen(Blend(accent, Colors.Black, 0.15));
        app.Resources["AccentSoftBrush"] = Frozen(Color.FromArgb(0x2E, accent.R, accent.G, accent.B));
    }

    public static Color ResolveBreakAccent(AppSettings settings)
    {
        if (string.IsNullOrEmpty(settings.BreakAccent) || settings.BreakAccent.Equals("auto", StringComparison.OrdinalIgnoreCase))
        {
            return Companion(ParseColor(settings.Accent));
        }

        return ParseColor(settings.BreakAccent);
    }

    /// <summary>The break color that "auto" would give for a focus color.</summary>
    public static Color Companion(Color focus)
    {
        if (Companions.TryGetValue(ToHex(focus), out var hex)) return ParseColor(hex);

        // Complementary hue with the same saturation, pulled toward a mid lightness.
        RgbToHsl(focus, out double h, out double s, out double l);
        return HslToRgb((h + 180) % 360, Math.Min(s, 0.85), Math.Clamp(l, 0.5, 0.65));
    }

    public static string ToHex(Color c) => $"#{c.R:X2}{c.G:X2}{c.B:X2}";

    public static Color ParseColor(string hex)
    {
        try
        {
            return (Color)ColorConverter.ConvertFromString(hex);
        }
        catch
        {
            return Color.FromRgb(0xFF, 0x6B, 0x6B);
        }
    }

    private static bool IsSystemDark()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return key?.GetValue("AppsUseLightTheme") is int light && light == 0;
        }
        catch
        {
            return true;
        }
    }

    private static Color Blend(Color a, Color b, double t) => Color.FromRgb(
        (byte)Math.Round(a.R + (b.R - a.R) * t),
        (byte)Math.Round(a.G + (b.G - a.G) * t),
        (byte)Math.Round(a.B + (b.B - a.B) * t));

    private static SolidColorBrush Frozen(Color c)
    {
        var brush = new SolidColorBrush(c);
        brush.Freeze();
        return brush;
    }

    private static void RgbToHsl(Color c, out double h, out double s, out double l)
    {
        double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b));
        l = (max + min) / 2;
        double d = max - min;
        if (d < 1e-6)
        {
            h = 0;
            s = 0;
            return;
        }

        s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
        if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
        else if (max == g) h = (b - r) / d + 2;
        else h = (r - g) / d + 4;
        h *= 60;
    }

    private static Color HslToRgb(double h, double s, double l)
    {
        double c = (1 - Math.Abs(2 * l - 1)) * s;
        double x = c * (1 - Math.Abs(h / 60 % 2 - 1));
        double m = l - c / 2;
        (double r, double g, double b) = h switch
        {
            < 60 => (c, x, 0.0),
            < 120 => (x, c, 0.0),
            < 180 => (0.0, c, x),
            < 240 => (0.0, x, c),
            < 300 => (x, 0.0, c),
            _ => (c, 0.0, x),
        };
        return Color.FromRgb(
            (byte)Math.Round((r + m) * 255),
            (byte)Math.Round((g + m) * 255),
            (byte)Math.Round((b + m) * 255));
    }
}

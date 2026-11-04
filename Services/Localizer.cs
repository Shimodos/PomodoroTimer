using System;
using System.Globalization;
using System.Linq;
using System.Windows;

namespace PomodoroTimer.Services;

/// <summary>
/// UI language. Strings live in Localization/Strings.{code}.xaml and are
/// looked up through application resources, so XAML uses DynamicResource
/// and code uses <see cref="Get"/> / <see cref="Format"/>.
/// </summary>
public static class Localizer
{
    public static readonly string[] Supported = { "en", "uk", "ru" };

    public static string Current { get; private set; } = "en";

    /// <summary>Maps a stored code (possibly empty = auto) to a supported language.</summary>
    public static string Resolve(string? code)
    {
        if (!string.IsNullOrEmpty(code) && Supported.Contains(code)) return code;

        var system = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;
        return system is "ru" or "uk" ? system : "en";
    }

    public static void Apply(string? code)
    {
        Current = Resolve(code);

        var merged = System.Windows.Application.Current.Resources.MergedDictionaries;
        var dict = new ResourceDictionary
        {
            Source = new Uri($"pack://application:,,,/Localization/Strings.{Current}.xaml"),
        };

        var existing = merged.FirstOrDefault(d => d.Source != null && d.Source.OriginalString.Contains("Localization/"));
        if (existing != null) merged[merged.IndexOf(existing)] = dict;
        else merged.Insert(0, dict);
    }

    public static string? TryGet(string key) =>
        System.Windows.Application.Current.TryFindResource(key) as string;

    public static string Get(string key) => TryGet(key) ?? key;

    public static string Format(string key, params object[] args) => string.Format(Get(key), args);

    /// <summary>Picks the One / Few / Many form of a noun for a count.</summary>
    public static string Plural(int n, string prefix)
    {
        string form;
        if (Current == "en")
        {
            form = n == 1 ? "One" : "Many";
        }
        else
        {
            int mod10 = n % 10, mod100 = n % 100;
            if (mod10 == 1 && mod100 != 11) form = "One";
            else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) form = "Few";
            else form = "Many";
        }

        return Get($"{prefix}_{form}");
    }
}

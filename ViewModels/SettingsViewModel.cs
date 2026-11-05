using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using PomodoroTimer.Models;
using PomodoroTimer.Services;

namespace PomodoroTimer.ViewModels;

/// <summary>One swatch in a color picker. Key is what gets stored ("auto" or a hex).</summary>
public sealed record AccentOption(string Key, string Hex, string Label, string? Tip);

public sealed class SettingsViewModel : ObservableObject
{
    private readonly AppSettings _s;

    public SettingsViewModel(AppSettings draft)
    {
        _s = draft;

        foreach (var option in SoundService.BuiltIn()) Sounds.Add(option);
        EnsureOption(_s.WorkEndSound);
        EnsureOption(_s.BreakEndSound);

        RebuildBreakAccents();
    }

    public ObservableCollection<SoundOption> Sounds { get; } = new();

    public IReadOnlyList<AccentOption> Accents { get; } =
        ThemeManager.Palette.Select(hex => new AccentOption(hex, hex, "", null)).ToList();

    /// <summary>"auto" (the companion of the focus color) followed by the palette.</summary>
    public ObservableCollection<AccentOption> BreakAccents { get; } = new();

    private void RebuildBreakAccents()
    {
        var auto = new AccentOption("auto",
            ThemeManager.ToHex(ThemeManager.Companion(ThemeManager.ParseColor(_s.Accent))),
            "A", Localizer.Get("Accent_Auto"));

        if (BreakAccents.Count == 0)
        {
            BreakAccents.Add(auto);
            foreach (var hex in ThemeManager.Palette) BreakAccents.Add(new AccentOption(hex, hex, "", null));
        }
        else
        {
            BreakAccents[0] = auto;
        }

        // Replacing the item drops the ListBox selection; re-announce the value to reselect it.
        OnPropertyChanged(nameof(BreakAccent));
    }

    public AppSettings Draft => _s;

    // Timer
    public int WorkMinutes { get => _s.WorkMinutes; set { _s.WorkMinutes = value; OnPropertyChanged(); NotifyPlan(); } }
    public int ShortBreakMinutes { get => _s.ShortBreakMinutes; set { _s.ShortBreakMinutes = value; OnPropertyChanged(); NotifyPlan(); } }
    public int LongBreakMinutes { get => _s.LongBreakMinutes; set { _s.LongBreakMinutes = value; OnPropertyChanged(); NotifyPlan(); } }
    public int CyclesBeforeLongBreak { get => _s.CyclesBeforeLongBreak; set { _s.CyclesBeforeLongBreak = value; OnPropertyChanged(); NotifyPlan(); } }
    public bool AutoStartBreaks { get => _s.AutoStartBreaks; set { _s.AutoStartBreaks = value; OnPropertyChanged(); } }
    public bool AutoStartWork { get => _s.AutoStartWork; set { _s.AutoStartWork = value; OnPropertyChanged(); } }
    public bool LimitSessions { get => _s.LimitSessions; set { _s.LimitSessions = value; OnPropertyChanged(); NotifyPlan(); } }
    public int TotalSessions { get => _s.TotalSessions; set { _s.TotalSessions = value; OnPropertyChanged(); NotifyPlan(); } }

    /// <summary>"Ends at 17:42" for a run started right now.</summary>
    public string PlanEndText =>
        Schedule.PlannedTotal(_s) is TimeSpan t ? Localizer.Format("Plan_End", Schedule.FormatEnd(t)) : "";

    /// <summary>"8 sessions · 4 h 05 min with breaks, if started now"</summary>
    public string PlanDurationText =>
        Schedule.PlannedTotal(_s) is TimeSpan t
            ? Localizer.Format("Plan_Duration", _s.TotalSessions, Schedule.SessionsWord(_s.TotalSessions), Schedule.FormatDuration(t))
            : "";

    private void NotifyPlan()
    {
        OnPropertyChanged(nameof(PlanEndText));
        OnPropertyChanged(nameof(PlanDurationText));
    }

    // Sound
    public bool SoundEnabled { get => _s.SoundEnabled; set { _s.SoundEnabled = value; OnPropertyChanged(); } }
    public string WorkEndSound { get => _s.WorkEndSound; set { _s.WorkEndSound = value; OnPropertyChanged(); } }
    public string BreakEndSound { get => _s.BreakEndSound; set { _s.BreakEndSound = value; OnPropertyChanged(); } }
    public double Volume { get => _s.Volume; set { _s.Volume = value; OnPropertyChanged(); } }

    // Appearance
    // Theme and accent are applied immediately as a live preview; the dialog
    // reverts them to the saved settings if the user cancels.
    public string Theme
    {
        get => _s.Theme;
        set
        {
            if (_s.Theme == value) return;
            _s.Theme = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(IsThemeSystem));
            OnPropertyChanged(nameof(IsThemeDark));
            OnPropertyChanged(nameof(IsThemeLight));
            ThemeManager.Apply(_s);
        }
    }

    public bool IsThemeSystem { get => Theme == "System"; set { if (value) Theme = "System"; } }
    public bool IsThemeDark { get => Theme == "Dark"; set { if (value) Theme = "Dark"; } }
    public bool IsThemeLight { get => Theme == "Light"; set { if (value) Theme = "Light"; } }

    public string Accent
    {
        get => _s.Accent;
        set
        {
            if (string.IsNullOrEmpty(value) || _s.Accent == value) return;
            _s.Accent = value;
            OnPropertyChanged();
            ThemeManager.Apply(_s);
            RebuildBreakAccents();
        }
    }

    public string BreakAccent
    {
        get => string.IsNullOrEmpty(_s.BreakAccent) ? "auto" : _s.BreakAccent;
        set
        {
            if (string.IsNullOrEmpty(value) || _s.BreakAccent == value) return;
            _s.BreakAccent = value;
            OnPropertyChanged();
            ThemeManager.Apply(_s);
        }
    }

    // Language switches live as well. Converter-based and computed texts don't
    // listen to resource changes, so every binding is refreshed afterwards.
    public string Language
    {
        get => Localizer.Resolve(_s.Language);
        set
        {
            if (Localizer.Resolve(_s.Language) == value && _s.Language == value) return;
            _s.Language = value;
            Localizer.Apply(value);
            foreach (var option in Sounds) option.NotifyNameChanged();
            RebuildBreakAccents();
            OnPropertyChanged(string.Empty);
            LanguageChanged?.Invoke();
        }
    }

    public event Action? LanguageChanged;

    public bool IsLangEn { get => Language == "en"; set { if (value) Language = "en"; } }
    public bool IsLangUk { get => Language == "uk"; set { if (value) Language = "uk"; } }
    public bool IsLangRu { get => Language == "ru"; set { if (value) Language = "ru"; } }

    // System
    public bool NotificationsEnabled { get => _s.NotificationsEnabled; set { _s.NotificationsEnabled = value; OnPropertyChanged(); } }
    public bool ShowOnPhaseEnd { get => _s.ShowOnPhaseEnd; set { _s.ShowOnPhaseEnd = value; OnPropertyChanged(); } }
    public bool AlwaysOnTop { get => _s.AlwaysOnTop; set { _s.AlwaysOnTop = value; OnPropertyChanged(); } }
    public bool MinimizeToTray { get => _s.MinimizeToTray; set { _s.MinimizeToTray = value; OnPropertyChanged(); } }
    public bool CloseToTray { get => _s.CloseToTray; set { _s.CloseToTray = value; OnPropertyChanged(); } }
    public bool StartWithWindows { get => _s.StartWithWindows; set { _s.StartWithWindows = value; OnPropertyChanged(); } }

    /// <summary>Adds a user file to the list (if missing) and returns its option.</summary>
    public SoundOption AddCustomSound(string path)
    {
        var existing = Sounds.FirstOrDefault(o => string.Equals(o.File, path, StringComparison.OrdinalIgnoreCase));
        if (existing != null) return existing;

        var option = new SoundOption(path, false);
        Sounds.Add(option);
        return option;
    }

    private void EnsureOption(string file)
    {
        if (string.IsNullOrEmpty(file)) return;
        if (Sounds.Any(o => string.Equals(o.File, file, StringComparison.OrdinalIgnoreCase))) return;

        if (Path.IsPathRooted(file)) AddCustomSound(file);
    }
}

namespace PomodoroTimer.Models;

public sealed class AppSettings
{
    // Timer
    public int WorkMinutes { get; set; } = 25;
    public int ShortBreakMinutes { get; set; } = 5;
    public int LongBreakMinutes { get; set; } = 15;
    public int CyclesBeforeLongBreak { get; set; } = 4;
    public bool AutoStartBreaks { get; set; } = true;
    public bool AutoStartWork { get; set; } = false;

    // When LimitSessions is on, the timer finishes after TotalSessions work sessions.
    // Adjustable right in the main window (‹ 4 sessions ›, down to ∞ = no limit).
    public bool LimitSessions { get; set; } = true;
    public int TotalSessions { get; set; } = 4;

    // Sound. A bare file name means a built-in sound from the Sounds folder,
    // an absolute path means a user-chosen file.
    public bool SoundEnabled { get; set; } = true;
    public string WorkEndSound { get; set; } = "bell.wav";
    public string BreakEndSound { get; set; } = "chime.wav";
    public double Volume { get; set; } = 0.8;

    // Appearance: "System" | "Dark" | "Light"
    public string Theme { get; set; } = "System";

    // Accent for focus, and a second one for breaks so the running timer is
    // recognizable at a glance. "auto" picks the companion of the focus color.
    public string Accent { get; set; } = "#FF6B6B";
    public string BreakAccent { get; set; } = "auto";

    // "en" | "uk" | "ru"; empty = follow the Windows UI language (falls back to en)
    public string Language { get; set; } = "";

    // System
    public bool NotificationsEnabled { get; set; } = true;
    public bool AlwaysOnTop { get; set; } = false;
    public bool MinimizeToTray { get; set; } = true;
    public bool CloseToTray { get; set; } = true;
    public bool StartWithWindows { get; set; } = false;

    // Window state
    public bool CompactMode { get; set; } = false;
    public double? WindowLeft { get; set; }
    public double? WindowTop { get; set; }

    public AppSettings Clone() => (AppSettings)MemberwiseClone();
}

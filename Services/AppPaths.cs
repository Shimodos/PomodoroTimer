using System;
using System.IO;

namespace PomodoroTimer.Services;

/// <summary>
/// Where settings and logs live. Defaults to %AppData%\PomodoroTimer; the
/// POMODORO_DATA_DIR environment variable overrides it (portable use, tests).
/// </summary>
public static class AppPaths
{
    public static string DataDir { get; } = ResolveDataDir();

    public static string SettingsFile => Path.Combine(DataDir, "settings.json");
    public static string ErrorLog => Path.Combine(DataDir, "error.log");
    public static string ActivityLog => Path.Combine(DataDir, "activity.log");

    private static string ResolveDataDir()
    {
        var custom = Environment.GetEnvironmentVariable("POMODORO_DATA_DIR");
        if (!string.IsNullOrWhiteSpace(custom)) return custom;

        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "PomodoroTimer");
    }
}

using System;
using System.IO;

namespace PomodoroTimer.Services;

/// <summary>
/// Plain-text journal of timer transitions (start, pause, skip, completion…)
/// so that "the session ended by itself" can be traced to its cause.
/// Kept small: trimmed to the last ~200 KB on startup.
/// </summary>
public static class ActivityLog
{
    private const long MaxBytes = 200 * 1024;
    private static bool _trimmed;

    public static void Write(string message)
    {
        try
        {
            Directory.CreateDirectory(AppPaths.DataDir);
            TrimOnce();
            File.AppendAllText(AppPaths.ActivityLog, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}  {message}{Environment.NewLine}");
        }
        catch
        {
            // Diagnostics never break the timer.
        }
    }

    private static void TrimOnce()
    {
        if (_trimmed) return;
        _trimmed = true;

        var info = new FileInfo(AppPaths.ActivityLog);
        if (!info.Exists || info.Length <= MaxBytes) return;

        var text = File.ReadAllText(AppPaths.ActivityLog);
        int cut = text.IndexOf('\n', text.Length - (int)(MaxBytes / 2));
        if (cut > 0) File.WriteAllText(AppPaths.ActivityLog, text[(cut + 1)..]);
    }
}

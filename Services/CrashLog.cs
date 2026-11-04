using System;
using System.IO;

namespace PomodoroTimer.Services;

/// <summary>Appends unhandled exceptions to %AppData%\PomodoroTimer\error.log.</summary>
public static class CrashLog
{
    private static string FilePath => AppPaths.ErrorLog;

    public static void Write(Exception exception)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.AppendAllText(FilePath, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {exception}{Environment.NewLine}{Environment.NewLine}");
        }
        catch
        {
            // Logging must never throw.
        }
    }
}

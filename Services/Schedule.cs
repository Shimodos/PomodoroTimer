using System;
using PomodoroTimer.Models;

namespace PomodoroTimer.Services;

/// <summary>Estimates when a limited run of sessions will finish.</summary>
public static class Schedule
{
    /// <summary>
    /// Time left until the last work session ends, assuming no pauses.
    /// Returns null when sessions are unlimited or the run is already finished.
    /// </summary>
    public static TimeSpan? TimeToFinish(AppSettings s, TimerPhase phase, int completed, TimeSpan remainingCurrent, bool finished)
    {
        int total = s.LimitSessions ? s.TotalSessions : 0;
        if (total <= 0 || finished) return null;

        int cycles = Math.Max(1, s.CyclesBeforeLongBreak);
        var t = remainingCurrent;
        var p = phase;
        int c = completed;

        for (int guard = 0; guard < 10_000; guard++)
        {
            if (p == TimerPhase.Work)
            {
                c++;
                if (c >= total) return t;
                p = c % cycles == 0 ? TimerPhase.LongBreak : TimerPhase.ShortBreak;
            }
            else
            {
                p = TimerPhase.Work;
            }

            t += Duration(s, p);
        }

        return t;
    }

    /// <summary>Full plan from a cold start: first work session through the last one.</summary>
    public static TimeSpan? PlannedTotal(AppSettings s) =>
        TimeToFinish(s, TimerPhase.Work, 0, Duration(s, TimerPhase.Work), false);

    public static TimeSpan Duration(AppSettings s, TimerPhase phase) => phase switch
    {
        TimerPhase.Work => TimeSpan.FromMinutes(Math.Max(1, s.WorkMinutes)),
        TimerPhase.ShortBreak => TimeSpan.FromMinutes(Math.Max(1, s.ShortBreakMinutes)),
        _ => TimeSpan.FromMinutes(Math.Max(1, s.LongBreakMinutes)),
    };

    public static string FormatEnd(TimeSpan left) => (DateTime.Now + left).ToString("HH:mm");

    /// <summary>session / sessions, with Slavic plural forms where needed.</summary>
    public static string SessionsWord(int n) => Localizer.Plural(n, "Sessions");

    /// <summary>"4 h 05 min" in the current language.</summary>
    public static string FormatDuration(TimeSpan t)
    {
        int minutes = (int)Math.Round(t.TotalMinutes);
        int hours = minutes / 60;
        int rest = minutes % 60;
        string h = Localizer.Get("Hours"), m = Localizer.Get("Min");
        if (hours == 0) return $"{rest} {m}";
        return rest == 0 ? $"{hours} {h}" : $"{hours} {h} {rest:00} {m}";
    }
}

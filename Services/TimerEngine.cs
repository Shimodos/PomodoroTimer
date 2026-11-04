using System;
using System.Windows.Threading;

namespace PomodoroTimer.Services;

public enum TimerPhase
{
    Work,
    ShortBreak,
    LongBreak
}

/// <summary>
/// Pomodoro state machine. Time is measured against the wall clock so that a
/// busy UI thread or a sleeping laptop never makes the countdown drift.
/// </summary>
public sealed class TimerEngine
{
    private readonly DispatcherTimer _timer = new() { Interval = TimeSpan.FromMilliseconds(200) };
    private readonly Func<TimerPhase, TimeSpan> _duration;
    private readonly Func<int> _cyclesPerRound;
    private readonly Func<int> _totalSessions;

    private DateTime _endUtc;
    private TimeSpan _remaining;

    /// <param name="totalSessions">Work sessions until the run is finished; 0 means unlimited.</param>
    public TimerEngine(Func<TimerPhase, TimeSpan> duration, Func<int> cyclesPerRound, Func<int> totalSessions)
    {
        _duration = duration;
        _cyclesPerRound = cyclesPerRound;
        _totalSessions = totalSessions;
        _timer.Tick += (_, _) => OnTick();
        Total = _duration(Phase);
        _remaining = Total;
    }

    public event Action? Tick;
    public event Action? StateChanged;
    public event Action<TimerPhase>? PhaseCompleted;

    public TimerPhase Phase { get; private set; } = TimerPhase.Work;
    public bool IsRunning { get; private set; }
    public TimeSpan Total { get; private set; }
    public int CompletedWork { get; private set; }

    /// <summary>True after the last of a limited number of work sessions ended.</summary>
    public bool IsFinished { get; private set; }

    public int CyclesPerRound => Math.Max(1, _cyclesPerRound());

    public int TotalSessions => Math.Max(0, _totalSessions());

    public TimeSpan Remaining
    {
        get
        {
            if (!IsRunning) return _remaining;
            var left = _endUtc - DateTime.UtcNow;
            return left < TimeSpan.Zero ? TimeSpan.Zero : left;
        }
    }

    /// <summary>Work sessions finished in the current round (0..CyclesPerRound).</summary>
    public int FilledInRound
    {
        get
        {
            int f = CompletedWork % CyclesPerRound;
            if (f == 0 && CompletedWork > 0 && (Phase != TimerPhase.Work || IsFinished)) f = CyclesPerRound;
            return f;
        }
    }

    public void Start()
    {
        if (IsRunning) return;
        if (IsFinished) NewRound();
        if (_remaining <= TimeSpan.Zero) _remaining = Total;
        _endUtc = DateTime.UtcNow + _remaining;
        IsRunning = true;
        _timer.Start();
        ActivityLog.Write($"Start {Phase} remaining={Fmt(_remaining)} total={Fmt(Total)} completed={CompletedWork}/{TotalSessions}");
        StateChanged?.Invoke();
    }

    public void Pause()
    {
        if (!IsRunning) return;
        _remaining = Remaining;
        IsRunning = false;
        _timer.Stop();
        ActivityLog.Write($"Pause {Phase} remaining={Fmt(_remaining)}");
        StateChanged?.Invoke();
    }

    public void Toggle()
    {
        if (IsRunning) Pause();
        else Start();
    }

    public void Reset()
    {
        if (IsRunning) ActivityLog.Write($"Reset while running {Phase} remaining={Fmt(Remaining)}");
        _timer.Stop();
        IsRunning = false;
        Total = _duration(Phase);
        _remaining = Total;
        StateChanged?.Invoke();
    }

    public void SetPhase(TimerPhase phase)
    {
        ActivityLog.Write($"SetPhase {Phase} -> {phase} (was running={IsRunning}, remaining={Fmt(Remaining)})");

        if (IsFinished)
        {
            CompletedWork = 0;
            IsFinished = false;
        }

        Phase = phase;
        Reset();
    }

    public void Skip()
    {
        if (IsFinished) return;
        ActivityLog.Write($"Skip {Phase} remaining={Fmt(Remaining)}");
        Advance();
    }

    /// <summary>
    /// After the session limit changed: a finished run continues if the new
    /// limit (or no limit) leaves sessions to do.
    /// </summary>
    public void ReevaluateLimit()
    {
        if (!IsFinished) return;
        if (TotalSessions != 0 && CompletedWork >= TotalSessions) return;

        IsFinished = false;
        Phase = TimerPhase.Work;
        Reset();
    }

    /// <summary>Forgets finished sessions and starts over from the first work session.</summary>
    public void NewRound()
    {
        CompletedWork = 0;
        IsFinished = false;
        Phase = TimerPhase.Work;
        Reset();
    }

    /// <summary>Re-reads durations after settings changed without losing a paused countdown.</summary>
    public void ReloadDurations()
    {
        if (IsRunning) return;
        bool untouched = _remaining == Total;
        Total = _duration(Phase);
        _remaining = untouched ? Total : (_remaining > Total ? Total : _remaining);
        ActivityLog.Write($"ReloadDurations {Phase} total={Fmt(Total)} remaining={Fmt(_remaining)}");
        StateChanged?.Invoke();
    }

    private void Advance()
    {
        var from = Phase;

        if (Phase == TimerPhase.Work)
        {
            CompletedWork++;

            if (TotalSessions > 0 && CompletedWork >= TotalSessions)
            {
                IsFinished = true;
                Phase = TimerPhase.Work;
                Reset();
                ActivityLog.Write($"Finished: {CompletedWork}/{TotalSessions} sessions done");
                return;
            }

            Phase = CompletedWork % CyclesPerRound == 0 ? TimerPhase.LongBreak : TimerPhase.ShortBreak;
        }
        else
        {
            Phase = TimerPhase.Work;
        }

        Reset();
        ActivityLog.Write($"Advance {from} -> {Phase} completed={CompletedWork}/{TotalSessions}");
    }

    private void OnTick()
    {
        if (Remaining <= TimeSpan.Zero)
        {
            _timer.Stop();
            IsRunning = false;
            var finished = Phase;
            ActivityLog.Write($"Completed {finished} by countdown (end={_endUtc.ToLocalTime():HH:mm:ss.fff})");
            Advance();
            PhaseCompleted?.Invoke(finished);
        }
        else
        {
            Tick?.Invoke();
        }
    }

    private static string Fmt(TimeSpan t) => $"{(int)t.TotalMinutes:00}:{t.Seconds:00}";
}

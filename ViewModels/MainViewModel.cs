using System;
using System.Collections.ObjectModel;
using System.Windows.Input;
using PomodoroTimer.Models;
using PomodoroTimer.Services;

namespace PomodoroTimer.ViewModels;

public sealed class CycleDot
{
    public CycleDot(bool filled, bool current)
    {
        Filled = filled;
        Current = current;
    }

    public bool Filled { get; }
    public bool Current { get; }
}

/// <summary>
/// Main window state. The engine owns the *active* phase and its countdown;
/// the tabs select a *viewed* phase, which is only a way to look at (and edit)
/// another phase's duration without touching the running timer.
/// </summary>
public sealed class MainViewModel : ObservableObject, IDisposable
{
    private const int MaxLoops = 16;
    private const int MinMinutes = 1;
    private const int MaxMinutes = 180;
    private const int EditStep = 5;

    private readonly TimerEngine _engine;
    private readonly SoundService _sound = new();
    private readonly TrayService _tray = new();

    private string _timeText = "25:00";
    private double _progress = 1;
    private string _phaseTitle = "";
    private string _statusText = "";
    private string _activeInfo = "";
    private string _sessionLabel = "";
    private bool _isRunning;
    private bool _isCompact;
    private bool _isTopmost;
    private bool _isEditing;
    private int _editMinutes = 25;
    private TimerPhase _viewedPhase = TimerPhase.Work;
    private string _dotsKey = "";

    private static AppSettings S => SettingsService.Current;

    public MainViewModel()
    {
        _engine = new TimerEngine(
            phase => Schedule.Duration(S, phase),
            () => S.CyclesBeforeLongBreak,
            () => S.LimitSessions ? S.TotalSessions : 0);
        _engine.Tick += Refresh;
        _engine.StateChanged += Refresh;
        _engine.PhaseCompleted += OnPhaseCompleted;

        _tray.ShowRequested += () => ShowRequested?.Invoke();
        _tray.ToggleRequested += () => { ActivityLog.Write("UI: tray toggle"); _engine.Toggle(); FollowEngine(); };
        _tray.ExitRequested += () => ExitRequested?.Invoke();

        ToggleCommand = new RelayCommand(TogglePrimary);
        SkipCommand = new RelayCommand(
            _ => { ActivityLog.Write("UI: skip button"); _engine.Skip(); FollowEngine(); },
            _ => IsViewingActive && !_engine.IsFinished);
        ResetCommand = new RelayCommand(
            _ => { ActivityLog.Write("UI: reset button"); _engine.Reset(); },
            _ => IsViewingActive);
        GoToActiveCommand = new RelayCommand(FollowEngine);
        IncreaseLoopsCommand = new RelayCommand(() => ChangeLoops(+1));
        DecreaseLoopsCommand = new RelayCommand(() => ChangeLoops(-1));
        ToggleCompactCommand = new RelayCommand(() => IsCompact = !IsCompact);
        ToggleTopmostCommand = new RelayCommand(() => IsTopmost = !IsTopmost);
        OpenSettingsCommand = new RelayCommand(() => SettingsRequested?.Invoke());
        ExitCommand = new RelayCommand(() => ExitRequested?.Invoke());

        BeginEditCommand = new RelayCommand(_ => BeginEdit(), _ => CanEdit);
        CommitEditCommand = new RelayCommand(CommitEdit);
        CancelEditCommand = new RelayCommand(() => IsEditing = false);
        EditPlusCommand = new RelayCommand(() => EditMinutes += EditStep);
        EditMinusCommand = new RelayCommand(() => EditMinutes -= EditStep);

        _isCompact = S.CompactMode;
        _isTopmost = S.AlwaysOnTop;

        LocalizeTray();
        Refresh();
    }

    public event Action? ShowRequested;
    public event Action? SettingsRequested;
    public event Action? ExitRequested;

    public ObservableCollection<CycleDot> CycleDots { get; } = new();

    public ICommand ToggleCommand { get; }
    public ICommand SkipCommand { get; }
    public ICommand ResetCommand { get; }
    public ICommand GoToActiveCommand { get; }
    public ICommand IncreaseLoopsCommand { get; }
    public ICommand DecreaseLoopsCommand { get; }
    public ICommand ToggleCompactCommand { get; }
    public ICommand ToggleTopmostCommand { get; }
    public ICommand OpenSettingsCommand { get; }
    public ICommand ExitCommand { get; }
    public ICommand BeginEditCommand { get; }
    public ICommand CommitEditCommand { get; }
    public ICommand CancelEditCommand { get; }
    public ICommand EditPlusCommand { get; }
    public ICommand EditMinusCommand { get; }

    // ---------------------------------------------------------------- display

    public string TimeText { get => _timeText; private set => Set(ref _timeText, value); }
    public double Progress { get => _progress; private set => Set(ref _progress, value); }
    public string PhaseTitle { get => _phaseTitle; private set => Set(ref _phaseTitle, value); }
    public string StatusText { get => _statusText; private set => Set(ref _statusText, value); }
    public string SessionLabel { get => _sessionLabel; private set => Set(ref _sessionLabel, value); }
    public bool IsRunning { get => _isRunning; private set => Set(ref _isRunning, value); }

    /// <summary>"Focus running · 23:41" shown while looking at another tab.</summary>
    public string ActiveInfo
    {
        get => _activeInfo;
        private set
        {
            if (Set(ref _activeInfo, value)) OnPropertyChanged(nameof(ActiveInfoVisible));
        }
    }

    public bool ActiveInfoVisible => _activeInfo.Length > 0;

    /// <summary>Color of the phase that is counting down (not the one being viewed).</summary>
    public System.Windows.Media.Brush ActiveAccentBrush =>
        _engine.Phase == TimerPhase.Work ? ThemeManager.FocusAccentBrush : ThemeManager.BreakAccentBrush;

    public string PlayGlyph => !IsViewingActive ? ""
        : _engine.IsRunning ? ""
        : _engine.IsFinished ? ""
        : "";

    public string PlayText => !IsViewingActive
        ? Localizer.Get(ViewedPhase switch
        {
            TimerPhase.Work => "Start_Work",
            TimerPhase.ShortBreak => "Start_Short",
            _ => "Start_Long",
        })
        : Localizer.Get(_engine.IsRunning ? "Pause" : _engine.IsFinished ? "Restart" : "Start");

    public string LoopsText => S.LimitSessions && S.TotalSessions > 0
        ? $"{S.TotalSessions} {Schedule.SessionsWord(S.TotalSessions)}"
        : $"∞ · {Localizer.Get("Loops_Unlimited")}";

    // ---------------------------------------------------------------- viewed phase (tabs)

    public TimerPhase ViewedPhase
    {
        get => _viewedPhase;
        set
        {
            if (!Set(ref _viewedPhase, value)) return;
            IsEditing = false;
            OnPropertyChanged(nameof(IsWorkViewed));
            OnPropertyChanged(nameof(IsShortBreakViewed));
            OnPropertyChanged(nameof(IsLongBreakViewed));
            CommandManager.InvalidateRequerySuggested();
            Refresh();
        }
    }

    public bool IsViewingActive => _viewedPhase == _engine.Phase;

    // Two-way bound to the segmented tabs. A RadioButton being unchecked by its
    // group writes false here, which is ignored; only a check switches the view.
    public bool IsWorkViewed { get => _viewedPhase == TimerPhase.Work; set { if (value) ViewedPhase = TimerPhase.Work; } }
    public bool IsShortBreakViewed { get => _viewedPhase == TimerPhase.ShortBreak; set { if (value) ViewedPhase = TimerPhase.ShortBreak; } }
    public bool IsLongBreakViewed { get => _viewedPhase == TimerPhase.LongBreak; set { if (value) ViewedPhase = TimerPhase.LongBreak; } }

    // Which tab carries the live countdown (shown as a dot when it is not the viewed one).
    public bool IsWorkActive => _engine.Phase == TimerPhase.Work;
    public bool IsShortBreakActive => _engine.Phase == TimerPhase.ShortBreak;
    public bool IsLongBreakActive => _engine.Phase == TimerPhase.LongBreak;

    private void FollowEngine() => ViewedPhase = _engine.Phase;

    // ---------------------------------------------------------------- in-place duration editing

    /// <summary>Editing is offered for a phase that is not counting down right now.</summary>
    public bool CanEdit => !IsCompact && !IsEditing && (!IsViewingActive || !_engine.IsRunning);

    public bool IsEditing
    {
        get => _isEditing;
        private set
        {
            if (!Set(ref _isEditing, value)) return;
            OnPropertyChanged(nameof(CanEdit));
            CommandManager.InvalidateRequerySuggested();
        }
    }

    public int EditMinutes
    {
        get => _editMinutes;
        set => Set(ref _editMinutes, Math.Clamp(value, MinMinutes, MaxMinutes));
    }

    private void BeginEdit()
    {
        EditMinutes = (int)Math.Round(Schedule.Duration(S, _viewedPhase).TotalMinutes);
        IsEditing = true;
    }

    private void CommitEdit()
    {
        int minutes = Math.Clamp(EditMinutes, MinMinutes, MaxMinutes);
        switch (_viewedPhase)
        {
            case TimerPhase.Work: S.WorkMinutes = minutes; break;
            case TimerPhase.ShortBreak: S.ShortBreakMinutes = minutes; break;
            default: S.LongBreakMinutes = minutes; break;
        }

        SettingsService.Save();
        ActivityLog.Write($"UI: duration {_viewedPhase} = {minutes} min");
        _engine.ReloadDurations();
        IsEditing = false;
        RefreshView();
    }

    // ---------------------------------------------------------------- window modes

    public bool IsCompact
    {
        get => _isCompact;
        set
        {
            if (!Set(ref _isCompact, value)) return;
            IsEditing = false;
            OnPropertyChanged(nameof(CanEdit));
            S.CompactMode = value;
            SettingsService.Save();
        }
    }

    public bool IsTopmost
    {
        get => _isTopmost;
        set
        {
            if (!Set(ref _isTopmost, value)) return;
            S.AlwaysOnTop = value;
            SettingsService.Save();
        }
    }

    // ---------------------------------------------------------------- actions

    private void TogglePrimary()
    {
        if (IsViewingActive)
        {
            ActivityLog.Write("UI: play/pause button");
            _engine.Toggle();
        }
        else
        {
            ActivityLog.Write($"UI: start {_viewedPhase} from its tab");
            _engine.SetPhase(_viewedPhase);
            _engine.Start();
        }

        FollowEngine();
    }

    /// <summary>Steps the session limit: 0 means unlimited, then 1..16.</summary>
    private void ChangeLoops(int delta)
    {
        int current = S.LimitSessions ? S.TotalSessions : 0;
        int next = Math.Clamp(current + delta, 0, MaxLoops);
        if (next == current) return;

        S.LimitSessions = next > 0;
        if (next > 0) S.TotalSessions = next;
        SettingsService.Save();
        ActivityLog.Write($"UI: loops {current} -> {next}");

        bool wasFinished = _engine.IsFinished;
        _engine.ReevaluateLimit();
        if (wasFinished && !_engine.IsFinished) FollowEngine();
        RefreshView();
    }

    /// <summary>Called after the settings dialog saved new values.</summary>
    public void ApplySettings()
    {
        _engine.ReloadDurations();
        IsTopmost = S.AlwaysOnTop;
        AutostartService.Apply(S.StartWithWindows);
        RefreshView();
    }

    public void PreviewSoundWithVolume(string file, double volume) => _sound.Play(file, volume);

    /// <summary>Re-renders everything, including language-dependent texts.</summary>
    public void RefreshView()
    {
        LocalizeTray();
        _dotsKey = "";
        OnPropertyChanged(nameof(LoopsText));
        Refresh();
    }

    private void LocalizeTray() => _tray.SetTexts(
        Localizer.Get("Tray_Show"), Localizer.Get("Start"), Localizer.Get("Pause"), Localizer.Get("Tray_Exit"));

    private void OnPhaseCompleted(TimerPhase finished)
    {
        bool wasWork = finished == TimerPhase.Work;

        if (S.SoundEnabled)
        {
            _sound.Play(wasWork ? S.WorkEndSound : S.BreakEndSound, S.Volume);
        }

        if (_engine.IsFinished)
        {
            if (S.NotificationsEnabled)
            {
                _tray.Notify(Localizer.Get("Notify_AllDone_Title"), Localizer.Format("Notify_AllDone_Text", _engine.CompletedWork));
            }

            FollowEngine();
            return;
        }

        if (S.NotificationsEnabled)
        {
            if (wasWork)
            {
                int minutes = _engine.Phase == TimerPhase.LongBreak ? S.LongBreakMinutes : S.ShortBreakMinutes;
                _tray.Notify(Localizer.Get("Notify_WorkDone_Title"), Localizer.Format("Notify_WorkDone_Text", minutes));
            }
            else
            {
                _tray.Notify(Localizer.Get("Notify_BreakDone_Title"), Localizer.Get("Notify_BreakDone_Text"));
            }
        }

        bool autoStart = wasWork ? S.AutoStartBreaks : S.AutoStartWork;
        if (autoStart) _engine.Start();

        FollowEngine();
    }

    // ---------------------------------------------------------------- rendering

    private static string TitleOf(TimerPhase phase) => Localizer.Get(phase switch
    {
        TimerPhase.Work => "Phase_Work",
        TimerPhase.ShortBreak => "Phase_Short",
        _ => "Phase_Long",
    });

    private static string Clock(TimeSpan t)
    {
        int totalSeconds = (int)Math.Ceiling(t.TotalSeconds);
        return $"{totalSeconds / 60:00}:{totalSeconds % 60:00}";
    }

    private void Refresh()
    {
        bool finished = _engine.IsFinished;
        bool viewingActive = IsViewingActive;

        // The whole window takes the color of the phase on screen.
        ThemeManager.SetBreakMode(_viewedPhase != TimerPhase.Work);
        OnPropertyChanged(nameof(ActiveAccentBrush));

        var activeRemaining = _engine.Remaining;
        var activeTotal = _engine.Total;
        string activeClock = finished ? "00:00" : Clock(activeRemaining);

        PhaseTitle = TitleOf(_engine.Phase);
        IsRunning = _engine.IsRunning;

        if (viewingActive)
        {
            TimeText = activeClock;
            Progress = finished || activeTotal.TotalSeconds <= 0
                ? 0
                : Math.Clamp(activeRemaining.TotalSeconds / activeTotal.TotalSeconds, 0, 1);

            StatusText = finished
                ? Localizer.Get("Status_Finished")
                : _engine.IsRunning
                    ? PhaseTitle
                    : Localizer.Format(activeRemaining == activeTotal ? "Status_Ready" : "Status_Paused", PhaseTitle);

            ActiveInfo = "";
        }
        else
        {
            var viewedTotal = Schedule.Duration(S, _viewedPhase);
            TimeText = Clock(viewedTotal);
            Progress = 1;
            StatusText = Localizer.Format("Status_Ready", TitleOf(_viewedPhase));

            bool activeInProgress = !finished && (_engine.IsRunning || activeRemaining != activeTotal);
            ActiveInfo = activeInProgress
                ? Localizer.Format(_engine.IsRunning ? "Active_Running" : "Active_Paused", PhaseTitle, activeClock)
                : "";
        }

        OnPropertyChanged(nameof(PlayGlyph));
        OnPropertyChanged(nameof(PlayText));
        OnPropertyChanged(nameof(CanEdit));
        OnPropertyChanged(nameof(IsWorkViewed));
        OnPropertyChanged(nameof(IsShortBreakViewed));
        OnPropertyChanged(nameof(IsLongBreakViewed));
        OnPropertyChanged(nameof(IsWorkActive));
        OnPropertyChanged(nameof(IsShortBreakActive));
        OnPropertyChanged(nameof(IsLongBreakActive));

        int cycles = _engine.CyclesPerRound;
        int filled = _engine.FilledInRound;
        int current = _engine.Phase == TimerPhase.Work && !finished ? filled : -1;

        SessionLabel = BuildSessionLabel(filled, cycles, finished, activeRemaining);

        string dotsKey = $"{cycles}|{filled}|{current}";
        if (dotsKey != _dotsKey)
        {
            _dotsKey = dotsKey;
            CycleDots.Clear();
            for (int i = 0; i < cycles; i++)
            {
                CycleDots.Add(new CycleDot(i < filled, i == current));
            }
        }

        int minutesLeft = finished ? 0 : (int)Math.Ceiling(activeRemaining.TotalMinutes);
        _tray.Update(
            finished ? "✓" : minutesLeft.ToString(),
            finished ? Localizer.Get("Tray_AllDone") : $"Pomodoro — {PhaseTitle} {activeClock}",
            _engine.Phase == TimerPhase.Work ? ThemeManager.FocusAccent : ThemeManager.BreakAccent,
            _engine.IsRunning);
    }

    private string BuildSessionLabel(int filled, int cycles, bool finished, TimeSpan remaining)
    {
        int totalSessions = _engine.TotalSessions;

        if (totalSessions > 0)
        {
            if (finished)
            {
                return totalSessions == 1
                    ? Localizer.Get("Session_Done")
                    : Localizer.Format("All_Done", totalSessions, Schedule.SessionsWord(totalSessions));
            }

            int number = _engine.Phase == TimerPhase.Work
                ? Math.Min(_engine.CompletedWork + 1, totalSessions)
                : _engine.CompletedWork;
            string prefix = Localizer.Format(
                _engine.Phase == TimerPhase.Work ? "Session_Of" : "Done_Of", number, totalSessions);

            var left = Schedule.TimeToFinish(S, _engine.Phase, _engine.CompletedWork, remaining, finished);
            return left is TimeSpan t
                ? $"{prefix} · {Localizer.Format("Left_Label", Schedule.FormatDuration(t))} · {Localizer.Format("Until", Schedule.FormatEnd(t))}"
                : prefix;
        }

        return _engine.Phase == TimerPhase.Work
            ? Localizer.Format("Session_Of", Math.Min(filled + 1, cycles), cycles)
            : Localizer.Format("Done_Of", filled, cycles);
    }

    public void Dispose()
    {
        _sound.Stop();
        _tray.Dispose();
    }
}

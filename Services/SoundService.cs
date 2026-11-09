using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;

namespace PomodoroTimer.Services;

public sealed class SoundOption : INotifyPropertyChanged
{
    public SoundOption(string file, bool isBuiltIn)
    {
        File = file;
        IsBuiltIn = isBuiltIn;
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public string File { get; }
    public bool IsBuiltIn { get; }

    /// <summary>Localized display name; re-read after the language changes.</summary>
    public string Name => IsBuiltIn
        ? SoundService.DisplayName(File)
        : Localizer.Format("Sound_Custom", Path.GetFileName(File));

    public void NotifyNameChanged() =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Name)));
}

/// <summary>
/// Plays the alert sounds. A MediaPlayer that lived through a system sleep goes silent for good:
/// the file opens, Position advances, MediaFailed never fires, but nothing reaches the speakers.
/// So no player is kept between alerts — every Play gets a fresh one — and the current player is
/// released when Windows is about to suspend.
/// </summary>
public sealed class SoundService : IDisposable
{
    // Order here is the order shown in the settings list.
    private static readonly string[] Order =
    {
        "bell.wav", "chime.wav", "ding.wav", "soft.wav", "marimba.wav", "beep.wav", "digital.wav", "alarm.wav",
    };

    private readonly Dispatcher _dispatcher = Dispatcher.CurrentDispatcher;
    private MediaPlayer? _player;

    public SoundService()
    {
        SystemEvents.PowerModeChanged += OnPowerModeChanged;
    }

    public static string SoundsDir => Path.Combine(AppContext.BaseDirectory, "Sounds");

    public static IReadOnlyList<SoundOption> BuiltIn()
    {
        if (!Directory.Exists(SoundsDir)) return Array.Empty<SoundOption>();

        return Directory.GetFiles(SoundsDir, "*.wav")
            .Select(Path.GetFileName)
            .Where(f => f != null)
            .Select(f => new SoundOption(f!, true))
            .OrderBy(o => SortIndex(o.File))
            .ThenBy(o => o.Name)
            .ToList();
    }

    private static int SortIndex(string file)
    {
        int index = Array.FindIndex(Order, o => string.Equals(o, file, StringComparison.OrdinalIgnoreCase));
        return index < 0 ? int.MaxValue : index;
    }

    /// <summary>"bell.wav" → localized "Bell"; unknown files show their bare name.</summary>
    public static string DisplayName(string file)
    {
        var stem = Path.GetFileNameWithoutExtension(file);
        return Localizer.TryGet("Sound_" + stem.ToLowerInvariant()) ?? stem;
    }

    public static string Resolve(string file) =>
        Path.IsPathRooted(file) ? file : Path.Combine(SoundsDir, file);

    public void Play(string file, double volume)
    {
        var path = Resolve(file);
        if (!File.Exists(path)) return;

        try
        {
            ReleasePlayer();

            var player = new MediaPlayer();
            player.MediaFailed += (_, e) =>
                ActivityLog.Write($"Sound failed: {Path.GetFileName(path)}: {e.ErrorException.Message}");
            player.Open(new Uri(path, UriKind.Absolute));
            player.Volume = Math.Clamp(volume, 0, 1);
            player.Play();
            _player = player;
        }
        catch (Exception e)
        {
            // A broken media file must not take the timer down.
            ActivityLog.Write($"Sound error: {Path.GetFileName(path)}: {e.Message}");
        }
    }

    public void Stop() => ReleasePlayer();

    public void Dispose()
    {
        SystemEvents.PowerModeChanged -= OnPowerModeChanged;
        ReleasePlayer();
    }

    // SystemEvents raises this on its own thread; MediaPlayer must be touched on the thread that created it.
    private void OnPowerModeChanged(object? sender, PowerModeChangedEventArgs e)
    {
        if (e.Mode != PowerModes.Suspend) return;
        ActivityLog.Write("Sound: system suspend, player released");
        _dispatcher.BeginInvoke(ReleasePlayer);
    }

    private void ReleasePlayer()
    {
        var player = _player;
        _player = null;
        if (player == null) return;

        try
        {
            player.Stop();
            player.Close();
        }
        catch
        {
            // Releasing a dead player is best effort.
        }
    }
}

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Windows.Media;

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

public sealed class SoundService
{
    // Order here is the order shown in the settings list.
    private static readonly string[] Order =
    {
        "bell.wav", "chime.wav", "ding.wav", "soft.wav", "marimba.wav", "beep.wav", "digital.wav", "alarm.wav",
    };

    private readonly MediaPlayer _player = new();

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
            _player.Stop();
            _player.Open(new Uri(path, UriKind.Absolute));
            _player.Volume = Math.Clamp(volume, 0, 1);
            _player.Play();
        }
        catch
        {
            // A broken media file must not take the timer down.
        }
    }

    public void Stop() => _player.Stop();
}

using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PomodoroTimer.Services;

/// <summary>
/// Notification-area icon that shows the minutes left and a shrinking ring, plus toast notifications.
/// Uses the WinForms NotifyIcon because WPF has no built-in tray support.
/// </summary>
public sealed class TrayService : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly ToolStripMenuItem _showItem;
    private readonly ToolStripMenuItem _toggleItem;
    private readonly ToolStripMenuItem _exitItem;
    /// <summary>Taskbar buttons are up to 48 px at 200 % scaling; 64 leaves room to downscale cleanly.</summary>
    private const int TaskbarIconSize = 64;

    private IntPtr _hIcon;
    private string _lastKey = "";
    private string _startText = "Start";
    private string _pauseText = "Pause";

    public TrayService()
    {
        var menu = new ContextMenuStrip();
        _showItem = new ToolStripMenuItem("Show", null, (_, _) => ShowRequested?.Invoke());
        _toggleItem = new ToolStripMenuItem(_startText, null, (_, _) => ToggleRequested?.Invoke());
        _exitItem = new ToolStripMenuItem("Exit", null, (_, _) => ExitRequested?.Invoke());
        menu.Items.Add(_showItem);
        menu.Items.Add(_toggleItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_exitItem);

        _icon = new NotifyIcon
        {
            ContextMenuStrip = menu,
            Text = "Pomodoro",
            Visible = true,
        };
        _icon.MouseClick += (_, e) =>
        {
            if (e.Button == MouseButtons.Left) ShowRequested?.Invoke();
        };
    }

    public event Action? ShowRequested;
    public event Action? ToggleRequested;
    public event Action? ExitRequested;

    /// <summary>Menu captions in the current language.</summary>
    public void SetTexts(string show, string start, string pause, string exit)
    {
        _showItem.Text = show;
        _exitItem.Text = exit;
        _startText = start;
        _pauseText = pause;
    }

    /// <param name="progress">Share of the active phase that is left, 0..1; drawn as a ring on the icon.</param>
    /// <returns>The same picture for the taskbar button when the icon was redrawn, otherwise null.</returns>
    public System.Windows.Media.ImageSource? Update(string label, string tooltip, System.Windows.Media.Color accent, bool running, double progress)
    {
        _toggleItem.Text = running ? _pauseText : _startText;

        if (tooltip.Length > 63) tooltip = tooltip[..63];
        _icon.Text = tooltip;

        progress = StatusIcon.Quantize(progress);
        string key = $"{label}|{running}|{accent}|{progress}";
        if (key == _lastKey) return null;
        _lastKey = key;

        using var bmp = StatusIcon.Render(32, label, accent, running, progress);
        var newHandle = bmp.GetHicon();
        _icon.Icon = Icon.FromHandle(newHandle);
        if (_hIcon != IntPtr.Zero) DestroyIcon(_hIcon);
        _hIcon = newHandle;

        using var large = StatusIcon.Render(TaskbarIconSize, label, accent, running, progress);
        return StatusIcon.ToImageSource(large);
    }

    public void Notify(string title, string text)
    {
        _icon.BalloonTipTitle = title;
        _icon.BalloonTipText = text;
        _icon.BalloonTipIcon = ToolTipIcon.None;
        _icon.ShowBalloonTip(5000);
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
        if (_hIcon != IntPtr.Zero)
        {
            DestroyIcon(_hIcon);
            _hIcon = IntPtr.Zero;
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr hIcon);
}

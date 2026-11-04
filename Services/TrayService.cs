using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PomodoroTimer.Services;

/// <summary>
/// Notification-area icon that shows the minutes left, plus toast notifications.
/// Uses the WinForms NotifyIcon because WPF has no built-in tray support.
/// </summary>
public sealed class TrayService : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly ToolStripMenuItem _showItem;
    private readonly ToolStripMenuItem _toggleItem;
    private readonly ToolStripMenuItem _exitItem;
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

    public void Update(string label, string tooltip, System.Windows.Media.Color accent, bool running)
    {
        _toggleItem.Text = running ? _pauseText : _startText;

        if (tooltip.Length > 63) tooltip = tooltip[..63];
        _icon.Text = tooltip;

        string key = $"{label}|{running}|{accent}";
        if (key == _lastKey) return;
        _lastKey = key;

        using var bmp = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);

            var accentColor = Color.FromArgb(accent.R, accent.G, accent.B);
            var rect = new RectangleF(1.5f, 1.5f, 29, 29);

            if (running)
            {
                using var fill = new SolidBrush(accentColor);
                g.FillEllipse(fill, rect);
            }
            else
            {
                using var fill = new SolidBrush(Color.FromArgb(60, 60, 68));
                using var pen = new Pen(accentColor, 2.5f);
                g.FillEllipse(fill, rect);
                g.DrawEllipse(pen, rect);
            }

            float fontSize = label.Length > 2 ? 10f : 13f;
            using var font = new Font("Segoe UI", fontSize, FontStyle.Bold, GraphicsUnit.Pixel);
            using var text = new SolidBrush(Color.White);
            var format = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center,
            };
            g.DrawString(label, font, text, new RectangleF(0, 0.5f, 32, 32), format);
        }

        var newHandle = bmp.GetHicon();
        _icon.Icon = Icon.FromHandle(newHandle);
        if (_hIcon != IntPtr.Zero) DestroyIcon(_hIcon);
        _hIcon = newHandle;
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

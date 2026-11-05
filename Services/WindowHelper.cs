using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace PomodoroTimer.Services;

public static class WindowHelper
{
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    private const int DWMWCP_ROUND = 2;

    /// <summary>Asks DWM (Windows 11) for rounded corners on a borderless window. No-op on Windows 10.</summary>
    public static void EnableRoundedCorners(Window window)
    {
        try
        {
            var handle = new WindowInteropHelper(window).Handle;
            if (handle == IntPtr.Zero) return;
            int preference = DWMWCP_ROUND;
            DwmSetWindowAttribute(handle, DWMWA_WINDOW_CORNER_PREFERENCE, ref preference, sizeof(int));
        }
        catch
        {
            // Older Windows builds don't know the attribute.
        }
    }

    /// <summary>
    /// Puts the window above every other window right now. Windows refuses to activate a
    /// window from a background process (it only flashes the taskbar button), but changing
    /// the Z order is allowed: a HWND_TOPMOST / HWND_NOTOPMOST pulse through SetWindowPos
    /// lifts the window to the front without making it permanently topmost.
    /// Talks to Win32 directly so the Topmost binding of the window stays untouched.
    /// </summary>
    public static void BringToFront(Window window, bool keepTopmost)
    {
        var handle = new WindowInteropHelper(window).Handle;
        if (handle == IntPtr.Zero) return;

        const uint flags = SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW;
        SetWindowPos(handle, HWND_TOPMOST, 0, 0, 0, 0, flags);
        if (!keepTopmost) SetWindowPos(handle, HWND_NOTOPMOST, 0, 0, 0, 0, flags);
    }

    private static readonly IntPtr HWND_TOPMOST = new(-1);
    private static readonly IntPtr HWND_NOTOPMOST = new(-2);
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_SHOWWINDOW = 0x0040;

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hwnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}

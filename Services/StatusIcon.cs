using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Windows.Media.Imaging;

namespace PomodoroTimer.Services;

/// <summary>
/// Draws the status icon shared by the tray and the taskbar button: a disc in the
/// phase color with the minutes left, and a ring around it that shrinks like the
/// ring in the main window.
/// </summary>
public static class StatusIcon
{
    /// <summary>Ring positions per full turn; the icon is redrawn only when the ring moves a step.</summary>
    public const int RingSteps = 60;

    public static double Quantize(double progress) =>
        Math.Round(Math.Clamp(progress, 0, 1) * RingSteps) / RingSteps;

    /// <param name="size">Side of the square bitmap in pixels; the drawing is designed on a 32-px grid.</param>
    /// <param name="progress">Share of the phase that is left, 0..1.</param>
    public static Bitmap Render(int size, string label, System.Windows.Media.Color accent, bool running, double progress)
    {
        var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using var g = Graphics.FromImage(bmp);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.Clear(Color.Transparent);
        g.ScaleTransform(size / 32f, size / 32f);

        var accentColor = Color.FromArgb(accent.R, accent.G, accent.B);
        var outer = new RectangleF(1, 1, 30, 30);

        // Ring in the phase color on a faint track, a gap, then the disc with the number.
        // Nothing here depends on the taskbar being light or dark.
        const float ringWidth = 3f;
        const float gap = 1f;
        var ring = RectangleF.Inflate(outer, -ringWidth / 2, -ringWidth / 2);
        var disc = RectangleF.Inflate(outer, -(ringWidth + gap), -(ringWidth + gap));

        // Running: disc in the phase color. Paused: dark disc.
        using (var fill = new SolidBrush(running ? accentColor : Color.FromArgb(60, 60, 68)))
        {
            g.FillEllipse(fill, disc);
        }

        using (var track = new Pen(Color.FromArgb(80, accentColor), ringWidth))
        {
            g.DrawEllipse(track, ring);
        }

        progress = Math.Clamp(progress, 0, 1);
        if (progress > 0)
        {
            using var arc = new Pen(accentColor, ringWidth);
            if (progress >= 1) g.DrawEllipse(arc, ring);
            else g.DrawArc(arc, ring, -90, (float)(360 * progress));
        }

        float fontSize = label.Length > 2 ? 9.5f : 13f;
        using var font = new Font("Segoe UI", fontSize, FontStyle.Bold, GraphicsUnit.Pixel);
        using var text = new SolidBrush(Color.White);
        using var format = new StringFormat
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
        };
        g.DrawString(label, font, text, new RectangleF(0, 0.5f, 32, 32), format);

        return bmp;
    }

    /// <summary>Copies a GDI+ bitmap into a frozen WPF image (for <c>Window.Icon</c>).</summary>
    public static BitmapSource ToImageSource(Bitmap bmp)
    {
        var data = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try
        {
            var source = BitmapSource.Create(
                bmp.Width, bmp.Height, 96, 96,
                System.Windows.Media.PixelFormats.Bgra32, null,
                data.Scan0, data.Stride * bmp.Height, data.Stride);
            source.Freeze();
            return source;
        }
        finally
        {
            bmp.UnlockBits(data);
        }
    }
}

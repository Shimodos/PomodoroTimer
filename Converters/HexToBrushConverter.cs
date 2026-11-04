using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Media;
using PomodoroTimer.Services;

namespace PomodoroTimer.Converters;

public sealed class HexToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        var brush = new SolidColorBrush(ThemeManager.ParseColor(value as string ?? ""));
        brush.Freeze();
        return brush;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

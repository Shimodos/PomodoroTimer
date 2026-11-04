using System;
using System.Globalization;
using System.Windows.Data;

namespace PomodoroTimer.Converters;

/// <summary>0.8 → "80 %"</summary>
public sealed class PercentConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        value is double d ? $"{Math.Round(d * 100)} %" : "";

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

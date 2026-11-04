using System;
using System.Globalization;
using System.Windows.Data;
using PomodoroTimer.Services;

namespace PomodoroTimer.Converters;

/// <summary>25 → "25 min" in the current language.</summary>
public sealed class MinutesConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture) =>
        $"{value} {Localizer.Get("Min")}";

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}

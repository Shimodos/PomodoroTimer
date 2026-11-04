using System;
using System.Windows;
using Microsoft.Win32;
using PomodoroTimer.Services;
using PomodoroTimer.ViewModels;

namespace PomodoroTimer.Views;

public partial class SettingsWindow : Window
{
    private readonly MainViewModel _main;
    private readonly SettingsViewModel _vm;

    public SettingsWindow(MainViewModel main)
    {
        InitializeComponent();
        _main = main;
        _vm = new SettingsViewModel(SettingsService.Current.Clone());
        _vm.LanguageChanged += () => _main.RefreshView();
        DataContext = _vm;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        WindowHelper.EnableRoundedCorners(this);
    }

    protected override void OnClosed(EventArgs e)
    {
        base.OnClosed(e);

        // Cancel, the close button or Alt+F4: undo the live theme / language preview.
        if (DialogResult != true)
        {
            Localizer.Apply(SettingsService.Current.Language);
            ThemeManager.Apply(SettingsService.Current);
            _main.RefreshView();
        }
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var d = _vm.Draft;
        ActivityLog.Write($"UI: settings saved work={d.WorkMinutes} short={d.ShortBreakMinutes} long={d.LongBreakMinutes} cycles={d.CyclesBeforeLongBreak} limit={d.LimitSessions}/{d.TotalSessions} autoBreak={d.AutoStartBreaks} autoWork={d.AutoStartWork}");
        SettingsService.Replace(_vm.Draft);
        ThemeManager.Apply(_vm.Draft);
        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private void PreviewWork_Click(object sender, RoutedEventArgs e) => _main.PreviewSoundWithVolume(_vm.WorkEndSound, _vm.Volume);

    private void PreviewBreak_Click(object sender, RoutedEventArgs e) => _main.PreviewSoundWithVolume(_vm.BreakEndSound, _vm.Volume);

    private void BrowseWork_Click(object sender, RoutedEventArgs e)
    {
        var file = PickSoundFile();
        if (file != null) _vm.WorkEndSound = _vm.AddCustomSound(file).File;
    }

    private void BrowseBreak_Click(object sender, RoutedEventArgs e)
    {
        var file = PickSoundFile();
        if (file != null) _vm.BreakEndSound = _vm.AddCustomSound(file).File;
    }

    private string? PickSoundFile()
    {
        var dialog = new OpenFileDialog
        {
            Title = Localizer.Get("Dialog_PickSound"),
            Filter = $"{Localizer.Get("Filter_Audio")} (*.wav;*.mp3)|*.wav;*.mp3|{Localizer.Get("Filter_All")} (*.*)|*.*",
            CheckFileExists = true,
        };
        return dialog.ShowDialog(this) == true ? dialog.FileName : null;
    }
}

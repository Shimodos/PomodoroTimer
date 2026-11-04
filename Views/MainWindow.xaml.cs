using System;
using System.ComponentModel;
using System.Windows;
using PomodoroTimer.Services;
using PomodoroTimer.ViewModels;

namespace PomodoroTimer.Views;

public partial class MainWindow : Window
{
    private const double NormalWidth = 340;
    private const double NormalHeight = 540;
    private const double CompactWidth = 250;
    private const double CompactHeight = 300;

    private readonly MainViewModel _vm;
    private bool _exiting;

    public MainWindow(MainViewModel vm)
    {
        InitializeComponent();
        _vm = vm;
        DataContext = vm;

        vm.ShowRequested += ShowFromTray;
        vm.SettingsRequested += OpenSettings;
        vm.ExitRequested += ExitApplication;
        vm.PropertyChanged += OnViewModelPropertyChanged;

        RestorePosition();
        ApplyCompact(vm.IsCompact);
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        WindowHelper.EnableRoundedCorners(this);
    }

    protected override void OnStateChanged(EventArgs e)
    {
        base.OnStateChanged(e);
        if (WindowState == WindowState.Minimized && SettingsService.Current.MinimizeToTray)
        {
            Hide();
            WindowState = WindowState.Normal;
        }
    }

    protected override void OnClosing(CancelEventArgs e)
    {
        if (!_exiting && SettingsService.Current.CloseToTray)
        {
            e.Cancel = true;
            Hide();
            return;
        }

        SavePosition();
        base.OnClosing(e);
    }

    protected override void OnLocationChanged(EventArgs e)
    {
        base.OnLocationChanged(e);
        if (IsVisible && WindowState == WindowState.Normal) SavePosition();
    }

    private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(MainViewModel.IsCompact)) ApplyCompact(_vm.IsCompact);

        if (e.PropertyName == nameof(MainViewModel.IsEditing) && _vm.IsEditing)
        {
            // The editor has just become visible; put the caret in it once layout settles.
            Dispatcher.BeginInvoke(new Action(() =>
            {
                EditBox.Focus();
                EditBox.SelectAll();
            }), System.Windows.Threading.DispatcherPriority.Input);
        }
    }

    private void EditBox_PreviewTextInput(object sender, System.Windows.Input.TextCompositionEventArgs e)
    {
        foreach (char c in e.Text)
        {
            if (!char.IsDigit(c))
            {
                e.Handled = true;
                return;
            }
        }
    }

    private void EditBox_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == System.Windows.Input.Key.Enter)
        {
            _vm.CommitEditCommand.Execute(null);
            e.Handled = true;
        }
        else if (e.Key == System.Windows.Input.Key.Escape)
        {
            _vm.CancelEditCommand.Execute(null);
            e.Handled = true;
        }
    }

    private void ApplyCompact(bool compact)
    {
        var hidden = compact ? Visibility.Collapsed : Visibility.Visible;
        Tabs.Visibility = hidden;
        Footer.Visibility = hidden;
        TitleText.Visibility = hidden;
        StatusText.Visibility = hidden;

        RingGrid.Width = RingGrid.Height = compact ? 156 : 236;
        Ring.StrokeThickness = compact ? 7 : 10;
        TimeText.FontSize = compact ? 38 : 58;
        PlayButton.MinWidth = compact ? 110 : 150;
        PlayButton.Height = compact ? 40 : 48;

        // Keep the window anchored at its top-left corner while resizing.
        Width = compact ? CompactWidth : NormalWidth;
        Height = compact ? CompactHeight : NormalHeight;
    }

    private void RestorePosition()
    {
        var s = SettingsService.Current;
        if (s.WindowLeft is not double left || s.WindowTop is not double top) return;

        var area = SystemParameters.VirtualScreenWidth;
        var areaH = SystemParameters.VirtualScreenHeight;
        if (left < -50 || top < -50 || left > area - 100 || top > areaH - 100) return;

        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = left;
        Top = top;
    }

    private void SavePosition()
    {
        if (double.IsNaN(Left) || double.IsNaN(Top)) return;
        SettingsService.Current.WindowLeft = Left;
        SettingsService.Current.WindowTop = Top;
    }

    private void ShowFromTray()
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    private void OpenSettings()
    {
        var dialog = new SettingsWindow(_vm) { Owner = this };
        if (dialog.ShowDialog() == true)
        {
            _vm.ApplySettings();
        }
    }

    private void ExitApplication()
    {
        _exiting = true;
        SavePosition();
        SettingsService.Save();
        System.Windows.Application.Current.Shutdown();
    }

    private void Minimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void Close_Click(object sender, RoutedEventArgs e)
    {
        if (SettingsService.Current.CloseToTray) Hide();
        else ExitApplication();
    }
}

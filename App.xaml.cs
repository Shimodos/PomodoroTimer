using System.Windows;
using System.Windows.Threading;
using PomodoroTimer.Services;
using PomodoroTimer.ViewModels;
using PomodoroTimer.Views;

namespace PomodoroTimer;

public partial class App : Application
{
    private MainViewModel? _viewModel;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        DispatcherUnhandledException += OnUnhandledException;

        SettingsService.Load();
        ActivityLog.Write($"App start v{typeof(App).Assembly.GetName().Version} data={AppPaths.DataDir}");
        Localizer.Apply(SettingsService.Current.Language);
        ThemeManager.Apply(SettingsService.Current);

        _viewModel = new MainViewModel();
        var window = new MainWindow(_viewModel);
        MainWindow = window;
        window.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        ActivityLog.Write("App exit");
        _viewModel?.Dispose();
        SettingsService.Save();
        base.OnExit(e);
    }

    private static void OnUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        CrashLog.Write(e.Exception);
        System.Windows.MessageBox.Show(e.Exception.Message, Localizer.Get("Error_Title"),
            MessageBoxButton.OK, MessageBoxImage.Error);
        e.Handled = true;
    }
}

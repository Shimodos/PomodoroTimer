import AppKit
import Combine
import PomodoroCore

/// Wires settings, strings, theme, view model, main window and the menu bar item together.
/// Settings window (phase 3), notifications, sounds and login item (phase 4) come later.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var env: AppEnvironment!
    private var theme: Theme!
    private var vm: MainViewModel!
    private var mainWindow: MainWindowController!
    private var statusItem: StatusItemController!
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        env = AppEnvironment()
        env.activityLog.write("App start v\(env.version) data=\(env.paths.dataDir.path)")

        theme = Theme()
        theme.apply(env.current)

        vm = MainViewModel(env: env, theme: theme)
        vm.onSettingsRequested = { [weak self] in
            self?.env.activityLog.write("UI: settings requested (window arrives in phase 3)")
        }

        installMainMenu()

        mainWindow = MainWindowController(vm: vm, theme: theme, env: env)
        mainWindow.show()

        statusItem = StatusItemController(env: env)
        statusItem.showRequested = { [weak self] in self?.mainWindow.show() }
        statusItem.toggleRequested = { [weak self] in self?.vm.trayToggle() }
        statusItem.quitRequested = { [weak self] in self?.quit() }

        vm.$snap
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in
                guard let self else { return }
                self.statusItem.update(
                    minutes: snap.minutesLeft, running: snap.isRunning, finished: snap.isFinished,
                    accent: self.theme.accentRGB(for: snap.activePhase), tooltip: snap.trayTooltip)
            }
            .store(in: &subscriptions)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        mainWindow?.prepareForExit()
        env.activityLog.write("App exit")
        env.settings.save()
        statusItem?.remove()
        env.activityLog.flush()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        mainWindow.show()
        return false
    }

    private func quit() {
        mainWindow.prepareForExit()
        NSApp.terminate(nil)
    }

    // MARK: - Main menu

    private func installMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        let settings = NSMenuItem(title: env.L("Settings_Title") + "…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: env.L("Tray_Exit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    @objc private func openSettings() { vm.openSettings() }
}

extension NSColor {
    convenience init(rgb: RGB, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: alpha)
    }
}

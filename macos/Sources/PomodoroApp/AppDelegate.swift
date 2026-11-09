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
    private var sound: SoundPlayer!
    private var notifier: Notifier!
    private var keyMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        env = AppEnvironment()
        env.activityLog.write("App start v\(env.version) data=\(env.paths.dataDir.path)")

        theme = Theme()
        theme.apply(env.current)

        sound = SoundPlayer(log: { [weak self] in self?.env.activityLog.write($0) })
        notifier = Notifier(log: { [weak self] in self?.env.activityLog.write($0) })
        installCrashHandler()

        vm = MainViewModel(env: env, theme: theme)
        vm.playSound = { [weak self] file, volume in self?.sound.play(file, volume: volume) }
        vm.notify = { [weak self] title, body in self?.notifier.notify(title: title, body: body) }
        vm.onSettingsRequested = { [weak self] in self?.showSettings() }

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

        if env.current.notificationsEnabled { notifier.requestAuthorizationIfNeeded() }
        LoginItem.syncAtLaunch(env.current.startWithWindows, log: env.activityLog.write)
        installSpaceKey()

        NSApp.activate(ignoringOtherApps: true)
    }

    /// Space starts / pauses when the main window is key and no text field has focus (SPEC §7.11).
    private func installSpaceKey() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.charactersIgnoringModifiers == " ",
                  event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                  let window = event.window, window === self.mainWindow.window, window.isKeyWindow,
                  !(window.firstResponder is NSTextView) else { return event }
            self.env.activityLog.write("UI: space key")
            self.vm.togglePrimary()
            return nil
        }
    }

    /// SPEC §14: unhandled errors go to error.log; the app keeps running where it can.
    private func installCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let paths = DataPaths.resolve()
            CrashLog(paths: paths).write("\(exception.name.rawValue): \(exception.reason ?? "")\n\(exception.callStackSymbols.joined(separator: "\n"))")
        }
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

    // MARK: - Settings window (SPEC §8)

    private var settingsOpen = false

    private func showSettings() {
        guard !settingsOpen else { return }
        settingsOpen = true
        defer { settingsOpen = false }

        let settingsVM = SettingsViewModel(env: env, theme: theme, player: sound)
        if LoginItem.requiresApproval { settingsVM.loginApprovalHint = env.L("Login_Approval") }
        settingsVM.onLanguageChanged = { [weak self] in self?.relocalize() }
        let controller = SettingsWindowController(vm: settingsVM, theme: theme)
        if controller.run(over: mainWindow.window) {
            vm.applySettings()
            if env.current.notificationsEnabled { notifier.requestAuthorizationIfNeeded() }
            LoginItem.apply(env.current.startWithWindows, log: env.activityLog.write)
        }
        relocalize()
    }

    /// Re-renders every language-dependent string outside SwiftUI bodies.
    private func relocalize() {
        vm.refresh()
        statusItem.relocalize()
        installMainMenu()
    }
}

extension NSColor {
    convenience init(rgb: RGB, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: alpha)
    }
}

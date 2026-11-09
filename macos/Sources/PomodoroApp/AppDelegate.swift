import AppKit
import PomodoroCore

/// Phase 1 skeleton: loads settings and strings, logs the launch, shows an empty
/// 340 × 540 window and puts the item in the menu bar. Windows, views, notifications
/// and sounds arrive in the next phases.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var env: AppEnvironment!
    private var window: NSWindow!
    private var statusItem: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        env = AppEnvironment()
        env.activityLog.write("App start v\(env.version) data=\(env.paths.dataDir.path)")

        installMainMenu()

        window = makeMainWindow()
        window.center()
        window.makeKeyAndOrderFront(nil)

        statusItem = StatusItemController(env: env)
        statusItem.showRequested = { [weak self] in self?.showWindow() }
        statusItem.quitRequested = { NSApp.terminate(nil) }
        statusItem.update(minutes: env.current.workMinutes, running: false, finished: false,
                          accent: AccentMath.focusAccent(env.current), tooltip: "Pomodoro")

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        env.activityLog.write("App exit")
        env.settings.save()
        env.activityLog.flush()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return false
    }

    // MARK: - Window

    private func makeMainWindow() -> NSWindow {
        let size = NSSize(width: 340, height: 540)
        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Pomodoro"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.setContentSize(size)
        w.contentMinSize = size
        w.contentMaxSize = size

        let palette = ThemePalette.dark
        w.backgroundColor = NSColor(rgb: palette.windowBg)
        return w
    }

    private func showWindow() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Main menu

    private func installMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Pomodoro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
}

extension NSColor {
    convenience init(rgb: RGB, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat(rgb.r) / 255, green: CGFloat(rgb.g) / 255, blue: CGFloat(rgb.b) / 255, alpha: alpha)
    }
}

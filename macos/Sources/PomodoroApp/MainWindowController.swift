import AppKit
import SwiftUI
import PomodoroCore

/// Main window class: "minimize to the menu bar" hides instead of miniaturizing (SPEC §7.8).
final class MainWindow: NSWindow {
    /// Returns true when the minimize was turned into a hide.
    var onMiniaturize: () -> Bool = { false }

    override func miniaturize(_ sender: Any?) {
        if onMiniaturize() { return }
        super.miniaturize(sender)
    }
}

/// The main window: fixed size (340 × 540, compact 250 × 300), transparent title bar,
/// SwiftUI content, always-on-top level, compact resize anchored at the top-left,
/// position persistence, hide-on-close (SPEC §7).
final class MainWindowController: NSObject, NSWindowDelegate {
    static let normalSize = NSSize(width: 340, height: 540)
    static let compactSize = NSSize(width: 250, height: 300)

    let window: MainWindow
    private let vm: MainViewModel
    private let env: AppEnvironment
    private var exiting = false

    init(vm: MainViewModel, theme: Theme, env: AppEnvironment) {
        self.vm = vm
        self.env = env

        let size = vm.isCompact ? MainWindowController.compactSize : MainWindowController.normalSize
        window = MainWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = "Pomodoro"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = self
        window.onMiniaturize = { [weak self] in
            guard let self, self.env.current.minimizeToTray else { return false }
            self.hide()
            return true
        }

        let root = MainView(vm: vm).environmentObject(theme)
        let hosting = NSHostingView(rootView: root)
        // The window is sized by us, not by SwiftUI's intrinsic size (which would add the
        // title-bar safe area on top of the fixed 340 × 540 frame).
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        window.setContentSize(size)

        applyTopmost(vm.isTopmost)
        if !restorePosition() { window.center() }

        vm.onCompactChanged = { [weak self] compact in self?.applyCompact(compact) }
        vm.onTopmostChanged = { [weak self] on in self?.applyTopmost(on) }
        vm.onPopUp = { [weak self] in self?.popUp() }
    }

    // MARK: - Show / hide

    func show() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        savePosition()
        window.orderOut(nil)
    }

    /// Phase ended: show the window and lift it above everything once (SPEC §7.8).
    func popUp() {
        show()
        window.orderFrontRegardless()
        if !vm.isTopmost {
            window.level = .floating
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.vm.isTopmost else { return }
                self.window.level = .normal
            }
        }
    }

    func applyTopmost(_ on: Bool) {
        window.level = on ? .floating : .normal
    }

    /// Resizes keeping the top-left corner in place (SPEC §7.7).
    func applyCompact(_ compact: Bool) {
        let size = compact ? MainWindowController.compactSize : MainWindowController.normalSize
        var frame = window.frame
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        frame.size = size
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - size.height)
        window.setFrame(frame, display: true, animate: false)
        window.contentView?.frame = NSRect(origin: .zero, size: size)
        savePosition()
    }

    /// Called for Quit: let the close go through.
    func prepareForExit() {
        exiting = true
        savePosition()
    }

    // MARK: - Position (SPEC §7.9)

    private func restorePosition() -> Bool {
        let s = env.current
        guard let left = s.windowLeft, let top = s.windowTop else { return false }
        let union = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
        guard !union.isNull else { return false }
        let point = NSPoint(x: left, y: top)
        let slack = union.insetBy(dx: 0, dy: 0)
        guard point.x >= slack.minX - 50, point.y >= slack.minY - 50,
              point.x <= slack.maxX - 100, point.y <= slack.maxY - 100 else { return false }
        window.setFrameOrigin(point)
        return true
    }

    private func savePosition() {
        let origin = window.frame.origin
        env.settings.update {
            $0.windowLeft = origin.x
            $0.windowTop = origin.y
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        if window.isVisible, !window.isMiniaturized { savePosition() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if exiting { return true }
        if env.current.closeToTray {
            hide()
            return false
        }
        NSApp.terminate(nil)
        return false
    }
}

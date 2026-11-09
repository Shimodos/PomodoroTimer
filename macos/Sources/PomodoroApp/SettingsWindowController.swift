import AppKit
import SwiftUI
import PomodoroCore

/// Escape closes the settings window like Cancel.
private final class SettingsWindow: NSWindow {
    var onCancel: () -> Void = {}
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

/// The modal settings window (SPEC §8.1): 600 × 680, not resizable, centered over the main
/// window; while it is open the main window ignores mouse input (see `present`).
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let vm: SettingsViewModel
    private let window: SettingsWindow
    private var result = false

    init(vm: SettingsViewModel, theme: Theme) {
        self.vm = vm
        let size = NSSize(width: 600, height: 680)
        window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        window.title = vm.L.get("Settings_Title")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // Dragging by the background would swallow clicks on SwiftUI controls; the title bar still drags.
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.onCancel = { [weak self] in self?.cancel() }

        let root = SettingsView(vm: vm, onCancel: { [weak self] in self?.cancel() }, onSave: { [weak self] in self?.save() })
            .environmentObject(theme)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        window.setContentSize(size)
    }

    private var parent: NSWindow?
    private var completion: ((Bool) -> Void)?

    /// Shows the window centered over `parent` and blocks the parent's mouse input until it closes.
    /// Not `NSApp.runModal`: SwiftUI controls do not get real mouse events reliably inside a modal
    /// run loop. `completion(true)` means Save.
    func present(over parent: NSWindow?, completion: @escaping (Bool) -> Void) {
        self.parent = parent
        self.completion = completion
        if let parent {
            let p = parent.frame
            var frame = window.frame
            frame.origin = NSPoint(x: p.midX - frame.width / 2, y: p.midY - frame.height / 2)
            window.setFrameOrigin(window.constrainFrameRect(frame, to: parent.screen ?? NSScreen.main).origin)
            parent.ignoresMouseEvents = true
        } else {
            window.center()
        }
        window.level = (parent?.level ?? .normal) == .floating ? .floating : .normal
        result = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish() {
        parent?.ignoresMouseEvents = false
        window.orderOut(nil)
        parent?.makeKeyAndOrderFront(nil)
        let done = completion
        completion = nil
        done?(result)
    }

    func save() {
        vm.save()
        result = true
        finish()
    }

    private func cancel() {
        vm.revertPreview()
        result = false
        finish()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancel()
        return false
    }
}

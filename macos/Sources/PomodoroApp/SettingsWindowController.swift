import AppKit
import SwiftUI
import PomodoroCore

/// Escape closes the settings window like Cancel.
private final class SettingsWindow: NSWindow {
    var onCancel: () -> Void = {}
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

/// The modal settings window (SPEC §8.1): 600 × 680, not resizable, centered over the main
/// window, run with `NSApp.runModal` so the main window ignores clicks while it is open.
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
        window.isMovableByWindowBackground = true
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

    /// Shows the window modally, centered over `parent`. Returns true when saved.
    func run(over parent: NSWindow?) -> Bool {
        if let parent {
            let p = parent.frame
            let origin = NSPoint(x: p.midX - window.frame.width / 2, y: p.midY - window.frame.height / 2)
            var frame = window.frame
            frame.origin = origin
            window.setFrameOrigin(window.constrainFrameRect(frame, to: parent.screen ?? NSScreen.main).origin)
        } else {
            window.center()
        }
        window.level = (parent?.level ?? .normal) == .floating ? .floating : .normal
        result = false
        NSApp.runModal(for: window)
        window.orderOut(nil)
        return result
    }

    func save() {
        vm.save()
        result = true
        NSApp.stopModal()
    }


    private func cancel() {
        vm.revertPreview()
        result = false
        NSApp.stopModal()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancel()
        return false
    }
}

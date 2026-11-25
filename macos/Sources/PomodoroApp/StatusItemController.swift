import AppKit
import PomodoroCore

/// The menu bar item (SPEC §9): a drawn disc with the minutes left and a shrinking ring, a
/// tooltip and a click menu Show / Start–Pause / Quit. Also keeps the Dock icon in step.
final class StatusItemController {
    private let env: AppEnvironment
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let toggleEntry: NSMenuItem

    var showRequested: () -> Void = {}
    var settingsRequested: () -> Void = {}
    var toggleRequested: () -> Void = {}
    var quitRequested: () -> Void = {}

    private var lastKey = ""

    init(env: AppEnvironment) {
        self.env = env
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let show = NSMenuItem(title: env.L("Tray_Show"), action: #selector(onShow), keyEquivalent: "")
        toggleEntry = NSMenuItem(title: env.L("Start"), action: #selector(onToggle), keyEquivalent: "")
        let settings = NSMenuItem(title: env.L("Settings_Title") + "…", action: #selector(onSettings), keyEquivalent: "")
        let quit = NSMenuItem(title: env.L("Tray_Exit"), action: #selector(onQuit), keyEquivalent: "")
        for entry in [show, toggleEntry, settings, quit] { entry.target = self }

        menu.addItem(show)
        menu.addItem(toggleEntry)
        menu.addItem(.separator())
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(quit)
        item.menu = menu
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    /// Ring positions per full turn; the images are redrawn only when the ring moves a step.
    static let ringSteps = 60

    /// Re-renders the images only when minutes, running state, accent or the ring step changed.
    /// The same picture, larger, replaces the Dock icon while the app runs (like the taskbar
    /// button on Windows); macOS shows the bundle icon again after the app quits.
    /// - Parameter progress: share of the active phase that is left, 0…1.
    func update(minutes: Int, running: Bool, finished: Bool, accent: RGB, progress: Double, tooltip: String) {
        let text = finished ? "✓" : String(minutes)
        let step = Int((min(max(progress, 0), 1) * Double(StatusItemController.ringSteps)).rounded())
        let key = "\(text)|\(running)|\(accent.hex)|\(step)"
        if key != lastKey {
            lastKey = key
            let left = Double(step) / Double(StatusItemController.ringSteps)
            item.button?.image = StatusItemController.drawImage(
                side: 18, inset: 0, text: text, running: running, accent: accent, progress: left)
            NSApp.applicationIconImage = StatusItemController.drawImage(
                side: 128, inset: 12, text: text, running: running, accent: accent, progress: left)
        }
        item.button?.toolTip = tooltip
        toggleEntry.title = env.L(running ? "Pause" : "Start")
    }

    func relocalize() {
        menu.items[0].title = env.L("Tray_Show")
        menu.items[3].title = env.L("Settings_Title") + "…"
        menu.items[5].title = env.L("Tray_Exit")
    }

    // MARK: - Drawing

    /// The status picture, same design as `Services/StatusIcon.cs` on Windows (a 32-unit grid):
    /// a ring in the accent on a faint track that shrinks clockwise from 12 o'clock with the
    /// time left, a 1-unit gap, then a disc with the minutes (or ✓) in white bold. The disc is
    /// the accent when running and dark grey `#3C3C44` when paused.
    /// - Parameters:
    ///   - side: image side in points (18 for the menu bar, 128 for the Dock).
    ///   - inset: empty margin around the drawing, in points.
    static func drawImage(side: CGFloat, inset: CGFloat, text: String, running: Bool, accent: RGB, progress: Double) -> NSImage {
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { rect in
            let box = rect.insetBy(dx: inset, dy: inset)
            let unit = box.width / 32
            let center = NSPoint(x: box.midX, y: box.midY)
            let accentColor = NSColor(rgb: accent)

            let ringWidth = 3 * unit
            let ringRadius = 15 * unit - ringWidth / 2
            let discRadius = 15 * unit - ringWidth - unit

            let discColor = running ? accentColor : NSColor(rgb: RGB(hex: "#3C3C44")!)
            discColor.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: center.x - discRadius, y: center.y - discRadius,
                width: discRadius * 2, height: discRadius * 2)).fill()

            let track = NSBezierPath(ovalIn: NSRect(
                x: center.x - ringRadius, y: center.y - ringRadius,
                width: ringRadius * 2, height: ringRadius * 2))
            track.lineWidth = ringWidth
            NSColor(rgb: accent, alpha: 80.0 / 255.0).setStroke()
            track.stroke()

            // The arc is built from points instead of an arc call, so that its start (top)
            // and direction (clockwise) depend on nothing but this math: the image is not
            // flipped, y grows upwards, angle 0 is 12 o'clock.
            let left = min(max(progress, 0), 1)
            if left > 0 {
                let arc = NSBezierPath()
                let segments = max(1, Int((left * 120).rounded(.up)))
                for i in 0...segments {
                    let angle = 2 * Double.pi * left * Double(i) / Double(segments)
                    let point = NSPoint(
                        x: center.x + ringRadius * CGFloat(sin(angle)),
                        y: center.y + ringRadius * CGFloat(cos(angle)))
                    if i == 0 { arc.move(to: point) } else { arc.line(to: point) }
                }
                if left >= 1 { arc.close() }
                arc.lineWidth = ringWidth
                arc.lineJoinStyle = .round
                accentColor.setStroke()
                arc.stroke()
            }

            let fontSize: CGFloat = (text.count <= 2 ? 14 : 10) * unit
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: paragraph,
            ]
            let string = NSAttributedString(string: text, attributes: attrs)
            let textSize = string.size()
            let origin = NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
            string.draw(at: origin)
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Actions

    @objc private func onShow() { showRequested() }
    @objc private func onToggle() { toggleRequested() }
    @objc private func onSettings() { settingsRequested() }
    @objc private func onQuit() { quitRequested() }
}

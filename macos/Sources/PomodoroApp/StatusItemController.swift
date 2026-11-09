import AppKit
import PomodoroCore

/// The menu bar item (SPEC §9): a drawn circle with the minutes left, a tooltip and a
/// click menu Show / Start–Pause / Quit. Phase 1 wires Show and Quit; the toggle entry
/// gets its engine in phase 4.
final class StatusItemController {
    private let env: AppEnvironment
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let toggleEntry: NSMenuItem

    var showRequested: () -> Void = {}
    var toggleRequested: () -> Void = {}
    var quitRequested: () -> Void = {}

    private var lastKey = ""

    init(env: AppEnvironment) {
        self.env = env
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let show = NSMenuItem(title: env.L("Tray_Show"), action: #selector(onShow), keyEquivalent: "")
        toggleEntry = NSMenuItem(title: env.L("Start"), action: #selector(onToggle), keyEquivalent: "")
        let quit = NSMenuItem(title: env.L("Tray_Exit"), action: #selector(onQuit), keyEquivalent: "")
        for entry in [show, toggleEntry, quit] { entry.target = self }

        menu.addItem(show)
        menu.addItem(toggleEntry)
        menu.addItem(.separator())
        menu.addItem(quit)
        item.menu = menu
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    /// Re-renders the image only when minutes, running state or accent changed.
    func update(minutes: Int, running: Bool, finished: Bool, accent: RGB, tooltip: String) {
        let text = finished ? "✓" : String(minutes)
        let key = "\(text)|\(running)|\(accent.hex)"
        if key != lastKey {
            lastKey = key
            item.button?.image = StatusItemController.drawImage(text: text, running: running, accent: accent)
        }
        item.button?.toolTip = tooltip
        toggleEntry.title = env.L(running ? "Pause" : "Start")
    }

    func relocalize() {
        menu.items[0].title = env.L("Tray_Show")
        menu.items[3].title = env.L("Tray_Exit")
    }

    // MARK: - Drawing

    /// 18 × 18 pt circle: accent fill when running; dark grey `#3C3C44` with a 2.5-px
    /// accent ring when paused. White bold centered text (minutes or ✓).
    static func drawImage(text: String, running: Bool, accent: RGB) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let accentColor = NSColor(rgb: accent)
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            if running {
                accentColor.setFill()
                circle.fill()
            } else {
                NSColor(rgb: RGB(hex: "#3C3C44")!).setFill()
                circle.fill()
                accentColor.setStroke()
                let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1.25, dy: 1.25))
                ring.lineWidth = 1.5   // ≈ 2.5 px of the 32-px Windows icon scaled to 18 pt
                ring.stroke()
            }

            let fontSize: CGFloat = text.count <= 2 ? 9.5 : 7
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
    @objc private func onQuit() { quitRequested() }
}

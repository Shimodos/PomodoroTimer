// dmg-background.swift <out.png> [title] [subtitle]
// Draws the DMG window background at 2× (1320 × 800 px for a 660 × 400 pt window):
// a serif title, a muted subtitle and an arrow between the two icon slots.
// Icon slots (set by scripts/dmg.sh through Finder): app at (165, 215), Applications at (495, 215).
import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: dmg-background.swift <out.png> [title] [subtitle]\n".data(using: .utf8)!)
    exit(2)
}
let out = args[1]
let title = args.count > 2 ? args[2] : "Install Pomodoro"
let subtitle = args.count > 3 ? args[3] : "Drag to Applications"

let scale: CGFloat = 2
let size = NSSize(width: 660, height: 400)
let pixels = NSSize(width: size.width * scale, height: size.height * scale)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size   // 72 dpi points → Finder shows it at window size on Retina

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
// rep.size is in points while the bitmap is 2× pixels, so the context already draws at 2×.

// Background: the app's light window color.
NSColor(srgbRed: 0xF7 / 255, green: 0xF7 / 255, blue: 0xFA / 255, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()

func draw(_ text: String, font: NSFont, color: NSColor, centerY: CGFloat) {
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: p]
    let s = NSAttributedString(string: text, attributes: attrs)
    let h = s.size().height
    s.draw(in: NSRect(x: 0, y: centerY - h / 2, width: size.width, height: h))
}

let serif = NSFont.systemFont(ofSize: 44, weight: .semibold).fontDescriptor.withDesign(.serif)
    .flatMap { NSFont(descriptor: $0, size: 44) } ?? NSFont.systemFont(ofSize: 44, weight: .semibold)
let ink = NSColor(srgbRed: 0x1B / 255, green: 0x1B / 255, blue: 0x20 / 255, alpha: 1)
let muted = NSColor(srgbRed: 0x6E / 255, green: 0x6E / 255, blue: 0x7A / 255, alpha: 1)

// Coordinates are flipped for drawing text from the top: y measured from the bottom.
draw(title, font: serif, color: ink, centerY: size.height - 82)
draw(subtitle, font: NSFont.systemFont(ofSize: 18), color: muted, centerY: size.height - 130)

// Arrow between the icon slots (icons sit around y = 215 from the top → 185 from the bottom).
let y = size.height - 215
let path = NSBezierPath()
path.lineWidth = 2
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.move(to: NSPoint(x: 290, y: y))
path.line(to: NSPoint(x: 370, y: y))
path.move(to: NSPoint(x: 356, y: y + 9))
path.line(to: NSPoint(x: 370, y: y))
path.line(to: NSPoint(x: 356, y: y - 9))
muted.setStroke()
path.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))

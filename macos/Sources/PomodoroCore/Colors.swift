import Foundation

/// An sRGB color with 8-bit channels and no AppKit dependency. The app converts it
/// to `NSColor` / SwiftUI `Color`; tests compare hex strings.
public struct RGB: Equatable, Hashable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// `#RRGGBB` (also accepts `RRGGBB` and `#AARRGGBB`, ignoring alpha, like WPF's `ColorConverter`).
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt32(s, radix: 16) else { return nil }
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8) & 0xFF)
        b = UInt8(value & 0xFF)
    }

    public var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}

/// Port of the color math in `Services/ThemeManager.cs`.
public enum AccentMath {
    public static let fallback = RGB(0xFF, 0x6B, 0x6B)

    /// Picker order of the eight accents.
    public static let palette: [String] = [
        "#FF6B6B", "#FF8E3C", "#F5C542", "#4ECB71", "#38BDF8", "#6C8CFF", "#B07CFF", "#F472B6",
    ]

    /// Hand-picked companions for the palette; anything else gets a hue rotation.
    static let companions: [String: String] = [
        "#FF6B6B": "#38BDF8",
        "#FF8E3C": "#6C8CFF",
        "#F5C542": "#B07CFF",
        "#4ECB71": "#F472B6",
        "#38BDF8": "#FF8E3C",
        "#6C8CFF": "#F5C542",
        "#B07CFF": "#4ECB71",
        "#F472B6": "#4ECB71",
    ]

    /// An unparsable hex falls back to `#FF6B6B`.
    public static func parse(_ hex: String) -> RGB {
        RGB(hex: hex) ?? fallback
    }

    /// The break color that `"auto"` gives for a focus color.
    public static func companion(of focus: RGB) -> RGB {
        if let hex = companions[focus.hex] { return parse(hex) }
        let (h, s, l) = rgbToHsl(focus)
        return hslToRgb(h: (h + 180).truncatingRemainder(dividingBy: 360), s: min(s, 0.85), l: min(max(l, 0.5), 0.65))
    }

    public static func focusAccent(_ settings: AppSettings) -> RGB {
        parse(settings.accent)
    }

    /// Break accent: companion when `"auto"` or empty, otherwise the stored color.
    public static func breakAccent(_ settings: AppSettings) -> RGB {
        let stored = settings.breakAccent
        if stored.isEmpty || stored.caseInsensitiveCompare("auto") == .orderedSame {
            return companion(of: focusAccent(settings))
        }
        return parse(stored)
    }

    /// Per-channel `a + (b − a) × t`, rounded.
    public static func blend(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
        func mix(_ x: UInt8, _ y: UInt8) -> UInt8 {
            UInt8(min(255, max(0, (Double(x) + (Double(y) - Double(x)) * t).rounded())))
        }
        return RGB(mix(a.r, b.r), mix(a.g, b.g), mix(a.b, b.b))
    }

    public static func hover(_ accent: RGB) -> RGB { blend(accent, RGB(255, 255, 255), 0.12) }
    public static func pressed(_ accent: RGB) -> RGB { blend(accent, RGB(0, 0, 0), 0.15) }
    /// Alpha of `AccentSoft` (0x2E ≈ 18 %); the color itself is the accent.
    public static let softAlpha: Double = Double(0x2E) / 255

    // MARK: - HSL

    static func rgbToHsl(_ c: RGB) -> (h: Double, s: Double, l: Double) {
        let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        let d = mx - mn
        if d < 1e-6 { return (0, 0, l) }
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        h *= 60
        return (h, s, l)
    }

    static func hslToRgb(h: Double, s: Double, l: Double) -> RGB {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        func byte(_ v: Double) -> UInt8 { UInt8(min(255, max(0, ((v + m) * 255).rounded()))) }
        return RGB(byte(r), byte(g), byte(b))
    }
}

/// Port of `Themes/Light.xaml` / `Themes/Dark.xaml` (SPEC §12.1).
public struct ThemePalette: Equatable {
    public var windowBg: RGB
    public var surface: RGB
    public var controlBg: RGB
    public var controlHover: RGB
    public var controlPressed: RGB
    public var track: RGB
    /// Divider and title-button colors carry an alpha; stored as (color, alpha 0…1).
    public var divider: (RGB, Double)
    public var text: RGB
    public var textMuted: RGB
    public var onAccent: RGB
    public var titleBtnHover: (RGB, Double)
    public var titleBtnPressed: (RGB, Double)
    public var thumbBorder: RGB

    public static func == (a: ThemePalette, b: ThemePalette) -> Bool {
        a.windowBg == b.windowBg && a.text == b.text
    }

    public static let light = ThemePalette(
        windowBg: RGB(hex: "#F7F7FA")!,
        surface: RGB(hex: "#FFFFFF")!,
        controlBg: RGB(hex: "#ECECF1")!,
        controlHover: RGB(hex: "#E1E1E8")!,
        controlPressed: RGB(hex: "#D6D6DE")!,
        track: RGB(hex: "#E4E4EA")!,
        divider: (RGB(0, 0, 0), Double(0x14) / 255),
        text: RGB(hex: "#1B1B20")!,
        textMuted: RGB(hex: "#6E6E7A")!,
        onAccent: RGB(hex: "#FFFFFF")!,
        titleBtnHover: (RGB(0, 0, 0), Double(0x12) / 255),
        titleBtnPressed: (RGB(0, 0, 0), Double(0x1F) / 255),
        thumbBorder: RGB(hex: "#FFFFFF")!
    )

    public static let dark = ThemePalette(
        windowBg: RGB(hex: "#1B1B20")!,
        surface: RGB(hex: "#25252C")!,
        controlBg: RGB(hex: "#2A2A32")!,
        controlHover: RGB(hex: "#35353F")!,
        controlPressed: RGB(hex: "#3F3F4A")!,
        track: RGB(hex: "#2E2E37")!,
        divider: (RGB(255, 255, 255), Double(0x1A) / 255),
        text: RGB(hex: "#F4F4F6")!,
        textMuted: RGB(hex: "#9A9AA6")!,
        onAccent: RGB(hex: "#FFFFFF")!,
        titleBtnHover: (RGB(255, 255, 255), Double(0x1A) / 255),
        titleBtnPressed: (RGB(255, 255, 255), Double(0x2B) / 255),
        thumbBorder: RGB(hex: "#1B1B20")!
    )
}

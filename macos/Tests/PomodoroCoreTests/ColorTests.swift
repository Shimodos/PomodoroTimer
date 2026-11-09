import Testing
import Foundation
@testable import PomodoroCore

struct ColorTests {
    @Test func testHexParseAndFormat() {
        expectEqual(RGB(hex: "#FF6B6B"), RGB(0xFF, 0x6B, 0x6B))
        expectEqual(RGB(hex: "ff6b6b")?.hex, "#FF6B6B")
        expectEqual(RGB(hex: "#80FF6B6B")?.hex, "#FF6B6B", "alpha is ignored like WPF's converter")
        expectNil(RGB(hex: "#12"))
        expectNil(RGB(hex: "#GGGGGG"))
        expectNil(RGB(hex: ""))
    }

    @Test func testBadHexFallsBack() {
        expectEqual(AccentMath.parse("nope").hex, "#FF6B6B")
        expectEqual(AccentMath.parse("").hex, "#FF6B6B")
    }

    @Test func testPaletteCompanions() {
        let expected: [String: String] = [
            "#FF6B6B": "#38BDF8", "#FF8E3C": "#6C8CFF", "#F5C542": "#B07CFF", "#4ECB71": "#F472B6",
            "#38BDF8": "#FF8E3C", "#6C8CFF": "#F5C542", "#B07CFF": "#4ECB71", "#F472B6": "#4ECB71",
        ]
        expectEqual(AccentMath.palette.count, 8)
        for focus in AccentMath.palette {
            expectEqual(AccentMath.companion(of: AccentMath.parse(focus)).hex, expected[focus], focus)
        }
        expectEqual(AccentMath.companion(of: AccentMath.parse("#ff6b6b")).hex, "#38BDF8", "lookup is case-insensitive")
    }

    @Test func testHueRotationForUnknownColor() {
        // #123456: h≈210°, s≈0.654, l≈0.204 → h=30°, s=0.654, l clamped to 0.5
        let c = AccentMath.companion(of: RGB(hex: "#123456")!)
        let (h, s, l) = AccentMath.rgbToHsl(c)
        expectEqual(h, 30, accuracy: 1.5)
        expectEqual(s, 0.654, accuracy: 0.02)
        expectEqual(l, 0.5, accuracy: 0.01)
        expectEqual(c.hex, "#D3802C")
    }

    @Test func testHslRoundTrip() {
        for hex in AccentMath.palette {
            let c = RGB(hex: hex)!
            let (h, s, l) = AccentMath.rgbToHsl(c)
            let back = AccentMath.hslToRgb(h: h, s: s, l: l)
            expectLessThanOrEqual(abs(Int(back.r) - Int(c.r)), 1, hex)
            expectLessThanOrEqual(abs(Int(back.g) - Int(c.g)), 1, hex)
            expectLessThanOrEqual(abs(Int(back.b) - Int(c.b)), 1, hex)
        }
        expectEqual(AccentMath.rgbToHsl(RGB(128, 128, 128)).s, 0, "grey has no saturation")
    }

    @Test func testBreakAccentResolution() {
        var s = AppSettings()
        expectEqual(AccentMath.breakAccent(s).hex, "#38BDF8")
        s.breakAccent = ""
        expectEqual(AccentMath.breakAccent(s).hex, "#38BDF8", "empty behaves like auto")
        s.breakAccent = "AUTO"
        expectEqual(AccentMath.breakAccent(s).hex, "#38BDF8")
        s.breakAccent = "#4ECB71"
        expectEqual(AccentMath.breakAccent(s).hex, "#4ECB71")
        s.accent = "#6C8CFF"
        s.breakAccent = "auto"
        expectEqual(AccentMath.breakAccent(s).hex, "#F5C542")
    }

    @Test func testBlendHoverAndPressed() {
        let accent = RGB(hex: "#FF6B6B")!
        // hover: ch + (255 - ch) * 0.12 → FF stays FF, 6B(107) → 124.76 → 125 = 7D
        expectEqual(AccentMath.hover(accent).hex, "#FF7D7D")
        // pressed: ch * 0.85 → 255*0.85=216.75→217=D9, 107*0.85=90.95→91=5B
        expectEqual(AccentMath.pressed(accent).hex, "#D95B5B")
        expectEqual(AccentMath.blend(RGB(0, 0, 0), RGB(255, 255, 255), 0.5).hex, "#808080")
        expectEqual(AccentMath.softAlpha, 46.0 / 255, accuracy: 0.0001)
    }

    @Test func testThemePalettes() {
        expectEqual(ThemePalette.light.windowBg.hex, "#F7F7FA")
        expectEqual(ThemePalette.dark.windowBg.hex, "#1B1B20")
        expectEqual(ThemePalette.light.textMuted.hex, "#6E6E7A")
        expectEqual(ThemePalette.dark.track.hex, "#2E2E37")
        expectEqual(ThemePalette.dark.divider.1, 26.0 / 255, accuracy: 0.0001)
    }
}

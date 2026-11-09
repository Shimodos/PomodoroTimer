import AppKit
import SwiftUI
import PomodoroCore

/// Port of `ThemeManager.cs`: the light / dark palette plus the two accents, and the
/// "break mode" switch that points the shared `accent` at the focus or the break color
/// depending on the phase being viewed. Also drives `NSApp.appearance`.
final class Theme: ObservableObject {
    @Published private(set) var isDark = true
    @Published private(set) var palette = ThemePalette.dark
    @Published private(set) var focusAccent = AccentMath.fallback
    @Published private(set) var breakAccentColor = AccentMath.companion(of: AccentMath.fallback)
    @Published private(set) var breakMode = false

    private var appearanceObservation: NSKeyValueObservation?
    private var themeSetting = "System"

    init() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.followSystemIfNeeded() }
        }
    }

    /// Applies theme and accents from the settings (`ThemeManager.Apply`).
    func apply(_ settings: AppSettings) {
        themeSetting = settings.theme
        switch settings.theme {
        case "Dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "Light": NSApp.appearance = NSAppearance(named: .aqua)
        default: NSApp.appearance = nil
        }
        focusAccent = AccentMath.focusAccent(settings)
        breakAccentColor = AccentMath.breakAccent(settings)
        updateDark()
    }

    /// `ThemeManager.SetBreakMode`: the whole window takes the color of the viewed phase.
    func setBreakMode(_ on: Bool) {
        if breakMode != on { breakMode = on }
    }

    private func followSystemIfNeeded() {
        if themeSetting != "Dark", themeSetting != "Light" { updateDark() }
    }

    private func updateDark() {
        let dark: Bool
        switch themeSetting {
        case "Dark": dark = true
        case "Light": dark = false
        default:
            dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        if dark != isDark || (dark ? ThemePalette.dark : .light) != palette {
            isDark = dark
            palette = dark ? .dark : .light
        }
    }

    // MARK: - Colors for SwiftUI

    var accentRGB: RGB { breakMode ? breakAccentColor : focusAccent }
    var accent: Color { Color(rgb: accentRGB) }
    var accentHover: Color { Color(rgb: AccentMath.hover(accentRGB)) }
    var accentPressed: Color { Color(rgb: AccentMath.pressed(accentRGB)) }
    var accentSoft: Color { Color(rgb: accentRGB).opacity(AccentMath.softAlpha) }
    var focus: Color { Color(rgb: focusAccent) }
    var breakColor: Color { Color(rgb: breakAccentColor) }

    func accent(for phase: TimerPhase) -> Color { phase == .work ? focus : breakColor }
    func accentRGB(for phase: TimerPhase) -> RGB { phase == .work ? focusAccent : breakAccentColor }

    var windowBg: Color { Color(rgb: palette.windowBg) }
    var surface: Color { Color(rgb: palette.surface) }
    var controlBg: Color { Color(rgb: palette.controlBg) }
    var controlHover: Color { Color(rgb: palette.controlHover) }
    var controlPressed: Color { Color(rgb: palette.controlPressed) }
    var track: Color { Color(rgb: palette.track) }
    var text: Color { Color(rgb: palette.text) }
    var textMuted: Color { Color(rgb: palette.textMuted) }
    var onAccent: Color { Color(rgb: palette.onAccent) }
    var titleBtnHover: Color { Color(rgb: palette.titleBtnHover.0).opacity(palette.titleBtnHover.1) }
    var titleBtnPressed: Color { Color(rgb: palette.titleBtnPressed.0).opacity(palette.titleBtnPressed.1) }
    var divider: Color { Color(rgb: palette.divider.0).opacity(palette.divider.1) }
    var thumbBorder: Color { Color(rgb: palette.thumbBorder) }
}

extension Color {
    init(rgb: RGB) {
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255, opacity: 1)
    }
}

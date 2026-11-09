import Foundation

/// Port of `Models/AppSettings.cs`. One flat JSON object with PascalCase keys; a
/// `settings.json` written by the Windows app decodes here unchanged and vice versa.
/// Every key is optional on input (missing → default), unknown keys are ignored.
public struct AppSettings: Codable, Equatable {
    // Timer
    public var workMinutes: Int = 25
    public var shortBreakMinutes: Int = 5
    public var longBreakMinutes: Int = 15
    public var cyclesBeforeLongBreak: Int = 4
    public var autoStartBreaks: Bool = true
    public var autoStartWork: Bool = false

    /// When on, the timer finishes after `totalSessions` work sessions.
    public var limitSessions: Bool = true
    public var totalSessions: Int = 4

    // Sound. A bare file name means a built-in sound, an absolute path a user file.
    public var soundEnabled: Bool = true
    public var workEndSound: String = "bell.wav"
    public var breakEndSound: String = "chime.wav"
    public var volume: Double = 0.8

    /// "System" | "Dark" | "Light"
    public var theme: String = "System"

    /// Focus accent `#RRGGBB`; break accent `"auto"` (companion) or `#RRGGBB`.
    public var accent: String = "#FF6B6B"
    public var breakAccent: String = "auto"

    /// "en" | "uk" | "ru"; empty = follow the system language.
    public var language: String = ""

    // System
    public var notificationsEnabled: Bool = true
    public var showOnPhaseEnd: Bool = true
    public var alwaysOnTop: Bool = false
    public var minimizeToTray: Bool = true
    public var closeToTray: Bool = true
    /// Login item on macOS; the key keeps its Windows name for file compatibility.
    public var startWithWindows: Bool = false

    // Window state
    public var compactMode: Bool = false
    public var windowLeft: Double?
    public var windowTop: Double?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case workMinutes = "WorkMinutes"
        case shortBreakMinutes = "ShortBreakMinutes"
        case longBreakMinutes = "LongBreakMinutes"
        case cyclesBeforeLongBreak = "CyclesBeforeLongBreak"
        case autoStartBreaks = "AutoStartBreaks"
        case autoStartWork = "AutoStartWork"
        case limitSessions = "LimitSessions"
        case totalSessions = "TotalSessions"
        case soundEnabled = "SoundEnabled"
        case workEndSound = "WorkEndSound"
        case breakEndSound = "BreakEndSound"
        case volume = "Volume"
        case theme = "Theme"
        case accent = "Accent"
        case breakAccent = "BreakAccent"
        case language = "Language"
        case notificationsEnabled = "NotificationsEnabled"
        case showOnPhaseEnd = "ShowOnPhaseEnd"
        case alwaysOnTop = "AlwaysOnTop"
        case minimizeToTray = "MinimizeToTray"
        case closeToTray = "CloseToTray"
        case startWithWindows = "StartWithWindows"
        case compactMode = "CompactMode"
        case windowLeft = "WindowLeft"
        case windowTop = "WindowTop"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        workMinutes = try c.decodeIfPresent(Int.self, forKey: .workMinutes) ?? d.workMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        cyclesBeforeLongBreak = try c.decodeIfPresent(Int.self, forKey: .cyclesBeforeLongBreak) ?? d.cyclesBeforeLongBreak
        autoStartBreaks = try c.decodeIfPresent(Bool.self, forKey: .autoStartBreaks) ?? d.autoStartBreaks
        autoStartWork = try c.decodeIfPresent(Bool.self, forKey: .autoStartWork) ?? d.autoStartWork
        limitSessions = try c.decodeIfPresent(Bool.self, forKey: .limitSessions) ?? d.limitSessions
        totalSessions = try c.decodeIfPresent(Int.self, forKey: .totalSessions) ?? d.totalSessions
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        workEndSound = try c.decodeIfPresent(String.self, forKey: .workEndSound) ?? d.workEndSound
        breakEndSound = try c.decodeIfPresent(String.self, forKey: .breakEndSound) ?? d.breakEndSound
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? d.volume
        theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? d.theme
        accent = try c.decodeIfPresent(String.self, forKey: .accent) ?? d.accent
        breakAccent = try c.decodeIfPresent(String.self, forKey: .breakAccent) ?? d.breakAccent
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? d.notificationsEnabled
        showOnPhaseEnd = try c.decodeIfPresent(Bool.self, forKey: .showOnPhaseEnd) ?? d.showOnPhaseEnd
        alwaysOnTop = try c.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? d.alwaysOnTop
        minimizeToTray = try c.decodeIfPresent(Bool.self, forKey: .minimizeToTray) ?? d.minimizeToTray
        closeToTray = try c.decodeIfPresent(Bool.self, forKey: .closeToTray) ?? d.closeToTray
        startWithWindows = try c.decodeIfPresent(Bool.self, forKey: .startWithWindows) ?? d.startWithWindows
        compactMode = try c.decodeIfPresent(Bool.self, forKey: .compactMode) ?? d.compactMode
        windowLeft = try c.decodeIfPresent(Double.self, forKey: .windowLeft)
        windowTop = try c.decodeIfPresent(Double.self, forKey: .windowTop)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(workMinutes, forKey: .workMinutes)
        try c.encode(shortBreakMinutes, forKey: .shortBreakMinutes)
        try c.encode(longBreakMinutes, forKey: .longBreakMinutes)
        try c.encode(cyclesBeforeLongBreak, forKey: .cyclesBeforeLongBreak)
        try c.encode(autoStartBreaks, forKey: .autoStartBreaks)
        try c.encode(autoStartWork, forKey: .autoStartWork)
        try c.encode(limitSessions, forKey: .limitSessions)
        try c.encode(totalSessions, forKey: .totalSessions)
        try c.encode(soundEnabled, forKey: .soundEnabled)
        try c.encode(workEndSound, forKey: .workEndSound)
        try c.encode(breakEndSound, forKey: .breakEndSound)
        try c.encode(volume, forKey: .volume)
        try c.encode(theme, forKey: .theme)
        try c.encode(accent, forKey: .accent)
        try c.encode(breakAccent, forKey: .breakAccent)
        try c.encode(language, forKey: .language)
        try c.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try c.encode(showOnPhaseEnd, forKey: .showOnPhaseEnd)
        try c.encode(alwaysOnTop, forKey: .alwaysOnTop)
        try c.encode(minimizeToTray, forKey: .minimizeToTray)
        try c.encode(closeToTray, forKey: .closeToTray)
        try c.encode(startWithWindows, forKey: .startWithWindows)
        try c.encode(compactMode, forKey: .compactMode)
        // Windows (System.Text.Json) writes nulls for the nullable doubles; keep the keys present.
        try c.encode(windowLeft, forKey: .windowLeft)
        try c.encode(windowTop, forKey: .windowTop)
    }

    /// Mirrors `AppSettings.Clone()`; a struct copy is already a clone, this just reads better at call sites.
    public func clone() -> AppSettings { self }

    /// Minutes of a phase as stored (before the `max(1, …)` guard that `Schedule.duration` applies).
    public func minutes(of phase: TimerPhase) -> Int {
        switch phase {
        case .work: return workMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }

    public mutating func setMinutes(_ minutes: Int, of phase: TimerPhase) {
        switch phase {
        case .work: workMinutes = minutes
        case .shortBreak: shortBreakMinutes = minutes
        case .longBreak: longBreakMinutes = minutes
        }
    }
}

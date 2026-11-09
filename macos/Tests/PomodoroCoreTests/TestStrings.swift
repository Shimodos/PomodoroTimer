import Foundation
@testable import PomodoroCore

/// Inline string tables for tests (subset of Localization/Strings.*.xaml).
enum TestStrings {
    static let en: [String: String] = [
        "Phase_Work": "Focus", "Phase_Short": "Short break", "Phase_Long": "Long break",
        "Start": "Start", "Pause": "Pause", "Restart": "Restart",
        "Status_Ready": "{0} · ready", "Status_Paused": "{0} · paused",
        "Status_Finished": "Done · all sessions complete",
        "Session_Of": "Session {0} of {1}", "Done_Of": "{0} of {1} done", "Until": "until {0}",
        "Session_Done": "Session complete", "Left_Label": "{0} left", "Loops_Unlimited": "no limit",
        "Start_Work": "Start focus", "Start_Short": "Start break", "Start_Long": "Start long break",
        "Active_Running": "{0} running · {1}", "Active_Paused": "{0} paused · {1}",
        "All_Done": "All {0} {1} complete",
        "Notify_AllDone_Text": "{0} of {0} — great work!",
        "Tray_AllDone": "Pomodoro — all sessions complete",
        "Min": "min", "Hours": "h",
        "Sessions_One": "session", "Sessions_Few": "sessions", "Sessions_Many": "sessions",
    ]

    static let uk: [String: String] = [
        "Sessions_One": "сесія", "Sessions_Few": "сесії", "Sessions_Many": "сесій",
        "Min": "хв", "Hours": "год",
    ]

    static let ru: [String: String] = [
        "Sessions_One": "сессия", "Sessions_Few": "сессии", "Sessions_Many": "сессий",
        "Min": "мин", "Hours": "ч",
    ]

    static func localizer(_ language: String = "en", system: [String] = ["en-US"]) -> Localizer {
        let l = Localizer(tables: ["en": en, "uk": uk, "ru": ru], systemLanguages: { system })
        l.apply(language)
        return l
    }
}

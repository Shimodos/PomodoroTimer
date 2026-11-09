import Foundation
import Combine
import PomodoroCore

enum SettingsPage: CaseIterable {
    case timer, sound, look, system

    var titleKey: String {
        switch self {
        case .timer: return "Nav_Timer"
        case .sound: return "Nav_Sound"
        case .look: return "Nav_Look"
        case .system: return "Nav_System"
        }
    }
}

/// Port of `ViewModels/SettingsViewModel.cs`: edits a **draft** copy of the settings.
/// Timer, sound and system values apply on Save; theme, accents and language are a live
/// preview that the window reverts on Cancel (SPEC §8.2).
final class SettingsViewModel: ObservableObject {
    @Published var draft: AppSettings
    @Published var page: SettingsPage = .timer
    @Published private(set) var sounds: [SoundOption]
    /// Set in phase 4 when the login item needs the user's approval.
    @Published var loginApprovalHint: String? = nil

    let env: AppEnvironment
    let theme: Theme
    let player: SoundPlayer
    /// Fired after a live language change so the main window re-renders its strings.
    var onLanguageChanged: () -> Void = {}

    var L: Localizer { env.localizer }

    init(env: AppEnvironment, theme: Theme, player: SoundPlayer) {
        self.env = env
        self.theme = theme
        self.player = player
        draft = env.current.clone()
        sounds = SoundPlayer.builtIn()
        ensureOption(draft.workEndSound)
        ensureOption(draft.breakEndSound)
    }

    // MARK: - Plan box

    var planEndText: String {
        guard let t = Schedule.plannedTotal(draft) else { return "" }
        return L.format("Plan_End", Schedule.formatEnd(t))
    }

    var planDurationText: String {
        guard let t = Schedule.plannedTotal(draft) else { return "" }
        return L.format("Plan_Duration", draft.totalSessions, Schedule.sessionsWord(draft.totalSessions, L), Schedule.formatDuration(t, L))
    }

    // MARK: - Live preview (theme, accents, language)

    func setTheme(_ value: String) {
        guard draft.theme != value else { return }
        draft.theme = value
        theme.apply(draft)
    }

    func setAccent(_ hex: String) {
        guard !hex.isEmpty, draft.accent != hex else { return }
        draft.accent = hex
        theme.apply(draft)
    }

    /// Stored value: `"auto"` or a hex. Empty is shown as auto.
    var breakAccentKey: String { draft.breakAccent.isEmpty ? "auto" : draft.breakAccent }

    func setBreakAccent(_ key: String) {
        guard !key.isEmpty, draft.breakAccent != key else { return }
        draft.breakAccent = key
        theme.apply(draft)
    }

    /// Hex of the "A" swatch: the companion of the current focus accent.
    var autoBreakHex: String { AccentMath.companion(of: AccentMath.parse(draft.accent)).hex }

    var language: String { L.resolve(draft.language) }

    func setLanguage(_ code: String) {
        guard draft.language != code else { return }
        draft.language = code
        L.apply(code)
        objectWillChange.send()
        onLanguageChanged()
    }

    // MARK: - Sounds

    func preview(_ file: String) {
        player.play(file, volume: draft.volume)
    }

    /// Adds a user file to the list (if missing) and returns it.
    @discardableResult
    func addCustomSound(_ path: String) -> SoundOption {
        if let existing = sounds.first(where: { $0.file.caseInsensitiveCompare(path) == .orderedSame }) { return existing }
        let option = SoundOption(file: path, isBuiltIn: false)
        sounds.append(option)
        return option
    }

    private func ensureOption(_ file: String) {
        guard !file.isEmpty, file.hasPrefix("/") else { return }
        addCustomSound(file)
    }

    // MARK: - Save

    /// Writes the draft and logs like `SettingsWindow.Save_Click`.
    func save() {
        let d = draft
        env.activityLog.write("UI: settings saved work=\(d.workMinutes) short=\(d.shortBreakMinutes) long=\(d.longBreakMinutes) cycles=\(d.cyclesBeforeLongBreak) limit=\(d.limitSessions)/\(d.totalSessions) autoBreak=\(d.autoStartBreaks) autoWork=\(d.autoStartWork)")
        env.settings.replace(d)
        theme.apply(d)
    }

    /// Undoes the live preview after Cancel / close / Escape.
    func revertPreview() {
        let saved = env.current
        L.apply(saved.language)
        theme.apply(saved)
        onLanguageChanged()
    }
}

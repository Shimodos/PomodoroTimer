import Foundation
import Combine
import PomodoroCore

struct CycleDot: Identifiable, Equatable {
    let id: Int
    let filled: Bool
    let current: Bool
}

/// Port of `ViewModels/MainViewModel.cs`. The engine owns the *active* phase and its
/// countdown; the tabs select a *viewed* phase, a way to look at (and edit) another
/// phase's duration without touching the running timer.
final class MainViewModel: ObservableObject {
    static let maxLoops = 16
    static let minMinutes = 1
    static let maxMinutes = 180
    static let editStep = 5

    /// Everything the main window draws, recomputed on every tick / state change.
    struct Snapshot {
        var timeText = "25:00"
        var progress: Double = 1
        var phaseTitle = ""
        var statusText = ""
        var activeInfo = ""
        var sessionLabel = ""
        var loopsText = ""
        var primaryText = ""
        var primaryIcon = "play.fill"
        var isRunning = false
        var isFinished = false
        var viewingActive = true
        var activePhase: TimerPhase = .work
        var dots: [CycleDot] = []
        var minutesLeft = 25
        var trayTooltip = ""
    }

    @Published private(set) var snap = Snapshot()
    @Published var viewedPhase: TimerPhase = .work {
        didSet {
            guard viewedPhase != oldValue else { return }
            isEditing = false
            refresh()
        }
    }
    @Published private(set) var isCompact: Bool
    @Published private(set) var isTopmost: Bool
    @Published private(set) var isEditing = false
    @Published var editText = "25"

    let engine: TimerEngine
    let env: AppEnvironment
    let theme: Theme

    // Wired by the window / app delegate.
    var onPopUp: () -> Void = {}
    var onSettingsRequested: () -> Void = {}
    var onCompactChanged: (Bool) -> Void = { _ in }
    var onTopmostChanged: (Bool) -> Void = { _ in }
    // Wired in phase 4 (sounds, notifications).
    var playSound: (String, Double) -> Void = { _, _ in }
    var notify: (String, String) -> Void = { _, _ in }

    private var settings: AppSettings { env.current }
    private var L: Localizer { env.localizer }

    init(env: AppEnvironment, theme: Theme) {
        self.env = env
        self.theme = theme
        let store = env.settings
        engine = TimerEngine(
            duration: { Schedule.duration(store.current, $0) },
            cyclesPerRound: { store.current.cyclesBeforeLongBreak },
            totalSessions: { store.current.limitSessions ? store.current.totalSessions : 0 }
        )
        isCompact = store.current.compactMode
        isTopmost = store.current.alwaysOnTop

        engine.log = { [weak self] in self?.env.activityLog.write($0) }
        engine.onTick = { [weak self] in self?.refresh() }
        engine.onStateChanged = { [weak self] in self?.refresh() }
        engine.onPhaseCompleted = { [weak self] in self?.phaseCompleted($0) }
        refresh()
    }

    // MARK: - Derived

    var isViewingActive: Bool { viewedPhase == engine.phase }
    var canReset: Bool { isViewingActive }
    var canSkip: Bool { isViewingActive && !engine.isFinished }
    /// Editing is offered for a phase that is not counting down right now.
    var canEdit: Bool { !isCompact && !isEditing && (!isViewingActive || !engine.isRunning) }
    var activeAccentRGB: RGB { theme.accentRGB(for: engine.phase) }

    // MARK: - Actions

    func togglePrimary() {
        if isViewingActive {
            env.activityLog.write("UI: play/pause button")
            engine.toggle()
        } else {
            env.activityLog.write("UI: start \(viewedPhase.rawValue) from its tab")
            engine.setPhase(viewedPhase)
            engine.start()
        }
        followEngine()
    }

    func reset() {
        guard canReset else { return }
        env.activityLog.write("UI: reset button")
        engine.reset()
    }

    func skip() {
        guard canSkip else { return }
        env.activityLog.write("UI: skip button")
        engine.skip()
        followEngine()
    }

    func goToActive() { followEngine() }

    func selectTab(_ phase: TimerPhase) { viewedPhase = phase }

    /// Steps the session limit: 0 means unlimited, then 1…16.
    func changeLoops(_ delta: Int) {
        let current = settings.limitSessions ? settings.totalSessions : 0
        let next = min(max(current + delta, 0), MainViewModel.maxLoops)
        if next == current { return }
        env.settings.update {
            $0.limitSessions = next > 0
            if next > 0 { $0.totalSessions = next }
        }
        env.activityLog.write("UI: loops \(current) -> \(next)")
        let wasFinished = engine.isFinished
        engine.reevaluateLimit()
        if wasFinished, !engine.isFinished { followEngine() }
        refresh()
    }

    func toggleCompact() { setCompact(!isCompact) }

    func setCompact(_ value: Bool) {
        guard value != isCompact else { return }
        isCompact = value
        isEditing = false
        env.settings.update { $0.compactMode = value }
        onCompactChanged(value)
        refresh()
    }

    func toggleTopmost() { setTopmost(!isTopmost) }

    func setTopmost(_ value: Bool) {
        guard value != isTopmost else { return }
        isTopmost = value
        env.settings.update { $0.alwaysOnTop = value }
        onTopmostChanged(value)
    }

    func openSettings() { onSettingsRequested() }

    /// Called from the menu bar item (`UI: tray toggle`).
    func trayToggle() {
        env.activityLog.write("UI: tray toggle")
        engine.toggle()
        followEngine()
    }

    // MARK: - In-place duration editing

    var editMinutes: Int {
        min(max(Int(editText) ?? MainViewModel.minMinutes, MainViewModel.minMinutes), MainViewModel.maxMinutes)
    }

    func beginEdit() {
        guard canEdit else { return }
        editText = String(Int((Schedule.duration(settings, viewedPhase) / 60).rounded()))
        isEditing = true
    }

    func editStep(_ delta: Int) {
        let value = min(max((Int(editText) ?? 0) + delta, MainViewModel.minMinutes), MainViewModel.maxMinutes)
        editText = String(value)
    }

    func commitEdit() {
        let minutes = editMinutes
        let phase = viewedPhase
        env.settings.update { $0.setMinutes(minutes, of: phase) }
        env.activityLog.write("UI: duration \(phase.rawValue) = \(minutes) min")
        engine.reloadDurations()
        isEditing = false
        refresh()
    }

    func cancelEdit() { isEditing = false }

    // MARK: - Settings applied

    /// Called after the settings window saved new values (phase 3).
    func applySettings() {
        engine.reloadDurations()
        setTopmost(settings.alwaysOnTop)
        refresh()
    }

    // MARK: - Phase completed (SPEC §6.3)

    private func phaseCompleted(_ finished: TimerPhase) {
        let s = settings
        let wasWork = finished == .work

        if s.soundEnabled {
            playSound(wasWork ? s.workEndSound : s.breakEndSound, s.volume)
        }
        if s.showOnPhaseEnd {
            env.activityLog.write("UI: pop up window on phase end")
            onPopUp()
        }
        if engine.isFinished {
            if s.notificationsEnabled {
                notify(L.get("Notify_AllDone_Title"), L.format("Notify_AllDone_Text", engine.completedWork))
            }
            followEngine()
            return
        }
        if s.notificationsEnabled {
            if wasWork {
                let minutes = engine.phase == .longBreak ? s.longBreakMinutes : s.shortBreakMinutes
                notify(L.get("Notify_WorkDone_Title"), L.format("Notify_WorkDone_Text", minutes))
            } else {
                notify(L.get("Notify_BreakDone_Title"), L.get("Notify_BreakDone_Text"))
            }
        }
        if wasWork ? s.autoStartBreaks : s.autoStartWork { engine.start() }
        followEngine()
    }

    private func followEngine() {
        if viewedPhase != engine.phase { viewedPhase = engine.phase } else { refresh() }
    }

    // MARK: - Rendering

    func refresh() {
        let s = settings
        let finished = engine.isFinished
        let viewingActive = isViewingActive

        theme.setBreakMode(viewedPhase != .work)

        let remaining = engine.remaining
        let total = engine.total
        let activeClock = finished ? "00:00" : SessionText.clock(remaining)

        var n = Snapshot()
        n.phaseTitle = SessionText.phaseTitle(engine.phase, L)
        n.isRunning = engine.isRunning
        n.isFinished = finished
        n.viewingActive = viewingActive
        n.activePhase = engine.phase

        if viewingActive {
            n.timeText = activeClock
            n.progress = finished || total <= 0 ? 0 : min(max(remaining / total, 0), 1)
        } else {
            n.timeText = SessionText.clock(Schedule.duration(s, viewedPhase))
            n.progress = 1
        }
        n.statusText = SessionText.statusText(
            viewingActive: viewingActive, viewedPhase: viewedPhase, activePhase: engine.phase,
            running: engine.isRunning, finished: finished, remaining: remaining, total: total, L)
        n.activeInfo = SessionText.activeInfo(
            viewingActive: viewingActive, activePhase: engine.phase, running: engine.isRunning,
            finished: finished, remaining: remaining, total: total, L)
        n.primaryText = SessionText.primaryButtonText(
            viewingActive: viewingActive, viewedPhase: viewedPhase, running: engine.isRunning, finished: finished, L)
        n.primaryIcon = !viewingActive ? "play.fill" : engine.isRunning ? "pause.fill" : finished ? "arrow.clockwise" : "play.fill"
        n.loopsText = SessionText.loopsText(s, L)

        let cycles = engine.cyclesPerRound
        let filled = engine.filledInRound
        let current = engine.phase == .work && !finished ? filled : -1
        n.dots = (0..<cycles).map { CycleDot(id: $0, filled: $0 < filled, current: $0 == current) }
        n.sessionLabel = SessionText.sessionLabel(settings: s, engine: engine, L)

        n.minutesLeft = SessionText.minutesLeft(remaining, finished: finished)
        n.trayTooltip = SessionText.trayTooltip(phase: engine.phase, remaining: remaining, finished: finished, L)

        snap = n
    }
}

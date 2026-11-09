import Foundation

/// Pure functions from engine state to the texts of the main window
/// (`MainViewModel.cs`: `Clock`, `TitleOf`, `BuildSessionLabel`, `LoopsText`, status
/// and active-info lines). Kept here so the label logic is unit-tested.
public enum SessionText {
    /// `mm:ss` from `ceil(seconds)`; minutes may exceed 59 (`120:00`).
    public static func clock(_ t: TimeInterval) -> String {
        let totalSeconds = Int(t.rounded(.up))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    /// `ceil(remaining in minutes)`, 0 when finished — for the menu bar item.
    public static func minutesLeft(_ remaining: TimeInterval, finished: Bool) -> Int {
        finished ? 0 : Int((remaining / 60).rounded(.up))
    }

    public static func phaseTitle(_ phase: TimerPhase, _ l: Localizer) -> String {
        switch phase {
        case .work: return l.get("Phase_Work")
        case .shortBreak: return l.get("Phase_Short")
        case .longBreak: return l.get("Phase_Long")
        }
    }

    public static func tabCaption(_ phase: TimerPhase, _ l: Localizer) -> String {
        switch phase {
        case .work: return l.get("Tab_Work")
        case .shortBreak: return l.get("Tab_Short")
        case .longBreak: return l.get("Tab_Long")
        }
    }

    /// Caption of the primary button (SPEC §6.1).
    public static func primaryButtonText(
        viewingActive: Bool, viewedPhase: TimerPhase, running: Bool, finished: Bool, _ l: Localizer
    ) -> String {
        if !viewingActive {
            switch viewedPhase {
            case .work: return l.get("Start_Work")
            case .shortBreak: return l.get("Start_Short")
            case .longBreak: return l.get("Start_Long")
            }
        }
        return l.get(running ? "Pause" : finished ? "Restart" : "Start")
    }

    /// Status line under the time (SPEC §6.1).
    public static func statusText(
        viewingActive: Bool, viewedPhase: TimerPhase, activePhase: TimerPhase,
        running: Bool, finished: Bool, remaining: TimeInterval, total: TimeInterval, _ l: Localizer
    ) -> String {
        if !viewingActive { return l.format("Status_Ready", phaseTitle(viewedPhase, l)) }
        if finished { return l.get("Status_Finished") }
        let title = phaseTitle(activePhase, l)
        if running { return title }
        return l.format(remaining == total ? "Status_Ready" : "Status_Paused", title)
    }

    /// "Focus running · 23:41" while another tab is viewed; empty when nothing to show.
    public static func activeInfo(
        viewingActive: Bool, activePhase: TimerPhase, running: Bool, finished: Bool,
        remaining: TimeInterval, total: TimeInterval, _ l: Localizer
    ) -> String {
        if viewingActive || finished { return "" }
        let inProgress = running || remaining != total
        guard inProgress else { return "" }
        return l.format(running ? "Active_Running" : "Active_Paused", phaseTitle(activePhase, l), clock(remaining))
    }

    /// `‹ 4 sessions ›` caption: `"<n> <sessions>"` or `"∞ · <Loops_Unlimited>"`.
    public static func loopsText(_ s: AppSettings, _ l: Localizer) -> String {
        if s.limitSessions, s.totalSessions > 0 {
            return "\(s.totalSessions) \(Schedule.sessionsWord(s.totalSessions, l))"
        }
        return "∞ · \(l.get("Loops_Unlimited"))"
    }

    /// Port of `MainViewModel.BuildSessionLabel` (SPEC §6.4).
    /// - Parameters:
    ///   - totalSessions: `engine.totalSessions` (0 = unlimited).
    ///   - remaining: the active phase's remaining time.
    ///   - now: injected for a deterministic `until HH:mm` in tests.
    public static func sessionLabel(
        settings s: AppSettings, phase: TimerPhase, completedWork: Int, totalSessions: Int,
        filled: Int, cycles: Int, finished: Bool, remaining: TimeInterval,
        _ l: Localizer, now: Date = Date(), timeZone: TimeZone = .current
    ) -> String {
        if totalSessions > 0 {
            if finished {
                return totalSessions == 1
                    ? l.get("Session_Done")
                    : l.format("All_Done", totalSessions, Schedule.sessionsWord(totalSessions, l))
            }
            let number = phase == .work ? min(completedWork + 1, totalSessions) : completedWork
            let prefix = l.format(phase == .work ? "Session_Of" : "Done_Of", number, totalSessions)
            if let left = Schedule.timeToFinish(s, phase: phase, completed: completedWork, remainingCurrent: remaining, finished: finished) {
                let leftText = l.format("Left_Label", Schedule.formatDuration(left, l))
                let until = l.format("Until", Schedule.formatEnd(left, now: now, timeZone: timeZone))
                return "\(prefix) · \(leftText) · \(until)"
            }
            return prefix
        }
        return phase == .work
            ? l.format("Session_Of", min(filled + 1, cycles), cycles)
            : l.format("Done_Of", filled, cycles)
    }

    /// Convenience over a live engine.
    public static func sessionLabel(settings s: AppSettings, engine e: TimerEngine, _ l: Localizer) -> String {
        sessionLabel(
            settings: s, phase: e.phase, completedWork: e.completedWork, totalSessions: e.totalSessions,
            filled: e.filledInRound, cycles: e.cyclesPerRound, finished: e.isFinished, remaining: e.remaining, l
        )
    }

    /// Menu bar tooltip: `"Pomodoro — <phase> <mm:ss>"` or `Tray_AllDone`.
    public static func trayTooltip(phase: TimerPhase, remaining: TimeInterval, finished: Bool, _ l: Localizer) -> String {
        finished ? l.get("Tray_AllDone") : "Pomodoro — \(phaseTitle(phase, l)) \(clock(remaining))"
    }
}

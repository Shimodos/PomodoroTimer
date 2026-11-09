import Foundation

/// Port of `Services/Schedule.cs`: estimates when a limited run of sessions ends.
public enum Schedule {
    /// Length of a phase: `max(1, minutes)` of the matching setting.
    public static func duration(_ s: AppSettings, _ phase: TimerPhase) -> TimeInterval {
        TimeInterval(max(1, s.minutes(of: phase))) * 60
    }

    /// Time left until the last work session ends, assuming no pauses. `nil` when
    /// sessions are unlimited or the run is already finished.
    public static func timeToFinish(
        _ s: AppSettings, phase: TimerPhase, completed: Int, remainingCurrent: TimeInterval, finished: Bool
    ) -> TimeInterval? {
        let total = s.limitSessions ? s.totalSessions : 0
        if total <= 0 || finished { return nil }

        let cycles = max(1, s.cyclesBeforeLongBreak)
        var t = remainingCurrent
        var p = phase
        var c = completed

        for _ in 0..<10_000 {
            if p == .work {
                c += 1
                if c >= total { return t }
                p = c % cycles == 0 ? .longBreak : .shortBreak
            } else {
                p = .work
            }
            t += duration(s, p)
        }
        return t
    }

    /// Full plan from a cold start: first work session through the last one.
    public static func plannedTotal(_ s: AppSettings) -> TimeInterval? {
        timeToFinish(s, phase: .work, completed: 0, remainingCurrent: duration(s, .work), finished: false)
    }

    /// `now + left` as `HH:mm`, 24-hour clock.
    public static func formatEnd(_ left: TimeInterval, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: now.addingTimeInterval(left))
    }

    /// session / sessions, with Slavic plural forms where needed.
    public static func sessionsWord(_ n: Int, _ l: Localizer) -> String {
        l.plural(n, "Sessions")
    }

    /// "4 h 05 min" in the current language.
    public static func formatDuration(_ t: TimeInterval, _ l: Localizer) -> String {
        let minutes = Int((t / 60).rounded())
        let hours = minutes / 60
        let rest = minutes % 60
        let h = l.get("Hours"), m = l.get("Min")
        if hours == 0 { return "\(rest) \(m)" }
        return rest == 0 ? "\(hours) \(h)" : "\(hours) \(h) \(String(format: "%02d", rest)) \(m)"
    }
}

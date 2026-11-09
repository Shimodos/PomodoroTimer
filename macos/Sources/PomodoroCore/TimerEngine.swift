import Foundation

public enum TimerPhase: String, CaseIterable {
    case work = "Work"
    case shortBreak = "ShortBreak"
    case longBreak = "LongBreak"
}

/// Something that fires a closure periodically while the engine runs. The app uses
/// `RunLoopTickSource` (200 ms); tests drive a `ManualTickSource`.
public protocol TickSource: AnyObject {
    func start(_ handler: @escaping () -> Void)
    func stop()
}

/// Foundation `Timer` on the current run loop, 200 ms like the Windows `DispatcherTimer`.
public final class RunLoopTickSource: TickSource {
    private var timer: Timer?
    private let interval: TimeInterval

    public init(interval: TimeInterval = 0.2) {
        self.interval = interval
    }

    public func start(_ handler: @escaping () -> Void) {
        stop()
        let t = Timer(timeInterval: interval, repeats: true) { _ in handler() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}

/// Tick source that fires only when told to (tests).
public final class ManualTickSource: TickSource {
    private var handler: (() -> Void)?
    public private(set) var isRunning = false

    public init() {}

    public func start(_ handler: @escaping () -> Void) {
        self.handler = handler
        isRunning = true
    }

    public func stop() {
        isRunning = false
        handler = nil
    }

    public func fire() {
        handler?()
    }
}

/// Port of `Services/TimerEngine.cs`: the Pomodoro state machine. Time is measured
/// against the wall clock (`now`) so a busy main thread or a sleeping laptop never
/// makes the countdown drift.
public final class TimerEngine {
    private let durationOf: (TimerPhase) -> TimeInterval
    private let cyclesSetting: () -> Int
    private let totalSessionsSetting: () -> Int
    private let now: () -> Date
    private let ticks: TickSource

    private var endDate = Date.distantPast
    private var storedRemaining: TimeInterval

    /// Activity log sink; the app points it at `ActivityLog.write`.
    public var log: (String) -> Void = { _ in }

    public var onTick: () -> Void = {}
    public var onStateChanged: () -> Void = {}
    public var onPhaseCompleted: (TimerPhase) -> Void = { _ in }

    public private(set) var phase: TimerPhase = .work
    public private(set) var isRunning = false
    public private(set) var total: TimeInterval
    public private(set) var completedWork = 0
    /// True after the last of a limited number of work sessions ended.
    public private(set) var isFinished = false

    /// - Parameters:
    ///   - duration: length of a phase, read live from the settings.
    ///   - cyclesPerRound: `CyclesBeforeLongBreak`, read live.
    ///   - totalSessions: work sessions until the run is finished, 0 = unlimited, read live.
    public init(
        duration: @escaping (TimerPhase) -> TimeInterval,
        cyclesPerRound: @escaping () -> Int,
        totalSessions: @escaping () -> Int,
        now: @escaping () -> Date = Date.init,
        tickSource: TickSource = RunLoopTickSource()
    ) {
        durationOf = duration
        cyclesSetting = cyclesPerRound
        totalSessionsSetting = totalSessions
        self.now = now
        ticks = tickSource
        total = duration(.work)
        storedRemaining = total
    }

    public var cyclesPerRound: Int { max(1, cyclesSetting()) }
    public var totalSessions: Int { max(0, totalSessionsSetting()) }

    public var remaining: TimeInterval {
        guard isRunning else { return storedRemaining }
        return max(0, endDate.timeIntervalSince(now()))
    }

    /// Work sessions finished in the current round (0…cyclesPerRound).
    public var filledInRound: Int {
        var f = completedWork % cyclesPerRound
        if f == 0, completedWork > 0, phase != .work || isFinished { f = cyclesPerRound }
        return f
    }

    // MARK: - Operations

    public func start() {
        if isRunning { return }
        if isFinished { newRound() }
        if storedRemaining <= 0 { storedRemaining = total }
        endDate = now().addingTimeInterval(storedRemaining)
        isRunning = true
        ticks.start { [weak self] in self?.tick() }
        log("Start \(phase.rawValue) remaining=\(Self.fmt(storedRemaining)) total=\(Self.fmt(total)) completed=\(completedWork)/\(totalSessions)")
        onStateChanged()
    }

    public func pause() {
        guard isRunning else { return }
        storedRemaining = remaining
        isRunning = false
        ticks.stop()
        log("Pause \(phase.rawValue) remaining=\(Self.fmt(storedRemaining))")
        onStateChanged()
    }

    public func toggle() {
        if isRunning { pause() } else { start() }
    }

    public func reset() {
        if isRunning { log("Reset while running \(phase.rawValue) remaining=\(Self.fmt(remaining))") }
        ticks.stop()
        isRunning = false
        total = durationOf(phase)
        storedRemaining = total
        onStateChanged()
    }

    public func setPhase(_ newPhase: TimerPhase) {
        log("SetPhase \(phase.rawValue) -> \(newPhase.rawValue) (was running=\(isRunning), remaining=\(Self.fmt(remaining)))")
        if isFinished {
            completedWork = 0
            isFinished = false
        }
        phase = newPhase
        reset()
    }

    public func skip() {
        if isFinished { return }
        log("Skip \(phase.rawValue) remaining=\(Self.fmt(remaining))")
        advance()
    }

    /// After the session limit changed: a finished run continues if the new limit
    /// (or no limit) leaves sessions to do.
    public func reevaluateLimit() {
        guard isFinished else { return }
        if totalSessions != 0, completedWork >= totalSessions { return }
        isFinished = false
        phase = .work
        reset()
    }

    /// Forgets finished sessions and starts over from the first work session.
    public func newRound() {
        completedWork = 0
        isFinished = false
        phase = .work
        reset()
    }

    /// Re-reads durations after settings changed without losing a paused countdown.
    public func reloadDurations() {
        if isRunning { return }
        let untouched = storedRemaining == total
        total = durationOf(phase)
        storedRemaining = untouched ? total : min(storedRemaining, total)
        log("ReloadDurations \(phase.rawValue) total=\(Self.fmt(total)) remaining=\(Self.fmt(storedRemaining))")
        onStateChanged()
    }

    // MARK: - Private

    private func advance() {
        let from = phase
        if phase == .work {
            completedWork += 1
            if totalSessions > 0, completedWork >= totalSessions {
                isFinished = true
                phase = .work
                reset()
                log("Finished: \(completedWork)/\(totalSessions) sessions done")
                return
            }
            phase = completedWork % cyclesPerRound == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        reset()
        log("Advance \(from.rawValue) -> \(phase.rawValue) completed=\(completedWork)/\(totalSessions)")
    }

    private func tick() {
        if remaining <= 0 {
            ticks.stop()
            isRunning = false
            let finished = phase
            log("Completed \(finished.rawValue) by countdown (end=\(Self.logTime.string(from: endDate)))")
            advance()
            onPhaseCompleted(finished)
        } else {
            onTick()
        }
    }

    private static let logTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// `mm:ss` with whole minutes (may exceed 59), like the Windows `Fmt`.
    static func fmt(_ t: TimeInterval) -> String {
        let seconds = Int(t)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

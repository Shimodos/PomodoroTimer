import Testing
import Foundation
@testable import PomodoroCore

/// Drives a `TimerEngine` with a fake clock and a manual tick source.
final class EngineHarness {
    var settings = AppSettings()
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    let ticks = ManualTickSource()
    var completed: [TimerPhase] = []
    var stateChanges = 0
    var log: [String] = []
    private(set) var engine: TimerEngine!

    init(configure: (inout AppSettings) -> Void = { _ in }) {
        configure(&settings)
        engine = TimerEngine(
            duration: { [unowned self] p in Schedule.duration(self.settings, p) },
            cyclesPerRound: { [unowned self] in self.settings.cyclesBeforeLongBreak },
            totalSessions: { [unowned self] in self.settings.limitSessions ? self.settings.totalSessions : 0 },
            now: { [unowned self] in self.now },
            tickSource: ticks
        )
        engine.onPhaseCompleted = { [unowned self] p in self.completed.append(p) }
        engine.onStateChanged = { [unowned self] in self.stateChanges += 1 }
        engine.log = { [unowned self] in self.log.append($0) }
    }

    /// Advances the clock and fires one tick.
    func elapse(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
        ticks.fire()
    }

    /// Runs the current phase to its end (one tick after the deadline).
    func finishPhase() {
        elapse(engine.remaining + 0.1)
    }
}

struct TimerEngineTests {
    @Test func testInitialState() {
        let h = EngineHarness()
        expectEqual(h.engine.phase, .work)
        expectFalse(h.engine.isRunning)
        expectEqual(h.engine.total, 25 * 60)
        expectEqual(h.engine.remaining, 25 * 60)
        expectEqual(h.engine.completedWork, 0)
        expectFalse(h.engine.isFinished)
        expectEqual(h.engine.cyclesPerRound, 4)
        expectEqual(h.engine.totalSessions, 4)
    }

    @Test func testStartPauseTracksWallClock() {
        let h = EngineHarness()
        h.engine.start()
        expectTrue(h.engine.isRunning)
        expectTrue(h.ticks.isRunning)
        h.elapse(61.5)
        expectEqual(h.engine.remaining, 25 * 60 - 61.5, accuracy: 0.001)
        expectTrue(h.completed.isEmpty)

        h.engine.pause()
        expectFalse(h.engine.isRunning)
        expectFalse(h.ticks.isRunning)
        let paused = h.engine.remaining
        h.now = h.now.addingTimeInterval(1000)
        expectEqual(h.engine.remaining, paused, "paused remaining does not move with the clock")

        h.engine.start()
        h.elapse(10)
        expectEqual(h.engine.remaining, paused - 10, accuracy: 0.001)
    }

    @Test func testStartWhileRunningIsNoOp() {
        let h = EngineHarness()
        h.engine.start()
        let changes = h.stateChanges
        h.engine.start()
        expectEqual(h.stateChanges, changes)
    }

    @Test func testCountdownToZeroCompletesOnceAndMovesToShortBreak() {
        let h = EngineHarness()
        h.engine.start()
        h.finishPhase()
        expectEqual(h.completed, [.work])
        expectEqual(h.engine.phase, .shortBreak)
        expectFalse(h.engine.isRunning, "engine does not auto-start; the view model does")
        expectEqual(h.engine.completedWork, 1)
        expectEqual(h.engine.remaining, 5 * 60)
        expectEqual(h.engine.total, 5 * 60)
        expectFalse(h.ticks.isRunning)
        // A stray tick after completion must not complete anything again.
        h.ticks.fire()
        expectEqual(h.completed.count, 1)
    }

    @Test func testFourthWorkSessionLeadsToLongBreak() {
        let h = EngineHarness { $0.limitSessions = false }
        for i in 1...3 {
            h.engine.start(); h.finishPhase()
            expectEqual(h.engine.phase, .shortBreak, "after work \(i)")
            h.engine.start(); h.finishPhase()
            expectEqual(h.engine.phase, .work)
        }
        h.engine.start(); h.finishPhase()
        expectEqual(h.engine.phase, .longBreak)
        expectEqual(h.engine.completedWork, 4)
        expectEqual(h.engine.filledInRound, 4, "all dots filled during the long break")
        h.engine.start(); h.finishPhase()
        expectEqual(h.engine.phase, .work)
        expectEqual(h.engine.filledInRound, 0, "next round starts empty")
        expectEqual(h.engine.total, 25 * 60)
    }

    @Test func testLimitedRunFinishesAfterLastWorkSession() {
        let h = EngineHarness { $0.totalSessions = 4 }
        for _ in 1...3 {
            h.engine.start(); h.finishPhase()   // work
            h.engine.start(); h.finishPhase()   // break
        }
        expectEqual(h.engine.phase, .work)
        expectEqual(h.engine.completedWork, 3)
        h.engine.start(); h.finishPhase()
        expectTrue(h.engine.isFinished)
        expectEqual(h.engine.phase, .work)
        expectEqual(h.engine.remaining, h.engine.total)
        expectEqual(h.engine.completedWork, 4)
        expectEqual(h.engine.filledInRound, 4)
        expectEqual(h.completed.last, .work)
        expectTrue(h.log.contains("Finished: 4/4 sessions done"))
    }

    @Test func testSkipOnFinishedRunIsNoOp() {
        let h = EngineHarness { $0.totalSessions = 1 }
        h.engine.start(); h.finishPhase()
        expectTrue(h.engine.isFinished)
        let changes = h.stateChanges
        h.engine.skip()
        expectEqual(h.stateChanges, changes)
        expectTrue(h.engine.isFinished)
        expectEqual(h.engine.completedWork, 1)
    }

    @Test func testSkipDoesNotRaisePhaseCompleted() {
        let h = EngineHarness()
        h.engine.skip()
        expectEqual(h.engine.phase, .shortBreak)
        expectEqual(h.engine.completedWork, 1)
        expectTrue(h.completed.isEmpty)
    }

    @Test func testStartOnFinishedRunBeginsNewRound() {
        let h = EngineHarness { $0.totalSessions = 1 }
        h.engine.start(); h.finishPhase()
        expectTrue(h.engine.isFinished)
        h.engine.start()
        expectFalse(h.engine.isFinished)
        expectEqual(h.engine.completedWork, 0)
        expectTrue(h.engine.isRunning)
        expectEqual(h.engine.phase, .work)
    }

    @Test func testSetPhaseOnFinishedRunResetsCompletedWork() {
        let h = EngineHarness { $0.totalSessions = 1 }
        h.engine.start(); h.finishPhase()
        h.engine.setPhase(.longBreak)
        expectFalse(h.engine.isFinished)
        expectEqual(h.engine.completedWork, 0)
        expectEqual(h.engine.phase, .longBreak)
        expectEqual(h.engine.total, 15 * 60)
        expectFalse(h.engine.isRunning)
    }

    @Test func testSetPhaseWhileRunningStopsAndResets() {
        let h = EngineHarness()
        h.engine.start()
        h.elapse(30)
        h.engine.setPhase(.shortBreak)
        expectFalse(h.engine.isRunning)
        expectFalse(h.ticks.isRunning)
        expectEqual(h.engine.remaining, 5 * 60)
        expectEqual(h.engine.completedWork, 0, "switching tabs does not count a session")
    }

    @Test func testReevaluateLimitUnfreezesWhenLimitGrows() {
        let h = EngineHarness { $0.totalSessions = 1 }
        h.engine.start(); h.finishPhase()
        expectTrue(h.engine.isFinished)

        h.engine.reevaluateLimit()
        expectTrue(h.engine.isFinished, "same limit: stays finished")

        h.settings.totalSessions = 2
        h.engine.reevaluateLimit()
        expectFalse(h.engine.isFinished)
        expectEqual(h.engine.phase, .work)
        expectEqual(h.engine.completedWork, 1, "finished sessions are kept")
        expectEqual(h.engine.remaining, 25 * 60)
    }

    @Test func testReevaluateLimitUnfreezesWhenUnlimited() {
        let h = EngineHarness { $0.totalSessions = 1 }
        h.engine.start(); h.finishPhase()
        h.settings.limitSessions = false
        h.engine.reevaluateLimit()
        expectFalse(h.engine.isFinished)
        expectEqual(h.engine.totalSessions, 0)
    }

    @Test func testReevaluateLimitIsNoOpWhenNotFinished() {
        let h = EngineHarness()
        h.engine.start(); h.elapse(5)
        h.settings.totalSessions = 8
        h.engine.reevaluateLimit()
        expectTrue(h.engine.isRunning)
    }

    @Test func testReloadDurationsResetsUntouchedCountdown() {
        let h = EngineHarness()
        h.settings.workMinutes = 30
        h.engine.reloadDurations()
        expectEqual(h.engine.total, 30 * 60)
        expectEqual(h.engine.remaining, 30 * 60)
    }

    @Test func testReloadDurationsKeepsPausedRemaining() {
        let h = EngineHarness()
        h.engine.start(); h.elapse(5 * 60); h.engine.pause()
        expectEqual(h.engine.remaining, 20 * 60, accuracy: 0.001)
        h.settings.workMinutes = 30
        h.engine.reloadDurations()
        expectEqual(h.engine.total, 30 * 60)
        expectEqual(h.engine.remaining, 20 * 60, accuracy: 0.001)
    }

    @Test func testReloadDurationsClampsToNewTotal() {
        let h = EngineHarness()
        h.engine.start(); h.elapse(60); h.engine.pause()   // 24:00 left
        h.settings.workMinutes = 10
        h.engine.reloadDurations()
        expectEqual(h.engine.total, 10 * 60)
        expectEqual(h.engine.remaining, 10 * 60)
    }

    @Test func testReloadDurationsIsNoOpWhileRunning() {
        let h = EngineHarness()
        h.engine.start()
        h.settings.workMinutes = 10
        h.engine.reloadDurations()
        expectEqual(h.engine.total, 25 * 60)
        expectTrue(h.engine.isRunning)
    }

    @Test func testResetWhileRunningStopsAndRestoresFullDuration() {
        let h = EngineHarness()
        h.engine.start(); h.elapse(100)
        h.engine.reset()
        expectFalse(h.engine.isRunning)
        expectEqual(h.engine.remaining, 25 * 60)
        expectTrue(h.log.contains { $0.hasPrefix("Reset while running Work") })
    }

    @Test func testCyclesPerRoundNeverBelowOne() {
        let h = EngineHarness { $0.cyclesBeforeLongBreak = 0; $0.limitSessions = false }
        expectEqual(h.engine.cyclesPerRound, 1)
        h.engine.skip()
        expectEqual(h.engine.phase, .longBreak, "every work session is followed by a long break")
    }

    @Test func testFilledInRoundAtStartOfRoundIsZeroWhileWorking() {
        let h = EngineHarness { $0.limitSessions = false }
        expectEqual(h.engine.filledInRound, 0)
        h.engine.skip()  // -> short break, 1 done
        expectEqual(h.engine.filledInRound, 1)
        h.engine.skip()  // -> work
        expectEqual(h.engine.filledInRound, 1)
    }

    @Test func testLogLinesMatchWindowsWording() {
        let h = EngineHarness()
        h.engine.start()
        expectEqual(h.log.first, "Start Work remaining=25:00 total=25:00 completed=0/4")
        h.elapse(30)
        h.engine.pause()
        expectEqual(h.log.last, "Pause Work remaining=24:30")
        h.engine.skip()
        expectEqual(h.log[h.log.count - 2], "Skip Work remaining=24:30")
        expectEqual(h.log.last, "Advance Work -> ShortBreak completed=1/4")
    }

    @Test func testClockTextCeilsSeconds() {
        expectEqual(SessionText.clock(25 * 60), "25:00")
        expectEqual(SessionText.clock(24 * 60 + 59.2), "25:00")
        expectEqual(SessionText.clock(0.3), "00:01")
        expectEqual(SessionText.clock(0), "00:00")
        expectEqual(SessionText.clock(120 * 60), "120:00")
        expectEqual(SessionText.minutesLeft(24 * 60 + 1, finished: false), 25)
        expectEqual(SessionText.minutesLeft(10, finished: true), 0)
    }
}

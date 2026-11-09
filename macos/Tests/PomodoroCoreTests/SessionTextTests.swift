import Testing
import Foundation
@testable import PomodoroCore

struct SessionTextTests {
    let en = TestStrings.localizer()
    let tz = TimeZone(identifier: "UTC")!
    var now: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 16, minute: 17))!
    }

    @Test func testSessionTwoOfFourWithTimeLeft() {
        // Session 2 of 4, 25:00 left: 25 + 5 + 25 + 5 + 25 = 85 min → until 17:42
        let s = AppSettings()
        let label = SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 1, totalSessions: 4, filled: 1, cycles: 4,
            finished: false, remaining: 25 * 60, en, now: now, timeZone: tz)
        expectEqual(label, "Session 2 of 4 · 1 h 25 min left · until 17:42")
    }

    @Test func testColdStartLabel() {
        let s = AppSettings()
        let label = SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 0, totalSessions: 4, filled: 0, cycles: 4,
            finished: false, remaining: 25 * 60, en, now: now, timeZone: tz)
        expectEqual(label, "Session 1 of 4 · 1 h 55 min left · until 18:12")
    }

    @Test func testBreakLabelUsesDoneOf() {
        let s = AppSettings()
        let label = SessionText.sessionLabel(
            settings: s, phase: .shortBreak, completedWork: 1, totalSessions: 4, filled: 1, cycles: 4,
            finished: false, remaining: 5 * 60, en, now: now, timeZone: tz)
        // 5 + 25 + 5 + 25 + 5 + 25 = 90 min
        expectEqual(label, "1 of 4 done · 1 h 30 min left · until 17:47")
    }

    @Test func testFinishedLabels() {
        let s = AppSettings()
        expectEqual(SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 4, totalSessions: 4, filled: 4, cycles: 4,
            finished: true, remaining: 25 * 60, en), "All 4 sessions complete")
        expectEqual(SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 1, totalSessions: 1, filled: 1, cycles: 4,
            finished: true, remaining: 25 * 60, en), "Session complete")
    }

    @Test func testUnlimitedLabels() {
        var s = AppSettings()
        s.limitSessions = false
        expectEqual(SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 5, totalSessions: 0, filled: 1, cycles: 4,
            finished: false, remaining: 10, en), "Session 2 of 4")
        expectEqual(SessionText.sessionLabel(
            settings: s, phase: .longBreak, completedWork: 4, totalSessions: 0, filled: 4, cycles: 4,
            finished: false, remaining: 10, en), "4 of 4 done")
        expectEqual(SessionText.sessionLabel(
            settings: s, phase: .work, completedWork: 4, totalSessions: 0, filled: 4, cycles: 4,
            finished: false, remaining: 10, en), "Session 4 of 4", "min(filled + 1, cycles)")
    }

    @Test func testLoopsText() {
        var s = AppSettings()
        expectEqual(SessionText.loopsText(s, en), "4 sessions")
        s.totalSessions = 1
        expectEqual(SessionText.loopsText(s, en), "1 session")
        s.limitSessions = false
        expectEqual(SessionText.loopsText(s, en), "∞ · no limit")
        s.limitSessions = true
        s.totalSessions = 3
        expectEqual(SessionText.loopsText(s, TestStrings.localizer("ru")), "3 сессии")
    }

    @Test func testStatusText() {
        expectEqual(SessionText.statusText(viewingActive: true, viewedPhase: .work, activePhase: .work,
                                              running: false, finished: false, remaining: 1500, total: 1500, en), "Focus · ready")
        expectEqual(SessionText.statusText(viewingActive: true, viewedPhase: .work, activePhase: .work,
                                              running: false, finished: false, remaining: 1400, total: 1500, en), "Focus · paused")
        expectEqual(SessionText.statusText(viewingActive: true, viewedPhase: .work, activePhase: .shortBreak,
                                              running: true, finished: false, remaining: 100, total: 300, en), "Short break")
        expectEqual(SessionText.statusText(viewingActive: true, viewedPhase: .work, activePhase: .work,
                                              running: false, finished: true, remaining: 1500, total: 1500, en), "Done · all sessions complete")
        expectEqual(SessionText.statusText(viewingActive: false, viewedPhase: .longBreak, activePhase: .work,
                                              running: true, finished: false, remaining: 100, total: 1500, en), "Long break · ready")
    }

    @Test func testActiveInfo() {
        expectEqual(SessionText.activeInfo(viewingActive: false, activePhase: .work, running: true, finished: false,
                                              remaining: 1421, total: 1500, en), "Focus running · 23:41")
        expectEqual(SessionText.activeInfo(viewingActive: false, activePhase: .work, running: false, finished: false,
                                              remaining: 1421, total: 1500, en), "Focus paused · 23:41")
        expectEqual(SessionText.activeInfo(viewingActive: false, activePhase: .work, running: false, finished: false,
                                              remaining: 1500, total: 1500, en), "", "nothing in progress")
        expectEqual(SessionText.activeInfo(viewingActive: true, activePhase: .work, running: true, finished: false,
                                              remaining: 10, total: 1500, en), "")
        expectEqual(SessionText.activeInfo(viewingActive: false, activePhase: .work, running: false, finished: true,
                                              remaining: 10, total: 1500, en), "")
    }

    @Test func testPrimaryButtonText() {
        expectEqual(SessionText.primaryButtonText(viewingActive: true, viewedPhase: .work, running: true, finished: false, en), "Pause")
        expectEqual(SessionText.primaryButtonText(viewingActive: true, viewedPhase: .work, running: false, finished: true, en), "Restart")
        expectEqual(SessionText.primaryButtonText(viewingActive: true, viewedPhase: .work, running: false, finished: false, en), "Start")
        expectEqual(SessionText.primaryButtonText(viewingActive: false, viewedPhase: .shortBreak, running: true, finished: false, en), "Start break")
        expectEqual(SessionText.primaryButtonText(viewingActive: false, viewedPhase: .longBreak, running: false, finished: false, en), "Start long break")
        expectEqual(SessionText.primaryButtonText(viewingActive: false, viewedPhase: .work, running: false, finished: false, en), "Start focus")
    }

    @Test func testTrayTooltip() {
        expectEqual(SessionText.trayTooltip(phase: .work, remaining: 1421, finished: false, en), "Pomodoro — Focus 23:41")
        expectEqual(SessionText.trayTooltip(phase: .work, remaining: 0, finished: true, en), "Pomodoro — all sessions complete")
    }
}

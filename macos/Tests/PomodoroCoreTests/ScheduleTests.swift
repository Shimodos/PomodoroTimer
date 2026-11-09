import Testing
import Foundation
@testable import PomodoroCore

struct ScheduleTests {
    let en = TestStrings.localizer()

    @Test func testDurationGuardsAtOneMinute() {
        var s = AppSettings()
        s.workMinutes = 0
        s.shortBreakMinutes = -3
        expectEqual(Schedule.duration(s, .work), 60)
        expectEqual(Schedule.duration(s, .shortBreak), 60)
        expectEqual(Schedule.duration(s, .longBreak), 15 * 60)
    }

    @Test func testPlannedTotalFourSessions() {
        let s = AppSettings()
        expectEqual(Schedule.plannedTotal(s), TimeInterval(115 * 60))
        expectEqual(Schedule.formatDuration(Schedule.plannedTotal(s)!, en), "1 h 55 min")
    }

    @Test func testPlannedTotalEightSessions() {
        var s = AppSettings()
        s.totalSessions = 8
        expectEqual(Schedule.plannedTotal(s), TimeInterval(245 * 60))
        expectEqual(Schedule.formatDuration(Schedule.plannedTotal(s)!, en), "4 h 05 min")
    }

    @Test func testPlannedTotalOneSession() {
        var s = AppSettings()
        s.totalSessions = 1
        expectEqual(Schedule.plannedTotal(s), TimeInterval(25 * 60))
        expectEqual(Schedule.formatDuration(Schedule.plannedTotal(s)!, en), "25 min")
    }

    @Test func testTimeToFinishFromMiddleOfBreak() {
        // 1 work done, 2 minutes of the short break left, 4 sessions total:
        // 2 + 25 + 5 + 25 + 5 + 25 = 87 min
        let s = AppSettings()
        let left = Schedule.timeToFinish(s, phase: .shortBreak, completed: 1, remainingCurrent: 2 * 60, finished: false)
        expectEqual(left, TimeInterval(87 * 60))
    }

    @Test func testTimeToFinishFromMiddleOfWork() {
        // Session 2 of 4 with 10 min left: 10 + 5 + 25 + 5 + 25 = 70 min
        let s = AppSettings()
        let left = Schedule.timeToFinish(s, phase: .work, completed: 1, remainingCurrent: 10 * 60, finished: false)
        expectEqual(left, TimeInterval(70 * 60))
    }

    @Test func testTimeToFinishNilWhenUnlimitedOrFinished() {
        var s = AppSettings()
        expectNil(Schedule.timeToFinish(s, phase: .work, completed: 0, remainingCurrent: 60, finished: true))
        s.limitSessions = false
        expectNil(Schedule.timeToFinish(s, phase: .work, completed: 0, remainingCurrent: 60, finished: false))
        s.limitSessions = true
        s.totalSessions = 0
        expectNil(Schedule.plannedTotal(s))
    }

    @Test func testFormatDurationVariants() {
        expectEqual(Schedule.formatDuration(60 * 60, en), "1 h")
        expectEqual(Schedule.formatDuration(90 * 60, en), "1 h 30 min")
        expectEqual(Schedule.formatDuration(0, en), "0 min")
        expectEqual(Schedule.formatDuration(29.6 * 60, en), "30 min", "rounded to the nearest minute")
        expectEqual(Schedule.formatDuration(245 * 60, TestStrings.localizer("ru")), "4 ч 05 мин")
    }

    @Test func testFormatEndUses24HourClock() {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 9; c.hour = 16; c.minute = 17
        let tz = TimeZone(identifier: "UTC")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let now = cal.date(from: c)!
        expectEqual(Schedule.formatEnd(85 * 60, now: now, timeZone: tz), "17:42")
        expectEqual(Schedule.formatEnd(8 * 60 * 60, now: now, timeZone: tz), "00:17")
    }

    @Test func testSessionsWord() {
        expectEqual(Schedule.sessionsWord(1, en), "session")
        expectEqual(Schedule.sessionsWord(4, en), "sessions")
    }
}

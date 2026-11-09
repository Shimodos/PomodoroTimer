import Testing
import Foundation
@testable import PomodoroCore

struct LogTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pomo-logs-\(UUID().uuidString)")
    }

    @Test func testActivityLogWritesStampedLines() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let paths = DataPaths(dataDir: dir)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let fixed = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 16, minute: 17, second: 5, nanosecond: 123_000_000))!
        let log = ActivityLog(paths: paths, now: { fixed })
        log.write("App start v1.0.0 data=\(dir.path)")
        log.write("Start Work remaining=25:00 total=25:00 completed=0/4")
        log.flush()
        let text = try String(contentsOf: paths.activityLog, encoding: .utf8)
        let lines = text.split(separator: "\n")
        expectEqual(lines.count, 2)
        expectTrue(lines[0].hasPrefix("2026-11-09 16:17:05.123  App start"), String(lines[0]))
        expectEqual(lines[1], "2026-11-09 16:17:05.123  Start Work remaining=25:00 total=25:00 completed=0/4")
    }

    @Test func testActivityLogTrimsLargeFileOnce() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let paths = DataPaths(dataDir: dir)
        paths.ensureDirectory()
        let line = String(repeating: "x", count: 99) + "\n"
        let big = String(repeating: line, count: 2500)   // 250 KB > 200 KB
        try big.write(to: paths.activityLog, atomically: true, encoding: .utf8)

        let log = ActivityLog(paths: paths)
        log.write("after trim")
        log.flush()

        let data = try Data(contentsOf: paths.activityLog)
        expectLessThan(data.count, ActivityLog.maxBytes / 2 + 200)
        expectGreaterThan(data.count, ActivityLog.maxBytes / 2 - 200)
        let text = String(decoding: data, as: UTF8.self)
        expectTrue(text.hasPrefix("xxxx"), "cut happens at a line boundary")
        expectTrue(text.hasSuffix("after trim\n"))
    }

    @Test func testCrashLogFormat() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let paths = DataPaths(dataDir: dir)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let fixed = cal.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 16, minute: 17, second: 5))!
        CrashLog(paths: paths, now: { fixed }).write("boom")
        let text = try String(contentsOf: paths.errorLog, encoding: .utf8)
        expectEqual(text, "[2026-11-09 16:17:05] boom\n\n")
    }
}

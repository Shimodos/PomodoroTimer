import Testing
import Foundation
@testable import PomodoroCore

struct SettingsTests {
    /// A settings.json as System.Text.Json writes it on Windows (WriteIndented, nulls for the nullable doubles).
    static let windowsJSON = """
    {
      "WorkMinutes": 50,
      "ShortBreakMinutes": 10,
      "LongBreakMinutes": 20,
      "CyclesBeforeLongBreak": 3,
      "AutoStartBreaks": false,
      "AutoStartWork": true,
      "LimitSessions": false,
      "TotalSessions": 6,
      "SoundEnabled": false,
      "WorkEndSound": "C:\\\\Users\\\\me\\\\Music\\\\gong.mp3",
      "BreakEndSound": "ding.wav",
      "Volume": 0.35,
      "Theme": "Dark",
      "Accent": "#4ECB71",
      "BreakAccent": "#F472B6",
      "Language": "uk",
      "NotificationsEnabled": false,
      "ShowOnPhaseEnd": false,
      "AlwaysOnTop": true,
      "MinimizeToTray": false,
      "CloseToTray": false,
      "StartWithWindows": true,
      "CompactMode": true,
      "WindowLeft": 120.5,
      "WindowTop": null
    }
    """

    @Test func testDecodesWindowsFile() {
        let s = SettingsStore.decode(Data(Self.windowsJSON.utf8))
        expectEqual(s.workMinutes, 50)
        expectEqual(s.shortBreakMinutes, 10)
        expectEqual(s.longBreakMinutes, 20)
        expectEqual(s.cyclesBeforeLongBreak, 3)
        expectFalse(s.autoStartBreaks)
        expectTrue(s.autoStartWork)
        expectFalse(s.limitSessions)
        expectEqual(s.totalSessions, 6)
        expectFalse(s.soundEnabled)
        expectEqual(s.workEndSound, "C:\\Users\\me\\Music\\gong.mp3")
        expectEqual(s.breakEndSound, "ding.wav")
        expectEqual(s.volume, 0.35)
        expectEqual(s.theme, "Dark")
        expectEqual(s.accent, "#4ECB71")
        expectEqual(s.breakAccent, "#F472B6")
        expectEqual(s.language, "uk")
        expectFalse(s.notificationsEnabled)
        expectFalse(s.showOnPhaseEnd)
        expectTrue(s.alwaysOnTop)
        expectFalse(s.minimizeToTray)
        expectFalse(s.closeToTray)
        expectTrue(s.startWithWindows)
        expectTrue(s.compactMode)
        expectEqual(s.windowLeft, 120.5)
        expectNil(s.windowTop)
    }

    @Test func testMissingKeysTakeDefaults() {
        let s = SettingsStore.decode(Data(#"{"WorkMinutes": 40, "SomethingUnknown": [1,2,3]}"#.utf8))
        var expected = AppSettings()
        expected.workMinutes = 40
        expectEqual(s, expected)
    }

    @Test func testDefaults() {
        let s = AppSettings()
        expectEqual(s.workMinutes, 25)
        expectEqual(s.shortBreakMinutes, 5)
        expectEqual(s.longBreakMinutes, 15)
        expectEqual(s.cyclesBeforeLongBreak, 4)
        expectTrue(s.autoStartBreaks)
        expectFalse(s.autoStartWork)
        expectTrue(s.limitSessions)
        expectEqual(s.totalSessions, 4)
        expectTrue(s.soundEnabled)
        expectEqual(s.workEndSound, "bell.wav")
        expectEqual(s.breakEndSound, "chime.wav")
        expectEqual(s.volume, 0.8)
        expectEqual(s.theme, "System")
        expectEqual(s.accent, "#FF6B6B")
        expectEqual(s.breakAccent, "auto")
        expectEqual(s.language, "")
        expectTrue(s.notificationsEnabled)
        expectTrue(s.showOnPhaseEnd)
        expectFalse(s.alwaysOnTop)
        expectTrue(s.minimizeToTray)
        expectTrue(s.closeToTray)
        expectFalse(s.startWithWindows)
        expectFalse(s.compactMode)
        expectNil(s.windowLeft)
        expectNil(s.windowTop)
    }

    @Test func testGarbageFallsBackToDefaults() {
        expectEqual(SettingsStore.decode(Data("not json".utf8)), AppSettings())
        expectEqual(SettingsStore.decode(Data(#"{"WorkMinutes": "twenty"}"#.utf8)), AppSettings(), "a wrong type invalidates the file like on Windows")
        expectEqual(SettingsStore.decode(Data()), AppSettings())
    }

    @Test func testEncodingRoundTripsWithPascalCaseKeys() throws {
        let original = SettingsStore.decode(Data(Self.windowsJSON.utf8))
        let data = SettingsStore.encode(original)
        let text = String(decoding: data, as: UTF8.self)
        for key in ["WorkMinutes", "ShortBreakMinutes", "LongBreakMinutes", "CyclesBeforeLongBreak",
                    "AutoStartBreaks", "AutoStartWork", "LimitSessions", "TotalSessions", "SoundEnabled",
                    "WorkEndSound", "BreakEndSound", "Volume", "Theme", "Accent", "BreakAccent", "Language",
                    "NotificationsEnabled", "ShowOnPhaseEnd", "AlwaysOnTop", "MinimizeToTray", "CloseToTray",
                    "StartWithWindows", "CompactMode", "WindowLeft", "WindowTop"] {
            expectTrue(text.contains("\"\(key)\""), "missing key \(key)")
        }
        expectTrue(text.contains("\"WindowTop\" : null"), "nullable doubles are written as null")
        expectEqual(SettingsStore.decode(data), original)
    }

    @Test func testStoreLoadsSavesAndReplaces() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pomo-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SettingsStore(paths: DataPaths(dataDir: dir))

        store.load()
        expectEqual(store.current, AppSettings(), "no file yet → defaults")

        store.update { $0.workMinutes = 45 }
        expectTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("settings.json").path))

        let again = SettingsStore(paths: DataPaths(dataDir: dir))
        again.load()
        expectEqual(again.current.workMinutes, 45)

        var replaced = AppSettings()
        replaced.theme = "Light"
        again.replace(replaced)
        let third = SettingsStore(paths: DataPaths(dataDir: dir))
        third.load()
        expectEqual(third.current.theme, "Light")
        expectEqual(third.current.workMinutes, 25)
    }

    @Test func testDataDirResolution() {
        let custom = DataPaths.resolve(environment: ["POMODORO_DATA_DIR": "/tmp/pomo"])
        expectEqual(custom.dataDir.path, "/tmp/pomo")
        expectEqual(custom.settingsFile.lastPathComponent, "settings.json")
        expectEqual(custom.activityLog.lastPathComponent, "activity.log")
        expectEqual(custom.errorLog.lastPathComponent, "error.log")

        let blank = DataPaths.resolve(environment: ["POMODORO_DATA_DIR": "   "])
        expectTrue(blank.dataDir.path.hasSuffix("/Library/Application Support/PomodoroTimer"), blank.dataDir.path)

        let none = DataPaths.resolve(environment: [:])
        expectEqual(none.dataDir.path, blank.dataDir.path)
    }
}

import Foundation

/// Port of `Services/AppPaths.cs`: where settings and logs live.
/// `POMODORO_DATA_DIR` (non-blank) overrides `~/Library/Application Support/PomodoroTimer`.
public struct DataPaths {
    public let dataDir: URL

    public var settingsFile: URL { dataDir.appendingPathComponent("settings.json") }
    public var activityLog: URL { dataDir.appendingPathComponent("activity.log") }
    public var errorLog: URL { dataDir.appendingPathComponent("error.log") }

    public init(dataDir: URL) {
        self.dataDir = dataDir
    }

    /// Resolves the data directory from the environment the same way the Windows app does.
    public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) -> DataPaths {
        if let custom = environment["POMODORO_DATA_DIR"],
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DataPaths(dataDir: URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true))
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return DataPaths(dataDir: support.appendingPathComponent("PomodoroTimer", isDirectory: true))
    }

    /// Creates the directory if needed. Best effort, like every disk write in the app.
    public func ensureDirectory() {
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }
}

/// Port of `Services/SettingsService.cs`. Holds the current settings and reads /
/// writes `settings.json`. A broken file is replaced by the defaults; a disk error
/// on save is swallowed — settings must never stop the timer.
public final class SettingsStore {
    public let paths: DataPaths
    public private(set) var current = AppSettings()

    public init(paths: DataPaths) {
        self.paths = paths
    }

    public func load() {
        current = SettingsStore.read(from: paths.settingsFile)
    }

    public func save() {
        paths.ensureDirectory()
        guard let data = try? SettingsStore.encoder.encode(current) else { return }
        try? data.write(to: paths.settingsFile, options: .atomic)
    }

    public func replace(_ settings: AppSettings) {
        current = settings
        save()
    }

    /// Mutates the current settings in place and saves them.
    public func update(_ change: (inout AppSettings) -> Void) {
        change(&current)
        save()
    }

    // MARK: - Pure helpers (used by tests)

    public static func read(from url: URL) -> AppSettings {
        guard let data = try? Data(contentsOf: url) else { return AppSettings() }
        return decode(data)
    }

    public static func decode(_ data: Data) -> AppSettings {
        (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    public static func encode(_ settings: AppSettings) -> Data {
        (try? encoder.encode(settings)) ?? Data("{}".utf8)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()
}

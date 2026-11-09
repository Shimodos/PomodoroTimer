import Foundation
import PomodoroCore

/// Process-wide services: data directory, settings, logs, strings. Created once by
/// the app delegate and handed to the controllers.
final class AppEnvironment {
    let paths: DataPaths
    let settings: SettingsStore
    let activityLog: ActivityLog
    let crashLog: CrashLog
    let localizer: Localizer

    var current: AppSettings { settings.current }

    init() {
        paths = DataPaths.resolve()
        settings = SettingsStore(paths: paths)
        activityLog = ActivityLog(paths: paths)
        crashLog = CrashLog(paths: paths)

        let stringsDir = Bundle.main.resourceURL?.appendingPathComponent("Localization", isDirectory: true)
            ?? URL(fileURLWithPath: "Localization")
        localizer = Localizer.load(from: stringsDir)

        settings.load()
        localizer.apply(settings.current.language)
    }

    /// `L("Key")` convenience used by views and controllers.
    func L(_ key: String) -> String { localizer.get(key) }

    func L(_ key: String, _ args: CustomStringConvertible...) -> String {
        Localizer.format(localizer.get(key), args)
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

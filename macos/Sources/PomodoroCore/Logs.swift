import Foundation

/// Port of `Services/ActivityLog.cs`: a plain-text journal of timer transitions.
/// One line per event: `yyyy-MM-dd HH:mm:ss.fff  message`. Trimmed once per launch
/// to roughly the last 100 KB when it exceeds 200 KB. Never throws, never blocks the timer.
public final class ActivityLog {
    public static let maxBytes = 200 * 1024

    private let paths: DataPaths
    private let now: () -> Date
    private var trimmed = false
    private let queue = DispatchQueue(label: "pomodoro.activitylog")

    public init(paths: DataPaths, now: @escaping () -> Date = Date.init) {
        self.paths = paths
        self.now = now
    }

    public func write(_ message: String) {
        let line = "\(ActivityLog.stamp.string(from: now()))  \(message)\n"
        queue.async { [self] in
            paths.ensureDirectory()
            trimOnce()
            ActivityLog.append(line, to: paths.activityLog)
        }
    }

    /// Blocks until every queued line is on disk (used at quit and in tests).
    public func flush() {
        queue.sync {}
    }

    private func trimOnce() {
        if trimmed { return }
        trimmed = true
        ActivityLog.trim(paths.activityLog, maxBytes: ActivityLog.maxBytes)
    }

    static func trim(_ url: URL, maxBytes: Int) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int, size > maxBytes,
              let data = try? Data(contentsOf: url) else { return }
        // Keep the tail, starting after the first newline inside the last maxBytes/2 bytes.
        let from = max(0, data.count - maxBytes / 2)
        guard let nl = data[from...].firstIndex(of: UInt8(ascii: "\n")) else { return }
        try? data[(nl + 1)...].write(to: url, options: .atomic)
    }

    static func append(_ text: String, to url: URL) {
        guard let data = text.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}

/// Port of `Services/CrashLog.cs`: appends unhandled errors to `error.log` as
/// `[yyyy-MM-dd HH:mm:ss] <description>` followed by a blank line.
public final class CrashLog {
    private let paths: DataPaths
    private let now: () -> Date

    public init(paths: DataPaths, now: @escaping () -> Date = Date.init) {
        self.paths = paths
        self.now = now
    }

    public func write(_ description: String) {
        paths.ensureDirectory()
        ActivityLog.append("[\(CrashLog.stamp.string(from: now()))] \(description)\n\n", to: paths.errorLog)
    }

    public func write(_ error: Error) {
        write(String(describing: error))
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

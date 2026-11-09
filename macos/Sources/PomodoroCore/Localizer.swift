import Foundation

/// Port of `Services/Localizer.cs`. Dictionary-based: the app loads
/// `<lang>.json` files produced by `scripts/strings.py`; tests pass dictionaries inline.
public final class Localizer {
    public static let supported = ["en", "uk", "ru"]

    public private(set) var current = "en"
    private var tables: [String: [String: String]]
    private let systemLanguages: () -> [String]

    /// - Parameters:
    ///   - tables: language code → key → value.
    ///   - systemLanguages: preferred languages of the system, most preferred first
    ///     (`Locale.preferredLanguages`); only the first one counts, like `CurrentUICulture`.
    public init(tables: [String: [String: String]] = [:], systemLanguages: @escaping () -> [String] = { Locale.preferredLanguages }) {
        self.tables = tables
        self.systemLanguages = systemLanguages
    }

    /// Loads `en.json`, `uk.json`, `ru.json` from a directory (the app bundle's Resources/Localization).
    public static func load(from directory: URL, systemLanguages: @escaping () -> [String] = { Locale.preferredLanguages }) -> Localizer {
        var tables: [String: [String: String]] = [:]
        for code in supported {
            let url = directory.appendingPathComponent("\(code).json")
            if let data = try? Data(contentsOf: url),
               let dict = try? JSONDecoder().decode([String: String].self, from: data) {
                tables[code] = dict
            }
        }
        return Localizer(tables: tables, systemLanguages: systemLanguages)
    }

    /// Maps a stored code (possibly empty = auto) to a supported language.
    public func resolve(_ code: String?) -> String {
        if let code, !code.isEmpty, Localizer.supported.contains(code) { return code }
        let system = Localizer.twoLetter(systemLanguages().first ?? "")
        return system == "ru" || system == "uk" ? system : "en"
    }

    public func apply(_ code: String?) {
        current = resolve(code)
    }

    public func tryGet(_ key: String) -> String? {
        tables[current]?[key]
    }

    /// A missing key renders as the key itself.
    public func get(_ key: String) -> String {
        tryGet(key) ?? key
    }

    /// Replaces `{0}`, `{1}`, … with the arguments' descriptions; a placeholder may repeat.
    public func format(_ key: String, _ args: CustomStringConvertible...) -> String {
        Localizer.format(get(key), args)
    }

    public static func format(_ template: String, _ args: [CustomStringConvertible]) -> String {
        var s = template
        for (i, arg) in args.enumerated() {
            s = s.replacingOccurrences(of: "{\(i)}", with: arg.description)
        }
        return s
    }

    /// Picks the One / Few / Many form of a noun for a count.
    public func plural(_ n: Int, _ prefix: String) -> String {
        get("\(prefix)_\(Localizer.pluralForm(n, language: current))")
    }

    public static func pluralForm(_ n: Int, language: String) -> String {
        if language == "en" { return n == 1 ? "One" : "Many" }
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1, mod100 != 11 { return "One" }
        if (2...4).contains(mod10), mod100 < 12 || mod100 > 14 { return "Few" }
        return "Many"
    }

    /// `"ru-RU"` / `"uk_UA"` / `"en"` → `"ru"` / `"uk"` / `"en"`.
    static func twoLetter(_ identifier: String) -> String {
        let code = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? identifier
        return code.lowercased()
    }
}

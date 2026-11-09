import Testing
import Foundation
@testable import PomodoroCore

struct LocalizerTests {
    @Test func testFormatWithRepeatedPlaceholder() {
        let l = TestStrings.localizer()
        expectEqual(l.format("Notify_AllDone_Text", 4), "4 of 4 — great work!")
        expectEqual(l.format("Session_Of", 2, 4), "Session 2 of 4")
        expectEqual(l.format("Active_Running", "Focus", "23:41"), "Focus running · 23:41")
    }

    @Test func testMissingKeyRendersAsKey() {
        let l = TestStrings.localizer()
        expectEqual(l.get("No_Such_Key"), "No_Such_Key")
        expectNil(l.tryGet("No_Such_Key"))
    }

    @Test func testPluralFormsEnglish() {
        expectEqual(Localizer.pluralForm(1, language: "en"), "One")
        for n in [0, 2, 5, 11, 21, 22, 25] {
            expectEqual(Localizer.pluralForm(n, language: "en"), "Many", "\(n)")
        }
    }

    @Test func testPluralFormsSlavic() {
        for lang in ["uk", "ru"] {
            expectEqual(Localizer.pluralForm(1, language: lang), "One", lang)
            expectEqual(Localizer.pluralForm(2, language: lang), "Few", lang)
            expectEqual(Localizer.pluralForm(5, language: lang), "Many", lang)
            expectEqual(Localizer.pluralForm(11, language: lang), "Many", lang)
            expectEqual(Localizer.pluralForm(21, language: lang), "One", lang)
            expectEqual(Localizer.pluralForm(22, language: lang), "Few", lang)
            expectEqual(Localizer.pluralForm(25, language: lang), "Many", lang)
            expectEqual(Localizer.pluralForm(12, language: lang), "Many", lang)
            expectEqual(Localizer.pluralForm(14, language: lang), "Many", lang)
        }
        expectEqual(TestStrings.localizer("ru").plural(2, "Sessions"), "сессии")
        expectEqual(TestStrings.localizer("uk").plural(5, "Sessions"), "сесій")
        expectEqual(TestStrings.localizer("en").plural(1, "Sessions"), "session")
    }

    @Test func testResolveStoredCodeWins() {
        let l = TestStrings.localizer("en", system: ["ru-RU"])
        expectEqual(l.resolve("uk"), "uk")
        expectEqual(l.resolve("en"), "en")
    }

    @Test func testResolveEmptyFollowsSystemWhenSupported() {
        expectEqual(TestStrings.localizer(system: ["ru-RU", "en-US"]).resolve(""), "ru")
        expectEqual(TestStrings.localizer(system: ["uk_UA"]).resolve(nil), "uk")
        expectEqual(TestStrings.localizer(system: ["de-DE", "ru-RU"]).resolve(""), "en", "only the first system language counts")
        expectEqual(TestStrings.localizer(system: []).resolve(""), "en")
    }

    @Test func testResolveUnknownCodeFallsBackLikeEmpty() {
        expectEqual(TestStrings.localizer(system: ["ru"]).resolve("fr"), "ru")
        expectEqual(TestStrings.localizer(system: ["fr"]).resolve("fr"), "en")
    }

    @Test func testApplyChangesCurrentTable() {
        let l = TestStrings.localizer()
        expectEqual(l.get("Min"), "min")
        l.apply("ru")
        expectEqual(l.current, "ru")
        expectEqual(l.get("Min"), "мин")
    }

    @Test func testLoadFromDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pomo-strings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(#"{"Start": "Start"}"#.utf8).write(to: dir.appendingPathComponent("en.json"))
        try Data(#"{"Start": "Старт"}"#.utf8).write(to: dir.appendingPathComponent("ru.json"))
        let l = Localizer.load(from: dir, systemLanguages: { ["en"] })
        l.apply("ru")
        expectEqual(l.get("Start"), "Старт")
        l.apply("uk")
        expectEqual(l.get("Start"), "Start", "a missing table renders keys as themselves")
    }
}

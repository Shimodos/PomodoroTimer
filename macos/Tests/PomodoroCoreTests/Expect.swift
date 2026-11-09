import Testing

// Thin XCTest-flavoured wrappers over Swift Testing's `#expect`, so the test bodies
// read like the Windows-mirroring checklist in ARCHITECTURE.md §6. Swift Testing is
// used instead of XCTest because it ships with the Command Line Tools; XCTest needs Xcode.

func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a == b, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectEqual(_ a: Double, _ b: Double, accuracy: Double, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(a - b) <= accuracy, Comment(rawValue: "\(a) != \(b) ± \(accuracy). \(message)"), sourceLocation: sourceLocation)
}

func expectTrue(_ value: Bool, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectFalse(_ value: Bool, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!value, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectNil<T>(_ value: T?, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(value == nil, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectLessThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a < b, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectLessThanOrEqual<T: Comparable>(_ a: T, _ b: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a <= b, Comment(rawValue: message), sourceLocation: sourceLocation)
}

func expectGreaterThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(a > b, Comment(rawValue: message), sourceLocation: sourceLocation)
}

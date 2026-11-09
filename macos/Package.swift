// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PomodoroCore"),
        .executableTarget(name: "PomodoroApp", dependencies: ["PomodoroCore"]),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"]),
    ],
    // Swift 5 language mode: the AppKit glue uses plain closures and delegates
    // without strict-concurrency annotations.
    swiftLanguageModes: [.v5]
)

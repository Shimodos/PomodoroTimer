# Pomodoro for macOS — architecture and build

How the port described in [SPEC.md](SPEC.md) is organized, built, tested and shipped. Everything
below was chosen so that the whole thing can be developed from a terminal (Claude Code) without
opening Xcode's GUI: a Swift package, a shell script that wraps the binary into an `.app` bundle,
XCTest for the logic, and manual checks for the windows.

## 1. Where the code lives

Same repository, new top-level folder `macos/`. The Windows app stays at the root untouched.

```
PomodoroTimer/
├── (Windows app: *.csproj, Models/, Services/, Views/ …)   ← reference implementation, read-only for the port
├── Sounds/            shared: copied into the Mac bundle at build time
├── Assets/app-256.png shared: source of the Mac icon
├── Localization/      shared: Strings.*.xaml → JSON at build time
├── docs/macos/        this documentation
└── macos/
    ├── Package.swift
    ├── Makefile                  make app | run | test | clean | zip
    ├── Info.plist                template, version substituted by the script
    ├── Localization/
    │   └── overrides.{en,uk,ru}.json      macOS-specific labels (SPEC §13.4)
    ├── scripts/
    │   ├── bundle.sh             swift build → build/Pomodoro.app (+ icon, sounds, strings, codesign)
    │   ├── strings.py            Strings.*.xaml + overrides → {en,uk,ru}.json
    │   └── icon.sh               app-256.png → AppIcon.icns (sips + iconutil)
    ├── Sources/
    │   ├── PomodoroCore/         pure Swift, no AppKit: settings model, timer engine, schedule, colors, plurals
    │   └── PomodoroApp/          AppKit + SwiftUI: windows, views, status item, notifications, sounds, login item
    └── Tests/
        └── PomodoroCoreTests/    Swift Testing suites for PomodoroCore
```

`build/` and `.build/` are git-ignored.

## 2. Requirements on the Mac

- macOS 13 Ventura or newer (runtime target; `SMAppService` and the SwiftUI features used need 13).
- Xcode 15 or newer, **or** just the Command Line Tools (`xcode-select --install`). Verified on a
  Mac with the Command Line Tools only (Swift 6.2, macOS 26 SDK): `swift build`, `make app`,
  `codesign`, `iconutil`, `sips` and `python3` all work without Xcode. One consequence: XCTest is
  not part of the Command Line Tools, so the tests use Swift Testing (`import Testing`), which is;
  `make test` adds the framework path and disables the (incomplete) Foundation cross-import overlay
  when it detects the Command Line Tools as the active developer directory. With Xcode installed
  plain `swift test` works.
- No Apple Developer account is needed to build and run locally (ad-hoc signing). It is needed only
  for notarized downloads (§8).

## 3. Package

```swift
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
    swiftLanguageModes: [.v5]
)
```

Tools version 6.0 is needed for SwiftPM to run Swift Testing tests; the code itself stays in Swift 5
language mode, so the AppKit glue needs no strict-concurrency annotations.

No dependencies. No SwiftPM resources: sounds, strings and the icon are placed into the bundle by
`bundle.sh`, and the app reads them from `Bundle.main.resourceURL`. That keeps `swift build`
simple and avoids the `Bundle.module` lookup inside a hand-made `.app`.

### 3.1 PomodoroCore (testable, no UI)

| Type | Port of | Notes |
|---|---|---|
| `AppSettings` (`Codable`) | `Models/AppSettings.cs` | `CodingKeys` spell the PascalCase keys; `decodeIfPresent` with defaults for every field; `clone()` |
| `SettingsStore` | `SettingsService.cs`, `AppPaths.cs` | data dir resolution (`POMODORO_DATA_DIR` → `~/Library/Application Support/PomodoroTimer`), load/save/replace |
| `TimerPhase`, `TimerEngine` | `TimerEngine.cs` | injectable clock `now: () -> Date` and tick source so tests can drive time; `tick`, `stateChanged`, `phaseCompleted` as closures |
| `Schedule` | `Schedule.cs` | `duration`, `timeToFinish`, `plannedTotal`, `formatDuration`, `formatEnd` |
| `Localizer` | `Localizer.cs` | dictionary-based; `resolve`, `get`, `format("{0}")`, `plural`; loaded from the bundled JSON by the app, from inline dictionaries in tests |
| `Palette`, `AccentMath` | `ThemeManager.cs` (color math only) | hex parse/format, companions table, HSL rotation, blend |
| `ActivityLog`, `CrashLog` | same names | append-only text files, trim on first write |
| `SessionText` | `MainViewModel.BuildSessionLabel` and friends | pure functions from engine state to strings, so the label logic is unit-tested |

### 3.2 PomodoroApp

- `main.swift` — creates `NSApplication`, sets `AppDelegate`, runs.
- `AppDelegate` — loads settings, applies language and theme, creates `MainViewModel`, `MainWindowController`,
  `StatusItemController`, `NotificationCenter` wrapper, installs the main menu; `applicationShouldHandleReopen`
  shows the window; `applicationWillTerminate` saves and logs.
- `MainViewModel: ObservableObject` — port of `MainViewModel.cs` (published properties, commands as methods).
- `MainWindowController` — `NSWindow` subclass (`miniaturize` override for "minimize to menu bar"),
  `NSWindowDelegate` (`windowShouldClose`, `windowDidMove`), `NSHostingView(rootView: MainView(vm))`,
  compact resizing anchored at the top-left, level `.floating` / `.normal`, `popUp()`.
- `SettingsWindowController` — modal window hosting `SettingsView` over a `SettingsViewModel` that
  edits a draft copy; live preview of theme/accents/language; `Cancel` reverts.
- `Theme: ObservableObject` — current palette (light/dark), focus/break accents, the "viewed phase"
  switch; sets `NSApp.appearance` (`nil` for System, `.darkAqua`, `.aqua`); observes
  `NSApplication.shared.effectiveAppearance` with KVO to follow the system.
- `StatusItemController` — `NSStatusItem`, draws the circle image with `NSImage(size:flipped:drawingHandler:)`,
  builds the menu, updates tooltip.
- `Notifier` — `UNUserNotificationCenter`: authorization, `UNUserNotificationCenterDelegate` returning
  `.banner` in `willPresent` so banners show while the app is frontmost.
- `SoundPlayer` — `AVAudioPlayer` (AVFoundation), one instance, stop-then-play, `volume`.
- `LoginItem` — `SMAppService.mainApp` register / unregister / status.
- Views (SwiftUI): `MainView`, `ProgressRing` (`Shape` with trimmed circle, round caps, rotated −90°),
  `SegmentedTabs`, `PillButton`, `RoundIconButton`, `ToggleRow`, `AccentPicker`, `SettingsView`
  with the four pages. Icons are SF Symbols (SPEC §16).

### 3.3 Why AppKit windows with SwiftUI inside

SwiftUI's `Window`/`Settings` scenes and `MenuBarExtra` give too little control for this app: fixed
sizes, hiding on close instead of closing, floating level, forcing the window to the front from the
background, a custom-drawn status item image, "minimize hides" behaviour. All of that is a few lines
with `NSWindow` / `NSStatusItem`, while the views themselves are far quicker to write in SwiftUI.
So: AppKit owns windows, menus, status item, notifications, sounds; SwiftUI owns everything drawn
inside the windows.

## 4. Bundle script

`scripts/bundle.sh` (called by `make app`):

1. `swift build -c release` (add `--arch arm64 --arch x86_64` for a universal binary; the product then
   lands under `.build/apple/Products/Release/`, a single-arch build under `.build/release/` — check
   the path on the machine).
2. Lay out `build/Pomodoro.app/Contents/{MacOS,Resources}`.
3. Copy the executable to `Contents/MacOS/Pomodoro`.
4. `Info.plist` → `Contents/Info.plist`, substituting the version (from `git describe --tags` or an
   argument). Keys: `CFBundleIdentifier com.shimodos.pomodoro`, `CFBundleName Pomodoro`,
   `CFBundleExecutable Pomodoro`, `CFBundlePackageType APPL`, `CFBundleIconFile AppIcon`,
   `CFBundleShortVersionString`, `CFBundleVersion`, `LSMinimumSystemVersion 13.0`,
   `NSHighResolutionCapable true`, `NSPrincipalClass NSApplication`,
   `LSApplicationCategoryType public.app-category.productivity`. Do **not** set `LSUIElement`
   (the app keeps a Dock icon, like the Windows app keeps a taskbar button).
5. `scripts/icon.sh ../Assets/app-256.png build/AppIcon.icns` → `Contents/Resources/AppIcon.icns`
   (`sips -z` into an `.iconset` with the sizes 16, 32, 64, 128, 256 and their @2x variants up to
   256 px, then `iconutil -c icns`; the source is 256 px, so skip the 512 sizes).
6. `cp -R ../Sounds Contents/Resources/Sounds`.
7. `python3 scripts/strings.py ../Localization Localization Contents/Resources/Localization`
   (parses `<sys:String x:Key="…">…</sys:String>`, merges `overrides.<lang>.json` on top, writes
   `<lang>.json`).
8. `codesign --force --deep --sign - build/Pomodoro.app` (ad-hoc).

`make run` = `make app` then `open build/Pomodoro.app`. `make test` = `swift test` (plus the
Command Line Tools flags described in §2 when Xcode is absent).
`make zip` = `ditto -c -k --keepParent build/Pomodoro.app build/Pomodoro-<version>-macos.zip`.

Why a bundle and not `swift run`: `UNUserNotificationCenter` aborts in a process that is not inside
an `.app` bundle (`bundleProxyForCurrentProcess is nil`), the icon and the Dock name come from the
bundle, and the login item is registered by bundle identifier. Always test through `make run`.

## 5. Verified platform facts

Checked against Apple's documentation and developer forums while writing this document; re-verify on
the Mac if a build breaks on one of them.

- `SMAppService.mainApp.register()` / `unregister()` / `.status` exist from macOS 13; registration
  can end in `.requiresApproval` until the user allows it in System Settings → General → Login Items.
- `UNUserNotificationCenter.current()` requires a real `.app` bundle with a bundle identifier; a bare
  executable (even with a bundle id injected) crashes.
- SwiftUI `MenuBarExtra` exists from macOS 13 but exposes neither the `NSStatusItem` nor custom-drawn
  colored images conveniently; the port uses `NSStatusItem` directly.
- The "Swift package + shell script → .app + ad-hoc codesign" workflow is common practice. Ad-hoc
  signatures change on every build, so permissions tied to the code signature (accessibility, and
  possibly the notification grant and the login item) can reset between rebuilds. If that becomes
  annoying, create a self-signed code-signing certificate in Keychain Access and pass its name to the
  script via `CODESIGN_IDENTITY`.
- Sources: [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice),
  [SMAppService forum thread](https://developer.apple.com/forums/thread/777520),
  [UserNotifications in a command-line program](https://developer.apple.com/forums/thread/724249),
  [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra),
  [Building an .app from a SwiftPM executable](https://forums.swift.org/t/building-an-app-from-a-swift-package-manager-executable-for-macos/64409).

Things to confirm on the Mac before relying on them (not verified here): the exact `.build` product
path for universal builds; whether `NSApplication.activate(ignoringOtherApps:)` is deprecated on the
installed SDK (macOS 14 introduced `activate()`). Confirmed in phase 1: `iconutil` accepts an iconset
without the 512-px sizes; the Command Line Tools alone build AppKit/SwiftUI code and the `.app`; the
single-arch release product is at `$(swift build -c release --show-bin-path)/PomodoroApp`.

## 6. Tests

`make test` runs `PomodoroCoreTests` (Swift Testing; thin `expectEqual` / `expectTrue` helpers in
`Tests/PomodoroCoreTests/Expect.swift` keep the assertions XCTest-shaped). Minimum set, each
mirroring a Windows behaviour:

- **Engine**: start/pause keeps `remaining` within 1 tick of `endDate − now`; countdown to zero calls
  `phaseCompleted(work)` once and moves to `shortBreak`; 4 cycles → the 4th work session advances to
  `longBreak`; `LimitSessions 4` → after the 4th work session `isFinished == true`, `phase == work`,
  `remaining == total`; `skip()` on a finished run is a no-op; `setPhase` on a finished run resets
  `completedWork`; `reevaluateLimit` unfreezes a finished run when the limit grows or becomes 0;
  `reloadDurations` keeps a paused remaining, clamps it to the new total, resets an untouched one;
  `filledInRound` is `cycles` during the long break and 0 at the start of the next round.
- **Schedule**: the three worked examples in SPEC §5; `timeToFinish` from the middle of a break;
  `nil` when unlimited or finished; `formatDuration(245 min) == "4 h 05 min"` in English.
- **Settings**: decoding a Windows `settings.json` (copy one from `%AppData%\PomodoroTimer`) yields
  the same values; missing keys → defaults; garbage → defaults; encoding round-trips the keys.
- **Localizer**: `{0}` formatting with repeated placeholders; plural forms for 1, 2, 5, 11, 21, 22, 25 in
  all three languages; empty language → system or `en`.
- **Colors**: every palette entry's companion matches SPEC §12.2; hue rotation for `#123456`; bad hex
  → `#FF6B6B`; blend values for hover/pressed.
- **SessionText**: the label examples in SPEC §6.4.

Manual checklist for the windows (run with a scratch data dir: `POMODORO_DATA_DIR=/tmp/pomo make run`):

1. Launch: 25:00, Focus tab, four dots, `‹ 4 sessions ›`, label `Session 1 of 4 · 1 h 55 min left · until HH:mm`.
2. Start, pause, reset; Skip goes to the break with the break color; the title dot stays the active color when another tab is viewed.
3. Break tab while focus runs: time shows 05:00, the link "Focus running · 24:xx" returns to Focus, "Start break" switches the engine.
4. Edit → 1 min → Return; a 1-minute focus ends with sound, banner, window popping up, break auto-starting.
5. Compact ↔ normal keeps the top-left corner; pin keeps the window over other apps.
6. Settings: sliders, plan box updating, sound preview and a custom MP3, theme/accent/language live
   preview and Cancel reverting, Save applying durations without losing a paused countdown.
7. Close with "Close to the menu bar" on → window hides, menu bar item still counts, "Show" brings it back; off → the app quits.
8. "Open at login" → the item appears in System Settings → Login Items (approval hint when required).
9. Quit, relaunch: position, compact mode and settings restored; `activity.log` has the expected lines.
10. Copy a Windows `settings.json` into the data dir → same values on screen.

## 7. Development loop with Claude Code

- Work from the repository root so the Windows sources are readable as reference; edit only under `macos/` and `docs/macos/`.
- After every meaningful change: `make test`, then `make app`; a build error is fixed before moving on.
- Behaviour questions are answered by the Windows code, not by guessing; API questions by Apple's
  documentation (`developer.apple.com`), not by memory.
- Use `POMODORO_DATA_DIR` for every test run so the user's real settings are never touched.
- Commit per phase (see [KICKOFF.md](KICKOFF.md)); never commit `build/` or `.build/`.

## 8. Release (later)

A second workflow, `.github/workflows/release-macos.yml`, on the same `v*` tags, runner `macos-14`:
`make app VERSION=<tag>` → `make zip` → `gh release upload <tag> build/Pomodoro-<ver>-macos.zip`
(the Windows workflow creates the release; make the Mac job wait for it or use `--clobber`).

Without an Apple Developer ID the zip is ad-hoc signed and not notarized: Gatekeeper will refuse the
downloaded app with "cannot be opened" until the user right-clicks → Open, or runs
`xattr -d com.apple.quarantine Pomodoro.app`. Document that on the release notes and the website;
proper Developer ID signing + notarization is a separate step for when there is an account.

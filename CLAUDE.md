# Pomodoro — repository guide for Claude Code

Two native apps share this repository:

| Where | What | Status |
|---|---|---|
| repository root (`*.csproj`, `Models/`, `Services/`, `Views/`, …) | Windows app, C# / WPF, .NET 8 | shipped, v1.0.2, the reference implementation |
| `macos/` | macOS app, Swift, AppKit + SwiftUI | feature-complete port of 1.0.2; see `docs/macos/` |

Shared between them, do not duplicate: `Sounds/` (built-in alerts), `Assets/app-256.png` (icon source),
`Localization/Strings.{en,uk,ru}.xaml` (strings; the Mac build converts them to JSON).

## Working on the macOS port

- Read `docs/macos/SPEC.md` and `docs/macos/ARCHITECTURE.md` first; `docs/macos/KICKOFF.md` has the phase plan.
- Behaviour comes from the Windows code, API facts from developer.apple.com. Do not guess either.
- Touch only `macos/` and `docs/macos/`. The Windows sources, sounds, assets and XAML strings are read-only for this work.
- Build and run through `make app` / `make run` in `macos/` (a real `.app` bundle); `swift run` is not supported.
- `make test` uses Swift Testing (XCTest needs Xcode, which may be absent). `open build/Pomodoro.app --args --settings` opens the settings window at launch for manual checks.
- Interactive checks need a real mouse: SwiftUI inside `NSApp.runModal` and events synthesized in-process behave differently from the user's clicks. Ask the user to click, do not fake it.
- Test runs use `POMODORO_DATA_DIR=/tmp/pomo` so the user's real settings stay untouched.
- Keep `settings.json` compatible: same keys, same defaults, same meaning.

## Working on the Windows app

- `dotnet build -c Release`, `dotnet run` from the root. No third-party packages; keep it that way.
- Settings live in `%AppData%\PomodoroTimer` (`POMODORO_DATA_DIR` overrides). Never test against the user's real data dir.
- Strings: add every new key to all three `Localization/Strings.*.xaml` files.

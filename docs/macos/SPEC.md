# Pomodoro for macOS — behaviour specification

This document describes, feature by feature, what the native macOS port has to do. It is written
from the Windows app (C# / WPF, version 1.0.1, the code at the root of this repository), which is
the reference implementation: when this text and the Windows code disagree, the Windows code wins,
unless the difference is listed in [§16 Accepted differences](#16-accepted-differences).

The companion document [ARCHITECTURE.md](ARCHITECTURE.md) says *how* to build it (Swift package
layout, AppKit/SwiftUI split, bundle script, tests). This one says *what*.

Reference files in the Windows app, by topic:

| Topic | Windows source |
|---|---|
| Settings model, defaults | `Models/AppSettings.cs` |
| Timer state machine | `Services/TimerEngine.cs` |
| Finish-time estimate, durations, formatting | `Services/Schedule.cs` |
| Main window state and texts | `ViewModels/MainViewModel.cs`, `Views/MainWindow.xaml(.cs)` |
| Settings dialog | `ViewModels/SettingsViewModel.cs`, `Views/SettingsWindow.xaml(.cs)` |
| Colors | `Themes/Light.xaml`, `Themes/Dark.xaml`, `Services/ThemeManager.cs` |
| Strings | `Localization/Strings.en.xaml` (key reference), `.uk.xaml`, `.ru.xaml` |
| Tray icon, notifications | `Services/TrayService.cs` |
| Sounds | `Services/SoundService.cs`, `Sounds/*.wav` |
| Files on disk, logs | `Services/AppPaths.cs`, `ActivityLog.cs`, `CrashLog.cs`, `SettingsService.cs` |

## 1. Scope

- Feature parity with Pomodoro 1.0.1 for Windows: the same timer logic, the same two windows, the
  same settings, the same three languages, the same look (colors, sizes, layout), adapted to macOS
  conventions where §16 says so.
- The settings file is the same JSON with the same keys, so a `settings.json` from Windows is valid
  on the Mac and vice versa.
- Native: Swift, AppKit + SwiftUI, no Electron, no web view, no third-party packages.
- Target: macOS 13 Ventura or newer, Apple Silicon and Intel.

## 2. Settings model

One flat JSON object, pretty-printed, keys in PascalCase exactly as below. Unknown keys are ignored
on load; missing keys take the default. A broken file is replaced by the defaults (never crash).

| Key | Type | Default | Range / values | Notes |
|---|---|---|---|---|
| `WorkMinutes` | int | 25 | 1…180 (slider 1…90) | focus length |
| `ShortBreakMinutes` | int | 5 | 1…180 (slider 1…30) | |
| `LongBreakMinutes` | int | 15 | 1…180 (slider 5…60) | |
| `CyclesBeforeLongBreak` | int | 4 | slider 2…8, engine uses max(1, n) | work sessions per round |
| `AutoStartBreaks` | bool | true | | start the break when focus ends |
| `AutoStartWork` | bool | false | | start focus when a break ends |
| `LimitSessions` | bool | true | | when false, sessions are unlimited (∞) |
| `TotalSessions` | int | 4 | 1…16 | work sessions until the run is finished |
| `SoundEnabled` | bool | true | | |
| `WorkEndSound` | string | `"bell.wav"` | bare file name = built-in, absolute path = user file | |
| `BreakEndSound` | string | `"chime.wav"` | same | |
| `Volume` | double | 0.8 | 0…1 | |
| `Theme` | string | `"System"` | `"System"` / `"Dark"` / `"Light"` | |
| `Accent` | string | `"#FF6B6B"` | `#RRGGBB` | focus color |
| `BreakAccent` | string | `"auto"` | `"auto"` or `#RRGGBB` | break color; empty string behaves like `"auto"` |
| `Language` | string | `""` | `""` / `"en"` / `"uk"` / `"ru"` | empty = follow the system language |
| `NotificationsEnabled` | bool | true | | |
| `ShowOnPhaseEnd` | bool | true | | pop the window up on top when a phase ends |
| `AlwaysOnTop` | bool | false | | |
| `MinimizeToTray` | bool | true | | macOS: "minimize" hides the window instead of sending it to the Dock |
| `CloseToTray` | bool | true | | macOS: the close button hides the window, the app keeps running |
| `StartWithWindows` | bool | false | | macOS: login item (keep the key name for file compatibility) |
| `CompactMode` | bool | false | | |
| `WindowLeft` | double? | null | | macOS: window frame origin x in screen points (see §7.9) |
| `WindowTop` | double? | null | | macOS: window frame origin y in screen points (see §7.9) |

Durations are always read through `max(1, minutes)`.

## 3. Files on disk

Data directory: `~/Library/Application Support/PomodoroTimer/`. The environment variable
`POMODORO_DATA_DIR`, when set and non-blank, replaces it (portable use, tests). The directory is
created on first write.

| File | Purpose |
|---|---|
| `settings.json` | settings, written on every change (see §2) |
| `activity.log` | journal of timer events, one line per event: `yyyy-MM-dd HH:mm:ss.fff  message`; trimmed to roughly the last 100 KB once per launch when it exceeds 200 KB |
| `error.log` | unhandled errors: `[yyyy-MM-dd HH:mm:ss] <description>` followed by a blank line |

Writing any of them is best effort: disk errors never surface to the user and never stop the timer.

## 4. Timer engine

A single state machine; time is measured against the wall clock so a busy main thread or a sleeping
laptop never makes the countdown drift.

### 4.1 State

```
phase          work | shortBreak | longBreak        (initially work)
isRunning      Bool
total          duration of the current phase (re-read from settings on Reset)
remaining      stored while paused; while running it is endDate − now, never below 0
endDate        Date, valid while running
completedWork  Int, work sessions completed in this run
isFinished     Bool, true after the last of a limited number of work sessions ended
cyclesPerRound = max(1, settings.CyclesBeforeLongBreak)          (read live)
totalSessions  = settings.LimitSessions ? settings.TotalSessions : 0   (read live; 0 = unlimited)
```

A tick fires every 200 ms while running. On each tick: if `remaining <= 0` → stop the tick source,
`isRunning = false`, remember the finished phase, call `advance()`, then raise `phaseCompleted(finishedPhase)`.
Otherwise raise `tick`. The UI re-renders on `tick` and on `stateChanged`.

### 4.2 Operations

- **start()** — no-op if running. If `isFinished`, do `newRound()` first. If `remaining <= 0`,
  `remaining = total`. `endDate = now + remaining`, `isRunning = true`, start ticking, `stateChanged`.
- **pause()** — no-op if not running. `remaining = endDate − now (≥ 0)`, `isRunning = false`, stop ticking, `stateChanged`.
- **toggle()** — pause if running, else start.
- **reset()** — stop ticking, `isRunning = false`, `total = duration(phase)`, `remaining = total`, `stateChanged`.
- **setPhase(p)** — if `isFinished`: `completedWork = 0`, `isFinished = false`. Then `phase = p`, `reset()`.
- **skip()** — no-op if `isFinished`; otherwise `advance()`. Note: `advance()` does not raise `phaseCompleted` (no sound, no notification on skip).
- **reevaluateLimit()** — after the session limit changed on the main window. If not finished → nothing.
  If `totalSessions != 0 && completedWork >= totalSessions` → still finished, nothing. Otherwise
  `isFinished = false`, `phase = work`, `reset()`.
- **newRound()** — `completedWork = 0`, `isFinished = false`, `phase = work`, `reset()`.
- **reloadDurations()** — after settings changed. No-op while running. `untouched = (remaining == total)`;
  `total = duration(phase)`; `remaining = untouched ? total : min(remaining, total)`; `stateChanged`.
- **advance()** (private):
  ```
  if phase == work:
      completedWork += 1
      if totalSessions > 0 && completedWork >= totalSessions:
          isFinished = true; phase = work; reset(); return
      phase = (completedWork % cyclesPerRound == 0) ? longBreak : shortBreak
  else:
      phase = work
  reset()
  ```

### 4.3 Derived values

- **filledInRound** — work sessions finished in the current round, 0…cyclesPerRound:
  `f = completedWork % cyclesPerRound; if f == 0 && completedWork > 0 && (phase != work || isFinished) { f = cyclesPerRound }`.
- **Clock text** — `totalSeconds = ceil(remaining)`, formatted `mm:ss` with two digits each (minutes may exceed 59, e.g. `120:00`).
- **Minutes left for the menu bar** — `ceil(remaining in minutes)`, `0` when finished.

### 4.4 Activity log lines

Every operation writes one line (same wording as Windows, see `TimerEngine.cs`): `Start …`, `Pause …`,
`Reset while running …`, `SetPhase a -> b …`, `Skip …`, `ReloadDurations …`, `Advance a -> b …`,
`Finished: n/m sessions done`, `Completed <phase> by countdown (end=HH:mm:ss.fff)`. The UI adds
`UI: …` lines for button presses and settings saves. Launch writes `App start v<version> data=<dir>`,
exit writes `App exit`.

## 5. Schedule

- **duration(phase)** — `max(1, minutes)` of the matching setting, as a time interval.
- **timeToFinish(settings, phase, completed, remainingCurrent, finished)** — time until the last
  work session ends, assuming no pauses. `nil` when `LimitSessions` is off, `TotalSessions <= 0`, or
  `finished`. Algorithm, with `total = TotalSessions`, `cycles = max(1, CyclesBeforeLongBreak)`:
  ```
  t = remainingCurrent; p = phase; c = completed
  loop (guard 10 000 iterations):
      if p == work:
          c += 1
          if c >= total: return t
          p = (c % cycles == 0) ? longBreak : shortBreak
      else:
          p = work
      t += duration(p)
  ```
- **plannedTotal(settings)** — `timeToFinish(settings, work, 0, duration(work), false)`: the whole
  plan from a cold start.
- **formatEnd(left)** — `now + left` as `HH:mm`, 24-hour clock.
- **formatDuration(t)** — minutes rounded to the nearest integer; `"<rest> min"` when under an hour,
  `"<hours> h"` when rest is 0, otherwise `"<hours> h <rest:00> min"` (`h`/`min` are the localized `Hours`/`Min` strings).
- **sessionsWord(n)** — plural form of "session" (§13.3).

Worked examples (25 / 5 / 15, 4 cycles):

| Sessions | plannedTotal | formatDuration |
|---|---|---|
| 4 | 4×25 + 3×5 = 115 min | `1 h 55 min` |
| 8 | 8×25 + 6×5 + 1×15 = 245 min | `4 h 05 min` |
| 1 | 25 min | `25 min` |

## 6. Main window: state model

The engine owns the **active** phase and its countdown. The three tabs select a **viewed** phase,
which is only a way to look at (and edit) another phase's duration without touching the running
timer. `viewingActive = (viewedPhase == engine.phase)`.

### 6.1 Texts and values (recomputed on every tick / state change)

| Value | When viewing the active phase | When viewing another tab |
|---|---|---|
| time text | clock of `engine.remaining`; `00:00` when finished | clock of `duration(viewedPhase)` |
| progress (ring, 0…1) | `remaining / total`; 0 when finished or total is 0 | 1 |
| status line | finished → `Status_Finished`; running → phase title; paused (remaining ≠ total) → `Status_Paused` with phase title; otherwise `Status_Ready` with phase title | `Status_Ready` with the viewed phase's title |
| active-info link | hidden | shown only if the active phase is in progress (`running` or `remaining ≠ total`) and not finished: `Active_Running` / `Active_Paused` with the active phase title and its clock; colored with the **active** phase's accent; clicking it selects the active tab |
| primary button | running → `Pause`; finished → `Restart`; else `Start` | `Start_Work` / `Start_Short` / `Start_Long` for the viewed phase |
| primary button icon | running → pause; finished → restart (circular arrow); else play | play |
| Reset button | enabled | disabled |
| Skip button | enabled unless finished | disabled |
| Edit link | visible when not compact, not editing, and the timer is not running | visible when not compact and not editing |

Phase titles: `Phase_Work` ("Focus"), `Phase_Short` ("Short break"), `Phase_Long` ("Long break").
Tab captions: `Tab_Work` ("Focus"), `Tab_Short` ("Break"), `Tab_Long` ("Long").

### 6.2 Actions

- **Primary button** — viewing active: `engine.toggle()`. Viewing another tab: `engine.setPhase(viewed)`
  then `engine.start()`. In both cases the view then follows the engine (`viewedPhase = engine.phase`).
- **Reset** — `engine.reset()`. **Skip** — `engine.skip()`, then follow the engine.
- **Tab click** — sets `viewedPhase`, cancels in-place editing. Never touches the engine.
- **Session stepper** ‹ › — `current = LimitSessions ? TotalSessions : 0`; `next = clamp(current ± 1, 0, 16)`;
  `LimitSessions = next > 0`; if `next > 0` then `TotalSessions = next`; save; `engine.reevaluateLimit()`;
  if the run was finished and is not any more, follow the engine. Caption: `"<n> <sessions>"` or
  `"∞ · <Loops_Unlimited>"`; tooltip `Loops_Tip`.
- **Pin** (always on top) — toggles `AlwaysOnTop`, saves, applies to the window level immediately.
- **Compact** — toggles `CompactMode`, saves, cancels editing (§7.7).
- **Settings** — opens the settings window (§8). **⌘,** does the same.

### 6.3 Phase completed (from the engine, after `advance()` already ran)

```
wasWork = finishedPhase == work
if SoundEnabled: play(wasWork ? WorkEndSound : BreakEndSound, Volume)
if ShowOnPhaseEnd: pop the window up (§7.8)
if engine.isFinished:
    if NotificationsEnabled: notify(Notify_AllDone_Title, Notify_AllDone_Text with completedWork)
    follow the engine; return
if NotificationsEnabled:
    if wasWork: minutes = (engine.phase == longBreak) ? LongBreakMinutes : ShortBreakMinutes
               notify(Notify_WorkDone_Title, Notify_WorkDone_Text with minutes)
    else:      notify(Notify_BreakDone_Title, Notify_BreakDone_Text)
if (wasWork ? AutoStartBreaks : AutoStartWork): engine.start()
follow the engine
```

### 6.4 Cycle dots and session label

- Dots: `cycles = cyclesPerRound`, `filled = filledInRound`, `current = (engine.phase == work && !finished) ? filled : -1`.
  One dot per cycle: dot `i` is filled when `i < filled`, outlined ("current") when `i == current`.
- Session label (muted text under the stepper):
  - Limited (`totalSessions > 0`):
    - finished: `Session_Done` when `totalSessions == 1`, else `All_Done` with `totalSessions` and `sessionsWord`.
    - otherwise `number = (phase == work) ? min(completedWork + 1, totalSessions) : completedWork`;
      `prefix = (phase == work ? Session_Of : Done_Of)` with `number, totalSessions`;
      if `timeToFinish` is not nil: `"<prefix> · <Left_Label(formatDuration)> · <Until(formatEnd)>"`, else just `prefix`.
      Example: `Session 2 of 4 · 1 h 25 min left · until 17:42`.
  - Unlimited: `Session_Of(min(filled + 1, cycles), cycles)` during work, `Done_Of(filled, cycles)` during breaks.

### 6.5 In-place duration editing

- "Edit" link under the time → the time block is replaced by: `−` button, a numeric text field
  (digits only, 92 pt wide), `+` button, the word `Min` under them, then two small round buttons:
  commit (checkmark, filled with the accent) and cancel (cross).
- Opens with the viewed phase's minutes; ± step 5; value clamped to 1…180.
- Return commits, Escape cancels. The field gets focus with all text selected when the editor appears.
- Commit: clamp, write to `WorkMinutes` / `ShortBreakMinutes` / `LongBreakMinutes` of the viewed
  phase, save, log `UI: duration <phase> = <n> min`, `engine.reloadDurations()`, leave edit mode, refresh.

## 7. Main window: layout and behaviour

### 7.1 Size and chrome

- Fixed size, not resizable: **340 × 540 pt** normal, **250 × 300 pt** compact.
- Native window with the standard traffic lights, transparent title bar, hidden title, full-size
  content view, movable by dragging the background. Rounded corners come from the system.
- Background `WindowBg`, text `TextBrush`, system font (SF Pro). The whole window tints with the
  **viewed** phase's accent (§12.3): focus color on the Focus tab, break color on either break tab.

### 7.2 Title row (44 pt)

Centered: a 10 pt dot filled with the **active** phase's accent, then "Pomodoro" (13 pt, semibold,
muted). Both are hidden in compact mode (macOS decision: the traffic lights already occupy the left,
so the Windows left-aligned title would sit off-center; the compact window keeps only the buttons).
Right: three 28-pt icon buttons: pin (tinted with the accent when `AlwaysOnTop`), compact / normal
(tooltips `Tip_Compact` / `Tip_Normal`), settings (`Tip_Settings`). The Windows minimize and close
buttons are not reproduced; the traffic lights do that.

### 7.3 Tabs (hidden in compact mode)

A segmented control centered under the title row: container `ControlBgBrush`, corner radius 12,
padding 4; each segment corner radius 9. The selected segment is filled with the accent and uses
`OnAccentBrush` text. The segment whose phase is live (the engine's phase) and is not selected shows a
small dot in that phase's color (focus accent for Focus, break accent for Break and Long).

### 7.4 Ring and time

- Ring: 236 pt, stroke 10 (compact 156 / 7). Track `TrackBrush`, progress in the accent with round
  caps, starting at 12 o'clock, clockwise; value 1 draws a full circle.
- Inside, vertically centered: the time (58 pt light, monospaced digits; compact 38 pt), the status
  line (13 pt muted; hidden in compact), the active-info link (same size, accent of the active phase),
  the Edit link (pencil icon + `Edit`, 13 pt, muted; hidden in compact).

### 7.5 Controls row

Centered: round Reset button (48 pt, `ControlBgBrush`, icon `arrow.counterclockwise`, tooltip `Tip_Reset`),
primary pill button (min width 150, height 48, corner radius 24, accent fill, white text; compact 110 × 40)
with the play / pause / restart icon and the text from §6.1, round Skip button (icon `forward.end`, tooltip `Tip_Skip`).
Disabled round buttons are drawn at reduced opacity.

### 7.6 Footer (hidden in compact mode)

Cycle dots (8 pt, 4 pt gaps, filled = accent, current = 1.5 pt accent outline, empty = `TrackBrush`),
then the session stepper `‹  4 sessions  ›` (28 pt step buttons, caption 13 pt semibold, min width 130),
then the session label (12 pt, muted). Bottom margin 22 pt.

### 7.7 Compact mode

Hides the tabs, the footer, the "Pomodoro" title with its dot and the status line; shrinks the ring, time and
primary button as above; resizes the window to 250 × 300 keeping the **top-left** corner in place.
Editing is not available in compact mode and is cancelled when entering it. Persisted in `CompactMode`.

### 7.8 Showing, hiding, popping up

- **Close button / ⌘W** — if `CloseToTray`: hide the window (`orderOut`), the app keeps running with
  its menu bar item and Dock icon. Otherwise quit (§7.10).
- **Minimize / ⌘M** — if `MinimizeToTray`: hide the window instead of miniaturizing. Otherwise the
  normal Dock miniaturize.
- **Show** — from the menu bar item's "Show", from clicking the Dock icon (reopen), or from the
  Window menu: show the window, de-miniaturize if needed, activate the app, make it key.
- **Pop up on phase end** (`ShowOnPhaseEnd`): show as above, then force it in front of every other
  window right now even if the app is in the background: `orderFrontRegardless()`, and if
  `AlwaysOnTop` is off, raise the level to floating and drop it back to normal on the next run-loop
  turn, so the window is on top once but not permanently. Log `UI: pop up window on phase end`.
- **Always on top** — window level `.floating` when `AlwaysOnTop`, `.normal` otherwise.

### 7.9 Position

Saved on every move while visible (and on quit) into `WindowLeft` / `WindowTop` as the window frame
origin in screen points. Restored on launch only when the point `(left, top)` lies inside the union
of all screens with at least 100 pt of slack; otherwise the window is centered on the main screen.

### 7.10 Quit

From the menu bar item's "Quit", the app menu, or ⌘Q: save position and settings, log `App exit`,
stop sounds, remove the menu bar item, terminate. Quitting while the timer runs is allowed and
silent (same as Windows).

### 7.11 Keyboard

⌘, settings · ⌘W close/hide · ⌘M minimize · ⌘Q quit · Space start/pause when the window is key and
no text field has focus · Return / Escape inside the duration editor (§6.5).

## 8. Settings window

### 8.1 Frame

A separate window, **600 × 680 pt**, not resizable, centered over the main window, opened as a
sheet-like modal (the main window does not react to clicks while it is open). Title row 44 pt with
"Settings" (13 pt semibold muted) and the standard close button. Body: left column 150 pt with four
navigation items (Timer, Sound, Appearance, System; 3 × 16 pt accent marker on the selected one),
right side a card (`SurfaceBrush`, corner radius 14, padding 24 × 20) that scrolls vertically.
Footer, right-aligned: `Cancel` (secondary pill) and `Save` (primary pill, height 40, min width 130).

### 8.2 Draft semantics

The window edits a **copy** of the settings. Timer, sound and system values apply only on Save.
Theme, both accents and language are a **live preview**: they apply to the whole app immediately as
the user clicks, and Cancel, the close button or Escape restore the saved theme, accents and language.
Save: replace the current settings with the draft, write the file, apply the theme, log
`UI: settings saved work=… short=… long=… cycles=… limit=…/… autoBreak=… autoWork=…`, close, then on
the main window: `engine.reloadDurations()`, apply `AlwaysOnTop`, apply the login item (§15), refresh.

### 8.3 Timer page

Section title `Nav_Timer`. Four sliders, each with a label on the left and the value on the right
(`"25 min"` via the `Min` string, cycles as a bare number):

| Setting | Slider range |
|---|---|
| `Label_Work` | 1…90 |
| `Label_Short` | 1…30 |
| `Label_Long` | 5…60 |
| `Label_Cycles` | 2…8 |

Then two switches `AutoBreaks`, `AutoWork`; then the switch `LimitSessions`, and when it is on: the
`TotalSessions` slider 1…16 and a rounded info box (`ControlBgBrush`, radius 10, padding 14 × 10) with
`Plan_End` (15 pt semibold: "Ends at 17:42") and `Plan_Duration` (hint style: "8 sessions · 4 h 05 min
with breaks, if started now"), both recomputed from the draft on every change via `plannedTotal`.

Values set through in-place editing can exceed a slider's maximum (up to 180). Show such a value at
the slider's maximum position with the real number in the value label; the stored value changes only
when the user moves the slider.

### 8.4 Sound page

Switch `SoundEnabled`. Two rows, `WorkEndSound` and `BreakEndSound`: a pop-up button listing the
sounds, a small round preview button (play icon, `Tip_Preview`) and a small round browse button
(folder icon, `Tip_Browse`). The list shows the eight built-in sounds in this order with localized
names — bell, chime, ding, soft, marimba, beep, digital, alarm (`Sound_<stem>` strings) — followed by
any user files as `Sound_Custom` ("Custom: name.mp3"). Browse opens an open panel (`Dialog_PickSound`,
WAV and MP3) and selects the chosen file; a file picked for one row is then available in both lists.
Preview plays the selected file at the draft's volume. Then the `Volume` slider 0…1 (value shown as
`"80 %"`) and the hint `Sound_Hint`.

### 8.5 Appearance page

`Theme` segmented control (System / Dark / Light), `Accent` picker: eight round swatches of the
palette (§12.2) in a wrapping row, each a 24-pt dot inside a 36-pt cell (27 pt on hover); the
selected one gets a 34-pt, 2-pt-thick ring in `TextBrush` around it.
`Accent_Break` picker: the same eight swatches preceded by an "A" swatch (tooltip `Accent_Auto`) whose
color is the companion of the current focus accent and updates when the focus accent changes.
`Language` segmented control: "English", "Українська", "Русский". Hint `Look_Hint`.
Changing the language re-renders every string in both windows immediately (sound names included).

### 8.6 System page

Six switches, in this order: `Notifications`, `ShowOnPhaseEnd`, `AlwaysOnTop`, `MinimizeToTray`,
`CloseToTray`, `StartWithWindows` (macOS labels in §13.4), then the hint `System_Hint`. When the login
item needs approval (§15), show a second hint line under the last switch.

### 8.7 Switch style

44 × 24 pt pill with a 16-pt knob (18 pt on hover), 4 pt from the left edge when off and 24 pt when
on. Off: track `ControlHoverBrush`, knob `TextMutedBrush`. On: track accent, knob `OnAccentBrush`.
Label (13 pt) on the left, switch on the right, 12 pt below each row.

## 9. Menu bar item

Replaces the Windows tray icon. An `NSStatusItem` of variable length in the system menu bar.

- **Image**: drawn, not a template. A circle of 18 × 18 pt (render at 2× for Retina): when running,
  filled with the active phase's accent; when paused, filled dark grey `#3C3C44` with a 2.5-px ring in
  the accent. White bold text centered: the minutes left (`ceil`), or `✓` when the run is finished.
  Font 13 px for one or two characters, 10 px for longer (in Windows' 32-px icon; scale to the point size).
  Re-rendered only when minutes, running state or accent changed.
- **Tooltip**: `"Pomodoro — <phase title> <mm:ss>"`, or `Tray_AllDone` when finished.
- **Menu** (opens on click): `Tray_Show`, `Start` / `Pause` (whichever applies, toggles the engine
  and logs `UI: tray toggle`), separator, `Settings_Title…` (shows the main window and opens the
  settings window), separator, `Tray_Exit`. Captions follow the current language.

The app also has the standard macOS main menu: application menu with Settings… (⌘,) and Quit (⌘Q),
Window menu with Minimize (⌘M) and Close (⌘W).

## 10. Notifications

User Notifications framework. When `NotificationsEnabled` is on at launch or is switched on, request
authorization for alerts (no sound: the app plays its own). Deliver as banners even when the app is
frontmost. Texts: §6.3, from the strings table. If authorization is denied, do nothing (no dialogs).

## 11. Sounds

- Built-in files are the eight WAVs from `Sounds/` at the repository root, bundled into the app under
  `Contents/Resources/Sounds/` (the bundle script copies them; they are not duplicated in git).
- A setting holding a bare name resolves to the bundled file; an absolute path is used as is. A
  missing file plays nothing, a broken file is ignored silently.
- Playback: one player; a new play stops the previous one; volume 0…1. WAV and MP3 must work.

## 12. Theme and colors

### 12.1 Theme palettes

| Key | Light | Dark | Used for |
|---|---|---|---|
| `WindowBg` | `#F7F7FA` | `#1B1B20` | window background |
| `SurfaceBrush` | `#FFFFFF` | `#25252C` | settings card |
| `ControlBgBrush` | `#ECECF1` | `#2A2A32` | tab container, round buttons, switches off, info box |
| `ControlHoverBrush` | `#E1E1E8` | `#35353F` | hover |
| `ControlPressedBrush` | `#D6D6DE` | `#3F3F4A` | pressed |
| `TrackBrush` | `#E4E4EA` | `#2E2E37` | ring track, empty dots, slider track |
| `DividerBrush` | `#14000000` | `#1AFFFFFF` | separators |
| `TextBrush` | `#1B1B20` | `#F4F4F6` | text |
| `TextMutedBrush` | `#6E6E7A` | `#9A9AA6` | secondary text |
| `OnAccentBrush` | `#FFFFFF` | `#FFFFFF` | text on accent |
| `TitleBtnHoverBrush` | `#12000000` | `#1AFFFFFF` | title-row icon buttons hover |
| `TitleBtnPressedBrush` | `#1F000000` | `#2BFFFFFF` | pressed |
| `ThumbBorderBrush` | `#FFFFFF` | `#1B1B20` | ring around the selected swatch / slider knob |

`Theme = "System"` follows the system appearance and switches live when it changes.
`"Dark"` / `"Light"` force the app's appearance regardless of the system.

### 12.2 Accent palette and companions

Palette, in picker order: `#FF6B6B #FF8E3C #F5C542 #4ECB71 #38BDF8 #6C8CFF #B07CFF #F472B6`.

Break accent `"auto"` = companion of the focus accent:

| Focus | Companion |
|---|---|
| `#FF6B6B` | `#38BDF8` |
| `#FF8E3C` | `#6C8CFF` |
| `#F5C542` | `#B07CFF` |
| `#4ECB71` | `#F472B6` |
| `#38BDF8` | `#FF8E3C` |
| `#6C8CFF` | `#F5C542` |
| `#B07CFF` | `#4ECB71` |
| `#F472B6` | `#4ECB71` |

Any other focus color (only possible from a hand-edited file): convert to HSL, hue + 180°,
saturation `min(s, 0.85)`, lightness `clamp(l, 0.5, 0.65)`, back to RGB. An unparsable hex falls
back to `#FF6B6B`.

### 12.3 Derived accent brushes

With `accent` = focus or break accent depending on the viewed phase:

- `AccentHover` = blend(accent → white, 12 %), `AccentPressed` = blend(accent → black, 15 %),
  `AccentSoft` = accent at alpha 0x2E (≈ 18 %). Blend is per channel: `a + (b − a) × t`, rounded.

## 13. Localization

### 13.1 Source of truth

The three XAML dictionaries at the repository root, `Localization/Strings.{en,uk,ru}.xaml`, stay the
single source: the macOS build converts them to JSON (`{"Key": "Value"}`) and bundles the result. A
small override file per language, kept in the macOS folder, replaces the handful of Windows-specific
labels (§13.4). Keys are used verbatim in Swift (`L("Status_Ready")`).

### 13.2 Placeholders

Values use `{0}`, `{1}`, `{2}` positional placeholders; format by replacing them with the arguments'
descriptions (`Notify_AllDone_Text` uses `{0}` twice).

### 13.3 Language resolution and plurals

- Supported: `en`, `uk`, `ru`. Stored `Language` empty or unknown → the system's preferred language
  if it is `ru` or `uk`, else `en`.
- Plural forms `Sessions_One / Sessions_Few / Sessions_Many`: English → `One` for 1, else `Many`.
  Ukrainian and Russian → `n % 10 == 1 && n % 100 != 11` → `One`; `n % 10 in 2…4 && n % 100 not in 12…14` → `Few`; else `Many`.
- A missing key renders as the key itself.

### 13.4 macOS label overrides

| Key | en | uk | ru |
|---|---|---|---|
| `Notifications` | Notifications | Сповіщення | Уведомления |
| `MinimizeToTray` | Minimize to the menu bar | Згортати в рядок меню | Сворачивать в строку меню |
| `CloseToTray` | Close to the menu bar | Закривати в рядок меню | Закрывать в строку меню |
| `StartWithWindows` | Open at login | Відкривати під час входу | Открывать при входе в систему |
| `System_Hint` | If close-to-menu-bar is off, the close button quits the app. You can always quit from the menu bar icon. | Якщо закриття в рядок меню вимкнено, кнопка закриття повністю закриває програму. Вийти завжди можна через іконку в рядку меню. | Если закрытие в строку меню выключено, кнопка закрытия полностью завершает программу. Выйти всегда можно через иконку в строке меню. |
| `Tray_Exit` | Quit Pomodoro | Завершити Pomodoro | Завершить Pomodoro |
| `Login_Approval` (new) | Allow Pomodoro in System Settings → General → Login Items. | Дозвольте Pomodoro у Системних параметрах → Основні → Об'єкти входу. | Разрешите Pomodoro в Системных настройках → Основные → Объекты входа. |

## 14. Error handling

Unhandled errors are appended to `error.log` and shown in an alert titled `Error_Title`; the app
keeps running. Settings, logs, sounds, notifications and the login item are all best effort.

## 15. Login item

`StartWithWindows` maps to a login item registered through `SMAppService.mainApp` (macOS 13+): on
Save with the switch on → `register()`, with it off → `unregister()`. On launch, if the setting is on
and the status is "not registered", register again. If the status is "requires approval", show the
`Login_Approval` hint under the switch. Errors are logged, never shown.

## 16. Accepted differences

| Windows | macOS |
|---|---|
| Borderless window with own minimize / close buttons | Native window chrome with traffic lights; pin, compact and settings buttons stay in the title row |
| Tray icon, left click shows the window, right click opens the menu | Menu bar item, click opens the menu: Show, Start/Pause, Settings…, Quit; the Dock icon also shows the window |
| Title "Pomodoro" with the phase dot at the left of the title bar, dot kept in compact mode | Centered after the traffic lights; hidden entirely in compact mode |
| Balloon notification from the tray icon | User Notifications banner |
| "Start with Windows" via the Run registry key | Login item via `SMAppService`, may require user approval |
| Fluent icons (Segoe) | SF Symbols |
| Segoe UI Variable | SF Pro (system font) |
| DWM rounded corners, custom title-bar drag | System corners; window movable by background |
| `Minimize to tray` | Minimize hides the window (no Dock miniaturize) when on |
| Modal dialog | Modal settings window, same Save / Cancel semantics |
| No main menu | Standard app menu with ⌘, ⌘W ⌘M ⌘Q and Space to start / pause |

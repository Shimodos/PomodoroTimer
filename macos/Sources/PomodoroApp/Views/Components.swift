import SwiftUI
import PomodoroCore

/// Circular progress: value 1 is a full ring, 0 is empty; the arc starts at 12 o'clock
/// and runs clockwise with round caps (port of `Controls/ProgressRing.cs`).
struct ProgressRing: View {
    var value: Double
    var lineWidth: CGFloat
    var track: Color
    var progress: Color

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(progress, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Tracks hover and press for custom button chrome.
struct PressableStyle: ButtonStyle {
    var onPressChange: (Bool) -> Void = { _ in }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { onPressChange($0) }
    }
}

/// 28-pt title-row icon button (`TitleButton` style): rounded 8, hover / pressed tint.
struct TitleIconButton: View {
    @EnvironmentObject var theme: Theme
    var symbol: String
    var tint: Color? = nil
    var help: String
    var action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint ?? theme.textMuted)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(pressed ? theme.titleBtnPressed : hover ? theme.titleBtnHover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle { pressed = $0 })
        .onHover { hover = $0 }
        .help(help)
    }
}

/// 48-pt round secondary button (`RoundButton` style): `ControlBgBrush`, reduced opacity when disabled.
struct RoundIconButton: View {
    @EnvironmentObject var theme: Theme
    var symbol: String
    var size: CGFloat = 48
    var enabled: Bool = true
    var help: String
    var action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.33, weight: .medium))
                .foregroundColor(theme.text)
                .frame(width: size, height: size)
                .background(Circle().fill(pressed ? theme.controlPressed : hover ? theme.controlHover : theme.controlBg))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle { pressed = $0 })
        .onHover { hover = $0 }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .help(help)
    }
}

/// Accent-filled pill (`PrimaryButton`): min width 150, height 48, radius 24.
struct PillButton: View {
    @EnvironmentObject var theme: Theme
    var symbol: String
    var title: String
    var minWidth: CGFloat = 150
    var height: CGFloat = 48
    var action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 14, weight: .bold))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(theme.onAccent)
            .padding(.horizontal, 24)
            .frame(minWidth: minWidth, minHeight: height, maxHeight: height)
            .background(Capsule().fill(pressed ? theme.accentPressed : hover ? theme.accentHover : theme.accent))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle { pressed = $0 })
        .onHover { hover = $0 }
    }
}

/// 28-pt step button (‹ › − +) with a subtle round hover.
struct StepButton: View {
    @EnvironmentObject var theme: Theme
    var symbol: String
    var help: String = ""
    var action: () -> Void
    @State private var hover = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(theme.textMuted)
                .frame(width: 28, height: 28)
                .background(Circle().fill(pressed ? theme.controlPressed : hover ? theme.controlBg : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle { pressed = $0 })
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Small round editor button (commit / cancel), 30 pt.
struct SmallRoundButton: View {
    @EnvironmentObject var theme: Theme
    var symbol: String
    var filled: Bool = false
    var help: String = ""
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(filled ? theme.onAccent : theme.text)
                .frame(width: 30, height: 30)
                .background(Circle().fill(filled ? (hover ? theme.accentHover : theme.accent) : (hover ? theme.controlHover : theme.controlBg)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Text-only link button (`LinkButton`): muted, 13 pt, brighter on hover.
struct LinkButton<Label: View>: View {
    @EnvironmentObject var theme: Theme
    var color: Color? = nil
    var help: String = ""
    var action: () -> Void
    @ViewBuilder var label: () -> Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 13))
                .foregroundColor(color ?? (hover ? theme.text : theme.textMuted))
                .opacity(color != nil && hover ? 0.8 : 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// Segmented tabs (`ModeTab`): container radius 12 / padding 4, segment radius 9, the
/// selected one filled with the accent; a small dot marks the live phase when not selected.
struct SegmentedTabs: View {
    @EnvironmentObject var theme: Theme
    var selected: TimerPhase
    var active: TimerPhase
    var captions: (TimerPhase) -> String
    var onSelect: (TimerPhase) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimerPhase.allCases, id: \.self) { phase in
                TabSegment(
                    title: captions(phase),
                    isSelected: phase == selected,
                    liveDot: phase == active && phase != selected ? theme.accent(for: phase) : nil,
                    action: { onSelect(phase) }
                )
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.controlBg))
    }
}

private struct TabSegment: View {
    @EnvironmentObject var theme: Theme
    var title: String
    var isSelected: Bool
    var liveDot: Color?
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? theme.onAccent : hover ? theme.text : theme.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 9).fill(isSelected ? theme.accent : .clear))
                .overlay(alignment: .topTrailing) {
                    if let dot = liveDot {
                        Circle().fill(dot).frame(width: 6, height: 6).offset(x: 3, y: -3)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Cycle dots: 8 pt, 4 pt gaps; filled = accent, current = accent outline, empty = track.
struct CycleDots: View {
    @EnvironmentObject var theme: Theme
    var dots: [CycleDot]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(dots) { dot in
                Circle()
                    .fill(dot.filled ? theme.accent : theme.track)
                    .overlay(Circle().strokeBorder(dot.current ? theme.accent : .clear, lineWidth: 1.5))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

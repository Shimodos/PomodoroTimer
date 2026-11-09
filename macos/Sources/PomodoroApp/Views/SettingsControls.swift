import SwiftUI
import PomodoroCore

/// Section heading inside the card (`SectionTitle`).
struct SectionTitle: View {
    @EnvironmentObject var theme: Theme
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(theme.text)
            .padding(.bottom, 16)
    }
}

/// Label on the left, accent-colored value on the right, then a slider (`ModernSlider`).
struct SliderRow: View {
    @EnvironmentObject var theme: Theme
    var label: String
    var valueText: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var bottom: CGFloat = 10

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.system(size: 13)).foregroundColor(theme.text)
                Spacer()
                Text(valueText).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.accent)
            }
            AccentSlider(
                value: Binding(
                    get: { Double(min(max(value, range.lowerBound), range.upperBound)) },
                    set: { value = Int($0.rounded()) }
                ),
                range: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
        .padding(.bottom, bottom)
    }
}

/// Slim slider: 4-pt track, accent fill, 16-pt knob with a `ThumbBorder` ring.
struct AccentSlider: View {
    @EnvironmentObject var theme: Theme
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 0
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let knob: CGFloat = 16
            let fraction = CGFloat((value - range.lowerBound) / max(range.upperBound - range.lowerBound, 0.0001))
            let x = (w - knob) * min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(theme.track).frame(height: 4)
                Capsule().fill(theme.accent).frame(width: x + knob / 2, height: 4)
                Circle()
                    .fill(theme.accent)
                    .overlay(Circle().strokeBorder(theme.thumbBorder, lineWidth: 2))
                    .frame(width: knob, height: knob)
                    .scaleEffect(dragging ? 1.15 : 1)
                    .offset(x: x)
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        dragging = true
                        let f = Double(min(max((g.location.x - knob / 2) / (w - knob), 0), 1))
                        var v = range.lowerBound + f * (range.upperBound - range.lowerBound)
                        if step > 0 { v = (v / step).rounded() * step }
                        value = min(max(v, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragging = false }
            )
        }
        .frame(height: 20)
    }
}

/// Label on the left, 44 × 24 switch on the right (`ToggleSwitch`, SPEC §8.7).
struct SwitchRow: View {
    @EnvironmentObject var theme: Theme
    var label: String
    @Binding var isOn: Bool
    @State private var hover = false

    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(theme.text)
            Spacer()
            ZStack(alignment: .leading) {
                Capsule().fill(isOn ? theme.accent : theme.controlHover).frame(width: 44, height: 24)
                Circle()
                    .fill(isOn ? theme.onAccent : theme.textMuted)
                    .frame(width: hover ? 18 : 16, height: hover ? 18 : 16)
                    .offset(x: isOn ? (hover ? 23 : 24) : (hover ? 3 : 4))
            }
            .animation(.easeOut(duration: 0.15), value: isOn)
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
            .onHover { hover = $0 }
        }
        .padding(.bottom, 12)
    }
}

/// Row of round color swatches (`AccentPicker`): 24-pt dot in a 36-pt cell, 34-pt ring
/// in `TextBrush` around the selected one; an optional "A" swatch for auto.
struct AccentPicker: View {
    @EnvironmentObject var theme: Theme
    struct Option: Identifiable {
        let key: String
        let hex: String
        var label: String = ""
        var help: String = ""
        var id: String { key }
    }
    var options: [Option]
    var selected: String
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { opt in
                Swatch(option: opt, isSelected: opt.key == selected) { onSelect(opt.key) }
            }
        }
    }

    private struct Swatch: View {
        @EnvironmentObject var theme: Theme
        var option: Option
        var isSelected: Bool
        var action: () -> Void
        @State private var hover = false

        var body: some View {
            Button(action: action) {
                ZStack {
                    if isSelected {
                        Circle().strokeBorder(theme.text, lineWidth: 2).frame(width: 34, height: 34)
                    }
                    Circle()
                        .fill(Color(rgb: AccentMath.parse(option.hex)))
                        .frame(width: hover ? 27 : 24, height: hover ? 27 : 24)
                    if !option.label.isEmpty {
                        Text(option.label).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .help(option.help)
            .animation(.easeOut(duration: 0.1), value: hover)
        }
    }
}

/// Segmented control reused for theme and language choices (same chrome as the tabs).
struct SegmentedChoice: View {
    @EnvironmentObject var theme: Theme
    var options: [(key: String, title: String)]
    var selected: String
    var onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.key) { opt in
                Segment(title: opt.title, isSelected: opt.key == selected) { onSelect(opt.key) }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.controlBg))
    }

    private struct Segment: View {
        @EnvironmentObject var theme: Theme
        var title: String
        var isSelected: Bool
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
                    .contentShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
        }
    }
}

/// Settings navigation item (`NavItem`): 14 × 9 padding, radius 8, 3 × 16 accent marker when selected.
struct NavItem: View {
    @EnvironmentObject var theme: Theme
    var title: String
    var isSelected: Bool
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? theme.accent : .clear)
                    .frame(width: 3, height: 16)
                    .padding(.leading, 4)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected || hover ? theme.text : theme.textMuted)
                    .padding(.leading, 7)
                Spacer()
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? theme.controlBg : hover ? theme.titleBtnHover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .padding(.bottom, 2)
    }
}

/// Secondary pill (`SecondaryButton`): `ControlBgBrush`, height 40.
struct SecondaryPill: View {
    @EnvironmentObject var theme: Theme
    var title: String
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.text)
                .padding(.horizontal, 24)
                .frame(minWidth: 100, minHeight: 40, maxHeight: 40)
                .background(Capsule().fill(hover ? theme.controlHover : theme.controlBg))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Muted hint text (`SettingHint`).
struct HintText: View {
    @EnvironmentObject var theme: Theme
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

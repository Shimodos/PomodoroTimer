import SwiftUI
import PomodoroCore

/// The main window content (SPEC §7). Layout rows: title 44 · tabs · ring · controls · footer.
struct MainView: View {
    @ObservedObject var vm: MainViewModel
    @EnvironmentObject var theme: Theme
    @FocusState private var editFocused: Bool

    private var L: Localizer { vm.env.localizer }
    private var compact: Bool { vm.isCompact }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
            if !compact {
                SegmentedTabs(
                    selected: vm.viewedPhase,
                    active: vm.snap.activePhase,
                    captions: { SessionText.tabCaption($0, L) },
                    onSelect: { vm.selectTab($0) }
                )
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
            ring
            Spacer(minLength: 0)
            controls
                .padding(.bottom, compact ? 18 : 10)
            if !compact { footer }
        }
        .frame(width: compact ? 250 : 340, height: compact ? 300 : 540)
        .background(theme.windowBg)
        .foregroundColor(theme.text)
        .animation(.easeOut(duration: 0.15), value: vm.isEditing)
        // The window uses fullSizeContentView: draw under the (transparent) title bar
        // instead of letting SwiftUI inset the content below it.
        .ignoresSafeArea()
    }

    // MARK: - Title row

    private var titleRow: some View {
        ZStack {
            // Centered name with the active-phase dot; nothing in compact mode.
            if !compact {
                HStack(spacing: 8) {
                    Circle().fill(theme.accent(for: vm.snap.activePhase)).frame(width: 10, height: 10)
                    Text("Pomodoro")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textMuted)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                TitleIconButton(symbol: vm.isTopmost ? "pin.fill" : "pin", tint: vm.isTopmost ? theme.accent : nil,
                                help: L.get("Tip_Pin"), action: vm.toggleTopmost)
                TitleIconButton(symbol: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                                help: L.get(compact ? "Tip_Normal" : "Tip_Compact"), action: vm.toggleCompact)
                TitleIconButton(symbol: "gearshape", help: L.get("Tip_Settings"), action: vm.openSettings)
            }
            .padding(.trailing, 8)
        }
        .frame(height: 44)
    }

    // MARK: - Ring

    private var ring: some View {
        let size: CGFloat = compact ? 156 : 236
        let stroke: CGFloat = compact ? 7 : 10
        return ZStack {
            ProgressRing(value: vm.snap.progress, lineWidth: stroke, track: theme.track, progress: theme.accent)
            if vm.isEditing {
                editor
            } else {
                VStack(spacing: 2) {
                    Text(vm.snap.timeText)
                        .font(.system(size: compact ? 38 : 58, weight: .light).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !compact {
                        Text(vm.snap.statusText)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textMuted)
                        if !vm.snap.activeInfo.isEmpty {
                            LinkButton(color: theme.accent(for: vm.snap.activePhase), action: vm.goToActive) {
                                Text(vm.snap.activeInfo)
                            }
                            .padding(.top, 2)
                        }
                        if vm.canEdit {
                            LinkButton(help: L.get("Edit_Tip"), action: vm.beginEdit) {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                                    Text(L.get("Edit"))
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, stroke + 12)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - In-place duration editor (SPEC §6.5)

    private var editor: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                StepButton(symbol: "minus", help: "−5") { vm.editStep(-MainViewModel.editStep) }
                TextField("", text: $vm.editText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 34, weight: .light).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(width: 92)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(theme.controlBg))
                    .focused($editFocused)
                    .onChange(of: vm.editText) { text in
                        let digits = String(text.filter(\.isNumber).prefix(3))
                        if digits != text { vm.editText = digits }
                    }
                    .onSubmit { vm.commitEdit() }
                    .onExitCommand { vm.cancelEdit() }
                StepButton(symbol: "plus", help: "+5") { vm.editStep(MainViewModel.editStep) }
            }
            Text(L.get("Min"))
                .font(.system(size: 13))
                .foregroundColor(theme.textMuted)
            HStack(spacing: 10) {
                SmallRoundButton(symbol: "checkmark", filled: true, help: L.get("Save"), action: vm.commitEdit)
                SmallRoundButton(symbol: "xmark", help: L.get("Cancel"), action: vm.cancelEdit)
            }
            .padding(.top, 10)
        }
        .onAppear {
            DispatchQueue.main.async {
                editFocused = true
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        }
    }

    // MARK: - Controls row

    private var controls: some View {
        HStack(spacing: 14) {
            RoundIconButton(symbol: "arrow.counterclockwise", size: compact ? 40 : 48, enabled: vm.canReset,
                            help: L.get("Tip_Reset"), action: vm.reset)
            PillButton(symbol: vm.snap.primaryIcon, title: vm.snap.primaryText,
                       minWidth: compact ? 110 : 150, height: compact ? 40 : 48, action: vm.togglePrimary)
            RoundIconButton(symbol: "forward.end.fill", size: compact ? 40 : 48, enabled: vm.canSkip,
                            help: L.get("Tip_Skip"), action: vm.skip)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            CycleDots(dots: vm.snap.dots)
            HStack(spacing: 4) {
                StepButton(symbol: "chevron.left") { vm.changeLoops(-1) }
                Text(vm.snap.loopsText)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 130)
                StepButton(symbol: "chevron.right") { vm.changeLoops(+1) }
            }
            .help(L.get("Loops_Tip"))
            .padding(.top, 12)
            Text(vm.snap.sessionLabel)
                .font(.system(size: 12))
                .foregroundColor(theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
        }
        .padding(.top, 4)
        .padding(.bottom, 22)
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PomodoroCore

/// Settings window content (SPEC §8): title row, nav column + card, footer.
struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel
    @EnvironmentObject var theme: Theme
    var onCancel: () -> Void
    var onSave: () -> Void

    private var L: Localizer { vm.L }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(SettingsPage.allCases, id: \.self) { page in
                        NavItem(title: L.get(page.titleKey), isSelected: vm.page == page) { vm.page = page }
                    }
                    Spacer()
                }
                .frame(width: 150)
                .padding(.top, 4)

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        switch vm.page {
                        case .timer: timerPage
                        case .sound: soundPage
                        case .look: lookPage
                        case .system: systemPage
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(theme.surface))
            }
            .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Spacer()
                SecondaryPill(title: L.get("Cancel"), action: onCancel)
                PillButton(symbol: "", title: L.get("Save"), minWidth: 130, height: 40, action: onSave)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
        }
        .frame(width: 600, height: 680)
        .background(theme.windowBg)
        .foregroundColor(theme.text)
        .ignoresSafeArea()
    }

    private var titleRow: some View {
        HStack {
            Spacer().frame(width: 62)
            Text(L.get("Settings_Title"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textMuted)
            Spacer()
        }
        .padding(.leading, 18)
        .frame(height: 44)
    }

    // MARK: - Timer

    private var timerPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: L.get("Nav_Timer"))
            SliderRow(label: L.get("Label_Work"), valueText: "\(vm.draft.workMinutes) \(L.get("Min"))",
                      value: $vm.draft.workMinutes, range: 1...90)
            SliderRow(label: L.get("Label_Short"), valueText: "\(vm.draft.shortBreakMinutes) \(L.get("Min"))",
                      value: $vm.draft.shortBreakMinutes, range: 1...30)
            SliderRow(label: L.get("Label_Long"), valueText: "\(vm.draft.longBreakMinutes) \(L.get("Min"))",
                      value: $vm.draft.longBreakMinutes, range: 5...60)
            SliderRow(label: L.get("Label_Cycles"), valueText: "\(vm.draft.cyclesBeforeLongBreak)",
                      value: $vm.draft.cyclesBeforeLongBreak, range: 2...8, bottom: 16)

            SwitchRow(label: L.get("AutoBreaks"), isOn: $vm.draft.autoStartBreaks)
            SwitchRow(label: L.get("AutoWork"), isOn: $vm.draft.autoStartWork)
                .padding(.bottom, 4)

            SwitchRow(label: L.get("LimitSessions"), isOn: $vm.draft.limitSessions)
            if vm.draft.limitSessions {
                SliderRow(label: L.get("TotalSessions"), valueText: "\(vm.draft.totalSessions)",
                          value: $vm.draft.totalSessions, range: 1...16, bottom: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.planEndText).font(.system(size: 15, weight: .semibold)).foregroundColor(theme.text)
                    HintText(text: vm.planDurationText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(theme.controlBg))
            }
        }
    }

    // MARK: - Sound

    private var soundPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: L.get("Nav_Sound"))
            SwitchRow(label: L.get("SoundEnabled"), isOn: $vm.draft.soundEnabled)
                .padding(.bottom, 6)

            soundRow(label: L.get("WorkEndSound"), selection: $vm.draft.workEndSound)
                .padding(.bottom, 14)
            soundRow(label: L.get("BreakEndSound"), selection: $vm.draft.breakEndSound)
                .padding(.bottom, 22)

            VStack(spacing: 4) {
                HStack {
                    Text(L.get("Volume")).font(.system(size: 13))
                    Spacer()
                    Text("\(Int((vm.draft.volume * 100).rounded())) %")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(theme.accent)
                }
                AccentSlider(value: $vm.draft.volume, range: 0...1, step: 0.05)
            }
            .padding(.bottom, 10)
            HintText(text: L.get("Sound_Hint"))
        }
    }

    private func soundRow(label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13))
            HStack(spacing: 6) {
                Picker("", selection: selection) {
                    ForEach(vm.sounds) { option in
                        Text(option.name(L)).tag(option.file)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                SmallRoundButton(symbol: "play.fill", help: L.get("Tip_Preview")) { vm.preview(selection.wrappedValue) }
                    .padding(.leading, 2)
                SmallRoundButton(symbol: "folder", help: L.get("Tip_Browse")) {
                    if let path = pickSoundFile() {
                        selection.wrappedValue = vm.addCustomSound(path).file
                    }
                }
            }
        }
    }

    private func pickSoundFile() -> String? {
        let panel = NSOpenPanel()
        panel.title = L.get("Dialog_PickSound")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.wav, .mp3]
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    // MARK: - Appearance

    private var lookPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: L.get("Nav_Look"))

            Text(L.get("Theme")).font(.system(size: 13)).padding(.bottom, 8)
            SegmentedChoice(
                options: [("System", L.get("Theme_System")), ("Dark", L.get("Theme_Dark")), ("Light", L.get("Theme_Light"))],
                selected: vm.draft.theme, onSelect: vm.setTheme)
            .padding(.bottom, 22)

            Text(L.get("Accent")).font(.system(size: 13)).padding(.bottom, 8)
            AccentPicker(
                options: AccentMath.palette.map { AccentPicker.Option(key: $0, hex: $0) },
                selected: vm.draft.accent, onSelect: vm.setAccent)
            .padding(.bottom, 16)

            Text(L.get("Accent_Break")).font(.system(size: 13)).padding(.bottom, 8)
            AccentPicker(
                options: [AccentPicker.Option(key: "auto", hex: vm.autoBreakHex, label: "A", help: L.get("Accent_Auto"))]
                    + AccentMath.palette.map { AccentPicker.Option(key: $0, hex: $0) },
                selected: vm.breakAccentKey, onSelect: vm.setBreakAccent)
            .padding(.bottom, 22)

            Text(L.get("Language")).font(.system(size: 13)).padding(.bottom, 8)
            SegmentedChoice(
                options: [("en", "English"), ("uk", "Українська"), ("ru", "Русский")],
                selected: vm.language, onSelect: vm.setLanguage)
            .padding(.bottom, 16)

            HintText(text: L.get("Look_Hint"))
        }
    }

    // MARK: - System

    private var systemPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: L.get("Nav_System"))
            SwitchRow(label: L.get("Notifications"), isOn: $vm.draft.notificationsEnabled)
            SwitchRow(label: L.get("ShowOnPhaseEnd"), isOn: $vm.draft.showOnPhaseEnd)
            SwitchRow(label: L.get("AlwaysOnTop"), isOn: $vm.draft.alwaysOnTop)
            SwitchRow(label: L.get("MinimizeToTray"), isOn: $vm.draft.minimizeToTray)
            SwitchRow(label: L.get("CloseToTray"), isOn: $vm.draft.closeToTray)
            SwitchRow(label: L.get("StartWithWindows"), isOn: $vm.draft.startWithWindows)
            if let hint = vm.loginApprovalHint {
                HintText(text: hint).padding(.bottom, 6)
            }
            HintText(text: L.get("System_Hint")).padding(.top, 6)
        }
    }
}

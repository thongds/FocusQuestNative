import SwiftUI

struct SettingsView: View {
    @Bindable var store: TaskStore
    @State private var draft: AppSettings
    @State private var saved = false

    init(store: TaskStore) {
        self.store = store
        _draft = State(initialValue: store.settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back
            Button("← BACK TO MISSIONS") {
                store.showSettings = false
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Theme.textFaint)
            .tracking(1)
            .buttonStyle(.plain)
            .padding(.bottom, 20)

            badgeView("CONFIGURATION MODE", color: Theme.cyan)
            Text("Pomodoro Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)
            Text("Tune your focus rounds and break intervals.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .padding(.bottom, 24)

            // Presets
            section("QUICK PRESETS") {
                HStack(spacing: 8) {
                    presetBtn("CLASSIC", focus: 25, short: 5, long: 15)
                    presetBtn("DEEP",    focus: 50, short: 10, long: 30)
                    presetBtn("SPRINT",  focus: 15, short: 3,  long: 10)
                }
            }

            // Focus
            section("FOCUS SESSION") {
                stepField("Focus Duration", unit: "min", value: $draft.focusMinutes, range: 1...120)
            }

            // Breaks
            section("BREAKS") {
                VStack(spacing: 12) {
                    stepField("Short Break",       unit: "min", value: $draft.shortBreak,        range: 1...60)
                    Divider().overlay(Theme.borderDim)
                    stepField("Long Break",        unit: "min", value: $draft.longBreak,         range: 1...60)
                    Divider().overlay(Theme.borderDim)
                    stepField("Long Break After",  unit: "rounds", value: $draft.longBreakInterval, range: 1...10)
                }
            }

            // Sound
            section("SOUND") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound Effects")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text("Play audio when a task starts and when a pomodoro finishes.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                    }
                    Spacer()
                    Toggle("", isOn: $draft.soundEnabled)
                        .toggleStyle(.switch)
                        .tint(Theme.cyan)
                        .labelsHidden()
                }
            }

            // Preview
            section("SESSION PREVIEW") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0..<draft.longBreakInterval, id: \.self) { i in
                            HStack(spacing: 4) {
                                previewChip("🎯 \(draft.focusMinutes)m", color: Theme.green)
                                if i < draft.longBreakInterval - 1 {
                                    previewChip("☕ \(draft.shortBreak)m", color: Theme.border)
                                } else {
                                    previewChip("🛋 \(draft.longBreak)m", color: Theme.cyan)
                                }
                            }
                        }
                    }
                }
            }

            // Save
            HStack {
                if saved {
                    Text("// SETTINGS SAVED")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.green)
                }
                Spacer()
                Button("Save Config") {
                    store.settings = draft
                    store.save()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Theme.green)
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        .padding(20)
    }

    // ── Helpers ──────────────────────────────────────────────────
    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(3)
            content()
        }
        .padding(16)
        .background(Theme.card)
        .questBorder()
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func stepField(_ label: String, unit: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) } label: {
                    Text("−").frame(width: 28, height: 28)
                        .background(Theme.bg).questBorder(Theme.border, width: 1.5)
                        .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text("\(value.wrappedValue)")
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(minWidth: 40, alignment: .center)
                    Text(unit)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                }

                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) } label: {
                    Text("+").frame(width: 28, height: 28)
                        .background(Theme.bg).questBorder(Theme.border, width: 1.5)
                        .foregroundStyle(Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func presetBtn(_ name: String, focus: Int, short: Int, long: Int) -> some View {
        let isActive = draft.focusMinutes == focus && draft.shortBreak == short && draft.longBreak == long
        return Button {
            draft.focusMinutes = focus
            draft.shortBreak = short
            draft.longBreak = long
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isActive ? Theme.cyan : Theme.text)
                    .tracking(2)
                Text("\(focus)m focus")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(isActive ? Theme.cyanBg : Theme.bg)
            .questBorder(isActive ? Theme.cyan : Theme.border, width: 1.5)
        }
        .buttonStyle(.plain)
    }

    private func previewChip(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.08))
            .questBorder(color, width: 1)
    }

    @ViewBuilder
    private func badgeView(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(color)
            .tracking(2)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .questBorder(color)
            .padding(.bottom, 16)
    }
}

import SwiftUI

struct SettingsView: View {
    @Bindable var store: TaskStore
    @State private var draft: AppSettings
    @State private var newBlockedURL: String = ""
    @State private var accessibilityGranted: Bool = DistractionMonitor.hasPermission

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

            // Blocked Sites
            section("BLOCKED SITES") {
                VStack(alignment: .leading, spacing: 10) {

                    // Permission row
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accessibilityGranted ? Theme.green : Theme.red)
                            .frame(width: 7, height: 7)
                        Text(accessibilityGranted ? "Accessibility permission granted" : "Accessibility permission required")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(accessibilityGranted ? Theme.green : Theme.textFaint)
                        Spacer()
                        if !accessibilityGranted {
                            Button("GRANT ACCESS") {
                                DistractionMonitor.requestPermission()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    accessibilityGranted = DistractionMonitor.hasPermission
                                    store.refreshDistractionMonitor()
                                }
                            }
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.cyan)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .questBorder(Theme.cyan, width: 1)
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)

                    Text("During a focus session, opening these sites will auto-pause your timer and show a warning in widget mode.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .fixedSize(horizontal: false, vertical: true)

                    // Add URL row
                    HStack(spacing: 8) {
                        TextField("e.g. facebook.com", text: $newBlockedURL)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.text)
                            .padding(8)
                            .background(Theme.bg)
                            .questBorder(Theme.border, width: 1)
                            .onSubmit { addBlockedURL() }

                        Button("ADD") { addBlockedURL() }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(newBlockedURL.isEmpty ? Theme.textFaint : Theme.bg)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(newBlockedURL.isEmpty ? Theme.card : Theme.cyan)
                            .questBorder(newBlockedURL.isEmpty ? Theme.border : Theme.cyan, width: 1)
                            .buttonStyle(.plain)
                            .disabled(newBlockedURL.isEmpty)
                    }

                    // Blocked URL list
                    if draft.blockedURLs.isEmpty {
                        Text("No blocked sites yet.")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.textFaint.opacity(0.5))
                            .padding(.top, 2)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(draft.blockedURLs, id: \.self) { url in
                                HStack {
                                    Image(systemName: "xmark.shield.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.red)
                                    Text(url)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Theme.textDim)
                                    Spacer()
                                    Button {
                                        draft.blockedURLs.removeAll { $0 == url }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.textFaint)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Theme.bg)
                                .questBorder(Theme.border, width: 1)
                            }
                        }
                    }
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
        }
        .padding(20)
        .onChange(of: draft) { _, newValue in
            guard newValue != store.settings else { return }
            store.applySettings(newValue)
        }
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

    private func addBlockedURL() {
        var trimmed = newBlockedURL.trimmingCharacters(in: .whitespaces).lowercased()
        for prefix in ["https://", "http://", "www."] {
            if trimmed.hasPrefix(prefix) { trimmed = String(trimmed.dropFirst(prefix.count)) }
        }
        // Strip trailing slashes and whitespace
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespaces))
        guard !trimmed.isEmpty, !draft.blockedURLs.contains(trimmed) else {
            newBlockedURL = ""
            return
        }
        draft.blockedURLs.append(trimmed)
        newBlockedURL = ""
    }

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

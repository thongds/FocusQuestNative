import SwiftUI

struct ArrangeView: View {
    @Bindable var store: TaskStore

    @State private var startTime: Date = Calendar.current.date(
        bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime: Date = Calendar.current.date(
        bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var lastApplied: String? = nil

    // ── Computed ─────────────────────────────────────────────────
    private var windowMinutes: Int {
        let minutes = Int(endTime.timeIntervalSince(startTime) / 60)
        return minutes > 0 ? minutes : minutes + 24 * 60   // handle overnight
    }

    private var totalFocusSeconds: Int {
        computeFocusSeconds(windowMinutes: windowMinutes, settings: store.settings)
    }

    private var missionCount: Int {
        store.tasks.filter { $0.status != .completed }.count
    }

    private var perTaskSeconds: Int {
        guard missionCount > 0 else { return 0 }
        return totalFocusSeconds / missionCount
    }

    private var canArrange: Bool {
        missionCount > 0 && totalFocusSeconds > 0 && windowMinutes > 0
    }

    // ── Body ─────────────────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)

            // Time pickers
            HStack(spacing: 12) {
                timeField(label: "START", time: $startTime)
                timeField(label: "END",   time: $endTime)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Preview row
            VStack(alignment: .leading, spacing: 6) {
                Text("PREVIEW")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                    .tracking(2)

                previewRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Footer
            HStack(spacing: 10) {
                if let msg = lastApplied {
                    Text(msg)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.green)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Arrange Targets") { applyArrangement() }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canArrange ? Theme.bg : Theme.textFaint)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(canArrange ? Theme.cyan : Theme.card)
                    .questBorder(canArrange ? Theme.cyan : Theme.border, width: 1)
                    .buttonStyle(.plain)
                    .disabled(!canArrange)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Theme.card)
        .questBorder()
    }

    // ── Header ────────────────────────────────────────────────────
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("ARRANGE MISSIONS")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.cyan)
                    .tracking(3)

                if store.arrangement != nil {
                    Text("● ACTIVE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.green)
                        .tracking(1)
                }

                Spacer()

                if store.arrangement != nil {
                    Button("CLEAR") {
                        store.clearArrangement()
                        lastApplied = nil
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.red)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .questBorder(Theme.red, width: 1)
                    .buttonStyle(.plain)
                }
            }

            Text("Equalize Targets By Study Window")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            Text("Set your learning range and the app will split the usable Pomodoro focus time equally across your current missions.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ── Time field ────────────────────────────────────────────────
    private func timeField(label: String, time: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(2)

            DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
        .questBorder(Theme.border, width: 1)
    }

    // ── Preview row ───────────────────────────────────────────────
    @ViewBuilder
    private var previewRow: some View {
        Group {
            if windowMinutes <= 0 {
                Text("End time must be after start time.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.red)
            } else if missionCount == 0 {
                Text("No non-completed missions to arrange.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            } else {
                (
                    Text(TimeHelpers.formatDuration(totalFocusSeconds))
                        .foregroundStyle(Theme.text)
                    + Text(" usable focus time")
                        .foregroundStyle(Theme.textFaint)
                    + Text("  ·  \(missionCount) mission\(missionCount == 1 ? "" : "s")")
                        .foregroundStyle(Theme.textFaint)
                    + Text("  ·  ")
                        .foregroundStyle(Theme.border)
                    + Text(TimeHelpers.formatDuration(perTaskSeconds))
                        .foregroundStyle(Theme.cyan)
                    + Text(" each")
                        .foregroundStyle(Theme.textFaint)
                )
                .font(.system(size: 12, design: .monospaced))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
        .questBorder(Theme.border, width: 1)
    }

    // ── Actions ───────────────────────────────────────────────────
    private func applyArrangement() {
        guard canArrange else { return }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        let plan = ArrangementPlan(
            startTime: fmt.string(from: startTime),
            endTime:   fmt.string(from: endTime),
            totalFocusSeconds: totalFocusSeconds,
            perTaskSeconds:    perTaskSeconds
        )
        store.applyArrangement(plan)
        lastApplied = "Updated \(missionCount) mission\(missionCount == 1 ? "" : "s") to \(TimeHelpers.formatDuration(perTaskSeconds)) each from \(TimeHelpers.formatDuration(totalFocusSeconds)) total focus time."
    }

    // ── Pomodoro-aware focus time calculation ─────────────────────
    private func computeFocusSeconds(windowMinutes: Int, settings: AppSettings) -> Int {
        guard windowMinutes > 0 else { return 0 }

        // Time in one full pomodoro cycle
        let focusPerCycle     = settings.longBreakInterval * settings.focusMinutes
        let shortBreaksPerCycle = settings.longBreakInterval - 1
        let breakPerCycle     = shortBreaksPerCycle * settings.shortBreak + settings.longBreak
        let minutesPerCycle   = focusPerCycle + breakPerCycle

        var remaining       = windowMinutes
        var totalFocusMin   = 0

        // Whole cycles
        let fullCycles       = remaining / minutesPerCycle
        totalFocusMin       += fullCycles * focusPerCycle
        remaining           -= fullCycles * minutesPerCycle

        // Partial cycle: greedily fit individual focus sessions
        var sessionsThisCycle = 0
        while sessionsThisCycle < settings.longBreakInterval {
            guard remaining >= settings.focusMinutes else { break }
            totalFocusMin += settings.focusMinutes
            remaining     -= settings.focusMinutes
            sessionsThisCycle += 1

            // Short break after each session except the last
            if sessionsThisCycle < settings.longBreakInterval {
                guard remaining >= settings.shortBreak else { break }
                remaining -= settings.shortBreak
            }
        }

        return totalFocusMin * 60
    }
}

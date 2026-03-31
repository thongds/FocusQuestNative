import SwiftUI

struct ArrangeView: View {
    @Bindable var store: TaskStore

    @State private var lastApplied: String? = nil
    @State private var isExpanded: Bool = true

    // ── Computed ─────────────────────────────────────────────────
    private var totalWindowMinutes: Int {
        store.studyWindowRanges.reduce(0) { total, range in
            total + minutesBetween(range.startTime, range.endTime)
        }
    }

    private var totalFocusSeconds: Int {
        store.studyWindowRanges.reduce(0) { total, range in
            total + computeFocusSeconds(
                windowMinutes: minutesBetween(range.startTime, range.endTime),
                settings: store.settings
            )
        }
    }

    private var missionCount: Int {
        store.tasks.filter { $0.status != .completed }.count
    }

    private var allocatedTaskSeconds: Int {
        store.tasks
            .filter { $0.status != .completed }
            .reduce(0) { $0 + ($1.targetSeconds ?? 0) }
    }

    private var perTaskSeconds: Int {
        guard missionCount > 0 else { return 0 }
        return totalFocusSeconds / missionCount
    }

    private var budgetRemainingSeconds: Int {
        totalFocusSeconds - allocatedTaskSeconds
    }

    private var canArrange: Bool {
        missionCount > 0 && totalFocusSeconds > 0 && totalWindowMinutes > 0
    }

    // ── Body ─────────────────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clickable header (always visible)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, isExpanded ? 14 : 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Time ranges
                VStack(spacing: 10) {
                    ForEach($store.studyWindowRanges) { $range in
                        HStack(spacing: 12) {
                            timeField(label: "START", time: $range.startTime)
                            timeField(label: "END",   time: $range.endTime)

                            if store.studyWindowRanges.count > 1 {
                                Button {
                                    removeRange(range.id)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Theme.red)
                                        .frame(width: 28, height: 28)
                                        .background(Theme.bg)
                                        .questBorder(Theme.red, width: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        Button {
                            addRange()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                Text("ADD RANGE")
                                    .font(.system(size: 9, design: .monospaced))
                                    .tracking(1)
                            }
                            .foregroundStyle(Theme.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.bg)
                            .questBorder(Theme.cyan, width: 1)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))

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
                .transition(.opacity.combined(with: .move(edge: .top)))

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.card)
        .questBorder()
        .clipped()
        .onChange(of: store.studyWindowRanges) { _, _ in
            store.save()
        }
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

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: 24, height: 24)
            }

            Text("Equalize Targets By Study Window")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)

            if isExpanded {
                Text("Set your learning range and the app will split the usable Pomodoro focus time equally across your current missions.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            if totalWindowMinutes <= 0 {
                Text("Add at least one non-zero study range.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.red)
            } else if missionCount == 0 {
                Text("No non-completed missions to arrange.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    (
                        Text(TimeHelpers.formatDuration(totalFocusSeconds))
                            .foregroundStyle(Theme.text)
                        + Text(" usable focus time")
                            .foregroundStyle(Theme.textFaint)
                        + Text("  ·  \(store.studyWindowRanges.count) range\(store.studyWindowRanges.count == 1 ? "" : "s")")
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

                    if budgetRemainingSeconds >= 0 {
                        (
                            Text(TimeHelpers.formatDuration(budgetRemainingSeconds))
                                .foregroundStyle(Theme.green)
                            + Text(" time budget remaining")
                                .foregroundStyle(Theme.textFaint)
                        )
                        .font(.system(size: 11, design: .monospaced))
                    } else {
                        (
                            Text(TimeHelpers.formatDuration(-budgetRemainingSeconds))
                                .foregroundStyle(Theme.red)
                            + Text(" over budget")
                                .foregroundStyle(Theme.textFaint)
                        )
                        .font(.system(size: 11, design: .monospaced))
                    }
                }
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

        let firstRange = store.studyWindowRanges.first ?? .defaultStudyWindow
        let lastRange = store.studyWindowRanges.last ?? firstRange

        let plan = ArrangementPlan(
            startTime: fmt.string(from: firstRange.startTime),
            endTime:   fmt.string(from: lastRange.endTime),
            totalFocusSeconds: totalFocusSeconds,
            perTaskSeconds:    perTaskSeconds
        )
        store.applyArrangement(plan)
        lastApplied = "Updated \(missionCount) mission\(missionCount == 1 ? "" : "s") to \(TimeHelpers.formatDuration(perTaskSeconds)) each from \(TimeHelpers.formatDuration(totalFocusSeconds)) total focus time across \(store.studyWindowRanges.count) range\(store.studyWindowRanges.count == 1 ? "" : "s")."
        store.save()
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

    private func minutesBetween(_ start: Date, _ end: Date) -> Int {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return minutes > 0 ? minutes : minutes + 24 * 60
    }

    private func addRange() {
        let base = store.studyWindowRanges.last ?? .defaultStudyWindow
        let calendar = Calendar.current
        let nextStart = calendar.date(byAdding: .minute, value: 30, to: base.endTime) ?? base.endTime
        let nextEnd = calendar.date(byAdding: .hour, value: 2, to: nextStart) ?? nextStart
        store.studyWindowRanges.append(TimeRangeInput(startTime: nextStart, endTime: nextEnd))
        store.save()
    }

    private func removeRange(_ id: UUID) {
        store.studyWindowRanges.removeAll { $0.id == id }
        store.save()
    }
}

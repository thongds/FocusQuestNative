import SwiftUI

struct MissionCardView: View {
    @Bindable var store: TaskStore
    let task: FocusTask
    let index: Int

    @State private var isEditingTarget = false
    @State private var targetInput = ""
    @State private var targetError = ""

    private var statusLabel: String {
        switch task.status {
        case .pending:   return "PENDING"
        case .active:    return task.pomodoroRunning ? "MIDWAY CHECKPOINT" : "PAUSED"
        case .completed: return "COMPLETED"
        }
    }

    private var borderColor: Color {
        switch task.status {
        case .completed: return Theme.green
        case .active:    return Theme.cyan
        case .pending:   return Theme.border
        }
    }

    private var cardBg: Color {
        switch task.status {
        case .completed: return Theme.greenBg
        default:         return Theme.card
        }
    }

    // Max allowed seconds within arrangement
    private var maxAllowedSeconds: Int? {
        guard store.arrangement != nil else { return nil }
        let free = store.freeTimeRemaining ?? 0
        return free + (task.targetSeconds ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(Theme.textFaint)
                    .font(.system(size: 12))

                Text("MISSION \(String(format: "%02d", index + 1))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.textFaint)
                    .tracking(1)

                Text("|").foregroundStyle(Theme.border)

                Text(statusLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(statusLabelColor)
                    .tracking(2)

                Spacer()

                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Title ─────────────────────────────────────────────
            Text(task.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            // ── Timer row ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Meta row
                        HStack(spacing: 4) {
                            Text("Target: ")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                            Text(task.formattedTarget)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textDim)
                            Text("  |  ")
                                .foregroundStyle(Theme.border)
                            Text("Elapsed: ")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                            Text(task.formattedElapsed)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textDim)

                            Spacer()

                            if task.status != .completed {
                                Button("EDIT TARGET") {
                                    targetInput = task.targetSeconds.map { TimeHelpers.secondsToHoursString($0) } ?? ""
                                    targetError = ""
                                    isEditingTarget.toggle()
                                }
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.border.opacity(0.6), lineWidth: 1))
                                .buttonStyle(.plain)
                            }
                        }

                        // Edit target inline
                        if isEditingTarget {
                            editTargetRow
                        }

                        // Arrangement free time
                        if store.arrangement != nil, task.status != .completed, !isEditingTarget {
                            HStack(spacing: 4) {
                                Text("Free time remain:")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Theme.textFaint)
                                Text(store.freeTimeRemaining.map { TimeHelpers.formatDuration($0) } ?? "--")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Theme.green)
                            }
                            .padding(.top, 2)
                        }

                        // Progress bar
                        if task.targetSeconds != nil {
                            progressBar
                        }

                        // Pomodoro countdown (active only)
                        if task.status == .active {
                            pomodoroDisplay
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .background(Theme.bg)
            .questBorder(task.status == .active ? Theme.cyanBg : Theme.border, width: 1)
            .padding(.horizontal, 16)

            // ── Bottom row ────────────────────────────────────────
            HStack {
                if task.status == .completed {
                    Text("ITEM DONE")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.green)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.green, lineWidth: 1))
                }
                Spacer()
                Button("REMOVE") {
                    store.deleteTask(task.id)
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.border.opacity(0.5), lineWidth: 1))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(cardBg)
        .questBorder(borderColor)
    }

    // ── Sub-views ────────────────────────────────────────────────
    @ViewBuilder
    private var actionButton: some View {
        switch task.status {
        case .completed:
            Image(systemName: "checkmark")
                .frame(width: 30, height: 30)
                .background(Theme.green)
                .foregroundStyle(Theme.bg)
                .clipShape(Circle())
        case .active:
            Button {
                store.togglePause(task.id)
            } label: {
                Image(systemName: task.pomodoroRunning ? "pause.fill" : "play.fill")
                    .frame(width: 30, height: 30)
                    .background(Theme.cyan)
                    .foregroundStyle(Theme.bg)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        case .pending:
            Button {
                store.startTask(task.id)
            } label: {
                Image(systemName: "play.fill")
                    .frame(width: 30, height: 30)
                    .background(Theme.border)
                    .foregroundStyle(Theme.text)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var statusLabelColor: Color {
        switch task.status {
        case .completed: return Theme.green
        case .active:    return Theme.cyan
        case .pending:   return Theme.textFaint
        }
    }

    @ViewBuilder
    private var editTargetRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Hours e.g. 1.5", text: $targetInput)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .frame(width: 120)
                    .padding(6)
                    .background(Theme.bg)
                    .overlay(RoundedRectangle(cornerRadius: 0)
                        .stroke(targetError.isEmpty ? Theme.border : Theme.red, lineWidth: 1))
                    .onSubmit { saveTarget() }

                if let max = maxAllowedSeconds {
                    Text("max \(TimeHelpers.formatDuration(max))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                }

                Button("SAVE")  { saveTarget() }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.green, lineWidth: 1))
                    .buttonStyle(.plain)

                Button("CANCEL") {
                    isEditingTarget = false
                    targetError = ""
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textDim)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(Theme.border, lineWidth: 1))
                .buttonStyle(.plain)
            }

            if !targetError.isEmpty {
                Text(targetError)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.red)
            }
        }
        .padding(.top, 6)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.card).frame(height: 6)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.cyan, Theme.green],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * task.progress, height: 6)
                }
            }
            .frame(height: 6)
            .questBorder(Theme.border, width: 1)

            Text("\(Int(task.progress * 100))% complete")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(1)
        }
        .padding(.top, 8)
    }

    private var pomodoroDisplay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task.formattedPomodoroLeft)
                .font(.system(size: 40, design: .monospaced))
                .foregroundStyle(task.phase == .focus ? Theme.cyan : Theme.orange)
                .padding(.top, 8)

            Text(phaseLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.textFaint)
                .tracking(2)
        }
    }

    private var phaseLabel: String {
        switch task.phase {
        case .focus:      return task.pomodoroRunning ? "COUNTDOWN" : "PAUSED"
        case .shortBreak: return "☕ SHORT BREAK"
        case .longBreak:  return "🛋 LONG BREAK"
        }
    }

    private func saveTarget() {
        let trimmed = targetInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if let err = store.updateTarget(id: task.id, seconds: nil) {
                targetError = err; return
            }
            isEditingTarget = false; return
        }
        guard let hours = Double(trimmed), hours > 0, hours <= 24 else {
            targetError = "Enter a number like 1 or 1.5"; return
        }
        let seconds = TimeHelpers.hoursToSeconds(hours)
        if let err = store.updateTarget(id: task.id, seconds: seconds) {
            targetError = err; return
        }
        isEditingTarget = false
        targetError = ""
    }
}

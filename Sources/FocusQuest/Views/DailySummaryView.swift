import SwiftUI

struct DailySummaryView: View {
    @Bindable var store: TaskStore
    @State private var showBreakdown = false

    private var completedCount: Int { store.tasks.filter { $0.status == .completed }.count }
    private var totalCount: Int     { store.tasks.count }

    private var hours: Int   { store.todayFocusSeconds / 3600 }
    private var minutes: Int { (store.todayFocusSeconds % 3600) / 60 }
    private var secs: Int    { store.todayFocusSeconds % 60 }

    private var focusLabel: String {
        if hours > 0    { return "\(hours)h \(minutes)m" }
        if minutes > 0  { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }

    private var hasProgress: Bool { store.todayFocusSeconds > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // ── Stats row ─────────────────────────────────────────
            HStack(spacing: 0) {
                // Focus time
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S FOCUS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(2)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(hasProgress ? focusLabel : "--")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(hasProgress ? Theme.cyan : Theme.textFaint)
                        if hasProgress {
                            Text("focused")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                }
                .padding(.vertical, 14)
                .padding(.leading, 16)

                Spacer()

                divider

                // Missions done
                VStack(alignment: .center, spacing: 4) {
                    Text("MISSIONS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(2)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(completedCount)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(completedCount > 0 ? Theme.green : Theme.textFaint)
                        Text("/ \(totalCount)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .frame(width: 110)
                .padding(.vertical, 14)

                divider

                // Status
                VStack(alignment: .center, spacing: 4) {
                    Text("STATUS")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(2)
                    Text(statusEmoji)
                        .font(.system(size: 22))
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(statusColor)
                        .tracking(1)
                }
                .frame(width: 100)
                .padding(.vertical, 14)

                divider

                // Breakdown toggle
                if !store.tasks.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showBreakdown.toggle() }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: showBreakdown ? "chevron.up" : "list.bullet")
                                .font(.system(size: 12))
                                .foregroundStyle(showBreakdown ? Theme.cyan : Theme.textFaint)
                            Text(showBreakdown ? "HIDE" : "TASKS")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(showBreakdown ? Theme.cyan : Theme.textFaint)
                                .tracking(1)
                        }
                        .frame(width: 60)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Task breakdown ────────────────────────────────────
            if showBreakdown && !store.tasks.isEmpty {
                Rectangle()
                    .fill(Theme.border.opacity(0.4))
                    .frame(height: 1)
                    .padding(.horizontal, 16)

                VStack(spacing: 0) {
                    ForEach(Array(store.tasks.enumerated()), id: \.element.id) { idx, task in
                        taskRow(task: task, index: idx)

                        if idx < store.tasks.count - 1 {
                            Rectangle()
                                .fill(Theme.border.opacity(0.25))
                                .frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.card)
        .questBorder()
        .clipped()
    }

    // ── Task row ──────────────────────────────────────────────────
    private func taskRow(task: FocusTask, index: Int) -> some View {
        HStack(spacing: 10) {
            // Status icon
            ZStack {
                Circle()
                    .fill(iconBg(task))
                    .frame(width: 24, height: 24)
                Image(systemName: iconName(task))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(iconFg(task))
            }

            // Title + meta
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(task.status == .completed ? Theme.textFaint : Theme.text)
                    .strikethrough(task.status == .completed, color: Theme.textFaint)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("MISSION \(String(format: "%02d", index + 1))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(1)

                    if task.elapsed > 0 {
                        Text("·")
                            .foregroundStyle(Theme.border)
                        Text(TimeHelpers.formatDuration(task.elapsed) + " elapsed")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                    }

                    if let target = task.targetSeconds {
                        Text("·")
                            .foregroundStyle(Theme.border)
                        Text("target \(TimeHelpers.formatDuration(target))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textFaint)
                    }
                }
                .font(.system(size: 9, design: .monospaced))
            }

            Spacer()

            // Status badge
            Text(badgeLabel(task))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(badgeColor(task))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(badgeColor(task).opacity(0.5), lineWidth: 1)
                )

            // Progress bar (if has target)
            if task.targetSeconds != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.bg).frame(height: 4)
                        Rectangle()
                            .fill(task.status == .completed ? Theme.green : Theme.cyan)
                            .frame(width: geo.size.width * task.progress, height: 4)
                    }
                }
                .frame(width: 60, height: 4)
                .questBorder(Theme.border.opacity(0.5), width: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(task.status == .active ? Theme.cyanBg.opacity(0.3) : Color.clear)
    }

    // ── Helpers ───────────────────────────────────────────────────
    private var divider: some View {
        Rectangle()
            .fill(Theme.border.opacity(0.5))
            .frame(width: 1)
            .padding(.vertical, 12)
    }

    private func iconName(_ task: FocusTask) -> String {
        switch task.status {
        case .completed: return "checkmark"
        case .active:    return task.pomodoroRunning ? "play.fill" : "pause.fill"
        case .pending:   return "clock"
        }
    }

    private func iconBg(_ task: FocusTask) -> Color {
        switch task.status {
        case .completed: return Theme.green
        case .active:    return Theme.cyan
        case .pending:   return Theme.card
        }
    }

    private func iconFg(_ task: FocusTask) -> Color {
        switch task.status {
        case .completed, .active: return Theme.bg
        case .pending:            return Theme.textFaint
        }
    }

    private func badgeLabel(_ task: FocusTask) -> String {
        switch task.status {
        case .completed: return "DONE"
        case .active:    return task.pomodoroRunning ? "RUNNING" : "PAUSED"
        case .pending:   return "PENDING"
        }
    }

    private func badgeColor(_ task: FocusTask) -> Color {
        switch task.status {
        case .completed: return Theme.green
        case .active:    return Theme.cyan
        case .pending:   return Theme.textFaint
        }
    }

    private var statusEmoji: String {
        let s = store.todayFocusSeconds
        if s == 0        { return "😴" }
        if s < 30 * 60   { return "🌱" }
        if s < 60 * 60   { return "🔥" }
        if s < 2 * 3600  { return "⚡" }
        return "🏆"
    }

    private var statusLabel: String {
        let s = store.todayFocusSeconds
        if s == 0        { return "NOT STARTED" }
        if s < 30 * 60   { return "WARMING UP" }
        if s < 60 * 60   { return "IN THE ZONE" }
        if s < 2 * 3600  { return "ON FIRE" }
        return "LEGENDARY"
    }

    private var statusColor: Color {
        let s = store.todayFocusSeconds
        if s == 0        { return Theme.textFaint }
        if s < 30 * 60   { return Theme.textDim }
        if s < 60 * 60   { return Theme.orange }
        if s < 2 * 3600  { return Theme.cyan }
        return Theme.green
    }
}

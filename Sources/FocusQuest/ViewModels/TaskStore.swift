import Foundation
import Observation

private let saveKey = "focusquest.state"

@Observable
final class TaskStore {

    // ── State ────────────────────────────────────────────────────
    var tasks: [FocusTask] = []
    var settings: AppSettings = AppSettings()
    var taskHistory: [HistoryItem] = []
    var arrangement: ArrangementPlan? = nil
    var isFloating: Bool = false         // always-on-top toggle
    var showSettings: Bool = false

    private var timer: Timer?

    // ── Init ─────────────────────────────────────────────────────
    init() {
        load()
        startTimer()
    }

    // ── Timer ────────────────────────────────────────────────────
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        var changed = false
        for i in tasks.indices {
            var t = tasks[i]
            guard t.status == .active && t.pomodoroRunning else { continue }

            t.elapsed += 1

            // Auto-complete when target reached
            if let target = t.targetSeconds, t.elapsed >= target {
                t.status = .completed
                t.pomodoroRunning = false
                tasks[i] = t
                changed = true
                continue
            }

            t.pomodoroLeft = max(0, t.pomodoroLeft - 1)

            if t.pomodoroLeft == 0 {
                // Pomodoro round done — switch to break
                t.roundsCompleted += 1
                let isLongBreak = t.roundsCompleted % settings.longBreakInterval == 0
                t.pomodoroLeft   = isLongBreak ? settings.longBreakSeconds : settings.shortBreakSeconds
                t.phase          = isLongBreak ? .longBreak : .shortBreak
                t.pomodoroRunning = false   // player starts break manually
            }

            tasks[i] = t
            changed = true
        }
        if changed { save() }
    }

    // ── Task actions ─────────────────────────────────────────────
    func addTask(title: String, targetSeconds: Int?) {
        let task = FocusTask(
            title: title,
            targetSeconds: targetSeconds,
            pomodoroLeft: settings.focusSeconds
        )
        tasks.append(task)
        upsertHistory(title: title, targetSeconds: targetSeconds)
        save()
    }

    func addFromHistory(_ item: HistoryItem) {
        addTask(title: item.title, targetSeconds: item.targetSeconds)
        // Bubble to top of history
        taskHistory.removeAll { $0.title == item.title }
        taskHistory.insert(HistoryItem(title: item.title, targetSeconds: item.targetSeconds), at: 0)
        save()
    }

    func startTask(_ id: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        // Revert any previously active task to pending
        for i in tasks.indices where tasks[i].status == .active {
            tasks[i].status = .pending
            tasks[i].pomodoroRunning = false
        }
        // Move target to front
        var task = tasks.remove(at: idx)
        task.status = .active
        task.pomodoroRunning = true
        task.phase = .focus
        tasks.insert(task, at: 0)
        save()
    }

    func togglePause(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].pomodoroRunning.toggle()
        // When resuming from a break, reset phase to focus
        if tasks[i].pomodoroRunning && tasks[i].phase != .focus {
            tasks[i].pomodoroLeft = settings.focusSeconds
            tasks[i].phase = .focus
        }
        save()
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func moveTask(from source: IndexSet, to destination: Int) {
        tasks.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func updateTarget(id: UUID, seconds: Int?) -> String? {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return nil }

        // Enforce arrangement cap on increases
        if let plan = arrangement, let newTarget = seconds {
            let otherAllocated = tasks.enumerated()
                .filter { $0.offset != i && $0.element.status != .completed }
                .reduce(0) { $0 + ($1.element.targetSeconds ?? 0) }
            let maxForThis = plan.totalFocusSeconds - otherAllocated
            if newTarget > maxForThis {
                let maxH = TimeHelpers.secondsToHoursString(maxForThis)
                return "Max allowed: \(maxH)h (\(TimeHelpers.formatDuration(maxForThis)))"
            }
        }

        tasks[i].targetSeconds = seconds
        // Auto-complete if elapsed already meets new target
        if let target = seconds, tasks[i].elapsed >= target {
            tasks[i].status = .completed
            tasks[i].pomodoroRunning = false
        }
        save()
        return nil
    }

    // ── Arrangement ──────────────────────────────────────────────
    func applyArrangement(_ plan: ArrangementPlan) {
        arrangement = plan
        for i in tasks.indices where tasks[i].status != .completed {
            tasks[i].targetSeconds = plan.perTaskSeconds
        }
        save()
    }

    func clearArrangement() {
        arrangement = nil
        save()
    }

    // ── Derived ──────────────────────────────────────────────────
    var freeTimeRemaining: Int? {
        guard let plan = arrangement else { return nil }
        let used = tasks.filter { $0.status != .completed }
                        .reduce(0) { $0 + ($1.targetSeconds ?? 0) }
        return max(0, plan.totalFocusSeconds - used)
    }

    var activeTasks: [FocusTask]  { tasks.filter { $0.status == .active  } }
    var pendingTasks: [FocusTask] { tasks.filter { $0.status == .pending } }

    // ── Persistence ──────────────────────────────────────────────
    private struct SavedState: Codable {
        var tasks: [FocusTask]
        var settings: AppSettings
        var taskHistory: [HistoryItem]
        var arrangement: ArrangementPlan?
        var isFloating: Bool
    }

    func save() {
        let state = SavedState(
            tasks: tasks, settings: settings,
            taskHistory: taskHistory, arrangement: arrangement,
            isFloating: isFloating
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        tasks       = state.tasks
        settings    = state.settings
        taskHistory = state.taskHistory
        arrangement = state.arrangement
        isFloating  = false
    }

    private func upsertHistory(title: String, targetSeconds: Int?) {
        taskHistory.removeAll { $0.title == title }
        taskHistory.insert(HistoryItem(title: title, targetSeconds: targetSeconds), at: 0)
    }
}

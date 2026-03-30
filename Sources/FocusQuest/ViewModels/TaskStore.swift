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
    var studyWindowRanges: [TimeRangeInput] = [.defaultStudyWindow]
    var isFloating: Bool = false
    var showSettings: Bool = false

    // Distraction monitoring
    var isDistracted: Bool = false
    var distractionURL: String = ""

    private var timer: Timer?
    private let distractionMonitor = DistractionMonitor()

    // ── Init ─────────────────────────────────────────────────────
    init() {
        load()
        startTimer()
        setupDistractionMonitor()
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

            if t.phase == .focus {
                t.elapsed += 1
            }

            // Auto-complete when target reached
            if let target = t.targetSeconds, t.elapsed >= target {
                t.status = .completed
                t.pomodoroRunning = false
                tasks[i] = t
                changed = true
                AudioPlayer.shared.stopCountdown()
                playEffect("finish")
                refreshDistractionMonitor()
                continue
            }

            t.pomodoroLeft = max(0, t.pomodoroLeft - 1)

            if t.pomodoroLeft == 0 {
                switch t.phase {
                case .focus:
                    t.roundsCompleted += 1
                    let isLongBreak = t.roundsCompleted % settings.longBreakInterval == 0
                    t.pomodoroLeft = isLongBreak ? settings.longBreakSeconds : settings.shortBreakSeconds
                    t.phase = isLongBreak ? .longBreak : .shortBreak
                    t.pomodoroRunning = true
                    tasks[i] = t
                    playEffect("finish")
                    startCountdownSound()
                    refreshDistractionMonitor()
                case .shortBreak, .longBreak:
                    t.pomodoroLeft = settings.focusSeconds
                    t.phase = .focus
                    t.pomodoroRunning = true
                    tasks[i] = t
                    playEffect("finish")
                    startCountdownSound()
                    refreshDistractionMonitor()
                }
            }

            tasks[i] = t
            changed = true
        }
        if changed { save() }
    }

    private func playEffect(_ name: String) {
        guard settings.soundEnabled else { return }
        DispatchQueue.main.async { [vol = Float(self.settings.volume)] in
            AudioPlayer.shared.setVolume(vol)
            AudioPlayer.shared.playEffect(named: name)
        }
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

    func applySettings(_ newSettings: AppSettings) {
        settings = newSettings

        for i in tasks.indices where tasks[i].status != .completed {
            switch tasks[i].phase {
            case .focus:
                tasks[i].pomodoroLeft = newSettings.focusSeconds
            case .shortBreak:
                tasks[i].pomodoroLeft = newSettings.shortBreakSeconds
            case .longBreak:
                tasks[i].pomodoroLeft = newSettings.longBreakSeconds
            }
        }

        if let active = activeTasks.first, active.pomodoroRunning, newSettings.soundEnabled {
            startCountdownSound()
        } else {
            AudioPlayer.shared.stopCountdown()
        }

        save()
        refreshDistractionMonitor()
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
        startCountdownSound()
        refreshDistractionMonitor()
    }

    func togglePause(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].pomodoroRunning.toggle()
        if tasks[i].pomodoroRunning {
            isDistracted = false
            distractionURL = ""
            AudioPlayer.shared.stopWarning()
            startCountdownSound()
        } else {
            AudioPlayer.shared.stopCountdown()
        }
        save()
        refreshDistractionMonitor()
    }

    func deleteTask(_ id: UUID) {
        if tasks.contains(where: { $0.id == id && $0.status == .active }) {
            AudioPlayer.shared.stopCountdown()
            AudioPlayer.shared.stopWarning()
            isDistracted = false
            distractionURL = ""
        }
        tasks.removeAll { $0.id == id }
        save()
        refreshDistractionMonitor()
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

    // ── Subtasks ─────────────────────────────────────────────────
    func addSubtask(taskId: UUID, title: String) {
        guard let i = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks[i].subtasks.append(Subtask(title: trimmed))
        save()
    }

    func toggleSubtask(taskId: UUID, subtaskId: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == taskId }),
              let j = tasks[i].subtasks.firstIndex(where: { $0.id == subtaskId }) else { return }
        tasks[i].subtasks[j].isCompleted.toggle()
        save()
    }

    func deleteSubtask(taskId: UUID, subtaskId: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == taskId }) else { return }
        tasks[i].subtasks.removeAll { $0.id == subtaskId }
        save()
    }

    // ── Arrangement ──────────────────────────────────────────────
    func applyArrangement(_ plan: ArrangementPlan) {
        arrangement = plan
        let openTaskIndices = tasks.indices.filter { tasks[$0].status != .completed }
        guard !openTaskIndices.isEmpty else {
            save()
            return
        }

        let baseSeconds = plan.totalFocusSeconds / openTaskIndices.count
        var remainderSeconds = plan.totalFocusSeconds % openTaskIndices.count

        for index in openTaskIndices {
            let bonus = remainderSeconds > 0 ? 1 : 0
            tasks[index].targetSeconds = baseSeconds + bonus
            if remainderSeconds > 0 {
                remainderSeconds -= 1
            }
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
        var studyWindowRanges: [TimeRangeInput]?
        var isFloating: Bool
    }

    func save() {
        let state = SavedState(
            tasks: tasks, settings: settings,
            taskHistory: taskHistory, arrangement: arrangement,
            studyWindowRanges: studyWindowRanges,
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
        studyWindowRanges = state.studyWindowRanges ?? [.defaultStudyWindow]
        isFloating  = false
    }

    private func upsertHistory(title: String, targetSeconds: Int?) {
        taskHistory.removeAll { $0.title == title }
        taskHistory.insert(HistoryItem(title: title, targetSeconds: targetSeconds), at: 0)
    }

    // ── Distraction monitor ───────────────────────────────────────
    private func setupDistractionMonitor() {
        distractionMonitor.onDistracted = { [weak self] url in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                // Only intervene during an active focus phase (not breaks)
                guard let active = self.activeTasks.first,
                      active.pomodoroRunning,
                      active.phase == .focus else { return }
                self.isDistracted = true
                self.distractionURL = url
                // Auto-pause the countdown and start looping warning
                if let i = self.tasks.firstIndex(where: { $0.id == active.id }) {
                    self.tasks[i].pomodoroRunning = false
                    AudioPlayer.shared.stopCountdown()
                    if self.settings.soundEnabled {
                        AudioPlayer.shared.setVolume(Float(self.settings.volume))
                        AudioPlayer.shared.startWarning(named: "warning")
                    }
                    self.save()
                }
            }
        }

        distractionMonitor.onCleared = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isDistracted = false
                self.distractionURL = ""
                AudioPlayer.shared.stopWarning()
            }
        }

        refreshDistractionMonitor()
    }

    /// Call whenever blockedURLs changes or a task starts/stops.
    func refreshDistractionMonitor() {
        let urls = settings.blockedURLs.filter { !$0.isEmpty }
        let hasActiveRunningFocusTask = activeTasks.contains { $0.phase == .focus && $0.pomodoroRunning }
        if urls.isEmpty || !hasActiveRunningFocusTask || !DistractionMonitor.hasPermission {
            distractionMonitor.stop()
            isDistracted = false
            distractionURL = ""
        } else {
            distractionMonitor.start(blockedURLs: urls)
        }
    }

    private func startCountdownSound() {
        guard settings.soundEnabled else { return }
        DispatchQueue.main.async { [vol = Float(self.settings.volume)] in
            AudioPlayer.shared.setVolume(vol)
            AudioPlayer.shared.startCountdown(named: "duration")
        }
    }
}

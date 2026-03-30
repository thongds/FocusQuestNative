import Foundation

enum TaskStatus: String, Codable {
    case pending, active, completed
}

enum PomodoroPhase: String, Codable {
    case focus, shortBreak, longBreak
}

struct Subtask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
}

struct FocusTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var targetSeconds: Int?         // total duration goal in seconds
    var elapsed: Int = 0            // seconds worked so far
    var status: TaskStatus = .pending
    var pomodoroLeft: Int           // seconds left in current pomodoro round
    var pomodoroRunning: Bool = false
    var roundsCompleted: Int = 0
    var phase: PomodoroPhase = .focus
    var subtasks: [Subtask] = []

    // Backward-compatible decoder so existing saves (without subtasks) still load
    enum CodingKeys: String, CodingKey {
        case id, title, targetSeconds, elapsed, status,
             pomodoroLeft, pomodoroRunning, roundsCompleted, phase, subtasks
    }

    init(id: UUID = UUID(), title: String, targetSeconds: Int? = nil,
         elapsed: Int = 0, status: TaskStatus = .pending,
         pomodoroLeft: Int, pomodoroRunning: Bool = false,
         roundsCompleted: Int = 0, phase: PomodoroPhase = .focus,
         subtasks: [Subtask] = []) {
        self.id = id
        self.title = title
        self.targetSeconds = targetSeconds
        self.elapsed = elapsed
        self.status = status
        self.pomodoroLeft = pomodoroLeft
        self.pomodoroRunning = pomodoroRunning
        self.roundsCompleted = roundsCompleted
        self.phase = phase
        self.subtasks = subtasks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,          forKey: .id)
        title           = try c.decode(String.self,        forKey: .title)
        targetSeconds   = try c.decodeIfPresent(Int.self,  forKey: .targetSeconds)
        elapsed         = try c.decodeIfPresent(Int.self,  forKey: .elapsed)         ?? 0
        status          = try c.decodeIfPresent(TaskStatus.self,     forKey: .status)          ?? .pending
        pomodoroLeft    = try c.decodeIfPresent(Int.self,  forKey: .pomodoroLeft)    ?? 0
        pomodoroRunning = try c.decodeIfPresent(Bool.self, forKey: .pomodoroRunning) ?? false
        roundsCompleted = try c.decodeIfPresent(Int.self,  forKey: .roundsCompleted) ?? 0
        phase           = try c.decodeIfPresent(PomodoroPhase.self,  forKey: .phase)           ?? .focus
        subtasks        = try c.decodeIfPresent([Subtask].self, forKey: .subtasks)   ?? []
    }

    // Convenience
    var progress: Double {
        guard let target = targetSeconds, target > 0 else { return 0 }
        return min(1.0, Double(elapsed) / Double(target))
    }

    var formattedTarget: String {
        guard let t = targetSeconds else { return "--" }
        return TimeHelpers.formatDuration(t)
    }

    var formattedElapsed: String {
        TimeHelpers.formatMMSS(elapsed)
    }

    var formattedPomodoroLeft: String {
        TimeHelpers.formatMMSS(pomodoroLeft)
    }
}

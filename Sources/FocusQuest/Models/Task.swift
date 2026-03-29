import Foundation

enum TaskStatus: String, Codable {
    case pending, active, completed
}

enum PomodoroPhase: String, Codable {
    case focus, shortBreak, longBreak
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

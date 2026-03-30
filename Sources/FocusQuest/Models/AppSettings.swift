import Foundation

struct AppSettings: Codable, Equatable {
    var focusMinutes: Int = 25
    var shortBreak: Int = 5
    var longBreak: Int = 15
    var longBreakInterval: Int = 4
    var soundEnabled: Bool = true
    var volume: Double = 0.8

    var focusSeconds: Int  { focusMinutes  * 60 }
    var shortBreakSeconds: Int { shortBreak * 60 }
    var longBreakSeconds: Int  { longBreak  * 60 }
}

struct HistoryItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var targetSeconds: Int?
}

struct ArrangementPlan: Codable, Equatable {
    var startTime: String       // "HH:mm"
    var endTime: String         // "HH:mm"
    var totalFocusSeconds: Int
    var perTaskSeconds: Int
}

struct TimeRangeInput: Identifiable, Codable, Equatable {
    var id: UUID
    var startTime: Date
    var endTime: Date

    init(id: UUID = UUID(), startTime: Date, endTime: Date) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
    }

    static var defaultStudyWindow: TimeRangeInput {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
        let end = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        return TimeRangeInput(startTime: start, endTime: end)
    }
}

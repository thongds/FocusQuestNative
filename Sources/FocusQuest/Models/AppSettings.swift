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

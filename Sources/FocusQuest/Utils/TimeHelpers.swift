import Foundation

enum TimeHelpers {
    // "02:45"
    static func formatMMSS(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // "1h 30m"
    static func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }

    // hours double → nearest-minute seconds  e.g. 1.5 → 5400
    static func hoursToSeconds(_ hours: Double) -> Int {
        Int(hours * 60.0 + 0.5) * 60
    }

    // seconds → hours string with max 2 decimal places  e.g. 14100 → "3.92"
    static func secondsToHoursString(_ seconds: Int) -> String {
        let totalMinutes = (seconds + 30) / 60   // round to nearest minute
        let hours = Double(totalMinutes) / 60.0
        let str = String(format: "%.2f", hours)
        // strip trailing zeros: "3.50" → "3.5", "3.00" → "3"
        if str.hasSuffix("0") {
            let trimmed = str.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            return trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed
        }
        return str
    }

    // Parse "HH:mm" → total minutes from midnight, or nil
    static func parseTime(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }
}

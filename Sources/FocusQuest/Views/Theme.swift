import SwiftUI

enum Theme {
    static let bg        = Color(hex: "#070d1a")
    static let card      = Color(hex: "#0c1628")
    static let border    = Color(hex: "#1e2d45")
    static let borderDim = Color(hex: "#0f1e30")
    static let text      = Color(hex: "#c8d8f0")
    static let textDim   = Color(hex: "#7a8eaa")
    static let textFaint = Color(hex: "#4a6080")
    static let green     = Color(hex: "#2af598")
    static let greenBg   = Color(hex: "#081a10")
    static let cyan      = Color(hex: "#00e5ff")
    static let cyanBg    = Color(hex: "#041218")
    static let orange    = Color(hex: "#f0a500")
    static let red       = Color(hex: "#ff4466")
    static let mono      = Font.system(.body, design: .monospaced)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let rgb = UInt64(hex, radix: 16) ?? 0
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// Shared border modifier
struct QuestBorder: ViewModifier {
    var color: Color = Theme.border
    var width: CGFloat = 1.5
    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(color, lineWidth: width)
                .allowsHitTesting(false)
        )
    }
}

extension View {
    func questBorder(_ color: Color = Theme.border, width: CGFloat = 1.5) -> some View {
        modifier(QuestBorder(color: color, width: width))
    }
}

import SwiftUI

struct NotificationEvent: Identifiable, Codable, Sendable {
    let id: String
    let icon: String
    let colorName: String
    let title: String
    let subtitle: String
    let date: Date

    init(icon: String, colorName: String, title: String, subtitle: String, date: Date) {
        self.id = UUID().uuidString
        self.icon = icon
        self.colorName = colorName
        self.title = title
        self.subtitle = subtitle
        self.date = date
    }

    var color: Color {
        switch colorName {
        case "orange": return .orange
        case "yellow": return .yellow
        case "primaryBright": return PulseTheme.primaryBright
        default: return PulseTheme.primary
        }
    }
}

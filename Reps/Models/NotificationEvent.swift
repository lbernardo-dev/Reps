import SwiftUI

/// Where an inbox notification row should take the user when tapped. Routes
/// within the current navigation stack. Optional so older persisted events
/// (encoded before this field existed) keep decoding.
enum InboxDestination: Codable, Hashable, Sendable {
    case workoutHistory
    case session(id: String)
    case personalRecords
    case socialProfile(username: String)
}

struct NotificationEvent: Identifiable, Codable, Sendable {
    let id: String
    let icon: String
    let colorName: String
    let title: String
    let subtitle: String
    let date: Date
    let destination: InboxDestination?

    init(
        icon: String,
        colorName: String,
        title: String,
        subtitle: String,
        date: Date,
        destination: InboxDestination? = nil
    ) {
        self.id = UUID().uuidString
        self.icon = icon
        self.colorName = colorName
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.destination = destination
    }

    var color: Color {
        switch colorName {
        case "orange": return .orange
        case "yellow": return .yellow
        case "primaryBright": return PulseTheme.ringStand
        default: return PulseTheme.accent
        }
    }
}

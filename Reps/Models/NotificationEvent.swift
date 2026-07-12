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

/// Groups inbox events so they can be muted/organized independently. Persisted
/// events created before this field existed decode as `.coaching`.
enum NotificationCategory: String, Codable, CaseIterable, Sendable {
    case workout
    case achievement
    case coaching
    case social

    var icon: String {
        switch self {
        case .workout: return "figure.strengthtraining.traditional"
        case .achievement: return "rosette"
        case .coaching: return "lightbulb.fill"
        case .social: return "person.2.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .workout: return localizedString("notif_category_workout")
        case .achievement: return localizedString("notif_category_achievements")
        case .coaching: return localizedString("notif_category_coaching")
        case .social: return localizedString("social_activity_notifs")
        }
    }

    var localizedSubtitle: String {
        switch self {
        case .workout: return localizedString("notif_category_workout_desc")
        case .achievement: return localizedString("notif_category_achievements_desc")
        case .coaching: return localizedString("notif_category_coaching_desc")
        case .social: return localizedString("notif_category_social_desc")
        }
    }
}

struct NotificationEvent: Identifiable, Codable, Sendable {
    let id: String
    let icon: String
    let colorName: String
    let title: String
    let subtitle: String
    let date: Date
    let destination: InboxDestination?
    var category: NotificationCategory = .coaching
    var isRead: Bool = false

    init(
        icon: String,
        colorName: String,
        title: String,
        subtitle: String,
        date: Date,
        destination: InboxDestination? = nil,
        category: NotificationCategory,
        isRead: Bool = false
    ) {
        self.id = UUID().uuidString
        self.icon = icon
        self.colorName = colorName
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.destination = destination
        self.category = category
        self.isRead = isRead
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

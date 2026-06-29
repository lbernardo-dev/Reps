import SwiftUI
import WatchKit

/// Centralized design tokens for the Reps watch app.
/// Mirrors the iPhone `PulseTheme` semantics; the watch target cannot see
/// `PulseTheme`, so the load-bearing values live here as the single source of truth.
enum WatchTheme {
    // Cards
    static let cardRadius: CGFloat = 15
    static let cardPadding: CGFloat = 10
    static let cardFill = Color.white.opacity(0.04)
    static let cardBorder = Color.white.opacity(0.08)

    // Controls
    static let buttonHeight: CGFloat = 46
    static let primaryActionHeight: CGFloat = 50
    static let minScale: CGFloat = 0.8

    // Semantic colors (kept in sync with PulseTheme)
    static let success = Color(red: 0.57, green: 0.91, blue: 0.16)   // ringExercise green
    static let warning = Color(red: 1.0, green: 0.60, blue: 0.14)
    static let destructive = Color(red: 0.93, green: 0.24, blue: 0.22)
    static let fallbackAccent = Color(red: 0.69, green: 0.99, blue: 0.16) // neon green #B0FC29

    // Activity ring colors — mirror PulseTheme
    static let ringMove     = Color(red: 0.98, green: 0.07, blue: 0.31)  // red-pink
    static let ringExercise = Color(red: 0.57, green: 0.91, blue: 0.16)  // green
    static let ringStand    = Color(red: 0.12, green: 0.92, blue: 0.94)  // cyan

    /// Resolves the snapshot accent name through the shared `WidgetColor`
    /// mapping so accent colors never drift between targets.
    static func accent(for name: String) -> Color {
        WidgetColor.from(name: name).color
    }

    static func batteryColor(for level: Int) -> Color {
        if level >= 75 { return success }
        if level >= 40 { return warning }
        if level >= 20 { return Color(red: 1.0, green: 0.60, blue: 0.14) }
        return destructive
    }

    // HR zones — same thresholds/colors as PulseTheme.hrZones.
    static let zoneColors: [Color] = [
        ringStand,              // Z1 recovery — cyan
        ringExercise,           // Z2 easy — green
        Color.yellow,           // Z3 moderate
        Color.orange,           // Z4 hard
        ringMove                // Z5 max — red-pink
    ]

    /// Color for an HR zone index (1…5). Returns secondary gray when unknown.
    static func zoneColor(_ zone: Int?) -> Color {
        guard let zone, (1...5).contains(zone) else { return Color.white.opacity(0.4) }
        return zoneColors[zone - 1]
    }

    static func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

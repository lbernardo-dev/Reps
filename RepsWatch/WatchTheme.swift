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
    static let success = Color(red: 0.18, green: 0.72, blue: 0.38)
    static let warning = Color(red: 1.0, green: 0.60, blue: 0.14)
    static let destructive = Color(red: 0.93, green: 0.24, blue: 0.22)
    static let fallbackAccent = Color(red: 0.23, green: 0.52, blue: 0.96)

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

    // HR zones — same thresholds/colors as the iPhone `ProgressView.zoneColor`.
    static let zoneColors: [Color] = [
        Color(red: 0.0, green: 0.48, blue: 1.0),   // Z1 recovery
        Color(red: 0.20, green: 0.80, blue: 0.35), // Z2 easy
        Color.yellow,                              // Z3 moderate
        Color.orange,                              // Z4 hard
        Color.red                                  // Z5 max
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

import AppIntents
import SwiftUI

public enum WidgetColor: String, AppEnum, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple
    case red
    case yellow
    case system

    public var id: String { rawValue }

    public static func from(name: String) -> WidgetColor {
        switch name.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        case "yellow": return .yellow
        default: return .system
        }
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Color de Acento")
    }

    public static var caseDisplayRepresentations: [WidgetColor: DisplayRepresentation] {
        [
            .blue: DisplayRepresentation(stringLiteral: "Azul"),
            .green: DisplayRepresentation(stringLiteral: "Verde"),
            .orange: DisplayRepresentation(stringLiteral: "Naranja"),
            .purple: DisplayRepresentation(stringLiteral: "Morado"),
            .red: DisplayRepresentation(stringLiteral: "Rojo"),
            .yellow: DisplayRepresentation(stringLiteral: "Amarillo"),
            .system: DisplayRepresentation(stringLiteral: "Sistema")
        ]
    }

    public var color: Color {
        switch self {
        case .blue: return Color(red: 0.23, green: 0.52, blue: 0.96)
        case .green: return Color(red: 0.33, green: 0.86, blue: 0.32)
        case .orange: return Color(red: 1.0, green: 0.60, blue: 0.14)
        case .purple: return Color(red: 0.52, green: 0.14, blue: 0.86)
        case .red: return Color(red: 0.93, green: 0.24, blue: 0.22)
        case .yellow: return Color(red: 1.0, green: 0.80, blue: 0.14)
        case .system: return Color(red: 0.23, green: 0.52, blue: 0.96)
        }
    }

    public var theme: WidgetTheme {
        switch self {
        case .blue:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.18, blue: 0.40), Color(red: 0.03, green: 0.07, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 0.35, green: 0.65, blue: 1.0),
                isDarkBackground: true
            )
        case .green:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.06, green: 0.28, blue: 0.14), Color(red: 0.02, green: 0.10, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 0.45, green: 0.90, blue: 0.50),
                isDarkBackground: true
            )
        case .orange:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.38, green: 0.15, blue: 0.04), Color(red: 0.16, green: 0.05, blue: 0.01)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 1.0, green: 0.60, blue: 0.25),
                isDarkBackground: true
            )
        case .purple:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.08, blue: 0.40), Color(red: 0.08, green: 0.02, blue: 0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 0.75, green: 0.45, blue: 1.0),
                isDarkBackground: true
            )
        case .red:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.36, green: 0.06, blue: 0.06), Color(red: 0.16, green: 0.02, blue: 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 1.0, green: 0.40, blue: 0.40),
                isDarkBackground: true
            )
        case .yellow:
            return WidgetTheme(
                background: AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.78, blue: 0.08), Color(red: 0.90, green: 0.62, blue: 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ),
                foreground: Color(red: 0.08, green: 0.06, blue: 0.02),
                secondaryForeground: Color(red: 0.08, green: 0.06, blue: 0.02).opacity(0.65),
                badgeBackground: Color.black.opacity(0.12),
                badgeText: Color(red: 0.08, green: 0.06, blue: 0.02),
                tint: Color(red: 0.08, green: 0.06, blue: 0.02),
                isDarkBackground: false
            )
        case .system:
            return WidgetTheme(
                background: AnyView(
                    ZStack {
                        #if os(watchOS)
                        Color.black
                        #else
                        Color(uiColor: .systemBackground)
                        #endif
                        LinearGradient(
                            colors: [Color(red: 0.23, green: 0.52, blue: 0.96).opacity(0.07), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                ),
                foreground: .primary,
                secondaryForeground: .secondary,
                badgeBackground: Color(red: 0.23, green: 0.52, blue: 0.96).opacity(0.12),
                badgeText: Color(red: 0.23, green: 0.52, blue: 0.96),
                tint: Color(red: 0.23, green: 0.52, blue: 0.96),
                isDarkBackground: false
            )
        }
    }
}

public struct WidgetTheme {
    public let background: AnyView
    public let foreground: Color
    public let secondaryForeground: Color
    public let badgeBackground: Color
    public let badgeText: Color
    public let tint: Color
    public let isDarkBackground: Bool
}

public struct RepsWidgetConfigurationIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "Configuración del Widget"
    public static let description = IntentDescription("Personaliza la visualización de los widgets de Reps.")

    @Parameter(title: "Color de Acento", default: .system)
    public var accentColor: WidgetColor

    public init() {}
}

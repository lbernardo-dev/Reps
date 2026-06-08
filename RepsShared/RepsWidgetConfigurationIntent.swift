import AppIntents
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    public static func resolved(appColorName: String, widgetBackgroundColor: WidgetColor) -> WidgetColor {
        let appColor = WidgetColor.from(name: appColorName)
        return widgetBackgroundColor == .system ? appColor : widgetBackgroundColor
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Color de fondo")
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
        case .green: return Color(red: 0.28, green: 0.86, blue: 0.38)
        case .orange: return Color(red: 1.0, green: 0.60, blue: 0.14)
        case .purple: return Color(red: 0.52, green: 0.14, blue: 0.86)
        case .red: return Color(red: 0.93, green: 0.24, blue: 0.22)
        case .yellow: return Color(red: 1.0, green: 0.80, blue: 0.14)
        case .system: return Color(red: 0.28, green: 0.86, blue: 0.38)
        }
    }

    public var widgetBackgroundFill: Color {
        switch self {
        case .blue: return Color(red: 0.06, green: 0.16, blue: 0.36)
        case .green: return Color(red: 0.04, green: 0.16, blue: 0.09)
        case .orange: return Color(red: 0.34, green: 0.13, blue: 0.03)
        case .purple: return Color(red: 0.18, green: 0.06, blue: 0.34)
        case .red: return Color(red: 0.34, green: 0.05, blue: 0.05)
        case .yellow: return Color(red: 0.92, green: 0.66, blue: 0.03)
        case .system:
            #if os(iOS)
            return Color(uiColor: .systemBackground)
            #else
            return Color.primary.opacity(0.05)
            #endif
        }
    }

    private static func darkBackground(top: Color, bottom: Color, accent: Color) -> AnyView {
        AnyView(
            ZStack {
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.white.opacity(0.16), .clear, .black.opacity(0.24)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [accent.opacity(0.26), .clear],
                    startPoint: .bottomTrailing,
                    endPoint: .center
                )
            }
        )
    }

    private static func lightBackground(top: Color, bottom: Color, accent: Color) -> AnyView {
        AnyView(
            ZStack {
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.white.opacity(0.34), .clear, accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }

    public var theme: WidgetTheme {
        switch self {
        case .blue:
            return WidgetTheme(
                background: Self.darkBackground(
                    top: Color(red: 0.08, green: 0.18, blue: 0.40),
                    bottom: Color(red: 0.03, green: 0.07, blue: 0.18),
                    accent: Color(red: 0.35, green: 0.65, blue: 1.0)
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
                background: Self.darkBackground(
                    top: Color(red: 0.05, green: 0.18, blue: 0.10),
                    bottom: Color(red: 0.01, green: 0.05, blue: 0.03),
                    accent: Color(red: 0.28, green: 0.86, blue: 0.38)
                ),
                foreground: .white,
                secondaryForeground: .white.opacity(0.7),
                badgeBackground: .white.opacity(0.15),
                badgeText: .white,
                tint: Color(red: 0.28, green: 0.86, blue: 0.38),
                isDarkBackground: true
            )
        case .orange:
            return WidgetTheme(
                background: Self.darkBackground(
                    top: Color(red: 0.38, green: 0.15, blue: 0.04),
                    bottom: Color(red: 0.16, green: 0.05, blue: 0.01),
                    accent: Color(red: 1.0, green: 0.60, blue: 0.25)
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
                background: Self.darkBackground(
                    top: Color(red: 0.22, green: 0.08, blue: 0.40),
                    bottom: Color(red: 0.08, green: 0.02, blue: 0.18),
                    accent: Color(red: 0.75, green: 0.45, blue: 1.0)
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
                background: Self.darkBackground(
                    top: Color(red: 0.36, green: 0.06, blue: 0.06),
                    bottom: Color(red: 0.16, green: 0.02, blue: 0.02),
                    accent: Color(red: 1.0, green: 0.40, blue: 0.40)
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
                background: Self.lightBackground(
                    top: Color(red: 0.98, green: 0.78, blue: 0.08),
                    bottom: Color(red: 0.90, green: 0.62, blue: 0.02),
                    accent: Color(red: 0.08, green: 0.06, blue: 0.02)
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
                        Color.primary.opacity(0.06)
                        #elseif os(iOS)
                        Color(uiColor: .systemBackground)
                        #else
                        Color.primary.opacity(0.06)
                        #endif
                        LinearGradient(
                            colors: [Color(red: 0.28, green: 0.86, blue: 0.38).opacity(0.12), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                ),
                foreground: .primary,
                secondaryForeground: .secondary,
                badgeBackground: Color.primary.opacity(0.08),
                badgeText: Color(red: 0.48, green: 0.88, blue: 0.58),
                tint: Color(red: 0.28, green: 0.86, blue: 0.38),
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

    @Parameter(title: "Fondo", default: WidgetColor.system)
    public var backgroundColor: WidgetColor

    public init() {}
}

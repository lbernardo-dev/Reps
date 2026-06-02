import WidgetKit
import SwiftUI
import AppIntents

struct RepsStreakEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuration: RepsWidgetConfigurationIntent
}

struct RepsStreakProvider: AppIntentTimelineProvider {
    typealias Entry = RepsStreakEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsStreakEntry {
        RepsStreakEntry(date: .now, snapshot: .empty, configuration: RepsWidgetConfigurationIntent())
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsStreakEntry {
        RepsStreakEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuration: configuration)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsStreakEntry> {
        let entry = RepsStreakEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct RepsStreakWidget: Widget {
    let kind = "RepsStreakWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsStreakProvider()) { entry in
            RepsStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Racha y Consistencia")
        .description("Días de racha seguidos y progreso semanal de entrenamientos.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget View

private struct RepsStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsStreakEntry

    var body: some View {
        let resolvedColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetColor: entry.configuration.accentColor
        )
        let theme = resolvedColor.theme
        let streak = entry.snapshot.streakDays
        let completion = entry.snapshot.weeklyCompletion
        let hasPlan = entry.snapshot.nextWorkoutDayName != nil || entry.snapshot.planTitle != nil

        switch family {
        case .accessoryCircular:
            Gauge(value: completion) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text("\(streak)")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("\(streak) días", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Progreso: \(Int(completion * 100))%")
                    .font(.caption)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .opacity(hasPlan ? 1 : 0.7)
            }

        default:
            if family == .systemSmall {
                SmallStreakView(entry: entry, theme: theme, streak: streak, completion: completion, hasPlan: hasPlan)
                    .padding(14)
                    .containerBackground(for: .widget) {
                        theme.background
                    }
                    .widgetURL(URL(string: "reps://workout"))
            } else {
                MediumStreakView(entry: entry, theme: theme, streak: streak, completion: completion, hasPlan: hasPlan)
                    .padding(14)
                    .containerBackground(for: .widget) {
                        theme.background
                    }
                    .widgetURL(URL(string: "reps://workout"))
            }
        }
    }
}

// MARK: - Small Streak

private struct SmallStreakView: View {
    let entry: RepsStreakEntry
    let theme: WidgetTheme
    let streak: Int
    let completion: Double
    let hasPlan: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("RACHA")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.tint)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            Spacer(minLength: 0)

            // Huge Streak count (#) — User Request 7
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(streak)")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                
                Text(streak == 1 ? "día" : "días")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.secondaryForeground)
            }
            .padding(.vertical, -4)

            Text(hasPlan ? "COMPLETADOS" : "SIN PLAN")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(theme.secondaryForeground)

            Spacer(minLength: 0)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.isDarkBackground ? Color.white.opacity(0.18) : Color.primary.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(theme.tint)
                        .frame(width: geo.size.width * CGFloat(min(completion, 1.0)), height: 5)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Medium Streak

private struct MediumStreakView: View {
    let entry: RepsStreakEntry
    let theme: WidgetTheme
    let streak: Int
    let completion: Double
    let hasPlan: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Left: flame icon + count
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 38
                            )
                        )
                        .frame(width: 70, height: 70)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.red.opacity(0.25), radius: 6)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text(streak == 1 ? "día" : "días")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)
                }
            }

            // Right: stats
            VStack(alignment: .leading, spacing: 4) {
                Text("CONSISTENCIA SEMANAL")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(streak > 0 ? "¡Excelente constancia!" : (hasPlan ? "Empieza tu racha hoy" : "Crea tu primer plan"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 2)

                Text(hasPlan ? "Has completado el \(Int(completion * 100))% de tus entrenos planificados esta semana." : "Cuando tengas un plan activo, aquí verás tu progreso semanal.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryForeground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                // Weekly bar dots
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Double(index) / 4.0 < completion ? theme.tint : (theme.isDarkBackground ? Color.white.opacity(0.18) : Color.primary.opacity(0.12)))
                            .frame(height: 6)
                    }
                }
            }
        }
    }
}

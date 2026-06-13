import WidgetKit
import SwiftUI
import AppIntents

struct RepsBatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuredBackgroundColor: WidgetColor
}

struct RepsBatteryProvider: AppIntentTimelineProvider {
    typealias Entry = RepsBatteryEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsBatteryEntry {
        RepsBatteryEntry(date: .now, snapshot: .empty, configuredBackgroundColor: .system)
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsBatteryEntry {
        RepsBatteryEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsBatteryEntry> {
        let entry = RepsBatteryEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct RepsBatteryWidget: Widget {
    let kind = "RepsBatteryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsBatteryProvider()) { entry in
            RepsBatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Batería de Recuperación")
        .description("Nivel de energía, descanso y sugerencia de entreno.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Helpers

private func batteryColor(for level: Int) -> Color {
    if level >= 75 { return Color(red: 0.28, green: 0.86, blue: 0.38) }
    if level >= 40 { return Color(red: 1.0,  green: 0.80, blue: 0.14) }
    if level >= 20 { return Color(red: 1.0,  green: 0.60, blue: 0.14) }
    return Color(red: 0.93, green: 0.24, blue: 0.22)
}

// MARK: - Widget View

private struct RepsBatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsBatteryEntry

    var body: some View {
        let contentColor = WidgetColor.from(name: entry.snapshot.widgetAccentColorName)
        let backgroundColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetBackgroundColor: entry.configuredBackgroundColor
        )
        let theme = contentColor.theme
        let level = entry.snapshot.trainingBatteryLevel
        let bColor = batteryColor(for: level)

        switch family {
        case .accessoryCircular:
            Gauge(value: Double(level) / 100.0) {
                Image(systemName: "battery.100percent")
            } currentValueLabel: {
                Text("\(level)%")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Batería: \(level)%", systemImage: "battery.100percent")
                    .font(.headline)
                    .foregroundStyle(bColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.snapshot.trainingBatteryTitle)
                    .font(.caption.weight(.bold))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(entry.snapshot.trainingBatterySuggestion)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

        case .accessoryInline:
            Text("Reps batería \(level)% · \(entry.snapshot.trainingBatteryTitle)")
                .widgetURL(URL(string: "reps://workout"))

        default:
            if family == .systemSmall {
                SmallBatteryView(entry: entry, theme: theme, bColor: bColor, level: level, resolvedColor: contentColor)
                    .padding(14)
                    .repsWidgetBackground(backgroundColor)
                    .widgetURL(URL(string: "reps://workout"))
            } else {
                MediumBatteryView(entry: entry, theme: theme, bColor: bColor, level: level, resolvedColor: contentColor)
                    .padding(14)
                    .repsWidgetBackground(backgroundColor)
                    .widgetURL(URL(string: "reps://workout"))
            }
        }
    }
}

// MARK: - Small Battery

private struct SmallBatteryView: View {
    let entry: RepsBatteryEntry
    let theme: WidgetTheme
    let bColor: Color
    let level: Int
    let resolvedColor: WidgetColor

    var body: some View {
        let percentageColor = (resolvedColor == .system) ? theme.tint : theme.foreground

        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .center) {
                Image(systemName: entry.snapshot.trainingBatterySystemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(percentageColor)
                Spacer()
                Text("BATERÍA")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.tint)
            }

            // Level percentage (# and %) — User Request 7
            Text("\(level)%")
                .font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundStyle(percentageColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.top, -4)

            // State title
            Text(entry.snapshot.trainingBatteryTitle.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(theme.secondaryForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            // Suggestion text
            Text(entry.snapshot.trainingBatterySuggestion)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(3)
                .minimumScaleFactor(0.75)
                .foregroundStyle(theme.secondaryForeground)
        }
    }
}

// MARK: - Medium Battery

private struct MediumBatteryView: View {
    let entry: RepsBatteryEntry
    let theme: WidgetTheme
    let bColor: Color
    let level: Int
    let resolvedColor: WidgetColor

    var body: some View {
        let gaugeColor = theme.tint

        HStack(spacing: 14) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(theme.isDarkBackground ? Color.white.opacity(0.18) : Color.primary.opacity(0.06), lineWidth: 8)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0.0, to: CGFloat(level) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [gaugeColor.opacity(0.6), gaugeColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(Double(level) / 100.0 * 360.0 - 90.0)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gaugeColor.opacity(0.3), radius: 4)

                VStack(spacing: 1) {
                    Text("\(level)%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(gaugeColor)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Image(systemName: entry.snapshot.trainingBatterySystemImage)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryForeground)
                }
            }
            .frame(width: 70)

            // Right column
            VStack(alignment: .leading, spacing: 4) {
                Text("BATERÍA DE RECUPERACIÓN")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entry.snapshot.trainingBatteryTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Text(entry.snapshot.trainingBatterySuggestion)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(theme.secondaryForeground)
            }
        }
    }
}

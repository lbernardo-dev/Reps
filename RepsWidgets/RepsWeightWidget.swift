import WidgetKit
import SwiftUI
import AppIntents

struct RepsWeightEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuredBackgroundColor: WidgetColor
}

struct RepsWeightProvider: AppIntentTimelineProvider {
    typealias Entry = RepsWeightEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsWeightEntry {
        RepsWeightEntry(date: .now, snapshot: .samplePlaceholder, configuredBackgroundColor: .system)
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsWeightEntry {
        let snapshot = context.isPreview ? .samplePlaceholder : SharedWorkoutStore.load()
        return RepsWeightEntry(date: .now, snapshot: snapshot, configuredBackgroundColor: configuration.backgroundColor)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsWeightEntry> {
        let snapshot = context.isPreview ? .samplePlaceholder : SharedWorkoutStore.load()
        let entry = RepsWeightEntry(date: .now, snapshot: snapshot, configuredBackgroundColor: configuration.backgroundColor)
        return Timeline(entries: [entry], policy: .after(nextMidnight()))
    }
}

struct RepsWeightWidget: Widget {
    let kind = "RepsWeightWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsWeightProvider()) { entry in
            RepsWeightWidgetView(entry: entry)
        }
        .configurationDisplayName("weight_widget_name")
        .description("weight_widget_description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Widget View

private struct RepsWeightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWeightEntry

    var body: some View {
        let _ = RepsLocalization.use(entry.snapshot.preferredLanguage)
        let backgroundColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetBackgroundColor: entry.configuredBackgroundColor
        )
        let theme = backgroundColor.theme
        let currentKg = entry.snapshot.currentWeightKg ?? 78.5
        let deltaKg = entry.snapshot.weeklyWeightDeltaKg ?? -0.4
        let targetKg = entry.snapshot.targetWeightKg ?? (currentKg > 75 ? currentKg - 4.0 : currentKg + 3.0)

        switch family {
        case .accessoryCircular:
            VStack(spacing: 1) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 10))
                Text(String(format: "%.1f", currentKg))
                    .font(.system(size: 11, weight: .bold))
            }
            .widgetURL(URL(string: "reps://weight"))

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption2)
                    Text("WEIGHT EVOLUTION")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.secondary)
                Text(String(format: "%.1f kg", currentKg))
                    .font(.headline.weight(.black))
                Text(String(format: "%+.1f kg this week", deltaKg))
                    .font(.caption2)
                    .foregroundStyle(deltaKg <= 0 ? Color.green : Color.orange)
            }
            .widgetURL(URL(string: "reps://weight"))

        case .accessoryInline:
            Text(String(format: "Weight: %.1f kg (%+.1f kg)", currentKg, deltaKg))
                .widgetURL(URL(string: "reps://weight"))

        case .systemSmall:
            SmallWeightWidgetView(currentKg: currentKg, deltaKg: deltaKg, targetKg: targetKg, theme: theme)
                .padding(14)
                .repsWidgetBackground(backgroundColor)
                .widgetURL(URL(string: "reps://weight"))

        case .systemMedium:
            MediumWeightWidgetView(currentKg: currentKg, deltaKg: deltaKg, targetKg: targetKg, theme: theme)
                .padding(14)
                .repsWidgetBackground(backgroundColor)
                .widgetURL(URL(string: "reps://weight"))

        default:
            LargeWeightWidgetView(currentKg: currentKg, deltaKg: deltaKg, targetKg: targetKg, theme: theme)
                .padding(16)
                .repsWidgetBackground(backgroundColor)
                .widgetURL(URL(string: "reps://weight"))
        }
    }
}

// MARK: - Small Weight View

private struct SmallWeightWidgetView: View {
    let currentKg: Double
    let deltaKg: Double
    let targetKg: Double
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.tint)
                    Text("WEIGHT")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.tint)
                }
                Spacer()
                Image(systemName: deltaKg <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(deltaKg <= 0 ? Color.green : Color.orange)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%.1f", currentKg))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("kg")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.secondaryForeground)
            }

            Spacer(minLength: 2)

            // Delta Pill
            HStack(spacing: 4) {
                Text(String(format: "%+.1f kg", deltaKg))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(deltaKg <= 0 ? Color.green : Color.orange)
                Text("7d")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondaryForeground)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                (deltaKg <= 0 ? Color.green : Color.orange).opacity(0.15),
                in: Capsule()
            )
        }
    }
}

// MARK: - Medium Weight View

private struct MediumWeightWidgetView: View {
    let currentKg: Double
    let deltaKg: Double
    let targetKg: Double
    let theme: WidgetTheme

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "scalemass.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.tint)
                    Text("BODY WEIGHT")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(theme.tint)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", currentKg))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                    Text("kg")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.secondaryForeground)
                }

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: deltaKg <= 0 ? "arrow.down.right" : "arrow.up.right")
                        Text(String(format: "%+.1f kg this week", deltaKg))
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(deltaKg <= 0 ? Color.green : Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (deltaKg <= 0 ? Color.green : Color.orange).opacity(0.15),
                        in: Capsule()
                    )
                }
            }

            Spacer()

            // Mini Sparkline Graph representation
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 4) {
                    Text("GOAL:")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(String(format: "%.1f kg", targetKg))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.foreground)
                }

                // Simulated sparkline waveform graph
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach([79.2, 79.0, 78.8, 78.9, 78.6, 78.5, 78.5], id: \.self) { val in
                        let heightRatio = CGFloat((val - 77.0) / 3.0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.tint.opacity(val == 78.5 ? 1.0 : 0.4))
                            .frame(width: 8, height: max(12, heightRatio * 40))
                    }
                }
                .padding(8)
                .background(theme.foreground.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text("Last 7 logs")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondaryForeground)
            }
        }
    }
}

// MARK: - Large Weight View

private struct LargeWeightWidgetView: View {
    let currentKg: Double
    let deltaKg: Double
    let targetKg: Double
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.tint)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("BODY WEIGHT EVOLUTION")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(theme.tint)
                        Text("Progress & Trend")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.foreground)
                    }
                }
                Spacer()
                Text(String(format: "Target: %.1f kg", targetKg))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.tint.opacity(0.18), in: Capsule())
                    .foregroundStyle(theme.tint)
            }

            // Stat Cards
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(String(format: "%.1f kg", currentKg))
                        .font(.title2.weight(.black))
                        .foregroundStyle(theme.foreground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(theme.foreground.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("7-DAY TREND")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(String(format: "%+.1f kg", deltaKg))
                        .font(.title2.weight(.black))
                        .foregroundStyle(deltaKg <= 0 ? Color.green : Color.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background((deltaKg <= 0 ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Expanded Sparkline Area
            VStack(alignment: .leading, spacing: 6) {
                Text("WEIGHT TREND (LAST 30 DAYS)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(theme.secondaryForeground)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach([80.1, 79.8, 79.5, 79.6, 79.2, 79.0, 78.8, 78.9, 78.6, 78.5], id: \.self) { val in
                        let heightRatio = CGFloat((val - 77.0) / 4.0)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.tint.opacity(val == 78.5 ? 1.0 : 0.45))
                                .frame(height: max(14, heightRatio * 50))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(12)
                .background(theme.foreground.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Spacer(minLength: 0)

            // CTA Footer
            HStack {
                Label("Log Weight Entry", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.tint)
                Spacer()
                Text("Tap to open")
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryForeground)
            }
        }
    }
}

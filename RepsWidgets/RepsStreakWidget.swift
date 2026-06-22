import WidgetKit
import SwiftUI
import AppIntents

struct RepsStreakEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuredBackgroundColor: WidgetColor
}

struct RepsStreakProvider: AppIntentTimelineProvider {
    typealias Entry = RepsStreakEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsStreakEntry {
        RepsStreakEntry(date: .now, snapshot: .empty, configuredBackgroundColor: .system)
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsStreakEntry {
        RepsStreakEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsStreakEntry> {
        let entry = RepsStreakEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct RepsStreakWidget: Widget {
    let kind = "RepsStreakWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsStreakProvider()) { entry in
            RepsStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("streak_and_consistency_widget_name")
        .description("streak_and_consistency_widget_description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

// MARK: - Widget View

private struct RepsStreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsStreakEntry

    var body: some View {
        let _ = RepsLocalization.use(entry.snapshot.preferredLanguage)
        let contentColor = WidgetColor.from(name: entry.snapshot.widgetAccentColorName)
        let backgroundColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetBackgroundColor: entry.configuredBackgroundColor
        )
        let theme = contentColor.theme
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
                Label(localizedFormat("days_count_format", streak), systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(localizedFormat("progress_percent_format", Int(completion * 100)))
                    .font(.caption)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .opacity(hasPlan ? 1 : 0.7)
            }

        case .accessoryInline:
            Text(localizedFormat("reps_streak_inline_format", streak, Int(completion * 100)))
                .widgetURL(URL(string: "reps://workout"))

        default:
            if family == .systemSmall {
                SmallStreakView(entry: entry, theme: theme, streak: streak, completion: completion, hasPlan: hasPlan)
                    .padding(14)
                    .repsWidgetBackground(backgroundColor)
                    .widgetURL(URL(string: "reps://workout"))
            } else {
                MediumStreakView(entry: entry, theme: theme, streak: streak, completion: completion, hasPlan: hasPlan)
                    .padding(14)
                    .repsWidgetBackground(backgroundColor)
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
                Text("streak")
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
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                Text(streak == 1 ? "day_singular" : "days_plural" as LocalizedStringKey)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.secondaryForeground)
            }
            .padding(.vertical, -4)

            Text(hasPlan ? "streak_completed_label" : "streak_no_plan_label" as LocalizedStringKey)
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
                    Text(streak == 1 ? "day_singular" : "days_plural" as LocalizedStringKey)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)
                }
            }

            // Right: stats
            VStack(alignment: .leading, spacing: 4) {
                Text("weekly_consistency")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(streak > 0 ? "excellent_consistency" : (hasPlan ? "start_your_streak_today" : "create_your_first_plan") as LocalizedStringKey)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 2)

                Group {
                    if hasPlan {
                        Text(localizedFormat("planned_workouts_completed_this_week_format", Int(completion * 100)))
                    } else {
                        Text("when_you_have_an_active_plan_you_ll_see_your_weekly_progress_here")
                    }
                }
                    .font(.system(size: 10))
                    .foregroundStyle(theme.secondaryForeground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 2)

                // Weekly bars: one per weekday, filled by weekly completion,
                // with today's column highlighted.
                let filledCount = Int((completion * 7).rounded())
                let todayIndex = (Calendar.current.component(.weekday, from: entry.date) + 5) % 7
                let inactiveFill = theme.isDarkBackground ? Color.white.opacity(0.18) : Color.primary.opacity(0.12)
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < filledCount ? theme.tint : inactiveFill)
                            .frame(height: 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(theme.foreground.opacity(index == todayIndex ? 0.9 : 0), lineWidth: 1.5)
                            )
                    }
                }
            }
        }
    }
}

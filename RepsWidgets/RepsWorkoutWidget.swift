import WidgetKit
import SwiftUI
import AppIntents

struct RepsWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuration: RepsWidgetConfigurationIntent
}

struct RepsWorkoutProvider: AppIntentTimelineProvider {
    typealias Entry = RepsWorkoutEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsWorkoutEntry {
        RepsWorkoutEntry(date: .now, snapshot: .empty, configuration: RepsWidgetConfigurationIntent())
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsWorkoutEntry {
        RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuration: configuration)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsWorkoutEntry> {
        let entry = RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuration: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

struct RepsWorkoutWidget: Widget {
    let kind = "RepsWorkoutWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsWorkoutProvider()) { entry in
            RepsWorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("Reps Entrenamiento")
        .description("Entreno activo, progreso, calorías y estado físico.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget View

private struct RepsWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry

    var body: some View {
        let resolvedColor: WidgetColor = {
            if entry.configuration.accentColor == .system {
                return WidgetColor.from(name: entry.snapshot.widgetAccentColorName)
            } else {
                return entry.configuration.accentColor
            }
        }()
        let theme = resolvedColor.theme

        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.progress) {
                Image(systemName: entry.snapshot.hasActiveWorkout ? "figure.strengthtraining.traditional" : "dumbbell")
            } currentValueLabel: {
                Text("\(entry.snapshot.completedSets)")
            }
            .gaugeStyle(.accessoryCircular)
            .widgetURL(URL(string: "reps://workout"))

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.hasActiveWorkout
                     ? (entry.snapshot.exerciseName ?? entry.snapshot.workoutTitle)
                     : (entry.snapshot.nextWorkoutDayName ?? "Reps"))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(entry.snapshot.hasActiveWorkout
                     ? "\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets) · \(entry.snapshot.elapsedText)"
                     : (entry.snapshot.nextWorkoutDayDescription ?? "Listo para entrenar"))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .widgetURL(URL(string: "reps://workout"))

        case .accessoryInline:
            Text(entry.snapshot.hasActiveWorkout
                 ? "\(entry.snapshot.workoutTitle) \(entry.snapshot.elapsedText)"
                 : "Reps: \(entry.snapshot.nextWorkoutDayName ?? "Listo")")
                .widgetURL(URL(string: "reps://workout"))

        default:
            Group {
                if entry.snapshot.hasActiveWorkout {
                    ActiveWorkoutView(entry: entry, theme: theme)
                } else {
                    InactiveWorkoutView(entry: entry, theme: theme)
                }
            }
            .padding(14)
            .containerBackground(for: .widget) {
                theme.background
            }
            .widgetURL(URL(string: "reps://workout"))
        }
    }
}

// MARK: - Active Workout View

private struct ActiveWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry
    let theme: WidgetTheme

    var body: some View {
        let restSeconds = entry.snapshot.restSeconds ?? 0
        let isResting = restSeconds > 0
        let restEndDate = entry.snapshot.updatedAt.addingTimeInterval(TimeInterval(restSeconds))

        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
            // Header
            HStack(alignment: .center) {
                Image(systemName: isResting ? "hourglass" : "figure.strengthtraining.traditional")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.tint)
                Spacer()
                Text(isResting ? "DESCANSO" : (entry.snapshot.isPaused ? "PAUSA" : "ACTIVO"))
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(isResting ? theme.foreground : (entry.snapshot.isPaused ? Color.orange : theme.badgeText))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isResting ? theme.badgeBackground : (entry.snapshot.isPaused ? Color.orange.opacity(0.15) : theme.badgeBackground), in: Capsule())
            }

            if isResting && restEndDate > Date() {
                Spacer(minLength: 0)

                // Prominent resting countdown timer
                VStack(alignment: .leading, spacing: 0) {
                    Text("TIEMPO DE DESCANSO")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)

                    Text(restEndDate, style: .timer)
                        .font(.system(size: family == .systemSmall ? 26 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(theme.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                // Next/Current exercise preview
                VStack(alignment: .leading, spacing: 0) {
                    Text("SIGUIENTE:")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(entry.snapshot.nextExerciseName ?? entry.snapshot.exerciseName ?? "Siguiente serie")
                        .font(.system(size: family == .systemSmall ? 10 : 12, weight: .bold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                // Workout title
                Text(entry.snapshot.workoutTitle)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // Current exercise
                if let exercise = entry.snapshot.exerciseName {
                    Label(exercise, systemImage: "dumbbell.fill")
                        .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                // Progress bar
                ProgressView(value: entry.snapshot.progress)
                    .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))

                // Timer row
                HStack {
                    Label(entry.snapshot.elapsedText, systemImage: "timer")
                    Spacer()
                    Label("\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets) series", systemImage: "checkmark.circle")
                }
                .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)

                // Medium only: extra stats
                if family == .systemMedium {
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        statPill(value: "\(entry.snapshot.volumeKg) kg", icon: "scalemass")
                        statPill(value: String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), icon: "waterbottle.fill")
                        statPill(value: "\(Int(entry.snapshot.activeEnergyKcal ?? 0)) kcal", icon: "flame.fill")
                    }
                }
            }
        }
    }

    private func statPill(value: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(theme.foreground)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Inactive Workout View

private struct InactiveWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry
    let theme: WidgetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.tint)
                Spacer()
                Text("PRÓXIMO")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.badgeText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.badgeBackground, in: Capsule())
            }

            // Next workout title
            Text(entry.snapshot.nextWorkoutDayName ?? "Entrenamiento")
                .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                .foregroundStyle(theme.foreground)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            // Subtitle
            Text(entry.snapshot.nextWorkoutDayDescription ?? "Sesión programada")
                .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(theme.secondaryForeground)

            Spacer(minLength: 0)

            // Stats footer
            if family == .systemMedium {
                HStack(spacing: 8) {
                    statPill(value: "\(entry.snapshot.streakDays) días", icon: "flame.fill", color: .orange)
                    statPill(value: "\(entry.snapshot.trainingBatteryLevel)%", icon: "battery.100percent", color: .green)
                    statPill(value: String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), icon: "waterbottle.fill", color: .blue)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(entry.snapshot.streakDays) días racha")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
                .font(.system(size: 9))
            }
        }
    }

    private func statPill(value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

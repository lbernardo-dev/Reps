import WidgetKit
import SwiftUI
import AppIntents

struct RepsWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
    let configuredBackgroundColor: WidgetColor
}

struct RepsWorkoutProvider: AppIntentTimelineProvider {
    typealias Entry = RepsWorkoutEntry
    typealias Intent = RepsWidgetConfigurationIntent

    func placeholder(in context: Context) -> RepsWorkoutEntry {
        RepsWorkoutEntry(date: .now, snapshot: .empty, configuredBackgroundColor: .system)
    }

    func snapshot(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> RepsWorkoutEntry {
        RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
    }

    func timeline(for configuration: RepsWidgetConfigurationIntent, in context: Context) async -> Timeline<RepsWorkoutEntry> {
        let entry = RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load(), configuredBackgroundColor: configuration.backgroundColor)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct RepsWorkoutWidget: Widget {
    let kind = "RepsWorkoutWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RepsWidgetConfigurationIntent.self, provider: RepsWorkoutProvider()) { entry in
            RepsWorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("reps_workout_widget_name")
        .description("reps_workout_widget_description")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

extension View {
    func repsWidgetBackground(_ color: WidgetColor) -> some View {
        ZStack {
            ContainerRelativeShape()
                .fill(color.widgetBackgroundFill)
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(color.widgetBackgroundFill)
        }
    }
}

// MARK: - Widget View

private struct RepsWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry

    var body: some View {
        let _ = RepsLocalization.use(entry.snapshot.preferredLanguage)
        let contentColor = WidgetColor.from(name: entry.snapshot.widgetAccentColorName)
        let backgroundColor = WidgetColor.resolved(
            appColorName: entry.snapshot.widgetAccentColorName,
            widgetBackgroundColor: entry.configuredBackgroundColor
        )
        let theme = contentColor.theme

        switch family {
        case .accessoryCircular:
            Group {
                if entry.snapshot.hasActiveWorkout,
                   entry.snapshot.isRouteWorkout {
                    Gauge(value: min(max((entry.snapshot.routeDistanceKm ?? 0) / 5.0, 0), 1)) {
                        Image(systemName: entry.snapshot.stateSystemImage)
                    } currentValueLabel: {
                        Text(routeDistanceText(compact: true))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                    .gaugeStyle(.accessoryCircular)
                } else if entry.snapshot.hasActiveWorkout,
                   let restEndDate = entry.snapshot.restEndDate {
                    Gauge(value: entry.snapshot.restProgress) {
                        Image(systemName: "hourglass")
                    } currentValueLabel: {
                        Text(restEndDate, style: .timer)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                    }
                    .gaugeStyle(.accessoryCircular)
                } else {
                    Gauge(value: entry.snapshot.progress) {
                        Image(systemName: entry.snapshot.hasActiveWorkout ? "figure.strengthtraining.traditional" : "dumbbell")
                    } currentValueLabel: {
                        Text("\(entry.snapshot.completedSets)")
                    }
                    .gaugeStyle(.accessoryCircular)
                }
            }
            .widgetURL(URL(string: "reps://workout"))

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                if entry.snapshot.hasActiveWorkout {
                    Label(entry.snapshot.stateLabel, systemImage: entry.snapshot.stateSystemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(entry.snapshot.isPaused ? .orange : .primary)
                        .lineLimit(1)
                    Text(entry.snapshot.exerciseName ?? entry.snapshot.workoutTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        if entry.snapshot.isRouteWorkout {
                            Label(routeDistanceText(), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                            Text(routePaceText())
                        } else if let restEndDate = entry.snapshot.restEndDate {
                            Label {
                                Text(restEndDate, style: .timer)
                            } icon: {
                                Image(systemName: "hourglass")
                            }
                        } else {
                            Label {
                                elapsedTimerText()
                            } icon: {
                                Image(systemName: "timer")
                            }
                        }
                        if !entry.snapshot.isRouteWorkout {
                            Text("\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets)")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                } else {
                    Text(entry.snapshot.nextWorkoutDayName ?? localizedKey("no_active_plan"))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(entry.snapshot.nextWorkoutDayDescription ?? localizedKey("create_or_schedule_your_first_session"))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .widgetURL(URL(string: "reps://workout"))

        case .accessoryInline:
            Group {
                if entry.snapshot.hasActiveWorkout {
                if entry.snapshot.isRouteWorkout {
                    Text("\(entry.snapshot.workoutTitle) \(routeDistanceText()) \(routePaceText())")
                } else {
                    elapsedTimerText(prefix: entry.snapshot.workoutTitle)
                }
                } else {
                    Text(localizedFormat("reps_plan_format", entry.snapshot.nextWorkoutDayName ?? localizedString("no_active_plan")))
                }
            }
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
            .repsWidgetBackground(backgroundColor)
            .widgetURL(URL(string: "reps://workout"))
        }
    }

    @ViewBuilder
    private func elapsedTimerText(prefix: String? = nil) -> some View {
        if entry.snapshot.isPaused {
            Text([prefix, entry.snapshot.elapsedText].compactMap(\.self).joined(separator: " "))
        } else if let prefix {
            Text(prefix) + Text(" ") + Text(entry.snapshot.elapsedStartDate, style: .timer)
        } else {
            Text(entry.snapshot.elapsedStartDate, style: .timer)
        }
    }

    private func routeDistanceText(compact: Bool = false) -> String {
        SharedWorkoutSnapshot.routeDistanceText(entry.snapshot.routeDistanceKm, compact: compact)
    }

    private func routePaceText() -> String {
        entry.snapshot.routePaceText
    }
}

private extension SharedWorkoutSnapshot {
    var stateLabel: LocalizedStringKey {
        if isRouteWorkout {
            if isPaused { return "PAUSA" }
            return isOutdoorRoute == false ? "CINTA" : "RUTA"
        }
        if restEndDate != nil {
            return "DESCANSO"
        }
        return isPaused ? "PAUSA" : "ACTIVO"
    }

    var stateSystemImage: String {
        if isRouteWorkout {
            if isPaused { return "pause.fill" }
            return isOutdoorRoute == false ? "figure.run.treadmill" : "figure.walk"
        }
        if restEndDate != nil {
            return "hourglass"
        }
        return isPaused ? "pause.fill" : "figure.strengthtraining.traditional"
    }

    var currentSetText: String? {
        guard currentSetWeightKg != nil || currentSetReps != nil else {
            return nil
        }

        let weight = currentSetWeightKg.map { value in
            value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(value)) kg"
                : String(format: "%.1f kg", value)
        }
        let reps = currentSetReps.map { "\($0) reps" }
        return [weight, reps].compactMap(\.self).joined(separator: " x ")
    }

    var hasUpcomingWorkout: Bool {
        nextWorkoutDayName != nil
    }
}

// MARK: - Active Workout View

private struct ActiveWorkoutView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry
    let theme: WidgetTheme

    var body: some View {
        let isResting = entry.snapshot.restEndDate != nil

        if entry.snapshot.isRouteWorkout {
            routeActiveBody()
        } else if family == .systemMedium {
            mediumActiveBody(isResting: isResting)
        } else {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 4 : 8) {
            // Header
            HStack(alignment: .center) {
                Image(systemName: entry.snapshot.stateSystemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.tint)
                Text(entry.snapshot.stateLabel)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(isResting ? theme.foreground : (entry.snapshot.isPaused ? Color.orange : theme.badgeText))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isResting ? theme.badgeBackground : (entry.snapshot.isPaused ? Color.orange.opacity(0.15) : theme.badgeBackground), in: Capsule())
                Spacer()
                Text("\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets)")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.badgeText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.badgeBackground, in: Capsule())
            }

            if let restEndDate = entry.snapshot.restEndDate {
                Spacer(minLength: 0)

                // Prominent resting countdown timer
                VStack(alignment: .leading, spacing: 3) {
                    Text(restEndDate, style: .timer)
                        .font(.system(size: family == .systemSmall ? 26 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(theme.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProgressView(value: entry.snapshot.restProgress)
                        .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))
                }

                Spacer(minLength: 0)

                // Next/Current exercise preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedKey("widget_next_label"))
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                    Text(entry.snapshot.nextExerciseName ?? entry.snapshot.exerciseName ?? localizedKey("next_set"))
                        .font(.system(size: family == .systemSmall ? 10 : 12, weight: .bold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if family == .systemMedium {
                    HStack(spacing: 8) {
                        metricPill(title: "session", icon: "timer") { liveTimerValue() }
                        metricPill(title: "volume", value: "\(entry.snapshot.volumeKg) kg", icon: "scalemass")
                        metricPill(title: "remaining", value: entry.snapshot.remainingText, icon: "hourglass.bottomhalf.filled")
                    }
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
                    VStack(alignment: .leading, spacing: 2) {
                        Label(exercise, systemImage: "dumbbell.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 5) {
                            if let exerciseIndex = entry.snapshot.exerciseIndex,
                               let totalExercises = entry.snapshot.totalExercises {
                                Text(localizedFormat("exercises_fraction_format", exerciseIndex, totalExercises))
                            }
                            if let currentSetText = entry.snapshot.currentSetText {
                                Text(currentSetText)
                            }
                        }
                        .font(.system(size: family == .systemSmall ? 8 : 9, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    }
                    .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryForeground)
                }

                // Progress bar
                ProgressView(value: entry.snapshot.progress)
                    .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))

                // Timer row
                HStack {
                    Label {
                        if entry.snapshot.isPaused {
                            Text(entry.snapshot.elapsedText)
                        } else {
                            Text(entry.snapshot.elapsedStartDate, style: .timer)
                        }
                    } icon: {
                        Image(systemName: "timer")
                    }
                    Spacer()
                    Label(localizedFormat("sets_fraction_format", entry.snapshot.completedSets, entry.snapshot.totalSets), systemImage: "checkmark.circle")
                }
                .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                .foregroundStyle(theme.secondaryForeground)

                // Medium only: extra stats
                if family == .systemMedium {
                    Spacer(minLength: 0)
                    if let current = entry.snapshot.currentExerciseCompletedSets,
                       let total = entry.snapshot.currentExerciseTotalSets,
                       total > 0 {
                        HStack(spacing: 6) {
                            Text("exercise_2")
                            ProgressView(value: Double(current) / Double(total))
                                .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))
                            Text("\(current)/\(total)")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)
                    }

                    HStack(spacing: 6) {
                        metricPill(title: "metric_remaining", value: entry.snapshot.remainingText, icon: "hourglass")
                        metricPill(title: "volume_label", value: "\(entry.snapshot.volumeKg) kg", icon: "scalemass")
                        metricPill(title: "metric_water", value: String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), icon: "waterbottle.fill")
                    }
                }
            }
        }
        }
    }

    private func routeActiveBody() -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 8) {
            HStack(alignment: .center) {
                Image(systemName: entry.snapshot.stateSystemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.tint)
                Text(entry.snapshot.stateLabel)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(entry.snapshot.isPaused ? Color.orange : theme.badgeText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.snapshot.isPaused ? Color.orange.opacity(0.15) : theme.badgeBackground, in: Capsule())
                Spacer(minLength: 0)
                if entry.snapshot.isPaused {
                    Text(entry.snapshot.elapsedText)
                } else {
                    Text(entry.snapshot.elapsedStartDate, style: .timer)
                }
            }
            .font(.system(size: 10, weight: .black, design: .rounded))

            Text(entry.snapshot.workoutTitle)
                .font(.system(size: family == .systemSmall ? 13 : 16, weight: .black, design: .rounded))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(routeDistanceText())
                    .font(.system(size: family == .systemSmall ? 20 : 28, weight: .black, design: .rounded))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                metricPill(title: "pace_label", value: routePaceText(), icon: "speedometer")
                if family == .systemMedium {
                    metricPill(title: "pulse_label", value: entry.snapshot.heartRate.map { "\(Int($0)) lpm" } ?? "--", icon: "heart.fill")
                    metricPill(title: "Kcal", value: entry.snapshot.activeEnergyKcal.map { "\(Int($0))" } ?? "--", icon: "flame.fill")
                } else {
                    metricPill(title: "steps_label", value: entry.snapshot.routeSteps.map { "\(Int($0))" } ?? "--", icon: "shoeprints.fill")
                }
            }

            if family == .systemMedium {
                workoutControlButtons(includesCompleteSet: false)
            }
        }
    }

    private func mediumActiveBody(isResting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: entry.snapshot.stateSystemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(theme.tint)
                    .frame(width: 24, height: 24)
                    .background(theme.badgeBackground, in: Circle())

                Text(entry.snapshot.stateLabel)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(isResting ? theme.foreground : (entry.snapshot.isPaused ? Color.orange : theme.badgeText))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isResting ? theme.badgeBackground : (entry.snapshot.isPaused ? Color.orange.opacity(0.15) : theme.badgeBackground), in: Capsule())

                Spacer(minLength: 0)

                compactMetric(icon: "checkmark.circle.fill", value: "\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets)")
            }

            Text(entry.snapshot.workoutTitle)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let restEndDate = entry.snapshot.restEndDate {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(restEndDate, style: .timer)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(theme.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(entry.snapshot.nextExerciseName ?? entry.snapshot.exerciseName ?? localizedString("next_set"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                ProgressView(value: entry.snapshot.restProgress)
                    .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.snapshot.exerciseName ?? localizedKey("widget_current_exercise"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.secondaryForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(currentExerciseDetailText)
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(theme.secondaryForeground.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 0)

                    if entry.snapshot.isPaused {
                        Text(entry.snapshot.elapsedText)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(theme.foreground)
                    } else {
                        Text(entry.snapshot.elapsedStartDate, style: .timer)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(theme.foreground)
                    }
                }

                ProgressView(value: entry.snapshot.progress)
                    .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))
            }

            HStack(spacing: 6) {
                metricPill(title: "Restante", value: entry.snapshot.remainingText, icon: "hourglass")
                metricPill(title: "volume_label", value: "\(entry.snapshot.volumeKg) kg", icon: "scalemass")
                metricPill(title: "Agua", value: String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), icon: "waterbottle.fill")
            }

            workoutControlButtons(includesCompleteSet: !isResting)
        }
    }

    private func routeDistanceText() -> String {
        entry.snapshot.routeDistanceText
    }

    private func routePaceText() -> String {
        entry.snapshot.routePaceText
    }

    private var currentExerciseDetailText: String {
        let exerciseProgress: String? = {
            guard let index = entry.snapshot.exerciseIndex,
                  let total = entry.snapshot.totalExercises else {
                return nil
            }
            return localizedFormat("exercises_fraction_format", index, total)
        }()

        return [exerciseProgress, entry.snapshot.currentSetText]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    private func compactMetric(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(theme.badgeText)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(theme.badgeBackground, in: Capsule())
    }

    @ViewBuilder
    private func liveTimerValue() -> some View {
        if entry.snapshot.isPaused {
            Text(entry.snapshot.elapsedText)
        } else {
            Text(entry.snapshot.elapsedStartDate, style: .timer)
        }
    }

    private func metricPill(title: String, value: String, icon: String) -> some View {
        metricPill(title: title, icon: icon) { Text(value) }
    }

    private func metricPill<Value: View>(
        title: String,
        icon: String,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 0) {
                Text(localizedKey(title))
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(theme.secondaryForeground)
                value()
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(theme.foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func workoutControlButtons(includesCompleteSet: Bool) -> some View {
        HStack(spacing: 6) {
            if includesCompleteSet {
                Button(intent: CompleteSetLiveActivityIntent()) {
                    Label("set_done", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.tint)
            }

            Button(intent: ToggleWorkoutPauseLiveActivityIntent()) {
                Label(
                    entry.snapshot.isPaused ? "resume_label" : "pause_label",
                    systemImage: entry.snapshot.isPaused ? "play.fill" : "pause.fill"
                )
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(theme.tint)
        }
        .controlSize(.small)
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
                Text(entry.snapshot.hasUpcomingWorkout ? "next_uppercase" : "no_plan_uppercase" as LocalizedStringKey)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(theme.badgeText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.badgeBackground, in: Capsule())
            }

            // Next workout title
            Text(entry.snapshot.nextWorkoutDayName ?? localizedKey("no_active_plan"))
                .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                .foregroundStyle(theme.foreground)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            // Subtitle
            Text(entry.snapshot.nextWorkoutDayDescription ?? localizedKey("create_routine_or_schedule_session"))
                .font(.system(size: family == .systemSmall ? 9 : 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(theme.secondaryForeground)

            Spacer(minLength: 0)

            // Stats footer
            if family == .systemMedium {
                HStack(spacing: 8) {
                    statPill(value: localizedFormat("days_count_format", entry.snapshot.streakDays), icon: "flame.fill", color: .orange)
                    statPill(value: "\(entry.snapshot.trainingBatteryLevel)%", icon: "battery.100percent", color: theme.tint)
                    statPill(value: String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), icon: "waterbottle.fill", color: theme.secondaryForeground)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text(localizedFormat("streak_days_count_format", entry.snapshot.streakDays))
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

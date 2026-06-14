import ActivityKit
import WidgetKit
import SwiftUI

struct RepsWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepsWorkoutActivityAttributes.self) { context in
            let _ = RepsLocalization.use(context.state.snapshot.preferredLanguage)
            let theme = WidgetColor.from(name: context.state.snapshot.widgetAccentColorName).theme
            liveActivityBody(context.state.snapshot, theme: theme, isStale: context.isStale)
                .activityBackgroundTint(theme.isDarkBackground ? Color.black : Color.white)
                .activitySystemActionForegroundColor(theme.tint)
        } dynamicIsland: { context in
            let snapshot = context.state.snapshot
            let _ = RepsLocalization.use(snapshot.preferredLanguage)
            let theme = WidgetColor.from(name: snapshot.widgetAccentColorName).theme
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandMetric(snapshot.isRouteWorkout ? "distance" : "session", icon: snapshot.isRouteWorkout ? "point.topleft.down.curvedto.point.bottomright.up" : "timer", tint: theme.tint) {
                        if snapshot.isRouteWorkout {
                            Text(routeDistanceText(snapshot))
                        } else {
                            elapsedTimerText(snapshot)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandMetric(snapshot.isRouteWorkout ? "pace" : "sets", icon: snapshot.isRouteWorkout ? "speedometer" : "checkmark.circle", tint: theme.tint) {
                        if snapshot.isRouteWorkout {
                            Text(routePaceText(snapshot))
                        } else {
                            Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    islandExpandedBottom(snapshot, theme: theme, isStale: context.isStale)
                }
            } compactLeading: {
                Image(systemName: compactLeadingSystemImage(snapshot))
                    .foregroundStyle(theme.tint)
            } compactTrailing: {
                compactTrailingView(snapshot)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: snapshot.isRouteWorkout ? "figure.walk" : "dumbbell.fill")
                    .foregroundStyle(theme.tint)
            }
        }
    }

    @ViewBuilder
    private func liveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        if snapshot.isRouteWorkout {
            routeLiveActivityBody(snapshot, theme: theme, isStale: isStale)
        } else {
            strengthLiveActivityBody(snapshot, theme: theme, isStale: isStale)
        }
    }

    private func routeLiveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.workoutTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    Group {
                        if snapshot.isPaused, snapshot.isOutdoorRoute == false {
                            Text("cinta_pausada")
                        } else if snapshot.isPaused {
                            Text("ruta_pausada")
                        } else {
                            Text(verbatim: routeSubtitle(snapshot))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryForeground)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                statusBadge(snapshot, theme: theme, isStale: isStale)
            }

            HStack(spacing: 10) {
                compactMetric("Tiempo", icon: "timer", theme: theme) {
                    elapsedTimerText(snapshot)
                }
                compactMetric("Distancia", icon: "point.topleft.down.curvedto.point.bottomright.up", theme: theme) {
                    Text(routeDistanceText(snapshot))
                }
                compactMetric("Ritmo", icon: "speedometer", theme: theme) {
                    Text(routePaceText(snapshot))
                }
            }

            HStack(spacing: 10) {
                compactMetric("Pulso", icon: "heart.fill", theme: theme) {
                    Text(snapshot.heartRate.map { localizedFormat("heart_rate_bpm_format", Int($0)) } ?? "--")
                }
                compactMetric("Kcal", icon: "flame.fill", theme: theme) {
                    Text(snapshot.activeEnergyKcal.map { "\(Int($0))" } ?? "--")
                }
                compactMetric("Pasos", icon: "shoeprints.fill", theme: theme) {
                    Text(snapshot.routeSteps.map { "\(Int($0))" } ?? "--")
                }
            }

            actionButtons(snapshot, theme: theme, includesCompleteSet: false)
        }
        .padding()
        .background(theme.background)
    }

    private func strengthLiveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.workoutTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                    Text(snapshot.exerciseName ?? snapshot.summary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                statusBadge(snapshot, theme: theme, isStale: isStale)
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(theme.isDarkBackground ? Color.white.opacity(0.18) : Color.primary.opacity(0.12), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: snapshot.progress)
                        .stroke(theme.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(snapshot.progress * 100))%")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 7) {
                    ProgressView(value: snapshot.progress)
                        .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: theme.isDarkBackground))

                    HStack(spacing: 6) {
                        compactMetric("Tiempo", icon: "timer", theme: theme) {
                            elapsedTimerText(snapshot)
                        }
                        compactMetric("Restante", icon: "hourglass", theme: theme) {
                            Text(snapshot.restEndDate == nil ? snapshot.remainingText : snapshot.restText)
                        }
                        compactMetric("Volumen", icon: "scalemass", theme: theme) {
                            Text("\(snapshot.volumeKg) kg")
                        }
                    }
                }
            }

            if let nextExercise = snapshot.nextExerciseName ?? snapshot.exerciseName {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.restEndDate == nil ? "dumbbell.fill" : "arrow.forward.circle.fill")
                        .foregroundStyle(theme.tint)
                    Group {
                        if snapshot.restEndDate == nil {
                            Text(verbatim: nextExercise)
                        } else {
                            Text(localizedFormat("next_value_format", nextExercise))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryForeground)
                    .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(localizedFormat("sets_fraction_format", snapshot.completedSets, max(snapshot.totalSets, 1)))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(theme.badgeText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(theme.badgeBackground, in: Capsule())
                }
            }

            actionButtons(snapshot, theme: theme, includesCompleteSet: true)
        }
        .padding()
        .background(theme.background)
    }

    private func actionButtons(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, includesCompleteSet: Bool) -> some View {
        let pauseTitle: LocalizedStringKey = snapshot.isPaused ? "Reanudar" : "Pausa"
        return HStack(spacing: 8) {
            Button(intent: ToggleWorkoutPauseLiveActivityIntent()) {
                Label(pauseTitle, systemImage: snapshot.isPaused ? "play.fill" : "pause.fill")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(theme.tint)

            if includesCompleteSet {
                Button(intent: CompleteSetLiveActivityIntent()) {
                    Label("set_done", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.tint)
            }
        }
        .controlSize(.small)
    }

    private func islandExpandedBottom(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(snapshot.workoutTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(snapshot.isRouteWorkout ? routeSubtitle(snapshot) : (snapshot.exerciseName ?? snapshot.summary))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                statusBadge(snapshot, theme: theme, isStale: isStale)
                    .labelStyle(.titleAndIcon)
            }

            HStack(spacing: 6) {
                Button(intent: ToggleWorkoutPauseLiveActivityIntent()) {
                    Image(systemName: snapshot.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(theme.tint)

                if snapshot.isRouteWorkout {
                    islandCompactMetric(icon: "timer", value: snapshot.isPaused ? snapshot.elapsedText : localizedString("en_curso"), theme: theme)
                    islandCompactMetric(icon: "point.topleft.down.curvedto.point.bottomright.up", value: routeDistanceText(snapshot), theme: theme)
                    islandCompactMetric(icon: "speedometer", value: routePaceText(snapshot), theme: theme)
                } else {
                    islandCompactMetric(icon: "hourglass", value: snapshot.restEndDate == nil ? snapshot.remainingText : snapshot.restText, theme: theme)
                    islandCompactMetric(icon: "dumbbell.fill", value: "\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))", theme: theme)

                    Button(intent: CompleteSetLiveActivityIntent()) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(theme.tint)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 7)
        .frame(maxHeight: 92, alignment: .top)
    }

    private func statusBadge(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        let title: LocalizedStringKey = isStale ? "ACTUALIZANDO" : statusTitle(snapshot)
        let icon = isStale ? "arrow.triangle.2.circlepath" : compactLeadingSystemImage(snapshot)

        return Label(localizedKey(title), systemImage: icon)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(theme.badgeText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.badgeBackground, in: Capsule())
    }

    private func compactMetric<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        theme: WidgetTheme,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(localizedKey(title), systemImage: icon)
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(theme.secondaryForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            value()
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func islandMetric<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        tint: Color,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(localizedKey(title), systemImage: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
            value()
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func islandCompactMetric(icon: String, value: String, theme: WidgetTheme) -> some View {
        Label(value, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(theme.secondaryForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(theme.badgeBackground, in: Capsule())
    }

    @ViewBuilder
    private func elapsedTimerText(_ snapshot: SharedWorkoutSnapshot) -> some View {
        if snapshot.isPaused {
            Text(snapshot.elapsedText)
        } else {
            Text(snapshot.elapsedStartDate, style: .timer)
        }
    }

    private func compactLeadingSystemImage(_ snapshot: SharedWorkoutSnapshot) -> String {
        if snapshot.isRouteWorkout {
            if snapshot.isPaused { return "pause.fill" }
            return snapshot.isOutdoorRoute == false ? "figure.run.treadmill" : "figure.walk"
        }
        if snapshot.restEndDate != nil {
            return "hourglass"
        }
        return snapshot.isPaused ? "pause.fill" : "figure.strengthtraining.traditional"
    }

    @ViewBuilder
    private func compactTrailingView(_ snapshot: SharedWorkoutSnapshot) -> some View {
        if snapshot.isRouteWorkout {
            Text(routeDistanceText(snapshot))
        } else {
            if let restEndDate = snapshot.restEndDate {
                Text(restEndDate, style: .timer)
            } else {
                Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
            }
        }
    }

    private func statusTitle(_ snapshot: SharedWorkoutSnapshot) -> LocalizedStringKey {
        if snapshot.isRouteWorkout {
            if snapshot.isPaused { return "PAUSA" }
            return snapshot.isOutdoorRoute == false ? "CINTA" : "RUTA"
        }
        if snapshot.restEndDate != nil {
            return "DESCANSO"
        }
        return snapshot.isPaused ? "PAUSA" : "ACTIVO"
    }

    private func routeDistanceText(_ snapshot: SharedWorkoutSnapshot) -> String {
        guard let distance = snapshot.routeDistanceKm, distance > 0 else {
            return "0.00 km"
        }
        return String(format: "%.2f km", distance)
    }

    private func routePaceText(_ snapshot: SharedWorkoutSnapshot) -> String {
        guard let pace = snapshot.routePaceSecondsPerKm, pace.isFinite, pace > 0 else {
            return "--"
        }
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))/km"
    }

    private func routeSubtitle(_ snapshot: SharedWorkoutSnapshot) -> String {
        [routeDistanceText(snapshot), routePaceText(snapshot)]
            .filter { $0 != "--" }
            .joined(separator: " · ")
    }
}

struct RepsProgressStyle: ProgressViewStyle {
    var tintColor: Color = Color(red: 0.28, green: 0.86, blue: 0.38)
    var isDarkBackground: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0.0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDarkBackground ? Color.white.opacity(0.2) : Color.primary.opacity(0.12))
                    .frame(height: 6)
                Capsule()
                    .fill(tintColor)
                    .frame(width: geo.size.width * CGFloat(fraction), height: 6)
            }
        }
        .frame(height: 6)
    }
}

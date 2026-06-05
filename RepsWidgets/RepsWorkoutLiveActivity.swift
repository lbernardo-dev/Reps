import ActivityKit
import WidgetKit
import SwiftUI

struct RepsWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepsWorkoutActivityAttributes.self) { context in
            let theme = WidgetColor.from(name: context.state.snapshot.widgetAccentColorName).theme
            liveActivityBody(context.state.snapshot, theme: theme, isStale: context.isStale)
                .activityBackgroundTint(theme.isDarkBackground ? Color.black : Color.white)
                .activitySystemActionForegroundColor(theme.tint)
        } dynamicIsland: { context in
            let snapshot = context.state.snapshot
            let theme = WidgetColor.from(name: snapshot.widgetAccentColorName).theme
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandMetric("Sesión", icon: "timer", tint: theme.tint) {
                        elapsedTimerText(snapshot)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandMetric("Series", icon: "checkmark.circle", tint: theme.tint) {
                        Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
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
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(theme.tint)
            }
        }
    }

    @ViewBuilder
    private func liveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
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
                    Text(snapshot.restEndDate == nil ? nextExercise : "Siguiente: \(nextExercise)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1)) series")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(theme.badgeText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(theme.badgeBackground, in: Capsule())
                }
            }
        }
        .padding()
        .background(theme.background)
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
                    Text(snapshot.exerciseName ?? snapshot.summary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                statusBadge(snapshot, theme: theme, isStale: isStale)
                    .labelStyle(.titleAndIcon)
            }

            ProgressView(value: snapshot.progress)
                .progressViewStyle(RepsProgressStyle(tintColor: theme.tint, isDarkBackground: true))

            HStack(spacing: 6) {
                islandCompactMetric(icon: "hourglass", value: snapshot.restEndDate == nil ? snapshot.remainingText : snapshot.restText, theme: theme)
                islandCompactMetric(icon: "scalemass", value: "\(snapshot.volumeKg) kg", theme: theme)
                islandCompactMetric(icon: "dumbbell.fill", value: "\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))", theme: theme)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 7)
        .frame(maxHeight: 92, alignment: .top)
    }

    private func statusBadge(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        let title = isStale ? "ACTUALIZANDO" : statusTitle(snapshot)
        let icon = isStale ? "arrow.triangle.2.circlepath" : compactLeadingSystemImage(snapshot)

        return Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(theme.badgeText)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.badgeBackground, in: Capsule())
    }

    private func compactMetric<Content: View>(
        _ title: String,
        icon: String,
        theme: WidgetTheme,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(title, systemImage: icon)
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
        _ title: String,
        icon: String,
        tint: Color,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(title, systemImage: icon)
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
        if snapshot.restEndDate != nil {
            return "hourglass"
        }
        return snapshot.isPaused ? "pause.fill" : "figure.strengthtraining.traditional"
    }

    @ViewBuilder
    private func compactTrailingView(_ snapshot: SharedWorkoutSnapshot) -> some View {
        if let restEndDate = snapshot.restEndDate {
            Text(restEndDate, style: .timer)
        } else {
            Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
        }
    }

    private func statusTitle(_ snapshot: SharedWorkoutSnapshot) -> String {
        if snapshot.restEndDate != nil {
            return "DESCANSO"
        }
        return snapshot.isPaused ? "PAUSA" : "ACTIVO"
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

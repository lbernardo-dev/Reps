import ActivityKit
import WidgetKit
import SwiftUI

struct RepsWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepsWorkoutActivityAttributes.self) { context in
            let tint = WidgetColor.from(name: context.state.snapshot.widgetAccentColorName).theme.tint
            liveActivityBody(context.state.snapshot, tint: tint)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(tint)
        } dynamicIsland: { context in
            let snapshot = context.state.snapshot
            let tint = WidgetColor.from(name: snapshot.widgetAccentColorName).theme.tint
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        elapsedTimerText(snapshot)
                    } icon: {
                        Image(systemName: "timer")
                    }
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(snapshot.completedSets)/\(snapshot.totalSets)", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    liveActivityBody(snapshot, tint: tint)
                }
            } compactLeading: {
                Image(systemName: compactLeadingSystemImage(snapshot))
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(compactTrailingText(snapshot))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(tint)
            }
        }
    }

    @ViewBuilder
    private func liveActivityBody(_ snapshot: SharedWorkoutSnapshot, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.workoutTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(snapshot.isPaused ? "Pausado" : "En curso")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.isPaused ? .orange : tint)
            }
            ProgressView(value: snapshot.progress)
                .progressViewStyle(RepsProgressStyle(tintColor: tint))
            if let exerciseName = snapshot.exerciseName {
                HStack {
                    Label(exerciseName, systemImage: "dumbbell.fill")
                        .lineLimit(1)
                    Spacer()
                    if let current = snapshot.currentExerciseCompletedSets,
                       let total = snapshot.currentExerciseTotalSets {
                        Text("\(current)/\(total)")
                    }
                }
                .font(.caption.weight(.semibold))
            }
            HStack {
                Label {
                    elapsedTimerText(snapshot)
                } icon: {
                    Image(systemName: "timer")
                }
                Spacer()
                Label(snapshot.remainingText, systemImage: "hourglass")
                Spacer()
                Label(String(format: "%.1f L", snapshot.waterLiters ?? 0), systemImage: "waterbottle.fill")
            }
            .font(.caption.weight(.semibold))
        }
        .padding()
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

    private func compactTrailingText(_ snapshot: SharedWorkoutSnapshot) -> String {
        if let restSeconds = snapshot.restSeconds, restSeconds > 0 {
            return shortDurationText(restSeconds)
        }
        return "\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))"
    }

    private func shortDurationText(_ seconds: Int) -> String {
        let seconds = max(seconds, 0)
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m"
    }
}

struct RepsProgressStyle: ProgressViewStyle {
    var tintColor: Color = .green
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

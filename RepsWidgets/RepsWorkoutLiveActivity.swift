import ActivityKit
import WidgetKit
import SwiftUI

struct RepsWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepsWorkoutActivityAttributes.self) { context in
            liveActivityBody(context.state.snapshot)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.snapshot.elapsedText, systemImage: "timer")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label("\(context.state.snapshot.completedSets)/\(context.state.snapshot.totalSets)", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    liveActivityBody(context.state.snapshot)
                }
            } compactLeading: {
                Image(systemName: context.state.snapshot.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
            } compactTrailing: {
                Text(context.state.snapshot.elapsedText)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "dumbbell.fill")
            }
        }
    }

    @ViewBuilder
    private func liveActivityBody(_ snapshot: SharedWorkoutSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.workoutTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(snapshot.isPaused ? "Pausado" : "En curso")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.isPaused ? .orange : .green)
            }
            ProgressView(value: snapshot.progress)
                .tint(.green)
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
                Label(snapshot.elapsedText, systemImage: "timer")
                Spacer()
                Label(snapshot.remainingText, systemImage: "hourglass")
                Spacer()
                Label(String(format: "%.1f L", snapshot.waterLiters ?? 0), systemImage: "waterbottle.fill")
            }
            .font(.caption.weight(.semibold))
        }
        .padding()
    }
}

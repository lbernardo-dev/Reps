import SwiftUI

struct RecommendedWorkoutCard: View {
    let workout: WorkoutDay
    let batteryLevel: Int
    let language: String
    let onStart: () -> Void

    private var batteryColor: Color {
        batteryLevel >= 80 ? PulseTheme.recovery : batteryLevel >= 55 ? PulseTheme.accent : PulseTheme.warning
    }

    private var batteryLabel: LocalizedStringKey {
        batteryLevel >= 80 ? "recommended_battery_charged" : batteryLevel >= 55 ? "recommended_battery_steady" : "recommended_battery_low"
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(batteryColor)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("recommended_workout_title")
                            .font(.headline)
                            .lineLimit(1)
                        Text(batteryLabel)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(workout.durationMinutes) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PulseTheme.grouped, in: Capsule())
                        .fixedSize()
                }

                if !workout.subtitle.isEmpty {
                    Text(workout.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if !workout.exercises.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(workout.exercises.prefix(4)) { we in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(PulseTheme.accent.opacity(0.15))
                                    .frame(width: 8, height: 8)
                                Text(RepsText.exerciseName(we.exercise.name, language: language))
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(we.targetSets)×\(we.repRange)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.subheadline.weight(.bold))
                        Text("recommended_workout_cta")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

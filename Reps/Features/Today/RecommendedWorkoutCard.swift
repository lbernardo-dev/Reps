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
        GlassMetricCard(domain: .strength, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(batteryColor))
                        .frame(width: 48, height: 48)
                        .background(batteryColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("recommended_workout_title")
                            .font(.title3.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(batteryLabel)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(workout.durationMinutes) min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PulseTheme.grouped.opacity(0.78), in: Capsule())
                            .fixedSize()

                        Button(action: onStart) {
                            Image(systemName: "play.fill")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(.black)
                                .frame(width: 42, height: 42)
                                .background(PulseTheme.fitActionGradient, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("recommended_workout_cta")
                    }
                }

                if !workout.subtitle.isEmpty {
                    Text(workout.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if !workout.exercises.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(workout.exercises.prefix(4)) { we in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .frame(width: 20, height: 20)
                                    .background(PulseTheme.accent.opacity(0.12), in: Circle())
                                Text(RepsText.exerciseName(we.exercise.name, language: language))
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                                Spacer()
                                Text("\(we.targetSets)×\(we.repRange)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .padding(9)
                            .background(PulseTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                Button(action: onStart) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.black))
                        Text("recommended_workout_cta")
                            .font(.caption.weight(.black))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.black))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(PulseTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

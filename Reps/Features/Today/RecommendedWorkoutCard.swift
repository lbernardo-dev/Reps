import SwiftUI

struct RecommendedWorkoutCard: View {
    let workout: WorkoutDay
    let batteryLevel: Int
    let language: String
    let experience: UserProfile.Experience
    let mainGoal: UserProfile.MainGoal
    let weeklyTrainingDays: Int
    let onStart: () -> Void

    @State private var showDetail = false

    private static let projectionWeeks = 8

    private var batteryColor: Color {
        batteryLevel >= 80 ? PulseTheme.recovery : batteryLevel >= 55 ? PulseTheme.accent : PulseTheme.warning
    }

    private var batteryLabel: String {
        batteryLevel >= 80 ? "recommended_battery_charged" : batteryLevel >= 55 ? "recommended_battery_steady" : "recommended_battery_low"
    }

    private var projectionPoints: [FitnessMetrics.PlanProjectionPoint] {
        FitnessMetrics.planProgressionProjection(
            for: workout,
            experience: experience,
            mainGoal: mainGoal,
            weeklyTrainingDays: weeklyTrainingDays,
            weeks: Self.projectionWeeks
        )
    }

    private var projectionCaption: String {
        let gain = projectionPoints.last?.percentGain ?? 0
        return String(format: localizedString("recommended_projection_caption_fmt"), String(format: "%+.0f%%", gain), Self.projectionWeeks)
    }

    var body: some View {
        GlassMetricCard(domain: .strength, contentPadding: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    PulseIconBadge(systemImage: "bolt.fill", tint: batteryColor, size: 48, radius: PulseTheme.mediumRadius, isFilled: true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("recommended_workout_title")
                            .font(.title3.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text(localizedKey(batteryLabel))
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
                            .background(PulseTheme.grouped, in: Capsule())
                            .fixedSize()

                        Button(action: onStart) {
                            Image(systemName: "play.fill")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.playControl))
                                .frame(width: 42, height: 42)
                                .background(PulseTheme.playControl, in: Circle())
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
                    VStack(spacing: 8) {
                        ForEach(workout.exercises.prefix(4)) { we in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .frame(width: 20, height: 20)
                                    .background(PulseTheme.accent.opacity(0.12), in: Circle())
                                Text(RepsText.exerciseName(we.exercise.name, language: language))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text("\(we.targetSets)×\(we.repRange)")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PulseTheme.grouped.opacity(0.72), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("recommended_projection_title")
                        .font(.caption.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .textCase(.uppercase)

                    PlanProjectionChart(
                        points: projectionPoints,
                        tint: PulseTheme.accent,
                        height: 130
                    )

                    Text(projectionCaption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    Label {
                        Text("recommended_projection_disclaimer_short")
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PulseTheme.grouped.opacity(0.72), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))

                Button {
                    showDetail = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.caption.weight(.black))
                        Text("recommended_workout_detail_cta")
                            .font(.caption.weight(.black))
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.black))
                    }
                    .foregroundStyle(PulseTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(PulseTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
                            .stroke(PulseTheme.accent.opacity(0.12), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("recommended_workout_detail_cta")
            }
        }
        .fullScreenCover(isPresented: $showDetail) {
            NavigationStack {
                WorkoutDetailView(workout: workout)
            }
        }
    }
}

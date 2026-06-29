import SwiftUI

struct FreeWorkoutStartView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                SectionHeader(title: "free_workout_2")
                    .padding(.top, 4)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeWorkout, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "free_strength",
                        subtitle: "add_exercises_and_log_sets",
                        systemImage: "dumbbell.fill",
                        tint: PulseTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeOutdoorWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "outdoor_walk",
                        subtitle: "gps_route_steps_distance_and_vitals",
                        systemImage: "figure.walk",
                        tint: PulseTheme.ringExercise
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "treadmill_walk",
                        subtitle: "no_map_time_steps_heart_rate_kcal_and_distance_when_available",
                        systemImage: "figure.walk.motion",
                        tint: PulseTheme.ringStand
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeOutdoorRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "outdoor_run",
                        subtitle: "pace_map_heart_rate_and_final_summary",
                        systemImage: "figure.run",
                        tint: PulseTheme.ringMove
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "treadmill_run",
                        subtitle: "no_gps_time_pace_heart_rate_and_kcal_from_sensors",
                        systemImage: "figure.run.treadmill",
                        tint: PulseTheme.warning
                    )
                }
                .buttonStyle(.plain)

                Text(localizedString("outdoor_uses_gps_and_map_treadmill_skips_route_tracking_and_saves_sensors_plus_d"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 24)
        }
        .navigationTitle(localizedString("start"))
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }
}

private struct FreeWorkoutStartRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(localizedKey(title))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(localizedKey(subtitle))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(14)
        .background(PulseTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    }
}

extension WorkoutDay {
    static var freeOutdoorWalk: WorkoutDay {
        WorkoutDay(
            title: localizedString("outdoor_walk"),
            subtitle: localizedString("gps_route_sensors"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillWalk: WorkoutDay {
        WorkoutDay(
            title: localizedString("treadmill_walk"),
            subtitle: localizedString("no_gps_with_sensors"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .treadmill
        )
    }

    static var freeOutdoorRun: WorkoutDay {
        WorkoutDay(
            title: localizedString("outdoor_run"),
            subtitle: localizedString("pace_route_sensors"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillRun: WorkoutDay {
        WorkoutDay(
            title: localizedString("treadmill_run"),
            subtitle: localizedString("no_gps_with_sensors"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .treadmill
        )
    }
}

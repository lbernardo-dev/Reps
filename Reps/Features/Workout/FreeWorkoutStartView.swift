import SwiftUI

struct FreeWorkoutStartView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ActiveWorkoutView(workout: .freeWorkout, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "free_strength",
                        subtitle: "add_exercises_and_log_sets",
                        systemImage: "dumbbell.fill"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeOutdoorWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "outdoor_walk",
                        subtitle: "gps_route_steps_distance_and_vitals",
                        systemImage: "figure.walk"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "treadmill_walk",
                        subtitle: "no_map_time_steps_heart_rate_kcal_and_distance_when_available",
                        systemImage: "figure.walk.motion"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeOutdoorRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "outdoor_run",
                        subtitle: "pace_map_heart_rate_and_final_summary",
                        systemImage: "figure.run"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "treadmill_run",
                        subtitle: "no_gps_time_pace_heart_rate_and_kcal_from_sensors",
                        systemImage: "figure.run.treadmill"
                    )
                }
            } header: {
                Text(localizedString("free_workout_2"))
            } footer: {
                Text(localizedString("outdoor_uses_gps_and_map_treadmill_skips_route_tracking_and_saves_sensors_plus_d"))
            }
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(localizedKey(title))
                    .font(.headline)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

extension WorkoutDay {
    static var freeOutdoorWalk: WorkoutDay {
        WorkoutDay(
            title: localizedString("Caminata exterior"),
            subtitle: localizedString("GPS, ruta y sensores"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillWalk: WorkoutDay {
        WorkoutDay(
            title: localizedString("Caminata en cinta"),
            subtitle: localizedString("Sin GPS, con sensores"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .treadmill
        )
    }

    static var freeOutdoorRun: WorkoutDay {
        WorkoutDay(
            title: localizedString("Carrera exterior"),
            subtitle: localizedString("Ritmo, ruta y sensores"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillRun: WorkoutDay {
        WorkoutDay(
            title: localizedString("Carrera en cinta"),
            subtitle: localizedString("Sin GPS, con sensores"),
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .treadmill
        )
    }
}

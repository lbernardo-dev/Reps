import SwiftUI

struct FreeWorkoutStartView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("start"))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text(localizedString("free_workout_2"))
                        .font(.headline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                NavigationLink {
                    ActiveWorkoutView(workout: .freeWorkout, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: "free_strength",
                        subtitle: "add_exercises_and_log_sets",
                        systemImage: "dumbbell.fill",
                        tint: PulseTheme.accent,
                        chips: ["sets_3", "volume_2"]
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
                        tint: PulseTheme.ringExercise,
                        chips: ["GPS", "steps"]
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
                        tint: PulseTheme.ringStand,
                        chips: ["time_3", "FC"]
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
                        tint: PulseTheme.ringMove,
                        chips: ["pace", "route"]
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
                        tint: PulseTheme.warning,
                        chips: ["pace", "active_kcal"]
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
    var chips: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 56)

                Spacer(minLength: 8)

                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 58, height: 58)
                    .background(tint, in: Circle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(localizedKey(title))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                Text(localizedKey(subtitle))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !chips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Text(localizedKey(chip))
                            .font(.caption.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)
        .background(
            ZStack {
                PulseTheme.card
                LinearGradient(
                    colors: [tint.opacity(0.19), tint.opacity(0.06), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
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

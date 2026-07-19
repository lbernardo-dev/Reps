import SwiftUI

struct StrengthWorkoutHero: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    let title: String
    let exerciseCount: Int
    let backAction: () -> Void
    let shareAction: () -> Void

    private var isMetric: Bool { store.userProfile.units == .metric }
    private var weightUnit: String { isMetric ? "kg" : "lb" }
    private var displayVolume: Int {
        let kg = FitnessMetrics.totalVolumeKg(for: [session])
        return Int(isMetric ? kg : UnitConverter.pounds(fromKilograms: kg))
    }
    private var setCount: Int { FitnessMetrics.completedSets(in: session).count }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    PulseTheme.card,
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.14))
                Text(localizedString(session.location == .home ? "home_workout_hero" : "gym_workout_hero"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 96)

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.15), Color.black.opacity(0.82), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: session.location == .home ? "house.fill" : "building.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text(localizedString(session.location == .home ? "home_2" : "gym_2"))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text("\(displayVolume) \(weightUnit.uppercased())")
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(PulseTheme.ringExercise)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 6) {
                    Text(session.routeDateRangeText)
                    Image(systemName: session.routeSourceText == "Apple Watch" ? "applewatch" : "iphone")
                    Text(session.routeSourceText)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.66)

                HStack(spacing: 16) {
                    RouteHeroSensor(
                        icon: "checkmark.circle.fill",
                        iconColor: PulseTheme.ringExercise,
                        value: "\(setCount)",
                        label: localizedString("sets_label")
                    )
                    RouteHeroSensor(
                        icon: "list.bullet",
                        iconColor: PulseTheme.ringStand,
                        value: "\(exerciseCount)",
                        label: localizedString("exercises_3")
                    )
                    if let averageHeartRate = session.averageHeartRate {
                        RouteHeroSensor(
                            icon: "heart.fill",
                            iconColor: PulseTheme.ringMove,
                            value: "\(Int(averageHeartRate))",
                            label: localizedString("avg_heart_rate")
                        )
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 24)

            WorkoutHeroToolbar(
                backAction: backAction,
                shareAction: shareAction
            )
        }
        .frame(height: 460)
    }
}

struct StrengthWorkoutDetailsCard: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    let exerciseCount: Int

    private let columns = [
        GridItem(.flexible(), spacing: 18, alignment: .topLeading),
        GridItem(.flexible(), spacing: 18, alignment: .topLeading)
    ]

    private var isMetric: Bool { store.userProfile.units == .metric }
    private var weightUnit: String { isMetric ? "kg" : "lb" }
    private var displayVolume: Int {
        let kg = FitnessMetrics.totalVolumeKg(for: [session])
        return Int(isMetric ? kg : UnitConverter.pounds(fromKilograms: kg))
    }
    private var setCount: Int { FitnessMetrics.completedSets(in: session).count }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            RouteWorkoutMetric(title: localizedString("workout_time_label"), value: session.workoutTimeText, color: PulseTheme.hrZones[2])
            RouteWorkoutMetric(title: localizedString("total_volume_label"), value: "\(displayVolume) \(weightUnit.uppercased())", color: PulseTheme.ringExercise)
            RouteWorkoutMetric(title: localizedString("sets_label"), value: "\(setCount)", color: PulseTheme.ringStand)
            RouteWorkoutMetric(title: localizedString("exercises_3"), value: "\(exerciseCount)", color: PulseTheme.ringStand)
            RouteWorkoutMetric(title: localizedString("avg_rpe_label"), value: (session.sessionRPE ?? AnalyticsEngine.averageRPE(for: session)).map { String(format: "%.1f", $0) } ?? "-", color: PulseTheme.hrZones[3])
            RouteWorkoutMetric(title: localizedString("active_kcal_label"), value: session.activeKilocaloriesText, color: PulseTheme.ringMove)
            RouteWorkoutMetric(title: localizedString("avg_heart_rate"), value: session.averageHeartRate.map { localizedFormat("heart_rate_bpm_format", Int($0)) } ?? "--", color: PulseTheme.ringMove)
            RouteWorkoutMetric(title: localizedString("max_heart_rate"), value: session.maxHeartRate.map { localizedFormat("heart_rate_bpm_format", Int($0)) } ?? "--", color: PulseTheme.ringMove)
        }
        .padding(24)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct StrengthExerciseBreakdownCard: View {
    @Environment(AppStore.self) private var store
    let exerciseLogs: [ExerciseLog]

    private var isMetric: Bool { store.userProfile.units == .metric }
    private var weightUnit: String { isMetric ? "kg" : "lb" }

    private func displayVolume(_ kg: Double) -> Int {
        Int(isMetric ? kg : UnitConverter.pounds(fromKilograms: kg))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("exercises_3")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(exerciseLogs) { log in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(log.exercise.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(localizedFormat("sets_volume_summary_format", log.sets.count, displayVolume(log.sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }), weightUnit))
                                .font(.subheadline)
                                .foregroundStyle(Color.white.opacity(0.55))
                        }
                        Spacer()
                        NavigationLink {
                            ExerciseProgressView(exercise: log.exercise)
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.ringExercise)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(log.sets) { set in
                        WorkoutSessionSetRow(set: set)
                    }

                    if !log.notes.isEmpty {
                        Text(log.notes)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.55))
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)

                if log.id != exerciseLogs.last?.id {
                    Divider().overlay(Color.white.opacity(0.08))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct WorkoutSessionSetRow: View {
    @Environment(AppStore.self) private var store
    let set: SetLog

    private var isMetric: Bool { store.userProfile.units == .metric }
    private var weightUnit: String { isMetric ? "kg" : "lb" }
    private var displayWeight: Double {
        isMetric ? set.weightKg : UnitConverter.pounds(fromKilograms: set.weightKg)
    }

    private var typeText: String? {
        switch set.setType {
        case .warmUp: return localizedString("warm_up")
        case .dropSet: return "Drop"
        case .topSet: return "Top"
        case .backOff: return "Backoff"
        case .restPause: return "Rest-Pause"
        case .activation: return localizedString("activation_set")
        case .failure: return localizedString("failure_set")
        case .work: return nil
        }
    }

    var body: some View {
        HStack {
            Text(localizedFormat("set_number_format", set.setNumber))
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)

            if let typeText {
                effortBadge(typeText, color: Color.white.opacity(0.10))
            }

            if let rpe = set.rpe {
                effortBadge(String(format: "RPE %.1f", rpe), color: Color.orange.opacity(0.22))
            }

            if let rir = set.rir {
                effortBadge("RIR \(rir)", color: Color.blue.opacity(0.22))
            }

            Spacer()

            Text("\(String(format: "%.1f", displayWeight)) \(weightUnit) x \(set.reps)")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.bold)
                .foregroundStyle(set.isPersonalRecord ? PulseTheme.accent : .white)

            if set.isPersonalRecord {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(PulseTheme.accent)
            }
        }
        .padding(.vertical, 2)
    }

    private func effortBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Color.white.opacity(0.75))
            .background(color)
            .clipShape(Capsule())
    }
}

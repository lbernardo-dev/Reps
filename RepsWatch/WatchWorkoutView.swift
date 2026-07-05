import SwiftUI
import WatchKit

// MARK: - Root router

struct WatchWorkoutView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    private var isActive: Bool {
        model.mode != .none || model.snapshot.hasActiveWorkout
    }

    var body: some View {
        let _ = RepsLocalization.use(model.snapshot.preferredLanguage)
        Group {
            if isActive {
                WatchActiveWorkoutView()
            } else {
                WatchStartView()
            }
        }
    }
}

// MARK: - Start launcher

struct WatchStartView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    var body: some View {
        if !model.snapshot.hasWatchAccess {
            WatchProLockedView()
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 10) {
                        WatchProgressDashboard()
                        WatchTodaySessionCard()

                        if let gymName = model.snapshot.gymPassName {
                            WatchGymPassCard(
                                gymName: gymName,
                                memberID: model.snapshot.gymMembershipID
                            )
                        }

                        Text(localizedString("Start"))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)

                        WatchStartRow(
                            title: localizedString("Strength"),
                            subtitle: localizedString("Log your sets"),
                            icon: "dumbbell.fill",
                            color: accent
                        ) {
                            model.startStrengthWorkout()
                        }
                        WatchStartRow(
                            title: localizedString("Walk"),
                            subtitle: localizedString("Outdoor · GPS"),
                            icon: "figure.walk",
                            color: WatchTheme.ringExercise
                        ) {
                            model.startStandaloneRouteWorkout(activity: .walking)
                        }
                        WatchStartRow(
                            title: localizedString("Run"),
                            subtitle: localizedString("Pace · distance"),
                            icon: "figure.run",
                            color: WatchTheme.ringExercise
                        ) {
                            model.startStandaloneRouteWorkout(activity: .running)
                        }
                        NavigationLink {
                            WatchIntervalPickerView()
                        } label: {
                            WatchStartRowLabel(
                                title: localizedString("Intervals"),
                                subtitle: localizedString("HIIT by phases"),
                                icon: "bolt.heart.fill",
                                color: WatchTheme.ringMove
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 10)
                }
                .navigationTitle("Reps")
            }
        }
    }
}

private struct WatchProLockedView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.yellow)
            Text(localizedString("watch_pro_required_title"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(localizedString("watch_pro_required_subtitle"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Home dashboard (general + today progress)

private struct WatchProgressDashboard: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    private var weekly: Double { min(max(model.snapshot.weeklyCompletion, 0), 1) }
    private var batteryLevel: Int { model.snapshot.trainingBatteryLevel }
    private var batteryColor: Color { WatchTheme.batteryColor(for: batteryLevel) }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                WatchRing(progress: weekly, lineWidth: 7, color: WatchTheme.ringExercise) {
                    VStack(spacing: 0) {
                        Text("\(Int(weekly * 100))%")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(localizedString("Week"))
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 7) {
                    WatchMiniStat(icon: "flame.fill", value: "\(model.snapshot.streakDays)", label: localizedString("Streak"), color: .orange)
                    WatchMiniStat(icon: model.snapshot.trainingBatterySystemImage, value: "\(batteryLevel)%", label: localizedString("Battery"), color: batteryColor)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(batteryColor)
                            .frame(width: max(4, proxy.size.width * CGFloat(Double(batteryLevel) / 100.0)))
                    }
                }
                .frame(height: 5)
                Text(batteryText)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
    }

    private var batteryText: String {
        let suggestion = model.snapshot.trainingBatterySuggestion
        return suggestion.isEmpty ? model.snapshot.trainingBatteryTitle : suggestion
    }
}

private struct WatchTodaySessionCard: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(accent.opacity(0.16)).frame(width: 34, height: 34)
                Image(systemName: model.snapshot.nextWorkoutDayName != nil ? "calendar.badge.clock" : "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("Today"))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(model.snapshot.nextWorkoutDayName ?? model.snapshot.summary)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let desc = model.snapshot.nextWorkoutDayDescription {
                    Text(desc)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - Gym Pass card

private struct WatchGymPassCard: View {
    let gymName: String
    let memberID: String?

    var body: some View {
        NavigationLink {
            WatchGymPassDetailView(gymName: gymName, memberID: memberID)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(WatchTheme.ringStand.opacity(0.16)).frame(width: 34, height: 34)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WatchTheme.ringStand)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedString("Gym Pass"))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(gymName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WatchTheme.ringStand.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous)
                    .stroke(WatchTheme.ringStand.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(localizedString("Gym Pass")): \(gymName)")
    }
}

private struct WatchGymPassDetailView: View {
    let gymName: String
    let memberID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(WatchTheme.ringStand)
                    .padding(.top, 6)

                Text(gymName)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let memberID {
                    Text(memberID)
                        .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .navigationTitle(localizedString("Gym Pass"))
    }
}

private struct WatchMiniStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

struct WatchRing<Content: View>: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0.001), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            content()
        }
    }
}

private struct WatchStartRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            WatchStartRowLabel(title: title, subtitle: subtitle, icon: icon, color: color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WatchStartRowLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct WatchIntervalPickerView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(WatchIntervalPreset.presets) { preset in
                    Button {
                        model.startIntervalWorkout(preset: preset)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(localizedFormat("%d rounds · %ds / %ds", preset.rounds, preset.workSeconds, preset.restSeconds))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(WatchTheme.ringMove)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WatchTheme.ringMove.opacity(0.10), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(preset.name), \(preset.rounds) rondas")
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(localizedString("Intervals"))
    }
}

// MARK: - Active workout container

struct WatchActiveWorkoutView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            nowPage.tag(0)
            WatchMetricsPage().tag(1)
            summaryPage.tag(2)
        }
        .tabViewStyle(.page)
    }

    @ViewBuilder
    private var nowPage: some View {
        switch model.mode {
        case .interval:
            WatchIntervalNowView()
        case .phoneRoute, .standaloneRoute:
            WatchRouteNowView()
        default:
            if model.snapshot.isRouteWorkout {
                WatchRouteNowView()
            } else {
                WatchStrengthNowView()
            }
        }
    }

    @ViewBuilder
    private var summaryPage: some View {
        switch model.mode {
        case .interval:
            WatchIntervalSummaryView()
        case .phoneRoute, .standaloneRoute:
            WatchRouteSummaryView()
        default:
            if model.snapshot.isRouteWorkout {
                WatchRouteSummaryView()
            } else {
                WatchStrengthSummaryView()
            }
        }
    }
}

// MARK: - Route: now page

struct WatchRouteNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    @State private var showStopConfirmation = false

    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }
    private var distanceKm: Double { model.routeDistanceKm ?? model.snapshot.routeDistanceKm ?? 0 }
    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
    private var hrZoneLabel: String { model.heartRateZone.map { "Z\($0)" } ?? localizedString("Pulse") }
    private var hrColor: Color { WatchTheme.zoneColor(model.heartRateZone) }

    var body: some View {
        VStack(spacing: 5) {
            // Activity type + paused badge
            HStack(spacing: 5) {
                Image(systemName: activityIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(model.snapshot.workoutTitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if model.state == .paused {
                    Text("PAUSED")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)

            // Big distance
            VStack(spacing: -2) {
                Text(String(format: "%.2f", distanceKm))
                    .font(.system(size: 52, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Text("km")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Pace · Time · HR pills
            HStack(spacing: 4) {
                WatchStatPill(title: localizedString("Pace"), value: paceText, color: .orange)
                WatchStatPill(title: localizedString("Time"), value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds), color: accent)
                WatchStatPill(title: hrZoneLabel, value: hrText, color: hrColor)
            }
            .padding(.horizontal, 6)

            // Controls
            HStack(spacing: 16) {
                Button { model.togglePause() } label: {
                    Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(WatchCircleButtonStyle(
                    color: model.state == .paused ? WatchTheme.success : WatchTheme.warning,
                    size: 48
                ))
                .accessibilityLabel(model.state == .paused ? localizedString("Resume") : localizedString("Pause"))

                Button { showStopConfirmation = true } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(WatchCircleButtonStyle(color: WatchTheme.destructive, size: 48))
                .accessibilityLabel(localizedString("End"))
            }
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
        .confirmationDialog("", isPresented: $showStopConfirmation, titleVisibility: .hidden) {
            Button(localizedString("End"), role: .destructive) { model.stop() }
        }
    }

    private var activityIcon: String {
        let t = model.snapshot.workoutTitle.lowercased()
        return (t.contains("carrera") || t.contains("run")) ? "figure.run" : "figure.walk"
    }

    private var paceText: String {
        guard let pace = model.routePaceSecondsPerKm ?? model.snapshot.routePaceSecondsPerKm,
              pace.isFinite, pace > 0 else { return "--" }
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))"
    }
}

// MARK: - Route: summary page

struct WatchRouteSummaryView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchBigMetric(value: stepsText, label: localizedString("Steps"), icon: "shoeprints.fill", color: WatchTheme.ringExercise)
                    WatchBigMetric(value: speedText, label: "km/h", icon: "gauge.with.needle", color: WatchTheme.ringStand)
                    WatchBigMetric(value: kcalText, label: "kcal", icon: "flame.fill", color: .orange)
                    WatchBigMetric(value: hrText, label: "lpm", icon: "heart.fill", color: WatchTheme.zoneColor(model.heartRateZone))
                }
                WatchEndButton()
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }

    private var stepsText: String { (model.routeSteps ?? model.snapshot.routeSteps).map { "\(Int($0))" } ?? "--" }
    private var speedText: String { (model.routeSpeedKmh ?? model.snapshot.routeSpeedKmh).map { String(format: "%.1f", $0) } ?? "--" }
    private var kcalText: String { "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))" }
    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
}

// MARK: - Strength: now page (set logging)

struct WatchStrengthNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    @State private var showStopConfirmation = false

    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    var body: some View {
        ScrollView {
            if model.exercises.isEmpty {
                emptyState
            } else if let resting = model.localRestEndDate {
                restBanner(until: resting)
                logger
            } else if let restSeconds = model.snapshot.restSeconds, restSeconds > 0, model.mode == .phoneStrength {
                phoneRestBanner
                logger
            } else {
                logger
            }
        }
        .confirmationDialog("", isPresented: $showStopConfirmation, titleVisibility: .hidden) {
            Button(localizedString("End"), role: .destructive) { model.stop() }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { model.moveExercise(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
            .disabled(model.currentExerciseIndex == 0)
            .opacity(model.currentExerciseIndex == 0 ? 0.3 : 1)
            .accessibilityLabel(localizedString("Previous exercise"))

            VStack(spacing: 1) {
                Text(model.currentExercise?.name ?? localizedString("Exercise"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                Text(localizedFormat("Set %d", model.currentSetNumber))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)

            Button { model.moveExercise(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
            .disabled(model.currentExerciseIndex >= model.exercises.count - 1)
            .opacity(model.currentExerciseIndex >= model.exercises.count - 1 ? 0.3 : 1)
            .accessibilityLabel(localizedString("Next exercise"))
        }
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            Button { model.togglePause() } label: {
                Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(WatchCircleButtonStyle(color: model.state == .paused ? WatchTheme.success : WatchTheme.warning, size: 30))
            .accessibilityLabel(model.state == .paused ? localizedString("Resume") : localizedString("Pause"))

            Spacer()
            Text(SharedWorkoutSnapshot.durationText(model.elapsedSeconds))
                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()

            Button { showStopConfirmation = true } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(WatchCircleButtonStyle(color: WatchTheme.destructive, size: 30))
            .accessibilityLabel(localizedString("End"))
        }
    }

    private var logger: some View {
        VStack(spacing: 9) {
            controlBar
            header

            HStack(spacing: 8) {
                if model.currentExercise?.isBodyweight == false {
                    WatchValueStepper(
                        label: "kg",
                        format: weightString(model.currentSetWeight),
                        accent: accent,
                        onDec: { model.adjustWeight(by: -2.5) },
                        onInc: { model.adjustWeight(by: 2.5) }
                    )
                }
                WatchRepsStepper(
                    reps: model.currentSetReps,
                    accent: accent,
                    onDec: { model.adjustReps(by: -1) },
                    onInc: { model.adjustReps(by: 1) }
                )
            }

            if let previous = model.currentExercise?.previous {
                Text(localizedFormat("Prev %@", previous))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let next = model.nextExerciseNameForDisplay {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(next)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Button {
                model.completeCurrentSet()
            } label: {
                Label(localizedString("Complete"), systemImage: "checkmark")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: WatchTheme.primaryActionHeight)
            }
            .buttonStyle(.plain)
            .background(accent, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
            .foregroundStyle(.black)
            .accessibilityLabel(localizedString("Complete set"))

            HStack(spacing: 6) {
                WatchTag(text: localizedString("warm_up_short"), color: .yellow) { model.addSet(type: .warmUp) }
                WatchTag(text: localizedString("+ Set"), color: accent) { model.addSet(type: .work) }
                WatchTag(text: localizedString("drop_set_short"), color: .purple) { model.addSet(type: .dropSet) }
            }

            WatchSetDots(exercise: model.currentExercise)
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 8)
    }

    private func restBanner(until end: Date) -> some View {
        VStack(spacing: 5) {
            HStack {
                Label(localizedString("Rest"), systemImage: "hourglass")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.orange)
                Spacer()
                Text(end, style: .timer)
                    .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            Button { model.skipLocalRest() } label: {
                Text(localizedString("Skip rest"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(.orange)
        }
        .padding(9)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .padding(.horizontal, 5)
        .padding(.bottom, 6)
    }

    private var phoneRestBanner: some View {
        HStack {
            Label(localizedString("Rest"), systemImage: "hourglass")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.orange)
            Spacer()
            if let end = model.snapshot.restEndDate {
                Text(end, style: .timer)
                    .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else {
                Text(model.snapshot.restText)
                    .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.orange)
            }
        }
        .padding(9)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .padding(.horizontal, 5)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(accent)
                .padding(.top, 10)

            if model.mode == .phoneStrength {
                Text(localizedString("Waiting for exercises from iPhone…"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                WatchEndButton()
            } else {
                Text(localizedString("Add an exercise"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                ForEach(WatchWorkoutModel.quickAddExercises, id: \.name) { item in
                    Button {
                        model.addExercise(named: item.name, trackingType: item.tracking)
                    } label: {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.name)
                }
                WatchEndButton()
            }
        }
        .padding(.horizontal, 5)
    }

    private func weightString(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Strength: summary page

struct WatchStrengthSummaryView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(localizedString("Volume"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(Int(model.totalVolumeKg)) kg")
                            .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(localizedString("Sets"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("\(model.totalCompletedSets)/\(model.totalSetCount)")
                            .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(accent)
                    }
                }
                .padding(10)
                .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))

                ForEach(Array(model.exercises.enumerated()), id: \.element.id) { index, exercise in
                    Button {
                        model.selectExercise(index)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(index == model.currentExerciseIndex ? accent : Color.white.opacity(0.15))
                                .frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(exercise.name)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(localizedFormat("%d/%d sets", exercise.completedSets, exercise.sets.count))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(exercise.volumeKg)) kg")
                                .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(accent)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 9)
                        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exercise.name)
                }

                WatchEndButton()
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Interval: now page

struct WatchIntervalNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    @State private var showStopConfirmation = false

    private var phaseColor: Color { model.intervalIsWork ? .red : WatchTheme.success }

    var body: some View {
        VStack(spacing: 6) {
            if let preset = model.intervalPreset {
                // Phase label
                Text(model.intervalIsWork ? localizedString("WORK") : localizedString("REST"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(phaseColor)
                    .padding(.top, 4)

                // Big countdown
                Text("\(model.intervalPhaseRemaining)s")
                    .font(.system(size: 54, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)

                // Round + name
                Text(localizedFormat("Round %d/%d", min(model.intervalRound + 1, preset.rounds), preset.rounds))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                // Stats pills
                HStack(spacing: 4) {
                    WatchStatPill(
                        title: localizedString("Total"),
                        value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds),
                        color: .blue
                    )
                    WatchStatPill(
                        title: localizedString("Pulse"),
                        value: hrText,
                        color: WatchTheme.zoneColor(model.heartRateZone)
                    )
                }
                .padding(.horizontal, 6)

                // Controls
                HStack(spacing: 10) {
                    Button { model.togglePause() } label: {
                        Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(WatchCircleButtonStyle(
                        color: model.state == .paused ? WatchTheme.success : WatchTheme.warning, size: 42
                    ))
                    .accessibilityLabel(model.state == .paused ? localizedString("Resume") : localizedString("Pause"))

                    Button { model.skipIntervalPhase() } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(WatchCircleButtonStyle(color: .blue, size: 42))
                    .accessibilityLabel(localizedString("Skip"))

                    Button { showStopConfirmation = true } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(WatchCircleButtonStyle(color: WatchTheme.destructive, size: 42))
                    .accessibilityLabel(localizedString("End"))
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
        .padding(.horizontal, 6)
        .confirmationDialog("", isPresented: $showStopConfirmation, titleVisibility: .hidden) {
            Button(localizedString("End"), role: .destructive) { model.stop() }
        }
    }

    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
}

// MARK: - Interval: summary page

struct WatchIntervalSummaryView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchBigMetric(
                        value: "\(min(model.intervalRound + 1, model.intervalPreset?.rounds ?? 0))",
                        label: localizedString("round"),
                        icon: "repeat",
                        color: .red
                    )
                    WatchBigMetric(value: kcalText, label: "kcal", icon: "flame.fill", color: .orange)
                    WatchBigMetric(value: hrText, label: "lpm", icon: "heart.fill", color: WatchTheme.zoneColor(model.heartRateZone))
                    WatchBigMetric(
                        value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds),
                        label: localizedString("time"),
                        icon: "timer",
                        color: .blue
                    )
                }
                WatchEndButton()
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }

    private var kcalText: String { "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))" }
    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
}

// MARK: - Metrics page (shared middle tab)

struct WatchMetricsPage: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                VStack(spacing: 1) {
                    Text(localizedString("Time"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(SharedWorkoutSnapshot.durationText(model.elapsedSeconds))
                        .font(.system(size: 32, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(model.state == .paused ? .orange : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))

                WatchZoneBar(zone: model.heartRateZone)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchBigMetric(value: hrText, label: zoneLabel, icon: "heart.fill", color: WatchTheme.zoneColor(model.heartRateZone))
                    WatchBigMetric(value: kcalText, label: "kcal", icon: "flame.fill", color: .orange)
                    if model.isStrengthMode {
                        WatchBigMetric(value: "\(Int(model.totalVolumeKg))", label: localizedString("kg vol"), icon: "chart.bar.fill", color: accent)
                        WatchBigMetric(value: "\(model.totalCompletedSets)", label: localizedString("Sets"), icon: "checkmark.seal.fill", color: WatchTheme.success)
                    } else {
                        WatchBigMetric(
                            value: String(format: "%.2f", model.routeDistanceKm ?? model.snapshot.routeDistanceKm ?? 0),
                            label: "km",
                            icon: "location.fill",
                            color: accent
                        )
                        WatchBigMetric(value: stepsText, label: localizedString("steps"), icon: "shoeprints.fill", color: WatchTheme.ringExercise)
                    }
                }

                // Music controls — only shown when iPhone is playing something
                let snapshot = model.snapshot
                if snapshot.musicTitle != nil || snapshot.isMusicPlaying != nil {
                    WatchMusicBar(snapshot: snapshot,
                                  onPrev:   { model.musicPrev() },
                                  onToggle: { model.musicToggle() },
                                  onNext:   { model.musicNext() })
                }

                // Water logging
                WatchWaterRow(waterLiters: model.snapshot.waterLiters) {
                    model.addWater()
                }

                WatchEndButton()
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }

    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
    private var kcalText: String { "\(Int(model.snapshot.activeEnergyKcal ?? model.activeEnergy))" }
    private var stepsText: String { (model.routeSteps ?? model.snapshot.routeSteps).map { "\(Int($0))" } ?? "--" }
    private var zoneLabel: String { model.heartRateZone.map { "Z\($0)" } ?? "lpm" }
}

// MARK: - Reusable components

/// Weight/value stepper without Digital Crown rotation to avoid conflicting
/// with ScrollView scrolling. Use the +/- buttons for adjustment.
struct WatchValueStepper: View {
    let label: String
    let format: String
    let accent: Color
    let onDec: () -> Void
    let onInc: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(format)
                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accent, lineWidth: 1.5)
                )

            HStack(spacing: 6) {
                Button(action: onDec) { Image(systemName: "minus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
                    .accessibilityLabel("Reducir \(label)")
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Button(action: onInc) { Image(systemName: "plus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
                    .accessibilityLabel("Aumentar \(label)")
            }
        }
    }
}

struct WatchRepsStepper: View {
    let reps: Int
    let accent: Color
    let onDec: () -> Void
    let onInc: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("\(reps)")
                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 6) {
                Button(action: onDec) { Image(systemName: "minus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
                    .accessibilityLabel("Reducir repeticiones")
                Text("reps")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Button(action: onInc) { Image(systemName: "plus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
                    .accessibilityLabel("Aumentar repeticiones")
            }
        }
    }
}

struct WatchSetDots: View {
    let exercise: WatchExercise?

    var body: some View {
        if let exercise, !exercise.sets.isEmpty {
            HStack(spacing: 5) {
                ForEach(exercise.sets) { set in
                    Circle()
                        .fill(color(for: set))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    private func color(for set: WatchSet) -> Color {
        if set.completed { return WatchTheme.success }
        switch set.type {
        case .warmUp: return .yellow.opacity(0.5)
        case .dropSet: return .purple.opacity(0.5)
        case .work: return Color.white.opacity(0.2)
        }
    }
}

struct WatchBigMetric: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
    }
}

struct WatchStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WatchZoneBar: View {
    let zone: Int?

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { z in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(zone == z ? WatchTheme.zoneColors[z - 1] : WatchTheme.zoneColors[z - 1].opacity(0.22))
                    .frame(height: zone == z ? 10 : 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.2), value: zone)
    }
}

struct WatchTag: View {
    let text: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct WatchEndButton: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    @State private var showConfirmation = false

    var body: some View {
        Button { showConfirmation = true } label: {
            Label(localizedString("End"), systemImage: "stop.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: WatchTheme.buttonHeight)
        }
        .buttonStyle(.plain)
        .background(WatchTheme.destructive.opacity(0.16), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .foregroundStyle(WatchTheme.destructive)
        .padding(.top, 4)
        .accessibilityLabel(localizedString("End workout"))
        .confirmationDialog("", isPresented: $showConfirmation, titleVisibility: .hidden) {
            Button(localizedString("End"), role: .destructive) { model.stop() }
        }
    }
}

// MARK: - Music controls (relayed to iPhone)

struct WatchMusicBar: View {
    let snapshot: SharedWorkoutSnapshot
    let onPrev: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "music.note")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.purple)
                Text(snapshot.musicTitle ?? localizedString("Music"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let artist = snapshot.musicArtist {
                    Text("· \(artist)")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button(action: onPrev) { Image(systemName: "backward.fill") }
                    .buttonStyle(WatchCircleButtonStyle(color: .purple, size: 30))
                    .accessibilityLabel("Anterior")
                Button(action: onToggle) {
                    Image(systemName: snapshot.isMusicPlaying == true ? "pause.fill" : "play.fill")
                }
                .buttonStyle(WatchCircleButtonStyle(color: .purple, size: 34))
                .accessibilityLabel(snapshot.isMusicPlaying == true ? localizedString("Pause") : "Play")
                Button(action: onNext) { Image(systemName: "forward.fill") }
                    .buttonStyle(WatchCircleButtonStyle(color: .purple, size: 30))
                    .accessibilityLabel("Siguiente")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Water logging (relayed to iPhone)

struct WatchWaterRow: View {
    let waterLiters: Double?
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.cyan)
            Text(String(format: "%.2f L", waterLiters ?? 0))
                .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button(action: onAdd) {
                Text("+250 ml")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("add_250_ml_water"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
    }
}

struct WatchCircleButtonStyle: ButtonStyle {
    let color: Color
    var size: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.14), in: Circle())
            .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1.2))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    WatchStartRow(title: localizedString("Strength"), subtitle: localizedString("Log your sets"), icon: "dumbbell.fill", color: accent) {
                        model.startStrengthWorkout()
                    }
                    WatchStartRow(title: localizedString("Walk"), subtitle: localizedString("Outdoor · GPS"), icon: "figure.walk", color: WatchTheme.success) {
                        model.startStandaloneRouteWorkout(activity: .walking)
                    }
                    WatchStartRow(title: localizedString("Run"), subtitle: localizedString("Pace · distance"), icon: "figure.run", color: .green) {
                        model.startStandaloneRouteWorkout(activity: .running)
                    }
                    NavigationLink {
                        WatchIntervalPickerView()
                    } label: {
                        WatchStartRowLabel(title: localizedString("Intervals"), subtitle: localizedString("HIIT by phases"), icon: "bolt.heart.fill", color: .red)
                    }
                    .buttonStyle(.plain)

                    WatchStartFooter()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            }
            .navigationTitle("Reps")
        }
    }
}

private struct WatchStartFooter: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Label("\(model.snapshot.streakDays)", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Label("\(Int(model.snapshot.weeklyCompletion * 100))%", systemImage: "calendar")
                    .foregroundStyle(WatchTheme.success)
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))

            Text(syncText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(WatchTheme.cardFill, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .padding(.top, 4)
    }

    private var syncText: String {
        if let next = model.snapshot.nextWorkoutDayName {
            return localizedFormat("Next: %@", next)
        }
        return localizedString("Start here or sync from your iPhone.")
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
        .padding(.vertical, 9)
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
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
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

// MARK: - Strength: now page (set logging)

struct WatchStrengthNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

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
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button { model.moveExercise(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(WatchCircleButtonStyle(color: accent, size: 30))
            .disabled(model.currentExerciseIndex == 0)
            .opacity(model.currentExerciseIndex == 0 ? 0.3 : 1)

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
        }
    }

    private var logger: some View {
        VStack(spacing: 9) {
            header

            HStack(spacing: 8) {
                if model.currentExercise?.isBodyweight == false {
                    WatchValueStepper(
                        label: "kg",
                        format: weightString(model.currentSetWeight),
                        accent: accent,
                        crownBinding: Binding(
                            get: { model.currentSetWeight },
                            set: { model.setActiveWeight($0) }
                        ),
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

            Button {
                model.completeCurrentSet()
            } label: {
                Label(localizedString("Complete"), systemImage: "checkmark")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: WatchTheme.primaryActionHeight)
            }
            .buttonStyle(.plain)
            .background(WatchTheme.success, in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
            .foregroundStyle(.white)

            HStack(spacing: 6) {
                WatchTag(text: "+W", color: .yellow) { model.addSet(type: .warmUp) }
                WatchTag(text: localizedString("+ Set"), color: accent) { model.addSet(type: .work) }
                WatchTag(text: "+ Drop", color: .purple) { model.addSet(type: .dropSet) }
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
                }
            }
        }
        .padding(.horizontal, 5)
    }

    private func weightString(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Strength: summary page (volume per exercise)

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
                }

                WatchEndButton()
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Route: now & summary

struct WatchRouteNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel
    private var accent: Color { WatchTheme.accent(for: model.snapshot.widgetAccentColorName) }

    private var distanceKm: Double { model.routeDistanceKm ?? model.snapshot.routeDistanceKm ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                Text(String(format: "%.2f", distanceKm))
                    .font(.system(size: 44, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("km")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    WatchStatPill(title: localizedString("Time"), value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds), color: accent)
                    WatchStatPill(title: localizedString("Pace"), value: paceText, color: .orange)
                }

                HStack(spacing: 10) {
                    Button { model.togglePause() } label: {
                        Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(WatchCircleButtonStyle(color: model.state == .paused ? WatchTheme.success : WatchTheme.warning, size: 48))

                    Button { model.stop() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(WatchCircleButtonStyle(color: WatchTheme.destructive, size: 48))
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }

    private var paceText: String {
        guard let pace = model.routePaceSecondsPerKm ?? model.snapshot.routePaceSecondsPerKm, pace.isFinite, pace > 0 else { return "--" }
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))"
    }
}

struct WatchRouteSummaryView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchBigMetric(value: stepsText, label: localizedString("Steps"), icon: "shoeprints.fill", color: .green)
                    WatchBigMetric(value: speedText, label: "km/h", icon: "gauge.with.needle", color: .blue)
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

// MARK: - Interval: now & summary

struct WatchIntervalNowView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    private var phaseColor: Color { model.intervalIsWork ? .red : WatchTheme.success }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let preset = model.intervalPreset {
                    Text(model.intervalIsWork ? localizedString("WORK") : localizedString("REST"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(phaseColor)

                    Text("\(model.intervalPhaseRemaining)s")
                        .font(.system(size: 52, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(localizedFormat("Round %d/%d", min(model.intervalRound + 1, preset.rounds), preset.rounds))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        WatchStatPill(title: localizedString("Total"), value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds), color: .blue)
                        WatchStatPill(title: localizedString("Pulse"), value: hrText, color: WatchTheme.zoneColor(model.heartRateZone))
                    }

                    HStack(spacing: 10) {
                        Button { model.togglePause() } label: {
                            Image(systemName: model.state == .paused ? "play.fill" : "pause.fill")
                        }
                        .buttonStyle(WatchCircleButtonStyle(color: model.state == .paused ? WatchTheme.success : WatchTheme.warning, size: 44))

                        Button { model.skipIntervalPhase() } label: {
                            Image(systemName: "forward.fill")
                        }
                        .buttonStyle(WatchCircleButtonStyle(color: .blue, size: 44))

                        Button { model.stop() } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(WatchCircleButtonStyle(color: WatchTheme.destructive, size: 44))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 5)
            .padding(.bottom, 8)
        }
    }

    private var hrText: String { (model.heartRate ?? model.snapshot.heartRate).map { "\(Int($0))" } ?? "--" }
}

struct WatchIntervalSummaryView: View {
    @EnvironmentObject private var model: WatchWorkoutModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    WatchBigMetric(value: "\(min(model.intervalRound + 1, model.intervalPreset?.rounds ?? 0))", label: localizedString("round"), icon: "repeat", color: .red)
                    WatchBigMetric(value: kcalText, label: "kcal", icon: "flame.fill", color: .orange)
                    WatchBigMetric(value: hrText, label: "lpm", icon: "heart.fill", color: WatchTheme.zoneColor(model.heartRateZone))
                    WatchBigMetric(value: SharedWorkoutSnapshot.durationText(model.elapsedSeconds), label: localizedString("time"), icon: "timer", color: .blue)
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

// MARK: - Metrics page (shared)

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
                        WatchBigMetric(value: String(format: "%.2f", model.routeDistanceKm ?? model.snapshot.routeDistanceKm ?? 0), label: "km", icon: "location.fill", color: accent)
                        WatchBigMetric(value: stepsText, label: localizedString("steps"), icon: "shoeprints.fill", color: .green)
                    }
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

struct WatchValueStepper: View {
    let label: String
    let format: String
    let accent: Color
    let crownBinding: Binding<Double>
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
                .focusable(true)
                .digitalCrownRotation(
                    crownBinding,
                    from: 0, through: 1000, by: 0.5,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            HStack(spacing: 6) {
                Button(action: onDec) { Image(systemName: "minus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 28))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Button(action: onInc) { Image(systemName: "plus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 28))
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
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 28))
                Text("reps")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Button(action: onInc) { Image(systemName: "plus") }
                    .buttonStyle(WatchCircleButtonStyle(color: accent, size: 28))
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

    var body: some View {
        Button { model.stop() } label: {
            Label(localizedString("End"), systemImage: "stop.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: WatchTheme.buttonHeight)
        }
        .buttonStyle(.plain)
        .background(WatchTheme.destructive.opacity(0.16), in: RoundedRectangle(cornerRadius: WatchTheme.cardRadius, style: .continuous))
        .foregroundStyle(WatchTheme.destructive)
        .padding(.top, 4)
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

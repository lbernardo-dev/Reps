import MuscleMap
import SwiftUI

enum BatteryStyle: String, CaseIterable, Identifiable {
    case liquid = "liquid"
    case tech = "tech"
    case grid = "grid"

    var id: String { self.rawValue }

    func displayName(isSpanish: Bool) -> String {
        switch self {
        case .liquid:
            return localizedString("liquid_capsule")
        case .tech:
            return localizedString("tech_ring")
        case .grid:
            return localizedString("sci_fi_grid")
        }
    }

    func systemImage() -> String {
        switch self {
        case .liquid:
            return "battery.100percent.bolt"
        case .tech:
            return "gauge.with.needle"
        case .grid:
            return "square.grid.3x3.topleft.filled"
        }
    }
}

struct TrainingBatteryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStyle: BatteryStyle = .liquid
    @State private var simulationDelta: Double = 0.0 // Interactive projection slider delta

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }

    private var batteryStatus: FitnessMetrics.TrainingBatteryStatus {
        store.trainingBattery
    }

    private var batteryColor: Color {
        switch batteryStatus.state {
        case .charged:
            return PulseTheme.primaryBright
        case .steady:
            return PulseTheme.primary
        case .low:
            return PulseTheme.warning
        case .critical:
            return PulseTheme.destructive
        }
    }

    // MARK: - Recomputed Internal Physiological Balance Factors
    private var latestMetric: BodyMetric? {
        store.bodyMetrics.sorted { $0.date > $1.date }.first
    }

    private var restDays: Int {
        let calendar = Calendar.current
        let lastSession = store.workoutSessions.sorted { $0.date > $1.date }.first
        if let lastSession {
            return max(calendar.dateComponents([.day], from: calendar.startOfDay(for: lastSession.date), to: calendar.startOfDay(for: .now)).day ?? 0, 0)
        } else {
            return 2
        }
    }

    private var sleepCredit: Double {
        latestMetric?.sleepHours.map { clamp(($0 - 6) * 4, lower: -8, upper: 8) } ?? 0
    }

    private var hrvCredit: Double {
        store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.heartRateVariabilityMS.map { hrv in
            clamp((hrv - 45) / 8, lower: -5, upper: 6)
        } ?? 0
    }

    private var fatigueCredit: Double {
        latestMetric?.fatigue.map { clamp(Double(3 - $0) * 3, lower: -8, upper: 6) } ?? 0
    }

    private var restDaysCredit: Double {
        Double(restDays) * 11.0
    }

    private var decayedFatigue: Double {
        let calendar = Calendar.current
        let now = Date.now
        let recentSessions = store.workoutSessions.filter { $0.date >= calendar.date(byAdding: .day, value: -10, to: now) ?? now }
        return recentSessions.reduce(0.0) { total, session in
            let ageHours = max(now.timeIntervalSince(session.date) / 3_600, 0)
            let decay = pow(0.72, ageHours / 24)
            return total + FitnessMetrics.sessionBatteryCost(session) * decay
        }
    }

    private var planPressure: Double {
        let calendar = Calendar.current
        let now = Date.now
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let upcoming = store.scheduledWorkouts.filter { workout in
            workout.status == .scheduled
                && workout.date >= weekStart
                && workout.date <= (calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now)
        }
        let plannedDays = upcoming.isEmpty ? store.activePlan.days : upcoming.map(\.workoutDay)
        guard !plannedDays.isEmpty else { return 0 }
        let averageCost = plannedDays.reduce(0) { $0 + FitnessMetrics.workoutBatteryCost($1) } / Double(plannedDays.count)
        let frequencyPressure = max(Double(store.activePlan.daysPerWeek - 3), 0) * 1.8
        return clamp((averageCost / 10) + frequencyPressure, lower: 0, upper: 16)
    }

    private var wellnessPenalty: Double {
        let fatigue = Double(max((latestMetric?.fatigue ?? 3) - 3, 0)) * 5
        let stress = Double(max((latestMetric?.stress ?? 3) - 3, 0)) * 4
        let sleep = max(0, 6.5 - (latestMetric?.sleepHours ?? 7)) * 5
        let activeEnergy = store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.activeEnergyKcal ?? 0
        let activityPenalty = activeEnergy > 900 ? 5.0 : 0.0
        return fatigue + stress + sleep + activityPenalty
    }

    private var totalRecovery: Double {
        restDaysCredit + max(0, sleepCredit) + max(0, hrvCredit) + max(0, fatigueCredit)
    }

    private var totalFatigue: Double {
        decayedFatigue + planPressure + wellnessPenalty + max(0, -sleepCredit) + max(0, -hrvCredit) + max(0, -fatigueCredit)
    }

    // MARK: - Upcoming Workout Projection
    private var nextWorkout: WorkoutDay? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if let scheduled = store.scheduledWorkouts.first(where: { calendar.isDate($0.date, inSameDayAs: today) && $0.status == .scheduled }) {
            return scheduled.workoutDay
        }
        guard !store.activePlan.days.isEmpty else {
            return nil
        }
        return store.todaysWorkout
    }

    private var estimatedWorkoutCost: Double {
        if let nextWorkout {
            return FitnessMetrics.workoutBatteryCost(nextWorkout)
        }
        return 15.0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header navigation bar replacement
                customNavBar

                // Central showcase hero view
                ZStack {
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .fill(PulseTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                                .stroke(PulseTheme.separator, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.12), radius: 15, y: 8)

                    VStack(spacing: 20) {
                        // Title of current state
                        VStack(spacing: 4) {
                            Text(localizedString("energy_state"))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(2.0)
                                .foregroundStyle(PulseTheme.secondaryText)

                            Text(batteryStatus.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(batteryColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }

                        // Dynamic Hero Gauge
                        heroGauge
                            .frame(height: 220)
                            .padding(.vertical, 8)

                        // Coach instant suggestion
                        Text(batteryStatus.suggestion)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(.horizontal, 24)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 24)
                }
                .frame(height: 380)

                // Style Selector Carousel
                styleSelector

                // Biological Balance Panel (Fatigue vs Recovery)
                physiologicalBalanceSheet

                // Detailed Health factors grid
                detailedFactorsGrid

                // Upcoming Workout Projection Simulator
                workoutProjectionSimulator

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Navigation Bar
    private var customNavBar: some View {
        HStack {
            Button {
                HapticService.selection()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                    Text(localizedString("back_2"))
                        .font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(localizedString("training_battery"))
                .font(.system(size: 19, weight: .bold, design: .rounded))

            Spacer()

            // Empty placeholder for symmetry
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .opacity(0)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Hero Gauge Switcher
    @ViewBuilder
    private var heroGauge: some View {
        switch selectedStyle {
        case .liquid:
            LiquidCapsuleGauge(level: batteryStatus.level, color: batteryColor)
                .transition(.scale.combined(with: .opacity))
        case .tech:
            CircularTechGauge(level: batteryStatus.level, color: batteryColor, isSpanish: isSpanish, stateText: batteryStatus.state.rawValue.uppercased())
                .transition(.scale.combined(with: .opacity))
        case .grid:
            VerticalSegmentedPowerCell(level: batteryStatus.level, color: batteryColor)
                .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Style Selector Component
    private var styleSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("display_styles"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(BatteryStyle.allCases) { style in
                    let isSelected = selectedStyle == style
                    Button {
                        HapticService.selection()
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                            selectedStyle = style
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: style.systemImage())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(isSelected ? .black : PulseTheme.primary)

                            Text(style.displayName(isSpanish: isSpanish))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .black : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? PulseTheme.accent : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? PulseTheme.accent : PulseTheme.separator, lineWidth: 1.5)
                        )
                        .shadow(color: isSelected ? PulseTheme.accent.opacity(0.18) : .clear, radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Physiological Balance Sheet
    private var physiologicalBalanceSheet: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(localizedString("physiological_performance_balance"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(localizedString("your_battery_reflects_the_net_balance_between_recovery_and_accumulated_cellular"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .padding(.bottom, 4)

                // Visual horizontal scale
                VStack(spacing: 12) {
                    HStack {
                        Label(localizedString("recovery_3"), systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primaryBright)
                        Spacer()
                        Label(localizedString("fatigue_2"), systemImage: "bolt.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.destructive)
                    }

                    // Balance indicator bar
                    GeometryReader { geo in
                        let total = max(totalRecovery + totalFatigue, 1.0)
                        let recoveryPct = totalRecovery / total
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(PulseTheme.destructive.opacity(0.85))
                            Capsule()
                                .fill(PulseTheme.primaryBright)
                                .frame(width: geo.size.width * recoveryPct)
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())

                    HStack {
                        Text(String(format: "+%.0f pts", totalRecovery))
                            .font(.subheadline.bold())
                            .foregroundStyle(PulseTheme.primaryBright)
                        Spacer()
                        Text(String(format: "-%.0f pts", totalFatigue))
                            .font(.subheadline.bold())
                            .foregroundStyle(PulseTheme.destructive)
                    }
                }
                .padding(14)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                // Detailed breakdown lists stacked vertically
                VStack(spacing: 20) {
                    // Recovery metrics (+)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizedString("recovery_credits"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(PulseTheme.primaryBright)
                            .padding(.bottom, 2)

                        BalanceRow(label: localizedString("rest_days"), value: String(format: "+%.0f", restDaysCredit), icon: "calendar.badge.clock", color: PulseTheme.primaryBright)
                        BalanceRow(label: localizedString("hours_of_sleep"), value: String(format: "+%.0f", max(0, sleepCredit)), icon: "bed.double.fill", color: PulseTheme.primaryBright, active: sleepCredit > 0)
                        BalanceRow(label: localizedString("hrv_recovery"), value: String(format: "+%.0f", max(0, hrvCredit)), icon: "waveform.path.ecg", color: PulseTheme.primaryBright, active: hrvCredit > 0)
                        BalanceRow(label: localizedString("perceived_energy_stress"), value: String(format: "+%.0f", max(0, fatigueCredit)), icon: "face.smiling", color: PulseTheme.primaryBright, active: fatigueCredit > 0)
                    }

                    Divider()

                    // Fatigue metrics (-)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizedString("stress_loads"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(PulseTheme.destructive)
                            .padding(.bottom, 2)

                        BalanceRow(label: localizedString("decayed_fatigue"), value: String(format: "-%.0f", decayedFatigue), icon: "clock.arrow.circlepath", color: PulseTheme.destructive)
                        BalanceRow(label: localizedString("active_plan_pressure"), value: String(format: "-%.0f", planPressure), icon: "crown.fill", color: PulseTheme.destructive)
                        BalanceRow(label: localizedString("body_stress_and_wellness"), value: String(format: "-%.0f", wellnessPenalty), icon: "exclamationmark.triangle.fill", color: PulseTheme.destructive)

                        // Penalties as positive fatigue values
                        if sleepCredit < 0 {
                            BalanceRow(label: localizedString("sleep_penalty"), value: String(format: "-%.0f", -sleepCredit), icon: "moon.fill", color: PulseTheme.destructive)
                        } else if hrvCredit < 0 {
                            BalanceRow(label: localizedString("hrv_penalty"), value: String(format: "-%.0f", -hrvCredit), icon: "heart.broken.fill", color: PulseTheme.destructive)
                        } else if fatigueCredit < 0 {
                            BalanceRow(label: localizedString("felt_fatigue"), value: String(format: "-%.0f", -fatigueCredit), icon: "brain.headprofile", color: PulseTheme.destructive)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Detailed Factors Grid
    private var detailedFactorsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("wellness_metrics"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Today's session load
                MiniMetricTile(
                    title: "today_s_load",
                    value: String(format: "%.1f", batteryStatus.todayLoad),
                    subtitle: "points_computed",
                    systemImage: "calendar.badge.clock",
                    color: PulseTheme.primary
                )

                // Weekly aggregate load
                MiniMetricTile(
                    title: "weekly_load",
                    value: String(format: "%.1f", batteryStatus.weeklyLoad),
                    subtitle: "volume_intensity",
                    systemImage: "waveform.path.ecg",
                    color: PulseTheme.primaryBright
                )

                // Rest days since last workout
                MiniMetricTile(
                    title: "real_rest",
                    value: isSpanish ? "\(restDays) \(restDays == 1 ? "día" : "días")" : "\(restDays) \(restDays == 1 ? "day" : "days")",
                    subtitle: "since_last_session",
                    systemImage: "bed.double.fill",
                    color: PulseTheme.accent
                )

                // Heart Rate Variability (HRV) if synced
                let latestHRV = store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.heartRateVariabilityMS
                MiniMetricTile(
                    title: "HRV Promedio",
                    value: latestHRV != nil ? "\(Int(latestHRV!)) ms" : "--",
                    subtitle: "autonomic_system_state",
                    systemImage: "waveform.path.ecg.rectangle.fill",
                    color: PulseTheme.primaryBright
                )
            }
        }
    }

    // MARK: - Upcoming Workout Projection Simulator
    private var workoutProjectionSimulator: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.line.trend.down")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.primary)
                    Text(localizedString("session_impact_simulator"))
                        .font(.headline)
                }

                if let nextWorkout {
                    let cost = estimatedWorkoutCost
                    let originalLevel = batteryStatus.level
                    let currentSimLevel = max(5, Int(Double(originalLevel) - cost + simulationDelta))

                    VStack(alignment: .leading, spacing: 14) {
                        Text(localizedString("calculate_how_your_next_scheduled_workout_will_impact_your_training_battery"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)

                        // Workout metadata display
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(RepsText.workoutTitle(nextWorkout.title, language: store.userProfile.preferredLanguage))
                                    .font(.headline)
                                Text(RepsText.localizedWorkoutSubtitle(nextWorkout.subtitle, language: store.userProfile.preferredLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()

                            Text(String(format: "-%.0f%%", cost))
                                .font(.title3.bold())
                                .foregroundStyle(PulseTheme.destructive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(PulseTheme.destructive.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Level impact slider
                        VStack(spacing: 8) {
                            HStack {
                                Text(isSpanish ? "Actual: \(originalLevel)%" : "Current: \(originalLevel)%")
                                    .font(.caption.weight(.bold))
                                Spacer()
                                Text(isSpanish ? "Proyectado: \(currentSimLevel)%" : "Projected: \(currentSimLevel)%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(projectedColor(for: currentSimLevel))
                            }

                            // Visual bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(PulseTheme.separator).frame(height: 8)
                                    Capsule().fill(projectedColor(for: currentSimLevel))
                                        .frame(width: geo.size.width * CGFloat(currentSimLevel) / 100, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 4)

                        // Dynamic advice
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(projectedColor(for: currentSimLevel))
                                .font(.subheadline)

                            Text(projectedCoachingAdvice(for: currentSimLevel))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(projectedColor(for: currentSimLevel).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                } else {
                    Text(localizedString("no_session_planned_for_today_create_a_plan_or_schedule_a_workout_to_simulate_its"))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Helpers
    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private func projectedColor(for level: Int) -> Color {
        switch level {
        case 0..<30:
            return PulseTheme.destructive
        case 30..<55:
            return PulseTheme.warning
        case 55..<80:
            return PulseTheme.primary
        default:
            return PulseTheme.primaryBright
        }
    }

    private func projectedCoachingAdvice(for level: Int) -> String {
        if isSpanish {
            switch level {
            case 0..<30:
                return "Zona Crítica. Entrenar aquí puede causar sobreentrenamiento. Recomendamos posponer o cambiar a una sesión de estiramiento y descargar peso un 40%."
            case 30..<55:
                return "Zona Baja. Puedes entrenar, pero modera el esfuerzo. Mantén el RPE objetivo en 6-7 y descansa un mínimo de 3 minutos entre series."
            case 55..<80:
                return "Zona Estable. Entrena según lo programado. Asegúrate de descansar bien y completar los tiempos de pausa previstos en ejercicios principales."
            default:
                return "Zona Excelente. La homeostasis celular está al máximo. Tienes margen óptimo para empujar series pesadas e intentar sobrecarga progresiva."
            }
        } else {
            switch level {
            case 0..<30:
                return "Critical State. Training now increases injury risk. We strongly recommend postponing or switching to low-intensity mobility, and cutting loads by 40%."
            case 30..<55:
                return "Low State. You can train but reduce accessories. Keep RPE target around 6-7 and rest at least 3 minutes between primary heavy sets."
            case 55..<80:
                return "Steady State. Perfect for standard routine training. Execute according to plan and respect complete rest periods between compound movements."
            default:
                return "Prime State. Cellular homeostasis is fully restored. You have the optimal window to push intense sets and seek progressive overload."
            }
        }
    }
}

// MARK: - Row helper for physiological balance
private struct BalanceRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var active: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(active ? color.opacity(0.12) : PulseTheme.secondaryText.opacity(0.06))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? color : PulseTheme.secondaryText.opacity(0.6))
            }

            Text(localizedKey(label))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(active ? .primary : PulseTheme.secondaryText.opacity(0.8))
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(active ? color : PulseTheme.secondaryText.opacity(0.6))
        }
        .opacity(active ? 1.0 : 0.65)
    }
}

// MARK: - Detailed factor small widget
private struct MiniMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        PulseCard(minHeight: 110, contentPadding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 24, height: 24)
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(color)
                    }

                    Text(localizedKey(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)

                Text(localizedKey(subtitle))
                    .font(.system(size: 9))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - GAUGE STYLE 1: CYBERPUNK LIQUID CAPSULE GAUGE
struct LiquidCapsuleGauge: View {
    let level: Int
    let color: Color

    private let capsuleWidth: CGFloat = 100
    private let capsuleHeight: CGFloat = 180
    private let innerCapsuleWidth: CGFloat = 88
    private let innerCapsuleHeight: CGFloat = 168

    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date
            let time = date.timeIntervalSince1970

            ZStack {
                // Battery Frame Outline
                Capsule()
                    .stroke(PulseTheme.separator, lineWidth: 6)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .frame(width: capsuleWidth, height: capsuleHeight)
                    .shadow(color: color.opacity(0.18), radius: 10)

                // Metallic Pin on top
                RoundedRectangle(cornerRadius: 3)
                    .fill(PulseTheme.grouped)
                    .frame(width: 32, height: 10)
                    .offset(y: -95)

                // Internal sloshing liquid and bubbles share the same clipped capsule bounds.
                innerLiquidCapsule(time: time)

                // Glass shine / overlay
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear, .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 168)
                    .clipShape(Capsule())
                    .overlay(alignment: .topLeading) {
                        // Gloss specular shine line
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .padding(2)
                    }

                // Central bold level readout
                VStack(spacing: -2) {
                    Text("\(level)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 6)

                    Text("%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.55), radius: 4)
                }
            }
        }
    }

    private func innerLiquidCapsule(time: TimeInterval) -> some View {
        let normalizedLevel = CGFloat(level) / 100.0
        let fillHeight = innerCapsuleHeight * normalizedLevel

        return ZStack(alignment: .bottom) {
            LiquidWaveShape(phase: time * 3.5, level: normalizedLevel)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.72), color.opacity(0.92)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: innerCapsuleWidth, height: max(16, fillHeight + 10))
                .shadow(color: color.opacity(0.45), radius: 12)

            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<5) { index in
                        let xOffset = sin(time + Double(index) * 1.5) * 22
                        let yCycle = CGFloat((Int(time * 30.0) + index * 35) % 150)
                        let isInsideLiquid = yCycle < fillHeight

                        if isInsideLiquid {
                            Circle()
                                .fill(Color.white.opacity(0.38))
                                .frame(width: CGFloat(4 + (index % 3)), height: CGFloat(4 + (index % 3)))
                                .position(
                                    x: proxy.size.width / 2 + CGFloat(xOffset),
                                    y: proxy.size.height - yCycle
                                )
                        }
                    }
                }
            }
        }
        .frame(width: innerCapsuleWidth, height: innerCapsuleHeight)
        .clipShape(Capsule())
    }
}

// Wave shape for simulation
struct LiquidWaveShape: Shape {
    var phase: Double
    var level: CGFloat

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height

        let baseline = height * (1.0 - level)
        let waveHeight: CGFloat = level > 0.95 || level < 0.05 ? 0.0 : 6.0

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: baseline))

        // Draw a double sine wave curve
        for x in stride(from: 0, to: width + 1, by: 2) {
            let relativeX = x / width
            let sine = sin(relativeX * 2 * .pi + CGFloat(phase))
            let y = baseline + sine * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - GAUGE STYLE 2: CIRCULAR TECH RADIAL GAUGE
struct CircularTechGauge: View {
    let level: Int
    let color: Color
    let isSpanish: Bool
    let stateText: String

    var body: some View {
        ZStack {
            // Dashboard ticks and background track
            Circle()
                .stroke(PulseTheme.separator, lineWidth: 2)
                .frame(width: 190, height: 190)

            Circle()
                .stroke(PulseTheme.separator.opacity(0.4), style: StrokeStyle(lineWidth: 12, lineCap: .butt, dash: [2, 5]))
                .frame(width: 172, height: 172)

            // Neon glowing charging arc
            Circle()
                .trim(from: 0, to: CGFloat(level) / 100.0)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.3), color, color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 172, height: 172)
                .shadow(color: color.opacity(0.55), radius: 10)

            // Ticks overlay for cyber look
            Circle()
                .stroke(Color.black.opacity(0.22), style: StrokeStyle(lineWidth: 14, lineCap: .butt, dash: [1.5, 4]))
                .frame(width: 172, height: 172)

            // Central information hub
            VStack(spacing: 2) {
                Text(localizedString("level"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(PulseTheme.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(level)")
                        .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Text(stateText)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - GAUGE STYLE 3: SEGMENTED SCI-FI POWER CELL GAUGE
struct VerticalSegmentedPowerCell: View {
    let level: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            // Metallic top terminal
            RoundedRectangle(cornerRadius: 4)
                .fill(PulseTheme.grouped)
                .frame(width: 44, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(PulseTheme.separator, lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 2)

            // Outer casing
            VStack(spacing: 5) {
                let segments = 10
                let activeSegments = Int(Double(level) / 10.0)

                ForEach((0..<segments).reversed(), id: \.self) { index in
                    let isActive = index < activeSegments
                    let isPulsing = index == activeSegments && (level % 10 > 0)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? color : (isPulsing ? color.opacity(0.65) : color.opacity(0.12)))
                        .frame(width: 80, height: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(isActive ? .white.opacity(0.25) : .clear, lineWidth: 1)
                        )
                        .shadow(color: isActive ? color.opacity(0.48) : .clear, radius: 6, y: 1)
                        .scaleEffect(isPulsing ? 1.03 : 1.0)
                        .animation(isPulsing ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isPulsing)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.35))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(PulseTheme.separator, lineWidth: 3.5))
            )
            .frame(width: 104)
        }
    }
}

#Preview {
    let store = AppStore()
    return TrainingBatteryView()
        .environment(store)
}

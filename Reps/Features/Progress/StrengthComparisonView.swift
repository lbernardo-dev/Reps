import SwiftUI

// MARK: - Period stats model
private struct ExercisePeriodStats {
    let oneRepMaxKg: Double
    let maxWeightKg: Double
    let bestSessionVolumeKg: Double
    let sessionCount: Int

    var isEmpty: Bool { sessionCount == 0 }
}

private enum ComparisonVerdict {
    case stronger(pct: Double)
    case declining(pct: Double)
    case same
    case noData

    var label: String {
        let es = RepsLocalization.language.hasPrefix("es")
        switch self {
        case .stronger: return es ? "MÁS FUERTE" : "STRONGER"
        case .declining: return es ? "BAJANDO" : "DECLINING"
        case .same: return es ? "MISMO NIVEL" : "SAME LEVEL"
        case .noData: return es ? "SIN DATOS" : "NO DATA"
        }
    }

    var color: Color {
        switch self {
        case .stronger: return PulseTheme.primaryBright
        case .declining: return PulseTheme.destructive
        case .same: return PulseTheme.accent
        case .noData: return PulseTheme.secondaryText
        }
    }

    var systemImage: String {
        switch self {
        case .stronger: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .same: return "equal.circle.fill"
        case .noData: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Main View

struct StrengthComparisonView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedExercise: Exercise?

    private static let windowDays = 28
    private var now: Date { .now }
    private var currentStart: Date { Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: now) ?? now }
    private var previousEnd: Date { currentStart }
    private var previousStart: Date { Calendar.current.date(byAdding: .day, value: -Self.windowDays, to: previousEnd) ?? previousEnd }

    // MARK: - Data

    private var exercisesWithHistory: [Exercise] {
        let ids = Set(store.workoutSessions.flatMap { $0.exerciseLogs ?? [] }.map { $0.exercise.id })
        return store.exercises
            .filter { ids.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    private var filteredExercises: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return exercisesWithHistory }
        return exercisesWithHistory.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.muscleGroup.localizedCaseInsensitiveContains(q)
        }
    }

    private func periodStats(for exercise: Exercise, from start: Date, to end: Date) -> ExercisePeriodStats {
        let points = FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions)
            .filter { $0.date >= start && $0.date <= end }
        return ExercisePeriodStats(
            oneRepMaxKg: points.map(\.estimatedOneRepMaxKg).max() ?? 0,
            maxWeightKg: points.map(\.maxWeightKg).max() ?? 0,
            bestSessionVolumeKg: points.map(\.totalVolumeKg).max() ?? 0,
            sessionCount: points.count
        )
    }

    private func verdict(current: ExercisePeriodStats, previous: ExercisePeriodStats) -> ComparisonVerdict {
        guard !current.isEmpty else { return .noData }
        guard !previous.isEmpty else { return .noData }
        let delta = (current.oneRepMaxKg - previous.oneRepMaxKg) / max(previous.oneRepMaxKg, 1) * 100
        if delta > 1 { return .stronger(pct: delta) }
        if delta < -1 { return .declining(pct: abs(delta)) }
        return .same
    }

    private var weightUnit: String {
        store.userProfile.units == .metric ? "kg" : "lb"
    }

    private func display(_ kg: Double) -> Double {
        store.userProfile.units == .metric ? kg : UnitConverter.pounds(fromKilograms: kg)
    }

    private func formatWeight(_ kg: Double) -> String {
        kg > 0 ? String(format: "%.1f", display(kg)) : "--"
    }

    private func deltaText(current: Double, previous: Double) -> String? {
        guard previous > 0, current > 0 else { return nil }
        let pct = (current - previous) / previous * 100
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", pct))%"
    }

    private func deltaColor(current: Double, previous: Double) -> Color {
        guard previous > 0, current > 0 else { return PulseTheme.secondaryText }
        let pct = (current - previous) / previous * 100
        if pct > 1 { return PulseTheme.primaryBright }
        if pct < -1 { return PulseTheme.destructive }
        return PulseTheme.secondaryText
    }

    private func shareText(exercise: Exercise, current: ExercisePeriodStats, previous: ExercisePeriodStats, v: ComparisonVerdict) -> String {
        let isES = RepsLocalization.language.hasPrefix("es")
        let name = exercise.name
        let orm = formatWeight(current.oneRepMaxKg)
        let unit = weightUnit
        switch v {
        case .stronger(let pct):
            return isES
                ? "💪 Soy más fuerte en \(name)! 1RM: \(orm) \(unit) (+\(Int(pct))% vs hace 4 semanas). #Reps"
                : "💪 I got stronger in \(name)! 1RM: \(orm) \(unit) (+\(Int(pct))% vs 4 weeks ago). #Reps"
        case .declining(let pct):
            return isES
                ? "📉 Trabajo pendiente en \(name). 1RM: \(orm) \(unit) (-\(Int(pct))% vs hace 4 semanas). #Reps"
                : "📉 Work in progress in \(name). 1RM: \(orm) \(unit) (-\(Int(pct))% vs 4 weeks ago). #Reps"
        default:
            return isES
                ? "🏋️ Mi fuerza en \(name) se mantiene: \(orm) \(unit). #Reps"
                : "🏋️ Holding strong in \(name): \(orm) \(unit). #Reps"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                customNavBar

                introCard

                if let exercise = selectedExercise {
                    let current = periodStats(for: exercise, from: currentStart, to: now)
                    let previous = periodStats(for: exercise, from: previousStart, to: previousEnd)
                    let v = verdict(current: current, previous: previous)

                    comparisonCard(exercise: exercise, current: current, previous: previous, verdict: v)

                    ShareLink(item: shareText(exercise: exercise, current: current, previous: previous, v: v)) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text(RepsLocalization.language.hasPrefix("es") ? "Compartir reto" : "Share challenge")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                exercisePickerSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 60)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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
                    Text(RepsLocalization.language.hasPrefix("es") ? "Progreso" : "Progress")
                        .font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(RepsLocalization.language.hasPrefix("es") ? "Comparar fuerza" : "Compare strength")
                .font(.system(size: 19, weight: .bold, design: .rounded))

            Spacer()

            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).opacity(0)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Intro card

    private var introCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PulseTheme.primary.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PulseTheme.primary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(RepsLocalization.language.hasPrefix("es") ? "Tú vs tu yo anterior" : "You vs your past self")
                    .font(.headline)
                Text(RepsLocalization.language.hasPrefix("es")
                    ? "Últ. 4 semanas vs las 4 anteriores"
                    : "Last 4 weeks vs the 4 before that")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PulseTheme.separator, lineWidth: 1))
    }

    // MARK: - Comparison card

    private func comparisonCard(
        exercise: Exercise,
        current: ExercisePeriodStats,
        previous: ExercisePeriodStats,
        verdict v: ComparisonVerdict
    ) -> some View {
        PulseCard {
            VStack(spacing: 16) {
                // Exercise + verdict
                VStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    HStack(spacing: 8) {
                        Image(systemName: v.systemImage)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(v.color)
                        Text(v.label)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(v.color)

                        if case .stronger(let pct) = v {
                            Text("+\(Int(pct))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(v.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(v.color.opacity(0.12))
                                .clipShape(Capsule())
                        } else if case .declining(let pct) = v {
                            Text("-\(Int(pct))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(v.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(v.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider()

                // Column headers
                HStack {
                    Text(RepsLocalization.language.hasPrefix("es") ? "Métrica" : "Metric")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    Text(RepsLocalization.language.hasPrefix("es") ? "Ahora" : "Now")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                        .frame(width: 72, alignment: .center)
                    Text(RepsLocalization.language.hasPrefix("es") ? "Antes" : "Before")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(width: 72, alignment: .center)
                }

                // Rows
                comparisonRow(
                    title: RepsLocalization.language.hasPrefix("es") ? "1RM Estimado" : "Est. 1RM",
                    systemImage: "trophy.fill",
                    color: PulseTheme.accent,
                    currentVal: current.oneRepMaxKg,
                    previousVal: previous.oneRepMaxKg
                )
                comparisonRow(
                    title: RepsLocalization.language.hasPrefix("es") ? "Peso máximo" : "Max weight",
                    systemImage: "scalemass.fill",
                    color: PulseTheme.primary,
                    currentVal: current.maxWeightKg,
                    previousVal: previous.maxWeightKg
                )
                comparisonRow(
                    title: RepsLocalization.language.hasPrefix("es") ? "Volumen/sesión" : "Volume/session",
                    systemImage: "chart.bar.fill",
                    color: PulseTheme.primaryBright,
                    currentVal: current.bestSessionVolumeKg,
                    previousVal: previous.bestSessionVolumeKg
                )

                // Session counts
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                    let es = RepsLocalization.language.hasPrefix("es")
                    Text(es
                        ? "\(current.sessionCount) sesiones ahora · \(previous.sessionCount) antes"
                        : "\(current.sessionCount) sessions now · \(previous.sessionCount) before")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
            }
        }
    }

    private func comparisonRow(
        title: String,
        systemImage: String,
        color: Color,
        currentVal: Double,
        previousVal: Double
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            // Current value
            VStack(spacing: 1) {
                Text(formatWeight(currentVal))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(currentVal > 0 ? .primary : PulseTheme.secondaryText)
                Text(currentVal > 0 ? weightUnit : "")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .frame(width: 72, alignment: .center)

            // Previous value + delta
            VStack(spacing: 1) {
                Text(formatWeight(previousVal))
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
                if let dt = deltaText(current: currentVal, previous: previousVal) {
                    Text(dt)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(deltaColor(current: currentVal, previous: previousVal))
                }
            }
            .frame(width: 72, alignment: .center)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Exercise Picker

    private var exercisePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)
                Text(RepsLocalization.language.hasPrefix("es") ? "Ejercicios con historial" : "Exercises with history")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PulseTheme.secondaryText)
                    .font(.subheadline)
                TextField(
                    RepsLocalization.language.hasPrefix("es") ? "Buscar ejercicio..." : "Search exercise...",
                    text: $searchText
                )
                .font(.subheadline)
                .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            if filteredExercises.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: RepsLocalization.language.hasPrefix("es") ? "Sin historial aún" : "No history yet",
                        message: RepsLocalization.language.hasPrefix("es")
                            ? "Completa entrenamientos con ejercicios de fuerza para ver la comparación."
                            : "Complete strength workouts to see the comparison.",
                        systemImage: "dumbbell"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                PulseCard {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { idx, exercise in
                            Button {
                                HapticService.selection()
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedExercise = selectedExercise?.id == exercise.id ? nil : exercise
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(exercise.muscleGroup)
                                            .font(.caption)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: selectedExercise?.id == exercise.id ? "checkmark.circle.fill" : "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(selectedExercise?.id == exercise.id ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.5))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.plain)

                            if idx < filteredExercises.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StrengthComparisonView()
            .environment(AppStore())
    }
}

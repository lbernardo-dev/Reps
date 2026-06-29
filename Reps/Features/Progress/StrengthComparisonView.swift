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
        switch self {
        case .stronger: return localizedString("comparison_verdict_stronger")
        case .declining: return localizedString("comparison_verdict_declining")
        case .same: return localizedString("comparison_verdict_same")
        case .noData: return localizedString("comparison_verdict_no_data")
        }
    }

    var color: Color {
        switch self {
        case .stronger: return PulseTheme.ringStand
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
        if pct > 1 { return PulseTheme.ringStand }
        if pct < -1 { return PulseTheme.destructive }
        return PulseTheme.secondaryText
    }

    private func shareText(exercise: Exercise, current: ExercisePeriodStats, previous: ExercisePeriodStats, v: ComparisonVerdict) -> String {
        let name = exercise.name
        let orm = formatWeight(current.oneRepMaxKg)
        let unit = weightUnit
        switch v {
        case .stronger(let pct):
            return localizedFormat("comparison_share_stronger_format", name, orm, unit, Int(pct))
        case .declining(let pct):
            return localizedFormat("comparison_share_declining_format", name, orm, unit, Int(pct))
        default:
            return localizedFormat("comparison_share_steady_format", name, orm, unit)
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
                            Text(localizedString("comparison_share_challenge"))
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
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .navigationGlassCircle(.secondary)
                    Text(localizedString("comparison_back_progress"))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text(localizedString("comparison_title"))
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
                    .fill(PulseTheme.accent.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "chart.bar.xaxis.ascending")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PulseTheme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedString("comparison_intro_title"))
                    .font(.headline)
                Text(localizedString("comparison_intro_subtitle"))
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
                    Text(localizedString("comparison_col_metric"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    Text(localizedString("comparison_col_now"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                        .frame(width: 72, alignment: .center)
                    Text(localizedString("comparison_col_before"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(width: 72, alignment: .center)
                }

                // Rows
                comparisonRow(
                    title: localizedString("comparison_row_1rm"),
                    systemImage: "trophy.fill",
                    color: PulseTheme.accent,
                    currentVal: current.oneRepMaxKg,
                    previousVal: previous.oneRepMaxKg
                )
                comparisonRow(
                    title: localizedString("comparison_row_max_weight"),
                    systemImage: "scalemass.fill",
                    color: PulseTheme.accent,
                    currentVal: current.maxWeightKg,
                    previousVal: previous.maxWeightKg
                )
                comparisonRow(
                    title: localizedString("comparison_row_volume_session"),
                    systemImage: "chart.bar.fill",
                    color: PulseTheme.ringStand,
                    currentVal: current.bestSessionVolumeKg,
                    previousVal: previous.bestSessionVolumeKg
                )

                // Session counts
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(localizedFormat("comparison_sessions_format", current.sessionCount, previous.sessionCount))
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
                    .foregroundStyle(PulseTheme.accent)
                Text(localizedString("comparison_exercises_with_history"))
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PulseTheme.secondaryText)
                    .font(.subheadline)
                TextField(
                    localizedString("comparison_search_placeholder"),
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
                        title: LocalizedStringKey("comparison_no_history_title"),
                        message: LocalizedStringKey("comparison_no_history_msg"),
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
                                        .foregroundStyle(selectedExercise?.id == exercise.id ? PulseTheme.accent : PulseTheme.secondaryText.opacity(0.5))
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

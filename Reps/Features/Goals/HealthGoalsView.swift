import SwiftUI

// MARK: - HealthGoalsView

/// Settings › Goals section — shows current health targets and opens per-goal pickers.
struct HealthGoalsView: View {
    @Environment(AppStore.self) private var store
    @State private var activeSheet: HealthGoalSheet?

    var body: some View {
        PulseCard {
            VStack(spacing: 0) {
                goalRow(
                    icon: "moon.stars.fill",
                    tint: .purple,
                    title: localizedTitle("sleep_target"),
                    value: String(format: "%.1g h", store.userProfile.sleepTargetHours)
                ) { activeSheet = .sleep }

                separator

                goalRow(
                    icon: "dumbbell.fill",
                    tint: PulseTheme.accent,
                    title: localizedTitle("workouts_per_week"),
                    value: "\(store.userProfile.weeklyTrainingDays) \(localizedString("days"))"
                ) { activeSheet = .workoutsPerWeek }

                separator

                goalRow(
                    icon: "flame.fill",
                    tint: .orange,
                    title: localizedTitle("daily_calories"),
                    value: calorieDisplayValue
                ) { activeSheet = .calories }

                separator

                goalRow(
                    icon: "drop.fill",
                    tint: .cyan,
                    title: localizedTitle("water"),
                    value: waterDisplayValue
                ) { activeSheet = .water }

                separator

                goalRow(
                    icon: "figure.walk",
                    tint: PulseTheme.growth,
                    title: localizedTitle("steps"),
                    value: "\(store.userProfile.dailyStepsGoal.formatted())"
                ) { activeSheet = .steps }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Row

    private func goalRow(icon: String, tint: Color, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(localizedTitleText(title))
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(value)
                    .font(.body)
                    .foregroundStyle(PulseTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText.opacity(0.6))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringButtonStyle())
    }

    private var separator: some View {
        Divider()
            .overlay(PulseTheme.separator)
            .padding(.leading, 52)
    }

    // MARK: - Display helpers

    private var calorieDisplayValue: String {
        let profile = store.userProfile
        if let explicit = profile.dailyCalorieGoalKcal {
            return "\(explicit) kcal"
        }
        let auto = Int(store.caloriesForGoalType(profile.calorieGoalType))
        return auto > 0 ? "\(auto) kcal" : "—"
    }

    private var waterDisplayValue: String {
        let liters = store.userProfile.dailyWaterGoalLiters
        let units = store.userProfile.units
        if units == .metric {
            return liters >= 1 ? String(format: "%.1f L", liters) : String(format: "%d ml", Int(liters * 1000))
        } else {
            let flOz = liters * 33.814
            return String(format: "%.0f fl oz", flOz)
        }
    }

    // MARK: - Sheet dispatcher

    @ViewBuilder
    private func sheetContent(for sheet: HealthGoalSheet) -> some View {
        switch sheet {
        case .sleep:         SleepTargetPicker()
        case .workoutsPerWeek: WorkoutsPerWeekPicker()
        case .calories:      CalorieGoalPicker()
        case .water:         WaterGoalPicker()
        case .steps:         StepsGoalPicker()
        }
    }
}

// MARK: - Sheet enum

private enum HealthGoalSheet: String, Identifiable {
    case sleep, workoutsPerWeek, calories, water, steps
    var id: String { rawValue }
}

// MARK: - Spring button style (micro-interaction)

struct SpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Shared picker shell

private struct GoalPickerShell<Content: View>: View {
    let title: String
    let onConfirm: () -> Void
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, onConfirm: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.onConfirm = onConfirm
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    HapticService.impact(.light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(PulseTheme.grouped.opacity(0.72))
                        .clipShape(Circle())
                        .foregroundStyle(PulseTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(localizedTitleText(title))
                    .font(.headline)
                    .foregroundStyle(PulseTheme.textPrimary)

                Spacer()

                Button {
                    HapticService.impact(.medium)
                    onConfirm()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(PulseTheme.accent.opacity(0.25))
                        .clipShape(Circle())
                        .foregroundStyle(PulseTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Big number display

private struct BigValueDisplay: View {
    let value: String
    let unit: String
    let description: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 68, weight: .heavy, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: value)

            Text(unit.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .kerning(1.5)

            if let description {
                Text(localizedTitleText(description))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(PulseTheme.grouped.opacity(0.72))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Preset grid button

private struct PresetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            Text(localizedTitleText(label))
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isSelected ? .white : .white.opacity(0.08))
                .foregroundStyle(isSelected ? .black : .white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Stepper row (+/-)

private struct StepperRow: View {
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            stepButton(icon: "minus", action: onDecrement)
            stepButton(icon: "plus", action: onIncrement)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticService.selection()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 54, height: 54)
                .background(PulseTheme.grouped.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .foregroundStyle(PulseTheme.textPrimary)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - 1. Sleep Target Picker

struct SleepTargetPicker: View {
    @Environment(AppStore.self) private var store
    @State private var selected: Double = 7.0

    private let options: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        GoalPickerShell(title: localizedTitle("sleep_target")) {
            store.userProfile.sleepTargetHours = selected
        }
        content: {
            BigValueDisplay(
                value: selected.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", selected)
                    : String(format: "%.1f", selected),
                unit: localizedString("hours_night"),
                description: sleepDescription(for: selected)
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(options, id: \.self) { h in
                    PresetButton(
                        label: h.truncatingRemainder(dividingBy: 1) == 0
                            ? String(format: "%.0f h", h)
                            : String(format: "%.1f h", h),
                        isSelected: selected == h
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            selected = h
                        }
                    }
                }
            }

            // Apple Health badge
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text(localizedString("linked_to_apple_health_sleep"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.top, 12)

            // Recovery battery note
            HStack(spacing: 6) {
                Image(systemName: "battery.75")
                    .foregroundStyle(PulseTheme.accent)
                    .font(.caption)
                Text(localizedString("sleep_target_affects_recovery_battery"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.top, 2)
        }
        .onAppear { selected = store.userProfile.sleepTargetHours }
    }

    private func sleepDescription(for hours: Double) -> String {
        switch hours {
        case ..<6:    return localizedString("sleep_desc_very_low")
        case 6..<6.5: return localizedString("sleep_desc_low")
        case 6.5..<7: return localizedString("sleep_desc_moderate")
        case 7..<8:   return localizedString("sleep_desc_sweet_spot")
        case 8..<9:   return localizedString("sleep_desc_great")
        default:      return localizedString("sleep_desc_high")
        }
    }
}

// MARK: - 2. Workouts Per Week Picker

struct WorkoutsPerWeekPicker: View {
    @Environment(AppStore.self) private var store
    @State private var selected: Int = 4

    var body: some View {
        GoalPickerShell(title: localizedTitle("workouts_per_week")) {
            store.userProfile.weeklyTrainingDays = selected
        }
        content: {
            BigValueDisplay(
                value: "\(selected)",
                unit: localizedString("workouts_week"),
                description: workoutsDescription(for: selected)
            )

            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { n in
                    PresetButton(label: "\(n)", isSelected: selected == n) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            selected = n
                        }
                    }
                }
            }
        }
        .onAppear { selected = store.userProfile.weeklyTrainingDays }
    }

    private func workoutsDescription(for n: Int) -> String {
        switch n {
        case 1...2: return localizedString("workouts_desc_low")
        case 3:     return localizedString("workouts_desc_moderate")
        case 4:     return localizedString("workouts_desc_optimal")
        case 5:     return localizedString("workouts_desc_high")
        default:    return localizedString("workouts_desc_elite")
        }
    }
}

// MARK: - 3. Calorie Goal Picker

struct CalorieGoalPicker: View {
    @Environment(AppStore.self) private var store
    @State private var goalType: UserProfile.CalorieGoalType = .recomposition
    @State private var kcal: Int = 2000
    private let range: ClosedRange<Double> = 1200...5000

    var body: some View {
        GoalPickerShell(title: localizedTitle("daily_calories")) {
            store.userProfile.calorieGoalType = goalType
            store.userProfile.dailyCalorieGoalKcal = kcal
        }
        content: {
            // BMR/TDEE info card
            let bmr = store.basalMetabolicRate
            let tdee = store.maintenanceCalories
            if bmr > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    metricRow("BMR", value: String(format: "%.0f kcal", bmr))
                    Divider().overlay(PulseTheme.separator)
                    metricRow(localizedString("tdee_label"), value: String(format: "%.0f kcal", tdee))
                    Divider().overlay(PulseTheme.separator)
                    metricRow(localizedString("activity_level"), value: activityLabel)
                    Text(localizedString("bmr_tdee_description"))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.top, 4)
                }
                .padding(14)
                .background(PulseTheme.grouped.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .padding(.bottom, 4)
            }

            Text(localizedString("what_do_you_want_to_achieve").uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .kerning(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(UserProfile.CalorieGoalType.allCases) { type in
                    PresetButton(label: type.localizedLabel, isSelected: goalType == type) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            goalType = type
                            kcal = Int(store.caloriesForGoalType(type))
                        }
                    }
                }
            }

            BigValueDisplay(
                value: kcal.formatted(),
                unit: localizedString("kcal_day"),
                description: calorieDescription(for: kcal, tdee: tdee)
            )

            StepperRow {
                withAnimation { kcal = max(1200, kcal - 50) }
            } onIncrement: {
                withAnimation { kcal = min(5000, kcal + 50) }
            }

            Slider(value: Binding(
                get: { Double(kcal) },
                set: { kcal = Int($0); HapticService.selection() }
            ), in: range, step: 50)
            .tint(PulseTheme.accent)

            HStack {
                Text("1.200").font(.caption).foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Text("5.000").font(.caption).foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .onAppear {
            goalType = store.userProfile.calorieGoalType
            kcal = store.userProfile.dailyCalorieGoalKcal
                ?? Int(store.caloriesForGoalType(store.userProfile.calorieGoalType))
        }
    }

    private var activityLabel: String {
        let days = store.userProfile.weeklyTrainingDays
        switch days {
        case 0...1: return localizedString("activity_sedentary")
        case 2...3: return localizedString("activity_lightly_active")
        case 4...5: return localizedString("activity_moderately_active")
        default:    return localizedString("activity_very_active")
        }
    }

    private func metricRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(PulseTheme.textPrimary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(PulseTheme.textPrimary)
        }
    }

    private func calorieDescription(for kcal: Int, tdee: Double) -> String? {
        guard tdee > 0 else { return nil }
        let diff = Double(kcal) - tdee
        switch diff {
        case ..<(-300):  return localizedString("calorie_desc_deficit")
        case -300..<(-50): return localizedString("calorie_desc_mild_deficit")
        case -50..<50:   return localizedString("calorie_desc_maintenance")
        case 50..<300:   return localizedString("calorie_desc_mild_surplus")
        default:         return localizedString("calorie_desc_surplus")
        }
    }
}

// MARK: - 4. Water Goal Picker

struct WaterGoalPicker: View {
    @Environment(AppStore.self) private var store
    @State private var liters: Double = 2.5

    private let presets: [Double] = [1.5, 2.0, 2.5, 3.0, 3.5]
    private let range: ClosedRange<Double> = 1.5...6.0
    private let step: Double = 0.1

    private var isMetric: Bool { store.userProfile.units == .metric }

    var body: some View {
        GoalPickerShell(title: localizedTitle("water")) {
            store.userProfile.dailyWaterGoalLiters = liters
        }
        content: {
            BigValueDisplay(
                value: displayValue,
                unit: isMetric ? "ml / \(localizedString("day"))" : "fl oz / \(localizedString("day"))",
                description: nil
            )

            StepperRow {
                withAnimation { liters = max(range.lowerBound, (liters - step * 2).rounded(toPlaces: 1)) }
            } onIncrement: {
                withAnimation { liters = min(range.upperBound, (liters + step * 2).rounded(toPlaces: 1)) }
            }

            Slider(value: $liters, in: range, step: step)
                .tint(.cyan)
                .onChange(of: liters) { _, _ in HapticService.selection() }

            HStack {
                Text(isMetric ? "1.500" : "51 fl oz").font(.caption).foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Text(isMetric ? "6.000" : "203 fl oz").font(.caption).foregroundStyle(PulseTheme.secondaryText)
            }

            Text(localizedString("quick_presets").uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .kerning(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    PresetButton(
                        label: isMetric
                            ? String(format: "%.1f L", preset)
                            : String(format: "%.0f oz", preset * 33.814),
                        isSelected: abs(liters - preset) < 0.05
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { liters = preset }
                    }
                }
            }
        }
        .onAppear { liters = store.userProfile.dailyWaterGoalLiters }
    }

    private var displayValue: String {
        if isMetric {
            return (liters * 1000).formatted()
        } else {
            return String(format: "%.0f", liters * 33.814)
        }
    }
}

// MARK: - 5. Steps Goal Picker

struct StepsGoalPicker: View {
    @Environment(AppStore.self) private var store
    @State private var steps: Int = 8_000

    private let presets = [5_000, 8_000, 10_000, 12_000, 15_000]
    private let range: ClosedRange<Double> = 2_000...25_000
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        GoalPickerShell(title: localizedTitle("steps")) {
            store.userProfile.dailyStepsGoal = steps
        }
        content: {
            BigValueDisplay(
                value: steps.formatted(),
                unit: localizedString("steps_day"),
                description: stepsDescription(for: steps)
            )

            StepperRow {
                withAnimation { steps = max(2_000, steps - 500) }
            } onIncrement: {
                withAnimation { steps = min(25_000, steps + 500) }
            }

            Slider(value: Binding(
                get: { Double(steps) },
                set: { steps = Int($0); HapticService.selection() }
            ), in: range, step: 500)
            .tint(PulseTheme.growth)

            HStack {
                Text("2.000").font(.caption).foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                Text("25.000").font(.caption).foregroundStyle(PulseTheme.secondaryText)
            }

            Text(localizedString("quick_presets").uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .kerning(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    PresetButton(
                        label: preset.formatted(),
                        isSelected: steps == preset
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { steps = preset }
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.red).font(.caption)
                Text(localizedString("steps_linked_to_apple_health"))
                    .font(.caption).foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.top, 8)
        }
        .onAppear { steps = store.userProfile.dailyStepsGoal }
    }

    private func stepsDescription(for n: Int) -> String {
        switch n {
        case ..<5_000:  return localizedString("steps_desc_sedentary")
        case 5_000..<8_000: return localizedString("steps_desc_low_active")
        case 8_000..<10_000: return localizedString("steps_desc_active")
        case 10_000..<15_000: return localizedString("steps_desc_very_active")
        default:        return localizedString("steps_desc_elite")
        }
    }
}

// MARK: - AppStore helpers

extension AppStore {
    func caloriesForGoalType(_ type: UserProfile.CalorieGoalType) -> Double {
        switch type {
        case .fatLoss:       return deficitCalories
        case .recomposition: return recompositionCalories
        case .strength:      return maintenanceCalories
        case .buildMuscle:   return leanBulkCalories
        }
    }

    var effectiveDailyCalorieGoal: Int {
        userProfile.dailyCalorieGoalKcal
            ?? Int(caloriesForGoalType(userProfile.calorieGoalType))
    }

    var effectiveDailyStepsGoal: Int { userProfile.dailyStepsGoal }
    var effectiveSleepTargetHours: Double { userProfile.sleepTargetHours }
    var effectiveWaterGoalLiters: Double { userProfile.dailyWaterGoalLiters }
}

// MARK: - Double rounding helper

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

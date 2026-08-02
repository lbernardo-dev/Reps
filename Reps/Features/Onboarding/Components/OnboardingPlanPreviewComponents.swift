import Charts
import MuscleMap
import SwiftUI

// MARK: - Plan Projection Card

struct PlanProjectionCard: View {
    let plan: WorkoutPlan
    let weeklySetTotal: Int
    let goal: UserProfile.MainGoal
    let experience: UserProfile.Experience
    let focusMuscles: [String]
    let locationID: String

    private struct WeekPoint: Identifiable {
        let id: Int
        let sets: Int
        let isDeload: Bool
    }

    private var projection: [WeekPoint] {
        let total = max(1, plan.totalWeeks)
        return (1...total).map { week in
            let mesoLen = 4
            let mesocycle = (week - 1) / mesoLen
            let weekInMeso = ((week - 1) % mesoLen) + 1
            let isDeload = weekInMeso == mesoLen && total >= 8
            let sets: Int
            if isDeload {
                sets = Int(Double(weeklySetTotal) * (1.0 + Double(mesocycle) * 0.12) * 0.68)
            } else {
                let factor = 1.0 + Double(mesocycle) * 0.12 + Double(weekInMeso - 1) * 0.05
                sets = Int(Double(weeklySetTotal) * factor)
            }
            return WeekPoint(id: week, sets: sets, isDeload: isDeload)
        }
    }

    private var axisWeeks: [Int] {
        let total = plan.totalWeeks
        if total <= 4 { return Array(1...total) }
        if total <= 8 { return [1, 4, total] }
        return Array(stride(from: 1, through: total, by: 4))
    }

    private struct TagEntry: Identifiable {
        let id: Int
        let icon: String
        let text: String
    }

    private var tags: [TagEntry] {
        var result: [TagEntry] = []
        result.append(TagEntry(id: 0, icon: goal.icon, text: goal.shortTitle))
        result.append(TagEntry(id: 1, icon: experience.icon, text: experience.shortLabel))
        if !focusMuscles.isEmpty {
            let label = focusMuscles.prefix(2).joined(separator: " · ")
            result.append(TagEntry(id: 2, icon: "sparkle", text: label))
        }
        let location = OnboardingLocationCatalog.location(for: locationID)
        result.append(TagEntry(id: 3, icon: location.icon, text: localizedString(location.titleKey)))
        return result
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedString("onboarding_plan_projection_title"))
                            .font(.headline)
                        Text(localizedString("onboarding_plan_projection_caption"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags) { tag in
                            Label(tag.text, systemImage: tag.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(PulseTheme.grouped)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }

                Chart(projection) { point in
                    BarMark(
                        x: .value("Week", point.id),
                        y: .value("Sets", point.sets),
                        width: .ratio(0.62)
                    )
                    .foregroundStyle(
                        point.isDeload
                            ? AnyShapeStyle(PulseTheme.ringStand.opacity(0.22))
                            : AnyShapeStyle(LinearGradient(
                                colors: [PulseTheme.ringStand.opacity(0.85), PulseTheme.accent],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                    )
                    .clipShape(.rect(cornerRadius: PulseTheme.smallRadius))

                    LineMark(
                        x: .value("Week", point.id),
                        y: .value("Sets", point.sets)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(PulseTheme.textPrimary.opacity(0.85))
                    .symbol {
                        Circle()
                            .fill(point.isDeload ? PulseTheme.ringStand : PulseTheme.textPrimary)
                            .frame(width: 5, height: 5)
                    }

                    AreaMark(
                        x: .value("Week", point.id),
                        y: .value("Sets", point.sets)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [PulseTheme.textPrimary.opacity(0.14), PulseTheme.textPrimary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(PulseTheme.secondaryText.opacity(0.14))
                        AxisValueLabel {
                            if let sets = value.as(Int.self) {
                                Text("\(sets)")
                                    .font(.caption2)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisWeeks) { value in
                        AxisValueLabel {
                            if let week = value.as(Int.self) {
                                Text(localizedString("onboarding_plan_wk") + "\(week)")
                                    .font(.caption2)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
        }
    }
}

// MARK: - Day 1 Preview Card

struct PlanDay1LockedPreviewCard: View {
    let day: WorkoutDay
    let gender: BodyGender
    let language: String
    let exercises: [Exercise]
    let isPro: Bool

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.title)
                            .font(.title3.weight(.bold))
                        Text(verbatim: localizedFormat("onboarding_plan_exer_dot_min_fmt", day.exercises.count, day.durationMinutes))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 36, height: 36)
                        .background(PulseTheme.accent)
                        .clipShape(Circle())
                }

                ForEach(Array(day.exercises.prefix(5).enumerated()), id: \.offset) { index, item in
                    PlanExerciseRow(
                        item: item,
                        gender: gender,
                        language: language,
                        exercises: exercises,
                        isLocked: !isPro && index > 0
                    )
                }

                if !isPro && day.exercises.count > 5 {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                        Text(verbatim: localizedFormat("onboarding_pro_more_exer_fmt", day.exercises.count - 5))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

// MARK: - Plan Exercise Row

struct PlanExerciseRow: View {
    let item: WorkoutExercise
    let gender: BodyGender
    let language: String
    let exercises: [Exercise]
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ExerciseMediaThumbnail(exercise: item.exercise, gender: gender, catalog: exercises)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isLocked ? PulseTheme.mediaScrimStrong.opacity(0.72) : Color.clear)
                )
                .overlay(
                    Image(systemName: "lock.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.mediaText)
                        .opacity(isLocked ? 1 : 0)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(RepsText.exerciseName(item.exercise.name, language: language))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                    .foregroundStyle(isLocked ? PulseTheme.secondaryText : .primary)

                if isLocked {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                        Text("onboarding_pro_sets_reps_load")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                } else {
                    Text(verbatim: localizedFormat("onboarding_pro_exercise_row_fmt", item.targetSets, item.repRange, item.previous))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Locked Days Card

struct PlanLockedDaysCard: View {
    let plan: WorkoutPlan
    let isPro: Bool

    var otherDays: [WorkoutDay] {
        Array(plan.days.dropFirst())
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(verbatim: localizedFormat("onboarding_plan_full_weeks_fmt", plan.totalWeeks))
                        .font(.headline)
                    Spacer()
                    if !isPro {
                        Text("PRO")
                            .font(.caption2.weight(.black))
                            .tracking(0.8)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 14)

                ForEach(Array(otherDays.prefix(isPro ? otherDays.count : 3).enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 10) {
                        if isPro {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PulseTheme.ringStand)
                        } else {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(PulseTheme.accent.opacity(0.7))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isPro ? .primary : PulseTheme.secondaryText)
                            Text(verbatim: localizedFormat("onboarding_plan_exer_dot_min_fmt", day.exercises.count, day.durationMinutes))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)

                    if index < min(otherDays.count, isPro ? otherDays.count : 3) - 1 {
                        Divider()
                            .overlay(PulseTheme.separator)
                    }
                }

                if !isPro && otherDays.count > 3 {
                    ZStack(alignment: .center) {
                        Rectangle()
                            .fill(PulseTheme.grouped.opacity(0.78))
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PulseTheme.accent)
                            Text(verbatim: localizedFormat("onboarding_plan_more_days_blk_fmt", otherDays.count - 3))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(PulseTheme.accent)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Unlock Pro Card

struct PlanUnlockProCard: View {
    let totalWeeks: Int
    let daysPerWeek: Int
    let onUnlock: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 40, height: 40)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("onboarding_pro_reps_pro")
                            .font(.headline)
                        Text("onboarding_pro_trial_detail")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 10) {
                    PlanBenefitRow(icon: "chart.line.uptrend.xyaxis", text: "onboarding_pro_benefit_overload")
                    PlanBenefitRow(icon: "scalemass.fill", text: "onboarding_pro_benefit_weights")
                    PlanBenefitRow(icon: "text.bubble.fill", text: "onboarding_pro_benefit_cues")
                    PlanBenefitRow(icon: "lock.open.fill", text: localizedFormat("onboarding_pro_all_days_fmt", daysPerWeek, totalWeeks))
                }

                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline.weight(.black))
                        Text("onboarding_pro_unlock_cta")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .background(PulseTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .pressableFeedback(scale: 0.97)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.5), lineWidth: 1.5)
        )
    }
}

struct PlanBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 18)
            Text(localizedString(text))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Onboarding Progress Body Hero

struct OnboardingProgressBodyHero: View {
    let goal: String
    let daysPerWeek: Int
    let minutes: Int

    private var progressHeatmap: [MuscleIntensity] {
        [
            MuscleIntensity(muscle: .chest, intensity: 0.92, color: .white.opacity(0.88)),
            MuscleIntensity(muscle: .upperChest, intensity: 1.0, color: .white),
            MuscleIntensity(muscle: .lowerChest, intensity: 0.82, color: .white.opacity(0.78)),
            MuscleIntensity(muscle: .upperBack, intensity: 0.96, color: .white.opacity(0.92)),
            MuscleIntensity(muscle: .rhomboids, intensity: 0.86, color: .white.opacity(0.80)),
            MuscleIntensity(muscle: .trapezius, intensity: 0.74, color: .white.opacity(0.68)),
            MuscleIntensity(muscle: .deltoids, intensity: 0.92, color: .white.opacity(0.88)),
            MuscleIntensity(muscle: .frontDeltoid, intensity: 0.84, color: .white.opacity(0.76)),
            MuscleIntensity(muscle: .rearDeltoid, intensity: 0.84, color: .white.opacity(0.76)),
            MuscleIntensity(muscle: .biceps, intensity: 0.78, color: .white.opacity(0.72)),
            MuscleIntensity(muscle: .triceps, intensity: 0.78, color: .white.opacity(0.72)),
            MuscleIntensity(muscle: .abs, intensity: 1.0, color: .white),
            MuscleIntensity(muscle: .upperAbs, intensity: 0.96, color: .white.opacity(0.90)),
            MuscleIntensity(muscle: .lowerAbs, intensity: 0.88, color: .white.opacity(0.82)),
            MuscleIntensity(muscle: .obliques, intensity: 0.80, color: .white.opacity(0.74)),
            MuscleIntensity(muscle: .quadriceps, intensity: 0.86, color: .white.opacity(0.80)),
            MuscleIntensity(muscle: .hamstring, intensity: 0.78, color: .white.opacity(0.72)),
            MuscleIntensity(muscle: .gluteal, intensity: 0.74, color: .white.opacity(0.68)),
            MuscleIntensity(muscle: .calves, intensity: 0.68, color: .white.opacity(0.62))
        ]
    }

    var body: some View {
        ZStack {
            backgroundGlow

            VStack(spacing: 10) {
                GeometryReader { proxy in
                    let modelWidth = min((proxy.size.width + 42) / 2, 186)

                    HStack(spacing: -42) {
                        bodyFigure(gender: .male, side: .front, scale: 1.18)
                            .frame(width: modelWidth, height: proxy.size.height)
                        bodyFigure(gender: .female, side: .back, scale: 0.94)
                            .frame(width: modelWidth, height: proxy.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .frame(height: 404)
                .padding(.top, 22)
                .padding(.horizontal, 4)

                HStack(spacing: 8) {
                    fatTrendBadge
                        .frame(width: 90, height: 58)
                    Spacer(minLength: 4)
                    strengthBadge
                        .frame(width: 90, height: 58)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strength and muscle progress preview")
    }

    private func bodyFigure(gender: BodyGender, side: BodySide, scale: CGFloat) -> some View {
        BodyView(gender: gender, side: side, style: .onboardingMonochromeProgress)
            .heatmap(progressHeatmap, configuration: .onboardingMonochromeProgress)
            .disabled(true)
            .accessibilityHidden(true)
            .scaleEffect(scale, anchor: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .shadow(color: .white.opacity(0.16), radius: 24)
            .shadow(color: .black.opacity(0.8), radius: 18, y: 14)
    }

    private var backgroundGlow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.055),
                            .white.opacity(0.018),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 72)
                .offset(y: -74)

            Circle()
                .stroke(.white.opacity(0.07), lineWidth: 1)
                .frame(width: 300, height: 300)
                .offset(x: -72, y: 28)
        }
    }

    private var strengthBadge: some View {
        VStack(spacing: 5) {
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.black))
            Text("Fuerza")
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(localizedString("muscle_plus"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.mediaSubtext.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(PulseTheme.mediaText)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PulseTheme.mediaText.opacity(0.08), in: RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous)
                .stroke(PulseTheme.mediaText.opacity(0.16), lineWidth: 1)
        }
    }

    private var fatTrendBadge: some View {
        VStack(spacing: 5) {
            Image(systemName: "arrow.down.forward")
                .font(.headline.weight(.black))
            Text("Grasa")
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("tendencia -")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.mediaSubtext.opacity(0.76))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(PulseTheme.mediaSubtext)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PulseTheme.mediaScrimStrong.opacity(0.45), in: RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous)
                .stroke(PulseTheme.mediaText.opacity(0.10), lineWidth: 1)
        }
    }
}

// MARK: - Onboarding Body Pair

struct OnboardingBodyPair: View {
    let gender: BodyGender
    var selectedMuscles: Set<Muscle> = []
    var heatmap: [MuscleIntensity] = []
    var onMuscleTap: ((Muscle) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: -28) {
                Spacer()
                bodyView(side: .front)
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.height)
                bodyView(side: .back)
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.height)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Muscle map")
    }

    private func bodyView(side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: .onboardingDark)
            .heatmap(heatmap, configuration: .onboardingHeatmap)
            .selected(selectedMuscles)
            .pulseSelected(speed: 1.2)
            .onMuscleSelected { muscle, _ in
                onMuscleTap?(muscle)
            }
            .allowsHitTesting(onMuscleTap != nil)
    }
}

// MARK: - Pressable Feedback Modifier

struct OnboardingPressableFeedback: ViewModifier {
    var pressedScale: CGFloat = 0.96
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticService.impact(.light)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func pressableFeedback(scale: CGFloat = 0.96) -> some View {
        modifier(OnboardingPressableFeedback(pressedScale: scale))
    }
}

// MARK: - Model Extensions

extension UserProfile.MainGoal {
    var title: String {
        switch self {
        case .buildMuscle: "onboarding_goal_build_muscle"
        case .bodyRecomposition: "onboarding_goal_recomp"
        case .loseFat: "onboarding_goal_lose_fat"
        case .getStronger: "onboarding_goal_get_stronger"
        case .stayActive: "onboarding_goal_stay_active"
        }
    }

    var shortTitle: String {
        switch self {
        case .buildMuscle: localizedString("onboarding_goal_build_muscle_short")
        case .bodyRecomposition: localizedString("onboarding_goal_recomp_short")
        case .loseFat: localizedString("onboarding_goal_lose_fat_short")
        case .getStronger: localizedString("onboarding_goal_get_stronger_short")
        case .stayActive: localizedString("onboarding_goal_stay_active_short")
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle: "onboarding_goal_build_muscle_sub"
        case .bodyRecomposition: "onboarding_goal_recomp_sub"
        case .loseFat: "onboarding_goal_lose_fat_sub"
        case .getStronger: "onboarding_goal_get_stronger_sub"
        case .stayActive: "onboarding_goal_stay_active_sub"
        }
    }

    var icon: String {
        switch self {
        case .buildMuscle: "dumbbell.fill"
        case .bodyRecomposition: "arrow.triangle.2.circlepath"
        case .loseFat: "flame.fill"
        case .getStronger: "bolt.fill"
        case .stayActive: "calendar.badge.checkmark"
        }
    }

    var tint: Color {
        switch self {
        case .buildMuscle: PulseTheme.accent
        case .bodyRecomposition: .white
        case .loseFat: PulseTheme.warning
        case .getStronger: PulseTheme.accent
        case .stayActive: PulseTheme.ringStand
        }
    }
}

extension UserProfile.Experience {
    var title: String {
        switch self {
        case .beginner: "onboarding_exp_beginner"
        case .intermediate: "onboarding_exp_intermediate"
        case .advanced: "onboarding_exp_advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: "onboarding_exp_beginner_sub"
        case .intermediate: "onboarding_exp_intermediate_sub"
        case .advanced: "onboarding_exp_advanced_sub"
        }
    }

    var icon: String {
        switch self {
        case .beginner: "figure.walk"
        case .intermediate: "figure.run"
        case .advanced: "figure.strengthtraining.traditional"
        }
    }

    var shortLabel: String {
        switch self {
        case .beginner: localizedString("onboarding_exp_beginner")
        case .intermediate: localizedString("onboarding_exp_intermediate")
        case .advanced: localizedString("onboarding_exp_advanced")
        }
    }
}

extension BodyViewStyle {
    static let onboardingDark = BodyViewStyle(
        defaultFillColor: PulseTheme.mediaText.opacity(0.16),
        strokeColor: PulseTheme.mediaScrimStrong.opacity(0.9),
        strokeWidth: 0.65,
        selectionColor: PulseTheme.accent,
        selectionStrokeColor: PulseTheme.mediaText,
        selectionStrokeWidth: 1.6,
        headColor: PulseTheme.mediaText.opacity(0.22),
        hairColor: PulseTheme.mediaText.opacity(0.10)
    )

    static let onboardingMonochromeProgress = BodyViewStyle(
        defaultFillColor: PulseTheme.mediaText.opacity(0.08),
        strokeColor: PulseTheme.mediaText.opacity(0.26),
        strokeWidth: 0.72,
        selectionColor: PulseTheme.mediaText,
        selectionStrokeColor: PulseTheme.mediaText,
        selectionStrokeWidth: 1.1,
        headColor: PulseTheme.mediaText.opacity(0.12),
        hairColor: PulseTheme.mediaText.opacity(0.05)
    )
}

extension HeatmapConfiguration {
    static let onboardingHeatmap = HeatmapConfiguration(
        colorScale: .repsVolume,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.55
    )

    static let onboardingMonochromeProgress = HeatmapConfiguration(
        colorScale: .repsMonochromeProgress,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.72
    )
}

extension HeatmapColorScale {
    static let repsVolume = HeatmapColorScale(colors: [
        PulseTheme.accent,
        PulseTheme.ringStand,
        PulseTheme.accent
    ])

    static let repsMonochromeProgress = HeatmapColorScale(colors: [
        .white.opacity(0.34),
        .white.opacity(0.70),
        .white
    ])
}

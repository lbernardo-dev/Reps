import Charts
import MuscleMap
import SwiftUI

// MARK: - Main Coordinator View

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store

    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .hero
    @State private var cachedPlan: WorkoutPlan?
    @State private var generationProgress = 0.0
    @State private var generationStatusText = localizedString("onboarding_gen_preparing")
    @State private var isGenerationComplete = false
    @State private var generationPulse = false
    @State private var generationTask: Task<Void, Never>?
    @State private var contentAppeared = false
    @State private var showingBackFromPlan = false

    var onFinish: (OnboardingResult) -> Void

    private var activeSteps: [OnboardingStep] {
        if draft.buildsOwnPlan {
            return [.hero, .value, .name, .setup, .goal, .equipment, .ready]
        }
        return OnboardingStep.allCases
    }

    private var stepIndex: Int {
        activeSteps.firstIndex(of: step) ?? 0
    }

    private var progressValue: Double {
        Double(stepIndex + 1) / Double(activeSteps.count)
    }

    private var bodyMetric: BodyMetric {
        BodyMetric(date: .now, weightKg: draft.weightKg, heightCm: draft.heightCm, source: .manual)
    }

    private var generatedPlan: WorkoutPlan {
        cachedPlan ?? buildPlan()
    }

    private var weeklySetTotal: Int {
        generatedPlan.days.flatMap(\.exercises).reduce(0) { $0 + $1.targetSets }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .hero && (step != .generating || isGenerationComplete) {
                OnboardingProgressHeader(
                    progress: progressValue,
                    currentStepIndex: stepIndex + 1,
                    totalSteps: activeSteps.count,
                    canGoBack: stepIndex > 0,
                    onBack: {
                        if step == .generating {
                            showingBackFromPlan = true
                        } else {
                            moveBackward()
                        }
                    }
                )
            }

            ScrollView(.vertical, showsIndicators: false) {
                stepContent
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    .padding(.top, 22)
                    .padding(.bottom, bottomContentPadding)
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .scaleEffect(contentAppeared ? 1 : 0.98, anchor: .top)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: contentAppeared)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .animation(.snappy(duration: 0.24), value: step)
        .animation(.snappy(duration: 0.24), value: isGenerationComplete)
        .onAppear {
            contentAppeared = true
        }
        .onChange(of: step) { _, newStep in
            contentAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                contentAppeared = true
            }
            if newStep == .generating {
                startPlanGeneration()
            } else {
                generationTask?.cancel()
            }
        }
        .onDisappear {
            generationTask?.cancel()
        }
        .alert(
            localizedString("onboarding_plan_back_title"),
            isPresented: $showingBackFromPlan
        ) {
            Button(localizedString("onboarding_plan_back_confirm"), role: .destructive) {
                isGenerationComplete = false
                moveBackward()
            }
            Button(localizedString("onboarding_plan_back_cancel"), role: .cancel) {}
        } message: {
            Text(localizedString("onboarding_plan_back_message"))
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .hero:
            OnboardingHeroStepView()
        case .value:
            OnboardingValueStepView(draft: $draft)
        case .name:
            OnboardingNameStepView(draft: $draft)
        case .setup:
            OnboardingSetupStepView(draft: $draft)
        case .goal:
            OnboardingGoalStepView(draft: $draft)
        case .timeline:
            OnboardingTimelineStepView(draft: $draft)
        case .experience:
            OnboardingExperienceStepView(draft: $draft)
        case .schedule:
            OnboardingScheduleStepView(draft: $draft)
        case .equipment:
            OnboardingEquipmentStepView(draft: $draft)
        case .baseline:
            OnboardingBaselineStepView(draft: $draft)
        case .focus:
            OnboardingFocusStepView(draft: $draft)
        case .generating:
            OnboardingGeneratingStepView(
                draft: $draft,
                generatedPlan: generatedPlan,
                weeklySetTotal: weeklySetTotal,
                isGenerationComplete: isGenerationComplete,
                generationProgress: generationProgress,
                generationStatusText: generationStatusText,
                generationPulse: generationPulse
            )
        case .ready:
            OnboardingReadyStepView(
                draft: $draft,
                generatedPlan: generatedPlan,
                weeklySetTotal: weeklySetTotal,
                onUnlockPro: {
                    store.presentPaywall(source: .onboarding, feature: nil, trigger: .onboarding)
                }
            )
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                primaryAction()
            } label: {
                Text(onboardingLocalizedString(step.primaryButtonTitle))
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(step == .generating && !isGenerationComplete ? .white.opacity(0.48) : .white)
                    .navigationGlassCapsule(step == .generating && !isGenerationComplete ? .disabled : .primary)
            }
            .buttonStyle(.plain)
            .disabled(step == .generating && !isGenerationComplete)
            .pressableFeedback(scale: 0.965)

            if step == .ready {
                Button {
                    finishOnboarding()
                } label: {
                    Text(onboardingLocalizedString(store.monetization.hasProAccess ? "onboarding_btn_start_with_plan" : "onboarding_btn_continue_free"))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .navigationGlassCapsule(.secondary)
                }
                .buttonStyle(.plain)
                .pressableFeedback(scale: 0.98)
            }

            // Privacy Note Badge
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(localizedString("onboarding_privacy_note"))
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(PulseTheme.secondaryText.opacity(0.85))
            .padding(.top, 2)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var bottomContentPadding: CGFloat {
        switch step {
        case .ready:
            128
        case .baseline, .equipment:
            120
        default:
            82
        }
    }

    private func primaryAction() {
        switch step {
        case .ready:
            finishOnboarding()
        default:
            moveForward()
        }
    }

    private func moveForward() {
        guard step != .ready else {
            finishOnboarding()
            return
        }
        if draft.buildsOwnPlan {
            switch step {
            case .setup:
                step = .goal
            case .goal:
                step = .equipment
            case .equipment:
                step = .ready
            default:
                let nextIdx = min(stepIndex + 1, activeSteps.count - 1)
                step = activeSteps[nextIdx]
            }
            return
        }
        let nextIdx = min(stepIndex + 1, activeSteps.count - 1)
        step = activeSteps[nextIdx]
    }

    private func moveBackward() {
        let prevIdx = max(stepIndex - 1, 0)
        step = activeSteps[prevIdx]
    }

    private func finishOnboarding() {
        onFinish(makeResult())
    }

    private func buildPlan() -> WorkoutPlan {
        let profile = draft.makeProfile()
        return OnboardingPlanBuilder.makePlan(
            profile: profile,
            bodyMetric: bodyMetric,
            sessionLengthMinutes: draft.sessionLengthMinutes,
            focusMuscles: Array(draft.focusMuscles)
        )
    }

    private func makeResult() -> OnboardingResult {
        var profile = draft.makeProfile()
        profile.onboardingCompleted = true
        guard !draft.buildsOwnPlan else {
            profile.dateOfBirth = nil
            profile.sex = nil
            return OnboardingResult(profile: profile, bodyMetric: nil, plan: nil, activatePlan: false)
        }
        let plan = cachedPlan ?? buildPlan()
        return OnboardingResult(
            profile: profile,
            bodyMetric: bodyMetric,
            plan: plan,
            activatePlan: true
        )
    }

    private func startPlanGeneration() {
        generationTask?.cancel()
        cachedPlan = buildPlan()
        generationProgress = 0.18
        generationStatusText = localizedString("onboarding_gen_saving")
        isGenerationComplete = false
        generationPulse = false

        generationTask = Task {
            let updates: [(delay: UInt64, progress: Double, text: String)] = [
                (450_000_000, 0.25, localizedString("onboarding_gen_filtering")),
                (900_000_000, 0.55, localizedString("onboarding_gen_adjusting")),
                (1_350_000_000, 0.82, localizedString("onboarding_gen_first_workout")),
                (1_800_000_000, 1.0, localizedString("onboarding_gen_ready"))
            ]

            for update in updates {
                try? await Task.sleep(nanoseconds: update.delay)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        generationProgress = update.progress
                        generationStatusText = update.text
                    }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.snappy(duration: 0.34)) {
                    isGenerationComplete = true
                }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    generationPulse = true
                }
            }
        }
    }
}

// MARK: - Onboarding String Localizer Helper

private func onboardingLocalizedString(_ key: String) -> String {
    let val = localizedString(key)
    return val.isEmpty ? key : val
}

// MARK: - WHO International Health & BMI Model (Adjusted by Sex)

struct HealthBMIMetrics {
    let bmi: Double
    let category: BMICategory
    let color: Color
    let title: String
    let subtitle: String

    enum BMICategory: String, CaseIterable {
        case underweight
        case normal
        case overweight
        case obesityClass1
        case obesityClass2Plus

        var icon: String {
            switch self {
            case .underweight: "bolt.shield.fill"
            case .normal: "checkmark.seal.fill"
            case .overweight: "exclamationmark.triangle.fill"
            case .obesityClass1: "heart.text.square.fill"
            case .obesityClass2Plus: "shield.trianglebadge.exclamationmark.fill"
            }
        }
    }

    static func calculate(heightCm: Double, weightKg: Double, sex: UserProfile.Sex? = .male) -> HealthBMIMetrics {
        let heightM = max(0.5, heightCm / 100.0)
        let bmi = weightKg / (heightM * heightM)
        let isFemale = (sex == .female)

        let category: BMICategory
        let color: Color
        let title: String
        let subtitle: String

        // Sex-adjusted WHO thresholds & localized advice from String Catalog
        switch bmi {
        case ..<18.5:
            category = .underweight
            color = Color(red: 0.3, green: 0.65, blue: 1.0)
            title = localizedString("bmi_underweight_title")
            subtitle = localizedString(isFemale ? "bmi_underweight_sub_female" : "bmi_underweight_sub_male")
        case 18.5..<25.0:
            category = .normal
            color = Color(red: 0.2, green: 0.85, blue: 0.45)
            title = localizedString("bmi_normal_title")
            subtitle = localizedString(isFemale ? "bmi_normal_sub_female" : "bmi_normal_sub_male")
        case 25.0..<30.0:
            category = .overweight
            color = Color(red: 0.95, green: 0.72, blue: 0.15)
            title = localizedString("bmi_overweight_title")
            subtitle = localizedString(isFemale ? "bmi_overweight_sub_female" : "bmi_overweight_sub_male")
        case 30.0..<35.0:
            category = .obesityClass1
            color = Color(red: 0.98, green: 0.48, blue: 0.12)
            title = localizedString("bmi_obesity1_title")
            subtitle = localizedString("bmi_obesity1_sub")
        default:
            category = .obesityClass2Plus
            color = Color(red: 0.92, green: 0.25, blue: 0.25)
            title = localizedString("bmi_obesity2_title")
            subtitle = localizedString("bmi_obesity2_sub")
        }

        return HealthBMIMetrics(
            bmi: bmi,
            category: category,
            color: color,
            title: title,
            subtitle: subtitle
        )
    }

    static func gradientStops(heightCm: Double, range: ClosedRange<Double>) -> [Gradient.Stop] {
        let heightM = max(1.0, heightCm / 100.0)
        let h2 = heightM * heightM

        let wUnder = 18.5 * h2
        let wNormal = 25.0 * h2
        let wOver = 30.0 * h2
        let wObese1 = 35.0 * h2

        let minW = range.lowerBound
        let maxW = range.upperBound
        let span = max(1.0, maxW - minW)

        func norm(_ w: Double) -> Double {
            min(max((w - minW) / span, 0.0), 1.0)
        }

        let blue = Color(red: 0.3, green: 0.65, blue: 1.0)
        let green = Color(red: 0.2, green: 0.85, blue: 0.45)
        let gold = Color(red: 0.95, green: 0.72, blue: 0.15)
        let orange = Color(red: 0.98, green: 0.48, blue: 0.12)
        let red = Color(red: 0.92, green: 0.25, blue: 0.25)

        return [
            .init(color: blue, location: 0.0),
            .init(color: blue, location: norm(wUnder * 0.92)),
            .init(color: green, location: norm(wUnder)),
            .init(color: green, location: norm((wUnder + wNormal) / 2)),
            .init(color: gold, location: norm(wNormal)),
            .init(color: orange, location: norm(wOver)),
            .init(color: red, location: norm(wObese1)),
            .init(color: red, location: 1.0)
        ]
    }
}

// MARK: - Onboarding Types & Draft

private enum OnboardingStep: String, CaseIterable, Identifiable {
    case hero
    case value
    case name
    case setup
    case goal
    case timeline
    case experience
    case schedule
    case equipment
    case baseline
    case focus
    case generating
    case ready

    var id: String { rawValue }

    var primaryButtonTitle: String {
        switch self {
        case .hero: "onboarding_btn_get_started"
        case .value: "onboarding_btn_start_setup"
        case .generating: "onboarding_btn_see_my_plan"
        case .ready: "onboarding_btn_unlock_plan"
        default: "onboarding_btn_continue"
        }
    }
}

private enum PlanHorizonMode: String, CaseIterable, Identifiable, Hashable {
    case lifestyle
    case specificEvent

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .lifestyle: "onboarding_horizon_lifestyle_title"
        case .specificEvent: "onboarding_horizon_event_title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .lifestyle: "onboarding_horizon_lifestyle_subtitle"
        case .specificEvent: "onboarding_horizon_event_subtitle"
        }
    }

    var icon: String {
        switch self {
        case .lifestyle: "infinity"
        case .specificEvent: "calendar.badge.clock"
        }
    }
}

private enum BodyMapPreference: String, CaseIterable, Identifiable {
    case mapA
    case mapB
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mapA: "onboarding_body_map_male"
        case .mapB: "onboarding_body_map_female"
        case .preferNotToSay: "onboarding_body_map_skip"
        }
    }

    var bodyGender: BodyGender {
        switch self {
        case .mapB: .female
        case .mapA, .preferNotToSay: .male
        }
    }

    var profileSex: UserProfile.Sex? {
        switch self {
        case .mapA: .male
        case .mapB: .female
        case .preferNotToSay: nil
        }
    }
}

private struct OnboardingDraft {
    var displayName: String = ""
    var mainGoal: UserProfile.MainGoal = .buildMuscle
    var targetHorizonMode: PlanHorizonMode = .lifestyle
    var targetEventName: String? = nil
    var targetEventDate: Date? = nil
    var experience: UserProfile.Experience = .intermediate
    var weeklyTrainingDays = 4
    var sessionLengthMinutes = 60
    var selectedLocationID = OnboardingLocationCatalog.defaultLocation.id
    var trainingLocation: UserProfile.TrainingLocation = OnboardingLocationCatalog.defaultLocation.profileLocation
    var availableEquipment: [String] = OnboardingLocationCatalog.defaultLocation.equipment
    var age = 32
    var heightCm = 178.0
    var weightKg = 78.0
    var bodyMapPreference: BodyMapPreference = .mapA
    var focusMuscles: Set<String> = []
    var preferredLanguage = UserProfile.deviceDefaultLanguage
    var buildsOwnPlan = false

    static let focusOptions = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

    static func localizedFocusKey(_ focus: String) -> String {
        switch focus {
        case "Chest":     return "muscle_group_chest"
        case "Back":      return "muscle_group_back"
        case "Shoulders": return "muscle_group_shoulders"
        case "Arms":      return "muscle_group_arms"
        case "Legs":      return "muscle_group_legs"
        case "Glutes":    return "muscle_group_glutes"
        case "Core":      return "muscle_group_core"
        default:          return localizedString(focus)
        }
    }

    mutating func applyLocation(_ location: OnboardingTrainingLocationOption) {
        selectedLocationID = location.id
        trainingLocation = location.profileLocation
        availableEquipment = location.equipment
    }

    mutating func toggleEquipment(_ equipment: String) {
        if availableEquipment.contains(equipment) {
            availableEquipment.removeAll { $0 == equipment }
        } else {
            availableEquipment.append(equipment)
        }

        if availableEquipment.isEmpty {
            availableEquipment = ["Bodyweight"]
        }
    }

    var allFocusSelected: Bool {
        Self.focusOptions.allSatisfy { focusMuscles.contains($0) }
    }

    mutating func toggleFocus(_ focus: String) {
        if focusMuscles.contains(focus) {
            focusMuscles.remove(focus)
        } else {
            focusMuscles.insert(focus)
        }
    }

    mutating func toggleAllFocus() {
        if allFocusSelected {
            focusMuscles.removeAll()
        } else {
            focusMuscles = Set(Self.focusOptions)
        }
    }

    func makeProfile() -> UserProfile {
        var profile = UserProfile()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmedName.isEmpty ? nil : trimmedName
        profile.mainGoal = mainGoal
        profile.experience = experience
        profile.weeklyTrainingDays = weeklyTrainingDays
        profile.preferredSessionLengthMinutes = sessionLengthMinutes
        profile.trainingLocation = trainingLocation
        profile.availableEquipment = normalizedEquipment
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        profile.sex = bodyMapPreference.profileSex
        profile.preferredLanguage = preferredLanguage

        if targetHorizonMode == .specificEvent {
            profile.targetEventName = targetEventName
            profile.targetEventDate = targetEventDate
        } else {
            profile.targetEventName = nil
            profile.targetEventDate = nil
        }
        return profile
    }

    private var normalizedEquipment: [String] {
        OnboardingLocationCatalog.normalizedEquipment(from: availableEquipment)
    }
}

// MARK: - Step Views

private struct OnboardingHeroStepView: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 64)

            ZStack {
                Circle()
                    .fill(.white.opacity(0.14))
                    .frame(width: 204, height: 204)
                    .blur(radius: 30)

                Image("StreakRepHeroIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 152, height: 152)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.18), radius: 26)
            }

            VStack(spacing: 14) {
                let brandText = Text("StreakReps")
                    .foregroundStyle(LinearGradient(
                        colors: [PulseTheme.accent, PulseTheme.warning],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                Text("\(Text(onboardingLocalizedString("onboarding_hero_meet")))\(brandText)\(Text(onboardingLocalizedString("onboarding_hero_partner")))")
                    .font(.system(size: 38, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.76)

                Text(onboardingLocalizedString("onboarding_hero_tagline"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingValueStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingTitle(
                title: "onboarding_value_title",
                subtitle: "onboarding_value_subtitle"
            )

            OnboardingProgressBodyHero(
                goal: draft.mainGoal.shortTitle,
                daysPerWeek: draft.weeklyTrainingDays,
                minutes: draft.sessionLengthMinutes
            )
            .frame(height: 480)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(onboardingLocalizedString("onboarding_results_disclaimer"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
        }
    }
}

private struct OnboardingNameStepView: View {
    @Binding var draft: OnboardingDraft
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingTitle(
                title: "onboarding_official_title",
                subtitle: "onboarding_official_subtitle"
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.title3)
                        .foregroundStyle(isNameFocused ? PulseTheme.accent : PulseTheme.secondaryText)

                    TextField(
                        onboardingLocalizedString("onboarding_name_placeholder"),
                        text: $draft.displayName
                    )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)

                    if !draft.displayName.isEmpty {
                        Button {
                            draft.displayName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(PulseTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isNameFocused ? PulseTheme.accent : Color.white.opacity(0.08), lineWidth: isNameFocused ? 2 : 1)
                )

                let firstName = UserProfile.firstName(from: draft.displayName)
                if !firstName.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                            .foregroundStyle(PulseTheme.accent)
                        Text(verbatim: String(format: onboardingLocalizedString("onboarding_nice_to_meet_you_format"), firstName))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(PulseTheme.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PulseTheme.accent.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
    }
}

private struct OnboardingSetupStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingTitle(
                title: onboardingLocalizedString("onboarding_setup_title"),
                subtitle: onboardingLocalizedString("onboarding_setup_subtitle")
            )

            VStack(spacing: 14) {
                OnboardingRichSetupOptionCard(
                    title: "onboarding_setup_create",
                    subtitle: "onboarding_setup_create_sub",
                    icon: "sparkles",
                    badgeText: onboardingLocalizedString("onboarding_setup_badge_recommended"),
                    badgeColor: PulseTheme.accent,
                    timeEstimate: onboardingLocalizedString("onboarding_setup_time_45s"),
                    features: [
                        "onboarding_setup_feat_overload",
                        "onboarding_setup_feat_anatomy",
                        "onboarding_setup_feat_weeks"
                    ],
                    isSelected: !draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = false
                }

                OnboardingRichSetupOptionCard(
                    title: "onboarding_setup_self",
                    subtitle: "onboarding_setup_self_sub",
                    icon: "wrench.fill",
                    badgeText: onboardingLocalizedString("onboarding_setup_badge_express"),
                    badgeColor: PulseTheme.ringStand,
                    timeEstimate: onboardingLocalizedString("onboarding_setup_time_instant"),
                    features: [
                        "onboarding_setup_feat_custom",
                        "onboarding_setup_feat_express",
                        "onboarding_setup_feat_pro"
                    ],
                    isSelected: draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = true
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(onboardingLocalizedString("onboarding_setup_footer_hint"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }
}

private struct OnboardingRichSetupOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let badgeText: String
    let badgeColor: Color
    let timeEstimate: String
    let features: [String]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: icon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isSelected ? PulseTheme.onColor(badgeColor) : badgeColor)
                        .frame(width: 48, height: 48)
                        .background(isSelected ? badgeColor : badgeColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(onboardingLocalizedString(title))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(badgeText)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(0.6)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .foregroundStyle(isSelected ? PulseTheme.onColor(badgeColor) : badgeColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(isSelected ? badgeColor : badgeColor.opacity(0.18))
                                .clipShape(Capsule())
                        }

                        Text(onboardingLocalizedString(subtitle))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isSelected ? .white : PulseTheme.tertiaryText)
                }

                Divider()
                    .overlay(PulseTheme.separator.opacity(0.6))

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(isSelected ? badgeColor : PulseTheme.ringStand)
                            Text(onboardingLocalizedString(feature))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.textPrimary.opacity(0.9))
                        }
                    }
                }

                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(timeEstimate)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .background(isSelected ? .white.opacity(0.08) : PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? badgeColor.opacity(0.9) : PulseTheme.separator, lineWidth: isSelected ? 2.0 : 1)
            )
            .shadow(color: isSelected ? badgeColor.opacity(0.22) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.965)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct OnboardingGoalStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_goal_title",
                subtitle: "onboarding_goal_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(UserProfile.MainGoal.allCases) { goal in
                    OnboardingOptionCard(
                        title: goal.title,
                        subtitle: goal.subtitle,
                        icon: goal.icon,
                        tint: goal.tint,
                        isSelected: draft.mainGoal == goal
                    ) {
                        draft.mainGoal = goal
                    }
                }
            }
        }
    }
}

private struct OnboardingTimelineStepView: View {
    @Binding var draft: OnboardingDraft

    private var minimumEventDate: Date {
        Calendar.current.date(byAdding: .day, value: 28, to: .now) ?? .now
    }

    private var maximumEventDate: Date {
        Calendar.current.date(byAdding: .day, value: 180, to: .now) ?? .now
    }

    private var selectedEventDateBinding: Binding<Date> {
        Binding(
            get: {
                if let current = draft.targetEventDate, current >= minimumEventDate {
                    return current
                }
                return minimumEventDate
            },
            set: { newDate in
                if newDate < minimumEventDate {
                    draft.targetEventDate = minimumEventDate
                } else if newDate > maximumEventDate {
                    draft.targetEventDate = maximumEventDate
                } else {
                    draft.targetEventDate = newDate
                }
            }
        )
    }

    private let presets: [(titleKey: String, icon: String)] = [
        ("onboarding_event_preset_wedding", "sparkles"),
        ("onboarding_event_preset_summer", "sun.max.fill"),
        ("onboarding_event_preset_sports", "trophy.fill"),
        ("onboarding_event_preset_personal", "target")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingTitle(
                title: "onboarding_timeline_title",
                subtitle: "onboarding_timeline_subtitle"
            )

            horizonModeSelector

            if draft.targetHorizonMode == .specificEvent {
                eventDetailsForm
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var horizonModeSelector: some View {
        VStack(spacing: 12) {
            ForEach(PlanHorizonMode.allCases, id: \.self) { mode in
                let isSelected = draft.targetHorizonMode == mode
                let tintColor = mode == .specificEvent ? PulseTheme.accent : Color.primary
                OnboardingOptionCard(
                    title: mode.titleKey,
                    subtitle: mode.subtitleKey,
                    icon: mode.icon,
                    tint: tintColor,
                    isSelected: isSelected
                ) {
                    selectHorizonMode(mode)
                }
            }
        }
    }

    private func selectHorizonMode(_ mode: PlanHorizonMode) {
        draft.targetHorizonMode = mode
        if mode == .specificEvent && draft.targetEventDate == nil {
            draft.targetEventDate = minimumEventDate
        }
    }

    private var eventDetailsForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localizedKey("onboarding_event_type_label"))
                .font(.footnote.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            presetChipsView
            eventNameInputView
            eventDatePickerView
            guardrailNoteView
        }
    }

    private var presetChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets, id: \.titleKey) { preset in
                    let presetTitle = localizedString(preset.titleKey)
                    let isSelected = draft.targetEventName == presetTitle
                    Button {
                        HapticService.selection()
                        draft.targetEventName = presetTitle
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: preset.icon)
                                .font(.caption.weight(.bold))
                            Text(localizedKey(preset.titleKey))
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? PulseTheme.accent.opacity(0.18) : PulseTheme.card)
                        .foregroundStyle(isSelected ? PulseTheme.accent : Color.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? PulseTheme.accent : PulseTheme.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var eventNameInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedKey("onboarding_event_name_prompt"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)

            TextField(
                localizedString("onboarding_event_name_placeholder"),
                text: Binding(
                    get: { draft.targetEventName ?? "" },
                    set: { draft.targetEventName = $0.isEmpty ? nil : $0 }
                )
            )
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PulseTheme.separator, lineWidth: 1)
            )
        }
    }

    private var eventDatePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedKey("onboarding_event_date_label"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)

            DatePicker(
                "",
                selection: selectedEventDateBinding,
                in: minimumEventDate...maximumEventDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(PulseTheme.accent)
            .padding(8)
            .background(PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var guardrailNoteView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.checkmark.fill")
                .font(.footnote)
                .foregroundStyle(PulseTheme.accent)
            Text(localizedKey("onboarding_event_guardrail_note"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(12)
        .background(PulseTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingExperienceStepView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_exp_title",
                subtitle: "onboarding_exp_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(UserProfile.Experience.allCases) { experience in
                    OnboardingOptionCard(
                        title: experience.title,
                        subtitle: experience.subtitle,
                        icon: experience.icon,
                        tint: PulseTheme.ringStand,
                        isSelected: draft.experience == experience
                    ) {
                        draft.experience = experience
                    }
                }
            }
        }
    }
}

// MARK: - AI Target Recommendation Engine

private struct OnboardingTargetRecommendation {
    let suggestedDays: Int
    let suggestedDuration: Int
    let suggestedLocationID: String
    let suggestedEquipment: [String]
    let scheduleExplanation: String
    let equipmentExplanation: String

    static func calculate(for draft: OnboardingDraft) -> OnboardingTargetRecommendation? {
        guard draft.targetHorizonMode == .specificEvent else { return nil }

        let weeks: Int
        if let eventDate = draft.targetEventDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: eventDate).day ?? 84
            weeks = max(1, Int(ceil(Double(daysRemaining) / 7.0)))
        } else {
            weeks = 12
        }

        let eventOrGoal: String
        if let eventName = draft.targetEventName, !eventName.trimmingCharacters(in: .whitespaces).isEmpty {
            eventOrGoal = eventName
        } else {
            eventOrGoal = onboardingLocalizedString(draft.mainGoal.title)
        }

        let days: Int
        let duration: Int
        let locationID = OnboardingLocationCatalog.defaultLocation.id

        if weeks <= 6 {
            days = 5
            duration = 60
        } else if weeks <= 12 {
            switch draft.mainGoal {
            case .buildMuscle, .getStronger:
                days = 5
                duration = 60
            case .loseFat, .bodyRecomposition:
                days = 5
                duration = 45
            case .stayActive:
                days = 4
                duration = 60
            }
        } else {
            days = 4
            duration = 60
        }

        let scheduleExpFmt = onboardingLocalizedString("onboarding_schedule_ai_recommendation_reason")
        let scheduleExp = String(format: scheduleExpFmt, eventOrGoal, weeks, days, duration)

        let equipmentExpFmt = onboardingLocalizedString("onboarding_equipment_ai_recommendation_reason")
        let equipmentExp = String(format: equipmentExpFmt, eventOrGoal, weeks)

        return OnboardingTargetRecommendation(
            suggestedDays: days,
            suggestedDuration: duration,
            suggestedLocationID: locationID,
            suggestedEquipment: OnboardingLocationCatalog.defaultLocation.equipment,
            scheduleExplanation: scheduleExp,
            equipmentExplanation: equipmentExp
        )
    }
}

private struct OnboardingAISuggestionBanner: View {
    let explanation: String
    let actionTitle: String
    let isApplied: Bool
    let onApply: () -> Void

    var body: some View {
        PulseCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.fitOrange))
                        .frame(width: 32, height: 32)
                        .background(PulseTheme.fitOrange)
                        .clipShape(Circle())
                        .shadow(color: PulseTheme.fitOrange.opacity(0.4), radius: 6, y: 2)

                    Text(onboardingLocalizedString("onboarding_ai_suggestion_badge"))
                        .font(.caption.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.fitOrange))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(PulseTheme.fitOrange)
                        .clipShape(Capsule())

                    Spacer()

                    if isApplied {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                            Text(onboardingLocalizedString("onboarding_ai_suggestion_applied"))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(PulseTheme.fitOrange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(PulseTheme.fitOrange.opacity(0.16))
                        .clipShape(Capsule())
                    }
                }

                Text(explanation)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !isApplied {
                    Button(action: onApply) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                                .font(.subheadline.weight(.bold))
                            Text(actionTitle)
                                .font(.subheadline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.fitOrange))
                        .background(PulseTheme.fitOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: PulseTheme.fitOrange.opacity(0.35), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .pressableFeedback(scale: 0.96)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.fitOrange.opacity(0.85), lineWidth: 1.5)
        )
        .shadow(color: PulseTheme.fitOrange.opacity(0.20), radius: 12, y: 4)
    }
}

private struct OnboardingScheduleStepView: View {
    @Binding var draft: OnboardingDraft

    private var recommendation: OnboardingTargetRecommendation? {
        OnboardingTargetRecommendation.calculate(for: draft)
    }

    private var isRecommendationApplied: Bool {
        guard let rec = recommendation else { return false }
        return draft.weeklyTrainingDays == rec.suggestedDays && draft.sessionLengthMinutes == rec.suggestedDuration
    }

    private var scheduleHelperText: String {
        switch draft.weeklyTrainingDays {
        case 1: "onboarding_schedule_1_day"
        case 2: "onboarding_schedule_2_days"
        case 3: "onboarding_schedule_3_days"
        case 4: "onboarding_schedule_4_days"
        case 5: "onboarding_schedule_5_days"
        case 6: "onboarding_schedule_6_days"
        default: "onboarding_schedule_7_days"
        }
    }

    private var durationHelperText: String {
        switch draft.sessionLengthMinutes {
        case 15: "onboarding_duration_15min"
        case 30: "onboarding_duration_30min"
        case 45: "onboarding_duration_45min"
        case 60: "onboarding_duration_60min"
        case 75: "onboarding_duration_75min"
        default: "onboarding_duration_90min"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_schedule_title",
                subtitle: "onboarding_schedule_subtitle"
            )

            if let rec = recommendation {
                OnboardingAISuggestionBanner(
                    explanation: rec.scheduleExplanation,
                    actionTitle: String(format: onboardingLocalizedString("onboarding_schedule_ai_apply_btn"), rec.suggestedDays, rec.suggestedDuration),
                    isApplied: isRecommendationApplied
                ) {
                    draft.weeklyTrainingDays = rec.suggestedDays
                    draft.sessionLengthMinutes = rec.suggestedDuration
                }
            }

            OnboardingNumberPicker(
                title: "onboarding_schedule_days_label",
                value: $draft.weeklyTrainingDays,
                options: Array(1...7),
                unit: "onboarding_schedule_days_unit",
                helper: scheduleHelperText,
                suggestedValue: recommendation?.suggestedDays
            )

            OnboardingNumberPicker(
                title: "onboarding_schedule_duration_label",
                value: $draft.sessionLengthMinutes,
                options: [15, 30, 45, 60, 75, 90],
                unit: "onboarding_schedule_duration_unit",
                helper: durationHelperText,
                suggestedValue: recommendation?.suggestedDuration
            )
        }
        .onAppear {
            if let rec = recommendation, draft.weeklyTrainingDays == 4 && draft.sessionLengthMinutes == 60 {
                draft.weeklyTrainingDays = rec.suggestedDays
                draft.sessionLengthMinutes = rec.suggestedDuration
            }
        }
    }
}

private struct OnboardingEquipmentStepView: View {
    @Binding var draft: OnboardingDraft

    private var recommendation: OnboardingTargetRecommendation? {
        OnboardingTargetRecommendation.calculate(for: draft)
    }

    private var isRecommendationApplied: Bool {
        guard let rec = recommendation else { return false }
        return draft.selectedLocationID == rec.suggestedLocationID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_equipment_title",
                subtitle: "onboarding_equipment_subtitle"
            )

            if let rec = recommendation {
                OnboardingAISuggestionBanner(
                    explanation: rec.equipmentExplanation,
                    actionTitle: onboardingLocalizedString("onboarding_equipment_ai_apply_btn"),
                    isApplied: isRecommendationApplied
                ) {
                    if let defaultLoc = OnboardingLocationCatalog.locations.first(where: { $0.id == rec.suggestedLocationID }) {
                        draft.applyLocation(defaultLoc)
                    }
                }
            }

            VStack(spacing: 12) {
                ForEach(OnboardingLocationCatalog.locations) { location in
                    let isSuggestedLocation = recommendation?.suggestedLocationID == location.id
                    OnboardingOptionCard(
                        title: location.title,
                        subtitle: location.subtitle,
                        icon: location.icon,
                        tint: isSuggestedLocation ? PulseTheme.fitOrange : PulseTheme.recovery,
                        isSelected: draft.selectedLocationID == location.id,
                        badgeText: isSuggestedLocation ? onboardingLocalizedString("onboarding_badge_suggested_ai") : nil,
                        badgeColor: PulseTheme.fitOrange,
                        isSuggested: isSuggestedLocation
                    ) {
                        draft.applyLocation(location)
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(onboardingLocalizedString("onboarding_equipment_available_label"))
                        .font(.headline)

                    FlowLayout(spacing: 10) {
                        ForEach(OnboardingLocationCatalog.coreEquipment, id: \.self) { equipment in
                            let isSuggestedEquip = recommendation?.suggestedEquipment.contains(equipment) ?? false
                            EquipmentChip(
                                title: OnboardingLocationCatalog.localizedEquipmentKey(equipment),
                                isSelected: draft.availableEquipment.contains(equipment),
                                isSuggested: isSuggestedEquip
                            ) {
                                draft.toggleEquipment(equipment)
                            }
                        }
                    }

                    Text(onboardingLocalizedString("onboarding_equipment_refine_hint"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .onAppear {
            if let rec = recommendation, draft.selectedLocationID != rec.suggestedLocationID {
                if let defaultLoc = OnboardingLocationCatalog.locations.first(where: { $0.id == rec.suggestedLocationID }) {
                    draft.applyLocation(defaultLoc)
                }
            }
        }
    }
}

private struct OnboardingBaselineStepView: View {
    @Binding var draft: OnboardingDraft

    private var bmiMetrics: HealthBMIMetrics {
        HealthBMIMetrics.calculate(
            heightCm: draft.heightCm,
            weightKg: draft.weightKg,
            sex: draft.bodyMapPreference.profileSex
        )
    }

    private var weightGradientStops: [Gradient.Stop] {
        HealthBMIMetrics.gradientStops(heightCm: draft.heightCm, range: 35...180)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_baseline_title",
                subtitle: "onboarding_baseline_subtitle"
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_age",
                valueText: "\(draft.age)",
                unit: "onboarding_baseline_age_unit",
                icon: "calendar",
                value: Binding(
                    get: { Double(draft.age) },
                    set: { draft.age = Int($0.rounded()) }
                ),
                range: 14...85,
                step: 1
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_height",
                valueText: String(format: "%.0f", draft.heightCm),
                unit: "onboarding_baseline_height_unit",
                icon: "ruler",
                value: $draft.heightCm,
                range: 130...220,
                step: 1
            )

            OnboardingMetricSlider(
                title: "onboarding_baseline_weight",
                valueText: String(format: "%.1f", draft.weightKg),
                unit: "onboarding_baseline_weight_unit",
                icon: "scalemass.fill",
                value: $draft.weightKg,
                range: 35...180,
                step: 0.5,
                accentColor: bmiMetrics.color,
                gradientStops: weightGradientStops
            )

            // WHO Health & BMI Category Indicator Card (Sex-Adjusted)
            PulseCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: bmiMetrics.category.icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(bmiMetrics.color))
                        .frame(width: 44, height: 44)
                        .background(bmiMetrics.color)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: bmiMetrics.color.opacity(0.35), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(verbatim: String(format: "IMC %.1f", bmiMetrics.bmi))
                                .font(.caption.weight(.black).monospacedDigit())
                                .foregroundStyle(PulseTheme.onColor(bmiMetrics.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(bmiMetrics.color)
                                .clipShape(Capsule())

                            Text(bmiMetrics.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Text(bmiMetrics.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            // New Sex / Anatomy Selection Cards at Original Bottom Position
            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(onboardingLocalizedString("onboarding_baseline_anatomy_label"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Text(onboardingLocalizedString("onboarding_baseline_anatomy_subtitle"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)

                    HStack(spacing: 10) {
                        ForEach(BodyMapPreference.allCases) { preference in
                            let isSelected = draft.bodyMapPreference == preference
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    draft.bodyMapPreference = preference
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: preference == .mapA ? "figure.stand" : (preference == .mapB ? "figure.stand.dress" : "person.fill"))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(isSelected ? PulseTheme.accent : PulseTheme.secondaryText)
                                    Text(onboardingLocalizedString(preference.title))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(isSelected ? PulseTheme.textPrimary : PulseTheme.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isSelected ? PulseTheme.accent.opacity(0.12) : PulseTheme.grouped)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(isSelected ? PulseTheme.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .pressableFeedback(scale: 0.95)
                        }
                    }
                }
            }
        }
    }
}

private struct OnboardingFocusStepView: View {
    @Binding var draft: OnboardingDraft

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    private var selectedFocusMuscles: Set<Muscle> {
        Set(draft.focusMuscles.flatMap(muscles(for:)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_focus_title",
                subtitle: "onboarding_focus_subtitle"
            )

            OnboardingBodyPair(gender: selectedGender, selectedMuscles: selectedFocusMuscles) { muscle in
                if let focus = focusKey(for: muscle) {
                    draft.toggleFocus(focus)
                }
            }
            .frame(height: 410)

            FlowLayout(spacing: 10) {
                ForEach(OnboardingDraft.focusOptions, id: \.self) { focus in
                    EquipmentChip(
                        title: OnboardingDraft.localizedFocusKey(focus),
                        isSelected: draft.focusMuscles.contains(focus)
                    ) {
                        draft.toggleFocus(focus)
                    }
                }
                EquipmentChip(
                    title: "onboarding_focus_all",
                    isSelected: draft.allFocusSelected
                ) {
                    draft.toggleAllFocus()
                }
            }
        }
    }

    private func muscles(for group: String) -> [Muscle] {
        let lower = group.lowercased()
        if lower.contains("chest") { return [.chest, .upperChest, .lowerChest] }
        if lower.contains("back") { return [.upperBack, .rhomboids, .trapezius, .lowerBack] }
        if lower.contains("shoulder") { return [.deltoids, .frontDeltoid, .rearDeltoid] }
        if lower.contains("arm") { return [.biceps, .triceps, .forearm] }
        if lower.contains("leg") { return [.quadriceps, .hamstring, .calves, .adductors] }
        if lower.contains("glute") { return [.gluteal, .hamstring] }
        if lower.contains("core") { return [.abs, .upperAbs, .lowerAbs, .obliques] }
        return []
    }

    private func focusKey(for muscle: Muscle) -> String? {
        if [.chest, .upperChest, .lowerChest].contains(muscle) { return "Chest" }
        if [.upperBack, .rhomboids, .trapezius, .upperTrapezius, .lowerTrapezius, .lowerBack].contains(muscle) { return "Back" }
        if [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff].contains(muscle) { return "Shoulders" }
        if [.biceps, .triceps, .forearm].contains(muscle) { return "Arms" }
        if [.quadriceps, .innerQuad, .outerQuad, .hamstring, .calves, .tibialis, .adductors].contains(muscle) { return "Legs" }
        if [.gluteal].contains(muscle) { return "Glutes" }
        if [.abs, .upperAbs, .lowerAbs, .obliques, .serratus].contains(muscle) { return "Core" }
        return nil
    }
}

private struct OnboardingGeneratingStepView: View {
    @Binding var draft: OnboardingDraft
    let generatedPlan: WorkoutPlan
    let weeklySetTotal: Int
    let isGenerationComplete: Bool
    let generationProgress: Double
    let generationStatusText: String
    let generationPulse: Bool

    @State private var testimonialIndex = 0
    @State private var shimmerOffset: CGFloat = -1.0

    private static let planTestimonials: [(text: String, author: String)] = [
        (text: "Al fin tengo un plan adaptado a mi horario y equipamiento real.", author: "Alex R."),
        (text: "La primera semana fue retadora pero en la 3era ya vi cambios reales.", author: "María K."),
        (text: "Una app que realmente ajusta la carga de trabajo según mi progreso.", author: "Carlos M."),
    ]

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    private var activeGenerationStep: Int {
        if generationProgress < 0.25 { return 0 }
        if generationProgress < 0.55 { return 1 }
        if generationProgress < 0.82 { return 2 }
        return 3
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isGenerationComplete {
                planGeneratingView
            } else {
                planCompleteView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var planGeneratingView: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(onboardingLocalizedString("onboarding_personalizing_title"))
                        .font(.system(size: 32, weight: .heavy))
                    Text(onboardingLocalizedString("onboarding_personalizing_subtitle"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Spacer()

                // Live Glowing Percentage Counter
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 2) {
                        Text("\(Int(generationProgress * 100))")
                            .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PulseTheme.ringStand, PulseTheme.accent, PulseTheme.fitOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .contentTransition(.numericText(value: generationProgress * 100))
                        Text("%")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PulseTheme.fitOrange)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(PulseTheme.fitOrange)
                            .frame(width: 6, height: 6)
                            .scaleEffect(generationPulse ? 1.4 : 0.8)
                            .animation(.easeInOut(duration: 0.6).repeatForever(), value: generationPulse)
                        Text(onboardingLocalizedString("onboarding_ai_suggestion_badge"))
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.6)
                            .foregroundStyle(PulseTheme.fitOrange)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.top, 6)

            // High-Tech Glowing Progress Bar with Animated Shimmer Beam
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(localizedString("onboarding_badge_progress"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .tracking(1.4)
                    Spacer()
                    Text(generationStatusText.isEmpty ? onboardingLocalizedString("onboarding_gen_live_ai_analyzing") : generationStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .lineLimit(1)
                }

                GeometryReader { proxy in
                    let barWidth = max(16, proxy.size.width * generationProgress)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.08))

                        Capsule()
                            .fill(LinearGradient(
                                colors: [PulseTheme.ringStand, PulseTheme.accent, PulseTheme.fitOrange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: barWidth)
                            .shadow(color: PulseTheme.fitOrange.opacity(0.35), radius: 6, y: 0)

                        // Shimmer highlight beam
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.6), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 7)
                            .offset(x: barWidth * shimmerOffset)
                            .mask(
                                Capsule()
                                    .frame(width: barWidth)
                            )
                    }
                }
                .frame(height: 7)
            }

            // Checklist Card with Active Step Glow
            PulseCard(contentPadding: 16) {
                let stepTitles: [String] = [
                    "onboarding_step_saving_profile",
                    "onboarding_step_preferences",
                    "onboarding_step_volume",
                    "onboarding_step_templates"
                ]
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                        GenerationStepRow(
                            title: title,
                            isCompleted: index < activeGenerationStep,
                            isActive: index == activeGenerationStep,
                            isLast: index == stepTitles.count - 1
                        )
                    }
                }
            }

            // Glassmorphic Testimonial Card with Star Rating
            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(PulseTheme.fitOrange)
                            }
                        }

                        Spacer()

                        Text(onboardingLocalizedString("onboarding_gen_verified_user"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Text(Self.planTestimonials[testimonialIndex].text)
                        .font(.body.weight(.medium))
                        .italic()
                        .foregroundStyle(PulseTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(testimonialIndex)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.accent)
                        Text(Self.planTestimonials[testimonialIndex].author)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.0
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation(.easeInOut(duration: 0.45)) {
                    testimonialIndex = (testimonialIndex + 1) % Self.planTestimonials.count
                }
            }
        }
    }

    private var planCompleteView: some View {
        VStack(spacing: 22) {
            OnboardingTitle(
                title: "onboarding_generating_title",
                subtitle: "onboarding_generating_subtitle"
            )

            OnboardingBodyPair(gender: selectedGender, heatmap: generationHeatmap)
                .frame(height: 410)
                .scaleEffect(generationPulse ? 1.02 : 0.98)
                .opacity(generationPulse ? 1 : 0.82)

            HStack(spacing: 8) {
                GenerationPill(title: onboardingLocalizedString("onboarding_pill_days"), value: "\(generatedPlan.daysPerWeek)")
                GenerationPill(title: onboardingLocalizedString("onboarding_pill_sets"), value: "\(weeklySetTotal)")
                GenerationPill(title: onboardingLocalizedString("onboarding_pill_weeks"), value: "\(generatedPlan.totalWeeks)")
            }

            TransformationProjection12WeekCard(
                plan: generatedPlan,
                weeklySetTotal: weeklySetTotal,
                goal: draft.mainGoal,
                experience: draft.experience,
                focusMuscles: Array(draft.focusMuscles).sorted(),
                locationID: draft.selectedLocationID,
                sex: draft.bodyMapPreference.profileSex
            )
        }
    }

    private var generationHeatmap: [MuscleIntensity] {
        let trained = Set(generatedPlan.days.flatMap(\.exercises).flatMap { muscles(for: $0.exercise.muscleGroup) })
        let focus = Set(draft.focusMuscles.flatMap(muscles(for:)))
        let focusIntensity = generationPulse ? 1.0 : 0.88
        let trainedIntensity = generationPulse ? 0.55 : 0.30

        let focusEntries = focus.map {
            MuscleIntensity(muscle: $0, intensity: focusIntensity, color: PulseTheme.focus)
        }
        let trainedEntries = trained.subtracting(focus).map {
            MuscleIntensity(muscle: $0, intensity: trainedIntensity, color: PulseTheme.accent.opacity(0.45))
        }
        return focusEntries + trainedEntries
    }

    private func muscles(for group: String) -> [Muscle] {
        let lower = group.lowercased()
        if lower.contains("chest") { return [.chest, .upperChest, .lowerChest] }
        if lower.contains("back") { return [.upperBack, .rhomboids, .trapezius, .lowerBack] }
        if lower.contains("shoulder") { return [.deltoids, .frontDeltoid, .rearDeltoid] }
        if lower.contains("arm") { return [.biceps, .triceps, .forearm] }
        if lower.contains("leg") { return [.quadriceps, .hamstring, .calves, .adductors] }
        if lower.contains("glute") { return [.gluteal, .hamstring] }
        if lower.contains("core") { return [.abs, .upperAbs, .lowerAbs, .obliques] }
        return []
    }
}

private struct OnboardingReadyStepView: View {
    @Environment(AppStore.self) private var store
    @Binding var draft: OnboardingDraft
    let generatedPlan: WorkoutPlan
    let weeklySetTotal: Int
    let onUnlockPro: () -> Void

    @State private var showingArchitectureSheet = false

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if draft.buildsOwnPlan {
                OnboardingTitle(
                    title: "Modo Libre listo",
                    subtitle: "Tu espacio de entrenamiento personalizado está configurado. Puedes crear tus rutinas y acceder a las herramientas Pro."
                )

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(draft.mainGoal.shortTitle, systemImage: draft.mainGoal.icon)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(PulseTheme.accent.opacity(0.12))
                                .clipShape(Capsule())

                            Spacer()

                            Label(OnboardingLocationCatalog.location(for: draft.selectedLocationID).title, systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }

                        Text(localizedString("onboarding_setup_self_confirmation"))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            } else {
                OnboardingTitle(
                    title: "onboarding_ready_title",
                    subtitle: "onboarding_ready_subtitle"
                )

                HStack(spacing: 8) {
                    GenerationPill(title: onboardingLocalizedString("onboarding_pill_days"), value: "\(generatedPlan.daysPerWeek)")
                    GenerationPill(title: onboardingLocalizedString("onboarding_pill_sets"), value: "\(weeklySetTotal)")
                    GenerationPill(title: onboardingLocalizedString("onboarding_pill_weeks"), value: "\(generatedPlan.totalWeeks)")
                }

                Button {
                    showingArchitectureSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(.subheadline.weight(.bold))
                        Text(onboardingLocalizedString("onboarding_plan_architecture_btn"))
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .foregroundStyle(PulseTheme.fitOrange)
                    .background(PulseTheme.fitOrange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PulseTheme.fitOrange.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .pressableFeedback(scale: 0.97)

                if let firstDay = generatedPlan.days.first {
                    PlanDay1LockedPreviewCard(
                        day: firstDay,
                        gender: selectedGender,
                        language: draft.preferredLanguage,
                        exercises: store.exercises,
                        isPro: store.monetization.hasProAccess
                    )
                }

                if generatedPlan.days.count > 1 {
                    PlanLockedDaysCard(
                        plan: generatedPlan,
                        isPro: store.monetization.hasProAccess,
                        onTapDay: { _ in
                            showingArchitectureSheet = true
                        }
                    )
                }
            }

            if !store.monetization.hasProAccess {
                PlanUnlockProCard(
                    totalWeeks: generatedPlan.totalWeeks,
                    daysPerWeek: generatedPlan.daysPerWeek,
                    onUnlock: onUnlockPro
                )
            }
        }
        .sheet(isPresented: $showingArchitectureSheet) {
            PlanArchitectureDetailSheet(
                plan: generatedPlan,
                draft: draft,
                exercises: store.exercises,
                gender: selectedGender,
                isPro: store.monetization.hasProAccess,
                onUnlockPro: onUnlockPro
            )
        }
    }
}

// MARK: - Reusable UI Components

private struct OnboardingProgressHeader: View {
    let progress: Double
    let currentStepIndex: Int
    let totalSteps: Int
    let canGoBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .navigationGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atrás")
            } else {
                Color.clear
                    .frame(width: 38, height: 38)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(PulseTheme.grouped)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [PulseTheme.accent, PulseTheme.ringStand],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: progress)
                    }
            }
            .frame(height: 5)

            if totalSteps > 0 {
                Text("\(currentStepIndex)/\(totalSteps)")
                    .font(.caption2.weight(.black).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
            }
        }
        .frame(height: 38)
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

private struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(onboardingLocalizedString(title))
                .font(.system(size: 34, weight: .heavy))
                .lineLimit(4)
                .minimumScaleFactor(0.72)
            Text(onboardingLocalizedString(subtitle))
                .font(.title3.weight(.medium))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    var badgeText: String? = nil
    var badgeColor: Color = PulseTheme.fitOrange
    var isSuggested: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? PulseTheme.onColor(tint) : tint)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? tint : tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(onboardingLocalizedString(title))
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(0.6)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .foregroundStyle(PulseTheme.onColor(badgeColor))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(badgeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(onboardingLocalizedString(subtitle))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : PulseTheme.tertiaryText)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .background(isSelected ? (isSuggested ? PulseTheme.fitOrange.opacity(0.12) : .white.opacity(0.08)) : PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(isSuggested ? PulseTheme.fitOrange : (isSelected ? tint.opacity(0.9) : PulseTheme.separator), lineWidth: isSuggested ? 2 : (isSelected ? 1.8 : 1))
            )
            .shadow(color: isSuggested ? PulseTheme.fitOrange.opacity(0.3) : (isSelected ? tint.opacity(0.20) : .clear), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.965)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct OnboardingNumberPicker: View {
    let title: String
    @Binding var value: Int
    let options: [Int]
    let unit: String
    let helper: String
    var suggestedValue: Int? = nil

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(onboardingLocalizedString(title))
                        .font(.headline)
                    Spacer()
                    Text(onboardingLocalizedString(helper))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(value)")
                        .font(.system(size: 68, weight: .heavy))
                        .contentTransition(.numericText(value: Double(value)))
                    Text(onboardingLocalizedString(unit))
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = value == option
                        let isSuggested = suggestedValue == option

                        Button {
                            value = option
                        } label: {
                            VStack(spacing: 2) {
                                Text(option == 90 && unit == "onboarding_schedule_duration_unit" ? "90+" : "\(option)")
                                    .font(.headline.monospacedDigit())
                                if isSuggested {
                                    Text("IA")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(isSelected ? PulseTheme.onColor(PulseTheme.fitOrange) : PulseTheme.fitOrange)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(isSelected ? (isSuggested ? PulseTheme.onColor(PulseTheme.fitOrange) : .black) : (isSuggested ? PulseTheme.fitOrange : PulseTheme.secondaryText))
                            .background(isSelected ? (isSuggested ? PulseTheme.fitOrange : .white) : PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        isSuggested ? PulseTheme.fitOrange : Color.clear,
                                        lineWidth: isSuggested ? 2 : 0
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .pressableFeedback(scale: 0.94)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct OnboardingMetricSlider: View {
    let title: String
    let valueText: String
    let unit: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var accentColor: Color = PulseTheme.accent
    var gradientStops: [Gradient.Stop]? = nil

    private var progress: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(accentColor))
                        .frame(width: 42, height: 42)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                    Text(onboardingLocalizedString(title))
                        .font(.headline)
                    Spacer()
                }

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text(valueText)
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(gradientStops != nil ? accentColor : .primary)
                        .contentTransition(.numericText(value: value))
                        .animation(.snappy(duration: 0.18), value: accentColor)
                    Text(onboardingLocalizedString(unit))
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                ZStack(alignment: .leading) {
                    if let gradientStops {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(LinearGradient(stops: gradientStops, startPoint: .leading, endPoint: .trailing))
                                .frame(height: 6)
                                .opacity(0.88)
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.12), lineWidth: 1)
                                )
                                .padding(.vertical, 12)
                        }
                        .frame(height: 30)
                        .allowsHitTesting(false)
                    }

                    Slider(value: $value, in: range, step: step)
                        .tint(gradientStops != nil ? accentColor : .white)
                }

                TickRail(progress: progress, activeColor: accentColor)
                    .frame(height: 30)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct TickRail: View {
    let progress: Double
    var activeColor: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let activeX = proxy.size.width * clampedProgress

            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<31, id: \.self) { index in
                        Rectangle()
                            .fill(index % 5 == 0 ? PulseTheme.secondaryText.opacity(0.55) : PulseTheme.separator.opacity(0.9))
                            .frame(width: 1.3, height: index % 5 == 0 ? 25 : 15)
                            .frame(maxWidth: .infinity)
                    }
                }

                Rectangle()
                    .fill(activeColor)
                    .frame(width: 3, height: 30)
                    .offset(x: activeX - 1.5)
                    .shadow(color: activeColor.opacity(0.6), radius: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct EquipmentChip: View {
    let title: String
    let isSelected: Bool
    var isSuggested: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(onboardingLocalizedString(title))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if isSuggested && !isSelected {
                    Circle()
                        .fill(PulseTheme.fitOrange)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(Capsule())
            .foregroundStyle(isSelected ? (isSuggested ? PulseTheme.onColor(PulseTheme.fitOrange) : .black) : (isSuggested ? PulseTheme.fitOrange : PulseTheme.secondaryText))
            .background(isSelected ? (isSuggested ? PulseTheme.fitOrange : PulseTheme.accent) : PulseTheme.grouped)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSuggested ? PulseTheme.fitOrange.opacity(0.85) : Color.clear, lineWidth: isSuggested ? 1.6 : 0)
            )
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.94)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 122), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

private struct GenerationPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(onboardingLocalizedString(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulseTheme.card)
        .clipShape(Capsule())
    }
}

private struct GenerationStepRow: View {
    let title: String
    let isCompleted: Bool
    let isActive: Bool
    let isLast: Bool
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(PulseTheme.ringStand)
                            .transition(.scale.combined(with: .opacity))
                    } else if isActive {
                        ZStack {
                            Circle()
                                .stroke(PulseTheme.fitOrange.opacity(0.3), lineWidth: 3.5)
                                .frame(width: 24, height: 24)

                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(
                                    LinearGradient(
                                        colors: [PulseTheme.fitOrange, PulseTheme.accent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                                .frame(width: 22, height: 22)
                                .rotationEffect(.degrees(pulse ? 360 : 0))
                                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
                        }
                    } else {
                        Circle()
                            .stroke(.white.opacity(0.18), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 26, height: 26)

                Text(onboardingLocalizedString(title))
                    .font(.subheadline.weight(isActive ? .bold : (isCompleted ? .semibold : .regular)))
                    .foregroundStyle(isActive ? .white : (isCompleted ? .white.opacity(0.9) : PulseTheme.secondaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isActive {
                    SparkleParticleView()
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(isActive ? PulseTheme.fitOrange.opacity(0.10) : (isCompleted ? .white.opacity(0.02) : .clear))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? PulseTheme.fitOrange.opacity(0.4) : Color.clear, lineWidth: 1)
            )

            if !isLast {
                HStack(spacing: 14) {
                    Rectangle()
                        .fill(isCompleted ? PulseTheme.ringStand.opacity(0.7) : (isActive ? PulseTheme.fitOrange.opacity(0.4) : .white.opacity(0.12)))
                        .frame(width: 2, height: 14)
                        .frame(width: 26)
                    Spacer()
                }
            }
        }
        .onAppear { pulse = isActive }
        .onChange(of: isActive) { _, v in pulse = v }
        .sensoryFeedback(.selection, trigger: isCompleted)
    }
}

private struct SparkleParticleView: View {
    @State private var isSparkling = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.caption2.weight(.bold))
            .foregroundStyle(PulseTheme.fitOrange)
            .scaleEffect(isSparkling ? 1.2 : 0.8)
            .opacity(isSparkling ? 1.0 : 0.4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    isSparkling = true
                }
            }
    }
}

// MARK: - Transformation Projection 12-Week Chart (Photo 3 Redesign)

private struct TransformationProjection12WeekCard: View {
    let plan: WorkoutPlan
    let weeklySetTotal: Int
    let goal: UserProfile.MainGoal
    let experience: UserProfile.Experience
    let focusMuscles: [String]
    let locationID: String
    let sex: UserProfile.Sex?

    private struct WeekTrendPoint: Identifiable {
        var id: Int { week }
        let week: Int
        let strengthKg: Double
        let muscleGainKg: Double
        let fatLossPercent: Double
        let isDeload: Bool
    }

    private var trendData: [WeekTrendPoint] {
        let isFemale = (sex == .female)
        let total = max(4, min(12, plan.totalWeeks))

        // Goal-tailored multipliers for strength, muscle & fat
        let strengthBase: Double
        let muscleBase: Double
        let fatBase: Double

        switch goal {
        case .buildMuscle:
            strengthBase = 22.0; muscleBase = isFemale ? 2.4 : 3.8; fatBase = 1.5
        case .loseFat:
            strengthBase = 12.0; muscleBase = isFemale ? 1.0 : 1.6; fatBase = 5.4
        case .bodyRecomposition:
            strengthBase = 18.0; muscleBase = isFemale ? 1.8 : 2.8; fatBase = 3.8
        case .getStronger:
            strengthBase = 28.0; muscleBase = isFemale ? 1.6 : 2.4; fatBase = 1.0
        case .stayActive:
            strengthBase = 10.0; muscleBase = isFemale ? 0.8 : 1.2; fatBase = 2.0
        }

        return (1...total).map { w in
            let mesoLen = 4
            let weekInMeso = ((w - 1) % mesoLen) + 1
            let isDeload = (weekInMeso == mesoLen)

            let progressRatio = Double(w) / Double(total)
            let logFactor = log2(1.0 + progressRatio * 3.0) / 2.0 // Realistic dimishing returns curve

            let str = strengthBase * logFactor * (isDeload ? 0.92 : 1.0)
            let mus = muscleBase * logFactor
            let fat = fatBase * logFactor

            return WeekTrendPoint(
                week: w,
                strengthKg: str,
                muscleGainKg: mus,
                fatLossPercent: fat,
                isDeload: isDeload
            )
        }
    }

    private var maxStrength: Double {
        trendData.map(\.strengthKg).max() ?? 20.0
    }

    private var maxMuscle: Double {
        trendData.map(\.muscleGainKg).max() ?? 3.0
    }

    private var maxFat: Double {
        trendData.map(\.fatLossPercent).max() ?? 4.0
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(localizedString("onboarding_projection_title"))
                            .font(.headline.weight(.bold))
                        Spacer()
                        Text(localizedString("onboarding_projection_badge_ai"))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                    }
                    Text(localizedString("onboarding_projection_subtitle"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                // Multi-metric legend badges
                HStack(spacing: 8) {
                    LegendPill(
                        color: PulseTheme.ringStand,
                        label: String(format: "Fuerza +%.0f%%", maxStrength),
                        icon: "arrow.up.right"
                    )
                    LegendPill(
                        color: PulseTheme.warning,
                        label: String(format: "Músculo +%.1fkg", maxMuscle),
                        icon: "bolt.fill"
                    )
                    LegendPill(
                        color: Color(red: 1.0, green: 0.35, blue: 0.35),
                        label: String(format: "Grasa -%.1f%%", maxFat),
                        icon: "arrow.down.right"
                    )
                }

                // 12-Week Multi-Curve Chart
                Chart {
                    ForEach(trendData) { pt in
                        LineMark(
                            x: .value("Semana", "S\(pt.week)"),
                            y: .value("Fuerza", pt.strengthKg),
                            series: .value("Métrica", "Fuerza")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(PulseTheme.ringStand)
                        .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round))

                        LineMark(
                            x: .value("Semana", "S\(pt.week)"),
                            y: .value("Músculo", pt.muscleGainKg * 6.0),
                            series: .value("Métrica", "Músculo")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(PulseTheme.warning)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [4, 3]))

                        LineMark(
                            x: .value("Semana", "S\(pt.week)"),
                            y: .value("Grasa", pt.fatLossPercent * 4.0),
                            series: .value("Métrica", "Grasa")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
                        .lineStyle(StrokeStyle(lineWidth: 2.0, lineCap: .round))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine()
                            .foregroundStyle(PulseTheme.separator.opacity(0.5))
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text("\(Int(val))%")
                                    .font(.caption2)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let wStr = value.as(String.self) {
                                Text(wStr)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 160)

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                    Text(onboardingLocalizedString("onboarding_projection_recalibrate_hint"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(onboardingLocalizedString("onboarding_results_disclaimer"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }
        }
    }
}

private struct LegendPill: View {
    let color: Color
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 0.8)
        )
    }
}

private struct PlanDay1LockedPreviewCard: View {
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

private struct PlanExerciseRow: View {
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
                        Text(onboardingLocalizedString("onboarding_pro_sets_reps_load"))
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

private struct PlanLockedDaysCard: View {
    let plan: WorkoutPlan
    let isPro: Bool
    var onTapDay: ((WorkoutDay) -> Void)? = nil

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
                    Button {
                        onTapDay?(day)
                    } label: {
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
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < min(otherDays.count, isPro ? otherDays.count : 3) - 1 {
                        Divider()
                            .overlay(PulseTheme.separator)
                    }
                }

                if !isPro && otherDays.count > 3 {
                    Button {
                        if let firstRemaining = otherDays.dropFirst(3).first {
                            onTapDay?(firstRemaining)
                        }
                    } label: {
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
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Plan Architecture & Rest Detail Sheet (Protected DRM & High Value)

private struct PlanArchitectureDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let plan: WorkoutPlan
    let draft: OnboardingDraft
    let exercises: [Exercise]
    let gender: BodyGender
    let isPro: Bool
    let onUnlockPro: () -> Void

    var muscleFrequencyMap: [(muscle: String, count: Int, sets: Int)] {
        var map = [String: (count: Int, sets: Int)]()
        for day in plan.days {
            for item in day.exercises {
                let key = item.exercise.muscleGroup
                let current = map[key] ?? (count: 0, sets: 0)
                map[key] = (count: current.count + 1, sets: current.sets + item.targetSets)
            }
        }
        return map.map { (muscle: $0.key, count: $0.value.count, sets: $0.value.sets) }
            .sorted { $0.sets > $1.sets }
    }

    var cadenceDescription: String {
        switch plan.daysPerWeek {
        case 5, 6:
            return onboardingLocalizedString("onboarding_cadence_consecutive")
        default:
            return onboardingLocalizedString("onboarding_cadence_interleaved")
        }
    }

    var body: some View {
        NavigationStack {
            SecureContainerView {
                ZStack {
                    PulseTheme.background
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header Banner
                            PulseCard(backgroundColor: PulseTheme.card) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(onboardingLocalizedString("onboarding_plan_architecture_title"))
                                            .font(.title3.weight(.heavy))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        HStack(spacing: 4) {
                                            Image(systemName: "lock.shield.fill")
                                                .font(.caption2.weight(.bold))
                                            Text(onboardingLocalizedString("onboarding_plan_anti_copy_badge"))
                                                .font(.system(size: 9, weight: .black))
                                                .tracking(0.6)
                                        }
                                        .foregroundStyle(PulseTheme.onColor(PulseTheme.fitOrange))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(PulseTheme.fitOrange)
                                        .clipShape(Capsule())
                                    }

                                    HStack(spacing: 12) {
                                        Label("\(plan.totalWeeks) sem", systemImage: "calendar")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PulseTheme.accent)
                                        Label("\(plan.daysPerWeek) días/sem", systemImage: "figure.run")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PulseTheme.ringStand)
                                        Label(onboardingLocalizedString(OnboardingLocationCatalog.location(for: draft.selectedLocationID).title), systemImage: "building.2.fill")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                            }

                            // Section 1: Tiempos de Descanso Científicos
                            PulseCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "timer")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PulseTheme.fitOrange)
                                        Text(onboardingLocalizedString("onboarding_section_rest_times"))
                                            .font(.headline.weight(.bold))
                                    }

                                    Divider().overlay(PulseTheme.separator)

                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(onboardingLocalizedString("onboarding_rest_between_sets_title"))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Text(onboardingLocalizedString("onboarding_rest_between_sets_val"))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        Spacer()
                                    }

                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(onboardingLocalizedString("onboarding_rest_between_exercises_title"))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Text(onboardingLocalizedString("onboarding_rest_between_exercises_val"))
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        Spacer()
                                    }
                                }
                            }

                            // Section 2: Cadencia y Distribución Semanal
                            PulseCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PulseTheme.accent)
                                        Text(onboardingLocalizedString("onboarding_section_schedule_distribution"))
                                            .font(.headline.weight(.bold))
                                    }

                                    Divider().overlay(PulseTheme.separator)

                                    Text(cadenceDescription)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(PulseTheme.textPrimary)
                                }
                            }

                            // Section 3: Frecuencia por Grupo Muscular
                            PulseCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(PulseTheme.ringStand)
                                        Text(onboardingLocalizedString("onboarding_section_muscle_frequency"))
                                            .font(.headline.weight(.bold))
                                    }

                                    Divider().overlay(PulseTheme.separator)

                                    FlowLayout(spacing: 8) {
                                        ForEach(muscleFrequencyMap, id: \.muscle) { item in
                                            HStack(spacing: 5) {
                                                Text(onboardingLocalizedString(item.muscle))
                                                    .font(.caption.weight(.bold))
                                                Text("• \(item.sets) series (\(item.count)x/sem)")
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(PulseTheme.secondaryText)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(PulseTheme.grouped)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            // Section 4: Desglose Completo de Días del Plan
                            VStack(alignment: .leading, spacing: 14) {
                                Text(onboardingLocalizedString("onboarding_section_full_days_breakdown"))
                                    .font(.headline.weight(.bold))

                                ForEach(Array(plan.days.enumerated()), id: \.offset) { dayIndex, day in
                                    PulseCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(day.title)
                                                        .font(.subheadline.weight(.heavy))
                                                        .foregroundStyle(.primary)
                                                    Text("\(day.exercises.count) ejercicios · \(day.durationMinutes) min")
                                                        .font(.caption.weight(.medium))
                                                        .foregroundStyle(PulseTheme.secondaryText)
                                                }
                                                Spacer()
                                                if !isPro && dayIndex > 0 {
                                                    Label("Pro Preview", systemImage: "lock.fill")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(PulseTheme.fitOrange)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(PulseTheme.fitOrange.opacity(0.14))
                                                        .clipShape(Capsule())
                                                }
                                            }

                                            Divider().overlay(PulseTheme.separator)

                                            ForEach(Array(day.exercises.enumerated()), id: \.offset) { exIndex, item in
                                                PlanExerciseRow(
                                                    item: item,
                                                    gender: gender,
                                                    language: draft.preferredLanguage,
                                                    exercises: exercises,
                                                    isLocked: !isPro && dayIndex > 0
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .overlay(WatermarkOverlayView())
                }
            }
            .navigationTitle(onboardingLocalizedString("onboarding_plan_architecture_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onboardingLocalizedString("onboarding_btn_continue")) {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isPro {
                    VStack(spacing: 8) {
                        Button {
                            dismiss()
                            onUnlockPro()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.headline.weight(.bold))
                                Text(onboardingLocalizedString("onboarding_pro_unlock_cta"))
                                    .font(.headline.weight(.heavy))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: PulseTheme.accent.opacity(0.35), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                        .pressableFeedback(scale: 0.96)
                    }
                    .padding(16)
                    .background(PulseTheme.background.opacity(0.92))
                }
            }
        }
    }
}

// MARK: - Screenshot Protection & DRM Secure Container View

private class PassthroughSecureTextField: UITextField {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in subviews {
            let convertedPoint = self.convert(point, to: subview)
            if let hit = subview.hitTest(convertedPoint, with: event) {
                return hit
            }
        }
        return nil
    }
}

private struct SecureContainerView<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let field = PassthroughSecureTextField()
        field.isSecureTextEntry = true

        guard let secureContainer = field.subviews.first else {
            let host = UIHostingController(rootView: content)
            return host.view
        }

        secureContainer.isUserInteractionEnabled = true
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        secureContainer.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: secureContainer.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: secureContainer.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: secureContainer.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: secureContainer.trailingAnchor)
        ])

        return field
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct WatermarkOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let text = onboardingLocalizedString("onboarding_watermark_text")
            VStack(spacing: 36) {
                ForEach(0..<12, id: \.self) { _ in
                    HStack(spacing: 24) {
                        ForEach(0..<4, id: \.self) { _ in
                            Text(text)
                                .font(.system(size: 11, weight: .black))
                                .tracking(1.0)
                                .foregroundStyle(PulseTheme.fitOrange.opacity(0.12))
                                .rotationEffect(.degrees(-22))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .allowsHitTesting(false)
        }
    }
}

private struct PlanUnlockProCard: View {
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
                    PlanBenefitRow(icon: "lock.open.fill", text: localizedFormat("onboarding_pro_all_days_fmt", max(daysPerWeek, 4), max(totalWeeks, 8)))
                }

                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline.weight(.black))
                        Text(onboardingLocalizedString("onboarding_pro_unlock_cta"))
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

private struct PlanBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 18)
            Text(onboardingLocalizedString(text))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

private struct OnboardingProgressBodyHero: View {
    let goal: String
    let daysPerWeek: Int
    let minutes: Int

    // Multi-tone heatmaps for Male & Female models
    private var maleHeatmap: [MuscleIntensity] {
        [
            MuscleIntensity(muscle: .chest, intensity: 1.0, color: Color(red: 0.18, green: 0.8, blue: 0.44)),      // Emerald
            MuscleIntensity(muscle: .upperChest, intensity: 0.95, color: Color(red: 1.0, green: 0.76, blue: 0.03)), // Gold
            MuscleIntensity(muscle: .deltoids, intensity: 0.92, color: Color(red: 0.0, green: 0.9, blue: 1.0)),     // Cyan
            MuscleIntensity(muscle: .frontDeltoid, intensity: 0.88, color: Color(red: 0.0, green: 0.9, blue: 1.0)),
            MuscleIntensity(muscle: .biceps, intensity: 0.85, color: Color(red: 1.0, green: 0.44, blue: 0.2)),     // Orange
            MuscleIntensity(muscle: .triceps, intensity: 0.85, color: Color(red: 1.0, green: 0.44, blue: 0.2)),
            MuscleIntensity(muscle: .abs, intensity: 0.98, color: Color(red: 1.0, green: 0.76, blue: 0.03)),        // Gold
            MuscleIntensity(muscle: .upperAbs, intensity: 0.95, color: Color(red: 1.0, green: 0.76, blue: 0.03)),
            MuscleIntensity(muscle: .lowerAbs, intensity: 0.88, color: Color(red: 0.18, green: 0.8, blue: 0.44)),
            MuscleIntensity(muscle: .quadriceps, intensity: 0.88, color: Color(red: 0.0, green: 0.9, blue: 1.0))
        ]
    }

    private var femaleHeatmap: [MuscleIntensity] {
        [
            MuscleIntensity(muscle: .gluteal, intensity: 1.0, color: Color(red: 1.0, green: 0.25, blue: 0.5)),      // Rose Pink
            MuscleIntensity(muscle: .hamstring, intensity: 0.92, color: Color(red: 1.0, green: 0.44, blue: 0.26)),  // Coral
            MuscleIntensity(muscle: .quadriceps, intensity: 0.88, color: Color(red: 1.0, green: 0.76, blue: 0.03)), // Gold
            MuscleIntensity(muscle: .upperBack, intensity: 0.85, color: Color(red: 0.15, green: 0.65, blue: 0.6)),   // Teal
            MuscleIntensity(muscle: .trapezius, intensity: 0.78, color: Color(red: 0.15, green: 0.65, blue: 0.6)),
            MuscleIntensity(muscle: .deltoids, intensity: 0.82, color: Color(red: 0.0, green: 0.9, blue: 1.0)),     // Cyan
            MuscleIntensity(muscle: .obliques, intensity: 0.88, color: Color(red: 1.0, green: 0.25, blue: 0.5)),
            MuscleIntensity(muscle: .calves, intensity: 0.75, color: Color(red: 1.0, green: 0.76, blue: 0.03))
        ]
    }

    var body: some View {
        ZStack {
            backgroundGlow

            VStack(spacing: 12) {
                GeometryReader { proxy in
                    let modelWidth = min((proxy.size.width + 42) / 2, 186)

                    HStack(spacing: -42) {
                        bodyFigure(gender: .male, side: .front, scale: 1.18, heatmap: maleHeatmap)
                            .frame(width: modelWidth, height: proxy.size.height)
                        bodyFigure(gender: .female, side: .back, scale: 0.94, heatmap: femaleHeatmap)
                            .frame(width: modelWidth, height: proxy.size.height)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
                .frame(height: 404)
                .padding(.top, 22)
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    fatTrendBadge
                    Spacer(minLength: 4)
                    strengthBadge
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

    private func bodyFigure(gender: BodyGender, side: BodySide, scale: CGFloat, heatmap: [MuscleIntensity]) -> some View {
        BodyView(gender: gender, side: side, style: .onboardingMonochromeProgress)
            .heatmap(heatmap, configuration: .onboardingMultiToneHeatmap)
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
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.right")
                .font(.headline.weight(.black))
                .foregroundStyle(PulseTheme.ringStand)
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("onboarding_body_hero_strength_muscle"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(localizedString("onboarding_body_hero_strength_est"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PulseTheme.ringStand)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous)
                .stroke(PulseTheme.ringStand.opacity(0.3), lineWidth: 1)
        }
    }

    private var fatTrendBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.right")
                .font(.headline.weight(.black))
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("onboarding_body_hero_fat_loss"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(localizedString("onboarding_body_hero_fat_est"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.35))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.largeRadius, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.3), lineWidth: 1)
        }
    }
}

private struct OnboardingBodyPair: View {
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

private struct OnboardingPressableFeedback: ViewModifier {
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

private extension View {
    func pressableFeedback(scale: CGFloat = 0.96) -> some View {
        modifier(OnboardingPressableFeedback(pressedScale: scale))
    }
}

private extension UserProfile.MainGoal {
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

private extension UserProfile.Experience {
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

private extension BodyViewStyle {
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

private extension HeatmapConfiguration {
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

    static let onboardingMultiToneHeatmap = HeatmapConfiguration(
        colorScale: .repsMultiTone,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.8
    )
}

private extension HeatmapColorScale {
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

    static let repsMultiTone = HeatmapColorScale(colors: [
        Color(red: 0.18, green: 0.8, blue: 0.44),
        Color(red: 1.0, green: 0.76, blue: 0.03),
        Color(red: 0.0, green: 0.9, blue: 1.0),
        Color(red: 1.0, green: 0.25, blue: 0.5)
    ])
}

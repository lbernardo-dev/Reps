import Charts
import MuscleMap
import SwiftUI

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
    @State private var testimonialIndex = 0
    @State private var contentAppeared = false
    @State private var showingBackFromPlan = false

    var onFinish: (OnboardingResult) -> Void

    private let steps = OnboardingStep.allCases

    private var stepIndex: Int {
        steps.firstIndex(of: step) ?? 0
    }

    private var progressValue: Double {
        Double(stepIndex + 1) / Double(steps.count)
    }

    private var bodyMetric: BodyMetric {
        BodyMetric(date: .now, weightKg: draft.weightKg, heightCm: draft.heightCm, source: .manual)
    }

    private var generatedPlan: WorkoutPlan {
        cachedPlan ?? buildPlan()
    }

    private var selectedGender: BodyGender {
        draft.bodyMapPreference.bodyGender
    }

    private var weeklySetTotal: Int {
        generatedPlan.days.flatMap(\.exercises).reduce(0) { $0 + $1.targetSets }
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .hero && (step != .generating || isGenerationComplete) {
                OnboardingProgressHeader(
                    progress: progressValue,
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
            LocalizedStringKey("onboarding_plan_back_title"),
            isPresented: $showingBackFromPlan
        ) {
            Button(LocalizedStringKey("onboarding_plan_back_confirm"), role: .destructive) {
                isGenerationComplete = false
                moveBackward()
            }
            Button(LocalizedStringKey("onboarding_plan_back_cancel"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("onboarding_plan_back_message"))
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .hero:
            heroStep
        case .value:
            valueStep
        case .setup:
            setupStep
        case .goal:
            goalStep
        case .experience:
            experienceStep
        case .schedule:
            scheduleStep
        case .equipment:
            equipmentStep
        case .baseline:
            baselineStep
        case .focus:
            focusStep
        case .generating:
            generatingStep
        case .ready:
            readyStep
        }
    }

    private var heroStep: some View {
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
                Text("\(Text("onboarding_hero_meet"))\(brandText)\(Text("onboarding_hero_partner"))")
                    .font(.system(size: 38, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.76)

                Text("onboarding_hero_tagline")
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

    private var valueStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingTitle(
                title: "onboarding_value_title",
                subtitle: "onboarding_value_subtitle"
            )

            OnboardingProgressBodyHero(
                goal: draft.mainGoal.shortTitle,
                daysPerWeek: draft.weeklyTrainingDays,
                minutes: draft.sessionLengthMinutes
            )
            .frame(height: 540)
        }
    }

    private var setupStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_setup_title",
                subtitle: "onboarding_setup_subtitle"
            )

            VStack(spacing: 12) {
                OnboardingOptionCard(
                    title: "onboarding_setup_create",
                    subtitle: "onboarding_setup_create_sub",
                    icon: "sparkles",
                    tint: PulseTheme.accent,
                    isSelected: !draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = false
                }

                OnboardingOptionCard(
                    title: "onboarding_setup_self",
                    subtitle: "onboarding_setup_self_sub",
                    icon: "wrench.fill",
                    tint: PulseTheme.secondaryText,
                    isSelected: draft.buildsOwnPlan
                ) {
                    draft.buildsOwnPlan = true
                }
            }
        }
    }

    private var goalStep: some View {
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

    private var experienceStep: some View {
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

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_schedule_title",
                subtitle: "onboarding_schedule_subtitle"
            )

            OnboardingNumberPicker(
                title: "onboarding_schedule_days_label",
                value: $draft.weeklyTrainingDays,
                options: Array(1...7),
                unit: "onboarding_schedule_days_unit",
                helper: scheduleHelperText
            )

            OnboardingNumberPicker(
                title: "onboarding_schedule_duration_label",
                value: $draft.sessionLengthMinutes,
                options: [15, 30, 45, 60, 75, 90],
                unit: "onboarding_schedule_duration_unit",
                helper: durationHelperText
            )
        }
    }

    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_equipment_title",
                subtitle: "onboarding_equipment_subtitle"
            )

            VStack(spacing: 12) {
                ForEach(OnboardingLocationCatalog.locations) { location in
                    OnboardingOptionCard(
                        title: location.title,
                        subtitle: location.subtitle,
                        icon: location.icon,
                        tint: PulseTheme.recovery,
                        isSelected: draft.selectedLocationID == location.id
                    ) {
                        draft.applyLocation(location)
                    }
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("onboarding_equipment_available_label")
                        .font(.headline)

                    FlowLayout(spacing: 10) {
                        ForEach(OnboardingLocationCatalog.coreEquipment, id: \.self) { equipment in
                            EquipmentChip(
                                title: OnboardingLocationCatalog.localizedEquipmentKey(equipment),
                                isSelected: draft.availableEquipment.contains(equipment)
                            ) {
                                draft.toggleEquipment(equipment)
                            }
                        }
                    }

                    Text("onboarding_equipment_refine_hint")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var baselineStep: some View {
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
                step: 0.5
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("onboarding_baseline_anatomy_label")
                        .font(.headline)
                    Text("onboarding_baseline_anatomy_subtitle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)

                    HStack(spacing: 8) {
                        ForEach(BodyMapPreference.allCases) { preference in
                            Button {
                                draft.bodyMapPreference = preference
                            } label: {
                                Text(preference.title)
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .contentShape(Capsule())
                                    .foregroundStyle(draft.bodyMapPreference == preference ? .black : PulseTheme.secondaryText)
                                    .background(draft.bodyMapPreference == preference ? .white : PulseTheme.grouped)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .pressableFeedback(scale: 0.94)
                        }
                    }
                }
            }
        }
    }

    private var focusStep: some View {
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

    private var generatingStep: some View {
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

    private var activeGenerationStep: Int {
        if generationProgress < 0.25 { return 0 }
        if generationProgress < 0.55 { return 1 }
        if generationProgress < 0.82 { return 2 }
        return 3
    }

    private static let planTestimonials: [(text: String, author: String)] = [
        (text: "I finally have a plan that fits my schedule and recovery.", author: "Alex R."),
        (text: "The first week was tough but by week 3 I was hooked.", author: "Maria K."),
        (text: "Finally an app that actually adapts to my life.", author: "Carlos M."),
    ]

    private var planGeneratingView: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding_personalizing_title")
                    .font(.system(size: 34, weight: .heavy))
                Text("onboarding_personalizing_subtitle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("PROGRESS")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .tracking(1.2)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [PulseTheme.ringStand, PulseTheme.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: max(16, proxy.size.width * generationProgress))
                    }
                }
                .frame(height: 5)
            }

            PulseCard {
                let stepTitles: [LocalizedStringKey] = [
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

            PulseCard(backgroundColor: PulseTheme.grouped) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PulseTheme.tertiaryText)

                    Text(Self.planTestimonials[testimonialIndex].text)
                        .font(.body.weight(.medium))
                        .italic()
                        .foregroundStyle(PulseTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(testimonialIndex)
                        .transition(.opacity)

                    Text("— \(Self.planTestimonials[testimonialIndex].author)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
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
                GenerationPill(title: "onboarding_pill_days", value: "\(generatedPlan.daysPerWeek)")
                GenerationPill(title: "onboarding_pill_sets", value: "\(weeklySetTotal)")
                GenerationPill(title: "onboarding_pill_weeks", value: "\(generatedPlan.totalWeeks)")
            }

            PlanProjectionCard(
                plan: generatedPlan,
                weeklySetTotal: weeklySetTotal,
                goal: draft.mainGoal,
                experience: draft.experience,
                focusMuscles: Array(draft.focusMuscles).sorted(),
                locationID: draft.selectedLocationID
            )
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "onboarding_ready_title",
                subtitle: "onboarding_ready_subtitle"
            )

            HStack(spacing: 8) {
                GenerationPill(title: "onboarding_pill_days", value: "\(generatedPlan.daysPerWeek)")
                GenerationPill(title: "onboarding_pill_sets", value: "\(weeklySetTotal)")
                GenerationPill(title: "onboarding_pill_weeks", value: "\(generatedPlan.totalWeeks)")
            }

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
                    isPro: store.monetization.hasProAccess
                )
            }

            if !store.monetization.hasProAccess {
                PlanUnlockProCard(
                    totalWeeks: generatedPlan.totalWeeks,
                    daysPerWeek: generatedPlan.daysPerWeek
                ) {
                    store.presentPaywall(source: .onboarding, feature: nil, trigger: .onboarding)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                primaryAction()
            } label: {
                Text(step.primaryButtonTitle)
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
                    Text(store.monetization.hasProAccess ? "onboarding_btn_start_with_plan" : "onboarding_btn_continue_free")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(PulseTheme.textPrimary)
                        .navigationGlassCapsule(.secondary)
                }
                .buttonStyle(.plain)
                .pressableFeedback(scale: 0.98)
            }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var bottomContentPadding: CGFloat {
        step == .ready ? 128 : 82
    }

    private var scheduleHelperText: LocalizedStringKey {
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

    private var durationHelperText: LocalizedStringKey {
        switch draft.sessionLengthMinutes {
        case 15: "onboarding_duration_15min"
        case 30: "onboarding_duration_30min"
        case 45: "onboarding_duration_45min"
        case 60: "onboarding_duration_60min"
        case 75: "onboarding_duration_75min"
        default: "onboarding_duration_90min"
        }
    }

    private func primaryAction() {
        switch step {
        case .ready:
            // The first generated plan is the free activation moment. Pro is
            // offered contextually from the preview, never before first value.
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
        if step == .setup && draft.buildsOwnPlan {
            finishOnboarding()
            return
        }
        step = steps[min(stepIndex + 1, steps.count - 1)]
    }

    private func moveBackward() {
        step = steps[max(stepIndex - 1, 0)]
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
            return OnboardingResult(profile: profile, bodyMetric: bodyMetric, plan: nil, activatePlan: false)
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

    private var selectedFocusMuscles: Set<Muscle> {
        Set(draft.focusMuscles.flatMap(muscles(for:)))
    }

    private var generationHeatmap: [MuscleIntensity] {
        let trained = Set(generatedPlan.days.flatMap(\.exercises).flatMap { muscles(for: $0.exercise.muscleGroup) })
        let focus = selectedFocusMuscles
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

private struct OnboardingDraft {
    var mainGoal: UserProfile.MainGoal = .buildMuscle
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

    static func localizedFocusKey(_ focus: String) -> LocalizedStringKey {
        switch focus {
        case "Chest":     return "muscle_group_chest"
        case "Back":      return "muscle_group_back"
        case "Shoulders": return "muscle_group_shoulders"
        case "Arms":      return "muscle_group_arms"
        case "Legs":      return "muscle_group_legs"
        case "Glutes":    return "muscle_group_glutes"
        case "Core":      return "muscle_group_core"
        default:          return LocalizedStringKey(focus)
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
        profile.mainGoal = mainGoal
        profile.experience = experience
        profile.weeklyTrainingDays = weeklyTrainingDays
        profile.preferredSessionLengthMinutes = sessionLengthMinutes
        profile.trainingLocation = trainingLocation
        profile.availableEquipment = normalizedEquipment
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        profile.sex = bodyMapPreference.profileSex
        profile.preferredLanguage = preferredLanguage
        return profile
    }

    private var normalizedEquipment: [String] {
        OnboardingLocationCatalog.normalizedEquipment(from: availableEquipment)
    }
}

private enum OnboardingStep: CaseIterable {
    case hero
    case value
    case setup
    case goal
    case experience
    case schedule
    case equipment
    case baseline
    case focus
    case generating
    case ready

    var primaryButtonTitle: LocalizedStringKey {
        switch self {
        case .hero: "onboarding_btn_get_started"
        case .value: "onboarding_btn_start_setup"
        case .generating: "onboarding_btn_see_my_plan"
        case .ready: "onboarding_btn_unlock_plan"
        default: "onboarding_btn_continue"
        }
    }
}

private enum BodyMapPreference: String, CaseIterable, Identifiable {
    case mapA
    case mapB
    case preferNotToSay

    var id: String { rawValue }

    var title: LocalizedStringKey {
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

private struct OnboardingProgressHeader: View {
    let progress: Double
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
                .accessibilityLabel("Back")
            } else {
                Color.clear
                    .frame(width: 38, height: 38)
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(PulseTheme.grouped)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(PulseTheme.accent)
                            .frame(width: proxy.size.width * min(max(progress, 0), 1))
                    }
            }
            .frame(height: 4)
        }
        .frame(height: 38)
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

private struct OnboardingTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 34, weight: .heavy))
                .lineLimit(4)
                .minimumScaleFactor(0.72)
            Text(subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingOptionCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let tint: Color
    let isSelected: Bool
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
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
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
            .background(isSelected ? .white.opacity(0.08) : PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.9) : PulseTheme.separator, lineWidth: isSelected ? 1.6 : 1)
            )
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.965)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct OnboardingNumberPicker: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let options: [Int]
    let unit: LocalizedStringKey
    let helper: LocalizedStringKey

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(helper)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(value)")
                        .font(.system(size: 68, weight: .heavy))
                        .contentTransition(.numericText(value: Double(value)))
                    Text(unit)
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            value = option
                        } label: {
                            Text(option == 90 && unit == "onboarding_schedule_duration_unit" ? "90+" : "\(option)")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundStyle(value == option ? .black : PulseTheme.secondaryText)
                                .background(value == option ? .white : PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    let title: LocalizedStringKey
    let valueText: String
    let unit: LocalizedStringKey
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private var progress: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                    Text(title)
                        .font(.headline)
                    Spacer()
                }

                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text(valueText)
                        .font(.system(size: 56, weight: .heavy))
                        .contentTransition(.numericText(value: value))
                    Text(unit)
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Slider(value: $value, in: range, step: step)
                    .tint(.white)

                TickRail(progress: progress)
                    .frame(height: 30)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct TickRail: View {
    let progress: Double

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
                    .fill(.white)
                    .frame(width: 3, height: 30)
                    .offset(x: activeX - 1.5)
                    .shadow(color: .white.opacity(0.36), radius: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct EquipmentChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(height: 40)
                .contentShape(Capsule())
                .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
                .background(isSelected ? PulseTheme.accent : PulseTheme.grouped)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .pressableFeedback(scale: 0.94)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: spacing)], alignment: .leading, spacing: spacing) {
            content
        }
    }
}

private struct HeroSignal: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.black))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OnboardingBenefit: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PulseTheme.accent)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingSignal: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GenerationPill: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
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
    let title: LocalizedStringKey
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
                    } else if isActive {
                        Circle()
                            .stroke(PulseTheme.ringStand, lineWidth: 2.5)
                            .frame(width: 22, height: 22)
                            .scaleEffect(pulse ? 1.15 : 0.88)
                            .opacity(pulse ? 1 : 0.55)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    } else {
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }
                .frame(width: 26, height: 26)

                Text(title)
                    .font(.subheadline.weight(isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : (isCompleted ? .white.opacity(0.75) : PulseTheme.secondaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 4)
            .background(isActive ? .white.opacity(0.07) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if !isLast {
                HStack(spacing: 14) {
                    Rectangle()
                        .fill(isCompleted ? PulseTheme.ringStand.opacity(0.5) : .white.opacity(0.14))
                        .frame(width: 1.5, height: 14)
                        .frame(width: 26)
                    Spacer()
                }
            }
        }
        .onAppear { pulse = isActive }
        .onChange(of: isActive) { _, v in pulse = v }
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isCompleted)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isActive)
    }
}

private struct PlanProjectionCard: View {
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
                        Text(LocalizedStringKey("onboarding_plan_projection_title"))
                            .font(.headline)
                        Text(LocalizedStringKey("onboarding_plan_projection_caption"))
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

private struct PlanLockedDaysCard: View {
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

private struct PlanBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 18)
            Text(LocalizedStringKey(text))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

private struct OnboardingProgressBodyHero: View {
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
            Text("Strength")
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("muscle +")
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
            Text("Fat stores")
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("trend down")
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

    private var setupBadge: some View {
        HStack(spacing: 6) {
            Text(goal)
            Circle()
                .fill(PulseTheme.mediaText.opacity(0.4))
                .frame(width: 4, height: 4)
            Text("\(daysPerWeek)d")
            Circle()
                .fill(PulseTheme.mediaText.opacity(0.4))
                .frame(width: 4, height: 4)
            Text("\(minutes)m")
        }
        .font(.caption.weight(.black))
        .foregroundStyle(PulseTheme.mediaSubtext)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(PulseTheme.mediaText.opacity(0.14), lineWidth: 1)
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
    var title: LocalizedStringKey {
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

    var subtitle: LocalizedStringKey {
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
    var title: LocalizedStringKey {
        switch self {
        case .beginner: "onboarding_exp_beginner"
        case .intermediate: "onboarding_exp_intermediate"
        case .advanced: "onboarding_exp_advanced"
        }
    }

    var subtitle: LocalizedStringKey {
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
}

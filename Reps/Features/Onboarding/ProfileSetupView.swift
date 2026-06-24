import MuscleMap
import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store

    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .hero
    @State private var cachedPlan: WorkoutPlan?
    @State private var generationProgress = 0.0
    @State private var generationStatusText = "Preparing your plan"
    @State private var isGenerationComplete = false
    @State private var generationPulse = false
    @State private var generationTask: Task<Void, Never>?
    @State private var contentAppeared = false

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
            if step != .hero {
                OnboardingProgressHeader(
                    progress: progressValue,
                    canGoBack: stepIndex > 0 && step != .generating,
                    onBack: moveBackward
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
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .hero:
            heroStep
        case .value:
            valueStep
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
                Text("Meet StreakRep.\nYour smartest training partner.")
                    .font(.system(size: 38, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)

                Text("Science-backed programming tailored to your body, goals, and schedule.")
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
                title: "From plan to progress",
                subtitle: "A short setup gives you a real first workout, not a generic template."
            )

            OnboardingProgressBodyHero(
                goal: draft.mainGoal.shortTitle,
                daysPerWeek: draft.weeklyTrainingDays,
                minutes: draft.sessionLengthMinutes
            )
            .frame(height: 540)
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "What is your main goal?",
                subtitle: "This changes volume, rep ranges, rests, and exercise priority."
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
                title: "How long have you trained?",
                subtitle: "We will avoid starting too easy or too aggressive."
            )

            VStack(spacing: 12) {
                ForEach(UserProfile.Experience.allCases) { experience in
                    OnboardingOptionCard(
                        title: experience.title,
                        subtitle: experience.subtitle,
                        icon: experience.icon,
                        tint: PulseTheme.primaryBright,
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
                title: "How much can you train?",
                subtitle: "We will build something you can actually repeat."
            )

            OnboardingNumberPicker(
                title: "Workouts per week",
                value: $draft.weeklyTrainingDays,
                options: Array(2...6),
                unit: "days",
                helper: scheduleHelperText
            )

            OnboardingNumberPicker(
                title: "Session length",
                value: $draft.sessionLengthMinutes,
                options: [30, 45, 60, 75, 90],
                unit: "min",
                helper: durationHelperText
            )
        }
    }

    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Where do you train?",
                subtitle: "We will only use exercises that match your setup."
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
                    Text("Available equipment")
                        .font(.headline)

                    FlowLayout(spacing: 10) {
                        ForEach(OnboardingLocationCatalog.coreEquipment, id: \.self) { equipment in
                            EquipmentChip(
                                title: equipment,
                                isSelected: draft.availableEquipment.contains(equipment)
                            ) {
                                draft.toggleEquipment(equipment)
                            }
                        }
                    }

                    Text("You can refine the full equipment list later in Profile.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var baselineStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Set your starting point",
                subtitle: "These values help estimate initial loads and body progress."
            )

            OnboardingMetricSlider(
                title: "Age",
                valueText: "\(draft.age)",
                unit: "yrs",
                icon: "calendar",
                value: Binding(
                    get: { Double(draft.age) },
                    set: { draft.age = Int($0.rounded()) }
                ),
                range: 14...85,
                step: 1
            )

            OnboardingMetricSlider(
                title: "Height",
                valueText: String(format: "%.0f", draft.heightCm),
                unit: "cm",
                icon: "ruler",
                value: $draft.heightCm,
                range: 130...220,
                step: 1
            )

            OnboardingMetricSlider(
                title: "Weight",
                valueText: String(format: "%.1f", draft.weightKg),
                unit: "kg",
                icon: "scalemass.fill",
                value: $draft.weightKg,
                range: 35...180,
                step: 0.5
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Body map preference")
                        .font(.headline)
                    Text("Used only for anatomy views and muscle visualizations.")
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
                title: "Want to prioritize a muscle group?",
                subtitle: "Pick one or two areas, or keep the plan balanced."
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
                        title: focus,
                        isSelected: draft.focusMuscles.contains(focus)
                    ) {
                        draft.toggleFocus(focus)
                    }
                }
            }

            Button {
                draft.focusMuscles.removeAll()
                moveForward()
            } label: {
                Text("Use a balanced plan")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var generatingStep: some View {
        VStack(spacing: 24) {
            if !isGenerationComplete {
                RepsLoadingView(
                    messages: [generationStatusText],
                    progress: generationProgress,
                    layout: .panel
                )
                .padding(.top, 42)
                .frame(maxWidth: .infinity, minHeight: 430)
            } else {
                VStack(spacing: 22) {
                    OnboardingTitle(
                        title: "Your first block is ready",
                        subtitle: "We matched your goal, time, equipment, and starting point."
                    )

                    OnboardingBodyPair(gender: selectedGender, heatmap: generationHeatmap)
                        .frame(height: 410)
                        .scaleEffect(generationPulse ? 1.02 : 0.98)
                        .opacity(generationPulse ? 1 : 0.82)

                    HStack(spacing: 8) {
                        GenerationPill(title: "Days", value: "\(generatedPlan.daysPerWeek)")
                        GenerationPill(title: "Sets", value: "\(weeklySetTotal)")
                        GenerationPill(title: "Weeks", value: "\(generatedPlan.totalWeeks)")
                    }

                    PlanSummaryCard(plan: generatedPlan)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Your first workout is ready",
                subtitle: "Start with a clear session now. You can review the full plan anytime in Plans."
            )

            PlanSummaryCard(plan: generatedPlan)

            if let firstDay = generatedPlan.days.first {
                PulseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(firstDay.title)
                                    .font(.title3.weight(.bold))
                                Text("\(firstDay.exercises.count) exercises - about \(firstDay.durationMinutes) min")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(.white)
                                .clipShape(Circle())
                        }

                        ForEach(firstDay.exercises.prefix(3)) { item in
                            HStack(spacing: 12) {
                                ExerciseMediaThumbnail(exercise: item.exercise, gender: selectedGender, catalog: store.exercises)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(RepsText.exerciseName(item.exercise.name, language: draft.preferredLanguage))
                                        .font(.subheadline.weight(.bold))
                                        .lineLimit(2)
                                    Text("\(item.targetSets) sets - \(item.repRange)")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }

            PulseCard(backgroundColor: PulseTheme.grouped) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next: reminders and Apple Health")
                            .font(.headline)
                        Text("We will ask for those later, when there is a clear reason. This setup finishes with your plan.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
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
                    Text("Go to Today")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(.white)
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

    private var scheduleHelperText: String {
        switch draft.weeklyTrainingDays {
        case 2: "Minimal and easy to recover from"
        case 3: "Simple full-body or push/pull/legs rhythm"
        case 4: "Strong balance for most lifters"
        case 5: "Higher volume with careful recovery"
        default: "Aggressive schedule for consistent athletes"
        }
    }

    private var durationHelperText: String {
        switch draft.sessionLengthMinutes {
        case 30: "Short and focused sessions"
        case 45: "Efficient sessions with core movements"
        case 60: "Best default for strength and muscle"
        case 75: "More accessories and rest time"
        default: "Long sessions with full volume"
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
        let plan = cachedPlan ?? buildPlan()
        return OnboardingResult(profile: profile, bodyMetric: bodyMetric, plan: plan)
    }

    private func startPlanGeneration() {
        generationTask?.cancel()
        cachedPlan = buildPlan()
        generationProgress = 0
        generationStatusText = "Saving your profile"
        isGenerationComplete = false
        generationPulse = false

        generationTask = Task {
            let updates: [(delay: UInt64, progress: Double, text: String)] = [
                (450_000_000, 0.25, "Filtering exercises by equipment"),
                (900_000_000, 0.55, "Adjusting weekly volume"),
                (1_350_000_000, 0.82, "Preparing your first workout"),
                (1_800_000_000, 1.0, "Plan ready")
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
        let groups = generatedPlan.days.flatMap(\.exercises).flatMap { muscles(for: $0.exercise.muscleGroup) }
        return Set(groups).map { MuscleIntensity(muscle: $0, intensity: generationPulse ? 0.95 : 0.52) }
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

    static let focusOptions = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Core"]

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

    mutating func toggleFocus(_ focus: String) {
        if focusMuscles.contains(focus) {
            focusMuscles.remove(focus)
        } else {
            focusMuscles.insert(focus)
        }
    }

    func makeProfile() -> UserProfile {
        var profile = UserProfile()
        profile.mainGoal = mainGoal
        profile.experience = experience
        profile.weeklyTrainingDays = weeklyTrainingDays
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
    case goal
    case experience
    case schedule
    case equipment
    case baseline
    case focus
    case generating
    case ready

    var primaryButtonTitle: String {
        switch self {
        case .hero: "Get started"
        case .value: "Start setup"
        case .generating: "See my plan"
        case .ready: "Start with my plan"
        default: "Continue"
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
        case .mapA: "Map A"
        case .mapB: "Map B"
        case .preferNotToSay: "Skip"
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
                        .foregroundStyle(.white)
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
                    .fill(.white.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
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
    let title: String
    let subtitle: String

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
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(isSelected ? 0.14 : 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

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
    let title: String
    @Binding var value: Int
    let options: [Int]
    let unit: String
    let helper: String

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
                            Text(option == 90 && unit == "min" ? "90+" : "\(option)")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
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
    let title: String
    let valueText: String
    let unit: String
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
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14)
                .frame(height: 40)
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
    let title: String
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
    let title: String
    let subtitle: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PulseTheme.primary)
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
    let title: String
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
    let title: String
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

private struct PlanSummaryCard: View {
    let plan: WorkoutPlan

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested plan")
                            .font(.headline)
                        Text("\(plan.daysPerWeek) days/week for \(plan.totalWeeks) weeks")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(.white)
                        .clipShape(Circle())
                }

                ForEach(plan.days.prefix(3)) { day in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.primaryBright)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(.subheadline.weight(.bold))
                            Text("\(day.exercises.count) exercises - \(day.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                    }
                }

                if plan.days.count > 3 {
                    Text("+\(plan.days.count - 3) more days in the block")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                }
            }
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
                        bodyFigure(gender: .male, side: .front, scale: 1.04)
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
                    setupBadge
                        .frame(width: 136)
                        .layoutPriority(1)
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
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
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
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var setupBadge: some View {
        HStack(spacing: 6) {
            Text(goal)
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: 4, height: 4)
            Text("\(daysPerWeek)d")
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: 4, height: 4)
            Text("\(minutes)m")
        }
        .font(.caption.weight(.black))
        .foregroundStyle(.white.opacity(0.82))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.14), lineWidth: 1)
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
        case .buildMuscle: "Build muscle"
        case .bodyRecomposition: "Body recomposition"
        case .loseFat: "Lose fat"
        case .getStronger: "Get stronger"
        case .stayActive: "Stay consistent"
        }
    }

    var shortTitle: String {
        switch self {
        case .buildMuscle: "Muscle"
        case .bodyRecomposition: "Recomp"
        case .loseFat: "Fat loss"
        case .getStronger: "Strength"
        case .stayActive: "Consistency"
        }
    }

    var subtitle: String {
        switch self {
        case .buildMuscle: "Prioritize hypertrophy and progressive volume"
        case .bodyRecomposition: "Build muscle while gradually losing fat"
        case .loseFat: "Keep muscle while improving conditioning"
        case .getStronger: "Lower reps, heavier work, longer rests"
        case .stayActive: "Simple sessions that build the habit"
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
        case .buildMuscle: PulseTheme.primary
        case .bodyRecomposition: .white
        case .loseFat: PulseTheme.warning
        case .getStronger: PulseTheme.accent
        case .stayActive: PulseTheme.primaryBright
        }
    }
}

private extension UserProfile.Experience {
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: "Less than 1 year training consistently"
        case .intermediate: "1-3 years with regular sessions"
        case .advanced: "3+ years and comfortable with progression"
        }
    }

    var icon: String {
        switch self {
        case .beginner: "figure.walk"
        case .intermediate: "figure.run"
        case .advanced: "figure.strengthtraining.traditional"
        }
    }
}

private extension BodyViewStyle {
    static let onboardingDark = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.16),
        strokeColor: Color.black.opacity(0.55),
        strokeWidth: 0.65,
        selectionColor: PulseTheme.primary,
        selectionStrokeColor: .white,
        selectionStrokeWidth: 1.6,
        headColor: Color.white.opacity(0.22),
        hairColor: Color.white.opacity(0.10)
    )

    static let onboardingMonochromeProgress = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.08),
        strokeColor: Color.white.opacity(0.26),
        strokeWidth: 0.72,
        selectionColor: .white,
        selectionStrokeColor: .white,
        selectionStrokeWidth: 1.1,
        headColor: Color.white.opacity(0.12),
        hairColor: Color.white.opacity(0.05)
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
        PulseTheme.primary,
        PulseTheme.primaryBright,
        PulseTheme.accent
    ])

    static let repsMonochromeProgress = HeatmapColorScale(colors: [
        .white.opacity(0.34),
        .white.opacity(0.70),
        .white
    ])
}

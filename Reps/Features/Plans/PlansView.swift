import MuscleMap
import SwiftUI

// MARK: - Layout customization

/// The optional, reorderable/hideable cards on Train, including the plan-state
/// hero (`.planHero`, first by default — active plan card or the "start
/// training" empty-state depending on app state, but reorderable/hideable like
/// every other card).
private enum TrainSection: String, CustomizableSection {
    case planHero, library, tools, yourPlans, calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planHero: localizedString("plan_3")
        case .library: localizedString("libraries")
        case .tools: localizedString("tools")
        case .yourPlans: localizedString("your_plans")
        case .calendar: localizedString("Calendar")
        }
    }

    var systemImage: String {
        switch self {
        case .planHero: "bolt.fill"
        case .library: "books.vertical.fill"
        case .tools: "wrench.and.screwdriver.fill"
        case .yourPlans: "square.stack.3d.up.fill"
        case .calendar: "calendar"
        }
    }
}

struct PlansView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreatePlan = false

    private var isProOrHasNoPlan: Bool {
        store.monetization.hasProAccess || store.plans.isEmpty
    }

    private func canManagePlan(_ plan: WorkoutPlan) -> Bool {
        store.monetization.hasProAccess || store.plans.count <= 1 || plan.id == store.activePlan.id
    }

    private func tryOpenCreatePlan() {
        if isProOrHasNoPlan {
            showCreatePlan = true
        } else {
            store.presentPaywall(source: .multiplePlans, feature: nil, trigger: .featureGate)
        }
    }

    private func tryActivateSavedPlan(_ plan: WorkoutPlan) {
        guard canManagePlan(plan) else {
            store.presentPaywall(source: .multiplePlans, feature: nil, trigger: .featureGate)
            return
        }

        HapticService.selection()
        store.activatePlan(plan)
    }

    private func tryEditPlan(_ plan: WorkoutPlan) {
        guard canManagePlan(plan) else {
            store.presentPaywall(source: .multiplePlans, feature: nil, trigger: .featureGate)
            return
        }

        planToEdit = plan
    }

    /// Browsing the catalog (search, filter, read details) is always free.
    /// Activating a program only requires Pro once the free first-plan slot
    /// (`store.plans.isEmpty`) is already used. See ProgramLibraryView.requiresPro.
    private func tryOpenProgramLibrary() {
        showProgramLibrary = true
    }
    @State private var showExerciseLibrary = false
    @State private var planToEdit: WorkoutPlan?
    @State private var selectedPlanForDetail: WorkoutPlan? = nil
    @State private var showProgramLibrary = false
    @State private var showNotifications = false
    @State private var showCalendar = false
    @State private var recommendedWorkout: WorkoutDay? = nil
    @State private var recommendedWorkoutToConfirm: WorkoutDay?
    @State private var workoutToStart: WorkoutDay?
    @State private var showEditLayout = false

    /// A few exercises spanning distinct muscle groups, for the library collage.
    private var collageExercises: [Exercise] {
        var seen = Set<String>()
        var result: [Exercise] = []
        for exercise in store.exercises {
            let group = exercise.muscleGroup.lowercased()
            guard !group.isEmpty, seen.insert(group).inserted else { continue }
            result.append(exercise)
            if result.count >= 4 { break }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            StickyHeaderScaffold(
                title: "plan_3",
                subtitle: "create_and_tune_your_routine",
                accessory: {
                    HStack(spacing: 6) {
                        Button {
                            HapticService.selection()
                            showNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                    .navigationGlassCircle(.secondary, tint: .clear)
                                if store.hasUnreadBell {
                                    Circle()
                                        .fill(PulseTheme.destructive)
                                        .frame(width: 9, height: 9)
                                        .offset(x: -1, y: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("notifications")
                    }
                }
            ) {
                    ForEach(resolvedTrainSections.visible) { section in
                        trainSectionView(for: section)
                    }

                    SecondaryButton("edit_layout", systemImage: "slider.horizontal.3") {
                        HapticService.selection()
                        showEditLayout = true
                    }
            }
            .sheet(isPresented: $showEditLayout) {
                let resolved = resolvedTrainSections
                SectionLayoutEditorSheet(
                    title: localizedString("edit_layout"),
                    visible: resolved.visible,
                    hidden: resolved.hiddenAvailable
                ) { order, hiddenIDs in
                    store.userProfile.trainSectionOrder = order
                    store.userProfile.trainHiddenSectionIDs = hiddenIDs
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(isPresented: $showProgramLibrary) {
                ProgramLibraryView()
                    .environment(store)
            }
            .sheet(item: $planToEdit) { plan in
                CreatePlanView(existingPlan: plan)
            }
            .sheet(item: $selectedPlanForDetail) { plan in
                PlanDetailSheet(plan: plan, isLocked: !canManagePlan(plan)) {
                    tryActivateSavedPlan(plan)
                    if canManagePlan(plan) {
                        selectedPlanForDetail = nil
                    }
                } onEdit: {
                    guard canManagePlan(plan) else {
                        store.presentPaywall(source: .multiplePlans, feature: nil, trigger: .featureGate)
                        return
                    }
                    selectedPlanForDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { planToEdit = plan }
                }
                .environment(store)
            }
            .navigationDestination(isPresented: $showExerciseLibrary) {
                ExerciseLibraryView()
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
            .navigationDestination(item: $workoutToStart) { workout in
                ActiveWorkoutView(workout: workout, origin: .routine)
            }
            .fullScreenCover(isPresented: $showCalendar) {
                CalendarView()
            }
            .alert("recommended_workout_alert_title", isPresented: recommendedWorkoutConfirmationBinding) {
                Button("Cancelar", role: .cancel) {
                    recommendedWorkoutToConfirm = nil
                }
                Button("recommended_workout_alert_confirm") {
                    guard let workout = recommendedWorkoutToConfirm else { return }
                    store.activateRecommendedWorkoutPlan(from: workout)
                    recommendedWorkoutToConfirm = nil
                    workoutToStart = workout
                }
            } message: {
                Text("Se seleccionará como plan de entrenamiento activo.")
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { buildRecommendedWorkoutIfNeeded() }
        }
    }

    private var recommendedWorkoutConfirmationBinding: Binding<Bool> {
        Binding(
            get: { recommendedWorkoutToConfirm != nil },
            set: { isPresented in
                if !isPresented {
                    recommendedWorkoutToConfirm = nil
                }
            }
        )
    }

    private func buildRecommendedWorkoutIfNeeded() {
        guard store.monetization.hasProAccess, recommendedWorkout == nil, store.activeWorkoutStatus == nil, !hasActivePlan else { return }
        let undertrainedMuscles = AnalyticsEngine.competitiveSummary(
            sessions: store.workoutSessions,
            activePlan: store.activePlan,
            exercises: store.exercises,
            since: Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-604_800)
        )
        .undertrainedMuscles
        .map(\.muscleGroup)
        let bodyMetric = store.bodyMetrics.sorted { $0.date > $1.date }.first ?? BodyMetric(date: .now, weightKg: 70, heightCm: 170, source: .manual)
        recommendedWorkout = OnboardingPlanBuilder.makeRecommendedDay(
            profile: store.userProfile,
            bodyMetric: bodyMetric,
            batteryLevel: store.trainingBattery.level,
            undertrainedMuscles: undertrainedMuscles
        )
    }

    private func locationTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }

    private var hasActivePlan: Bool {
        store.hasActiveTrainingPlan
    }

    // MARK: - Layout customization

    private var resolvedTrainSections: (visible: [TrainSection], hiddenAvailable: [TrainSection]) {
        SectionLayoutResolver.resolve(
            storedOrder: store.userProfile.trainSectionOrder,
            storedHidden: store.userProfile.trainHiddenSectionIDs
        )
    }

    @ViewBuilder
    private var planHeroSection: some View {
        if hasActivePlan {
            activePlanSection
            discoveryBanner
        } else {
            if let rec = recommendedWorkout {
                RecommendedWorkoutCard(
                    workout: rec,
                    batteryLevel: store.trainingBattery.level,
                    language: store.userProfile.preferredLanguage,
                    experience: store.userProfile.experience,
                    mainGoal: store.userProfile.mainGoal,
                    weeklyTrainingDays: store.userProfile.weeklyTrainingDays,
                    onStart: {
                        HapticService.impact(.medium)
                        recommendedWorkoutToConfirm = rec
                    }
                )
            }
            startTrainingSection
        }
    }

    @ViewBuilder
    private func trainSectionView(for section: TrainSection) -> some View {
        switch section {
        case .planHero:
            planHeroSection
                .stickyHeaderTitle(hasActivePlan ? localizedString("active_plan") : localizedString("create_plan_2"))
        case .library:
            librarySection
                .stickyHeaderTitle(section.title)
        case .tools:
            toolsSection
                .stickyHeaderTitle(section.title)
        case .yourPlans:
            yourPlansSection
                .stickyHeaderTitle(section.title)
        case .calendar:
            calendarSection
                .stickyHeaderTitle(section.title)
        }
    }

    private var yourPlansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "your_plans_header")
            }

            let inactivePlans = store.plans.filter { $0.id != store.activePlan.id }
            if inactivePlans.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "no_saved_plans",
                        message: "create_plan_from_templates",
                        systemImage: "square.stack.3d.up"
                    )
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(inactivePlans) { plan in
                        PlanCard(plan: plan, isLocked: !canManagePlan(plan)) {
                            selectedPlanForDetail = plan
                        } onActivate: {
                            tryActivateSavedPlan(plan)
                        } onEdit: {
                            tryEditPlan(plan)
                        } onDelete: {
                            store.deletePlan(plan)
                        }
                    }
                }
            }

            Button {
                HapticService.selection()
                tryOpenProgramLibrary()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text(localizedString("browse_programs_button"))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PulseTheme.grouped.opacity(0.3), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .stroke(PulseTheme.accent.opacity(0.3), lineWidth: 1.0)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var calendarSection: some View {
        Button {
            HapticService.selection()
            showCalendar = true
        } label: {
            PulseCard {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedString("Calendar"))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(localizedString("view_day_in_calendar"))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var librarySection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                LibraryHeroHeader(
                    exercises: collageExercises,
                    exerciseCount: store.exercises.count,
                    routineCount: store.workoutTemplates.count
                )

                HStack(spacing: 12) {
                    Button {
                        showExerciseLibrary = true
                    } label: {
                        LibraryShortcut(
                            title: "exercises_3",
                            subtitle: localizedFormat("exercises_available_format", store.exercises.count),
                            systemImage: "magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WorkoutLibraryView()
                    } label: {
                        LibraryShortcut(
                            title: "routines_label",
                            subtitle: localizedFormat("templates_count_format", store.workoutTemplates.count),
                            systemImage: "list.clipboard"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var toolsSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                ToolsHeroHeader()
                HStack(spacing: 12) {
                    NavigationLink {
                        OneRepMaxCalculatorView()
                    } label: {
                        LibraryShortcut(
                            title: "one_rep_max_calculator",
                            subtitle: localizedString("estimate_your_max"),
                            systemImage: "function"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PlateCalculatorView()
                    } label: {
                        LibraryShortcut(
                            title: "weight_plates",
                            subtitle: localizedString("load_the_bar"),
                            systemImage: "circle.grid.3x3.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Compact promo shown below the active plan — discovery is secondary
    /// once training is already underway, so it doesn't need hero real estate.
    private var discoveryBanner: some View {
        Button {
            tryOpenProgramLibrary()
        } label: {
            PulseCard(contentPadding: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 40, height: 40)
                        .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedString("browse_programs_button"))
                            .font(.subheadline.weight(.bold))
                        Text(localizedFormat("programs_available_format", SeedData.defaultPlans.count))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var activePlanSection: some View {
        ActivePlanCommandCard(
            plan: store.activePlan,
            summary: store.activePlanExecutionSummary,
            locationTitle: locationTitle(store.activePlan.location),
            onEdit: { planToEdit = store.activePlan },
            onDeactivate: { store.deactivatePlan(store.activePlan) }
        )

        PlanMusicCard(plan: store.activePlan) {
            planToEdit = store.activePlan
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "training_days_section")
            LazyVStack(spacing: 10) {
                ForEach(store.activePlan.days) { day in
                    NavigationLink {
                        WorkoutDetailView(workout: day)
                    } label: {
                        PlanDayRow(day: day, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Adaptive "get started" section shown while no plan is active.
    /// Collapses what used to be two separate cards (empty state + program
    /// discovery hero) into one, and tailors its content to whether this is
    /// a true cold start or a returning user who just needs to activate a
    /// plan they already saved.
    @ViewBuilder
    private var startTrainingSection: some View {
        if store.plans.isEmpty {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("no_active_plan")
                                .font(.headline)
                            Text("create_your_first_routine_use_a_template_or_open_the_library_to_choose_exercises")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            tryOpenCreatePlan()
                        } label: {
                            Label("create_plan", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .background(PulseTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            WorkoutLibraryView()
                        } label: {
                            Label("ver_rutinas", systemImage: "list.clipboard")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .overlay(PulseTheme.grouped)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(localizedString("program_discovery_subtitle"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            PlanValuePill(value: "\(SeedData.defaultPlans.count)", label: localizedString("program_library_title"), systemImage: "square.grid.2x2")
                            PlanValuePill(value: "\(SeedData.ProgramMetadata.Category.allCases.count)", label: localizedString("goals"), systemImage: "scope")
                            PlanValuePill(value: "\(store.exercises.count)", label: localizedString("exercises_2"), systemImage: "figure.strengthtraining.traditional")
                        }

                        Button {
                            tryOpenProgramLibrary()
                        } label: {
                            Label(localizedString("browse_programs_button"), systemImage: "sparkles")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.badge.clock.fill")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(localizedFormat("saved_plans_ready_format", store.plans.count))
                                .font(.headline)
                            Text(localizedString("activate_one_below_or_discover_a_new_program"))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            tryOpenCreatePlan()
                        } label: {
                            Label(
                                store.monetization.hasProAccess ? localizedString("create_plan") : localizedString("create_plan_pro_locked"),
                                systemImage: store.monetization.hasProAccess ? "plus" : "lock.fill"
                            )
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            tryOpenProgramLibrary()
                        } label: {
                            Label(localizedString("social_discover"), systemImage: "sparkles")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ActivePlanCommandCard: View {
    let plan: WorkoutPlan
    let summary: FitnessMetrics.PlanExecutionSummary?
    let locationTitle: String
    let onEdit: () -> Void
    let onDeactivate: () -> Void

    private var planProgress: Double {
        summary?.planProgress ?? 0
    }

    private var statusTint: Color {
        switch summary?.loadState {
        case .onTrack:
            return PulseTheme.recovery
        case .behind:
            return PulseTheme.warning
        case .overreaching:
            return PulseTheme.destructive
        case .noData, .none:
            return PulseTheme.accent
        }
    }

    private var statusText: String {
        switch summary?.loadState {
        case .onTrack:
            return localizedString("on_track")
        case .behind:
            return localizedString("review_plan")
        case .overreaching:
            return localizedString("recovery_2")
        case .noData, .none:
            return localizedString("in_progress_label")
        }
    }

    private var volumeText: String {
        guard let summary else { return "0 kg" }
        return "\(Int(summary.volumeThisWeekKg.rounded())) kg"
    }

    private var weeklySetsText: String {
        guard let summary else { return "0/0" }
        return "\(summary.actualWeeklySets)/\(max(summary.targetWeeklySets, 0))"
    }

    private var adherenceText: String {
        guard let summary else { return "0/\(plan.daysPerWeek)" }
        return "\(summary.completedThisWeek)/\(summary.daysPerWeek)"
    }

    private var weekText: String {
        guard plan.totalWeeks > 0 else { return "0/0" }
        return "\(max(plan.currentWeek, 1))/\(plan.totalWeeks)"
    }

    private var compactLocationTitle: String {
        switch plan.location {
        case .gym:
            return localizedString("gym")
        case .home:
            return localizedString("home")
        case .both:
            return "Casa/gym"
        }
    }

    private var compactFrequencyTitle: String {
        localizedFormat("days_per_week_short_format", plan.daysPerWeek)
    }

    private var statusIcon: String {
        switch summary?.loadState {
        case .onTrack:
            return "checkmark.circle.fill"
        case .behind:
            return "clock.badge.exclamationmark.fill"
        case .overreaching:
            return "exclamationmark.triangle.fill"
        case .noData, .none:
            return "bolt.fill"
        }
    }

    var body: some View {
        PulseCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(statusText, systemImage: statusIcon)
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(statusTint)
                            .lineLimit(1)
                        Text(plan.name)
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)

                        HStack(spacing: 8) {
                            PlanContextPill(title: compactLocationTitle, systemImage: "mappin.and.ellipse", tint: PulseTheme.ringStand)
                            PlanContextPill(title: compactFrequencyTitle, systemImage: "calendar", tint: PulseTheme.accent)
                            PlanContextPill(title: weekText, systemImage: "flag.checkered", tint: PulseTheme.recovery)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        Menu {
                            Button("edit_plan", action: onEdit)
                            Button("deactivate_plan", role: .destructive, action: onDeactivate)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(width: 38, height: 38)
                                .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .accessibilityLabel("plan_actions")

                        PlanProgressDial(progress: planProgress, tint: statusTint)
                            .frame(width: 58, height: 58)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    PlanMetricTile(value: adherenceText, label: localizedString("this_week"), systemImage: "calendar.badge.checkmark", tint: PulseTheme.recovery)
                    PlanMetricTile(value: volumeText, label: localizedString("volume_2"), systemImage: "scalemass.fill", tint: PulseTheme.ringStand)
                    PlanMetricTile(value: weeklySetsText, label: localizedString("sets_3"), systemImage: "checklist.checked", tint: PulseTheme.semanticProgress)
                }

                if let summary {
                    PlanExecutionBars(points: summary.weeklyPoints, tint: statusTint)
                }

                if let targetEventName = plan.targetEventName,
                   let targetEventDate = plan.targetEventDate {
                    PlanTargetEventSummary(
                        eventName: targetEventName,
                        eventDate: targetEventDate
                    )
                }
            }
        }
    }
}

private struct PlanProgressDial: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.18), PulseTheme.grouped.opacity(0.35), PulseTheme.grouped.opacity(0.18)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 44
                    )
                )
            Circle()
                .stroke(PulseTheme.separator.opacity(0.55), lineWidth: 7)
                .padding(4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                Text("%")
                    .font(.system(size: 8, weight: .black, design: .rounded))
            }
            .foregroundStyle(tint)
        }
    }
}

private struct PlanContextPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(tint.opacity(0.09), in: Capsule())
    }
}

private struct PlanValuePill: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(PulseTheme.accent)
            Text(value)
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PlanMetricTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.66)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.15), PulseTheme.grouped.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanExecutionBars: View {
    let points: [FitnessMetrics.PlanWeekPoint]
    let tint: Color

    private var maxVolume: Double {
        max(points.map(\.volumeKg).max() ?? 0, 1)
    }

    private var hasAnySession: Bool {
        points.contains { $0.sessions > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(localizedString("real_execution"), systemImage: "chart.bar.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .textCase(.uppercase)
                Spacer()
                if hasAnySession {
                    Text(localizedFormat("weeks_short_count_format", "6"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.12), in: Capsule())
                }
            }

            if hasAnySession {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points) { point in
                        VStack(spacing: 6) {
                            GeometryReader { proxy in
                                let height = max(10, CGFloat(point.volumeKg / maxVolume) * proxy.size.height)
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(PulseTheme.card.opacity(0.82))
                                    Capsule()
                                        .fill(barColor(for: point))
                                        .frame(height: point.sessions > 0 ? height : 8)
                                }
                            }
                            .frame(height: 54)

                            Text("\(point.sessions)/\(point.targetSessions)")
                                .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(point.sessions > 0 ? barColor(for: point) : PulseTheme.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("plan_no_sessions_yet_title")
                            .font(.caption.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        Text("plan_no_sessions_yet_message")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.10), PulseTheme.grouped.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 0.8)
        }
    }

    private func barColor(for point: FitnessMetrics.PlanWeekPoint) -> Color {
        guard point.sessions > 0 else { return PulseTheme.tertiaryText.opacity(0.45) }
        if point.targetSessions > 0, point.sessions >= point.targetSessions {
            return PulseTheme.recovery
        }
        return PulseTheme.warning
    }
}

private struct LibraryHeroHeader: View {
    let exercises: [Exercise]
    let exerciseCount: Int
    let routineCount: Int

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [PulseTheme.accent.opacity(0.30), PulseTheme.ringStand.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Collage of anatomy thumbnails bleeding off the trailing edge.
            HStack(spacing: -26) {
                ForEach(Array(exercises.prefix(4).enumerated()), id: \.offset) { index, exercise in
                    ExerciseAnatomyThumbnail(exercise: exercise, size: 96)
                        .rotationEffect(.degrees(Double(index - 1) * 5))
                        .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 3)
                        .zIndex(Double(4 - index))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: 30)

            // Readability scrim so the title reads over the collage.
            LinearGradient(
                colors: [PulseTheme.elevated, PulseTheme.elevated.opacity(0.85), PulseTheme.elevated.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.ringStand)
                Text("library_hero_title")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(localizedFormat("library_hero_subtitle_format", exerciseCount, routineCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 124)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ToolsHeroHeader: View {
    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [PulseTheme.accent.opacity(0.28), PulseTheme.fitOrange.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Playful oversized tool glyphs on the trailing side.
            HStack(spacing: 14) {
                Image(systemName: "function")
                Image(systemName: "circle.grid.3x3.fill")
            }
            .font(.system(size: 54, weight: .bold))
            .foregroundStyle(PulseTheme.accent.opacity(0.22))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: 16)

            LinearGradient(
                colors: [PulseTheme.elevated, PulseTheme.elevated.opacity(0.85), PulseTheme.elevated.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
                Text("tools_hero_title")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("tools_hero_subtitle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct LibraryShortcut: View {
    let title: LocalizedStringKey
    let subtitle: String
    let systemImage: String

    var body: some View {
        let components = subtitle.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        let firstWord = components.first.map(String.init) ?? ""
        let isDigit = firstWord.allSatisfy(\.isNumber) && !firstWord.isEmpty

        let countText = isDigit ? firstWord : ""
        let labelText = isDigit ? (components.count > 1 ? String(components[1]) : "") : subtitle

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                PulseIconBadge(systemImage: systemImage, tint: PulseTheme.ringStand, size: 32, radius: PulseTheme.smallRadius)
                Spacer()
                if !countText.isEmpty {
                    Text(countText)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.ringStand)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(isDigit ? labelText.capitalized : localizedKey(subtitle))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .background(PulseTheme.grouped.opacity(0.72), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 0.8)
        )
    }
}

private struct PlanTargetEventSummary: View {
    let eventName: String
    let eventDate: Date

    private var eventState: (days: Int, weeks: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.startOfDay(for: eventDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (days, max(0, days / 7))
    }

    private var statusText: String {
        let state = eventState
        if state.days > 0 {
            return localizedFormat("days_weeks_remaining_format", state.days, state.weeks)
        }
        if state.days == 0 {
            return localizedString("today_2")
        }
        return localizedString("completed_3")
    }

    private var adviceText: String {
        let state = eventState
        if state.days <= 0 {
            return localizedString("event_reached_review_results_and_prepare_next_block")
        }
        if state.weeks < 6 {
            return localizedString("short_deadline_prioritize_consistency_and_controlled_intensity")
        }
        if state.weeks <= 12 {
            return localizedString("optimal_deadline_progressive_block_window")
        }
        return localizedString("long_deadline_strength_hypertrophy_block")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(PulseTheme.accent)
                Text(localizedFormat("goal_value_format", eventName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(PulseTheme.ringStand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PulseTheme.ringStand.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(adviceText)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PlanCard: View {
    let plan: WorkoutPlan
    var isLocked: Bool = false
    let onTap: () -> Void
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var locationColor: Color {
        switch plan.location {
        case .gym: return PulseTheme.accent
        case .home: return PulseTheme.recovery
        case .both: return PulseTheme.ringStand
        }
    }

    private var locationIcon: String {
        switch plan.location {
        case .gym: return "dumbbell.fill"
        case .home: return "house.fill"
        case .both: return "bolt.fill"
        }
    }

    private var topExerciseNames: [String] {
        Array(plan.days.flatMap { $0.exercises }.prefix(4).map { $0.exercise.name })
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    PulseIconBadge(systemImage: locationIcon, tint: locationColor, size: 52, radius: PulseTheme.compactRadius, isFilled: true)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold color
                            .frame(width: 16, height: 16)
                            .background(Color.black.opacity(0.6), in: Circle())
                            .overlay(Circle().stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4), lineWidth: 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(.primary)

                    HStack(spacing: 10) {
                        Label(localizedFormat("days_per_week_short_format", plan.daysPerWeek), systemImage: "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)

                        let totalEx = plan.days.flatMap { $0.exercises }.count
                        if totalEx > 0 {
                            Label("\(totalEx)", systemImage: "dumbbell")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    if !topExerciseNames.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(topExerciseNames.prefix(2), id: \.self) { name in
                                Text(name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Capsule())
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(maxWidth: 104, alignment: .leading)
                            }
                            if topExerciseNames.count > 2 {
                                Text("+\(plan.days.flatMap { $0.exercises }.count - 2)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(locationColor)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText.opacity(0.5))
                        .padding(.trailing, 4)

                    Menu {
                        Button {
                            onActivate()
                        } label: {
                            Label(isLocked ? localizedString("activate_plan_pro_locked") : localizedString("activate_plan"), systemImage: isLocked ? "lock.fill" : "bolt.fill")
                        }
                        Button {
                            onEdit()
                        } label: {
                            Label(isLocked ? localizedString("edit_plan_pro_locked") : localizedString("edit_plan"), systemImage: isLocked ? "lock.fill" : "pencil")
                        }
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label(localizedString("delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .frame(width: 36, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.separator, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onActivate()
            } label: {
                Label(isLocked ? localizedString("activate_plan_pro_locked") : localizedString("activate_plan"), systemImage: isLocked ? "lock.fill" : "bolt.fill")
            }
            Button {
                onEdit()
            } label: {
                Label(isLocked ? localizedString("edit_plan_pro_locked") : localizedString("edit_plan"), systemImage: isLocked ? "lock.fill" : "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(localizedString("delete"), systemImage: "trash")
            }
        }
    }
}

private struct PlanDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let plan: WorkoutPlan
    let isLocked: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void

    private var locationColor: Color {
        switch plan.location {
        case .gym: return PulseTheme.accent
        case .home: return PulseTheme.recovery
        case .both: return PulseTheme.ringStand
        }
    }

    private var planExercises: [Exercise] {
        plan.days.flatMap { $0.exercises.map(\.exercise) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PulseCard {
                        HStack(spacing: 14) {
                            Image(systemName: plan.location == .gym ? "dumbbell.fill" : plan.location == .home ? "house.fill" : "bolt.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PulseTheme.onColor(locationColor))
                                .frame(width: 56, height: 56)
                                .background(locationColor, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.name)
                                    .font(.title3.weight(.bold))
                                HStack(spacing: 12) {
                                    Label(localizedFormat("days_per_week_short_format", plan.daysPerWeek), systemImage: "calendar")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    Label("\(plan.days.count) \(localizedString("days"))", systemImage: "figure.strengthtraining.traditional")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                            Spacer()
                        }
                    }

                    if !planExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizedString("muscles_worked"))
                                .font(.headline)
                            WorkoutMusclePreview(exercises: planExercises, gender: store.userProfile.muscleMapGender)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                        }
                    }

                    if !plan.days.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizedString("training_days_section"))
                                .font(.headline)
                            LazyVStack(spacing: 10) {
                                ForEach(plan.days) { day in
                                    NavigationLink {
                                        WorkoutDetailView(workout: day)
                                    } label: {
                                        PlanDayRow(day: day, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 16)
            }
            .screenBackground()
            .navigationTitle(Text(plan.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onEdit()
                    } label: {
                        Label(localizedString("edit_plan"), systemImage: isLocked ? "lock.fill" : "pencil")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onActivate) {
                    Label(
                        isLocked ? localizedString("activate_plan_pro_locked") : localizedString("activate_plan"),
                        systemImage: isLocked ? "lock.fill" : "bolt.fill"
                    )
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(PulseTheme.onColor(locationColor))
                        .background(locationColor, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(PulseTheme.separator)
                        .frame(height: 0.8)
                }
            }
        }
    }
}

private struct PlanRow: View {
    let plan: WorkoutPlan

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: plan.location == .home ? "house.fill" : "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 52, height: 52)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.title3.weight(.bold))
                Text(localizedFormat("days_per_week_short_format", plan.daysPerWeek)).foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanDayRow: View {
    let day: WorkoutDay
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        PulseCard(contentPadding: 14) {
            HStack(alignment: .top, spacing: 12) {
                dayThumbnail

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.title)
                                .font(.headline.weight(.black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text(day.subtitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer(minLength: 8)
                        Label("\(day.durationMinutes) min", systemImage: "clock")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(1)
                    }

                    if !day.exercises.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(day.exercises.prefix(3)) { workoutExercise in
                                HStack(spacing: 5) {
                                    ExerciseMediaThumbnail(exercise: workoutExercise.exercise, gender: gender, catalog: catalog)
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                    Text(workoutExercise.exercise.name)
                                        .font(.caption2.weight(.bold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }
                                .padding(.leading, 3)
                                .padding(.trailing, 8)
                                .padding(.vertical, 4)
                                .background(PulseTheme.grouped, in: Capsule())
                            }
                            if day.exercises.count > 3 {
                                Text("+\(day.exercises.count - 3)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(PulseTheme.accent.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .padding(.top, 4)
            }
        }
    }

    private var dayThumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let first = day.exercises.first?.exercise {
                    ExerciseMediaThumbnail(exercise: first, gender: gender, catalog: catalog)
                } else {
                    Rectangle().fill(PulseTheme.accent.opacity(0.10))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            Text("\(day.exercises.count)")
                .font(.caption2.weight(.black).monospacedDigit())
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(PulseTheme.accent, in: Capsule())
                .overlay(Capsule().stroke(PulseTheme.card, lineWidth: 1.5))
                .offset(x: 6, y: 6)
        }
    }
}

private struct PlanMusicCard: View {
    let plan: WorkoutPlan
    let onEdit: () -> Void
    @Environment(\.openURL) private var openURL
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer.shared

    private var primaryPlaylist: PlanPlaylist? {
        plan.playlists.first
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("plan_music", systemImage: "music.note.list")
                        .font(.headline)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: plan.playlists.isEmpty ? "plus.circle.fill" : "slider.horizontal.3")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .accessibilityLabel(plan.playlists.isEmpty ? localizedString("add_playlist") : localizedString("edit_playlists"))
                }

                if let primaryPlaylist {
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: primaryPlaylist.provider)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryPlaylist.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(statusTitle(for: primaryPlaylist))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            playPlaylist(primaryPlaylist)
                        } label: {
                            Image(systemName: playButtonIcon(for: primaryPlaylist))
                                .foregroundStyle(PulseTheme.onColor(primaryPlaylist.provider == .appleMusic ? PulseTheme.appleMusic : PulseTheme.accent))
                                .frame(width: 44, height: 44)
                                .background(primaryPlaylist.provider == .appleMusic ? PulseTheme.appleMusic : PulseTheme.accent)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(localizedString(primaryPlaylist.provider == .appleMusic ? "play_in_reps" : "open_playlist"))
                    }

                    if plan.playlists.count > 1 {
                        Text(localizedFormat("alternative_playlists_count_format", plan.playlists.count - 1))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                } else {
                    Text("add_an_apple_music_playlist_to_start_it_from_the_workout")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                    Button(action: onEdit) {
                        Label("conectar_playlist", systemImage: "link.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private func statusTitle(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic ? musicPlayer.statusText(for: playlist) : providerTitle(playlist.provider)
    }

    private func playButtonIcon(for playlist: PlanPlaylist) -> String {
        playlist.provider == .appleMusic && musicPlayer.isPlaying(playlist) ? "pause.fill" : "play.fill"
    }

    private func playPlaylist(_ playlist: PlanPlaylist) {
        if playlist.provider == .appleMusic {
            Task {
                await musicPlayer.playOrPause(playlist)
            }
            return
        }

        guard let url = URL(string: playlist.urlString) else {
            return
        }
        openURL(url)
    }
}

private struct PlaylistProviderBadge: View {
    let provider: PlanPlaylist.Provider

    var body: some View {
        Image(systemName: "music.note")
            .font(.title3.weight(.bold))
            .foregroundStyle(PulseTheme.onColor(PulseTheme.appleMusic))
            .frame(width: 52, height: 52)
            .background(PulseTheme.appleMusic)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

struct PlanPlaylistEditor: View {
    @Binding var playlists: [PlanPlaylist]
    @Binding var showMusicConnector: Bool
    @State private var title = ""
    @State private var urlString = ""
    @State private var notes = ""

    @State private var showManualForm = false

    var body: some View {
        Section("music") {
            if playlists.isEmpty {
                Text("save_apple_music_playlists_to_open_them_during_workouts")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playlists) { playlist in
                    HStack(spacing: 12) {
                        PlaylistProviderBadge(provider: playlist.provider)
                            .frame(width: 38, height: 38)
                        VStack(alignment: .leading) {
                            Text(playlist.title)
                                .font(.headline)
                            Text(providerTitle(playlist.provider))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            playlists.removeAll { $0.id == playlist.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            Button {
                showMusicConnector = true
            } label: {
                Label("connect_from_library", systemImage: "music.note.list")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.appleMusic))
                    .background(PulseTheme.appleMusic)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
                    .shadow(color: PulseTheme.surfaceShadow, radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)

            DisclosureGroup(isExpanded: $showManualForm) {
                VStack(spacing: 12) {
                    TextField("playlist_name", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("https://music.apple.com/...", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("nota_opcional_fuerza_cardio_focus", text: $notes)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        addPlaylist()
                    } label: {
                        Label("add_manual_playlist", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(canAdd ? PulseTheme.accent : PulseTheme.secondaryText.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.smallRadius, style: .continuous))
                    }
                    .disabled(!canAdd)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            } label: {
                Text("add_manually_by_url")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func addPlaylist() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        playlists.append(
            PlanPlaylist(
                provider: .appleMusic,
                title: trimmedTitle,
                urlString: trimmedURL,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
        )
        title = ""
        urlString = ""
        notes = ""
    }
}

private func providerTitle(_ provider: PlanPlaylist.Provider) -> String {
    switch provider {
    case .appleMusic: "Apple Music"
    }
}

struct CompactStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedKey(title))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            
            HStack(spacing: 2) {
                Button {
                    value = max(range.lowerBound, value - step)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Text("\(value)\(suffix)")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                
                Button {
                    value = min(range.upperBound, value + step)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 40)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .background(PulseTheme.grouped)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// Numeric-only seconds input (digits filtered as typed, no upper bound) —
/// used for the exercise-change timer, which the user can extend well past
/// the 5 min default and shouldn't be capped like a stepper range.
struct NumericSecondsField: View {
    let title: String
    @Binding var seconds: Int
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(localizedKey(title))
                .font(.subheadline)
            Spacer()
            TextField("300", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { text = filtered }
                    seconds = Int(filtered) ?? 0
                }
            Text("s")
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .onAppear {
            if text.isEmpty { text = String(seconds) }
        }
    }
}

struct PlanPreviewDay: View {
    let title: String
    let workout: String
    let exercises: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                CardTitle(verbatim: title)
                Text(workout).foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Text(localizedFormat("exercises_count_format", exercises))
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }
}

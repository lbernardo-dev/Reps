import SwiftUI

struct PlansView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreatePlan = false

    private var isProOrHasNoPlan: Bool {
        store.monetization.hasProAccess || store.plans.isEmpty
    }

    private func tryOpenCreatePlan() {
        if isProOrHasNoPlan {
            showCreatePlan = true
        } else {
            store.presentPaywall(source: .multiplePlans, feature: nil, trigger: .featureGate)
        }
    }

    private func tryOpenProgramLibrary() {
        if isProOrHasNoPlan {
            showProgramLibrary = true
        } else {
            store.presentPaywall(source: .programLibrary, feature: nil, trigger: .featureGate)
        }
    }
    @State private var showExerciseLibrary = false
    @State private var planToEdit: WorkoutPlan?
    @State private var selectedPlanForDetail: WorkoutPlan? = nil
    @State private var showProfile = false
    @State private var showProgramLibrary = false
    @State private var showNotifications = false
    @State private var showSocialHub = false

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
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                if store.hasUnreadBell {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 9, height: 9)
                                        .offset(x: -1, y: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("notifications")

                        if store.userProfile.socialEnabled {
                            Button {
                                HapticService.selection()
                                showSocialHub = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(PulseTheme.primary)
                                        .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                    if store.unreadFeedCount > 0 {
                                        Circle()
                                            .fill(.red)
                                            .frame(width: 9, height: 9)
                                            .offset(x: -1, y: 1)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("social_hub")
                        }

                        HeaderAvatarButton(
                            imageData: store.userProfile.avatarImageData,
                            accessibilityLabel: "profile"
                        ) {
                            showProfile = true
                        }
                    }
                }
            ) {
                    if hasActivePlan {
                        activePlanSection
                            .stickyHeaderTitle(localizedString("active_plan"))
                    } else {
                        emptyPlanSection
                            .stickyHeaderTitle(localizedString("create_plan_2"))
                    }

                    programDiscoverySection
                        .stickyHeaderTitle(localizedString("browse_programs_button"))

                    librarySection
                        .stickyHeaderTitle(localizedString("libraries"))

                    toolsSection
                        .stickyHeaderTitle(localizedString("tools"))

                    HStack {
                        SectionHeader(title: "your_plans_header")
                        Spacer()
                        Button {
                            tryOpenProgramLibrary()
                        } label: {
                            Label(localizedString("browse_programs_button"), systemImage: "magnifyingglass")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .stickyHeaderTitle(localizedString("your_plans"))

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
                                PlanCard(plan: plan, isLocked: !store.monetization.hasProAccess) {
                                    selectedPlanForDetail = plan
                                } onActivate: {
                                    if store.monetization.hasProAccess {
                                        HapticService.selection()
                                        store.activatePlan(plan)
                                    } else {
                                        store.presentPaywall(source: .onboarding, feature: nil, trigger: .featureGate)
                                    }
                                } onEdit: {
                                    planToEdit = plan
                                } onDelete: {
                                    store.deletePlan(plan)
                                }
                            }
                        }
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
                EditPlanView(plan: plan)
            }
            .sheet(item: $selectedPlanForDetail) { plan in
                PlanDetailSheet(plan: plan) {
                    if store.monetization.hasProAccess {
                        store.activatePlan(plan)
                        selectedPlanForDetail = nil
                    } else {
                        store.presentPaywall(source: .onboarding, feature: nil, trigger: .featureGate)
                    }
                } onEdit: {
                    selectedPlanForDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        planToEdit = plan
                    }
                }
                .environment(store)
            }
            .navigationDestination(isPresented: $showExerciseLibrary) {
                ExerciseLibraryView()
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
            .navigationDestination(isPresented: $showSocialHub) {
                SocialHubView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func locationTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }

    private var hasActivePlan: Bool {
        !store.activePlan.days.isEmpty
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

    private var programDiscoverySection: some View {
        PulseCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedString("browse_programs_button"))
                            .font(.title3.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(localizedString("program_discovery_subtitle"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    PlanValuePill(value: "\(SeedData.defaultPlans.count)", label: localizedString("program_library_title"), systemImage: "square.grid.2x2")
                    PlanValuePill(value: "\(SeedData.ProgramMetadata.Category.allCases.count)", label: localizedString("goals"), systemImage: "scope")
                    PlanValuePill(value: "\(store.exercises.count)", label: localizedString("exercises_2"), systemImage: "figure.strengthtraining.traditional")
                }

                HStack(spacing: 10) {
                    Button {
                        tryOpenProgramLibrary()
                    } label: {
                        Label(localizedString("browse_programs_button"), systemImage: "sparkles")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        tryOpenCreatePlan()
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.black))
                            .frame(width: 50, height: 50)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedString("create_plan"))
                }
            }
        }
    }

    @ViewBuilder
    private var activePlanSection: some View {
        ActivePlanCommandCard(
            plan: store.activePlan,
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
                        PlanDayRow(day: day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyPlanSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(.white)
                        .background(PulseTheme.primary)
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
                            .foregroundStyle(.black)
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
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    tryOpenProgramLibrary()
                } label: {
                    Label(localizedString("browse_programs_button"), systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ActivePlanCommandCard: View {
    let plan: WorkoutPlan
    let locationTitle: String
    let onEdit: () -> Void
    let onDeactivate: () -> Void

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(max(plan.completion, 0), 1))
                            .stroke(PulseTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(plan.completion * 100))%")
                            .font(.caption.weight(.black).monospacedDigit())
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("in_progress_label", systemImage: "bolt.fill")
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.accent)
                        Text(plan.name)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        HStack(spacing: 8) {
                            Label(locationTitle, systemImage: "mappin.and.ellipse")
                            Text("·")
                            Label(localizedFormat("days_per_week_short_format", plan.daysPerWeek), systemImage: "calendar")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    }

                    Spacer(minLength: 0)

                    Menu {
                        Button("edit_plan", action: onEdit)
                        Button("deactivate_plan", role: .destructive, action: onDeactivate)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .frame(width: 42, height: 42)
                            .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .accessibilityLabel("plan_actions")
                }

                HStack(spacing: 8) {
                    PlanValuePill(value: "\(plan.currentWeek)/\(plan.totalWeeks)", label: "Week", systemImage: "calendar")
                    PlanValuePill(value: "\(plan.days.count)", label: "Days", systemImage: "list.clipboard")
                    PlanValuePill(value: "\(plan.days.reduce(0) { $0 + $1.exercises.count })", label: localizedString("exercises_2"), systemImage: "dumbbell.fill")
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

private struct PlanValuePill: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(PulseTheme.primary)
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

private struct LibraryHeroHeader: View {
    let exercises: [Exercise]
    let exerciseCount: Int
    let routineCount: Int

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [PulseTheme.primary.opacity(0.30), PulseTheme.primaryBright.opacity(0.18)],
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
                    .foregroundStyle(PulseTheme.primaryBright)
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
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 38, height: 38)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            Text(localizedKey(title))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(localizedKey(subtitle))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
                    .foregroundStyle(PulseTheme.primary)
                Text(localizedFormat("goal_value_format", eventName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(PulseTheme.primaryBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(PulseTheme.primaryBright.opacity(0.12))
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
        case .gym: return PulseTheme.primary
        case .home: return PulseTheme.recovery
        case .both: return PulseTheme.accent
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
                    Image(systemName: locationIcon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(locationColor, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(PulseTheme.accent, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.headline)
                        .lineLimit(1)
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
                            ForEach(topExerciseNames.prefix(3), id: \.self) { name in
                                Text(name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Capsule())
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            if topExerciseNames.count > 3 {
                                Text("+\(plan.days.flatMap { $0.exercises }.count - 3)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(locationColor)
                            }
                        }
                    }
                }

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
                            Label(localizedString("activate_plan"), systemImage: "bolt.fill")
                        }
                        Button {
                            onEdit()
                        } label: {
                            Label(localizedString("edit_plan"), systemImage: "pencil")
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
                    .stroke(PulseTheme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onActivate()
            } label: {
                Label(localizedString("activate_plan"), systemImage: "bolt.fill")
            }
            Button {
                onEdit()
            } label: {
                Label(localizedString("edit_plan"), systemImage: "pencil")
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
    let onActivate: () -> Void
    let onEdit: () -> Void

    private var locationColor: Color {
        switch plan.location {
        case .gym: return PulseTheme.primary
        case .home: return PulseTheme.recovery
        case .both: return PulseTheme.accent
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PulseCard {
                        HStack(spacing: 14) {
                            Image(systemName: plan.location == .gym ? "dumbbell.fill" : plan.location == .home ? "house.fill" : "bolt.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
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

                    if !plan.days.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localizedString("training_days_section"))
                                .font(.headline)
                            LazyVStack(spacing: 10) {
                                ForEach(plan.days) { day in
                                    NavigationLink {
                                        WorkoutDetailView(workout: day)
                                    } label: {
                                        PlanDayRow(day: day)
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
                    Button(localizedString("edit_plan")) { onEdit() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onActivate) {
                    Label(localizedString("activate_plan"), systemImage: "bolt.fill")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(locationColor, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
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
                .foregroundStyle(PulseTheme.primary)
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

    var body: some View {
        PulseCard(contentPadding: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 2) {
                    Text("\(day.exercises.count)")
                        .font(.title3.weight(.black).monospacedDigit())
                        .foregroundStyle(PulseTheme.primary)
                    Text(localizedString("exercises_2"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(width: 56, height: 56)
                .background(PulseTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

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
                                Text(workoutExercise.exercise.name)
                                    .font(.caption2.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(PulseTheme.grouped, in: Capsule())
                            }
                            if day.exercises.count > 3 {
                                Text("+\(day.exercises.count - 3)")
                                    .font(.caption2.weight(.black))
                                    .foregroundStyle(PulseTheme.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(PulseTheme.primary.opacity(0.12), in: Capsule())
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
                            .foregroundStyle(PulseTheme.primary)
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
                                .foregroundStyle(.white)
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
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
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
            .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                    .background(PulseTheme.appleMusic)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
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
                            .foregroundStyle(.white)
                            .background(canAdd ? PulseTheme.primary : PulseTheme.secondaryText.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
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
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.primary.opacity(0.08))
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

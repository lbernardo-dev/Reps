import MuscleMap
import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var showScheduleWorkout = false
    @State private var showCreatePlan = false
    @State private var showProfile = false
    @State private var showFreeWorkoutStart = false
    @State private var planToEdit: WorkoutPlan?
    @State private var workoutToStart: WorkoutDay?
    @State private var showNotifications = false
    @State private var recommendedWorkout: WorkoutDay? = nil
    @Namespace private var wellnessZoom

    var onSelectTab: ((AppTab) -> Void)? = nil

    private var freeWorkout: WorkoutDay {
        WorkoutDay.freeWorkout
    }

    private var todaysScheduledWorkout: ScheduledWorkout? {
        store.scheduledWorkouts.first { Calendar.current.isDateInToday($0.date) && $0.status != .skipped }
    }

    private var focusWorkout: WorkoutDay {
        todaysScheduledWorkout?.workoutDay ?? store.todaysWorkout
    }

    private var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-604_800)
    }

    private var weekSessions: [WorkoutSession] {
        store.workoutSessions.filter { $0.date >= weekStart }
    }

    private var completedThisWeek: Int {
        guard hasActivePlan else {
            return weekSessions.count
        }
        return min(weekSessions.count, store.activePlan.daysPerWeek)
    }

    private var weekTargetText: String {
        guard hasActivePlan else {
            return "\(completedThisWeek)"
        }
        return "\(completedThisWeek)/\(store.activePlan.daysPerWeek)"
    }

    private var streakDays: Int {
        store.streakDays
    }

    private var lastWorkout: WorkoutSession? {
        store.workoutSessions.sorted { $0.date > $1.date }.first
    }

    private var latestMetric: BodyMetric? {
        store.bodyMetrics.sorted { $0.date > $1.date }.first
    }

    private var batteryStatus: FitnessMetrics.TrainingBatteryStatus {
        store.trainingBattery
    }

    private var batteryColor: Color {
        switch batteryStatus.state {
        case .charged:
            return PulseTheme.recovery
        case .steady:
            return PulseTheme.accent
        case .low:
            return PulseTheme.warning
        case .critical:
            return PulseTheme.destructive
        }
    }


    private var nextScheduledWorkout: ScheduledWorkout? {
        store.scheduledWorkouts
            .filter { $0.date >= Calendar.current.startOfDay(for: .now) && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .first
    }

    private var featuredExercises: [Exercise] {
        let withImages = store.exercises.filter { ($0.mediaURL ?? "").isEmpty == false }
        return Array((withImages.isEmpty ? store.exercises : withImages).prefix(8))
    }

    private var focusPreviewExercises: [Exercise] {
        let planned = focusWorkout.exercises.map(\.exercise)
        return Array((planned.isEmpty ? featuredExercises : planned).prefix(3))
    }

    private var focusMediaExercises: [Exercise] {
        focusWorkout.exercises.map { hydratedExercise($0.exercise) }
    }

    private var focusProgressionRecommendations: [SmartProgressionAdvisor.Recommendation] {
        SmartProgressionAdvisor.recommendations(
            for: focusWorkout,
            sessions: store.workoutSessions,
            weightIncrementKg: store.userProfile.weightIncrementKg,
            limit: 3
        )
    }

    private var competitiveSummary: AnalyticsEngine.CompetitiveSummary {
        AnalyticsEngine.competitiveSummary(
            sessions: store.workoutSessions,
            activePlan: store.activePlan,
            exercises: store.exercises,
            since: weekStart
        )
    }

    private var workloadSummary: AnalyticsEngine.WorkloadSummary {
        AnalyticsEngine.workloadSummary(sessions: store.workoutSessions, bodyMetrics: store.bodyMetrics)
    }

    private var dailyCoachRecommendation: FitnessMetrics.DailyCoachRecommendation {
        FitnessMetrics.dailyCoachRecommendation(
            battery: batteryStatus,
            competitiveSummary: competitiveSummary,
            hasActivePlan: hasActivePlan,
            hasTodayWorkout: todaysScheduledWorkout != nil,
            hasCompletedWorkout: !store.workoutSessions.isEmpty
        )
    }


    private var hasActivePlan: Bool {
        !store.activePlan.days.isEmpty
    }

    private var currentDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = localizedString("eeee_d_mmmm")
        return formatter.string(from: .now).capitalized(with: formatter.locale)
    }

    private var last30StartDate: Date {
        let today = Calendar.current.startOfDay(for: .now)
        return Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
    }

    private var recentSessions: [WorkoutSession] {
        store.workoutSessions.filter { $0.date >= last30StartDate }
    }

    private var previous30Sessions: [WorkoutSession] {
        let calendar = Calendar.current
        guard let previousStart = calendar.date(byAdding: .day, value: -30, to: last30StartDate) else {
            return []
        }
        return store.workoutSessions.filter { $0.date >= previousStart && $0.date < last30StartDate }
    }

    private var recentCompletedSets: [SetLog] {
        completedSets(in: recentSessions)
    }

    private var weekCompletedSets: [SetLog] {
        completedSets(in: weekSessions)
    }

    private var recentVolumeKg: Double {
        FitnessMetrics.totalVolumeKg(for: recentSessions)
    }

    private var previous30VolumeKg: Double {
        FitnessMetrics.totalVolumeKg(for: previous30Sessions)
    }

    private var displayedRecentVolume: Double {
        displayedWeight(fromKilograms: recentVolumeKg)
    }

    private var displayedVolumeUnit: String {
        store.userProfile.units == .metric ? "kg" : "lb"
    }

    private var recentActivityPoints: [DailyActivityPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let loadByDay = Dictionary(grouping: recentSessions, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { sessions in
                sessions.reduce(0.0) { $0 + AnalyticsEngine.sessionLoad(for: $1) }
            }
        let maxDailyLoad = loadByDay.values.max() ?? 0

        return (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 29, to: today) else {
                return nil
            }
            let dailyLoad = loadByDay[date] ?? 0
            return DailyActivityPoint(
                date: date,
                isCompleted: dailyLoad > 0,
                isToday: calendar.isDateInToday(date),
                intensity: maxDailyLoad > 0 ? min(dailyLoad / maxDailyLoad, 1) : 0
            )
        }
    }

    private var weeklyRepsPoints: [MiniBarPoint] {
        weeklyPoints { session in
            Double(completedSets(in: [session]).reduce(0) { $0 + $1.reps })
        }
    }

    private var weeklyVolumePoints: [MiniBarPoint] {
        weeklyPoints { session in
            displayedWeight(fromKilograms: FitnessMetrics.totalVolumeKg(for: [session]))
        }
    }

    private var weeklyVolumeValues: [Double] {
        weeklyVolumePoints.map(\.value)
    }

    private var workoutTrendText: String? {
        trendText(current: Double(recentSessions.count), previous: Double(previous30Sessions.count))
    }

    private var volumeTrendText: String? {
        trendText(current: recentVolumeKg, previous: previous30VolumeKg)
    }

    private var weekRepsTrendText: String? {
        let calendar = Calendar.current
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previousWeekSessions = store.workoutSessions.filter { $0.date >= previousWeekStart && $0.date < weekStart }
        let previousReps = completedSets(in: previousWeekSessions).reduce(0) { $0 + $1.reps }
        return trendText(current: Double(weekCompletedSets.reduce(0) { $0 + $1.reps }), previous: Double(previousReps))
    }

    var body: some View {
        NavigationStack {
            StickyHeaderScaffold(
                title: "workout",
                subtitle: currentDateTitle,
                topContentPadding: 104,
                accessory: {
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
            ) {
                if let activeStatus = store.activeWorkoutStatus {
                    activeSessionHero(activeStatus)
                        .stickyHeaderTitle(localizedString("in_progress_label"))
                } else {
                    focusHeroSection
                        .stickyHeaderTitle(localizedString("today_3"))
                    if let rec = recommendedWorkout {
                        RecommendedWorkoutCard(
                            workout: rec,
                            batteryLevel: batteryStatus.level,
                            language: store.userProfile.preferredLanguage,
                            onStart: {
                                HapticService.impact(.medium)
                                workoutToStart = rec
                            }
                        )
                        .stickyHeaderTitle(localizedString("recommended_workout_title"))
                    }
                }
                if !focusProgressionRecommendations.isEmpty {
                    ProgressionRecommendationCard(
                        recommendations: focusProgressionRecommendations,
                        language: store.userProfile.preferredLanguage,
                        title: "what_to_progress_today"
                    )
                    .stickyHeaderTitle(localizedString("progression"))
                }
                relationshipSignalBoard
                    .stickyHeaderTitle("Señales")
                wellnessWidgets
                    .stickyHeaderTitle(localizedString("recovery_2"))
                if hasActivePlan {
                    planSection
                        .stickyHeaderTitle(localizedString("plan_3"))
                }
                smartShortcuts
                    .stickyHeaderTitle(localizedString("shortcuts"))
            }
            .sheet(isPresented: $showScheduleWorkout) {
                ScheduleWorkoutView()
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(item: $planToEdit) { plan in
                EditPlanView(plan: plan)
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView {
                    onSelectTab?(.today)
                }
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
            .navigationDestination(item: $workoutToStart) { workout in
                ActiveWorkoutView(workout: workout, origin: workout.id == freeWorkout.id ? .free : .routine)
            }
            .navigationDestination(isPresented: $showFreeWorkoutStart) {
                FreeWorkoutStartView()
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { buildRecommendedWorkoutIfNeeded() }
        }
    }

    private func buildRecommendedWorkoutIfNeeded() {
        guard recommendedWorkout == nil, store.activeWorkoutStatus == nil else { return }
        let undertrainedMuscles = competitiveSummary.undertrainedMuscles.map(\.muscleGroup)
        let bodyMetric = store.bodyMetrics.sorted { $0.date > $1.date }.first ?? BodyMetric(date: .now, weightKg: 70, heightCm: 170, source: .manual)
        recommendedWorkout = OnboardingPlanBuilder.makeRecommendedDay(
            profile: store.userProfile,
            bodyMetric: bodyMetric,
            batteryLevel: batteryStatus.level,
            undertrainedMuscles: undertrainedMuscles
        )
    }

    @ViewBuilder
    private var focusHeroSection: some View {
        if let activeStatus = store.activeWorkoutStatus {
            activeSessionHero(activeStatus)
        } else {
            dashboardWorkoutCard
        }
    }

    private var relationshipSignalBoard: some View {
        DomainHeroCard(domain: .strength, minHeight: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MetricDomain.strength.tint)
                    Text("Señales de hoy")
                        .font(.headline.weight(.black))
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    TrainingSignalTile(
                        title: localizedString("plan"),
                        value: weekTargetText,
                        subtitle: "objetivo semanal",
                        systemImage: "target",
                        color: PulseTheme.accent,
                        domain: .strength
                    )
                    TrainingSignalTile(
                        title: localizedString("load"),
                        value: "\(Int(workloadSummary.fatigueScore.rounded()))",
                        subtitle: "fatiga",
                        systemImage: "waveform.path.ecg",
                        color: batteryColor,
                        domain: .recovery
                    )
                    TrainingSignalTile(
                        title: localizedString("health"),
                        value: store.todayHealthMetric.map { "\(Int($0.steps))" } ?? "--",
                        subtitle: localizedString("steps_today"),
                        systemImage: "figure.walk",
                        color: PulseTheme.ringStand,
                        domain: .activity
                    )
                    TrainingSignalTile(
                        title: localizedString("progress_2"),
                        value: "\(recentSessions.count)",
                        subtitle: "30 días",
                        systemImage: "chart.line.uptrend.xyaxis",
                        color: PulseTheme.ringMove,
                        domain: .cardio
                    )
                }
            }
            .padding(18)
        }
    }

    private var dashboardWorkoutCard: some View {
        let hasActivePlanSession = todaysScheduledWorkout != nil || hasActivePlan
        let titleText = hasActivePlanSession
            ? RepsText.workoutTitle(focusWorkout.title, language: store.userProfile.preferredLanguage)
            : (localizedString("choose_next_move"))
        let subtitleText = hasActivePlanSession
            ? RepsText.localizedWorkoutSubtitle(focusWorkout.subtitle, language: store.userProfile.preferredLanguage)
            : (localizedString("free_workout_routine_or_scheduled_session"))
        let playButtonTitle = hasActivePlanSession
            ? (localizedString("start_workout_2"))
            : (localizedString("free_workout"))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    PulseStatusPill(title: "today_2", systemImage: "bolt.fill", tint: PulseTheme.accent, isFilled: true)

                    if !focusWorkout.exercises.isEmpty {
                        WorkoutExerciseAvatarStrip(
                            exercises: focusMediaExercises,
                            gender: store.userProfile.muscleMapGender,
                            tint: PulseTheme.accent,
                            catalog: store.exercises
                        )
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Text(titleText)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        if !store.activePlan.days.isEmpty {
                            focusWorkoutMenu
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(subtitleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hasActivePlan {
                    Button {
                        HapticService.selection()
                        planToEdit = store.activePlan
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .frame(width: 38, height: 38)
                            .background(PulseTheme.fitActionGradient)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localizedString("edit_plan"))
                }
            }

            HStack(spacing: 8) {
                SummaryChip(title: "~\(focusWorkout.durationMinutes) min", systemImage: "clock", color: PulseTheme.accent)
                let exercisesWord = localizedString("exercises_2")
                SummaryChip(title: "\(focusWorkout.exercises.count) \(exercisesWord)", systemImage: "dumbbell.fill", color: PulseTheme.accent)
                SummaryChip(title: locationLabel, systemImage: "mappin.and.ellipse", color: PulseTheme.ringStand)
            }

            Button {
                perform(dailyCoachRecommendation.action)
            } label: {
                TodayCoachSummaryRow(
                    recommendation: dailyCoachRecommendation,
                    weekTargetText: weekTargetText,
                    batteryLevel: batteryStatus.level,
                    color: color(for: dailyCoachRecommendation.tone)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    perform(dailyCoachRecommendation.action)
                } label: {
                    Label(dailyCoachRecommendation.actionTitle, systemImage: "arrow.up.right.circle.fill")
                        .font(.headline.weight(.black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(PulseTheme.onColor(color(for: dailyCoachRecommendation.tone)))
                        .background(color(for: dailyCoachRecommendation.tone), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                NavigationLink {
                    if hasActivePlanSession {
                        ActiveWorkoutView(workout: focusWorkout)
                    } else {
                        FreeWorkoutStartView()
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.black))
                        .frame(width: 54, height: 54)
                        .foregroundStyle(PulseTheme.onColor(MetricDomain.strength.tint))
                        .background(MetricDomain.strength.tint, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playButtonTitle)
            }
        }
        .padding(18)
        .background {
            let shape = RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
            ZStack {
                shape
                    .fill(PulseTheme.card)
                shape
                    .fill(MetricDomain.strength.backgroundGradient.opacity(0.34))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(MetricDomain.strength.tint.opacity(0.22), lineWidth: 0.8)
        )
        .shadow(color: PulseTheme.surfaceShadow, radius: 7, x: 0, y: 3)
    }

    private var focusWorkoutMenu: some View {
        Menu {
            Section(header: Text(localizedString("change_day"))) {
                ForEach(store.activePlan.days) { day in
                    Button {
                        store.selectWorkoutDayForToday(day)
                    } label: {
                        HStack {
                            Text(RepsText.workoutTitle(day.title, language: store.userProfile.preferredLanguage))
                            if day.id == focusWorkout.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section(header: Text(localizedString("change_plan"))) {
                ForEach(store.plans) { plan in
                    Button {
                        store.activatePlan(plan)
                    } label: {
                        HStack {
                            Text(plan.name)
                            if plan.id == store.activePlan.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if let suggestedDay = store.activePlan.normalizedActiveDay {
                if focusWorkout.id != suggestedDay.id {
                    Divider()
                    Button(role: .destructive) {
                        store.restoreSuggestedWorkoutForToday()
                    } label: {
                        Text(localizedString("restore_suggested"))
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(PulseTheme.fitActionGradient)
        }
        .buttonStyle(.plain)
    }

    // MARK: – Active session hero (replaces the old separate banner)
    private func activeSessionHero(_ status: ActiveWorkoutStatus) -> some View {
        let isPaused = status.isPaused
        let setsWord = localizedString("sets_3")
        let progress: Double = status.totalSets > 0 ? Double(status.completedSets) / Double(status.totalSets) : 0
        
        let progressColor: Color = {
            let percent = progress * 100
            if percent >= 70 {
                return PulseTheme.growth
            } else if percent >= 50 {
                return PulseTheme.semanticAction
            } else if percent >= 30 {
                return PulseTheme.warning
            } else {
                return PulseTheme.destructive
            }
        }()

        return VStack(alignment: .leading, spacing: 16) {

            // ── Header row ────────────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(PulseTheme.separator, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Image(systemName: isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(progressColor)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString(isPaused ? "PAUSED" : "IN PROGRESS"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(Color.orange)
                    Text(RepsText.workoutTitle(status.workoutTitle, language: store.userProfile.preferredLanguage))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(PulseTheme.textPrimary)
                }
                Spacer()
            }

            // ── Plan & Session info ───────────────────────────────────
            if let planTitle = status.planTitle {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                    Text("\(planTitle)\(status.sessionTitle.map { " · \($0)" } ?? "")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .padding(.top, -4)
            } else if let sessionTitle = status.sessionTitle {
                HStack(spacing: 6) {
                    Image(systemName: "list.clipboard.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                    Text(sessionTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .padding(.top, -4)
            }

            // ── Current Exercise & Target Info ────────────────────────
            if let exerciseName = status.exerciseName {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                        Text(localizedString("current_exercise_label"))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                    }
                    
                    Text(exerciseName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.textPrimary)
                    
                    HStack(spacing: 12) {
                        if let completed = status.currentExerciseCompletedSets,
                           let total = status.currentExerciseTotalSets {
                            Label("\(completed)/\(total) series", systemImage: "checklist")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        
                        if let weight = status.currentSetWeightKg,
                           let reps = status.currentSetReps {
                            Label("\(weight.formatted()) kg x \(reps) reps", systemImage: "target")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            // ── Next Exercise & Water Info ────────────────────────────
            HStack(spacing: 16) {
                if let next = status.nextExerciseName, !next.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedString("next_exercise_label"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                        Text(next)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(PulseTheme.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let water = status.waterLiters {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(localizedString("water_label"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                        Label(String(format: "%.2f L", water), systemImage: "drop.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.blue)
                    }
                }
            }
            .padding(.top, 4)

            // ── Timers row ─────────────────────────────────────────────
            HStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    HStack(spacing: 0) {
                        StatPill(
                            value: timeString(status.effectiveElapsedSeconds(at: timeline.date)),
                            label: "Total",
                            systemImage: "timer"
                        )
                        Spacer()
                        Divider().frame(height: 24).opacity(0.3)
                        Spacer()
                        
                        let restVal = (status.restSeconds ?? 0) > 0 ? timeString(status.restSeconds ?? 0) : "--:--"
                        StatPill(
                            value: restVal,
                            label: "Descanso",
                            systemImage: "hourglass"
                        )
                        Spacer()
                        Divider().frame(height: 24).opacity(0.3)
                        Spacer()
                        
                        StatPill(
                            value: timeString(status.effectivePausedSeconds(at: timeline.date)),
                            label: "Pausa",
                            systemImage: "pause.circle"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.primary)

            // ── Metrics row ───────────────────────────────────────────
            HStack(spacing: 0) {
                StatPill(
                    value: "\(status.completedSets)/\(status.totalSets)",
                    label: setsWord,
                    systemImage: "checkmark.circle"
                )
                Spacer()
                Divider().frame(height: 24).opacity(0.3)
                Spacer()
                StatPill(
                    value: "\(status.volumeKg) kg",
                    label: localizedString("volume_2"),
                    systemImage: "scalemass"
                )
            }
            .foregroundStyle(.primary)
            .padding(.top, 4)

            // ── Compact progress bar ──────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulseTheme.grouped).frame(height: 6)
                    Capsule().fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)

            // ── Action buttons ────────────────────────────────────────
            HStack(spacing: 10) {
                // Return to workout
                NavigationLink {
                    ActiveWorkoutView(workout: store.activeWorkout ?? focusWorkout)
                } label: {
                    Label(localizedString("return"), systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.white)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                // Pause / Resume
                Button {
                    store.setActiveWorkoutPaused(!isPaused)
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(isPaused ? PulseTheme.warning : Color.orange)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(PulseTheme.separator, lineWidth: 1)
                        )
                }
                .accessibilityLabel(isPaused ? "Resume workout" : "Pause workout")

                // Stop
                Button {
                    store.finishActiveWorkoutFromSummaryCard()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.destructive))
                        .background(PulseTheme.destructive)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .accessibilityLabel("stop_workout")
            }
        }
        .padding(18)
        .foregroundStyle(.primary)
        .background(
            ZStack {
                Color.orange.opacity(0.08)
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.18),
                        Color.orange.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: PulseTheme.surfaceShadow, radius: 8, x: 0, y: 3)
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func hydratedExercise(_ exercise: Exercise) -> Exercise {
        if exercise.customImageData != nil || (exercise.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) {
            return exercise
        }

        return store.exercises.first { candidate in
            candidate.id == exercise.id
                || (candidate.sourceID != nil && candidate.sourceID == exercise.sourceID)
                || normalizedExerciseName(candidate.name) == normalizedExerciseName(exercise.name)
                || candidate.aliases.contains { normalizedExerciseName($0) == normalizedExerciseName(exercise.name) }
        } ?? exercise
    }

    private func normalizedExerciseName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private var weightGoalText: String? {
        latestMetric.map { relativeDateTitle(for: $0.date) }
    }

    private func completedSets(in sessions: [WorkoutSession]) -> [SetLog] {
        sessions.flatMap { session in
            if let exerciseLogs = session.exerciseLogs, !exerciseLogs.isEmpty {
                return exerciseLogs.flatMap { $0.sets.filter(\.completed) }
            }
            return session.sets.filter(\.completed)
        }
    }

    private func displayedWeight(fromKilograms kilograms: Double) -> Double {
        switch store.userProfile.units {
        case .metric:
            return kilograms
        case .imperial:
            return UnitConverter.pounds(fromKilograms: kilograms)
        }
    }

    private func compactNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private func trendText(current: Double, previous: Double) -> String? {
        guard previous > 0 else {
            return current > 0 ? "+100%" : nil
        }

        let percentage = ((current - previous) / previous) * 100
        guard abs(percentage) >= 1 else {
            return nil
        }
        return String(format: "%+.0f%%", percentage)
    }

    private func weeklyPoints(_ valueForSession: (WorkoutSession) -> Double) -> [MiniBarPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = "EEEEE"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let daySessions = weekSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return MiniBarPoint(
                id: date,
                label: formatter.string(from: date).uppercased(),
                value: daySessions.reduce(0) { $0 + valueForSession($1) },
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    private func perform(_ action: RetentionEngine.ActivationAction?) {
        HapticService.impact(.light)
        guard let action else {
            showProfile = true
            return
        }

        switch action {
        case .startWorkout:
            if todaysScheduledWorkout != nil || hasActivePlan {
                workoutToStart = focusWorkout
            } else {
                showFreeWorkoutStart = true
            }
        case .createPlan:
            showCreatePlan = true
        case .scheduleWorkout:
            showScheduleWorkout = true
        case .competitive(let competitiveAction):
            if competitiveAction == .reviewPlan {
                reviewActivePlan()
                return
            }
            if let destination = store.executeCompetitiveAction(competitiveAction) {
                onSelectTab?(destination)
            }
        case .openProgress:
            onSelectTab?(.progress)
        }
    }

    private func perform(_ action: FitnessMetrics.DailyCoachRecommendation.Action) {
        HapticService.impact(.light)
        switch action {
        case .startWorkout:
            if todaysScheduledWorkout != nil || hasActivePlan {
                workoutToStart = focusWorkout
            } else {
                showFreeWorkoutStart = true
            }
        case .createPlan:
            showCreatePlan = true
        case .scheduleWorkout:
            showScheduleWorkout = true
        case .openProgress:
            onSelectTab?(.progress)
        case .competitive(let competitiveAction):
            if competitiveAction == .reviewPlan {
                reviewActivePlan()
                return
            }
            if let destination = store.executeCompetitiveAction(competitiveAction) {
                onSelectTab?(destination)
            }
        }
    }

    private func reviewActivePlan() {
        if hasActivePlan {
            planToEdit = store.activePlan
        } else {
            showCreatePlan = true
        }
    }

    private func color(for tone: FitnessMetrics.DailyCoachRecommendation.Tone) -> Color {
        switch tone {
        case .primary:
            return MetricDomain.strength.tint
        case .recovery:
            return PulseTheme.recovery
        case .warning:
            return PulseTheme.warning
        case .accent:
            return MetricDomain.strength.tint
        }
    }

    private var weeklyCommandGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HomeMetricTile(title: "Week", value: weekTargetText, subtitle: "sessions_2", systemImage: "calendar", color: PulseTheme.accent)
            HomeMetricTile(title: "Volume", value: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: "kg_this_week", systemImage: "scalemass", color: PulseTheme.ringStand)
            HomeMetricTile(title: "Streak", value: "\(streakDays)", subtitle: "days_in_a_row", systemImage: "flame", color: PulseTheme.accent)
        }
    }

    private var wellnessWidgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("wellness"))
                .font(.headline)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                NavigationLink {
                    TrainingBatteryView()
                        .navigationTransition(.zoom(sourceID: "wellness-battery", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "battery_2",
                        value: "\(batteryStatus.level)%",
                        subtitle: batteryStatus.suggestion,
                        localizesSubtitle: false,
                        systemImage: batteryStatus.systemImage,
                        domain: .recovery
                    )
                    .matchedTransitionSource(id: "wellness-battery", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    ExerciseView()
                        .navigationTransition(.zoom(sourceID: "wellness-exercise", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "exercise_2",
                        value: store.todayHealthMetric.map { "\(Int($0.exerciseMinutes ?? 0)) min" } ?? "--",
                        subtitle: "apple_watch_health",
                        systemImage: "applewatch",
                        domain: .strength
                    )
                    .matchedTransitionSource(id: "wellness-exercise", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    HydrationView()
                        .navigationTransition(.zoom(sourceID: "wellness-hydration", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "hydration",
                        value: store.todayHealthMetric.map { String(format: "%.1f L", $0.waterLiters) } ?? "--",
                        subtitle: latestMetric?.waterLiters.map { String(format: "%.1f L en Reps", $0) } ?? (localizedString("no_local_log")),
                        localizesSubtitle: latestMetric?.waterLiters == nil,
                        systemImage: "drop.fill",
                        domain: .nutrition
                    )
                    .matchedTransitionSource(id: "wellness-hydration", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    HeartRateView()
                        .navigationTransition(.zoom(sourceID: "wellness-heart-rate", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "heart_rate_short",
                        value: store.todayHealthMetric?.restingHeartRate.map { "\(Int($0))" } ?? "--",
                        subtitle: "lpm",
                        localizesSubtitle: false,
                        systemImage: "heart.fill",
                        domain: .heartRate
                    )
                    .matchedTransitionSource(id: "wellness-heart-rate", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    HRVView()
                        .navigationTransition(.zoom(sourceID: "wellness-hrv", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "HRV",
                        value: store.todayHealthMetric?.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--",
                        subtitle: store.todayHealthMetric?.restingHeartRate.map { "\(Int($0)) lpm reposo" } ?? (localizedString("no_resting_hr")),
                        localizesSubtitle: store.todayHealthMetric?.restingHeartRate == nil,
                        systemImage: "waveform.path.ecg",
                        domain: .recovery
                    )
                    .matchedTransitionSource(id: "wellness-hrv", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    VO2MaxView()
                        .navigationTransition(.zoom(sourceID: "wellness-vo2", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "VO₂ Max",
                        value: store.health.latestDailyMetrics.sorted { $0.date > $1.date }.first(where: { $0.vo2MaxMlKgMin != nil })?.vo2MaxMlKgMin.map { String(format: "%.1f", $0) } ?? "--",
                        subtitle: "ml/kg/min",
                        localizesSubtitle: false,
                        systemImage: "lungs.fill",
                        domain: .cardio
                    )
                    .matchedTransitionSource(id: "wellness-vo2", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    SleepView()
                        .navigationTransition(.zoom(sourceID: "wellness-sleep", in: wellnessZoom))
                } label: {
                    let todaySleep = store.health.latestDailyMetrics
                        .sorted { $0.date > $1.date }
                        .first(where: { ($0.sleepHours ?? 0) > 0 })?.sleepHours
                    WellnessWidget(
                        title: "sleep",
                        value: todaySleep.map { String(format: "%.1fh", $0) } ?? "--",
                        subtitle: localizedString("last_recorded"),
                        systemImage: "moon.zzz.fill",
                        domain: .sleep
                    )
                    .matchedTransitionSource(id: "wellness-sleep", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink {
                    StepsView()
                        .navigationTransition(.zoom(sourceID: "wellness-steps", in: wellnessZoom))
                } label: {
                    WellnessWidget(
                        title: "steps",
                        value: store.todayHealthMetric.map { "\(Int($0.steps))" } ?? "--",
                        subtitle: localizedFormat("goal_format", store.userProfile.dailyStepsGoal),
                        systemImage: "figure.walk",
                        domain: .activity
                    )
                    .matchedTransitionSource(id: "wellness-steps", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())
            }
            .scrollTargetLayout()
            .padding(.vertical, 2)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var planSection: some View {
        planPreview
    }

    private var planPreview: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(store.activePlan.name, systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.accent)
                    Spacer()
                    Text("\(Int(store.activePlan.completion * 100))%")
                        .font(.title2.bold().monospacedDigit())
                }

                ProgressView(value: store.activePlan.completion)
                    .tint(PulseTheme.accent)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)

                if let eventName = store.activePlan.targetEventName,
                   let eventDate = store.activePlan.targetEventDate {
                    let calendar = Calendar.current
                    let start = calendar.startOfDay(for: .now)
                    let end = calendar.startOfDay(for: eventDate)
                    let daysDiff = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                    let weeks = max(0, daysDiff / 7)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(PulseTheme.accent)
                            Text(localizedFormat("target_event_format", eventName))
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if daysDiff > 0 {
                                Text(localizedFormat("days_left_weeks_format", daysDiff, weeks))
                                    .font(.caption.bold())
                                    .foregroundStyle(PulseTheme.ringStand)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PulseTheme.ringStand.opacity(0.12))
                                    .clipShape(Capsule())
                            } else if daysDiff == 0 {
                                Text(localizedString("today_is_the_day"))
                                    .font(.caption.bold())
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PulseTheme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            } else {
                                Text(localizedString("completed_3"))
                                    .font(.caption.bold())
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        let adviceText: String = {
                            if daysDiff < 0 {
                                return localizedString("the_event_day_has_arrived_we_hope_you_achieved_your_goals")
                            } else if weeks < 6 {
                                return localizedString("short_target_we_suggest_maximizing_intensity_now_and_avoiding_excessive_fatigue")
                            } else if weeks <= 12 {
                                return localizedString("optimal_timeline_you_have_the_perfect_amount_of_time_to_complete_a_full_training")
                            } else {
                                return localizedString("long_timeline_we_suggest_completing_an_8_12_week_strength_hypertrophy_block_foll")
                            }
                        }()
                        
                        Text(adviceText)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, 4)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.activePlan.days) { day in
                            NavigationLink {
                                WorkoutDetailView(workout: day)
                            } label: {
                                PlanMicroCard(
                                    day: day,
                                    language: store.userProfile.preferredLanguage,
                                    gender: store.userProfile.muscleMapGender,
                                    catalog: store.exercises
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var smartShortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("smart_shortcuts"))
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    ShortcutTile(
                        title: "library",
                        subtitle: LocalizedStringKey(localizedFormat("exercises_count_format", store.exercises.count)),
                        systemImage: "photo.stack",
                        color: PulseTheme.accent
                    )
                }
                .buttonStyle(.plain)

                Button {
                    HapticService.selection()
                    if let onSelectTab {
                        onSelectTab(.progress)
                    }
                } label: {
                    ShortcutTile(
                        title: "progress_2",
                        subtitle: "charts_and_insights",
                        systemImage: "chart.line.uptrend.xyaxis",
                        color: PulseTheme.ringStand
                    )
                }
                .buttonStyle(.plain)

                Button {
                    HapticService.selection()
                    showCreatePlan = true
                } label: {
                    ShortcutTile(
                        title: "new_plan",
                        subtitle: "editable_routine",
                        systemImage: "square.stack.3d.up",
                        color: PulseTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutLibraryView()
                } label: {
                    ShortcutTile(
                        title: "routines",
                        subtitle: LocalizedStringKey(localizedFormat("templates_count_format", store.workoutTemplates.count)),
                        systemImage: "list.clipboard",
                        color: PulseTheme.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var locationLabel: String {
        guard hasActivePlan else {
            return localizedString("free_2")
        }

        return switch store.activePlan.location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("mixed")
        }
    }

    private var lastWorkoutSubtitle: String {
        guard let lastWorkout else {
            return localizedString("complete_your_first_session")
        }
        return "\(relativeDateTitle(for: lastWorkout.date)) · \(lastWorkout.durationMinutes) min"
    }

    private func relativeDateTitle(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .full
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return localizedString("today_4")
        }
        if calendar.isDateInYesterday(date) {
            return localizedString("yesterday_2")
        }
        
        let startToday = calendar.startOfDay(for: .now)
        let startDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startDate, to: startToday)
        if let days = components.day, days > 0 {
            return formatter.localizedString(from: components)
        }
        
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// Compact stat display used inside the active-session hero card.
private struct StatPill: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.75)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
            }
            Text(localizedKey(label))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TodayCoachSummaryRow: View {
    let recommendation: FitnessMetrics.DailyCoachRecommendation
    let weekTargetText: String
    let batteryLevel: Int
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: recommendation.systemImage)
                .font(.headline.weight(.black))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("next_best_action"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .textCase(.uppercase)
                    .foregroundStyle(color)
                Text(recommendation.title)
                    .font(.subheadline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(recommendation.message)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(PulseTheme.grouped.opacity(0.82), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ReadinessBadge: View {
    let level: Int
    let title: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseTheme.grouped, lineWidth: 4.5)
            Circle()
                .trim(from: 0, to: CGFloat(level) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(level)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(color)
                Text(localizedKey(title))
                    .font(.system(size: 8, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(width: 58, height: 58)
        .padding(6)
        .background(PulseTheme.card)
        .clipShape(Circle())
        .shadow(color: PulseTheme.surfaceShadow, radius: 6, x: 0, y: 3)
        .accessibilityLabel("\(title) \(level)%")
    }
}

private struct WorkoutImageStack: View {
    let exercises: [Exercise]
    let gender: BodyGender
    let fallbackSystemImage: String
    var catalog: [Exercise] = []

    var body: some View {
        ZStack {
            if exercises.isEmpty {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(PulseTheme.textSecondary)
                    .frame(width: 74, height: 74)
                    .background(PulseTheme.grouped)
                    .clipShape(Circle())
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PulseTheme.cardStroke, lineWidth: 1.8))
                        .shadow(color: PulseTheme.surfaceShadow, radius: 5, x: 0, y: 3)
                        .offset(x: CGFloat(index) * -16, y: CGFloat(index) * 8)
                }
            }
        }
        .frame(width: 84, height: 78)
        .accessibilityHidden(true)
    }
}

private struct WorkoutExerciseAvatarStrip: View {
    let exercises: [Exercise]
    let gender: BodyGender
    let tint: Color
    let catalog: [Exercise]

    private let maxDiameter: CGFloat = 58
    private let minDiameter: CGFloat = 46
    private let overlap: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let step = maxDiameter - overlap
            let fullWidth = maxDiameter + CGFloat(max(exercises.count - 1, 0)) * step
            let diameter = fullWidth <= availableWidth
                ? maxDiameter
                : max(minDiameter, min(maxDiameter, availableWidth / 4.6))
            let compactStep = diameter - overlap
            let maxVisible = max(1, Int(floor((availableWidth - diameter) / compactStep)) + 1)
            let needsCounter = exercises.count > maxVisible
            let visibleCount = needsCounter ? max(1, maxVisible - 1) : min(exercises.count, maxVisible)
            let hiddenCount = max(0, exercises.count - visibleCount)

            ZStack(alignment: .leading) {
                ForEach(Array(exercises.prefix(visibleCount).enumerated()), id: \.element.id) { index, exercise in
                    ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(PulseTheme.cardStroke, lineWidth: 2))
                        .shadow(color: PulseTheme.surfaceShadow, radius: 6, x: 0, y: 3)
                        .offset(x: CGFloat(index) * compactStep)
                }

                if needsCounter {
                    Text("+\(hiddenCount)")
                        .font(.system(size: max(11, diameter * 0.34), weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .frame(width: diameter, height: diameter)
                        .background(tint.opacity(0.16))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(tint.opacity(0.45), lineWidth: 1.5))
                        .offset(x: CGFloat(visibleCount) * compactStep)
                }
            }
            .frame(width: availableWidth, height: diameter, alignment: .leading)
        }
        .frame(height: maxDiameter)
        .accessibilityLabel("plan_exercises")
    }
}


private struct DailyActivityPoint: Identifiable {
    let date: Date
    let isCompleted: Bool
    let isToday: Bool
    let intensity: Double

    var id: Date { date }
}

private struct MiniBarPoint: Identifiable {
    let id: Date
    let label: String
    let value: Double
    let isToday: Bool
}

private struct SummaryChip: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(localizedKey(title), systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.10), lineWidth: 0.8)
            }
    }
}

private struct SummaryMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let trendText: String?
    let color: Color
    var onTap: (() -> Void)? = nil

    private var trendColor: Color {
        guard let trendText else { return PulseTheme.secondaryText }
        return trendText.hasPrefix("-") ? PulseTheme.destructive : PulseTheme.recovery
    }

    var body: some View {
        if let onTap {
            Button {
                HapticService.selection()
                onTap()
            } label: { card }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        PulseCard(minHeight: 112, contentPadding: 12, backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(color)
                    Spacer(minLength: 0)
                    if let trendText {
                        Text(trendText)
                            .font(.caption2.weight(.black).monospacedDigit())
                            .foregroundStyle(trendColor)
                    }
                }

                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(localizedKey(subtitle))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)

                Text(localizedKey(title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct TrainingSignalTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var domain: MetricDomain? = nil

    private var tileTint: Color { domain?.tint ?? color }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PulseIconBadge(systemImage: systemImage, tint: tileTint, size: 34, radius: PulseTheme.smallRadius)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.3)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .frame(minHeight: 82)
        .background {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .fill(tileTint.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .stroke(tileTint.opacity(0.18), lineWidth: 0.8)
                )
        }
    }
}

private struct ActivityMatrixCard: View {
    let title: String
    let progressText: String
    let points: [DailyActivityPoint]
    let color: Color
    var onTapDay: ((Date) -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    private func fill(for point: DailyActivityPoint) -> LinearGradient {
        guard point.isCompleted else {
            return LinearGradient(
                colors: [
                    PulseTheme.grouped.opacity(0.82),
                    PulseTheme.grouped.opacity(0.96)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        let intensity = max(0.18, min(point.intensity, 1))
        return LinearGradient(
            colors: [
                color.opacity(0.42 + (0.38 * intensity)),
                PulseTheme.ringStand.opacity(0.58 + (0.30 * intensity)),
                PulseTheme.accent.opacity(0.28 + (0.50 * intensity))
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func accessibilityLabel(for point: DailyActivityPoint) -> String {
        guard point.isCompleted else {
            return "No workout"
        }

        return "Workout completed, intensity \(Int((point.intensity * 100).rounded())) percent"
    }

    var body: some View {
        PulseCard(contentPadding: 16, backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(localizedKey(title))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulseTheme.textPrimary)
                    Spacer()
                    Text(progressText)
                        .font(.caption.weight(.black).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(points) { point in
                        Button {
                            HapticService.selection()
                            onTapDay?(point.date)
                        } label: {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(fill(for: point))
                                .frame(height: 17)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(point.isToday ? PulseTheme.accent : PulseTheme.separator, style: StrokeStyle(lineWidth: point.isToday ? 2 : 1, dash: point.isCompleted ? [] : [4, 3]))
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(onTapDay == nil)
                        .accessibilityLabel(accessibilityLabel(for: point))
                        .accessibilityHint(localizedString("view_day_in_calendar"))
                    }
                }
            }
        }
    }
}

private struct MiniTrendCard<Chart: View>: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String
    let systemImage: String
    let trendText: String?
    let color: Color
    let chart: Chart

    init(
        title: String,
        subtitle: String,
        value: String,
        unit: String,
        systemImage: String,
        trendText: String?,
        color: Color,
        @ViewBuilder chart: () -> Chart
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.unit = unit
        self.systemImage = systemImage
        self.trendText = trendText
        self.color = color
        self.chart = chart()
    }

    private var trendColor: Color {
        guard let trendText else { return PulseTheme.secondaryText }
        return trendText.hasPrefix("-") ? PulseTheme.destructive : PulseTheme.recovery
    }

    var body: some View {
        PulseCard(contentPadding: 14, backgroundColor: PulseTheme.card) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizedKey(title))
                            .font(.caption.weight(.black))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(localizedKey(subtitle))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                    Spacer(minLength: 0)
                    if let trendText {
                        Text(trendText)
                            .font(.caption2.weight(.black).monospacedDigit())
                            .foregroundStyle(trendColor)
                    }
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 31, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text(unit)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 8)

                chart
                    .frame(height: 42, alignment: .bottom)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 130, alignment: .top)
        }
    }
}

private struct MiniAreaChart: View {
    let values: [Double]
    let color: Color

    var body: some View {
        ZStack(alignment: .bottom) {
            SparklineAreaShape(values: values)
                .fill(color.opacity(0.16))
            SparklineShape(values: values)
                .stroke(color.opacity(0.72), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let stepX = rect.width / CGFloat(values.count - 1)

        var path = Path()
        for index in values.indices {
            let x = CGFloat(index) * stepX
            let normalized = (values[index] - minValue) / range
            let y = rect.maxY - CGFloat(normalized) * rect.height
            let point = CGPoint(x: x, y: y)
            index == values.startIndex ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

private struct SparklineAreaShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        var path = SparklineShape(values: values).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct MiniBarChart: View {
    let points: [MiniBarPoint]
    let color: Color

    private var maxValue: Double {
        max(points.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(points) { point in
                VStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(point.value > 0 ? color.opacity(point.isToday ? 0.95 : 0.52) : PulseTheme.grouped)
                        .frame(height: max(8, CGFloat(point.value / maxValue) * 38))
                    Text(point.label)
                        .font(.system(size: 8, weight: point.isToday ? .black : .semibold, design: .rounded))
                        .foregroundStyle(point.isToday ? color : PulseTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct BodyWeightSummaryRow: View {
    let title: String
    let value: String
    let subtitle: String
    let goalText: String?

    var body: some View {
        PulseCard(contentPadding: 16) {
            HStack(spacing: 12) {
                Image(systemName: "figure")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(PulseTheme.grouped)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedKey(title))
                        .font(.subheadline.weight(.bold))
                    Text(localizedKey(subtitle))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(value)
                        .font(.system(size: 23, weight: .black, design: .rounded).monospacedDigit())
                    if let goalText {
                        Text(goalText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                }
            }
        }
    }
}

private struct HomeMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        PulseCard(minHeight: 102, contentPadding: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PulseTheme.onColor(color))
                        .frame(width: 22, height: 22)
                        .background(color)
                        .clipShape(Circle())
                    Text(localizedKey(title))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text(localizedKey(subtitle))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// Home wellness card — deliberately saturated (`DomainHeroCard`) rather than
/// the translucent `GlassMetricCard` used in detail screens, so each metric
/// reads as a solid block of color at a glance (competitor pattern: a red
/// heart-rate card, an amber steps card, an indigo sleep card…).
private struct WellnessWidget: View {
    let title: String
    let value: String
    let subtitle: String
    var localizesSubtitle = true
    let systemImage: String
    let domain: MetricDomain

    /// Without a real reading, the card would otherwise render at full
    /// saturation with a bare "--" — indistinguishable from a loading glitch.
    /// Muting it signals "not connected yet" instead of "broken".
    private var hasData: Bool { value != "--" }

    var body: some View {
        DomainHeroCard(domain: domain, minHeight: 156) {
            ZStack(alignment: .bottomTrailing) {
                if hasData {
                    WidgetVisualDecoration(domain: domain, valueString: value)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PulseIconBadge(systemImage: systemImage, tint: hasData ? domain.tint : PulseTheme.semanticNeutral, size: 30, radius: PulseTheme.smallRadius)
                        Text(localizedKey(title))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(0.2)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 2)

                    Text(hasData ? value : "–")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(hasData ? PulseTheme.textPrimary : PulseTheme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(localizesSubtitle ? localizedKey(subtitle) : subtitle)
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156, alignment: .topLeading)
            }
        }
        .opacity(hasData ? 1 : 0.86)
    }
}

private struct PlanMicroCard: View {
    let day: WorkoutDay
    let language: String
    let gender: BodyGender
    let catalog: [Exercise]

    private var leadingExercise: Exercise? {
        day.exercises.first?.exercise
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                if let leadingExercise {
                    ExerciseMediaThumbnail(exercise: leadingExercise, gender: gender, catalog: catalog)
                        .frame(width: 108, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .fill(PulseTheme.accent.opacity(0.10))
                        .frame(width: 108, height: 58)
                }
                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 24, height: 24)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
                    .offset(x: 5, y: 5)
            }
            Text(RepsText.workoutTitle(day.title, language: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(localizedFormat("exercises_count_format", day.exercises.count))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
            Spacer(minLength: 0)
            Label("\(day.durationMinutes) min", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.accent)
        }
        .padding(12)
        .frame(width: 132, height: 160, alignment: .leading)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 0.8)
        }
    }
}

private struct ShortcutTile: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            PulseIconBadge(systemImage: systemImage, tint: color, size: 42, radius: PulseTheme.mediumRadius)
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedKey(title))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(localizedKey(subtitle))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 90, alignment: .leading)
        .foregroundStyle(PulseTheme.textPrimary)
        .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 0.8)
        }
    }
}

private struct VisualExerciseCard: View {
    let exercise: Exercise
    let language: String
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image container (edge-to-edge top)
            ZStack(alignment: .bottomLeading) {
                ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
                    .frame(width: 156, height: 100)
                
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.40)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                Image(systemName: trackingIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 22, height: 22)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
                    .padding(6)
            }
            .frame(width: 156, height: 100)
            .clipped()
            
            // Content padding
            VStack(alignment: .leading, spacing: 6) {
                // Title (max 2 lines, fixed height for alignment)
                Text(RepsText.exerciseName(exercise.name, language: language))
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(height: 34, alignment: .topLeading)
                
                Spacer(minLength: 0)
                
                // Text aligned to footer
                Text("\(RepsText.muscle(exercise.muscleGroup, language: language)) · \(RepsText.equipment(exercise.equipment, language: language))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                // Tags aligned to footer (max 1 line)
                HStack(spacing: 4) {
                    Text(difficultyLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(difficultyColor.opacity(0.12))
                        .foregroundStyle(difficultyColor)
                        .clipShape(Capsule())
                    
                    Text(environmentLabel)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(PulseTheme.grouped)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .clipShape(Capsule())
                }
                .lineLimit(1)
            }
            .padding(10)
            .frame(width: 156, height: 114, alignment: .topLeading)
        }
        .frame(width: 156, height: 214) // Fixed vertical height for ALL cards!
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius - 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius - 4, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }

    private var trackingIcon: String {
        switch exercise.trackingType {
        case .weightReps: "dumbbell.fill"
        case .repsOnly: "figure.strengthtraining.traditional"
        case .duration: "timer"
        }
    }

    private var difficultyLabel: String {
        switch exercise.difficulty {
        case .low: return localizedString("easy_label")
        case .medium: return localizedString("medium_label")
        case .high: return localizedString("hard_label")
        }
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .low: return PulseTheme.ringStand
        case .medium: return PulseTheme.warning
        case .high: return PulseTheme.destructive
        }
    }

    private var environmentLabel: String {
        switch exercise.environment {
        case .home: return localizedString("home")
        case .gym: return localizedString("gym")
        case .both: return localizedString("mixed")
        }
    }
}

// MARK: - Premium Widget Visual Decorations
private struct WidgetVisualDecoration: View {
    let domain: MetricDomain
    let valueString: String

    var body: some View {
        Group {
            switch domain {
            case .recovery:
                if valueString.contains("%") {
                    BatteryLevelVisual(level: Int(valueString.filter("0123456789".contains)) ?? 80)
                } else {
                    HeartbeatWaveVisual(color: domain.tint)
                }
            case .strength:
                ConcentricRingVisual(progress: 0.70, color: domain.tint)
            case .nutrition:
                WaterDropsVisual(color: domain.tint)
            case .heartRate:
                HeartbeatWaveVisual(color: domain.tint)
            case .sleep:
                SleepStagesVisual(color: domain.tint)
            case .activity:
                MiniStepBarsVisual(color: domain.tint)
            case .cardio:
                UpwardTrendVisual(color: domain.tint)
            default:
                EmptyView()
            }
        }
        .frame(width: 64, height: 48)
        .opacity(0.18) // Muted watermark style to keep text readable
    }
}

private struct BatteryLevelVisual: View {
    let level: Int
    var body: some View {
        HStack(spacing: 3) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(PulseTheme.secondaryText.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 38, height: 20)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(level > 50 ? PulseTheme.recovery : (level > 20 ? PulseTheme.warning : PulseTheme.destructive))
                    .frame(width: CGFloat(min(100, max(0, level))) * 0.32, height: 14)
                    .padding(.leading, 2)
            }
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(PulseTheme.secondaryText.opacity(0.5))
                .frame(width: 3, height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private struct HeartbeatWaveVisual: View {
    let color: Color
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 24))
            path.addLine(to: CGPoint(x: 12, y: 24))
            path.addLine(to: CGPoint(x: 16, y: 12))
            path.addLine(to: CGPoint(x: 20, y: 36))
            path.addLine(to: CGPoint(x: 24, y: 24))
            path.addLine(to: CGPoint(x: 32, y: 24))
            path.addLine(to: CGPoint(x: 36, y: 4))
            path.addLine(to: CGPoint(x: 40, y: 44))
            path.addLine(to: CGPoint(x: 44, y: 24))
            path.addLine(to: CGPoint(x: 64, y: 24))
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .frame(width: 64, height: 48)
    }
}

private struct ConcentricRingVisual: View {
    let progress: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38, height: 38)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private struct WaterDropsVisual: View {
    let color: Color
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.system(size: 11))
                .foregroundStyle(color.opacity(0.6))
            Image(systemName: "drop.fill")
                .font(.system(size: 18))
                .foregroundStyle(color)
            Image(systemName: "drop.fill")
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private struct SleepStagesVisual: View {
    let color: Color
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color.opacity(0.4))
                .frame(width: 6, height: 12)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color.opacity(0.7))
                .frame(width: 6, height: 28)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color)
                .frame(width: 6, height: 18)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color.opacity(0.8))
                .frame(width: 6, height: 36)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(color.opacity(0.5))
                .frame(width: 6, height: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private struct MiniStepBarsVisual: View {
    let color: Color
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach([12, 22, 34, 28, 40, 36, 46], id: \.self) { height in
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(color)
                    .frame(width: 4, height: CGFloat(height))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

private struct UpwardTrendVisual: View {
    let color: Color
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 36))
                path.addLine(to: CGPoint(x: 12, y: 32))
                path.addLine(to: CGPoint(x: 24, y: 24))
                path.addLine(to: CGPoint(x: 36, y: 28))
                path.addLine(to: CGPoint(x: 48, y: 12))
                path.addLine(to: CGPoint(x: 60, y: 8))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 60, height: 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}


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
            return PulseTheme.primary
        case .low:
            return PulseTheme.warning
        case .critical:
            return PulseTheme.destructive
        }
    }

    private var coachInsight: FitnessMetrics.TrainingInsight {
        FitnessMetrics.insightCards(for: store.workoutSessions, goals: store.goals, since: weekStart).first
            ?? FitnessMetrics.TrainingInsight(
                title: String(localized: "Log Workouts to Activate Insights"),
                message: String(localized: "Complete a session with sets and reps to unlock practical signals."),
                systemImage: "sparkles"
            )
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

    private var nextBestSteps: [RetentionEngine.ActivationStep] {
        RetentionEngine.nextBestSteps(
            sessions: store.workoutSessions,
            activePlan: store.activePlan,
            scheduledWorkouts: store.scheduledWorkouts,
            remindersEnabled: store.userProfile.remindersEnabled,
            competitiveSummary: competitiveSummary
        )
    }

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }

    private var hasActivePlan: Bool {
        !store.activePlan.days.isEmpty
    }

    private var currentDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = isSpanish ? "EEEE, d MMMM" : "EEEE, d MMMM"
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
                title: isSpanish ? "Resumen" : "Summary",
                subtitle: currentDateTitle,
                topContentPadding: 104,
                accessory: {
                    HeaderAvatarButton(
                        imageData: store.userProfile.avatarImageData,
                        accessibilityLabel: isSpanish ? "Perfil" : "Profile"
                    ) {
                        showProfile = true
                    }
                }
            ) {
                summaryDashboard
                    .stickyHeaderTitle(isSpanish ? "Resumen" : "Summary")
                activationChecklist
                    .stickyHeaderTitle(isSpanish ? "Siguiente acción" : "Next Action")
                if !focusProgressionRecommendations.isEmpty {
                    ProgressionRecommendationCard(
                        recommendations: focusProgressionRecommendations,
                        language: store.userProfile.preferredLanguage,
                        title: isSpanish ? "Qué progresar hoy" : "What to Progress Today"
                    )
                    .stickyHeaderTitle(isSpanish ? "Progresión" : "Progression")
                }
                wellnessWidgets
                    .stickyHeaderTitle(isSpanish ? "Recuperación" : "Recovery")
                coachingCard
                    .stickyHeaderTitle(isSpanish ? "Coach" : "Coach")
                planSection
                    .stickyHeaderTitle(isSpanish ? "Plan" : "Plan")
                progressAndRecovery
                    .stickyHeaderTitle(isSpanish ? "Progreso" : "Progress")
                smartShortcuts
                    .stickyHeaderTitle(isSpanish ? "Atajos" : "Shortcuts")
                visualLibraryStrip
                    .stickyHeaderTitle(isSpanish ? "Biblioteca visual" : "Visual Library")
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
                    onSelectTab?(.plans)
                }
            }
            .navigationDestination(item: $workoutToStart) { workout in
                ActiveWorkoutView(workout: workout, origin: workout.id == freeWorkout.id ? .free : .routine)
            }
            .navigationDestination(isPresented: $showFreeWorkoutStart) {
                FreeWorkoutStartView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var summaryDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let activeStatus = store.activeWorkoutStatus {
                activeSessionHero(activeStatus)
            } else {
                dashboardWorkoutCard
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                SummaryMetricTile(
                    title: isSpanish ? "Entrenos" : "Workouts",
                    value: "\(recentSessions.count)",
                    subtitle: isSpanish ? "30 días" : "30 days",
                    systemImage: "figure.strengthtraining.traditional",
                    trendText: workoutTrendText,
                    color: PulseTheme.primary
                )
                SummaryMetricTile(
                    title: isSpanish ? "Series" : "Sets",
                    value: "\(recentCompletedSets.count)",
                    subtitle: isSpanish ? "completadas" : "completed",
                    systemImage: "square.stack.3d.up.fill",
                    trendText: nil,
                    color: PulseTheme.accent
                )
                SummaryMetricTile(
                    title: isSpanish ? "Volumen" : "Volume",
                    value: compactNumber(displayedRecentVolume),
                    subtitle: displayedVolumeUnit,
                    systemImage: "scalemass.fill",
                    trendText: volumeTrendText,
                    color: PulseTheme.primaryBright
                )
            }

            ActivityMatrixCard(
                title: isSpanish ? "Últimos 30 días" : "Last 30 Days",
                progressText: isSpanish ? "\(recentSessions.count) sesiones" : "\(recentSessions.count) sessions",
                points: recentActivityPoints,
                color: PulseTheme.primary
            )

            HStack(spacing: 12) {
                MiniTrendCard(
                    title: isSpanish ? "Volumen" : "Volume",
                    subtitle: isSpanish ? "tendencia semanal" : "weekly trend",
                    value: "\(compactNumber(displayedWeight(fromKilograms: FitnessMetrics.totalVolumeKg(for: weekSessions)))) \(displayedVolumeUnit)",
                    systemImage: "scalemass.fill",
                    trendText: volumeTrendText,
                    color: PulseTheme.accent
                ) {
                    MiniAreaChart(values: weeklyVolumeValues, color: PulseTheme.accent)
                        .frame(height: 54)
                }

                MiniTrendCard(
                    title: isSpanish ? "Esta semana" : "This Week",
                    subtitle: isSpanish ? "reps diarias" : "daily reps",
                    value: "\(weekCompletedSets.reduce(0) { $0 + $1.reps }) reps",
                    systemImage: "arrow.up.right",
                    trendText: weekRepsTrendText,
                    color: PulseTheme.primary
                ) {
                    MiniBarChart(points: weeklyRepsPoints, color: PulseTheme.primary)
                        .frame(height: 54)
                }
            }

            if latestMetric != nil {
                BodyWeightSummaryRow(
                    title: isSpanish ? "Peso corporal" : "Body Weight",
                    value: String(format: "%.1f %@", store.displayedWeight.value, store.displayedWeight.unit),
                    subtitle: isSpanish ? "último registro" : "latest log",
                    goalText: weightGoalText
                )
            }
        }
    }

    private var dashboardWorkoutCard: some View {
        let hasActivePlanSession = todaysScheduledWorkout != nil || hasActivePlan
        let titleText = hasActivePlanSession
            ? RepsText.workoutTitle(focusWorkout.title, language: store.userProfile.preferredLanguage)
            : (isSpanish ? "Elige tu entrenamiento" : "Choose Next Move")
        let subtitleText = hasActivePlanSession
            ? RepsText.localizedWorkoutSubtitle(focusWorkout.subtitle, language: store.userProfile.preferredLanguage)
            : (isSpanish ? "Entreno libre, rutina o sesión programada." : "Free workout, routine, or scheduled session.")
        let playButtonTitle = hasActivePlanSession
            ? (isSpanish ? "Empezar entreno" : "Start Workout")
            : (isSpanish ? "Entrenar libre" : "Free Workout")

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isSpanish ? "HOY" : "TODAY")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(PulseTheme.primary)
                        .clipShape(Capsule())

                        if !focusWorkout.exercises.isEmpty {
                            WorkoutExerciseAvatarStrip(
                                exercises: focusMediaExercises,
                                gender: store.userProfile.muscleMapGender,
                                tint: PulseTheme.primary
                            )
                    }

                    HStack(alignment: .center, spacing: 8) {
                        Text(titleText)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(PulseTheme.primary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            )

                        if !store.activePlan.days.isEmpty {
                            focusWorkoutMenu
                        }
                    }

                    Text(subtitleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if hasActivePlan {
                    Button {
                        HapticService.selection()
                        planToEdit = store.activePlan
                    } label: {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(PulseTheme.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSpanish ? "Editar plan" : "Edit plan")
                }
            }

            HStack(spacing: 8) {
                SummaryChip(title: "~\(focusWorkout.durationMinutes) min", systemImage: "clock", color: PulseTheme.primary)
                let exercisesWord = isSpanish ? "ejercicios" : "exercises"
                SummaryChip(title: "\(focusWorkout.exercises.count) \(exercisesWord)", systemImage: "dumbbell.fill", color: PulseTheme.accent)
                SummaryChip(title: locationLabel, systemImage: "mappin.and.ellipse", color: PulseTheme.primaryBright)
            }

            NavigationLink {
                if hasActivePlanSession {
                    ActiveWorkoutView(workout: focusWorkout)
                } else {
                    FreeWorkoutStartView()
                }
            } label: {
                Label(playButtonTitle, systemImage: "play.fill")
                    .font(.headline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [PulseTheme.accent, PulseTheme.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [PulseTheme.accentMuted, PulseTheme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: PulseTheme.accent.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private var focusWorkoutMenu: some View {
        Menu {
            Section(header: Text(isSpanish ? "Cambiar día" : "Change day")) {
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

            Section(header: Text(isSpanish ? "Cambiar plan" : "Change plan")) {
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

            let count = store.activePlan.days.count
            if count > 0 {
                let index = ((store.activePlan.activeDayIndex % count) + count) % count
                let suggestedDay = store.activePlan.days[index]
                if focusWorkout.id != suggestedDay.id {
                    Divider()
                    Button(role: .destructive) {
                        store.restoreSuggestedWorkoutForToday()
                    } label: {
                        Text(isSpanish ? "Restaurar sugerido" : "Restore suggested")
                    }
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(PulseTheme.primary)
        }
        .buttonStyle(.plain)
    }

    private var activationChecklist: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checklist.checked")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSpanish ? "Siguiente mejor acción" : "Next Best Action")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                            .textCase(.uppercase)
                        Text(isSpanish ? "Haz lo mínimo que más mueve tu progreso hoy." : "Do the smallest useful thing for today's progress.")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                ForEach(Array(nextBestSteps.enumerated()), id: \.element.id) { index, step in
                    TodayActivationStepRow(step: step, isSpanish: isSpanish) {
                        perform(step.action)
                    }
                    if index < nextBestSteps.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var dailyMissionCard: some View {
        let missionProgress = min(max(store.weeklyCompletion, 0), 1)
        let action = nextBestSteps.first { !$0.isCompleted } ?? nextBestSteps.first

        return PulseCard(contentPadding: 18) {
            HStack(alignment: .center, spacing: 16) {
                ProgressMissionRing(
                    progress: missionProgress,
                    color: batteryColor,
                    centerValue: "\(Int(missionProgress * 100))%"
                )
                .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label(isSpanish ? "Misión de hoy" : "Today's Mission", systemImage: "flag.checkered")
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.primary)
                        Spacer(minLength: 0)
                        Text("\(streakDays)🔥")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(PulseTheme.accent.opacity(0.12))
                            .foregroundStyle(PulseTheme.accent)
                            .clipShape(Capsule())
                    }

                    Text(action?.title ?? (isSpanish ? "Mantén el ritmo" : "Keep Momentum"))
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(action?.message ?? coachInsight.message)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 8) {
                        MissionSignal(title: isSpanish ? "Semana" : "Week", value: weekTargetText, color: PulseTheme.primary)
                        MissionSignal(title: isSpanish ? "Batería" : "Battery", value: "\(Int(batteryStatus.level))%", color: batteryColor)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentDateTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text("Summary")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Button {
                HapticService.selection()
                showProfile = true
            } label: {
                let avatarData = store.userProfile.avatarImageData
                if let avatarData, let image = UIImage(data: avatarData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.20), radius: 4)
                } else {
                    ZStack {
                        Circle()
                            .fill(PulseTheme.primary.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(PulseTheme.primary)
                    }
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.20), radius: 4)
                }
            }
            .padding(.top, 4)
            .buttonStyle(.plain)
            .accessibilityLabel(isSpanish ? "Perfil" : "Profile")
        }
    }

    @ViewBuilder
    private var focusHero: some View {
        if let activeStatus = store.activeWorkoutStatus {
            activeSessionHero(activeStatus)
        } else {
            idleHero
        }
    }

    // MARK: – Active session hero (replaces the old separate banner)
    private func activeSessionHero(_ status: ActiveWorkoutStatus) -> some View {
        let isPaused = status.isPaused
        let setsWord = isSpanish ? "series" : "sets"
        let progress: Double = status.totalSets > 0 ? Double(status.completedSets) / Double(status.totalSets) : 0
        let activeGradient: [Color] = isPaused
            ? [PulseTheme.card, Color(red: 0.24, green: 0.15, blue: 0.03)]
            : [PulseTheme.card, PulseTheme.accentMuted]

        return VStack(alignment: .leading, spacing: 18) {

            // ── Header row ────────────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(PulseTheme.separator, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(isPaused ? PulseTheme.warning : PulseTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Image(systemName: isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isPaused ? PulseTheme.warning : PulseTheme.accent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPaused ? "PAUSED" : "IN PROGRESS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(isPaused ? PulseTheme.warning : PulseTheme.accent)
                    Text(RepsText.workoutTitle(status.workoutTitle, language: store.userProfile.preferredLanguage))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            // ── Stats row ─────────────────────────────────────────────
            HStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    StatPill(
                        value: timeString(status.effectiveElapsedSeconds(at: timeline.date)),
                        label: isSpanish ? "tiempo" : "time",
                        systemImage: "timer"
                    )
                }
                Divider().frame(height: 32).opacity(0.3).padding(.horizontal, 8)
                StatPill(value: "\(status.completedSets)/\(status.totalSets)", label: setsWord,
                         systemImage: "checkmark.circle")
                Divider().frame(height: 32).opacity(0.3).padding(.horizontal, 8)
                StatPill(value: "\(status.volumeKg) kg", label: isSpanish ? "volumen" : "volume",
                         systemImage: "scalemass")
            }
            .foregroundStyle(.primary)

            // ── Compact progress bar ──────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PulseTheme.grouped).frame(height: 6)
                    Capsule().fill(isPaused ? PulseTheme.warning : PulseTheme.accent)
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
                    Label(isSpanish ? "Volver" : "Return", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.black)
                        .background(isPaused ? PulseTheme.warning : PulseTheme.accent)
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
                        .foregroundStyle(isPaused ? PulseTheme.warning : PulseTheme.accent)
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
                        .foregroundStyle(.white)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .accessibilityLabel("Stop workout")
            }
        }
        .padding(18)
        .foregroundStyle(.primary)
        .background(
            LinearGradient(
                colors: activeGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke((isPaused ? PulseTheme.warning : PulseTheme.accent).opacity(0.28), lineWidth: 1)
        )
        .shadow(
            color: (isPaused ? PulseTheme.warning : PulseTheme.accent).opacity(0.14),
            radius: 20, x: 0, y: 10
        )
    }

    // MARK: – Idle / pre-session hero (refined design)
    private var idleHero: some View {
        let hasActivePlanSession = todaysScheduledWorkout != nil || hasActivePlan
        let badgeText: String = {
            if todaysScheduledWorkout != nil {
                return isSpanish ? "SESIÓN PROGRAMADA" : "TODAY'S SESSION"
            } else if hasActivePlan {
                return isSpanish ? "SESIÓN SUGERIDA" : "SUGGESTED SESSION"
            } else {
                return isSpanish ? "SIN SESIÓN FIJADA" : "NO SESSION FIXED"
            }
        }()
        let titleText: String = {
            if hasActivePlanSession {
                return RepsText.workoutTitle(focusWorkout.title, language: store.userProfile.preferredLanguage)
            } else {
                return isSpanish ? "Elige tu entrenamiento" : "Choose Next Move"
            }
        }()
        let subtitleText: String = {
            if hasActivePlanSession {
                return RepsText.localizedWorkoutSubtitle(focusWorkout.subtitle, language: store.userProfile.preferredLanguage)
            } else {
                return isSpanish ? "Registra un entreno libre, crea una rutina o programa una sesión cuando estés listo." : "Log a free workout, create a routine, or schedule a session when you are ready."
            }
        }()
        let playButtonTitle: String = {
            if hasActivePlanSession {
                return isSpanish ? "Empezar" : "Start"
            } else {
                return isSpanish ? "Entrenar libre" : "Free Workout"
            }
        }()

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(badgeText)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.18))
                    .clipShape(Capsule())
                    .padding(.bottom, 2)
                
                HStack(alignment: .center, spacing: 6) {
                    Text(titleText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    
                    if !store.activePlan.days.isEmpty {
                        Menu {
                            Section(header: Text(isSpanish ? "Cambiar día" : "Change day")) {
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
                            
                            Section(header: Text(isSpanish ? "Cambiar plan" : "Change plan")) {
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
                            
                            let count = store.activePlan.days.count
                            let index = ((store.activePlan.activeDayIndex % count) + count) % count
                            let suggestedDay = store.activePlan.days[index]
                            if focusWorkout.id != suggestedDay.id {
                                Divider()
                                Button(role: .destructive) {
                                    store.restoreSuggestedWorkoutForToday()
                                } label: {
                                    Text(isSpanish ? "Restaurar sugerido" : "Restore suggested")
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .layoutPriority(1)
                    }
                }
                
                Text(subtitleText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 124)
            }

            HStack(spacing: 8) {
                HeroPill(title: "\(focusWorkout.durationMinutes) min", systemImage: "timer")
                let exercisesWord = isSpanish ? "ejercicios" : "exercises"
                HeroPill(title: "\(focusWorkout.exercises.count) \(exercisesWord)", systemImage: "list.bullet")
                HeroPill(title: locationLabel, systemImage: "mappin.and.ellipse")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    if hasActivePlanSession {
                        ActiveWorkoutView(workout: focusWorkout)
                    } else {
                        FreeWorkoutStartView()
                    }
                } label: {
                    Label(playButtonTitle, systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.black)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    showScheduleWorkout = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 58, height: 54)
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Programar entrenamiento")
            }
        }
        .padding(18)
        .foregroundStyle(.white)
        .background(
                LinearGradient(
                    colors: [PulseTheme.accentMuted, PulseTheme.card],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.accent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: PulseTheme.accent.opacity(0.12), radius: 18, x: 0, y: 10)
        .overlay(alignment: .topTrailing) {
            if hasActivePlan {
                Button {
                    HapticService.selection()
                    planToEdit = store.activePlan
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.12), radius: 4)
                }
                .buttonStyle(.plain)
                .padding(14)
                .accessibilityLabel(isSpanish ? "Editar plan" : "Edit plan")
            }
        }
        .overlay(alignment: .topTrailing) {
            WorkoutImageStack(
                exercises: focusPreviewExercises,
                gender: store.userProfile.muscleMapGender,
                fallbackSystemImage: hasActivePlanSession ? "figure.strengthtraining.traditional" : "sparkles"
            )
            .padding(.top, 40)
            .padding(.trailing, 8)
            .allowsHitTesting(false)
        }
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
            if let destination = store.executeCompetitiveAction(competitiveAction) {
                onSelectTab?(destination)
            }
        case .openProgress:
            onSelectTab?(.progress)
        }
    }

    private var weeklyCommandGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            HomeMetricTile(title: "Week", value: weekTargetText, subtitle: isSpanish ? "sesiones" : "sessions", systemImage: "calendar", color: PulseTheme.primary)
            HomeMetricTile(title: "Volume", value: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: isSpanish ? "kg esta semana" : "kg this week", systemImage: "scalemass", color: PulseTheme.primaryBright)
            HomeMetricTile(title: "Streak", value: "\(streakDays)", subtitle: isSpanish ? "días seguidos" : "days in a row", systemImage: "flame", color: PulseTheme.accent)
        }
    }

    private var wellnessWidgets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                NavigationLink {
                    TrainingBatteryView()
                } label: {
                    WellnessWidget(
                        title: isSpanish ? "Batería de entreno" : "Battery",
                        value: "\(batteryStatus.level)%",
                        subtitle: batteryStatus.suggestion,
                        systemImage: batteryStatus.systemImage,
                        color: batteryColor
                    )
                }
                .buttonStyle(.plain)

                WellnessWidget(
                    title: isSpanish ? "Ejercicio" : "Exercise",
                    value: store.todayHealthMetric.map { "\(Int($0.exerciseMinutes ?? 0)) min" } ?? "--",
                    subtitle: "Apple Watch / Health",
                    systemImage: "applewatch",
                    color: PulseTheme.primaryBright
                )

                WellnessWidget(
                    title: isSpanish ? "Hidratación" : "Hydration",
                    value: store.todayHealthMetric.map { String(format: "%.1f L", $0.waterLiters) } ?? "--",
                    subtitle: latestMetric?.waterLiters.map { String(format: "%.1f L en Reps", $0) } ?? (isSpanish ? "Sin registro local" : "No local log"),
                    systemImage: "drop.fill",
                    color: PulseTheme.primaryBright
                )

                WellnessWidget(
                    title: "HRV",
                    value: store.todayHealthMetric?.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--",
                    subtitle: store.todayHealthMetric?.restingHeartRate.map { "\(Int($0)) lpm reposo" } ?? (isSpanish ? "Sin pulso de reposo" : "No resting HR"),
                    systemImage: "waveform.path.ecg",
                    color: PulseTheme.accent
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var coachingCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: batteryStatus.level < 55 ? batteryStatus.systemImage : coachInsight.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(batteryStatus.level < 55 ? batteryColor : PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Insight")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(batteryStatus.level < 55 ? batteryColor : PulseTheme.primary)
                            .textCase(.uppercase)
                        Text(batteryStatus.level < 55 ? batteryStatus.title : coachInsight.title)
                            .font(.headline)
                        Text(batteryStatus.level < 55 ? batteryStatus.suggestion : coachInsight.message)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        if hasActivePlan {
            planPreview
        } else {
            noPlanCard
        }
    }

    private var noPlanCard: some View {
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
                        Text(isSpanish ? "Sin plan activo" : "No active plan")
                            .font(.headline)
                        Text(isSpanish ? "Crea una rutina o programa una sesión cuando estés listo." : "Create a routine or schedule a session when you are ready.")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        Label(isSpanish ? "Crear plan" : "Create plan", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showScheduleWorkout = true
                    } label: {
                        Label(isSpanish ? "Programar" : "Schedule", systemImage: "calendar")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var planPreview: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(store.activePlan.name, systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.primary)
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
                                .foregroundStyle(PulseTheme.primary)
                            Text(isSpanish ? "Objetivo: \(eventName)" : "Target: \(eventName)")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if daysDiff > 0 {
                                Text(isSpanish ? "Faltan \(daysDiff) días (\(weeks) sem)" : "\(daysDiff) days left (\(weeks) wk)")
                                    .font(.caption.bold())
                                    .foregroundStyle(PulseTheme.primaryBright)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PulseTheme.primaryBright.opacity(0.12))
                                    .clipShape(Capsule())
                            } else if daysDiff == 0 {
                                Text(isSpanish ? "¡Hoy es el día!" : "Today is the day!")
                                    .font(.caption.bold())
                                    .foregroundStyle(PulseTheme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(PulseTheme.accent.opacity(0.12))
                                    .clipShape(Capsule())
                            } else {
                                Text(isSpanish ? "Completado" : "Completed")
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
                                return isSpanish 
                                    ? "¡Llegó el día de tu evento! Esperamos que hayas alcanzado tus objetivos."
                                    : "The event day has arrived! We hope you achieved your goals."
                            } else if weeks < 6 {
                                return isSpanish
                                    ? "Plazo corto. Sugerimos maximizar intensidad ahora y evitar fatiga excesiva justo antes de tu evento. Considera extender tu plan más adelante."
                                    : "Short target. We suggest maximizing intensity now and avoiding excessive fatigue just before your event. Consider extending your plan later."
                            } else if weeks <= 12 {
                                return isSpanish
                                    ? "¡Plazo óptimo! Tienes el tiempo perfecto para completar un ciclo completo de entrenamiento y llegar en tu mejor forma."
                                    : "Optimal timeline! You have the perfect amount of time to complete a full training block and arrive in peak shape."
                            } else {
                                return isSpanish
                                    ? "Plazo largo. Te sugerimos realizar un bloque de fuerza/hipertrofia de 8-12 semanas y luego un plan de mantenimiento o definición secundario para afinar detalles."
                                    : "Long timeline. We suggest completing an 8-12 week strength/hypertrophy block, followed by a secondary definition/maintenance cycle."
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
                                    gender: store.userProfile.muscleMapGender
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var progressAndRecovery: some View {
        HStack(spacing: 12) {
            PulseCard(minHeight: 125) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(isSpanish ? "Último entreno" : "Last Workout", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer(minLength: 0)
                    Text(lastWorkout.map { RepsText.workoutTitle($0.workoutTitle, language: store.userProfile.preferredLanguage) } ?? (isSpanish ? "Sin entrenos" : "No Workouts"))
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(lastWorkoutSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            PulseCard(minHeight: 125) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(isSpanish ? "Salud" : "Health", systemImage: "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer(minLength: 0)
                    Text(store.todayHealthMetric.map { "\($0.steps, specifier: "%.0f")" } ?? "--")
                        .font(.title2.bold().monospacedDigit())
                    Text(isSpanish ? "pasos hoy" : "steps today")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var smartShortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isSpanish ? "Accesos directos" : "Smart Shortcuts")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    let exercisesCount = store.exercises.count
                    let sub = isSpanish ? "\(exercisesCount) ejercicios" : "\(exercisesCount) exercises"
                    ShortcutTile(
                        title: isSpanish ? "Biblioteca" : "Library",
                        subtitle: LocalizedStringKey(sub),
                        systemImage: "photo.stack",
                        color: PulseTheme.primary
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
                        title: isSpanish ? "Progreso" : "Progress",
                        subtitle: isSpanish ? "gráficas e insights" : "charts & insights",
                        systemImage: "chart.line.uptrend.xyaxis",
                        color: PulseTheme.primaryBright
                    )
                }
                .buttonStyle(.plain)

                Button {
                    HapticService.selection()
                    showCreatePlan = true
                } label: {
                    ShortcutTile(
                        title: isSpanish ? "Nueva rutina" : "New Plan",
                        subtitle: isSpanish ? "diseño editable" : "editable routine",
                        systemImage: "square.stack.3d.up",
                        color: PulseTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutLibraryView()
                } label: {
                    let templatesCount = store.workoutTemplates.count
                    let sub = isSpanish ? "\(templatesCount) plantillas" : "\(templatesCount) templates"
                    ShortcutTile(
                        title: isSpanish ? "Plantillas" : "Routines",
                        subtitle: LocalizedStringKey(sub),
                        systemImage: "list.clipboard",
                        color: PulseTheme.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var visualLibraryStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Visual References")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    Text("View All")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(featuredExercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            VisualExerciseCard(
                                exercise: exercise,
                                language: store.userProfile.preferredLanguage,
                                gender: store.userProfile.muscleMapGender
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var locationLabel: String {
        guard hasActivePlan else {
            return isSpanish ? "libre" : "free"
        }

        if isSpanish {
            return switch store.activePlan.location {
            case .gym: "gimnasio"
            case .home: "casa"
            case .both: "mixto"
            }
        } else {
            return switch store.activePlan.location {
            case .gym: "gym"
            case .home: "home"
            case .both: "mixed"
            }
        }
    }

    private var lastWorkoutSubtitle: String {
        guard let lastWorkout else {
            return String(localized: "Complete your first session")
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
            return isSpanish ? "hoy" : "today"
        }
        if calendar.isDateInYesterday(date) {
            return isSpanish ? "ayer" : "yesterday"
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

private struct HeroPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius - 2, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius - 2, style: .continuous))
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
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
        .frame(maxWidth: .infinity)
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
                Text(title)
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
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .accessibilityLabel("\(title) \(level)%")
    }
}

private struct WorkoutImageStack: View {
    let exercises: [Exercise]
    let gender: BodyGender
    let fallbackSystemImage: String

    var body: some View {
        ZStack {
            if exercises.isEmpty {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 74, height: 74)
                    .background(.white.opacity(0.14))
                    .clipShape(Circle())
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseCardImage(exercise: exercise, gender: gender)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1.8))
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
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
                    ExerciseMediaThumbnail(exercise: exercise, gender: gender)
                        .frame(width: diameter, height: diameter)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 2))
                        .shadow(color: tint.opacity(0.28), radius: 9, x: 0, y: 5)
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
        .accessibilityLabel("Ejercicios del plan")
    }
}

private struct TodayActivationStepRow: View {
    let step: RetentionEngine.ActivationStep
    let isSpanish: Bool
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                    .fill(iconColor.opacity(step.isCompleted ? 0.18 : 0.12))
                Image(systemName: step.isCompleted ? "checkmark.seal.fill" : step.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(step.title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    if step.isCompleted {
                        Text(isSpanish ? "Hecho" : "Done")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.recovery)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(PulseTheme.recovery.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(step.message)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !step.isCompleted {
                    Button(action: onAction) {
                        Label(step.actionTitle, systemImage: "arrow.forward.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(PulseTheme.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        step.isCompleted ? PulseTheme.recovery : PulseTheme.primary
    }
}

private struct ProgressMissionRing: View {
    let progress: Double
    let color: Color
    let centerValue: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseTheme.grouped, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(colors: [color, PulseTheme.accent, color], center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(centerValue)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text("GO")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .accessibilityLabel("Progreso de misión \(centerValue)")
    }
}

private struct MissionSignal: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(color)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct SummaryMetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let trendText: String?
    let color: Color

    private var trendColor: Color {
        guard let trendText else { return PulseTheme.secondaryText }
        return trendText.hasPrefix("-") ? PulseTheme.destructive : PulseTheme.recovery
    }

    var body: some View {
        PulseCard(minHeight: 112, contentPadding: 12, backgroundColor: color.opacity(0.08)) {
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
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct ActivityMatrixCard: View {
    let title: String
    let progressText: String
    let points: [DailyActivityPoint]
    let color: Color

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
                PulseTheme.primaryBright.opacity(0.58 + (0.30 * intensity)),
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
        PulseCard(contentPadding: 16, backgroundColor: color.opacity(0.07)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(progressText)
                        .font(.caption.weight(.black).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(points) { point in
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(fill(for: point))
                            .frame(height: 17)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(point.isToday ? PulseTheme.accent : PulseTheme.separator, style: StrokeStyle(lineWidth: point.isToday ? 2 : 1, dash: point.isCompleted ? [] : [4, 3]))
                            )
                            .accessibilityLabel(accessibilityLabel(for: point))
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
    let systemImage: String
    let trendText: String?
    let color: Color
    let chart: Chart

    init(
        title: String,
        subtitle: String,
        value: String,
        systemImage: String,
        trendText: String?,
        color: Color,
        @ViewBuilder chart: () -> Chart
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
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
        PulseCard(minHeight: 156, contentPadding: 14, backgroundColor: color.opacity(0.08)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.black))
                            .foregroundStyle(color)
                        Text(subtitle)
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

                Text(value)
                    .font(.system(size: 25, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                chart
            }
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
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
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
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(color)
                        .clipShape(Circle())
                    Text(title)
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
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct WellnessWidget: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 166, height: 126, alignment: .topLeading)
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }
}

private struct PlanMicroCard: View {
    let day: WorkoutDay
    let language: String
    let gender: BodyGender

    private var leadingExercise: Exercise? {
        day.exercises.first?.exercise
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                if let leadingExercise {
                    ExerciseCardImage(exercise: leadingExercise, gender: gender)
                        .frame(width: 108, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .fill(PulseTheme.primary.opacity(0.10))
                        .frame(width: 108, height: 58)
                }
                Image(systemName: "play.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(PulseTheme.primary)
                    .clipShape(Circle())
                    .offset(x: 5, y: 5)
            }
            Text(RepsText.workoutTitle(day.title, language: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(day.exercises.count) ejercicios")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
            Spacer(minLength: 0)
            Label("\(day.durationMinutes) min", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.primary)
        }
        .padding(12)
        .frame(width: 132, height: 160, alignment: .leading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ShortcutTile: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .leading)
        .foregroundStyle(.primary)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }
}

private struct VisualExerciseCard: View {
    let exercise: Exercise
    let language: String
    let gender: BodyGender

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image container (edge-to-edge top)
            ZStack(alignment: .bottomLeading) {
                ExerciseCardImage(exercise: exercise, gender: gender)
                    .frame(width: 156, height: 100)
                
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.40)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                Image(systemName: trackingIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(PulseTheme.primary)
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
        case .low: return language.hasPrefix("es") ? "Fácil" : "Easy"
        case .medium: return language.hasPrefix("es") ? "Medio" : "Medium"
        case .high: return language.hasPrefix("es") ? "Difícil" : "Hard"
        }
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .low: return PulseTheme.primaryBright
        case .medium: return PulseTheme.warning
        case .high: return PulseTheme.destructive
        }
    }

    private var environmentLabel: String {
        switch exercise.environment {
        case .home: return language.hasPrefix("es") ? "Casa" : "Home"
        case .gym: return language.hasPrefix("es") ? "Gym" : "Gym"
        case .both: return language.hasPrefix("es") ? "Mixto" : "Mixed"
        }
    }
}

private struct ExerciseCardImage: View {
    let exercise: Exercise
    var gender: BodyGender = .male

    var body: some View {
        ZStack {
            if let data = exercise.customImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = exercise.mediaAssetURL {
                RemoteExerciseImage(url: url) {
                    fallback
                }
            } else {
                fallback
            }
        }
        .background(PulseTheme.grouped)
        .clipped()
    }

    private var fallback: some View {
        ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

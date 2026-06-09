import MuscleMap
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showScheduleWorkout = false
    @State private var showCreatePlan = false
    @State private var showProfile = false
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    focusHero
                    activationChecklist
                    if !focusProgressionRecommendations.isEmpty {
                        ProgressionRecommendationCard(
                            recommendations: focusProgressionRecommendations,
                            language: store.userProfile.preferredLanguage,
                            title: isSpanish ? "Qué progresar hoy" : "What to Progress Today"
                        )
                    }
                    weeklyCommandGrid
                    wellnessWidgets
                    coachingCard
                    planSection
                    progressAndRecovery
                    smartShortcuts
                    visualLibraryStrip
                }
                .padding(20)
                .safeAreaPadding(.top, 8)
                .padding(.bottom, 120)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showScheduleWorkout) {
                ScheduleWorkoutView()
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView {
                    onSelectTab?(.plans)
                }
            }
            .sheet(item: $planToEdit) { plan in
                EditPlanView(plan: plan)
            }
            .navigationDestination(item: $workoutToStart) { workout in
                ActiveWorkoutView(workout: workout, origin: workout.id == freeWorkout.id ? .free : .routine)
            }
        }
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
                    hasActivePlanSession
                        ? ActiveWorkoutView(workout: focusWorkout)
                        : ActiveWorkoutView(workout: freeWorkout, origin: .free)
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

    private func perform(_ action: RetentionEngine.ActivationAction?) {
        guard let action else {
            showProfile = true
            return
        }

        switch action {
        case .startWorkout:
            workoutToStart = (todaysScheduledWorkout != nil || hasActivePlan) ? focusWorkout : freeWorkout
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
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
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

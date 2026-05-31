import MuscleMap
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showScheduleWorkout = false
    @State private var showCreatePlan = false

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
        min(weekSessions.count, store.activePlan.daysPerWeek)
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

    private var readinessScore: Int {
        var score = 76
        if let sleep = latestMetric?.sleepHours {
            score += sleep >= 7 ? 10 : -8
        }
        if let fatigue = latestMetric?.fatigue {
            score -= max(0, fatigue - 2) * 6
        }
        if let stress = latestMetric?.stress {
            score -= max(0, stress - 2) * 5
        }
        return min(max(score, 35), 96)
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
        let planned = focusWorkout.exercises.map(\.exercise).filter { ($0.mediaURL ?? "").isEmpty == false }
        return Array((planned.isEmpty ? featuredExercises : planned).prefix(3))
    }

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
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
                    weeklyCommandGrid
                    coachingCard
                    planPreview
                    progressAndRecovery
                    smartShortcuts
                    visualLibraryStrip
                }
                .padding(20)
                .safeAreaPadding(.top, 8)
                .padding(.bottom, 120)
            }
            .screenBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showScheduleWorkout) {
                ScheduleWorkoutView()
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(currentDateTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text("Training Hub")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            ReadinessBadge(score: readinessScore, title: isSpanish ? "estado" : "readiness")
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
            ? [Color(red: 0.80, green: 0.50, blue: 0.00), PulseTheme.warning, Color(red: 0.95, green: 0.65, blue: 0.10)]
            : [PulseTheme.primary, Color(red: 0.48, green: 0.38, blue: 0.92), PulseTheme.accent]

        return VStack(alignment: .leading, spacing: 18) {

            // ── Header row ────────────────────────────────────────────
            HStack(alignment: .top, spacing: 14) {

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Image(systemName: isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isPaused ? "PAUSED" : "IN PROGRESS")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.white.opacity(0.75))
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
                StatPill(value: timeString(status.elapsedSeconds), label: isSpanish ? "tiempo" : "time",
                         systemImage: "timer")
                Divider().frame(height: 32).opacity(0.3).padding(.horizontal, 8)
                StatPill(value: "\(status.completedSets)/\(status.totalSets)", label: setsWord,
                         systemImage: "checkmark.circle")
                Divider().frame(height: 32).opacity(0.3).padding(.horizontal, 8)
                StatPill(value: "\(status.volumeKg) kg", label: isSpanish ? "volumen" : "volume",
                         systemImage: "scalemass")
            }
            .foregroundStyle(.white)

            // ── Compact progress bar ──────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.20)).frame(height: 6)
                    Capsule().fill(.white)
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
                        .foregroundStyle(isPaused ? PulseTheme.warning : PulseTheme.primary)
                        .background(.white)
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
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.20))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(.white.opacity(0.30), lineWidth: 1)
                        )
                }
                .accessibilityLabel(isPaused ? "Resume workout" : "Pause workout")

                // Stop
                Button {
                    store.clearActiveWorkout()
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
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: activeGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .shadow(
            color: (isPaused ? PulseTheme.warning : PulseTheme.primary).opacity(0.28),
            radius: 20, x: 0, y: 10
        )
    }

    // MARK: – Idle / pre-session hero (original design, unchanged)
    private var idleHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todaysScheduledWorkout == nil ? "NO SESSION FIXED" : "TODAY'S SESSION")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                        .padding(.bottom, 2)
                    Text(todaysScheduledWorkout == nil ? "Choose Next Move" : RepsText.workoutTitle(focusWorkout.title, language: store.userProfile.preferredLanguage))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(todaysScheduledWorkout == nil ? "You can log a free workout, schedule a session, or continue your active plan." : RepsText.localizedWorkoutSubtitle(focusWorkout.subtitle, language: store.userProfile.preferredLanguage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                WorkoutImageStack(
                    exercises: focusPreviewExercises,
                    gender: store.userProfile.muscleMapGender,
                    fallbackSystemImage: todaysScheduledWorkout == nil ? "sparkles" : "figure.strengthtraining.traditional"
                )
            }

            HStack(spacing: 10) {
                HeroPill(title: "\(focusWorkout.durationMinutes) min", systemImage: "timer")
                let exercisesWord = isSpanish ? "ejercicios" : "exercises"
                HeroPill(title: "\(focusWorkout.exercises.count) \(exercisesWord)", systemImage: "list.bullet")
                HeroPill(title: locationLabel, systemImage: "mappin.and.ellipse")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    todaysScheduledWorkout == nil
                        ? ActiveWorkoutView(workout: freeWorkout, origin: .free)
                        : ActiveWorkoutView(workout: focusWorkout)
                } label: {
                    Label(todaysScheduledWorkout == nil ? "Free Workout" : "Start", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.black)
                        .background(.white)
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
                colors: [PulseTheme.primary, Color(red: 0.48, green: 0.38, blue: 0.92), PulseTheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .shadow(color: PulseTheme.primary.opacity(0.20), radius: 18, x: 0, y: 10)
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var weeklyCommandGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            HomeMetricTile(title: "Week", value: "\(completedThisWeek)/\(store.activePlan.daysPerWeek)", subtitle: "sessions", systemImage: "calendar", color: PulseTheme.primary)
            HomeMetricTile(title: "Volume", value: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: "kg this week", systemImage: "scalemass", color: PulseTheme.primaryBright)
            HomeMetricTile(title: "Streak", value: "\(streakDays)", subtitle: "days in a row", systemImage: "flame", color: PulseTheme.accent)
            HomeMetricTile(title: "1RM", value: "\(Int(store.bestEstimatedOneRepMaxKg))", subtitle: "best estimate", systemImage: "trophy", color: PulseTheme.warning)
        }
    }

    private var coachingCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: coachInsight.systemImage)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Insight")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                            .textCase(.uppercase)
                        Text(coachInsight.title)
                            .font(.headline)
                        Text(coachInsight.message)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                    .tint(PulseTheme.primaryBright)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)

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
                    Label("Last Workout", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer(minLength: 0)
                    Text(lastWorkout.map { RepsText.workoutTitle($0.workoutTitle, language: store.userProfile.preferredLanguage) } ?? "No Workouts")
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
                    Label("Health", systemImage: "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer(minLength: 0)
                    Text(store.todayHealthMetric.map { "\($0.steps, specifier: "%.0f")" } ?? "--")
                        .font(.title2.bold().monospacedDigit())
                    Text("steps today")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var smartShortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Shortcuts")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    let exercisesCount = store.exercises.count
                    let sub = store.userProfile.preferredLanguage.hasPrefix("es") ? "\(exercisesCount) ejercicios" : "\(exercisesCount) exercises"
                    ShortcutTile(title: "Library", subtitle: LocalizedStringKey(sub), systemImage: "photo.stack", color: PulseTheme.primary)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ProgressDashboardView()
                } label: {
                    ShortcutTile(title: "Progress", subtitle: "charts & insights", systemImage: "chart.line.uptrend.xyaxis", color: PulseTheme.primaryBright)
                }
                .buttonStyle(.plain)

                Button {
                    showCreatePlan = true
                } label: {
                    ShortcutTile(title: "New Plan", subtitle: "editable routine", systemImage: "square.stack.3d.up", color: PulseTheme.accent)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutLibraryView()
                } label: {
                    let templatesCount = store.workoutTemplates.count
                    let sub = store.userProfile.preferredLanguage.hasPrefix("es") ? "\(templatesCount) plantillas" : "\(templatesCount) templates"
                    ShortcutTile(title: "Routines", subtitle: LocalizedStringKey(sub), systemImage: "list.clipboard", color: PulseTheme.primary)
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
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
    let score: Int
    let title: String

    private var color: Color {
        score >= 70 ? PulseTheme.primaryBright : PulseTheme.accent
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(PulseTheme.grouped, lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(width: 76, height: 76)
        .padding(8)
        .background(PulseTheme.card)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .accessibilityLabel("\(title) \(score)")
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
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.92), lineWidth: 2))
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
                        .offset(x: CGFloat(index) * -18, y: CGFloat(index) * 12)
                }
            }
        }
        .frame(width: 92, height: 90)
        .accessibilityHidden(true)
    }
}

private struct HomeMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey
    let systemImage: String
    let color: Color

    var body: some View {
        PulseCard(minHeight: 115) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(color)
                        .clipShape(Circle())
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
        }
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
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                ExerciseCardImage(exercise: exercise, gender: gender)
                    .frame(width: 150, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                Image(systemName: trackingIcon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(PulseTheme.primary)
                    .clipShape(Circle())
                    .padding(8)
            }

            Text(RepsText.exerciseName(exercise.name, language: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.primary)
            Text("\(RepsText.muscle(exercise.muscleGroup, language: language)) · \(RepsText.equipment(exercise.equipment, language: language))")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(width: 170, height: 190, alignment: .topLeading)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
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

}

private struct ExerciseCardImage: View {
    let exercise: Exercise
    var gender: BodyGender = .male

    var body: some View {
        ZStack {
            fallback
        }
        .background(PulseTheme.grouped)
        .clipped()
    }

    private var fallback: some View {
        ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

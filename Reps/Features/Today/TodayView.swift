import MuscleMap
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showScheduleWorkout = false
    @State private var showCreatePlan = false

    private var freeWorkout: WorkoutDay {
        WorkoutDay(
            title: "Entrenamiento libre",
            subtitle: "Añade ejercicios durante la sesión",
            durationMinutes: 45,
            exercises: []
        )
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
        let calendar = Calendar.current
        let workoutDays = Set(store.workoutSessions.map { calendar.startOfDay(for: $0.date) })
        var date = calendar.startOfDay(for: .now)
        var streak = 0

        while workoutDays.contains(date) {
            streak += 1
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }

        return streak
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
                title: "Registra entrenos para activar insights",
                message: "Completa una sesión con series y repeticiones para desbloquear señales prácticas.",
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
                    if let activeStatus = store.activeWorkoutStatus {
                        activeWorkoutBanner(activeStatus)
                    }
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
                Text("Centro de entrenamiento")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            ReadinessBadge(score: readinessScore, title: isSpanish ? "estado" : "readiness")
        }
    }

    private func activeWorkoutBanner(_ status: ActiveWorkoutStatus) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: status.isPaused ? "pause.fill" : "figure.strengthtraining.traditional")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(status.isPaused ? PulseTheme.warning : PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.isPaused ? "ENTRENO PAUSADO" : "ENTRENO EN PROGRESO")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                        Text(RepsText.workoutTitle(status.workoutTitle, language: store.userProfile.preferredLanguage))
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text("\(timeString(status.elapsedSeconds)) · \(status.completedSets)/\(status.totalSets) series · \(status.volumeKg) kg")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        store.setActiveWorkoutPaused(!status.isPaused)
                    } label: {
                        Label(status.isPaused ? "Reanudar" : "Pausar", systemImage: status.isPaused ? "play.fill" : "pause.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.white)
                            .background(status.isPaused ? PulseTheme.primary : PulseTheme.warning)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    Button {
                        store.clearActiveWorkout()
                    } label: {
                        Label("Detener", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.white)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private var focusHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todaysScheduledWorkout == nil ? "SIN SESIÓN FIJADA" : "SESIÓN DE HOY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.78))
                    Text(todaysScheduledWorkout == nil ? "Elige el siguiente movimiento" : RepsText.workoutTitle(focusWorkout.title, language: store.userProfile.preferredLanguage))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(todaysScheduledWorkout == nil ? "Puedes registrar libre, programar una sesión o continuar tu plan activo." : localizedWorkoutSubtitle(focusWorkout.subtitle))
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
                HeroPill(title: "\(focusWorkout.exercises.count) ejercicios", systemImage: "list.bullet")
                HeroPill(title: locationLabel, systemImage: "mappin.and.ellipse")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    todaysScheduledWorkout == nil
                        ? ActiveWorkoutView(workout: freeWorkout, origin: .free)
                        : ActiveWorkoutView(workout: focusWorkout)
                } label: {
                    Label(todaysScheduledWorkout == nil ? "Entrenar libre" : "Empezar", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(PulseTheme.accent)
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
                colors: [PulseTheme.primary, PulseTheme.accent],
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
            HomeMetricTile(title: "Semana", value: "\(completedThisWeek)/\(store.activePlan.daysPerWeek)", subtitle: "sesiones", systemImage: "calendar", color: PulseTheme.primary)
            HomeMetricTile(title: "Volumen", value: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: "kg esta semana", systemImage: "scalemass", color: PulseTheme.primaryBright)
            HomeMetricTile(title: "Racha", value: "\(streakDays)", subtitle: "días seguidos", systemImage: "flame", color: PulseTheme.accent)
            HomeMetricTile(title: "1RM", value: "\(Int(store.bestEstimatedOneRepMaxKg))", subtitle: "mejor estimado", systemImage: "trophy", color: PulseTheme.warning)
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
                        Text("Insight de hoy")
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
            PulseCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Último entreno", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(lastWorkout.map { RepsText.workoutTitle($0.workoutTitle, language: store.userProfile.preferredLanguage) } ?? "Sin entrenos")
                        .font(.headline)
                        .lineLimit(2)
                    Text(lastWorkoutSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Salud", systemImage: "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(store.todayHealthMetric.map { "\($0.steps, specifier: "%.0f")" } ?? "--")
                        .font(.title.bold().monospacedDigit())
                    Text("pasos hoy")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var smartShortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accesos de valor")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    ShortcutTile(title: "Biblioteca", subtitle: "\(store.exercises.count) ejercicios", systemImage: "photo.stack", color: PulseTheme.primary)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ProgressDashboardView()
                } label: {
                    ShortcutTile(title: "Progreso", subtitle: "gráficas e insights", systemImage: "chart.line.uptrend.xyaxis", color: PulseTheme.primaryBright)
                }
                .buttonStyle(.plain)

                Button {
                    showCreatePlan = true
                } label: {
                    ShortcutTile(title: "Nuevo plan", subtitle: "rutina editable", systemImage: "square.stack.3d.up", color: PulseTheme.accent)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutLibraryView()
                } label: {
                    ShortcutTile(title: "Rutinas", subtitle: "\(store.workoutTemplates.count) plantillas", systemImage: "list.clipboard", color: PulseTheme.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var visualLibraryStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Referencias visuales")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    ExerciseLibraryView()
                } label: {
                    Text("Ver todo")
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
        switch store.activePlan.location {
        case .gym: "gimnasio"
        case .home: "casa"
        case .both: "mixto"
        }
    }

    private var lastWorkoutSubtitle: String {
        guard let lastWorkout else {
            return "Completa tu primera sesión"
        }
        return "\(relativeDateTitle(for: lastWorkout.date)) · \(lastWorkout.durationMinutes) min"
    }

    private func relativeDateTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return isSpanish ? "hoy" : "today"
        }
        if calendar.isDateInYesterday(date) {
            return isSpanish ? "ayer" : "yesterday"
        }
        let startToday = calendar.startOfDay(for: .now)
        let startDate = calendar.startOfDay(for: date)
        let days = abs(calendar.dateComponents([.day], from: startDate, to: startToday).day ?? 0)
        return isSpanish ? "hace \(days) días" : "\(days) days ago"
    }

    private func localizedWorkoutSubtitle(_ subtitle: String) -> String {
        guard isSpanish else {
            return subtitle
        }

        return switch subtitle.lowercased() {
        case "upper body & core": "Tren superior y core"
        case "back & biceps": "Espalda y bíceps"
        case "lower body": "Tren inferior"
        case "dumbbells, bands & bodyweight": "Mancuernas, bandas y peso corporal"
        case "limited equipment strength": "Fuerza con equipamiento limitado"
        default: subtitle
        }
    }
}

private struct HeroPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
        .background(.white)
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
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
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
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
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
            Label("\(day.durationMinutes) min", systemImage: "timer")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PulseTheme.primary)
        }
        .padding(12)
        .frame(width: 132, alignment: .leading)
        .frame(minHeight: 148, alignment: .leading)
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

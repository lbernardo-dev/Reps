import MuscleMap
import SwiftUI

// MARK: - Layout customization

/// The optional, reorderable/hideable cards on Today, including the primary
/// workout hero (`.hero`, first by default) — fully reorderable/hideable like
/// every other card, per explicit request rather than pinned Apple-Rings-style.
private enum TodaySection: String, CustomizableSection {
    case hero, greeting, weeklyProgress, weather, insights, continuity, recommendedWorkout
    case progression, signals, wellness, plan, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero: localizedString("workout")
        case .greeting: localizedString("daily_greeting")
        case .weeklyProgress: localizedString("weekly_target")
        case .weather: localizedString("weather")
        case .insights: localizedString("smart_weather_insights")
        case .continuity: localizedString("consistency")
        case .recommendedWorkout: localizedString("recommended_workout_title")
        case .progression: localizedString("progression")
        case .signals: localizedString("today_signals")
        case .wellness: localizedString("recovery_2")
        case .plan: localizedString("plan_3")
        case .shortcuts: localizedString("shortcuts")
        }
    }

    var systemImage: String {
        switch self {
        case .hero: "bolt.fill"
        case .greeting: "sun.max.fill"
        case .weeklyProgress: "chart.bar.fill"
        case .weather: "cloud.sun.fill"
        case .insights: "sparkles"
        case .continuity: "flame.fill"
        case .recommendedWorkout: "wand.and.stars"
        case .progression: "arrow.up.right.circle.fill"
        case .signals: "gauge.with.dots.needle.67percent"
        case .wellness: "heart.text.square.fill"
        case .plan: "bolt.fill"
        case .shortcuts: "square.grid.2x2.fill"
        }
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    var onSelectTab: ((AppTab) -> Void)? = nil

    var body: some View {
        let model = makeTodayRenderModel()
        TodayViewContent(model: model, store: store, onSelectTab: onSelectTab)
    }

    private var todaysScheduledWorkout: ScheduledWorkout? {
        store.scheduledWorkouts.first { Calendar.current.isDateInToday($0.date) && $0.status != .skipped }
    }

    private func completedSets(in sessions: [WorkoutSession]) -> [SetLog] {
        sessions.flatMap { session in
            if let exerciseLogs = session.exerciseLogs, !exerciseLogs.isEmpty {
                return exerciseLogs.flatMap { $0.sets.filter(\.completed) }
            }
            return session.sets.filter(\.completed)
        }
    }

    private static func trendText(current: Double, previous: Double) -> String? {
        guard previous > 0 else {
            return current > 0 ? "+100%" : nil
        }

        let percentage = ((current - previous) / previous) * 100
        guard abs(percentage) >= 1 else {
            return nil
        }
        return String(format: "%+.0f%%", percentage)
    }

    private static func continuitySignal(for lastWorkout: WorkoutSession?, calendar: Calendar, now: Date) -> ContinuitySignal {
        if let lastWorkout {
            let daysSince = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastWorkout.date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            if daysSince == 0 {
                return ContinuitySignal(
                    title: localizedString("today_continuity_secured_title"),
                    message: localizedString("today_continuity_secured_message"),
                    systemImage: "checkmark.seal.fill",
                    tint: PulseTheme.recovery
                )
            }
            if daysSince == 1 {
                return ContinuitySignal(
                    title: localizedString("today_continuity_keep_going_title"),
                    message: localizedString("today_continuity_keep_going_message"),
                    systemImage: "flame.fill",
                    tint: PulseTheme.accent
                )
            }
            return ContinuitySignal(
                title: localizedString("today_continuity_recover_title"),
                message: localizedFormat("today_continuity_recover_message_format", daysSince),
                systemImage: "arrow.counterclockwise.circle.fill",
                tint: PulseTheme.warning
            )
        }

        return ContinuitySignal(
            title: localizedString("today_continuity_first_step_title"),
            message: localizedString("today_continuity_first_step_message"),
            systemImage: "figure.strengthtraining.traditional",
            tint: PulseTheme.accent
        )
    }

    private func hydratedExercise(_ exercise: Exercise, catalog: [Exercise]) -> Exercise {
        if exercise.customImageData != nil || (exercise.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) {
            return exercise
        }

        return catalog.first { candidate in
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

    private func makeTodayRenderModel() -> TodayRenderModel {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now.addingTimeInterval(-604_800)
        let todayStart = calendar.startOfDay(for: now)
        let last30StartDate = calendar.date(byAdding: .day, value: -29, to: todayStart) ?? todayStart
        let previous30StartDate = calendar.date(byAdding: .day, value: -30, to: last30StartDate) ?? last30StartDate
        let hasActivePlan = store.hasActiveTrainingPlan
        let language = store.userProfile.preferredLanguage
        let units = store.userProfile.units

        let weekSessions = store.workoutSessions.filter { $0.date >= weekStart }
        let recentSessions = store.workoutSessions.filter { $0.date >= last30StartDate }
        let previous30Sessions = store.workoutSessions.filter { $0.date >= previous30StartDate && $0.date < last30StartDate }
        let latestWorkout = store.workoutSessions.max { $0.date < $1.date }
        let latestMetric = store.bodyMetrics.max { $0.date < $1.date }
        let sortedHealthMetrics = store.health.latestDailyMetrics.sorted { $0.date > $1.date }
        let battery = store.trainingBattery
        let completedThisWeek = hasActivePlan ? min(weekSessions.count, store.activePlan.daysPerWeek) : weekSessions.count
        let weekTargetText = hasActivePlan ? "\(completedThisWeek)/\(store.activePlan.daysPerWeek)" : "\(completedThisWeek)"
        let weeklyPlanCompletionRatio = hasActivePlan && store.activePlan.daysPerWeek > 0
            ? min(Double(completedThisWeek) / Double(store.activePlan.daysPerWeek), 1)
            : 0

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: language)
        dateFormatter.dateFormat = localizedString("eeee_d_mmmm")
        let currentDateTitle = dateFormatter.string(from: now).capitalized(with: dateFormatter.locale)

        let recentVolumeKg = FitnessMetrics.totalVolumeKg(for: recentSessions)
        let previous30VolumeKg = FitnessMetrics.totalVolumeKg(for: previous30Sessions)
        let weekCompletedSets = completedSets(in: weekSessions)
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previousWeekSessions = store.workoutSessions.filter { $0.date >= previousWeekStart && $0.date < weekStart }
        let previousReps = completedSets(in: previousWeekSessions).reduce(0) { $0 + $1.reps }
        let currentWeekReps = weekCompletedSets.reduce(0) { $0 + $1.reps }

        let loadByDay = Dictionary(grouping: recentSessions, by: { calendar.startOfDay(for: $0.date) })
            .mapValues { sessions in
                sessions.reduce(0.0) { $0 + AnalyticsEngine.sessionLoad(for: $1) }
            }
        let maxDailyLoad = loadByDay.values.max() ?? 0
        let recentActivityPoints = (0..<30).compactMap { offset -> DailyActivityPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset - 29, to: todayStart) else { return nil }
            let dailyLoad = loadByDay[date] ?? 0
            return DailyActivityPoint(
                date: date,
                isCompleted: dailyLoad > 0,
                isToday: calendar.isDateInToday(date),
                intensity: maxDailyLoad > 0 ? min(dailyLoad / maxDailyLoad, 1) : 0
            )
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: language)
        dayFormatter.dateFormat = "EEEEE"
        func displayWeight(_ kilograms: Double) -> Double {
            units == .metric ? kilograms : UnitConverter.pounds(fromKilograms: kilograms)
        }
        func sets(in session: WorkoutSession) -> [SetLog] {
            if let exerciseLogs = session.exerciseLogs, !exerciseLogs.isEmpty {
                return exerciseLogs.flatMap { $0.sets.filter(\.completed) }
            }
            return session.sets.filter(\.completed)
        }
        func weeklyPoints(_ valueForSession: (WorkoutSession) -> Double) -> [MiniBarPoint] {
            (0..<7).compactMap { offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
                let daySessions = weekSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
                return MiniBarPoint(
                    id: date,
                    label: dayFormatter.string(from: date).uppercased(),
                    value: daySessions.reduce(0) { $0 + valueForSession($1) },
                    isToday: calendar.isDateInToday(date)
                )
            }
        }
        let weeklyRepsPoints = weeklyPoints { Double(sets(in: $0).reduce(0) { $0 + $1.reps }) }
        let weeklyVolumePoints = weeklyPoints { displayWeight(FitnessMetrics.totalVolumeKg(for: [$0])) }

        let competitiveSummary = AnalyticsEngine.competitiveSummary(
            sessions: store.workoutSessions,
            activePlan: store.activePlan,
            exercises: store.exercises,
            since: weekStart
        )
        let workloadSummary = AnalyticsEngine.workloadSummary(sessions: store.workoutSessions, bodyMetrics: store.bodyMetrics)
        let todaysScheduledWorkout = store.scheduledWorkouts.first {
            Calendar.current.isDateInToday($0.date) && $0.status != .skipped
        }
        let dailyCoachRecommendation = FitnessMetrics.dailyCoachRecommendation(
            battery: battery,
            competitiveSummary: competitiveSummary,
            hasActivePlan: hasActivePlan,
            hasTodayWorkout: todaysScheduledWorkout != nil,
            hasCompletedWorkout: !store.workoutSessions.isEmpty
        )

        // ── Focus Workout ──────────────────────────────────────────────────
        let focusWorkout: WorkoutDay = todaysScheduledWorkout?.workoutDay ?? store.todaysWorkout
        let focusWorkoutTitle = focusWorkout.title
        let focusWorkoutAlreadyCompletedToday: Bool = {
            if todaysScheduledWorkout?.status == .completed { return true }
            return store.workoutSessions.contains {
                Calendar.current.isDateInToday($0.date) && $0.workoutTitle == focusWorkoutTitle
            }
        }()
        let nextScheduledWorkout = store.scheduledWorkouts
            .filter { $0.date >= Calendar.current.startOfDay(for: now) && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .first

        let catalog = store.exercises
        let withImages = catalog.filter { ($0.mediaURL ?? "").isEmpty == false }
        let featuredExercises = Array((withImages.isEmpty ? catalog : withImages).prefix(8))
        let planned = focusWorkout.exercises.map(\.exercise)
        let focusPreviewExercises = Array((planned.isEmpty ? featuredExercises : planned).prefix(3))
        let focusMediaExercises = focusWorkout.exercises.map { hydratedExercise($0.exercise, catalog: catalog) }
        let focusProgressionRecommendations = SmartProgressionAdvisor.recommendations(
            for: focusWorkout,
            sessions: store.workoutSessions,
            weightIncrementKg: store.userProfile.weightIncrementKg,
            limit: 3
        )

        // ── Greeting ──────────────────────────────────────────────────────────
        let isSpanish = language == "es"
        let hour = Calendar.current.component(.hour, from: now)
        let greeting: String
        if isSpanish {
            switch hour {
            case 5..<12: greeting = "Buenos d\u{ED}as"
            case 12..<20: greeting = "Buenas tardes"
            default: greeting = "Buenas noches"
            }
        } else {
            switch hour {
            case 5..<12: greeting = "Good morning"
            case 12..<20: greeting = "Good afternoon"
            default: greeting = "Good evening"
            }
        }
        let greetingHeadline: String
        if let alias = store.userProfile.resolvedAlias {
            greetingHeadline = "\(greeting), \(alias)"
        } else {
            greetingHeadline = greeting
        }

        let latestSleepHours: Double? = store.todayHealthMetric?.sleepHours
            ?? sortedHealthMetrics.first(where: { ($0.sleepHours ?? 0) > 0 })?.sleepHours
            ?? latestMetric?.sleepHours
        let latestHRV: Double? = store.todayHealthMetric?.heartRateVariabilityMS
            ?? sortedHealthMetrics.first(where: { $0.heartRateVariabilityMS != nil })?.heartRateVariabilityMS
        let latestRestingHeartRate: Double? = store.todayHealthMetric?.restingHeartRate
            ?? sortedHealthMetrics.first(where: { $0.restingHeartRate != nil })?.restingHeartRate

        let weeklyPlanSummaryTint: Color
        switch weeklyPlanCompletionRatio {
        case 1...: weeklyPlanSummaryTint = PulseTheme.recovery
        case 0.5..<1: weeklyPlanSummaryTint = PulseTheme.warning
        default: weeklyPlanSummaryTint = PulseTheme.destructive
        }

        let stressText: String = {
            guard let stress = latestMetric?.stress else {
                return isSpanish ? "sin registro de estr\u{E9}s" : "stress not logged"
            }
            switch stress {
            case 1...2: return isSpanish ? "estr\u{E9}s bajo" : "low stress"
            case 3: return isSpanish ? "estr\u{E9}s estable" : "steady stress"
            default: return isSpanish ? "estr\u{E9}s alto" : "high stress"
            }
        }()

        var greetingTokens: [GreetingFlowToken] = []
        func gWords(_ phrase: String) {
            for word in phrase.split(separator: " ") {
                greetingTokens.append(GreetingFlowToken(kind: .word(String(word))))
            }
        }
        func gPill(_ icon: String, _ value: String, _ tint: Color, _ dest: GreetingMetricDestination) {
            greetingTokens.append(GreetingFlowToken(kind: .pill(icon: icon, value: value, tint: tint, destination: dest)))
        }
        func gHighlight(_ value: String, _ tint: Color) {
            greetingTokens.append(GreetingFlowToken(kind: .highlight(value: value, tint: tint)))
        }
        if isSpanish {
            gWords("Descansaste")
            if let s = latestSleepHours { gPill(TrackedMetric.sleep.systemImage, String(format: "%.1f h", s), TrackedMetric.sleep.tint, .sleep) } else { gWords("sin registro") }
            gWords("\u{B7} HRV")
            if let h = latestHRV { gPill(TrackedMetric.hrv.systemImage, "\(Int(h.rounded())) ms", TrackedMetric.hrv.tint, .hrv) } else { gWords("pendiente") }
            gWords("\u{B7} FC reposo")
            if let r = latestRestingHeartRate { gPill(TrackedMetric.restingHeartRate.systemImage, "\(Int(r.rounded())) lpm", TrackedMetric.restingHeartRate.tint, .heartRate) } else { gWords("sin datos") }
            gWords("\u{B7} Recuperaci\u{F3}n")
            gPill(TrackedMetric.readiness.systemImage, "\(battery.level)%", TrackedMetric.readiness.tint, .recovery)
            gWords("\u{B7} \(stressText) \u{B7}")
            if hasActivePlan { gWords("tu plan pide"); gHighlight(weekTargetText, weeklyPlanSummaryTint); gWords("sesiones esta semana.") } else { gWords("a\u{FA}n no tienes plan activo.") }
        } else {
            gWords("You slept")
            if let s = latestSleepHours { gPill(TrackedMetric.sleep.systemImage, String(format: "%.1f h", s), TrackedMetric.sleep.tint, .sleep) } else { gWords("no data") }
            gWords("\u{B7} HRV")
            if let h = latestHRV { gPill(TrackedMetric.hrv.systemImage, "\(Int(h.rounded())) ms", TrackedMetric.hrv.tint, .hrv) } else { gWords("pending") }
            gWords("\u{B7} resting HR")
            if let r = latestRestingHeartRate { gPill(TrackedMetric.restingHeartRate.systemImage, "\(Int(r.rounded())) bpm", TrackedMetric.restingHeartRate.tint, .heartRate) } else { gWords("unavailable") }
            gWords("\u{B7} recovery")
            gPill(TrackedMetric.readiness.systemImage, "\(battery.level)%", TrackedMetric.readiness.tint, .recovery)
            gWords("\u{B7} \(stressText) \u{B7}")
            if hasActivePlan { gWords("your plan calls for"); gHighlight(weekTargetText, weeklyPlanSummaryTint); gWords("sessions this week.") } else { gWords("no active plan yet.") }
        }

        // ── Weather ───────────────────────────────────────────────────────────
        let todayWeather = FitnessWeatherSnapshot.trainingDayPreview(now: now, units: units)
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86_400)
        let tomorrowWeather = FitnessWeatherSnapshot.trainingDayPreview(now: tomorrowDate, units: units)
        let weatherInsights = FitnessWeatherInsight.make(
            today: todayWeather,
            tomorrow: tomorrowWeather,
            battery: battery,
            hasActivePlan: hasActivePlan,
            trainingLocation: store.userProfile.trainingLocation,
            now: now
        )

        return TodayRenderModel(
            weekStart: weekStart,
            last30StartDate: last30StartDate,
            weekSessions: weekSessions,
            recentSessions: recentSessions,
            previous30Sessions: previous30Sessions,
            completedThisWeek: completedThisWeek,
            weekTargetText: weekTargetText,
            weeklyPlanCompletionRatio: weeklyPlanCompletionRatio,
            streakDays: store.streakDays,
            lastWorkout: latestWorkout,
            continuitySignal: Self.continuitySignal(for: latestWorkout, calendar: calendar, now: now),
            latestMetric: latestMetric,
            batteryStatus: battery,
            hasActivePlan: hasActivePlan,
            units: units,
            focusWorkout: focusWorkout,
            focusWorkoutAlreadyCompletedToday: focusWorkoutAlreadyCompletedToday,
            todaysScheduledWorkout: todaysScheduledWorkout,
            nextScheduledWorkout: nextScheduledWorkout,
            focusPreviewExercises: focusPreviewExercises,
            focusMediaExercises: focusMediaExercises,
            focusProgressionRecommendations: focusProgressionRecommendations,
            competitiveSummary: competitiveSummary,
            workloadSummary: workloadSummary,
            dailyCoachRecommendation: dailyCoachRecommendation,
            currentDateTitle: currentDateTitle,
            recentCompletedSets: completedSets(in: recentSessions),
            weekCompletedSets: weekCompletedSets,
            recentVolumeKg: recentVolumeKg,
            previous30VolumeKg: previous30VolumeKg,
            displayedRecentVolume: displayWeight(recentVolumeKg),
            recentActivityPoints: recentActivityPoints,
            weeklyRepsPoints: weeklyRepsPoints,
            weeklyVolumePoints: weeklyVolumePoints,
            weeklyVolumeValues: weeklyVolumePoints.map(\.value),
            workoutTrendText: Self.trendText(current: Double(recentSessions.count), previous: Double(previous30Sessions.count)),
            volumeTrendText: Self.trendText(current: recentVolumeKg, previous: previous30VolumeKg),
            weekRepsTrendText: Self.trendText(current: Double(currentWeekReps), previous: Double(previousReps)),
            latestSleepHours: latestSleepHours,
            latestHRV: latestHRV,
            latestRestingHeartRate: latestRestingHeartRate,
            latestVO2Max: sortedHealthMetrics.first(where: { $0.vo2MaxMlKgMin != nil })?.vo2MaxMlKgMin,
            latestRecordedSleepHours: sortedHealthMetrics.first(where: { ($0.sleepHours ?? 0) > 0 })?.sleepHours,
            greetingHeadline: greetingHeadline,
            naturalGreetingTokens: greetingTokens,
            todayWeather: todayWeather,
            tomorrowWeather: tomorrowWeather,
            weatherInsights: weatherInsights
        )
    }
}

private struct TodayViewContent: View {
    let model: TodayRenderModel
    let store: AppStore
    var onSelectTab: ((AppTab) -> Void)? = nil

    @State private var showScheduleWorkout = false
    @State private var showCreatePlan = false
    @State private var showProfile = false
    @State private var showFreeWorkoutStart = false
    @State private var planToEdit: WorkoutPlan?
    @State private var workoutToStart: WorkoutDay?
    @State private var showWeatherDetail = false
    @State private var homeWeatherDay: FitnessWeatherDay = .today
    @State private var isOutdoorInsightsExpanded = true
    @State private var showNotifications = false
    @State private var recommendedWorkout: WorkoutDay? = nil
    @State private var recommendedWorkoutToConfirm: WorkoutDay?
    @State private var showRestartConfirmation = false
    @State private var showEditLayout = false
    @Namespace private var wellnessZoom

    private var freeWorkout: WorkoutDay {
        WorkoutDay.freeWorkout
    }

    private var focusWorkout: WorkoutDay {
        model.focusWorkout
    }

    private var focusWorkoutAlreadyCompletedToday: Bool {
        model.focusWorkoutAlreadyCompletedToday
    }

    private func startFocusWorkout() {
        guard focusWorkoutAlreadyCompletedToday else {
            workoutToStart = focusWorkout
            return
        }
        showRestartConfirmation = true
    }

    private var weekStart: Date { model.weekStart }
    private var weekSessions: [WorkoutSession] { model.weekSessions }
    private var completedThisWeek: Int { model.completedThisWeek }
    private var weekTargetText: String { model.weekTargetText }
    private var weeklyPlanCompletionRatio: Double { model.weeklyPlanCompletionRatio }
    private var weeklyPlanSummaryTint: Color {
        switch weeklyPlanCompletionRatio {
        case 1...:
            return PulseTheme.recovery
        case 0.5..<1:
            return PulseTheme.warning
        default:
            return PulseTheme.destructive
        }
    }
    private var streakDays: Int { model.streakDays }
    private var lastWorkout: WorkoutSession? { model.lastWorkout }
    private var continuitySignal: ContinuitySignal { model.continuitySignal }
    private var latestMetric: BodyMetric? { model.latestMetric }
    private var batteryStatus: FitnessMetrics.TrainingBatteryStatus { model.batteryStatus }
    private var batteryColor: Color {
        switch batteryStatus.state {
        case .charged: return PulseTheme.recovery
        case .steady: return PulseTheme.accent
        case .low: return PulseTheme.warning
        case .critical: return PulseTheme.destructive
        }
    }
    private var nextScheduledWorkout: ScheduledWorkout? { model.nextScheduledWorkout }
    private var focusPreviewExercises: [Exercise] { model.focusPreviewExercises }
    private var focusMediaExercises: [Exercise] { model.focusMediaExercises }
    private var focusProgressionRecommendations: [SmartProgressionAdvisor.Recommendation] { model.focusProgressionRecommendations }
    private var competitiveSummary: AnalyticsEngine.CompetitiveSummary { model.competitiveSummary }
    private var workloadSummary: AnalyticsEngine.WorkloadSummary { model.workloadSummary }
    private var dailyCoachRecommendation: FitnessMetrics.DailyCoachRecommendation { model.dailyCoachRecommendation }
    private var hasActivePlan: Bool { model.hasActivePlan }
    private var currentDateTitle: String { model.currentDateTitle }
    private var last30StartDate: Date { model.last30StartDate }
    private var recentSessions: [WorkoutSession] { model.recentSessions }
    private var previous30Sessions: [WorkoutSession] { model.previous30Sessions }
    private var recentCompletedSets: [SetLog] { model.recentCompletedSets }
    private var weekCompletedSets: [SetLog] { model.weekCompletedSets }
    private var recentVolumeKg: Double { model.recentVolumeKg }
    private var previous30VolumeKg: Double { model.previous30VolumeKg }
    private var displayedRecentVolume: Double { model.displayedRecentVolume }
    private var displayedVolumeUnit: String {
        model.units == .metric ? "kg" : "lb"
    }
    private var recentActivityPoints: [DailyActivityPoint] { model.recentActivityPoints }
    private var weeklyRepsPoints: [MiniBarPoint] { model.weeklyRepsPoints }
    private var weeklyVolumePoints: [MiniBarPoint] { model.weeklyVolumePoints }
    private var weeklyVolumeValues: [Double] { model.weeklyVolumeValues }
    private var workoutTrendText: String? { model.workoutTrendText }
    private var volumeTrendText: String? { model.volumeTrendText }
    private var weekRepsTrendText: String? { model.weekRepsTrendText }
    private var latestSleepHours: Double? { model.latestSleepHours }
    private var latestHRV: Double? { model.latestHRV }
    private var latestRestingHeartRate: Double? { model.latestRestingHeartRate }
    private var greetingHeadline: String { model.greetingHeadline }
    private var naturalGreetingTokens: [GreetingFlowToken] { model.naturalGreetingTokens }
    private var todayWeather: FitnessWeatherSnapshot { model.todayWeather }
    private var tomorrowWeather: FitnessWeatherSnapshot { model.tomorrowWeather }
    private var weatherInsights: [FitnessWeatherInsight] { model.weatherInsights }
    private var todaysScheduledWorkout: ScheduledWorkout? { model.todaysScheduledWorkout }

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
        let undertrainedMuscles = competitiveSummary.undertrainedMuscles.map(\.muscleGroup)
        let bodyMetric = store.bodyMetrics.sorted { $0.date > $1.date }.first ?? BodyMetric(date: .now, weightKg: 70, heightCm: 170, source: .manual)
        recommendedWorkout = OnboardingPlanBuilder.makeRecommendedDay(
            profile: store.userProfile,
            bodyMetric: bodyMetric,
            batteryLevel: batteryStatus.level,
            undertrainedMuscles: undertrainedMuscles
        )
    }

    private func consumePendingSystemWorkoutStart() {
        guard store.pendingSystemWorkoutStart else { return }
        store.pendingSystemWorkoutStart = false

        if let activeWorkout = store.activeWorkout,
           store.activeWorkoutStatus != nil {
            workoutToStart = activeWorkout
        } else {
            workoutToStart = store.todaysWorkout
        }
    }

    var body: some View {
        NavigationStack {
            StickyHeaderScaffold(
                title: "workout",
                subtitle: currentDateTitle,
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
                if let activity = store.possibleExternalActivity,
                   store.activeWorkoutStatus == nil {
                    ExternalActivityNoticeCard(
                        snapshot: activity,
                        distanceUnit: store.userProfile.distanceUnit
                    )
                    .stickyHeaderTitle(localizedString("possible_activity_section_title"))
                }

                ForEach(resolvedTodaySections.visible) { section in
                    todaySectionView(for: section)
                }

                SecondaryButton("edit_layout", systemImage: "slider.horizontal.3") {
                    HapticService.selection()
                    showEditLayout = true
                }
            }
            .sheet(isPresented: $showEditLayout) {
                let resolved = resolvedTodaySections
                SectionLayoutEditorSheet(
                    title: localizedString("edit_layout"),
                    visible: resolved.visible,
                    hidden: resolved.hiddenAvailable
                ) { order, hiddenIDs in
                    store.userProfile.todaySectionOrder = order
                    store.userProfile.todayHiddenSectionIDs = hiddenIDs
                }
            }
            .sheet(isPresented: $showScheduleWorkout) {
                ScheduleWorkoutView()
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(item: $planToEdit) { plan in
                CreatePlanView(existingPlan: plan)
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView {
                    onSelectTab?(.today)
                }
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView()
            }
            .navigationDestination(isPresented: $showWeatherDetail) {
                TodayWeatherDetailView(
                    today: todayWeather,
                    tomorrow: tomorrowWeather,
                    insights: weatherInsights,
                    selectedDay: homeWeatherDay
                )
            }
            .navigationDestination(item: $workoutToStart) { workout in
                ActiveWorkoutView(workout: workout, origin: workout.id == freeWorkout.id ? .free : .routine)
            }
            .navigationDestination(isPresented: $showFreeWorkoutStart) {
                FreeWorkoutStartView()
            }
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .sleep:
                    SleepView()
                        .navigationTransition(.zoom(sourceID: "wellness-sleep", in: wellnessZoom))
                case .hrv:
                    HRVView()
                        .navigationTransition(.zoom(sourceID: "wellness-hrv", in: wellnessZoom))
                case .heartRate:
                    HeartRateView()
                        .navigationTransition(.zoom(sourceID: "wellness-heart-rate", in: wellnessZoom))
                case .trainingBattery:
                    TrainingBatteryView()
                        .navigationTransition(.zoom(sourceID: "wellness-battery", in: wellnessZoom))
                case .exercise:
                    ExerciseView()
                        .navigationTransition(.zoom(sourceID: "wellness-exercise", in: wellnessZoom))
                case .hydration:
                    HydrationView()
                        .navigationTransition(.zoom(sourceID: "wellness-hydration", in: wellnessZoom))
                case .vo2Max:
                    VO2MaxView()
                        .navigationTransition(.zoom(sourceID: "wellness-vo2", in: wellnessZoom))
                case .steps:
                    StepsView(initialRange: .today)
                        .navigationTransition(.zoom(sourceID: "wellness-steps", in: wellnessZoom))
                case .greetingSleep:
                    SleepView()
                        .navigationTransition(.zoom(sourceID: "greeting-sleep", in: wellnessZoom))
                case .greetingHrv:
                    HRVView()
                        .navigationTransition(.zoom(sourceID: "greeting-hrv", in: wellnessZoom))
                case .greetingHeartRate:
                    HeartRateView()
                        .navigationTransition(.zoom(sourceID: "greeting-heart-rate", in: wellnessZoom))
                case .greetingRecovery:
                    TrainingBatteryView()
                        .navigationTransition(.zoom(sourceID: "greeting-recovery", in: wellnessZoom))
                case .activeWorkout:
                    ActiveWorkoutView(workout: store.activeWorkout ?? focusWorkout)
                case .workoutDetail(let day):
                    WorkoutDetailView(workout: day)
                case .workoutLibrary:
                    WorkoutLibraryView()
                }
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
            .alert(localizedString("already_completed_today_title"), isPresented: $showRestartConfirmation) {
                Button(localizedString("cancel"), role: .cancel) {}
                Button(localizedString("start_new_session")) {
                    workoutToStart = focusWorkout
                }
            } message: {
                Text(localizedString("already_completed_today_message"))
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                buildRecommendedWorkoutIfNeeded()
                consumePendingSystemWorkoutStart()
            }
            .onChange(of: store.pendingSystemWorkoutStart) { _, shouldStart in
                guard shouldStart else { return }
                consumePendingSystemWorkoutStart()
            }
        }
    }

    @ViewBuilder
    private var focusHeroSection: some View {
        if let activeStatus = store.activeWorkoutStatus {
            activeSessionHero(activeStatus)
        } else {
            dashboardWorkoutCard
        }
    }

    // MARK: - Layout customization

    private func isTodaySectionAvailable(_ section: TodaySection) -> Bool {
        switch section {
        case .hero:
            return true
        case .greeting, .weeklyProgress, .weather, .insights, .continuity:
            return store.activeWorkoutStatus == nil
        case .recommendedWorkout:
            return store.activeWorkoutStatus == nil && recommendedWorkout != nil && !hasActivePlan
        case .progression:
            return !focusProgressionRecommendations.isEmpty
        case .signals, .wellness, .shortcuts:
            return true
        case .plan:
            return hasActivePlan
        }
    }

    private var resolvedTodaySections: (visible: [TodaySection], hiddenAvailable: [TodaySection]) {
        SectionLayoutResolver.resolve(
            storedOrder: store.userProfile.todaySectionOrder,
            storedHidden: store.userProfile.todayHiddenSectionIDs,
            available: isTodaySectionAvailable
        )
    }

    @ViewBuilder
    private func todaySectionView(for section: TodaySection) -> some View {
        switch section {
        case .hero:
            focusHeroSection
                .stickyHeaderTitle(store.activeWorkoutStatus != nil ? localizedString("in_progress_label") : section.title)
        case .greeting:
            dailyReadinessGreeting
                .stickyHeaderTitle(section.title)
        case .weeklyProgress:
            weeklyProgressHero
                .stickyHeaderTitle(section.title)
        case .weather:
            weatherSection
                .stickyHeaderTitle(section.title)
        case .insights:
            outdoorIntelligenceSection
                .stickyHeaderTitle(section.title)
        case .continuity:
            continuityCard
                .stickyHeaderTitle(section.title)
        case .recommendedWorkout:
            if let rec = recommendedWorkout {
                RecommendedWorkoutCard(
                    workout: rec,
                    batteryLevel: batteryStatus.level,
                    language: store.userProfile.preferredLanguage,
                    experience: store.userProfile.experience,
                    mainGoal: store.userProfile.mainGoal,
                    weeklyTrainingDays: store.userProfile.weeklyTrainingDays,
                    onStart: {
                        HapticService.impact(.medium)
                        recommendedWorkoutToConfirm = rec
                    }
                )
                .stickyHeaderTitle(section.title)
            }
        case .progression:
            ProgressionRecommendationCard(
                recommendations: focusProgressionRecommendations,
                language: store.userProfile.preferredLanguage,
                title: "what_to_progress_today"
            )
            .stickyHeaderTitle(section.title)
        case .signals:
            relationshipSignalBoard
                .stickyHeaderTitle(section.title)
        case .wellness:
            wellnessWidgets
                .stickyHeaderTitle(section.title)
        case .plan:
            planSection
                .stickyHeaderTitle(section.title)
        case .shortcuts:
            smartShortcuts
                .stickyHeaderTitle(section.title)
        }
    }

    // MARK: - Weekly Progress Hero

    private var weeklyProgressBarPoints: [WeeklyBarPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = "EEEEE"

        let maxVolume = (0..<7).compactMap { offset -> Double? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let daySessions = weekSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return FitnessMetrics.totalVolumeKg(for: daySessions)
        }.max() ?? 1.0

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let daySessions = weekSessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let vol = FitnessMetrics.totalVolumeKg(for: daySessions)
            return WeeklyBarPoint(
                id: date,
                dayLabel: formatter.string(from: date),
                normalizedHeight: maxVolume > 0 ? min(vol / maxVolume, 1.0) : 0,
                hasActivity: !daySessions.isEmpty,
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    @ViewBuilder
    private var weeklyProgressHero: some View {
        WeeklyProgressHeroCard(
            streakDays: streakDays,
            completedThisWeek: completedThisWeek,
            weeklyTarget: hasActivePlan ? store.activePlan.daysPerWeek : store.userProfile.weeklyTrainingDays,
            weeklyVolumeKg: FitnessMetrics.totalVolumeKg(for: weekSessions),
            weeklyVolumeUnit: displayedVolumeUnit,
            barPoints: weeklyProgressBarPoints
        )
    }

    private var dailyReadinessGreeting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(greetingHeadline)
                .font(.system(size: 29, weight: .black, design: .rounded))
                .foregroundStyle(PulseTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            GreetingFlowLayout(horizontalSpacing: 6, verticalSpacing: 8) {
                ForEach(naturalGreetingTokens) { token in
                    greetingTokenView(token)
                }
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func greetingDestinationView(for destination: GreetingMetricDestination) -> some View {
        switch destination {
        case .sleep: SleepView()
        case .hrv: HRVView()
        case .heartRate: HeartRateView()
        case .recovery: TrainingBatteryView()
        }
    }

    private func route(for greetingDestination: GreetingMetricDestination) -> TodayRoute {
        switch greetingDestination {
        case .sleep: return .greetingSleep
        case .hrv: return .greetingHrv
        case .heartRate: return .greetingHeartRate
        case .recovery: return .greetingRecovery
        }
    }

    @ViewBuilder
    private func greetingTokenView(_ token: GreetingFlowToken) -> some View {
        switch token.kind {
        case .word(let text):
            Text(text)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        case .pill(let icon, let value, let tint, let destination):
            NavigationLink(value: route(for: destination)) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(value)
                        .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.16), in: Capsule())
                .overlay {
                    Capsule().stroke(tint.opacity(0.22), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: destination.zoomID, in: wellnessZoom)
        case .highlight(let value, let tint):
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(tint.opacity(0.16), in: Capsule())
                .overlay {
                    Capsule().stroke(tint.opacity(0.24), lineWidth: 0.8)
                }
        }
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionHeader(
                systemImage: "cloud.sun.fill",
                tint: MetricDomain.weather.tint,
                titleKey: "weather",
                subtitleKey: "weather_fitness_subtitle"
            )

            Button {
                HapticService.selection()
                showWeatherDetail = true
            } label: {
                FitnessWeatherWidget(today: todayWeather, tomorrow: tomorrowWeather, selectedDay: $homeWeatherDay)
            }
            .buttonStyle(PressableCardStyle())
        }
    }



    private var outdoorIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                TodaySectionHeader(
                    systemImage: "sparkles",
                    tint: PulseTheme.accent,
                    titleKey: "smart_weather_insights",
                    subtitleKey: "smart_weather_insights_subtitle"
                )
                Spacer(minLength: 8)
                WeatherInsightsCollapseToggle(isExpanded: $isOutdoorInsightsExpanded)
            }

            WeatherInsightsPanel(insights: weatherInsights, isExpanded: $isOutdoorInsightsExpanded)
                .padding(14)
                .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .stroke(PulseTheme.cardStroke, lineWidth: 0.8)
                }
                .shadow(color: PulseTheme.surfaceShadow, radius: 7, x: 0, y: 3)
        }
    }

    private var relationshipSignalBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionHeader(
                systemImage: "gauge.with.dots.needle.67percent",
                tint: MetricDomain.strength.tint,
                titleKey: "today_signals",
                subtitleKey: "today_signals_subtitle"
            )

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                TrainingSignalTile(
                    title: localizedString("plan"),
                    value: weekTargetText,
                    subtitle: localizedString("weekly_target"),
                    systemImage: "target",
                    color: PulseTheme.accent,
                    domain: .strength
                )
                TrainingSignalTile(
                    title: localizedString("load"),
                    value: "\(Int(workloadSummary.fatigueScore.rounded()))",
                    subtitle: localizedString("fatigue"),
                    systemImage: "waveform.path.ecg",
                    color: batteryColor,
                    domain: .recovery
                )
                TrainingSignalTile(
                    title: localizedString("health"),
                    value: store.todayHealthMetric.map { "\(Int($0.steps))" } ?? "--",
                    subtitle: localizedString("steps_today"),
                    systemImage: TrackedMetric.steps.systemImage,
                    color: TrackedMetric.steps.tint,
                    domain: TrackedMetric.steps.domain
                )
                TrainingSignalTile(
                    title: localizedString("progress_2"),
                    value: "\(recentSessions.count)",
                    subtitle: localizedFormat("days_count_format", 30),
                    systemImage: "chart.line.uptrend.xyaxis",
                    color: PulseTheme.ringMove,
                    domain: .cardio
                )
            }
            .padding(14)
            .background(PulseTheme.card, in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.cardStroke, lineWidth: 0.8)
            )
            .shadow(color: PulseTheme.surfaceShadow, radius: 7, x: 0, y: 3)
        }
    }

    private var continuityCard: some View {
        Button {
            HapticService.selection()
            startFocusWorkout()
        } label: {
            PulseCard {
                HStack(spacing: 12) {
                    Image(systemName: continuitySignal.systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(continuitySignal.tint)
                        .frame(width: 42, height: 42)
                        .background(continuitySignal.tint.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(continuitySignal.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(continuitySignal.message)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 34, height: 34)
                        .background(PulseTheme.accent, in: Circle())
                }
            }
        }
        .buttonStyle(.plain)
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

                Button {
                    HapticService.selection()
                    if hasActivePlanSession {
                        startFocusWorkout()
                    } else {
                        showFreeWorkoutStart = true
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.black))
                        .frame(width: 54, height: 54)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.playControl))
                        .background(PulseTheme.playControl, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
        let language = store.userProfile.preferredLanguage
        let sessionTitle = status.sessionTitle.map { RepsText.localizedWorkoutSubtitle($0, language: language) }
        
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
                    Text(RepsText.workoutTitle(status.workoutTitle, language: language))
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
                    Text("\(planTitle)\(sessionTitle.map { " · \($0)" } ?? "")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .padding(.top, -4)
            } else if let sessionTitle {
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
                NavigationLink(value: TodayRoute.activeWorkout) {
                    Label(localizedString("return"), systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.semanticProgress))
                        .background(PulseTheme.semanticProgress)
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
                        .foregroundStyle(PulseTheme.onColor(isPaused ? PulseTheme.playControl : PulseTheme.pauseControl))
                        .background(isPaused ? PulseTheme.playControl : PulseTheme.pauseControl)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .accessibilityLabel(isPaused ? "Resume workout" : "Pause workout")

                // Stop
                Button {
                    store.finishActiveWorkoutFromSummaryCard()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.headline.weight(.bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.stopControl))
                        .background(PulseTheme.stopControl)
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
        Self.trendText(current: current, previous: previous)
    }

    private static func trendText(current: Double, previous: Double) -> String? {
        guard previous > 0 else {
            return current > 0 ? "+100%" : nil
        }

        let percentage = ((current - previous) / previous) * 100
        guard abs(percentage) >= 1 else {
            return nil
        }
        return String(format: "%+.0f%%", percentage)
    }

    private static func continuitySignal(for lastWorkout: WorkoutSession?, calendar: Calendar, now: Date) -> ContinuitySignal {
        if let lastWorkout {
            let daysSince = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastWorkout.date),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            if daysSince == 0 {
                return ContinuitySignal(
                    title: localizedString("today_continuity_secured_title"),
                    message: localizedString("today_continuity_secured_message"),
                    systemImage: "checkmark.seal.fill",
                    tint: PulseTheme.recovery
                )
            }
            if daysSince == 1 {
                return ContinuitySignal(
                    title: localizedString("today_continuity_keep_going_title"),
                    message: localizedString("today_continuity_keep_going_message"),
                    systemImage: "flame.fill",
                    tint: PulseTheme.accent
                )
            }
            return ContinuitySignal(
                title: localizedString("today_continuity_recover_title"),
                message: localizedFormat("today_continuity_recover_message_format", daysSince),
                systemImage: "arrow.counterclockwise.circle.fill",
                tint: PulseTheme.warning
            )
        }

        return ContinuitySignal(
            title: localizedString("today_continuity_first_step_title"),
            message: localizedString("today_continuity_first_step_message"),
            systemImage: "figure.strengthtraining.traditional",
            tint: PulseTheme.accent
        )
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

    private func perform(_ action: FitnessMetrics.DailyCoachRecommendation.Action) {
        HapticService.impact(.light)
        switch action {
        case .startWorkout:
            if todaysScheduledWorkout != nil || hasActivePlan {
                startFocusWorkout()
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
            TodaySectionHeader(
                systemImage: "heart.text.square.fill",
                tint: MetricDomain.recovery.tint,
                titleKey: "wellness",
                subtitleKey: "wellness_subtitle"
            )
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                NavigationLink(value: TodayRoute.trainingBattery) {
                    WellnessWidget(
                        title: "battery_2",
                        value: "\(batteryStatus.level)%",
                        subtitle: batteryStatus.suggestion,
                        localizesSubtitle: false,
                        systemImage: batteryStatus.systemImage,
                        domain: .sleep,
                        customTint: batteryColor
                    )
                    .matchedTransitionSource(id: "wellness-battery", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.exercise) {
                    WellnessWidget(
                        title: "exercise_2",
                        value: store.todayHealthMetric.map { "\(Int($0.exerciseMinutes ?? 0)) min" } ?? "--",
                        subtitle: "apple_watch_health",
                        systemImage: TrackedMetric.exerciseMinutes.systemImage,
                        domain: TrackedMetric.exerciseMinutes.domain,
                        customTint: TrackedMetric.exerciseMinutes.tint
                    )
                    .matchedTransitionSource(id: "wellness-exercise", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.hydration) {
                    WellnessWidget(
                        title: "hydration",
                        value: store.todayHealthMetric.map { String(format: "%.1f L", $0.waterLiters) } ?? "--",
                        subtitle: latestMetric?.waterLiters.map { String(format: "%.1f L en StreakRep", $0) } ?? (localizedString("no_local_log")),
                        localizesSubtitle: latestMetric?.waterLiters == nil,
                        systemImage: TrackedMetric.hydration.systemImage,
                        domain: TrackedMetric.hydration.domain,
                        customTint: TrackedMetric.hydration.tint
                    )
                    .matchedTransitionSource(id: "wellness-hydration", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.heartRate) {
                    WellnessWidget(
                        title: "heart_rate_short",
                        value: store.todayHealthMetric?.restingHeartRate.map { "\(Int($0))" } ?? "--",
                        subtitle: "lpm",
                        localizesSubtitle: false,
                        systemImage: TrackedMetric.restingHeartRate.systemImage,
                        domain: TrackedMetric.restingHeartRate.domain
                    )
                    .matchedTransitionSource(id: "wellness-heart-rate", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.hrv) {
                    WellnessWidget(
                        title: "HRV",
                        value: store.todayHealthMetric?.heartRateVariabilityMS.map { "\(Int($0)) ms" } ?? "--",
                        subtitle: store.todayHealthMetric?.restingHeartRate.map { "\(Int($0)) lpm reposo" } ?? (localizedString("no_resting_hr")),
                        localizesSubtitle: store.todayHealthMetric?.restingHeartRate == nil,
                        systemImage: TrackedMetric.hrv.systemImage,
                        domain: TrackedMetric.hrv.domain
                    )
                    .matchedTransitionSource(id: "wellness-hrv", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.vo2Max) {
                    WellnessWidget(
                        title: "VO₂ Max",
                        value: model.latestVO2Max.map { String(format: "%.1f", $0) } ?? "--",
                        subtitle: "ml/kg/min",
                        localizesSubtitle: false,
                        systemImage: TrackedMetric.vo2Max.systemImage,
                        domain: TrackedMetric.vo2Max.domain
                    )
                    .matchedTransitionSource(id: "wellness-vo2", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.sleep) {
                    WellnessWidget(
                        title: "sleep",
                        value: model.latestRecordedSleepHours.map { String(format: "%.1fh", $0) } ?? "--",
                        subtitle: localizedString("last_recorded"),
                        systemImage: TrackedMetric.sleep.systemImage,
                        domain: TrackedMetric.sleep.domain
                    )
                    .matchedTransitionSource(id: "wellness-sleep", in: wellnessZoom)
                    .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                }
                .buttonStyle(PressableCardStyle())

                NavigationLink(value: TodayRoute.steps) {
                    WellnessWidget(
                        title: "steps",
                        value: store.todayHealthMetric.map { "\(Int($0.steps))" } ?? "--",
                        subtitle: localizedFormat("goal_format", store.userProfile.dailyStepsGoal),
                        systemImage: TrackedMetric.steps.systemImage,
                        domain: TrackedMetric.steps.domain
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
        let summary = store.activePlanExecutionSummary
        let progress = summary?.planProgress ?? 0
        let tint = planTint(for: summary?.loadState)

        return PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(store.activePlan.name, systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(tint)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(tint)
                }

                ProgressView(value: progress)
                    .tint(tint)
                    .scaleEffect(x: 1, y: 1.25, anchor: .center)

                HStack(spacing: 8) {
                    PlanExecutionTile(
                        value: summary.map { "\($0.completedThisWeek)/\($0.daysPerWeek)" } ?? "0/\(store.activePlan.daysPerWeek)",
                        label: localizedString("this_week"),
                        systemImage: "calendar",
                        tint: tint
                    )
                    PlanExecutionTile(
                        value: summary.map { "\(Int(displayedWeight(fromKilograms: $0.volumeThisWeekKg).rounded()))" } ?? "0",
                        label: store.userProfile.units == .metric ? "kg" : "lb",
                        systemImage: "scalemass",
                        tint: PulseTheme.ringStand
                    )
                    PlanExecutionTile(
                        value: summary.map { "\($0.actualWeeklySets)/\(max($0.targetWeeklySets, 0))" } ?? "0/0",
                        label: localizedString("sets_3"),
                        systemImage: "checklist",
                        tint: PulseTheme.recovery
                    )
                }

                if let summary {
                    planExecutionStatus(summary)
                }

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
                            NavigationLink(value: TodayRoute.workoutDetail(day)) {
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

    private func planTint(for state: FitnessMetrics.PlanLoadState?) -> Color {
        switch state {
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

    private func planExecutionStatus(_ summary: FitnessMetrics.PlanExecutionSummary) -> some View {
        let message: String = {
            switch summary.loadState {
            case .onTrack:
                if let delta = summary.volumeDeltaVsPreviousWeek {
                    return localizedFormat("volume_vs_last_week_format", delta * 100)
                }
                return localizedString("plan_execution_on_track")
            case .behind:
                return localizedString("missing_real_stimulus_weekly_target")
            case .overreaching:
                return localizedString("high_load_prioritize_recovery")
            case .noData:
                return localizedString("complete_session_for_real_progress")
            }
        }()

        return HStack(spacing: 10) {
            Image(systemName: summary.loadState == .overreaching ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.black))
                .foregroundStyle(planTint(for: summary.loadState))
                .frame(width: 28, height: 28)
                .background(planTint(for: summary.loadState).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(PulseTheme.grouped.opacity(0.72), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
    }

    private var smartShortcuts: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionHeader(
                systemImage: "square.grid.2x2.fill",
                tint: PulseTheme.accent,
                titleKey: "smart_shortcuts",
                subtitleKey: "smart_shortcuts_subtitle"
            )
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                Button {
                    HapticService.selection()
                    onSelectTab?(.exercises)
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

                NavigationLink(value: TodayRoute.workoutLibrary) {
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

private struct TodayRenderSignature: Equatable {
    let workoutSessionCount: Int
    let latestWorkoutDate: Date?
    let bodyMetricCount: Int
    let latestBodyMetricDate: Date?
    let healthMetricCount: Int
    let latestHealthMetricDate: Date?
    let activePlanID: UUID
    let activePlanDayCount: Int
    let activePlanCurrentDayIndex: Int?
    let activePlanDaysPerWeek: Int
    let hasActivePlan: Bool
    let units: UserProfile.Units
    let preferredLanguage: String
    let trainingLocation: UserProfile.TrainingLocation
    let weightIncrementKg: Double
    let todayHealthMetric: DailyHealthMetric?
}

private struct TodayRenderModel {
    // ── Dates & Sessions ────────────────────────────────────────────────
    let weekStart: Date
    let last30StartDate: Date
    let weekSessions: [WorkoutSession]
    let recentSessions: [WorkoutSession]
    let previous30Sessions: [WorkoutSession]
    // ── Weekly Progress ─────────────────────────────────────────────────
    let completedThisWeek: Int
    let weekTargetText: String
    let weeklyPlanCompletionRatio: Double
    let streakDays: Int
    // ── Training State ──────────────────────────────────────────────────
    let lastWorkout: WorkoutSession?
    let continuitySignal: ContinuitySignal
    let latestMetric: BodyMetric?
    let batteryStatus: FitnessMetrics.TrainingBatteryStatus
    let hasActivePlan: Bool
    let units: UserProfile.Units
    // ── Focus Workout ───────────────────────────────────────────────────
    let focusWorkout: WorkoutDay
    let focusWorkoutAlreadyCompletedToday: Bool
    let todaysScheduledWorkout: ScheduledWorkout?
    let nextScheduledWorkout: ScheduledWorkout?
    let focusPreviewExercises: [Exercise]
    let focusMediaExercises: [Exercise]
    let focusProgressionRecommendations: [SmartProgressionAdvisor.Recommendation]
    // ── Analytics ───────────────────────────────────────────────────────
    let competitiveSummary: AnalyticsEngine.CompetitiveSummary
    let workloadSummary: AnalyticsEngine.WorkloadSummary
    let dailyCoachRecommendation: FitnessMetrics.DailyCoachRecommendation
    // ── UI Labels ───────────────────────────────────────────────────────
    let currentDateTitle: String
    // ── Volume & Sets ───────────────────────────────────────────────────
    let recentCompletedSets: [SetLog]
    let weekCompletedSets: [SetLog]
    let recentVolumeKg: Double
    let previous30VolumeKg: Double
    let displayedRecentVolume: Double
    // ── Chart Data ──────────────────────────────────────────────────────
    let recentActivityPoints: [DailyActivityPoint]
    let weeklyRepsPoints: [MiniBarPoint]
    let weeklyVolumePoints: [MiniBarPoint]
    let weeklyVolumeValues: [Double]
    // ── Trend Strings ───────────────────────────────────────────────────
    let workoutTrendText: String?
    let volumeTrendText: String?
    let weekRepsTrendText: String?
    // ── Health Metrics ──────────────────────────────────────────────────
    let latestSleepHours: Double?
    let latestHRV: Double?
    let latestRestingHeartRate: Double?
    let latestVO2Max: Double?
    let latestRecordedSleepHours: Double?
    // ── Greeting ────────────────────────────────────────────────────────
    let greetingHeadline: String
    let naturalGreetingTokens: [GreetingFlowToken]
    // ── Weather ─────────────────────────────────────────────────────────
    let todayWeather: FitnessWeatherSnapshot
    let tomorrowWeather: FitnessWeatherSnapshot
    let weatherInsights: [FitnessWeatherInsight]
}

/// Consistent icon + title/subtitle header used above the Today tab's top-level sections.
private struct TodaySectionHeader: View {
    let systemImage: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString(titleKey))
                    .font(.headline.weight(.black))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(localizedString(subtitleKey))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// Read-only notice for strong HealthKit signals that may belong to a workout
/// being recorded by another app. It intentionally offers no session controls.
private struct ExternalActivityNoticeCard: View {
    let snapshot: ExternalActivitySnapshot
    let distanceUnit: UserProfile.DistanceUnit

    private var tint: Color { MetricDomain.cardio.tint }

    private var sourceDescription: String {
        if let sourceName = snapshot.verifiedSourceName {
            return localizedFormat("possible_activity_source_format", sourceName)
        }
        return localizedString("possible_activity_question")
    }

    private var displayedDistance: (value: String, unit: String)? {
        guard let distanceKm = snapshot.distanceKm, distanceKm > 0 else { return nil }
        switch distanceUnit {
        case .kilometers:
            return (String(format: "%.2f", distanceKm), "km")
        case .miles:
            return (String(format: "%.2f", distanceKm / 1.609_344), "mi")
        }
    }

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.14))
                        Image(systemName: "figure.walk.motion")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localizedString("possible_activity_section_title"))
                            .font(.caption2.weight(.black))
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(tint)
                        Text(localizedString("possible_activity_title"))
                            .font(.title3.weight(.black))
                            .foregroundStyle(PulseTheme.textPrimary)
                        Text(sourceDescription)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: snapshot.confidence == .strong ? "checkmark.shield.fill" : "waveform.path.ecg")
                        .font(.title3)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }

                Text(localizedString("possible_activity_import_notice"))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ExternalActivityMetric(
                        value: snapshot.estimatedStartDate,
                        labelKey: "possible_activity_duration",
                        systemImage: "timer"
                    )

                    if let heartRate = snapshot.latestHeartRate {
                        ExternalActivityMetric(
                            value: "\(Int(heartRate.rounded()))",
                            unit: "bpm",
                            labelKey: "possible_activity_heart_rate",
                            systemImage: "heart.fill"
                        )
                    }

                    if let activeEnergy = snapshot.activeEnergyKcal, activeEnergy > 0 {
                        ExternalActivityMetric(
                            value: "\(Int(activeEnergy.rounded()))",
                            unit: "kcal",
                            labelKey: "possible_activity_energy",
                            systemImage: "flame.fill"
                        )
                    }

                    if let displayedDistance {
                        ExternalActivityMetric(
                            value: displayedDistance.value,
                            unit: displayedDistance.unit,
                            labelKey: "possible_activity_distance",
                            systemImage: "location.fill"
                        )
                    }
                }

                Label(localizedString("possible_activity_estimates_note"), systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.tertiaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedString("possible_activity_title"))
        .accessibilityValue("\(sourceDescription). \(localizedString("possible_activity_import_notice"))")
    }
}

private struct ExternalActivityMetric: View {
    private enum MetricValue {
        case text(String)
        case timer(Date)
    }

    private let value: MetricValue
    private let unit: String?
    private let labelKey: String
    private let systemImage: String

    init(value: String, unit: String? = nil, labelKey: String, systemImage: String) {
        self.value = .text(value)
        self.unit = unit
        self.labelKey = labelKey
        self.systemImage = systemImage
    }

    init(value: Date, labelKey: String, systemImage: String) {
        self.value = .timer(value)
        self.unit = nil
        self.labelKey = labelKey
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                switch value {
                case .text(let text):
                    Text(text)
                case .timer(let startDate):
                    Text(startDate, style: .timer)
                }
                if let unit {
                    Text(unit)
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.callout.weight(.black).monospacedDigit())
            .foregroundStyle(PulseTheme.textPrimary)

            Text(localizedString(labelKey))
                .font(.caption2)
                .foregroundStyle(PulseTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(localizedKey(label))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

private enum GreetingMetricDestination {
    case sleep, hrv, heartRate, recovery

    var zoomID: String {
        switch self {
        case .sleep: return "greeting-sleep"
        case .hrv: return "greeting-hrv"
        case .heartRate: return "greeting-heart-rate"
        case .recovery: return "greeting-recovery"
        }
    }
}

private struct GreetingFlowToken: Identifiable {
    enum Kind {
        case word(String)
        case pill(icon: String, value: String, tint: Color, destination: GreetingMetricDestination)
        case highlight(value: String, tint: Color)
    }

    let kind: Kind

    /// Deterministic ID derived from content so SwiftUI can diff tokens
    /// without destroying and recreating views on every store update.
    var id: String {
        switch kind {
        case .word(let text): return "w-\(text)"
        case .pill(_, let value, _, let dest): return "p-\(dest.zoomID)-\(value)"
        case .highlight(let value, _): return "h-\(value)"
        }
    }
}

/// Wraps mixed-width children (plain words and metric pills) left to right,
/// overflowing to a new line like natural paragraph text, so inline data
/// pills can sit inside a flowing sentence instead of a separate stat row.
private struct GreetingFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                width = max(width, x - horizontalSpacing)
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
        width = max(width, x - horizontalSpacing)
        return CGSize(width: min(width, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
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
    var customTint: Color? = nil

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
                        PulseIconBadge(systemImage: systemImage, tint: hasData ? (customTint ?? domain.tint) : PulseTheme.semanticNeutral, size: 30, radius: PulseTheme.smallRadius)
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

private struct PlanExecutionTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.grouped.opacity(0.72), in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
        .accessibilityElement(children: .combine)
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
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.playControl))
                    .frame(width: 24, height: 24)
                    .background(PulseTheme.playControl)
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
                    .foregroundStyle(PulseTheme.onColor(trackingIcon == "play.fill" ? PulseTheme.playControl : PulseTheme.accent))
                    .frame(width: 22, height: 22)
                    .background(trackingIcon == "play.fill" ? PulseTheme.playControl : PulseTheme.accent)
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
            if valueString.contains("%") {
                BatteryLevelVisual(level: Int(valueString.filter("0123456789".contains)) ?? 80)
            } else {
                switch domain {
                case .recovery:
                    HeartbeatWaveVisual(color: domain.tint)
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

private enum FitnessWeatherDay: String, CaseIterable, Identifiable {
    case today
    case tomorrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: localizedString("today_2")
        case .tomorrow: localizedString("tomorrow")
        }
    }
}

private struct FitnessWeatherHourPoint: Identifiable, Hashable {
    let hour: Int
    let temperature: Int
    let windSpeed: Int
    let rainProbability: Int
    let uvIndex: Int

    /// Stable identity: hour is unique within a forecast snapshot.
    var id: Int { hour }

    var label: String {
        String(format: "%02d", hour)
    }
}

private struct FitnessWeatherWindow: Hashable {
    let title: String
    let subtitle: String
    let systemImage: String
    /// Hour (0-23) this window closes, used to detect a "today" window that has already elapsed.
    let endHour: Int
}

private struct FitnessWeatherSnapshot: Identifiable, Hashable {
    let date: Date
    let locationName: String
    let conditionTitle: String
    let conditionMessage: String
    let systemImage: String
    let temperatureUnit: String
    let speedUnit: String
    let currentTemperature: Int
    let highTemperature: Int
    let lowTemperature: Int
    let rainProbability: Int
    let humidity: Int
    let windSpeed: Int
    let windGusts: Int
    let uvIndex: Int
    let sunrise: String
    let sunset: String
    let hourly: [FitnessWeatherHourPoint]
    let bestWindow: FitnessWeatherWindow

    /// Stable identity keyed on calendar day so the weather card
    /// is not recreated when unrelated store updates happen.
    var id: Date { date }

    static func trainingDayPreview(now: Date, units: UserProfile.Units) -> FitnessWeatherSnapshot {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: now)
        let dayOffset = calendar.isDateInTomorrow(now) ? 1 : 0
        let isImperial = units == .imperial
        let celsius = [22, 21, 20, 21, 25, 30, 33 - dayOffset, 30 - dayOffset]
        let windKmh = [5, 5, 4, 5, 8, 12, 14, 9]
        let rain = [0, 0, 0, 0, 0, 0, 2 + dayOffset, 0]
        let uv = [0, 0, 1, 4, 8, 7, 3, 0]
        let hours = [0, 3, 6, 9, 12, 15, 18, 21]
        let hourNow = calendar.component(.hour, from: now)
        let closestIndex = hours.enumerated().min { lhs, rhs in
            abs(lhs.element - hourNow) < abs(rhs.element - hourNow)
        }?.offset ?? 2

        func temp(_ value: Int) -> Int {
            isImperial ? Int((Double(value) * 9 / 5 + 32).rounded()) : value
        }

        func speed(_ value: Int) -> Int {
            isImperial ? Int((Double(value) * 0.621_371).rounded()) : value
        }

        let hourly = zip(hours.indices, hours).map { index, hour in
            FitnessWeatherHourPoint(
                hour: hour,
                temperature: temp(celsius[index]),
                windSpeed: speed(windKmh[index]),
                rainProbability: rain[index],
                uvIndex: uv[index]
            )
        }

        let highCelsius = celsius.max() ?? 30
        let conditionTitle = highCelsius >= 32 ? localizedString("sunny_hot") : localizedString("moderate_clouds")
        let conditionMessage = highCelsius >= 32
            ? localizedString("sunny_hot_message")
            : localizedString("moderate_clouds_message")
        let dayTitle = dayOffset == 0 ? localizedString("today_2") : localizedString("tomorrow")
        let windowEndHour = dayOffset == 0 ? 9 : 10
        let windowTitle = "\(dayTitle), \(dayOffset == 0 ? "07:00 - 09:00" : "08:00 - 10:00")"
        let windowRain = "\(rain.max() ?? 0)"
        let windowSpeed = "\(speed(5)) \(isImperial ? "mph" : "km/h")"

        return FitnessWeatherSnapshot(
            date: dayStart,
            locationName: localizedString("your_area"),
            conditionTitle: conditionTitle,
            conditionMessage: conditionMessage,
            systemImage: highCelsius >= 32 ? "sun.max.fill" : "cloud.sun.fill",
            temperatureUnit: isImperial ? "°F" : "°C",
            speedUnit: isImperial ? "mph" : "km/h",
            currentTemperature: temp(celsius[closestIndex]),
            highTemperature: temp(highCelsius),
            lowTemperature: temp(celsius.min() ?? 20),
            rainProbability: rain.max() ?? 0,
            humidity: dayOffset == 0 ? 58 : 55,
            windSpeed: speed(windKmh[closestIndex]),
            windGusts: speed(32 + dayOffset * 4),
            uvIndex: uv.max() ?? 0,
            sunrise: dayOffset == 0 ? "06:41" : "06:42",
            sunset: dayOffset == 0 ? "21:31" : "21:30",
            hourly: hourly,
            bestWindow: FitnessWeatherWindow(
                title: windowTitle,
                subtitle: localizedFormat("light_rain_wind_window_subtitle_format", "\(temp(dayOffset == 0 ? 21 : 22))\(isImperial ? "°F" : "°C")", windowRain, windowSpeed),
                systemImage: "sunrise.fill",
                endHour: windowEndHour
            )
        )
    }
}

private struct FitnessWeatherInsight: Identifiable {
    enum Tone {
        case good
        case warning
        case indoor
    }

    let title: String
    let message: String
    let systemImage: String
    let tone: Tone

    /// Stable identity: title text is unique per insight within a snapshot.
    var id: String { title }

    var color: Color {
        switch tone {
        case .good: PulseTheme.recovery
        case .warning: PulseTheme.warning
        case .indoor: MetricDomain.strength.tint
        }
    }

    static func make(
        today: FitnessWeatherSnapshot,
        tomorrow: FitnessWeatherSnapshot,
        battery: FitnessMetrics.TrainingBatteryStatus,
        hasActivePlan: Bool,
        trainingLocation: UserProfile.TrainingLocation,
        now: Date = Date()
    ) -> [FitnessWeatherInsight] {
        var insights: [FitnessWeatherInsight] = []
        var suggestedTomorrowWindow = false
        let comfortableHigh = today.temperatureUnit == "°F" ? 93 : 34
        let comfortableGusts = today.speedUnit == "mph" ? 25 : 40

        let calendar = Calendar.current
        let nowFraction = Double(calendar.component(.hour, from: now)) + Double(calendar.component(.minute, from: now)) / 60
        // The mocked "best window" is a fixed morning slot; once its end hour has
        // passed, recommending it as "today" would be a stale, already-elapsed tip.
        let todayWindowHasPassed = nowFraction >= Double(today.bestWindow.endHour)
        // Matches the 12:00-17:00 window referenced in strong_sun_midday_message_format.
        let uvPeakHasPassed = nowFraction >= 17

        if today.rainProbability <= 10 && today.windGusts < comfortableGusts && today.highTemperature < comfortableHigh {
            if todayWindowHasPassed {
                insights.append(FitnessWeatherInsight(
                    title: localizedString("tomorrow_window"),
                    message: localizedFormat("tomorrow_window_message_format", tomorrow.bestWindow.title, tomorrow.bestWindow.subtitle),
                    systemImage: "clock.arrow.circlepath",
                    tone: .indoor
                ))
                suggestedTomorrowWindow = true
            } else {
                insights.append(FitnessWeatherInsight(
                    title: localizedString("good_day_to_go_out"),
                    message: localizedFormat("good_day_to_go_out_message_format", today.bestWindow.title.lowercased(with: RepsLocalization.locale)),
                    systemImage: "figure.run",
                    tone: .good
                ))
            }
        } else {
            insights.append(FitnessWeatherInsight(
                title: localizedString("controlled_outdoor_plan"),
                message: localizedString("controlled_outdoor_plan_message"),
                systemImage: "exclamationmark.triangle.fill",
                tone: .warning
            ))
        }

        if today.uvIndex >= 7 && !uvPeakHasPassed {
            insights.append(FitnessWeatherInsight(
                title: localizedString("strong_sun_midday"),
                message: localizedFormat("strong_sun_midday_message_format", "\(today.uvIndex)"),
                systemImage: "sun.max.trianglebadge.exclamationmark.fill",
                tone: .warning
            ))
        }

        if battery.level < 55 || trainingLocation == .gym || trainingLocation == .home {
            insights.append(FitnessWeatherInsight(
                title: hasActivePlan ? localizedString("better_indoors") : localizedString("indoor_alternative"),
                message: localizedFormat("indoor_strength_recovery_message_format", "\(battery.level)"),
                systemImage: "house.and.flag.fill",
                tone: .indoor
            ))
        } else if !suggestedTomorrowWindow {
            insights.append(FitnessWeatherInsight(
                title: localizedString("tomorrow_window"),
                message: localizedFormat("tomorrow_window_message_format", tomorrow.bestWindow.title, tomorrow.bestWindow.subtitle),
                systemImage: "calendar.badge.clock",
                tone: .good
            ))
        }

        return Array(insights.prefix(3))
    }
}

private struct FitnessWeatherWidget: View {
    let today: FitnessWeatherSnapshot
    let tomorrow: FitnessWeatherSnapshot
    @Binding var selectedDay: FitnessWeatherDay

    private var activeSnapshot: FitnessWeatherSnapshot {
        selectedDay == .today ? today : tomorrow
    }

    var body: some View {
        GlassMetricCard(domain: .weather, contentPadding: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(activeSnapshot.locationName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text(activeSnapshot.conditionTitle)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(activeSnapshot.conditionMessage)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: activeSnapshot.systemImage)
                        .font(.system(size: 48, weight: .bold))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 60, height: 60)
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                WeatherCompactChart(points: activeSnapshot.hourly, tint: MetricDomain.weather.tint)
                    .frame(height: 118)
                    .padding(.horizontal, 8)
                    .id(selectedDay)

                HStack(spacing: 8) {
                    WeatherMetricPill(value: "\(activeSnapshot.currentTemperature)\(activeSnapshot.temperatureUnit)", label: localizedString("now"), systemImage: "thermometer.medium", color: PulseTheme.warning)
                    WeatherMetricPill(value: "\(activeSnapshot.windSpeed) \(activeSnapshot.speedUnit)", label: localizedString("wind"), systemImage: "location.north.fill", color: MetricDomain.weather.tint)
                    WeatherMetricPill(value: "\(activeSnapshot.rainProbability)%", label: localizedString("rain"), systemImage: "cloud.rain.fill", color: Color.blue)
                    WeatherMetricPill(value: "\(activeSnapshot.uvIndex)", label: "UV", systemImage: "sun.max.fill", color: PulseTheme.accent)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    ForecastDayPill(
                        title: localizedString("today_2"),
                        temperature: "\(today.lowTemperature)-\(today.highTemperature)\(today.temperatureUnit)",
                        systemImage: today.systemImage,
                        isSelected: selectedDay == .today
                    ) {
                        HapticService.selection()
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedDay = .today
                        }
                    }
                    ForecastDayPill(
                        title: localizedString("tomorrow"),
                        temperature: "\(tomorrow.lowTemperature)-\(tomorrow.highTemperature)\(tomorrow.temperatureUnit)",
                        systemImage: tomorrow.systemImage,
                        isSelected: selectedDay == .tomorrow
                    ) {
                        HapticService.selection()
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedDay = .tomorrow
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(localizedString("weather")), \(activeSnapshot.conditionTitle), \(activeSnapshot.currentTemperature)\(activeSnapshot.temperatureUnit)")
    }
}

private struct ForecastDayPill: View {
    let title: String
    let temperature: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(isSelected ? PulseTheme.textPrimary : PulseTheme.secondaryText)
                    Text(temperature)
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((isSelected ? MetricDomain.weather.tint : PulseTheme.secondaryText).opacity(isSelected ? 0.15 : 0.08), in: Capsule())
            .overlay {
                Capsule().stroke((isSelected ? MetricDomain.weather.tint : PulseTheme.separator).opacity(0.22), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WeatherMetricPill: View {
    let value: String
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(PulseTheme.grouped.opacity(0.75), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct WeatherCompactChart: View {
    let points: [FitnessWeatherHourPoint]
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .bottom) {
                    WeatherGrid()
                    WeatherTemperatureArea(points: points)
                        .fill(
                            LinearGradient(
                                colors: [PulseTheme.warning.opacity(0.28), tint.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    WeatherTemperatureLine(points: points)
                        .stroke(temperatureGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    WeatherWindLine(points: points)
                        .stroke(tint.opacity(0.78), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [7, 6]))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }

            HStack {
                ForEach(points) { point in
                    VStack(spacing: 3) {
                        Text(point.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(PulseTheme.secondaryText)
                        if point.uvIndex >= 7 {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(PulseTheme.warning)
                        } else {
                            Color.clear.frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            colors: [PulseTheme.warning, PulseTheme.semanticEffort],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct WeatherGrid: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let horizontalLines = 3
                for index in 0...horizontalLines {
                    let y = proxy.size.height * CGFloat(index) / CGFloat(horizontalLines)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                }
            }
            .stroke(PulseTheme.separator.opacity(0.55), style: StrokeStyle(lineWidth: 0.8, dash: [4, 6]))
        }
    }
}

private struct WeatherTemperatureLine: Shape {
    let points: [FitnessWeatherHourPoint]

    func path(in rect: CGRect) -> Path {
        weatherPath(in: rect, values: points.map(\.temperature))
    }
}

private struct WeatherTemperatureArea: Shape {
    let points: [FitnessWeatherHourPoint]

    func path(in rect: CGRect) -> Path {
        var path = weatherPath(in: rect, values: points.map(\.temperature))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WeatherWindLine: Shape {
    let points: [FitnessWeatherHourPoint]

    func path(in rect: CGRect) -> Path {
        weatherPath(in: rect.insetBy(dx: 0, dy: rect.height * 0.20), values: points.map(\.windSpeed))
    }
}

private func weatherPath(in rect: CGRect, values: [Int]) -> Path {
    guard values.count > 1 else { return Path() }
    let minValue = values.min() ?? 0
    let maxValue = values.max() ?? 1
    let range = max(maxValue - minValue, 1)
    let stepX = rect.width / CGFloat(values.count - 1)

    var path = Path()
    for index in values.indices {
        let x = CGFloat(index) * stepX
        let normalized = Double(values[index] - minValue) / Double(range)
        let y = rect.maxY - CGFloat(normalized) * rect.height
        index == values.startIndex ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    return path
}

private struct FitnessWeatherInsightRow: View {
    let insight: FitnessWeatherInsight
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PulseIconBadge(systemImage: insight.systemImage, tint: insight.color, size: 38, radius: PulseTheme.smallRadius)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(6)
                        .background(PulseTheme.secondaryText.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("dismiss_insight"))
            }
        }
        .padding(12)
        .background(insight.color.opacity(0.08), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(insight.color.opacity(0.13), lineWidth: 0.8)
        }
    }
}

/// Persists which insights the user has hidden "for today" — dismissals reset
/// automatically once the day rolls over since insights are regenerated daily.
private enum WeatherInsightDismissalStore {
    private static func key(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "weatherInsights.dismissed.\(Int(day.timeIntervalSince1970))"
    }

    static func dismissedIDs(for date: Date = Date()) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key(for: date)) ?? [])
    }

    static func dismiss(_ id: String, for date: Date = Date()) {
        var ids = dismissedIDs(for: date)
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: key(for: date))
    }

    static func restoreAll(for date: Date = Date()) {
        UserDefaults.standard.removeObject(forKey: key(for: date))
    }
}

/// Shared body for weather insight sections: expand/collapse into a one-line
/// summary, and per-insight hide/show with a restore affordance once any are hidden.
private struct WeatherInsightsPanel: View {
    let insights: [FitnessWeatherInsight]
    @Binding var isExpanded: Bool
    @State private var dismissedIDs: Set<String>

    init(insights: [FitnessWeatherInsight], isExpanded: Binding<Bool>) {
        self.insights = insights
        _isExpanded = isExpanded
        _dismissedIDs = State(initialValue: WeatherInsightDismissalStore.dismissedIDs())
    }

    private var visibleInsights: [FitnessWeatherInsight] {
        insights.filter { !dismissedIDs.contains($0.id) }
    }

    private var hiddenCount: Int { insights.count - visibleInsights.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isExpanded {
                if visibleInsights.isEmpty {
                    allClearRow
                } else {
                    ForEach(visibleInsights) { insight in
                        FitnessWeatherInsightRow(insight: insight) {
                            dismiss(insight)
                        }
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                if hiddenCount > 0 {
                    restoreButton
                }
            } else {
                collapsedSummary
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: dismissedIDs)
    }

    private func dismiss(_ insight: FitnessWeatherInsight) {
        HapticService.impact(.medium)
        dismissedIDs.insert(insight.id)
        WeatherInsightDismissalStore.dismiss(insight.id)
    }

    private var restoreButton: some View {
        Button {
            HapticService.selection()
            dismissedIDs.removeAll()
            WeatherInsightDismissalStore.restoreAll()
        } label: {
            Label(localizedFormat("weather_insights_restore_hidden_format", hiddenCount), systemImage: "arrow.uturn.backward")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
        }
        .buttonStyle(.plain)
    }

    private var allClearRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PulseTheme.recovery)
            Text(localizedString("weather_insights_all_clear"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Spacer(minLength: 0)
        }
    }

    private var collapsedSummary: some View {
        HStack(spacing: 8) {
            if let first = visibleInsights.first {
                Image(systemName: first.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(first.color)
                Text(first.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .lineLimit(1)
                if visibleInsights.count > 1 {
                    Text(localizedFormat("weather_insights_more_count_format", visibleInsights.count - 1))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(PulseTheme.secondaryText.opacity(0.12), in: Capsule())
                }
            } else {
                Text(localizedString("weather_insights_all_clear"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Chevron toggle shared by both weather insight sections (home + detail sheet).
private struct WeatherInsightsCollapseToggle: View {
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            HapticService.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .padding(7)
                .background(PulseTheme.secondaryText.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? localizedString("collapse_insights") : localizedString("expand_insights"))
    }
}

private struct TodayWeatherDetailView: View {
    let today: FitnessWeatherSnapshot
    let tomorrow: FitnessWeatherSnapshot
    let insights: [FitnessWeatherInsight]
    @State private var selectedDay: FitnessWeatherDay
    @State private var isInsightsExpanded = true

    init(
        today: FitnessWeatherSnapshot,
        tomorrow: FitnessWeatherSnapshot,
        insights: [FitnessWeatherInsight],
        selectedDay: FitnessWeatherDay
    ) {
        self.today = today
        self.tomorrow = tomorrow
        self.insights = insights
        _selectedDay = State(initialValue: selectedDay)
    }

    private var domain: MetricDomain { .weather }

    private var activeSnapshot: FitnessWeatherSnapshot {
        selectedDay == .today ? today : tomorrow
    }

    var body: some View {
        ZStack {
            PulseTheme.background.ignoresSafeArea()
            DomainTintedBackground(domain: domain, height: 460)

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    dayPicker
                    bestWindowCard
                    detailStats
                    temperatureCard
                    windCard
                    rainUVCard
                    insightsCard
                }
                .padding(.top, DetailNavigationHeaderBar.contentTopPadding - 40)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .overlay(alignment: .top) {
                HealthWidgetDetailNavBar(title: nil, domain: domain)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        VStack(spacing: 13) {
            Image(systemName: activeSnapshot.systemImage)
                .font(.system(size: 88, weight: .bold))
                .symbolRenderingMode(.multicolor)
            VStack(spacing: 5) {
                Text(activeSnapshot.locationName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text(activeSnapshot.conditionTitle)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                Text(activeSnapshot.conditionMessage)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                WeatherMetricPill(value: "\(activeSnapshot.currentTemperature)\(activeSnapshot.temperatureUnit)", label: localizedString("now"), systemImage: "thermometer.medium", color: PulseTheme.warning)
                WeatherMetricPill(value: "\(activeSnapshot.windSpeed) \(activeSnapshot.speedUnit)", label: localizedString("wind"), systemImage: "location.north.fill", color: MetricDomain.weather.tint)
                WeatherMetricPill(value: "\(activeSnapshot.uvIndex)", label: "UV", systemImage: "sun.max.fill", color: PulseTheme.accent)
                WeatherMetricPill(value: "\(activeSnapshot.rainProbability)%", label: localizedString("rain"), systemImage: "cloud.rain.fill", color: Color.blue)
            }
        }
        .padding(.top, 6)
    }

    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(FitnessWeatherDay.allCases) { day in
                Button {
                    HapticService.selection()
                    withAnimation(.snappy(duration: 0.22)) {
                        selectedDay = day
                    }
                } label: {
                    Text(day.title)
                        .font(.caption.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedDay == day ? PulseTheme.onColor(domain.tint) : domain.tint)
                        .background(selectedDay == day ? domain.tint : domain.tint.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bestWindowCard: some View {
        GlassMetricCard(domain: domain) {
            HStack(alignment: .center, spacing: 14) {
                PulseIconBadge(systemImage: activeSnapshot.bestWindow.systemImage, tint: PulseTheme.warning, size: 52, radius: PulseTheme.mediumRadius)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("best_time"))
                        .font(.headline.weight(.black))
                    Text(activeSnapshot.bestWindow.title)
                        .font(.subheadline.weight(.bold))
                    Text(activeSnapshot.bestWindow.subtitle)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var detailStats: some View {
        HealthStatsHeader(items: [
            HealthStatItem(value: "\(activeSnapshot.highTemperature)\(activeSnapshot.temperatureUnit)", label: localizedString("max_temperature")),
            HealthStatItem(value: "\(activeSnapshot.humidity)%", label: localizedString("humidity")),
            HealthStatItem(value: "\(activeSnapshot.windGusts) \(activeSnapshot.speedUnit)", label: localizedString("wind_gusts"))
        ], domain: domain)
    }

    private var temperatureCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                WeatherDetailCardHeader(title: localizedString("temperature"), systemImage: "thermometer.medium", color: PulseTheme.warning)
                WeatherCompactChart(points: activeSnapshot.hourly, tint: domain.tint)
                    .frame(height: 170)
            }
        }
    }

    private var windCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                WeatherDetailCardHeader(title: localizedString("wind"), systemImage: "location.north.fill", color: domain.tint)
                HStack(spacing: 0) {
                    HealthStatItem(value: "\(activeSnapshot.windSpeed)", label: activeSnapshot.speedUnit)
                        .weatherStatCell()
                    HealthStatItem(value: "\(activeSnapshot.windGusts)", label: localizedString("wind_gusts"))
                        .weatherStatCell()
                }
                WeatherWindBars(points: activeSnapshot.hourly, color: domain.tint)
                    .frame(height: 98)
            }
        }
    }

    private var rainUVCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 14) {
                WeatherDetailCardHeader(title: localizedString("rain_uv"), systemImage: "sun.max.fill", color: PulseTheme.accent)
                HStack(spacing: 10) {
                    HealthMiniTile(title: localizedString("rain"), value: "\(activeSnapshot.rainProbability)%", subtitle: localizedString("rain_probability"), systemImage: "cloud.rain.fill", color: Color.blue, domain: domain)
                    HealthMiniTile(title: "UV", value: "\(activeSnapshot.uvIndex)", subtitle: uvLabel(activeSnapshot.uvIndex), systemImage: "sun.max.fill", color: PulseTheme.accent, domain: domain)
                }
                HealthInsightRow(
                    icon: "shield.lefthalf.filled",
                    color: activeSnapshot.uvIndex >= 7 ? PulseTheme.warning : PulseTheme.recovery,
                    title: activeSnapshot.uvIndex >= 7 ? localizedString("sun_protection") : localizedString("controlled_uv"),
                    message: activeSnapshot.uvIndex >= 7 ? localizedString("sun_protection_message") : localizedString("controlled_uv_message")
                )
            }
        }
    }

    private var insightsCard: some View {
        GlassMetricCard(domain: domain) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    WeatherDetailCardHeader(title: localizedString("fitness_insights"), systemImage: "sparkles", color: PulseTheme.accent)
                    Spacer(minLength: 8)
                    WeatherInsightsCollapseToggle(isExpanded: $isInsightsExpanded)
                }
                WeatherInsightsPanel(insights: insights, isExpanded: $isInsightsExpanded)
            }
        }
    }

    private func uvLabel(_ value: Int) -> String {
        switch value {
        case 0...2: "bajo"
        case 3...5: "moderado"
        case 6...7: "alto"
        default: "muy alto"
        }
    }
}

private struct WeatherDetailCardHeader: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.black))
            .foregroundStyle(PulseTheme.textPrimary)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
            .tint(color)
    }
}

private extension HealthStatItem {
    func weatherStatCell() -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(PulseTheme.textPrimary)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WeatherWindBars: View {
    let points: [FitnessWeatherHourPoint]
    let color: Color

    private var maxWind: Int {
        max(points.map(\.windSpeed).max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(points) { point in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color.opacity(0.25 + 0.60 * (Double(point.windSpeed) / Double(maxWind))))
                        .frame(height: max(10, CGFloat(point.windSpeed) / CGFloat(maxWind) * 68))
                    Text(point.label)
                        .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ContinuitySignal {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

private enum TodayRoute: Hashable {
    case sleep
    case hrv
    case heartRate
    case trainingBattery
    case exercise
    case hydration
    case vo2Max
    case steps
    case greetingSleep
    case greetingHrv
    case greetingHeartRate
    case greetingRecovery
    case activeWorkout
    case workoutDetail(WorkoutDay)
    case workoutLibrary
}

// MARK: - Weekly Progress Hero Card

/// Tarjeta hero de progreso semanal. Muestra racha, sesiones y volumen con barras
/// de actividad diaria animadas. Visible en TodayView cuando no hay sesión activa,
/// justo debajo del saludo — diseñada para motivar al usuario con datos de progreso
/// real de un solo vistazo.
struct WeeklyProgressHeroCard: View {
    let streakDays: Int
    let completedThisWeek: Int
    let weeklyTarget: Int
    let weeklyVolumeKg: Double
    let weeklyVolumeUnit: String
    let barPoints: [WeeklyBarPoint]

    @State private var barsAnimated = false
    private let chartPlotHeight: CGFloat = 32
    private let dayLabelHeight: CGFloat = 15
    private let barLabelGap: CGFloat = 9

    var body: some View {
        DomainHeroCard(domain: .strength, minHeight: 168) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Top row: streak + sessions ─────────────────────────────
                HStack(spacing: 16) {
                    // Streak
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.caption.weight(.black))
                                .foregroundStyle(PulseTheme.warning)
                            Text("\(streakDays)")
                                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        Text("days_in_a_row")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    Divider()
                        .frame(height: 36)
                        .opacity(0.25)

                    // Sessions this week
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.black))
                                .foregroundStyle(PulseTheme.growth)
                            Text("\(completedThisWeek)/\(weeklyTarget)")
                                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        Text("sessions_2")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    Spacer()

                    // Volume
                    VStack(alignment: .trailing, spacing: 3) {
                        let volDisplay = weeklyVolumeKg >= 1000
                            ? String(format: "%.1fk", weeklyVolumeKg / 1000)
                            : String(format: "%.0f", weeklyVolumeKg)
                        Text(volDisplay)
                            .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(weeklyVolumeUnit)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                }

                // ── Bar chart: 7-day activity ──────────────────────────────
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(barPoints) { point in
                        VStack(spacing: 0) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(barFill(for: point))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .strokeBorder(PulseTheme.accentOnCard.opacity(point.isToday ? 0.9 : 0), lineWidth: 1.5)
                                    )
                                    .frame(
                                        height: barsAnimated
                                            ? max(5, chartPlotHeight * point.normalizedHeight)
                                            : 5
                                    )
                                    .animation(
                                        .spring(response: 0.55, dampingFraction: 0.70)
                                            .delay(Double(barPoints.firstIndex(where: { $0.id == point.id }) ?? 0) * 0.06),
                                        value: barsAnimated
                                    )
                            }
                            .frame(height: chartPlotHeight, alignment: .bottom)
                            .clipped()

                            Spacer(minLength: barLabelGap)
                                .frame(height: barLabelGap)
                            
                            Text(point.dayLabel)
                                .font(.system(size: 10, weight: point.isToday ? .black : .bold, design: .rounded))
                                .foregroundStyle(point.isToday ? PulseTheme.accent : PulseTheme.tertiaryText)
                                .textCase(.uppercase)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(height: dayLabelHeight, alignment: .center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: chartPlotHeight + barLabelGap + dayLabelHeight, alignment: .bottom)
            }
            .padding(16)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                barsAnimated = true
            }
        }
    }

    /// Vertical gradient whose hue reflects the day's share of the week's peak
    /// volume — cool (cyan/green) for light days, hot (orange/red) for the
    /// biggest ones — instead of a single flat green, so the row reads as a
    /// heatmap of effort at a glance. Rest days stay neutral gray.
    private func barFill(for point: WeeklyBarPoint) -> LinearGradient {
        guard point.hasActivity else {
            return LinearGradient(
                colors: [PulseTheme.grouped.opacity(0.5), PulseTheme.grouped.opacity(0.5)],
                startPoint: .top, endPoint: .bottom
            )
        }
        let base = PulseTheme.magnitudeColor(point.normalizedHeight)
        return LinearGradient(
            colors: [base.opacity(point.isToday ? 0.85 : 0.62), base],
            startPoint: .top, endPoint: .bottom
        )
    }
}

struct WeeklyBarPoint: Identifiable {
    let id: Date
    let dayLabel: String
    let normalizedHeight: Double   // 0.0 – 1.0
    let hasActivity: Bool
    let isToday: Bool
}

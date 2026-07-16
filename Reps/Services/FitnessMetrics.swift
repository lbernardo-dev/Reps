import Foundation

enum FitnessMetrics {
    /// Returns a calendar age only after a cheap range check. Calling
    /// `Calendar.dateComponents` with a corrupted sentinel date (for example
    /// `Date.distantPast`) can spend seconds walking historical time-zone
    /// transitions and block the main thread.
    static func ageYears(
        from dateOfBirth: Date?,
        now: Date = .now,
        maximumAge: Int = 120
    ) -> Int? {
        guard let dateOfBirth, maximumAge > 0 else { return nil }

        let elapsed = now.timeIntervalSince(dateOfBirth)
        let maximumPlausibleInterval = Double(maximumAge + 1) * 366 * 24 * 60 * 60
        guard elapsed.isFinite,
              elapsed >= 0,
              elapsed <= maximumPlausibleInterval else {
            return nil
        }

        let years = Calendar.current.dateComponents(
            [.year],
            from: dateOfBirth,
            to: now
        ).year
        guard let years, (0...maximumAge).contains(years) else { return nil }
        return years
    }

    static func estimatedMaxHeartRate(
        dateOfBirth: Date?,
        now: Date = .now,
        fallback: Double = 190
    ) -> Double {
        guard let age = ageYears(from: dateOfBirth, now: now), age > 0 else {
            return fallback
        }
        return Double(max(120, 220 - age))
    }

    struct ExerciseProgressPoint: Identifiable {
        let id = UUID()
        let date: Date
        let workoutTitle: String
        let maxWeightKg: Double
        let maxReps: Int
        let totalVolumeKg: Double
        let estimatedOneRepMaxKg: Double
        let completedSets: Int
    }

    struct MuscleVolumePoint: Identifiable {
        let id = UUID()
        let muscleGroup: String
        let completedSets: Int
        let totalVolumeKg: Double

        var recommendedRangeText: String {
            switch completedSets {
            case 0...7:
                return localizedString("muscle_range_below_10")
            case 8...20:
                return localizedString("muscle_range_10_20")
            default:
                return localizedString("muscle_range_above_20")
            }
        }

        var targetProgress: Double {
            min(Double(completedSets) / 20, 1)
        }
    }

    struct TrainingInsight: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
    }

    struct TrainingBatteryStatus: Equatable {
        enum State: String {
            case charged
            case steady
            case low
            case critical
        }

        let level: Int
        let fatigueLoad: Double
        let recoveryCredit: Double
        let todayLoad: Double
        let weeklyLoad: Double
        let planPressure: Double
        let state: State
        let title: String
        let message: String
        let suggestion: String
        let systemImage: String
        // Breakdown fields for UI display — single source of truth
        let decayedFatigue: Double
        let wellnessPenalty: Double
        let restDays: Int
        let sleepCredit: Double
        let hrvCredit: Double
        let fatigueCredit: Double
    }

    struct DailyCoachRecommendation: Equatable {
        enum Action: Equatable {
            case startWorkout
            case createPlan
            case scheduleWorkout
            case openProgress
            case competitive(AnalyticsEngine.CompetitiveAction)
        }

        enum Tone: String, Equatable {
            case primary
            case recovery
            case warning
            case accent
        }

        let title: String
        let message: String
        let actionTitle: String
        let systemImage: String
        let tone: Tone
        let action: Action
    }

    enum PlanTrendDirection: Equatable {
        case up
        case flat
        case down
    }

    enum PlanLoadState: Equatable {
        case onTrack
        case behind
        case overreaching
        case noData
    }

    struct PlanWeekPoint: Identifiable, Equatable {
        let id: Date
        let weekStart: Date
        let sessions: Int
        let targetSessions: Int
        let volumeKg: Double

        var adherence: Double {
            FitnessMetrics.weeklyCompletion(completedWorkouts: sessions, plannedWorkouts: targetSessions)
        }
    }

    struct PlanExecutionSummary: Equatable {
        let planID: UUID
        let planName: String
        let currentWeek: Int
        let totalWeeks: Int
        let daysPerWeek: Int
        let completedThisWeek: Int
        let scheduledThisWeek: Int
        let adherence: Double
        let totalCompletedSessions: Int
        let planProgress: Double
        let targetWeeklySets: Int
        let actualWeeklySets: Int
        let volumeThisWeekKg: Double
        let volumeDeltaVsPreviousWeek: Double?
        let estimatedOneRepMaxTrend: PlanTrendDirection
        let loadState: PlanLoadState
        let nextWorkout: WorkoutDay?
        let lastCompletedWorkoutDate: Date?
        let weeklyPoints: [PlanWeekPoint]
        let muscleTargetPoints: [AnalyticsEngine.MuscleTargetPoint]
        let stalledExercises: [AnalyticsEngine.ExerciseStall]
    }

    static func totalVolumeKg(for sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { partial, session in
            partial + completedSets(in: session).reduce(0) { setTotal, set in
                setTotal + (set.weightKg * Double(set.reps))
            }
        }
    }

    static func personalRecordWeightKg(for sessions: [WorkoutSession]) -> Double? {
        sessions
            .flatMap(completedSets)
            .map(\.weightKg)
            .max()
    }

    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        guard reps > 1 else { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    static func bestEstimatedOneRepMaxKg(for sessions: [WorkoutSession]) -> Double? {
        sessions
            .flatMap(completedSets)
            .map { estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }
            .max()
    }

    static func weeklyCompletion(completedWorkouts: Int, plannedWorkouts: Int) -> Double {
        guard plannedWorkouts > 0 else { return 0 }
        return min(Double(completedWorkouts) / Double(plannedWorkouts), 1)
    }

    static func planExecutionSummary(
        for plan: WorkoutPlan,
        sessions allSessions: [WorkoutSession],
        scheduledWorkouts: [ScheduledWorkout],
        exercises: [Exercise],
        now: Date = .now
    ) -> PlanExecutionSummary {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
        let planSessions = allSessions.filter { isSession($0, attributableTo: plan) }
        let thisWeekSessions = planSessions.filter { $0.date >= weekStart && $0.date < nextWeekStart }
        let previousWeekSessions = planSessions.filter { $0.date >= previousWeekStart && $0.date < weekStart }
        let scheduledThisWeek = scheduledWorkouts.filter { scheduled in
            scheduled.date >= weekStart
                && scheduled.date < nextWeekStart
                && scheduled.status == .scheduled
                && plan.days.contains { $0.id == scheduled.workoutDay.id || $0.title == scheduled.workoutDay.title }
        }

        let competitive = AnalyticsEngine.competitiveSummary(
            sessions: thisWeekSessions,
            activePlan: plan,
            exercises: exercises,
            since: weekStart,
            now: now
        )
        let completedThisWeek = thisWeekSessions.count
        let totalExpectedSessions = max(plan.totalWeeks * max(plan.daysPerWeek, 0), 1)
        let planProgress = min(Double(planSessions.count) / Double(totalExpectedSessions), 1)
        let volumeThisWeek = totalVolumeKg(for: thisWeekSessions)
        let previousVolume = totalVolumeKg(for: previousWeekSessions)
        let volumeDelta = previousVolume > 0 ? ((volumeThisWeek - previousVolume) / previousVolume) : nil
        let adherence = weeklyCompletion(completedWorkouts: completedThisWeek, plannedWorkouts: plan.daysPerWeek)
        let loadState = planLoadState(
            adherence: adherence,
            volumeThisWeek: volumeThisWeek,
            previousVolume: previousVolume,
            actualWeeklySets: competitive.actualWeeklySets,
            targetWeeklySets: competitive.targetWeeklySets
        )

        return PlanExecutionSummary(
            planID: plan.id,
            planName: plan.name,
            currentWeek: plan.currentWeek,
            totalWeeks: plan.totalWeeks,
            daysPerWeek: plan.daysPerWeek,
            completedThisWeek: completedThisWeek,
            scheduledThisWeek: scheduledThisWeek.count,
            adherence: adherence,
            totalCompletedSessions: planSessions.count,
            planProgress: planProgress,
            targetWeeklySets: competitive.targetWeeklySets,
            actualWeeklySets: competitive.actualWeeklySets,
            volumeThisWeekKg: volumeThisWeek,
            volumeDeltaVsPreviousWeek: volumeDelta,
            estimatedOneRepMaxTrend: oneRepMaxTrend(current: thisWeekSessions, previous: previousWeekSessions),
            loadState: loadState,
            nextWorkout: plan.normalizedActiveDay,
            lastCompletedWorkoutDate: planSessions.map(\.date).max(),
            weeklyPoints: planWeeklyPoints(for: plan, sessions: planSessions, now: now),
            muscleTargetPoints: competitive.muscleTargets,
            stalledExercises: competitive.stalledExercises
        )
    }

    static func progressPoints(for exercise: Exercise, in sessions: [WorkoutSession]) -> [ExerciseProgressPoint] {
        sessions.compactMap { session in
            let logs = session.exerciseLogs?.filter { $0.exercise.id == exercise.id || $0.exercise.name == exercise.name } ?? []
            let sets = logs.flatMap(\.sets).filter(\.completed)

            guard !sets.isEmpty else {
                return nil
            }

            let maxWeight = sets.map(\.weightKg).max() ?? 0
            let maxReps = sets.map(\.reps).max() ?? 0
            let volume = sets.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
            let bestOneRepMax = sets.map { estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0

            return ExerciseProgressPoint(
                date: session.date,
                workoutTitle: session.workoutTitle,
                maxWeightKg: maxWeight,
                maxReps: maxReps,
                totalVolumeKg: volume,
                estimatedOneRepMaxKg: bestOneRepMax,
                completedSets: sets.count
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func averageVolumeKg(for points: [ExerciseProgressPoint]) -> Double {
        guard !points.isEmpty else {
            return 0
        }

        return points.reduce(0) { $0 + $1.totalVolumeKg } / Double(points.count)
    }

    static func completedSets(in session: WorkoutSession) -> [SetLog] {
        if let exerciseLogs = session.exerciseLogs, !exerciseLogs.isEmpty {
            return exerciseLogs.flatMap(\.sets).filter(\.completed)
        }

        return session.sets.filter(\.completed)
    }

    static func completedExerciseLogs(in session: WorkoutSession) -> [ExerciseLog] {
        if let exerciseLogs = session.exerciseLogs, !exerciseLogs.isEmpty {
            return exerciseLogs.compactMap { log in
                let completedSets = log.sets.filter(\.completed)
                guard !completedSets.isEmpty else {
                    return nil
                }

                var completedLog = log
                completedLog.sets = completedSets
                return completedLog
            }
        }

        let completedSets = session.sets.filter(\.completed)
        guard !completedSets.isEmpty else {
            return []
        }
        return [ExerciseLog(exercise: SeedData.bench, notes: session.notes ?? "", sets: completedSets)]
    }

    static func progressiveOverloadDelta(for points: [ExerciseProgressPoint]) -> Double {
        guard let first = points.first, let last = points.last else {
            return 0
        }

        return last.estimatedOneRepMaxKg - first.estimatedOneRepMaxKg
    }

    static func muscleVolumePoints(for sessions: [WorkoutSession], since startDate: Date) -> [MuscleVolumePoint] {
        var buckets: [String: (sets: Int, volume: Double)] = [:]

        sessions
            .filter { $0.date >= startDate }
            .flatMap(completedExerciseLogs)
            .forEach { log in
                let volume = log.sets.reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
                let current = buckets[log.exercise.muscleGroup] ?? (sets: 0, volume: 0)
                buckets[log.exercise.muscleGroup] = (current.sets + log.sets.count, current.volume + volume)
            }

        return buckets.map { muscleGroup, values in
            MuscleVolumePoint(muscleGroup: muscleGroup, completedSets: values.sets, totalVolumeKg: values.volume)
        }
        .sorted {
            if $0.completedSets == $1.completedSets {
                return $0.muscleGroup < $1.muscleGroup
            }
            return $0.completedSets > $1.completedSets
        }
    }

    static func insightCards(for sessions: [WorkoutSession], goals: [Goal], since startDate: Date) -> [TrainingInsight] {
        let recentSessions = sessions.filter { $0.date >= startDate }
        let musclePoints = muscleVolumePoints(for: sessions, since: startDate)
        let totalVolume = totalVolumeKg(for: recentSessions)
        let previousStart = Calendar.current.date(byAdding: .day, value: -7, to: startDate) ?? startDate
        let previousSessions = sessions.filter { $0.date >= previousStart && $0.date < startDate }
        let previousVolume = totalVolumeKg(for: previousSessions)

        var insights: [TrainingInsight] = []

        if totalVolume > previousVolume, previousVolume > 0 {
            insights.append(TrainingInsight(
                title: localizedString("insight_volume_up_title"),
                message: localizedFormat("insight_volume_up_message_format", Int(totalVolume - previousVolume)),
                systemImage: "chart.line.uptrend.xyaxis"
            ))
        } else if !recentSessions.isEmpty {
            insights.append(TrainingInsight(
                title: localizedString("insight_keep_base_title"),
                message: localizedFormat("insight_keep_base_message_format", recentSessions.count),
                systemImage: "calendar.badge.clock"
            ))
        }

        if let lowestMuscle = musclePoints.min(by: { $0.completedSets < $1.completedSets }), lowestMuscle.completedSets < 10 {
            insights.append(TrainingInsight(
                title: localizedFormat("insight_muscle_low_title_format", lowestMuscle.muscleGroup),
                message: localizedFormat("insight_muscle_low_message_format", lowestMuscle.completedSets),
                systemImage: "target"
            ))
        }

        if let strengthGoal = goals.first(where: { $0.kind == .strength }) {
            let remaining = max(strengthGoal.target - strengthGoal.current, 0)
            insights.append(TrainingInsight(
                title: strengthGoal.title,
                message: remaining == 0 ? localizedString("insight_goal_reached_message") : localizedFormat("insight_goal_remaining_message_format", Int(remaining), strengthGoal.unit),
                systemImage: "trophy"
            ))
        }

        if insights.isEmpty {
            insights.append(TrainingInsight(
                title: localizedString("insight_empty_title"),
                message: localizedString("insight_empty_message"),
                systemImage: "sparkles"
            ))
        }

        return Array(insights.prefix(3))
    }

    static func trainingBatteryStatus(
        sessions: [WorkoutSession],
        scheduledWorkouts: [ScheduledWorkout],
        activePlan: WorkoutPlan,
        bodyMetrics: [BodyMetric],
        health: HealthSyncState,
        sleepTarget: Double = 7.0,
        now: Date = .now
    ) -> TrainingBatteryStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recentSessions = sessions.filter { $0.date >= calendar.date(byAdding: .day, value: -10, to: now) ?? now }
        let todaySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }

        let decayedFatigue = recentSessions.reduce(0.0) { total, session in
            let ageHours = max(now.timeIntervalSince(session.date) / 3_600, 0)
            let decay = pow(0.72, ageHours / 24)
            return total + sessionBatteryCost(session) * decay
        }

        let todayLoad = todaySessions.reduce(0) { $0 + sessionBatteryCost($1) }
        let weeklyLoad = sessions
            .filter { $0.date >= weekStart && $0.date <= now }
            .reduce(0) { $0 + sessionBatteryCost($1) }
        let planPressure = planBatteryPressure(activePlan, scheduledWorkouts: scheduledWorkouts, now: now)

        // Recovery sub-breakdown (single computation, exposed in result for UI)
        let latestBodyMetric = bodyMetrics.sorted { $0.date > $1.date }.first
        let lastSession = sessions.sorted { $0.date > $1.date }.first
        let restDays: Int
        if let lastSession {
            restDays = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: lastSession.date), to: calendar.startOfDay(for: now)).day ?? 0, 0)
        } else {
            restDays = 2
        }
        let sleepCredit = latestBodyMetric?.sleepHours.map { clamp(($0 - sleepTarget) * 4, lower: -8, upper: 8) } ?? 0
        let fatigueCredit = latestBodyMetric?.fatigue.map { clamp(Double(3 - $0) * 3, lower: -8, upper: 6) } ?? 0
        let hrvCredit = health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.heartRateVariabilityMS.map { hrv in
            clamp((hrv - 45) / 8, lower: -5, upper: 6)
        } ?? 0
        let recoveryCredit = clamp(Double(restDays) * 11 + sleepCredit + fatigueCredit + hrvCredit, lower: -12, upper: 36)

        let wellnessPenalty = wellnessPenalty(bodyMetrics: bodyMetrics, health: health, now: now)
        let fatigueLoad = decayedFatigue + planPressure + wellnessPenalty
        let level = Int(clamp(100 - fatigueLoad + recoveryCredit, lower: 5, upper: 100).rounded())
        let state: TrainingBatteryStatus.State
        let title: String
        let message: String
        let suggestion: String
        let systemImage: String

        switch level {
        case 0..<30:
            state = .critical
            title = localizedString("battery_critical_title")
            message = localizedString("battery_critical_message")
            suggestion = localizedString("battery_critical_suggestion")
            systemImage = "battery.25percent"
        case 30..<55:
            state = .low
            title = localizedString("battery_low_title")
            message = localizedString("battery_low_message")
            suggestion = localizedString("battery_low_suggestion")
            systemImage = "battery.50percent"
        case 55..<80:
            state = .steady
            title = localizedString("battery_steady_title")
            message = localizedString("battery_steady_message")
            suggestion = localizedString("battery_steady_suggestion")
            systemImage = "battery.75percent"
        default:
            state = .charged
            title = localizedString("battery_charged_title")
            message = localizedString("battery_charged_message")
            suggestion = localizedString("battery_charged_suggestion")
            systemImage = "battery.100percent"
        }

        return TrainingBatteryStatus(
            level: level,
            fatigueLoad: fatigueLoad,
            recoveryCredit: recoveryCredit,
            todayLoad: todayLoad,
            weeklyLoad: weeklyLoad,
            planPressure: planPressure,
            state: state,
            title: title,
            message: message,
            suggestion: suggestion,
            systemImage: systemImage,
            decayedFatigue: decayedFatigue,
            wellnessPenalty: wellnessPenalty,
            restDays: restDays,
            sleepCredit: sleepCredit,
            hrvCredit: hrvCredit,
            fatigueCredit: fatigueCredit
        )
    }

    static func projectedBatteryLevel(after workout: WorkoutDay, from currentLevel: Int) -> Int {
        let plannedCost = workoutBatteryCost(workout)
        return Int(clamp(Double(currentLevel) - plannedCost, lower: 5, upper: 100).rounded())
    }

    struct PlanProjectionPoint: Identifiable {
        let id = UUID()
        let week: Int
        /// Cumulative expected gain vs. today, as a percentage (0 at week 0).
        let percentGain: Double
    }

    /// Xorshift64 generator seeded from stable content (not `hashValue`, which is
    /// randomized per process) so the same plan + profile always renders the same
    /// projection curve, across app relaunches.
    private struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        }

        mutating func nextUnit() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 1_000_000) / 1_000_000
        }
    }

    private static func fnv1aHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    /// Rough, non-clinical estimate of expected progress if the user sticks to
    /// the recommended plan, derived from experience level (novice/intermediate/
    /// advanced strength-gain curves), the stated main goal, and how many days a
    /// week the plan is trained — not from a specific exercise's actual 1RM.
    ///
    /// Real training progress is never a smooth curve: it fluctuates week to week
    /// with sleep, stress and session quality, and dips on planned deload weeks.
    /// A deterministic seed (derived from the plan + profile, not from `hashValue`)
    /// adds that texture so the same inputs always render the same "real-looking"
    /// curve instead of a straight line — while the underlying upward trend stays
    /// governed by the same experience/goal/consistency model.
    static func planProgressionProjection(
        for workout: WorkoutDay,
        experience: UserProfile.Experience,
        mainGoal: UserProfile.MainGoal,
        weeklyTrainingDays: Int,
        weeks: Int = 8
    ) -> [PlanProjectionPoint] {
        let baseWeeklyRate: Double
        switch experience {
        case .beginner: baseWeeklyRate = 0.020
        case .intermediate: baseWeeklyRate = 0.010
        case .advanced: baseWeeklyRate = 0.005
        }

        let goalMultiplier: Double
        switch mainGoal {
        case .getStronger: goalMultiplier = 1.15
        case .buildMuscle: goalMultiplier = 1.0
        case .bodyRecomposition: goalMultiplier = 0.75
        case .loseFat: goalMultiplier = 0.55
        case .stayActive: goalMultiplier = 0.4
        }

        let consistency = clamp(Double(weeklyTrainingDays) / 4.0, lower: 0.5, upper: 1.25)
        let weeklyRate = baseWeeklyRate * goalMultiplier * consistency

        let seedKey = "\(workout.id.uuidString)|\(experience.rawValue)|\(mainGoal.rawValue)|\(weeklyTrainingDays)"
        var rng = SeededGenerator(seed: fnv1aHash(seedKey))

        var points: [PlanProjectionPoint] = [PlanProjectionPoint(week: 0, percentGain: 0)]
        var cumulative = 0.0
        for week in 1...weeks {
            let trendStep = (pow(1 + weeklyRate, Double(week)) - pow(1 + weeklyRate, Double(week - 1))) * 100
            // Two averaged draws bias the noise toward its center, reading as
            // organic variance rather than uniform static.
            let noise = ((rng.nextUnit() + rng.nextUnit()) / 2 - 0.5) * 2
            var step = trendStep + noise * max(trendStep, 0.3) * 0.7
            if week % 4 == 0 {
                // Planned deload/lighter week — a normal part of real periodization.
                step *= 0.4
            }
            cumulative += step
            points.append(PlanProjectionPoint(week: week, percentGain: cumulative))
        }
        return points
    }

    static func dailyCoachRecommendation(
        battery: TrainingBatteryStatus,
        competitiveSummary: AnalyticsEngine.CompetitiveSummary,
        hasActivePlan: Bool,
        hasTodayWorkout: Bool,
        hasCompletedWorkout: Bool
    ) -> DailyCoachRecommendation {
        if !hasActivePlan {
            return DailyCoachRecommendation(
                title: localizedString("act_create_plan_title"),
                message: localizedString("act_create_plan_msg"),
                actionTitle: localizedString("act_create_plan_cta"),
                systemImage: "rectangle.stack.badge.plus",
                tone: .primary,
                action: .createPlan
            )
        }

        if battery.state == .critical {
            return DailyCoachRecommendation(
                title: battery.title,
                message: battery.suggestion,
                actionTitle: localizedString("act_schedule_recovery"),
                systemImage: battery.systemImage,
                tone: .warning,
                action: .competitive(.scheduleRecovery)
            )
        }

        if battery.state == .low {
            return DailyCoachRecommendation(
                title: battery.title,
                message: battery.suggestion,
                actionTitle: hasTodayWorkout ? localizedString("act_start_today_cta") : localizedString("act_schedule_cta"),
                systemImage: battery.systemImage,
                tone: .accent,
                action: hasTodayWorkout ? .startWorkout : .scheduleWorkout
            )
        }

        if hasTodayWorkout && competitiveSummary.completionRate < 0.75 {
            return DailyCoachRecommendation(
                title: localizedString("act_close_week_title"),
                message: localizedString("act_close_week_msg"),
                actionTitle: localizedString("act_start_today_cta"),
                systemImage: "play.circle.fill",
                tone: .primary,
                action: .startWorkout
            )
        }

        if let recommendation = competitiveSummary.recommendations.first(where: { $0.action != .none }) {
            return DailyCoachRecommendation(
                title: recommendation.title,
                message: recommendation.message,
                actionTitle: dailyCoachActionTitle(for: recommendation.action),
                systemImage: recommendation.systemImage,
                tone: .primary,
                action: .competitive(recommendation.action)
            )
        }

        if !hasCompletedWorkout || hasTodayWorkout {
            return DailyCoachRecommendation(
                title: localizedString("act_first_workout_title"),
                message: hasTodayWorkout ? localizedString("act_close_week_msg") : localizedString("act_first_workout_msg"),
                actionTitle: localizedString("act_train_cta"),
                systemImage: "play.circle.fill",
                tone: .primary,
                action: .startWorkout
            )
        }

        return DailyCoachRecommendation(
            title: localizedString("act_first_value_title"),
            message: localizedString("act_first_value_msg"),
            actionTitle: localizedString("act_see_progress_cta"),
            systemImage: "chart.line.uptrend.xyaxis",
            tone: .recovery,
            action: .openProgress
        )
    }

    private static func dailyCoachActionTitle(for action: AnalyticsEngine.CompetitiveAction) -> String {
        switch action {
        case .scheduleUndertrainedMuscle:
            return localizedString("act_schedule_focus")
        case .scheduleDeloadExercise:
            return localizedString("act_schedule_deload")
        case .reviewPlan:
            return localizedString("act_review_plan")
        case .scheduleRecovery:
            return localizedString("act_schedule_recovery")
        case .none:
            return localizedString("act_view_generic")
        }
    }

    static func workoutBatteryCost(_ workout: WorkoutDay) -> Double {
        let plannedSets = workout.exercises.reduce(0) { $0 + max($1.targetSets, 1) }
        let hardExerciseFactor = workout.exercises.reduce(0.0) { total, item in
            let priority: Double = item.priority == .primary ? 1.35 : (item.priority == .accessory ? 0.85 : 1.0)
            let type: Double
            switch item.exercise.exerciseType {
            case .hiit: type = 1.35
            case .cardio: type = 0.9
            case .mobility, .stretching: type = 0.35
            case .strength: type = 1.0
            }
            let restRelief = item.restSeconds >= 150 ? -0.35 : (item.restSeconds < 75 ? 0.45 : 0)
            return total + (Double(max(item.targetSets, 1)) * max(priority * type + restRelief, 0.25))
        }
        let durationCost = Double(workout.durationMinutes) / 9
        let exerciseRestCredit = Double(max(workout.exercises.count - 1, 0)) * (workout.restBetweenExercisesSeconds >= 120 ? 0.35 : -0.2)
        return clamp(durationCost + hardExerciseFactor + Double(plannedSets) * 0.55 - exerciseRestCredit, lower: 4, upper: 42)
    }

    static func sessionBatteryCost(_ session: WorkoutSession) -> Double {
        let completed = completedSets(in: session)
        let rpe = session.sessionRPE ?? averageSetRPE(for: completed) ?? 6.5
        let effective = completed.filter { $0.setType != .warmUp }.count
        let volumeCost = min(totalVolumeKg(for: [session]) / 650, 18)
        let durationCost = Double(session.durationMinutes) / 8
        let setCost = Double(effective) * 0.95
        let intensityCost = max(rpe - 6, 0) * 3.2
        let energyCost = Double(max((session.energyBefore ?? 3) - (session.energyAfter ?? 3), 0)) * 3.5
        let restAdjustment = restAdjustment(for: completed)
        let pauseRecovery = min(Double(session.pausedDurationSeconds) / 180, 3)
        return clamp(durationCost + setCost + volumeCost + intensityCost + energyCost + restAdjustment - pauseRecovery, lower: 3, upper: 46)
    }

    private static func planBatteryPressure(_ plan: WorkoutPlan, scheduledWorkouts: [ScheduledWorkout], now: Date) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let upcoming = scheduledWorkouts.filter { workout in
            workout.status == .scheduled
                && workout.date >= weekStart
                && workout.date <= (calendar.date(byAdding: .day, value: 7, to: weekStart) ?? now)
        }
        let plannedDays = upcoming.isEmpty ? plan.days : upcoming.map(\.workoutDay)
        guard !plannedDays.isEmpty else {
            return 0
        }

        let averageCost = plannedDays.reduce(0) { $0 + workoutBatteryCost($1) } / Double(plannedDays.count)
        let frequencyPressure = max(Double(plan.daysPerWeek - 3), 0) * 1.8
        return clamp((averageCost / 10) + frequencyPressure, lower: 0, upper: 16)
    }

    private static func recoveryCredit(
        sessions: [WorkoutSession],
        bodyMetrics: [BodyMetric],
        health: HealthSyncState,
        now: Date
    ) -> Double {
        let calendar = Calendar.current
        let lastSession = sessions.sorted { $0.date > $1.date }.first
        let restDays: Int
        if let lastSession {
            restDays = max(calendar.dateComponents([.day], from: calendar.startOfDay(for: lastSession.date), to: calendar.startOfDay(for: now)).day ?? 0, 0)
        } else {
            restDays = 2
        }

        let latestMetric = bodyMetrics.sorted { $0.date > $1.date }.first
        let sleepCredit = latestMetric?.sleepHours.map { clamp(($0 - 6) * 4, lower: -8, upper: 8) } ?? 0
        let fatigueCredit = latestMetric?.fatigue.map { clamp(Double(3 - $0) * 3, lower: -8, upper: 6) } ?? 0
        let hrvCredit = health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.heartRateVariabilityMS.map { hrv in
            clamp((hrv - 45) / 8, lower: -5, upper: 6)
        } ?? 0

        return clamp(Double(restDays) * 11 + sleepCredit + fatigueCredit + hrvCredit, lower: -12, upper: 36)
    }

    private static func wellnessPenalty(bodyMetrics: [BodyMetric], health: HealthSyncState, now: Date) -> Double {
        let latestMetric = bodyMetrics.sorted { $0.date > $1.date }.first
        let fatigue = Double(max((latestMetric?.fatigue ?? 3) - 3, 0)) * 5
        let stress = Double(max((latestMetric?.stress ?? 3) - 3, 0)) * 4
        let sleep = max(0, 6.5 - (latestMetric?.sleepHours ?? 7)) * 5
        let activeEnergy = health.latestDailyMetrics.sorted { $0.date > $1.date }.first?.activeEnergyKcal ?? 0
        let activityPenalty = activeEnergy > 900 ? 5.0 : 0.0
        return fatigue + stress + sleep + activityPenalty
    }

    private static func averageSetRPE(for sets: [SetLog]) -> Double? {
        let values = sets.compactMap(\.rpe)
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private static func restAdjustment(for sets: [SetLog]) -> Double {
        let rests = sets.compactMap(\.previousRestSeconds)
        guard !rests.isEmpty else {
            return 0
        }

        return rests.reduce(0.0) { total, rest in
            switch rest {
            case 0..<45:
                return total + 1.5
            case 45..<90:
                return total + 0.65
            case 150...:
                return total - 0.45
            default:
                return total
            }
        }
    }

    private static func isSession(_ session: WorkoutSession, attributableTo plan: WorkoutPlan) -> Bool {
        guard !plan.days.isEmpty, session.origin == .routine else {
            return false
        }
        let normalizedSessionTitle = normalizedPlanText(session.workoutTitle)
        if plan.days.contains(where: { normalizedPlanText($0.title) == normalizedSessionTitle }) {
            return true
        }

        let plannedExerciseIDs = Set(plan.days.flatMap(\.exercises).map(\.exercise.id))
        let plannedExerciseNames = Set(plan.days.flatMap(\.exercises).map { normalizedPlanText($0.exercise.name) })
        let sessionLogs = completedExerciseLogs(in: session)
        let matchedExerciseCount = sessionLogs.filter { log in
            plannedExerciseIDs.contains(log.exercise.id) || plannedExerciseNames.contains(normalizedPlanText(log.exercise.name))
        }.count
        return matchedExerciseCount >= max(1, min(sessionLogs.count, 2))
    }

    private static func normalizedPlanText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func planLoadState(
        adherence: Double,
        volumeThisWeek: Double,
        previousVolume: Double,
        actualWeeklySets: Int,
        targetWeeklySets: Int
    ) -> PlanLoadState {
        guard volumeThisWeek > 0 || actualWeeklySets > 0 else {
            return .noData
        }
        if targetWeeklySets > 0, actualWeeklySets > Int(Double(targetWeeklySets) * 1.35) {
            return .overreaching
        }
        if adherence < 0.67 {
            return .behind
        }
        if previousVolume > 0, volumeThisWeek < previousVolume * 0.72 {
            return .behind
        }
        return .onTrack
    }

    private static func oneRepMaxTrend(current: [WorkoutSession], previous: [WorkoutSession]) -> PlanTrendDirection {
        let currentBest = bestEstimatedOneRepMaxKg(for: current) ?? 0
        let previousBest = bestEstimatedOneRepMaxKg(for: previous) ?? 0
        guard currentBest > 0, previousBest > 0 else {
            return .flat
        }
        if currentBest > previousBest * 1.015 {
            return .up
        }
        if currentBest < previousBest * 0.985 {
            return .down
        }
        return .flat
    }

    private static func planWeeklyPoints(for plan: WorkoutPlan, sessions: [WorkoutSession], now: Date) -> [PlanWeekPoint] {
        let calendar = Calendar.current
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return (0..<6).compactMap { reverseOffset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: reverseOffset - 5, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else {
                return nil
            }
            let weekSessions = sessions.filter { $0.date >= weekStart && $0.date < weekEnd }
            return PlanWeekPoint(
                id: weekStart,
                weekStart: weekStart,
                sessions: weekSessions.count,
                targetSessions: plan.daysPerWeek,
                volumeKg: totalVolumeKg(for: weekSessions)
            )
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

enum UnitConverter {
    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms * 2.2046226218
    }

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds / 2.2046226218
    }

    static func inches(fromCentimeters centimeters: Double) -> Double {
        centimeters / 2.54
    }

    static func centimeters(fromInches inches: Double) -> Double {
        inches * 2.54
    }
}

enum AnalyticsEngine {
    struct WorkloadSummary: Equatable {
        let acuteLoad: Double
        let chronicLoad: Double
        let acwr: Double
        let fatigueScore: Double
    }

    struct MuscleTargetPoint: Identifiable, Equatable {
        var id: String { "\(muscleGroup)-\(kind)" }
        let muscleGroup: String
        let kind: String
        let sets: Int
    }

    struct ExerciseStall: Identifiable, Equatable {
        var id: UUID { exercise.id }
        let exercise: Exercise
        let latestEstimatedOneRepMaxKg: Double
        let previousBestEstimatedOneRepMaxKg: Double
        let loggedSessions: Int
    }

    enum CompetitiveAction: Equatable {
        case scheduleUndertrainedMuscle(String)
        case scheduleDeloadExercise(UUID)
        case reviewPlan
        case scheduleRecovery
        case none
    }

    struct CompetitiveRecommendation: Identifiable, Equatable {
        var id: String { "\(title)-\(systemImage)" }
        let title: String
        let message: String
        let systemImage: String
        let action: CompetitiveAction
    }

    struct CompetitiveSummary: Equatable {
        let completedWorkouts: Int
        let plannedWorkouts: Int
        let completionRate: Double
        let targetWeeklySets: Int
        let actualWeeklySets: Int
        let muscleTargets: [MuscleTargetPoint]
        let undertrainedMuscles: [MuscleTargetPoint]
        let overtrainedMuscles: [MuscleTargetPoint]
        let stalledExercises: [ExerciseStall]
        let recommendations: [CompetitiveRecommendation]
    }

    struct IntensityBucket: Identifiable, Equatable {
        let label: String
        let count: Int
        var id: String { label }
    }

    static func effectiveSets(in session: WorkoutSession) -> [SetLog] {
        FitnessMetrics.completedSets(in: session).filter { set in
            set.setType != .warmUp && (set.rpe ?? 6) >= 6
        }
    }

    static func effectiveVolumeKg(for sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { total, session in
            total + effectiveSets(in: session).reduce(0) { $0 + ($1.weightKg * Double($1.reps)) }
        }
    }

    static func sessionLoad(for session: WorkoutSession) -> Double {
        let rpe = session.sessionRPE ?? averageRPE(for: session) ?? 6
        return Double(session.durationMinutes) * rpe
    }

    static func averageRPE(for session: WorkoutSession) -> Double? {
        let rpes = FitnessMetrics.completedSets(in: session).compactMap(\.rpe)
        guard !rpes.isEmpty else {
            return nil
        }

        return rpes.reduce(0, +) / Double(rpes.count)
    }

    static func intensityDistribution(for sessions: [WorkoutSession]) -> [IntensityBucket] {
        let buckets: [(label: String, range: ClosedRange<Double>)] = [
            ("RPE 0-5", 0...5.99),
            ("RPE 6-7", 6...7.99),
            ("RPE 8", 8...8.99),
            ("RPE 9-10", 9...10)
        ]
        let rpes = sessions.flatMap(FitnessMetrics.completedSets(in:)).compactMap(\.rpe)
        return buckets.map { bucket in
            IntensityBucket(label: bucket.label, count: rpes.filter { bucket.range.contains($0) }.count)
        }
    }

    static func workloadSummary(sessions: [WorkoutSession], bodyMetrics: [BodyMetric], now: Date = .now) -> WorkloadSummary {
        let calendar = Calendar.current
        let acuteStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let chronicStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let acuteSessions = sessions.filter { $0.date >= acuteStart && $0.date <= now }
        let chronicSessions = sessions.filter { $0.date >= chronicStart && $0.date <= now }

        let acuteLoad = acuteSessions.reduce(0) { $0 + sessionLoad(for: $1) }
        let chronicWeeklyLoad = chronicSessions.reduce(0) { $0 + sessionLoad(for: $1) } / 4
        let acwr = chronicWeeklyLoad > 0 ? acuteLoad / chronicWeeklyLoad : 0
        let latestWellness = bodyMetrics.sorted { $0.date > $1.date }.first
        let wellnessPenalty = Double((latestWellness?.fatigue ?? 3) + (latestWellness?.stress ?? 3)) * 4
        let sleepPenalty = max(0, 7 - (latestWellness?.sleepHours ?? 7)) * 5
        let workloadPenalty = min(max((acwr - 0.8) * 35, 0), 45)
        let fatigueScore = min(max(wellnessPenalty + sleepPenalty + workloadPenalty, 0), 100)

        return WorkloadSummary(
            acuteLoad: acuteLoad,
            chronicLoad: chronicWeeklyLoad,
            acwr: acwr,
            fatigueScore: fatigueScore
        )
    }

    static func competitiveSummary(
        sessions: [WorkoutSession],
        activePlan: WorkoutPlan,
        exercises: [Exercise],
        since startDate: Date,
        now: Date = .now
    ) -> CompetitiveSummary {
        let recentSessions = sessions.filter { $0.date >= startDate && $0.date <= now }
        let completedWorkouts = recentSessions.count
        let plannedWorkouts = max(activePlan.daysPerWeek, 0)
        let completionRate = FitnessMetrics.weeklyCompletion(
            completedWorkouts: completedWorkouts,
            plannedWorkouts: plannedWorkouts
        )

        let actualByMuscle = muscleSetBuckets(from: recentSessions)
        let targetByMuscle = plannedSetBuckets(from: activePlan)
        let allMuscles = Set(actualByMuscle.keys).union(targetByMuscle.keys)
        let targetWeeklySets = targetByMuscle.values.reduce(0, +)
        let actualWeeklySets = actualByMuscle.values.reduce(0, +)

        let muscleTargets = allMuscles.sorted().flatMap { muscle -> [MuscleTargetPoint] in
            [
                MuscleTargetPoint(muscleGroup: muscle, kind: localizedString("muscle_target_kind_target"), sets: targetByMuscle[muscle, default: 0]),
                MuscleTargetPoint(muscleGroup: muscle, kind: localizedString("muscle_target_kind_actual"), sets: actualByMuscle[muscle, default: 0])
            ]
        }

        let undertrained = allMuscles.compactMap { muscle -> MuscleTargetPoint? in
            let target = targetByMuscle[muscle, default: 0]
            let actual = actualByMuscle[muscle, default: 0]
            guard target >= 4, actual < Int(Double(target) * 0.75) else { return nil }
            return MuscleTargetPoint(muscleGroup: muscle, kind: localizedString("muscle_target_kind_missing"), sets: target - actual)
        }
        .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : $0.muscleGroup < $1.muscleGroup }

        let overtrained = allMuscles.compactMap { muscle -> MuscleTargetPoint? in
            let target = targetByMuscle[muscle, default: 0]
            let actual = actualByMuscle[muscle, default: 0]
            guard target > 0, actual > Int(Double(target) * 1.35) else { return nil }
            return MuscleTargetPoint(muscleGroup: muscle, kind: localizedString("muscle_target_kind_excess"), sets: actual - target)
        }
        .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : $0.muscleGroup < $1.muscleGroup }

        let stalled = stalledExercises(in: exercises, sessions: sessions)
        let recommendations = competitiveRecommendations(
            completionRate: completionRate,
            undertrainedMuscles: undertrained,
            overtrainedMuscles: overtrained,
            stalledExercises: stalled,
            actualWeeklySets: actualWeeklySets,
            targetWeeklySets: targetWeeklySets
        )

        return CompetitiveSummary(
            completedWorkouts: completedWorkouts,
            plannedWorkouts: plannedWorkouts,
            completionRate: completionRate,
            targetWeeklySets: targetWeeklySets,
            actualWeeklySets: actualWeeklySets,
            muscleTargets: muscleTargets,
            undertrainedMuscles: Array(undertrained.prefix(4)),
            overtrainedMuscles: Array(overtrained.prefix(4)),
            stalledExercises: Array(stalled.prefix(5)),
            recommendations: recommendations
        )
    }

    private static func muscleSetBuckets(from sessions: [WorkoutSession]) -> [String: Int] {
        var buckets: [String: Int] = [:]
        sessions
            .flatMap(FitnessMetrics.completedExerciseLogs(in:))
            .forEach { log in
                buckets[log.exercise.muscleGroup, default: 0] += log.sets.count
            }
        return buckets
    }

    private static func plannedSetBuckets(from plan: WorkoutPlan) -> [String: Int] {
        var buckets: [String: Int] = [:]
        plan.days
            .prefix(max(plan.daysPerWeek, 0))
            .flatMap(\.exercises)
            .forEach { item in
                buckets[item.exercise.muscleGroup, default: 0] += max(item.targetSets, 0)
            }
        return buckets
    }

    private static func stalledExercises(in exercises: [Exercise], sessions: [WorkoutSession]) -> [ExerciseStall] {
        exercises.compactMap { exercise in
            let points = FitnessMetrics.progressPoints(for: exercise, in: sessions)
            guard points.count >= 4 else { return nil }
            let latestWindow = points.suffix(3)
            let latestBest = latestWindow.map(\.estimatedOneRepMaxKg).max() ?? 0
            let previousBest = points.dropLast(3).map(\.estimatedOneRepMaxKg).max() ?? 0
            guard previousBest > 0, latestBest <= previousBest * 1.005 else { return nil }
            return ExerciseStall(
                exercise: exercise,
                latestEstimatedOneRepMaxKg: latestBest,
                previousBestEstimatedOneRepMaxKg: previousBest,
                loggedSessions: points.count
            )
        }
        .sorted {
            if $0.loggedSessions == $1.loggedSessions {
                return $0.exercise.name < $1.exercise.name
            }
            return $0.loggedSessions > $1.loggedSessions
        }
    }

    private static func competitiveRecommendations(
        completionRate: Double,
        undertrainedMuscles: [MuscleTargetPoint],
        overtrainedMuscles: [MuscleTargetPoint],
        stalledExercises: [ExerciseStall],
        actualWeeklySets: Int,
        targetWeeklySets: Int
    ) -> [CompetitiveRecommendation] {
        var recommendations: [CompetitiveRecommendation] = []

        if completionRate < 0.75 {
            recommendations.append(CompetitiveRecommendation(
                title: localizedString("recommendation_adherence_title"),
                message: localizedString("recommendation_adherence_msg"),
                systemImage: "calendar.badge.exclamationmark",
                action: .reviewPlan
            ))
        }

        if let muscle = undertrainedMuscles.first {
            recommendations.append(CompetitiveRecommendation(
                title: localizedFormat("recommendation_prioritize_format", muscle.muscleGroup),
                message: localizedFormat("recommendation_prioritize_msg_format", muscle.sets),
                systemImage: "target",
                action: .scheduleUndertrainedMuscle(muscle.muscleGroup)
            ))
        }

        if let muscle = overtrainedMuscles.first {
            recommendations.append(CompetitiveRecommendation(
                title: localizedFormat("recommendation_control_format", muscle.muscleGroup),
                message: localizedFormat("recommendation_control_msg_format", muscle.sets),
                systemImage: "gauge.with.needle",
                action: .scheduleRecovery
            ))
        }

        if let stalled = stalledExercises.first {
            recommendations.append(CompetitiveRecommendation(
                title: localizedString("recommendation_break_plateau_title"),
                message: localizedFormat("recommendation_break_plateau_msg_format", stalled.exercise.name),
                systemImage: "arrow.triangle.2.circlepath",
                action: .scheduleDeloadExercise(stalled.exercise.id)
            ))
        }

        if recommendations.isEmpty {
            let delta = actualWeeklySets - targetWeeklySets
            recommendations.append(CompetitiveRecommendation(
                title: localizedString("recommendation_balanced_week_title"),
                message: delta >= 0
                    ? localizedString("recommendation_balanced_week_msg_on_target")
                    : localizedFormat("recommendation_balanced_week_msg_off_format", abs(delta)),
                systemImage: "checkmark.seal",
                action: .none
            ))
        }

        return Array(recommendations.prefix(4))
    }
}

enum ProgressionEngine {
    struct Suggestion: Equatable {
        let targetWeightKg: Double
        let targetReps: Int
        let shouldDeload: Bool
        let explanation: String
    }

    static func nextSuggestion(
        for item: WorkoutExercise,
        recentSets: [SetLog],
        repRange: ClosedRange<Int>? = nil,
        weightIncrementKg: Double = 2.5
    ) -> Suggestion {
        let completed = recentSets.filter(\.completed)
        guard !completed.isEmpty else {
            return Suggestion(
                targetWeightKg: 0,
                targetReps: repRange?.lowerBound ?? defaultLowerRep(from: item.repRange),
                shouldDeload: false,
                explanation: localizedString("prog_no_history")
            )
        }

        let range = repRange ?? parsedRepRange(item.repRange)
        let lastWeight = completed.map(\.weightKg).max() ?? 0
        let highEffort = completed.contains { ($0.rpe ?? 0) >= 9 || ($0.rir ?? 5) <= 0 }
        let allHitTop = completed.count >= item.targetSets && completed.allSatisfy { $0.reps >= range.upperBound }
        let missedBottom = completed.contains { $0.reps < range.lowerBound }
        let stalled = isStalled(recentSets: completed)

        if stalled && highEffort {
            return Suggestion(
                targetWeightKg: rounded(max(lastWeight * 0.9, 0), increment: weightIncrementKg),
                targetReps: range.lowerBound,
                shouldDeload: true,
                explanation: localizedString("prog_deload_stalled")
            )
        }

        switch item.progressionType {
        case .linear:
            if allHitTop && !highEffort {
                return Suggestion(
                    targetWeightKg: rounded(lastWeight + item.incrementKg, increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: localizedString("prog_completed_with_margin")
                )
            }
        case .doubleProgression:
            if allHitTop && !highEffort {
                return Suggestion(
                    targetWeightKg: rounded(lastWeight + item.incrementKg, increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: localizedString("prog_closed_rep_range")
                )
            }
            return Suggestion(
                targetWeightKg: rounded(lastWeight, increment: weightIncrementKg),
                targetReps: min((completed.map(\.reps).min() ?? range.lowerBound) + 1, range.upperBound),
                shouldDeload: false,
                explanation: localizedString("prog_maintain_add_rep")
            )
        case .rpeTarget:
            if highEffort {
                return Suggestion(
                    targetWeightKg: rounded(max(lastWeight - item.incrementKg, 0), increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: localizedString("prog_high_effort_lower")
                )
            }
        case .percentOneRepMax:
            let estimatedTrainingMax = completed
                .map { FitnessMetrics.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }
                .max() ?? lastWeight
            let targetPercent = parsedPercent(from: item.repRange) ?? 0.75
            return Suggestion(
                targetWeightKg: rounded(estimatedTrainingMax * targetPercent, increment: weightIncrementKg),
                targetReps: range.lowerBound,
                shouldDeload: false,
                explanation: localizedFormat("prog_target_percent_1rm_format", Int(targetPercent * 100))
            )
        case .none:
            break
        }

        if missedBottom && highEffort {
            return Suggestion(
                targetWeightKg: rounded(max(lastWeight * 0.9, 0), increment: weightIncrementKg),
                targetReps: range.lowerBound,
                shouldDeload: true,
                explanation: localizedString("prog_missed_min_high_effort")
            )
        }

        return Suggestion(
            targetWeightKg: rounded(lastWeight, increment: weightIncrementKg),
            targetReps: range.lowerBound,
            shouldDeload: false,
            explanation: localizedString("prog_maintain_good_technique")
        )
    }

    static func rounded(_ weight: Double, increment: Double) -> Double {
        guard increment > 0 else {
            return weight
        }

        return (weight / increment).rounded() * increment
    }

    static func parsedRepRange(_ text: String) -> ClosedRange<Int> {
        let values = text.split { !$0.isNumber }.compactMap { Int($0) }
        let repValues = values.filter { $0 <= 30 }
        guard let first = repValues.first else {
            return 8...12
        }

        let second = repValues.dropFirst().first ?? first
        return min(first, second)...max(first, second)
    }

    static func isStalled(recentSets: [SetLog], sessionsThreshold: Int = 3) -> Bool {
        let completed = recentSets.filter(\.completed)
        guard completed.count >= sessionsThreshold else {
            return false
        }

        let latest = completed.prefix(sessionsThreshold)
        let bestLatest = latest.map { FitnessMetrics.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? 0
        let previousBest = completed.dropFirst(sessionsThreshold).map { FitnessMetrics.estimatedOneRepMax(weightKg: $0.weightKg, reps: $0.reps) }.max() ?? bestLatest
        return bestLatest <= previousBest
    }

    private static func parsedPercent(from text: String) -> Double? {
        let values = text.split { !$0.isNumber }.compactMap { Double($0) }
        guard let percent = values.first(where: { $0 > 20 && $0 <= 100 }) else {
            return nil
        }
        return percent / 100
    }

    private static func defaultLowerRep(from text: String) -> Int {
        parsedRepRange(text).lowerBound
    }
}

enum ExerciseSubstitutionService {
    static func candidates(
        for exercise: Exercise,
        in exercises: [Exercise],
        availableEquipment: [String],
        limit: Int = 8
    ) -> [Exercise] {
        let equipment = Set(availableEquipment.map(normalized))
        return exercises
            .filter { candidate in
                candidate.id != exercise.id
                && normalized(candidate.muscleGroup) == normalized(exercise.muscleGroup)
                && (candidate.environment != .gym || exercise.environment == .gym || exercise.environment == .both)
            }
            .filter { candidate in
                guard !equipment.isEmpty else { return true }
                let required = candidate.requiredEquipment.isEmpty ? [candidate.equipment] : candidate.requiredEquipment
                let normalizedRequired = Set(required.map(normalized))
                return normalizedRequired.isEmpty
                    || normalizedRequired.contains("bodyweight")
                    || !normalizedRequired.isDisjoint(with: equipment)
                    || equipment.contains(normalized(candidate.equipment))
            }
            .sorted { lhs, rhs in
                let lhsScore = substitutionScore(lhs, original: exercise)
                let rhsScore = substitutionScore(rhs, original: exercise)
                if lhsScore == rhsScore {
                    return lhs.name < rhs.name
                }
                return lhsScore > rhsScore
            }
            .prefix(limit)
            .map { $0 }
    }

    static func matchReasons(
        for candidate: Exercise,
        replacing original: Exercise,
        availableEquipment: [String]
    ) -> [String] {
        var reasons: [String] = []
        if normalized(candidate.muscleGroup) == normalized(original.muscleGroup) {
            reasons.append(localizedString("match_reason_same_muscle_group"))
        }
        if normalized(candidate.equipment) == normalized(original.equipment) {
            reasons.append(localizedString("match_reason_same_equipment"))
        }
        if matchesAvailableEquipment(candidate, availableEquipment: availableEquipment) {
            reasons.append(localizedString("match_reason_available_equipment"))
        }
        if candidate.trackingType == original.trackingType {
            reasons.append(localizedString("match_reason_same_tracking"))
        }
        if candidate.environment == original.environment || candidate.environment == .both {
            reasons.append(localizedString("match_reason_same_environment"))
        }

        return Array(reasons.prefix(3))
    }

    private static func substitutionScore(_ candidate: Exercise, original: Exercise) -> Int {
        var score = 0
        if normalized(candidate.equipment) == normalized(original.equipment) { score += 3 }
        if candidate.trackingType == original.trackingType { score += 2 }
        if candidate.difficulty == original.difficulty { score += 1 }
        if candidate.environment == original.environment || candidate.environment == .both { score += 1 }
        return score
    }

    private static func matchesAvailableEquipment(_ exercise: Exercise, availableEquipment: [String]) -> Bool {
        let equipment = Set(availableEquipment.map(normalized))
        guard !equipment.isEmpty else { return true }

        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(normalized))
        return normalizedRequired.isEmpty
            || normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: equipment)
            || equipment.contains(normalized(exercise.equipment))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

struct PlateLoadItem: Identifiable, Equatable {
    var id: Double { weightKg }
    let weightKg: Double
    let count: Int
}

enum PlateLoadingCalculator {
    static let defaultMetricPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]

    static func platesPerSide(
        targetWeightKg: Double,
        barWeightKg: Double = 20,
        availablePlatesKg: [Double] = defaultMetricPlates
    ) -> [PlateLoadItem] {
        guard targetWeightKg > barWeightKg else { return [] }

        var remaining = (targetWeightKg - barWeightKg) / 2
        var items: [PlateLoadItem] = []

        for plate in availablePlatesKg.sorted(by: >) where plate > 0 {
            let count = Int(remaining / plate)
            guard count > 0 else { continue }
            items.append(PlateLoadItem(weightKg: plate, count: count))
            remaining -= Double(count) * plate
        }

        return items
    }

    static func loadSummary(
        targetWeightKg: Double,
        barWeightKg: Double = 20,
        availablePlatesKg: [Double] = defaultMetricPlates
    ) -> String? {
        let plates = platesPerSide(
            targetWeightKg: targetWeightKg,
            barWeightKg: barWeightKg,
            availablePlatesKg: availablePlatesKg
        )
        guard !plates.isEmpty else { return nil }

        return plates
            .map { item in
                let weight = item.weightKg.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(item.weightKg))"
                    : String(format: "%.2f", item.weightKg).replacingOccurrences(of: ".00", with: "")
                return "\(item.count)x\(weight)"
            }
            .joined(separator: " + ")
    }
}

enum WorkoutSetBuilder {
    static func warmUpSets(targetWeightKg: Double, targetReps: Int) -> [SetLog] {
        guard targetWeightKg >= 20 else { return [] }

        let steps: [(Double, Int)] = [
            (0.40, max(targetReps, 8)),
            (0.60, min(max(targetReps - 2, 5), 8)),
            (0.80, min(max(targetReps - 4, 3), 5))
        ]

        return steps.enumerated().map { index, step in
            SetLog(
                setNumber: index + 1,
                weightKg: roundedToNearestIncrement(targetWeightKg * step.0),
                reps: step.1,
                completed: false,
                setType: .warmUp
            )
        }
    }

    static func dropSet(after set: SetLog) -> SetLog {
        SetLog(
            setNumber: set.setNumber + 1,
            weightKg: roundedToNearestIncrement(set.weightKg * 0.75),
            reps: max(set.reps + 4, 8),
            completed: false,
            setType: .dropSet
        )
    }

    static func backOffSet(after set: SetLog) -> SetLog {
        SetLog(
            setNumber: set.setNumber + 1,
            weightKg: roundedToNearestIncrement(set.weightKg * 0.90),
            reps: max(set.reps + 2, 6),
            completed: false,
            setType: .backOff
        )
    }

    static func renumbered(_ sets: [SetLog]) -> [SetLog] {
        sets.enumerated().map { index, set in
            var copy = set
            copy.setNumber = index + 1
            return copy
        }
    }

    private static func roundedToNearestIncrement(_ weightKg: Double, increment: Double = 2.5) -> Double {
        guard increment > 0 else { return weightKg }
        return max(0, (weightKg / increment).rounded() * increment)
    }
}

enum ExerciseHistoryAnalyzer {
    static func recentCompletedSets(
        for exercise: Exercise,
        in sessions: [WorkoutSession],
        limit: Int = 12
    ) -> [SetLog] {
        sessions
            .sorted { $0.date > $1.date }
            .flatMap { session in
                (session.exerciseLogs ?? []).filter { log in
                    log.exercise.id == exercise.id || normalizedExerciseName(log.exercise.name) == normalizedExerciseName(exercise.name)
                }
                .flatMap(\.sets)
            }
            .filter(\.completed)
            .prefix(limit)
            .map { $0 }
    }

    static func isPersonalRecord(_ set: SetLog, for exercise: Exercise, in sessions: [WorkoutSession]) -> Bool {
        let points = FitnessMetrics.progressPoints(for: exercise, in: sessions)
        let previousBestWeight = points.map(\.maxWeightKg).max() ?? 0
        let previousBestOneRepMax = points.map(\.estimatedOneRepMaxKg).max() ?? 0
        let estimatedOneRepMax = FitnessMetrics.estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
        return set.weightKg > previousBestWeight || estimatedOneRepMax > previousBestOneRepMax
    }

    static func normalizedExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

enum WorkoutDraftController {
    struct PendingSet: Equatable {
        let exerciseIndex: Int
        let setIndex: Int
        let exerciseName: String
        let setNumber: Int
    }

    struct CompletionOutcome: Equatable {
        let restDurationSeconds: Int?
        let shouldMoveToNextExercise: Bool
        let didFinishWorkout: Bool
    }

    static func makeDrafts(for workout: WorkoutDay) -> [ExerciseSessionDraft] {
        workout.exercises.map(makeDraft(for:))
    }

    static func makeDraft(for exercise: Exercise) -> ExerciseSessionDraft {
        makeDraft(
            for: WorkoutExercise(
                exercise: exercise,
                targetSets: 3,
                repRange: defaultRepRange(for: exercise),
                previous: "-"
            )
        )
    }

    static func makeDraft(for item: WorkoutExercise) -> ExerciseSessionDraft {
        let sets = (1...max(item.targetSets, 1)).map { index in
            SetLog(
                setNumber: index,
                weightKg: item.exercise.trackingType == .weightReps ? defaultWeight(from: item.previous) : 0,
                reps: defaultReps(from: item.repRange),
                completed: false
            )
        }
        return ExerciseSessionDraft(workoutExercise: item, notes: "", sets: sets)
    }

    @discardableResult
    static func addExercise(_ exercise: Exercise, to drafts: inout [ExerciseSessionDraft]) -> Int {
        drafts.append(makeDraft(for: exercise))
        return max(drafts.count - 1, 0)
    }

    @discardableResult
    static func replaceExercise(at index: Int, with exercise: Exercise, in drafts: inout [ExerciseSessionDraft]) -> Bool {
        guard drafts.indices.contains(index) else { return false }

        var replacement = makeDraft(for: exercise)
        let currentSets = drafts[index].sets
        if !currentSets.isEmpty {
            replacement.sets = currentSets.enumerated().map { offset, set in
                SetLog(
                    setNumber: offset + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    completed: set.completed,
                    setType: set.setType,
                    rpe: set.rpe,
                    rir: set.rir,
                    tempo: set.tempo,
                    previousRestSeconds: set.previousRestSeconds,
                    isPersonalRecord: false,
                    notes: set.notes
                )
            }
        }
        drafts[index] = replacement
        return true
    }

    @discardableResult
    static func removeExercise(at index: Int, from drafts: inout [ExerciseSessionDraft]) -> Int? {
        guard drafts.indices.contains(index) else { return nil }

        drafts.remove(at: index)
        return max(0, min(index, drafts.count - 1))
    }

    @discardableResult
    static func moveExercise(
        from source: Int,
        to destination: Int,
        in drafts: inout [ExerciseSessionDraft],
        selectedWorkoutExerciseID: UUID?
    ) -> Int? {
        guard drafts.indices.contains(source),
              drafts.indices.contains(destination),
              source != destination else {
            return nil
        }

        let draft = drafts.remove(at: source)
        drafts.insert(draft, at: destination)
        if let selectedWorkoutExerciseID,
           let newIndex = drafts.firstIndex(where: { $0.workoutExercise.id == selectedWorkoutExerciseID }) {
            return newIndex
        }
        return min(max(destination, 0), drafts.count - 1)
    }

    @discardableResult
    static func applyAutoProgression(
        to drafts: inout [ExerciseSessionDraft],
        sessions: [WorkoutSession],
        weightIncrementKg: Double
    ) -> Bool {
        var didApply = false

        for index in drafts.indices {
            let item = drafts[index].workoutExercise
            let recentSets = ExerciseHistoryAnalyzer.recentCompletedSets(for: item.exercise, in: sessions)
            guard !recentSets.isEmpty else {
                continue
            }

            let suggestion = ProgressionEngine.nextSuggestion(
                for: item,
                recentSets: recentSets,
                weightIncrementKg: weightIncrementKg
            )
            guard suggestion.targetWeightKg > 0 else {
                continue
            }

            for setIndex in drafts[index].sets.indices where !drafts[index].sets[setIndex].completed {
                drafts[index].sets[setIndex].weightKg = suggestion.targetWeightKg
                drafts[index].sets[setIndex].reps = suggestion.targetReps
                didApply = true
            }
        }

        return didApply
    }

    /// Short transition rest applied when alternating between members of the same
    /// superset (vs. the exercise's full rest once a round is closed).
    static let supersetTransitionRestSeconds = 15

    static func nextIncompleteSet(in drafts: [ExerciseSessionDraft]) -> PendingSet? {
        for exerciseIndex in drafts.indices {
            guard drafts[exerciseIndex].sets.contains(where: { !$0.completed }) else { continue }

            // When the earliest remaining exercise is part of a superset, alternate
            // round-robin across the group's members (fewest completed sets first,
            // ties broken by order) so the user logs A1, B1, A2, B2, …
            if let group = drafts[exerciseIndex].workoutExercise.supersetGroup,
               let pick = nextSupersetMemberIndex(group: group, in: drafts),
               let setIndex = drafts[pick].sets.firstIndex(where: { !$0.completed }) {
                return PendingSet(
                    exerciseIndex: pick,
                    setIndex: setIndex,
                    exerciseName: drafts[pick].workoutExercise.exercise.name,
                    setNumber: drafts[pick].sets[setIndex].setNumber
                )
            }

            let setIndex = drafts[exerciseIndex].sets.firstIndex(where: { !$0.completed }) ?? 0
            let draft = drafts[exerciseIndex]
            return PendingSet(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                exerciseName: draft.workoutExercise.exercise.name,
                setNumber: draft.sets[setIndex].setNumber
            )
        }

        return nil
    }

    /// Indices of all drafts belonging to a superset group, in session order.
    static func supersetMemberIndices(_ group: UUID, in drafts: [ExerciseSessionDraft]) -> [Int] {
        drafts.indices.filter { drafts[$0].workoutExercise.supersetGroup == group }
    }

    private static func nextSupersetMemberIndex(group: UUID, in drafts: [ExerciseSessionDraft]) -> Int? {
        supersetMemberIndices(group, in: drafts)
            .filter { drafts[$0].sets.contains(where: { !$0.completed }) }
            .min { lhs, rhs in
                let lc = drafts[lhs].sets.filter(\.completed).count
                let rc = drafts[rhs].sets.filter(\.completed).count
                return lc != rc ? lc < rc : lhs < rhs
            }
    }

    @discardableResult
    static func completeSet(
        in drafts: inout [ExerciseSessionDraft],
        exerciseIndex: Int,
        setIndex: Int,
        elapsedSeconds: Int,
        lastSetCompletedAtSeconds: Int?,
        isPersonalRecord: Bool,
        betweenExercisesRestSeconds: Int
    ) -> CompletionOutcome? {
        guard drafts.indices.contains(exerciseIndex),
              drafts[exerciseIndex].sets.indices.contains(setIndex) else {
            return nil
        }

        if let lastSetCompletedAtSeconds {
            drafts[exerciseIndex].sets[setIndex].previousRestSeconds = max(elapsedSeconds - lastSetCompletedAtSeconds, 0)
        }
        drafts[exerciseIndex].sets[setIndex].completed = true
        drafts[exerciseIndex].sets[setIndex].isPersonalRecord = isPersonalRecord

        let completedSet = drafts[exerciseIndex].sets[setIndex]
        // Carry weight/reps forward to the next set of the same exercise as a
        // sensible default (used both for the immediate next set and for when a
        // superset rotation returns to this exercise).
        let nextSetIndex = setIndex + 1
        if drafts[exerciseIndex].sets.indices.contains(nextSetIndex),
           !drafts[exerciseIndex].sets[nextSetIndex].completed {
            drafts[exerciseIndex].sets[nextSetIndex].weightKg = completedSet.weightKg
            drafts[exerciseIndex].sets[nextSetIndex].reps = completedSet.reps
        }

        // Superset rotation: while the group still owes work, alternate to the
        // next member with a short transition rest; once every member has caught
        // up to this exercise's completed-set count a round is closed, so apply
        // the exercise's full rest before the next round begins.
        if let group = drafts[exerciseIndex].workoutExercise.supersetGroup {
            let members = supersetMemberIndices(group, in: drafts)
            let groupHasRemaining = members.contains { drafts[$0].sets.contains { !$0.completed } }
            if groupHasRemaining {
                let myCompleted = drafts[exerciseIndex].sets.filter(\.completed).count
                let roundClosed = members
                    .filter { $0 != exerciseIndex }
                    .allSatisfy { drafts[$0].sets.filter(\.completed).count >= myCompleted }
                return CompletionOutcome(
                    restDurationSeconds: roundClosed ? drafts[exerciseIndex].workoutExercise.restSeconds : supersetTransitionRestSeconds,
                    shouldMoveToNextExercise: true,
                    didFinishWorkout: false
                )
            }
            // Group fully complete — fall through to the linear next-exercise logic.
        }

        // Linear flow: rest in place if this exercise still has sets, otherwise
        // move to whatever remains next, or finish.
        if let next = nextIncompleteSet(in: drafts) {
            if next.exerciseIndex == exerciseIndex {
                return CompletionOutcome(
                    restDurationSeconds: drafts[exerciseIndex].workoutExercise.restSeconds,
                    shouldMoveToNextExercise: false,
                    didFinishWorkout: false
                )
            }
            return CompletionOutcome(
                restDurationSeconds: betweenExercisesRestSeconds,
                shouldMoveToNextExercise: true,
                didFinishWorkout: false
            )
        }

        return CompletionOutcome(
            restDurationSeconds: nil,
            shouldMoveToNextExercise: false,
            didFinishWorkout: true
        )
    }

    /// Links the exercise at `index` with the one immediately after it into a
    /// superset (or splits them apart if already linked). Adjacent linked
    /// exercises form a single group; singletons are cleared.
    static func toggleSupersetLink(at index: Int, in drafts: inout [ExerciseSessionDraft]) {
        toggleSupersetLink(at: index, in: &drafts, supersetGroup: \.workoutExercise.supersetGroup)
    }

    /// Any superset group left with a single member is dissolved.
    static func normalizeSupersetSingletons(in drafts: inout [ExerciseSessionDraft]) {
        normalizeSupersetSingletons(in: &drafts, supersetGroup: \.workoutExercise.supersetGroup)
    }

    /// Links the item at `index` with the one immediately after it into a
    /// superset (or splits them apart if already linked). Adjacent linked
    /// items form a single group; singletons are cleared. Generic over the
    /// keypath to `supersetGroup` so it works both on live-session drafts
    /// (`ExerciseSessionDraft.workoutExercise.supersetGroup`) and plan
    /// authoring data (`WorkoutExercise.supersetGroup`) with one implementation.
    static func toggleSupersetLink<T>(at index: Int, in items: inout [T], supersetGroup: WritableKeyPath<T, UUID?>) {
        guard items.indices.contains(index), items.indices.contains(index + 1) else { return }

        let groupA = items[index][keyPath: supersetGroup]
        let groupB = items[index + 1][keyPath: supersetGroup]
        let alreadyLinked = groupA != nil && groupA == groupB

        if alreadyLinked, let group = groupA {
            // Split the run between index and index+1: everything from index+1
            // onward sharing the group moves to a fresh group.
            let newGroup = UUID()
            for i in (index + 1)..<items.count {
                guard items[i][keyPath: supersetGroup] == group else { break }
                items[i][keyPath: supersetGroup] = newGroup
            }
        } else {
            // Merge index and index+1 (and any run already attached to index+1).
            let target = groupA ?? UUID()
            items[index][keyPath: supersetGroup] = target
            if let groupB {
                for i in items.indices where items[i][keyPath: supersetGroup] == groupB {
                    items[i][keyPath: supersetGroup] = target
                }
            } else {
                items[index + 1][keyPath: supersetGroup] = target
            }
        }

        normalizeSupersetSingletons(in: &items, supersetGroup: supersetGroup)
    }

    static func normalizeSupersetSingletons<T>(in items: inout [T], supersetGroup: WritableKeyPath<T, UUID?>) {
        var counts: [UUID: Int] = [:]
        for item in items {
            if let group = item[keyPath: supersetGroup] { counts[group, default: 0] += 1 }
        }
        for i in items.indices {
            if let group = items[i][keyPath: supersetGroup], counts[group] ?? 0 < 2 {
                items[i][keyPath: supersetGroup] = nil
            }
        }
    }

    @discardableResult
    static func uncompleteSet(
        in drafts: inout [ExerciseSessionDraft],
        exerciseIndex: Int,
        setIndex: Int
    ) -> Bool {
        guard drafts.indices.contains(exerciseIndex),
              drafts[exerciseIndex].sets.indices.contains(setIndex),
              drafts[exerciseIndex].sets[setIndex].completed else {
            return false
        }

        drafts[exerciseIndex].sets[setIndex].completed = false
        drafts[exerciseIndex].sets[setIndex].isPersonalRecord = false
        drafts[exerciseIndex].sets[setIndex].previousRestSeconds = nil
        return true
    }

    @discardableResult
    static func removeSet(from drafts: inout [ExerciseSessionDraft], exerciseIndex: Int, setIndex: Int) -> Bool {
        guard drafts.indices.contains(exerciseIndex),
              drafts[exerciseIndex].sets.indices.contains(setIndex) else {
            return false
        }
        drafts[exerciseIndex].sets.remove(at: setIndex)
        drafts[exerciseIndex].sets = WorkoutSetBuilder.renumbered(drafts[exerciseIndex].sets)
        return true
    }

    @discardableResult
    static func addSet(to drafts: inout [ExerciseSessionDraft], selectedIndex: Int) -> Bool {
        guard drafts.indices.contains(selectedIndex) else { return false }

        let previous = drafts[selectedIndex].sets.last
        drafts[selectedIndex].sets.append(
            SetLog(
                setNumber: drafts[selectedIndex].sets.count + 1,
                weightKg: previous?.weightKg ?? 0,
                reps: previous?.reps ?? 8,
                completed: false
            )
        )
        return true
    }

    @discardableResult
    static func insertWarmUpSets(
        to drafts: inout [ExerciseSessionDraft],
        selectedIndex: Int,
        targetSet: SetLog?
    ) -> Bool {
        guard drafts.indices.contains(selectedIndex),
              let targetSet,
              targetSet.weightKg >= 20,
              !drafts[selectedIndex].sets.contains(where: { $0.setType == .warmUp }) else {
            return false
        }

        let warmUps = WorkoutSetBuilder.warmUpSets(
            targetWeightKg: targetSet.weightKg,
            targetReps: targetSet.reps
        )
        guard !warmUps.isEmpty else { return false }

        let existing = drafts[selectedIndex].sets
        let firstWorkIndex = existing.firstIndex { $0.setType != .warmUp } ?? 0
        let updated = Array(existing[..<firstWorkIndex]) + warmUps + Array(existing[firstWorkIndex...])
        drafts[selectedIndex].sets = WorkoutSetBuilder.renumbered(updated)
        return true
    }

    @discardableResult
    static func appendDropSet(to drafts: inout [ExerciseSessionDraft], selectedIndex: Int) -> Bool {
        appendSpecialSet(to: &drafts, selectedIndex: selectedIndex) { WorkoutSetBuilder.dropSet(after: $0) }
    }

    @discardableResult
    static func appendBackOffSet(to drafts: inout [ExerciseSessionDraft], selectedIndex: Int) -> Bool {
        appendSpecialSet(to: &drafts, selectedIndex: selectedIndex) { WorkoutSetBuilder.backOffSet(after: $0) }
    }

    @discardableResult
    private static func appendSpecialSet(
        to drafts: inout [ExerciseSessionDraft],
        selectedIndex: Int,
        build: (SetLog) -> SetLog
    ) -> Bool {
        guard drafts.indices.contains(selectedIndex),
              let reference = drafts[selectedIndex].sets.last(where: { $0.weightKg > 0 }) ?? drafts[selectedIndex].sets.last else {
            return false
        }

        var next = build(reference)
        next.completed = false
        drafts[selectedIndex].sets.append(next)
        drafts[selectedIndex].sets = WorkoutSetBuilder.renumbered(drafts[selectedIndex].sets)
        return true
    }

    private static func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "8-15"
        case .duration: "30-45 sec"
        }
    }

    private static func defaultWeight(from previous: String) -> Double {
        let normalized = previous.replacingOccurrences(of: ",", with: ".")
        let number = normalized
            .split { character in
                !(character.isNumber || character == ".")
            }
            .compactMap { Double($0) }
            .first
        return number ?? 0
    }

    private static func defaultReps(from repRange: String) -> Int {
        let digits = repRange.split { !$0.isNumber }.compactMap { Int($0) }
        return digits.first ?? 8
    }
}

enum SelectedExerciseContextBuilder {
    struct Input {
        let draft: ExerciseSessionDraft?
        let recentSets: [SetLog]
        let hasConfigurableProgressionAccess: Bool
        let autoProgressionEnabled: Bool
        let weightIncrementKg: Double
    }

    struct Context: Equatable {
        let currentWorkingSet: SetLog?
        let targetWeightKg: Double?
        let plateLoadSummary: String?
        let historySummary: String?
        let suggestionText: String?
        let canInsertWarmUpSets: Bool
        let canAppendAdvancedSet: Bool
        let toolsCaption: String
    }

    static func context(from input: Input) -> Context {
        let currentWorkingSet = input.draft?.sets.first(where: { !$0.completed }) ?? input.draft?.sets.last
        let targetWeightKg = currentWorkingSet.flatMap { $0.weightKg > 0 ? $0.weightKg : nil }
        let plateLoadSummary = plateLoadSummary(for: input.draft?.workoutExercise.exercise, targetWeightKg: targetWeightKg)
        let canInsertWarmUpSets = canInsertWarmUpSets(draft: input.draft, targetWeightKg: targetWeightKg)
        let canAppendAdvancedSet = input.draft?.sets.isEmpty == false && targetWeightKg != nil
        let suggestionText = suggestionText(
            draft: input.draft,
            recentSets: input.recentSets,
            hasConfigurableProgressionAccess: input.hasConfigurableProgressionAccess,
            autoProgressionEnabled: input.autoProgressionEnabled,
            weightIncrementKg: input.weightIncrementKg
        )
        let toolsCaption: String
        if plateLoadSummary != nil {
            toolsCaption = localizedString("set_tools_caption_plate_load")
        } else if canAppendAdvancedSet {
            toolsCaption = localizedString("set_tools_caption_advanced_set")
        } else {
            toolsCaption = localizedString("set_tools_caption")
        }

        return Context(
            currentWorkingSet: currentWorkingSet,
            targetWeightKg: targetWeightKg,
            plateLoadSummary: plateLoadSummary,
            historySummary: historySummary(from: input.recentSets),
            suggestionText: suggestionText,
            canInsertWarmUpSets: canInsertWarmUpSets,
            canAppendAdvancedSet: canAppendAdvancedSet,
            toolsCaption: toolsCaption
        )
    }

    private static func canInsertWarmUpSets(draft: ExerciseSessionDraft?, targetWeightKg: Double?) -> Bool {
        guard let draft, let targetWeightKg else { return false }
        return targetWeightKg >= 20 && !draft.sets.contains(where: { $0.setType == .warmUp })
    }

    private static func plateLoadSummary(for exercise: Exercise?, targetWeightKg: Double?) -> String? {
        guard let exercise,
              isBarbellLoadedExercise(exercise),
              let targetWeightKg else {
            return nil
        }
        return PlateLoadingCalculator.loadSummary(targetWeightKg: targetWeightKg)
    }

    private static func historySummary(from recentSets: [SetLog]) -> String? {
        let recent = recentSets.prefix(3)
        guard !recent.isEmpty,
              let best = recent.max(by: { ($0.weightKg * Double($0.reps)) < ($1.weightKg * Double($1.reps)) }) else {
            return nil
        }
        return localizedFormat("set_history_summary_format", Int(best.weightKg), best.reps)
    }

    private static func suggestionText(
        draft: ExerciseSessionDraft?,
        recentSets: [SetLog],
        hasConfigurableProgressionAccess: Bool,
        autoProgressionEnabled: Bool,
        weightIncrementKg: Double
    ) -> String? {
        guard hasConfigurableProgressionAccess,
              autoProgressionEnabled,
              let draft,
              !recentSets.isEmpty else {
            return nil
        }

        let suggestion = ProgressionEngine.nextSuggestion(
            for: draft.workoutExercise,
            recentSets: recentSets,
            weightIncrementKg: weightIncrementKg
        )
        return suggestion.explanation
    }

    private static func isBarbellLoadedExercise(_ exercise: Exercise) -> Bool {
        let searchable = "\(exercise.name) \(exercise.equipment) \(exercise.requiredEquipment.joined(separator: " "))"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return searchable.contains("barbell") ||
            searchable.contains("barra") ||
            searchable.contains("smith")
    }
}

enum WorkoutRestController {
    struct RestState: Equatable {
        let restSeconds: Int
        let restDuration: Int
        let restStartedAt: Date?
    }

    static func adjustedRest(
        current: RestState,
        remainingSeconds: Int,
        deltaSeconds: Int,
        now: Date = Date()
    ) -> RestState {
        if deltaSeconds < 0 {
            return RestState(
                restSeconds: max(0, remainingSeconds + deltaSeconds),
                restDuration: current.restDuration,
                restStartedAt: current.restStartedAt?.addingTimeInterval(Double(deltaSeconds))
            )
        }

        if let restStartedAt = current.restStartedAt {
            return RestState(
                restSeconds: min(600, remainingSeconds + deltaSeconds),
                restDuration: current.restDuration,
                restStartedAt: restStartedAt.addingTimeInterval(Double(deltaSeconds))
            )
        }

        return RestState(
            restSeconds: deltaSeconds,
            restDuration: deltaSeconds,
            restStartedAt: now
        )
    }
}

enum WorkoutSessionBuilder {
    struct Input {
        let workoutTitle: String
        let finishedAt: Date
        let startedAt: Date
        let origin: WorkoutSession.Origin
        let isRouteCandidate: Bool
        let isTreadmillCandidate: Bool
        let userTrainingLocation: UserProfile.TrainingLocation
        let activePlanLocation: UserProfile.TrainingLocation
        let elapsedSeconds: Int
        let drafts: [ExerciseSessionDraft]
        let globalNotes: String
        let sessionVoiceNote: String
        let sessionMediaAttachments: [WorkoutMediaAttachment]
        let sessionRPE: Double
        let energyBefore: Double
        let energyAfter: Double
        let sensorSummary: WorkoutSensorSummary?
        let routePoints: [RoutePoint]
        let pausedSeconds: Int
        let displayedRouteDistanceKm: Double
        let displayedRoutePaceSecondsPerKm: Double?
    }

    static func session(from input: Input) -> WorkoutSession {
        let logs = exerciseLogs(from: input.drafts)
        let sessionAttachments = input.sessionMediaAttachments + voiceAttachments(from: input.sessionVoiceNote)

        return WorkoutSession(
            workoutTitle: input.workoutTitle,
            date: input.finishedAt,
            startedAt: input.startedAt,
            endedAt: input.finishedAt,
            origin: input.origin,
            location: location(
                isRouteCandidate: input.isRouteCandidate,
                isTreadmillCandidate: input.isTreadmillCandidate,
                origin: input.origin,
                userTrainingLocation: input.userTrainingLocation,
                activePlanLocation: input.activePlanLocation
            ),
            contextTag: .normal,
            durationMinutes: max(input.elapsedSeconds / 60, 1),
            sets: logs.flatMap(\.sets),
            notes: sessionNotes(
                globalNotes: input.globalNotes,
                sessionMediaAttachments: input.sessionMediaAttachments,
                logs: logs
            ),
            exerciseLogs: logs,
            sessionRPE: input.sessionRPE,
            energyBefore: Int(input.energyBefore),
            energyAfter: Int(input.energyAfter),
            estimatedCalories: input.sensorSummary?.activeEnergyKcal,
            mediaAttachments: sessionAttachments,
            routePoints: input.isRouteCandidate ? input.routePoints : [],
            pausedDurationSeconds: input.pausedSeconds,
            distanceKm: input.displayedRouteDistanceKm > 0 ? input.displayedRouteDistanceKm : nil,
            averagePaceSecondsPerKm: input.displayedRoutePaceSecondsPerKm,
            steps: input.sensorSummary?.steps,
            activeEnergyKcal: input.sensorSummary?.activeEnergyKcal,
            heartRateBefore: input.sensorSummary?.heartRateBefore,
            heartRateAfter: input.sensorSummary?.heartRateAfter,
            averageHeartRate: input.sensorSummary?.averageHeartRate,
            maxHeartRate: input.sensorSummary?.maxHeartRate
        )
    }

    static func voiceAttachments(from text: String) -> [WorkoutMediaAttachment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return [WorkoutMediaAttachment(kind: .audio, note: trimmed, durationSeconds: nil)]
    }

    static func exerciseLogs(from drafts: [ExerciseSessionDraft]) -> [ExerciseLog] {
        drafts.compactMap { draft -> ExerciseLog? in
            let completedSets = draft.sets.filter(\.completed)
            guard !completedSets.isEmpty else {
                return nil
            }

            return ExerciseLog(
                exercise: draft.workoutExercise.exercise,
                notes: draft.notes,
                sets: completedSets,
                mediaAttachments: draft.mediaAttachments + voiceAttachments(from: draft.voiceNote)
            )
        }
    }

    static func sessionNotes(
        globalNotes: String,
        sessionMediaAttachments: [WorkoutMediaAttachment],
        logs: [ExerciseLog]
    ) -> String? {
        let exerciseNotes = logs.compactMap { $0.notes.isEmpty ? nil : "\($0.exercise.name): \($0.notes)" }
        let global = globalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionMediaSummary = sessionMediaAttachments.isEmpty ? nil : localizedFormat("session_media_summary_format", sessionMediaAttachments.count)
        let exerciseMediaSummary = logs
            .filter { !$0.mediaAttachments.isEmpty }
            .map { localizedFormat("exercise_media_summary_format", $0.exercise.name, $0.mediaAttachments.count) }
        let allNotes = (global.isEmpty ? [] : [global]) + exerciseNotes + (sessionMediaSummary.map { [$0] } ?? []) + exerciseMediaSummary
        return allNotes.isEmpty ? nil : allNotes.joined(separator: "\n")
    }

    static func location(
        isRouteCandidate: Bool,
        isTreadmillCandidate: Bool,
        origin: WorkoutSession.Origin,
        userTrainingLocation: UserProfile.TrainingLocation,
        activePlanLocation: UserProfile.TrainingLocation
    ) -> WorkoutSession.Location {
        if isRouteCandidate {
            return .outdoor
        }

        if isTreadmillCandidate {
            return .gym
        }

        if origin == .free {
            return userTrainingLocation == .home ? .home : .gym
        }

        return activePlanLocation == .home ? .home : .gym
    }

    static func cardioLog(
        from session: WorkoutSession,
        sensorSummary: WorkoutSensorSummary?,
        isCardioMovementCandidate: Bool,
        sessionType: WorkoutDay.SessionType,
        isTreadmillCandidate: Bool,
        isRouteCandidate: Bool,
        averageSpeedKmh: Double?
    ) -> CardioLog? {
        guard isCardioMovementCandidate else { return nil }

        let activityType: CardioLog.ActivityType
        switch sessionType {
        case .cardioRun:
            activityType = isTreadmillCandidate ? .treadmill : .outdoorRun
        case .cardioWalk:
            activityType = .walking
        default:
            activityType = .other
        }

        return CardioLog(
            activityType: activityType,
            date: session.startedAt ?? session.date,
            durationMinutes: session.durationMinutes,
            distanceKm: session.distanceKm,
            averageSpeedKmh: averageSpeedKmh,
            averagePaceSecondsPerKm: session.averagePaceSecondsPerKm,
            averageHeartRate: sensorSummary?.averageHeartRate,
            maxHeartRate: sensorSummary?.maxHeartRate,
            estimatedCalories: sensorSummary?.activeEnergyKcal,
            steps: sensorSummary?.steps,
            activeEnergyKcal: sensorSummary?.activeEnergyKcal,
            heartRateBefore: sensorSummary?.heartRateBefore,
            heartRateAfter: sensorSummary?.heartRateAfter,
            rpe: session.sessionRPE,
            notes: session.notes,
            routePoints: isRouteCandidate ? session.routePoints : []
        )
    }
}

enum ActiveWorkoutStatusBuilder {
    struct Input {
        let elapsedSeconds: Int
        let pausedSeconds: Int
        let isPaused: Bool
        let selectedExerciseName: String?
        let selectedExerciseIndex: Int
        let drafts: [ExerciseSessionDraft]
        let currentSet: SetLog?
        let restSeconds: Int
        let restDurationSeconds: Int
        let estimatedRemainingSeconds: Int
        let waterLiters: Double
        let musicTitle: String?
        let musicArtist: String?
        let isMusicPlaying: Bool?
        let nextExerciseName: String
        let exerciseHistorySummary: String?
        let gymPass: GymPass?
        let lastPausedAt: Date?
        let isRouteWorkout: Bool
        let isOutdoorRoute: Bool
        let routeDistanceKm: Double?
        let routePaceSecondsPerKm: Double?
        let routeSpeedKmh: Double?
        let routePointCount: Int?
        let routePoints: [RoutePoint]
        let pedometerDistanceKm: Double?
        let pedometerPaceSecondsPerKm: Double?
        let pedometerSpeedKmh: Double?
        let pedometerSteps: Double?
        let previousRouteDistanceKm: Double?
        let previousRoutePaceSecondsPerKm: Double?
        let previousRouteSpeedKmh: Double?
        let previousRoutePointCount: Int?
        let previousRoutePoints: [RoutePoint]?
        let previousRouteSteps: Double?
        let routeSteps: Double?
        let liveHeartRate: Double?
        let liveActiveEnergyKcal: Double?
    }

    struct Update {
        let elapsedSeconds: Int
        let pausedSeconds: Int
        let completedSets: Int
        let totalSets: Int
        let volumeKg: Int
        let isPaused: Bool
        let exerciseName: String?
        let exerciseIndex: Int?
        let totalExercises: Int?
        let currentExerciseCompletedSets: Int?
        let currentExerciseTotalSets: Int?
        let currentSetWeightKg: Double?
        let currentSetReps: Int?
        let restSeconds: Int?
        let restDurationSeconds: Int?
        let estimatedRemainingSeconds: Int?
        let waterLiters: Double?
        let musicTitle: String?
        let musicArtist: String?
        let isMusicPlaying: Bool?
        let nextExerciseName: String?
        let exerciseHistorySummary: String?
        let gymPass: GymPass?
        let lastPausedAt: Date?
        let isRouteWorkout: Bool
        let isOutdoorRoute: Bool?
        let routeDistanceKm: Double?
        let routePaceSecondsPerKm: Double?
        let routeSpeedKmh: Double?
        let routePointCount: Int?
        let routePoints: [RoutePoint]?
        let routeSteps: Double?
        let liveHeartRate: Double?
        let liveActiveEnergyKcal: Double?
    }

    static func update(from input: Input) -> Update {
        let allSets = input.drafts.flatMap(\.sets)
        let completedSets = allSets.filter(\.completed)
        let selectedDraft = input.drafts.indices.contains(input.selectedExerciseIndex) ? input.drafts[input.selectedExerciseIndex] : nil
        let liveDistance = max(input.routeDistanceKm ?? 0, input.pedometerDistanceKm ?? 0)
        let routeDistance = input.isOutdoorRoute ? liveDistance : (input.pedometerDistanceKm ?? input.previousRouteDistanceKm ?? 0)
        let routePace = input.isOutdoorRoute
            ? (input.routePaceSecondsPerKm ?? input.pedometerPaceSecondsPerKm)
            : (input.pedometerPaceSecondsPerKm ?? input.previousRoutePaceSecondsPerKm)
        let routeSpeed = input.isOutdoorRoute
            ? (input.routeSpeedKmh ?? input.pedometerSpeedKmh)
            : (input.pedometerSpeedKmh ?? input.previousRouteSpeedKmh)
        let routePointCount = input.isOutdoorRoute ? input.routePointCount : input.previousRoutePointCount
        let routePoints = input.isOutdoorRoute ? input.routePoints : (input.previousRoutePoints ?? [])
        let routeSteps = input.pedometerSteps ?? input.routeSteps ?? input.previousRouteSteps

        return Update(
            elapsedSeconds: input.elapsedSeconds,
            pausedSeconds: input.pausedSeconds,
            completedSets: completedSets.count,
            totalSets: allSets.count,
            volumeKg: Int(completedSets.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }),
            isPaused: input.isPaused,
            exerciseName: input.selectedExerciseName,
            exerciseIndex: input.drafts.isEmpty ? nil : input.selectedExerciseIndex + 1,
            totalExercises: input.drafts.count,
            currentExerciseCompletedSets: selectedDraft?.sets.filter(\.completed).count,
            currentExerciseTotalSets: selectedDraft?.sets.count,
            currentSetWeightKg: input.currentSet?.weightKg,
            currentSetReps: input.currentSet?.reps,
            restSeconds: input.restSeconds,
            restDurationSeconds: input.restDurationSeconds,
            estimatedRemainingSeconds: input.estimatedRemainingSeconds,
            waterLiters: input.waterLiters,
            musicTitle: input.musicTitle,
            musicArtist: input.musicArtist,
            isMusicPlaying: input.isMusicPlaying,
            nextExerciseName: input.nextExerciseName,
            exerciseHistorySummary: input.exerciseHistorySummary,
            gymPass: input.gymPass,
            lastPausedAt: input.lastPausedAt,
            isRouteWorkout: input.isRouteWorkout,
            isOutdoorRoute: input.isOutdoorRoute,
            routeDistanceKm: routeDistance > 0 ? routeDistance : nil,
            routePaceSecondsPerKm: routePace,
            routeSpeedKmh: routeSpeed,
            routePointCount: routePointCount,
            routePoints: routePoints,
            routeSteps: routeSteps,
            liveHeartRate: input.liveHeartRate,
            liveActiveEnergyKcal: input.liveActiveEnergyKcal
        )
    }
}

enum RouteMetricsBuilder {
    struct Input {
        let trackerDistanceKm: Double
        let trackerPaceSecondsPerKm: Double?
        let trackerSpeedKmh: Double?
        let trackerPointCount: Int
        let pedometerDistanceKm: Double?
        let pedometerPaceSecondsPerKm: Double?
        let pedometerSpeedKmh: Double?
        let pedometerSteps: Double?
        let activeStatus: ActiveWorkoutStatus?
        let sensorSummary: WorkoutSensorSummary?
        let todayHealthMetric: DailyHealthMetric?
    }

    struct Metrics: Equatable {
        let distanceKm: Double
        let paceSecondsPerKm: Double?
        let speedKmh: Double?
        let pointCount: Int
        let paceText: String
        let speedText: String
        let stepsText: String
        let heartRateText: String
        let energyText: String
    }

    static func metrics(from input: Input) -> Metrics {
        let distanceKm = max(input.trackerDistanceKm, input.pedometerDistanceKm ?? 0, input.activeStatus?.routeDistanceKm ?? 0)
        let paceSecondsPerKm = validPositive(input.activeStatus?.routePaceSecondsPerKm) ?? validPositive(input.trackerPaceSecondsPerKm) ?? validPositive(input.pedometerPaceSecondsPerKm)
        let speedKmh = validPositive(input.activeStatus?.routeSpeedKmh) ?? validPositive(input.trackerSpeedKmh) ?? validPositive(input.pedometerSpeedKmh)
        let pointCount = max(input.trackerPointCount, input.activeStatus?.routePointCount ?? 0)
        let steps = input.pedometerSteps ?? input.activeStatus?.routeSteps ?? input.sensorSummary?.steps
        let heartRate = validPositive(input.activeStatus?.liveHeartRate) ?? validPositive(input.sensorSummary?.averageHeartRate)
        let activeEnergy = input.activeStatus?.liveActiveEnergyKcal

        return Metrics(
            distanceKm: distanceKm,
            paceSecondsPerKm: paceSecondsPerKm,
            speedKmh: speedKmh,
            pointCount: pointCount,
            paceText: SharedWorkoutSnapshot.routePaceText(paceSecondsPerKm),
            speedText: SharedWorkoutSnapshot.routeSpeedText(speedKmh),
            stepsText: SharedWorkoutSnapshot.integerMetricText(steps),
            heartRateText: SharedWorkoutSnapshot.heartRateText(heartRate),
            energyText: SharedWorkoutSnapshot.integerMetricText(activeEnergy)
        )
    }

    private static func validPositive(_ value: Double?) -> Double? {
        SharedWorkoutSnapshot.validPositive(value)
    }
}

enum RouteProgressBuilder {
    enum VisualState: Equatable {
        case inactive
        case active
        case paused
    }

    struct Input {
        let isTreadmill: Bool
        let isSessionStarted: Bool
        let isPaused: Bool
        let plannedDurationMinutes: Int
        let elapsedSeconds: Int
        let pausedSeconds: Int
        let distanceKm: Double
        let paceText: String
    }

    struct Snapshot: Equatable {
        let progress: Double
        let visualState: VisualState
        let icon: String
        let status: String
        let subtitle: String
        let startHint: String
        let startHintSystemImage: String
    }

    static func snapshot(from input: Input) -> Snapshot {
        let progress = durationProgress(elapsedSeconds: input.elapsedSeconds, plannedDurationMinutes: input.plannedDurationMinutes)
        let visualState: VisualState = !input.isSessionStarted ? .inactive : (input.isPaused ? .paused : .active)
        let status = statusText(isTreadmill: input.isTreadmill, isSessionStarted: input.isSessionStarted, isPaused: input.isPaused)
        let subtitle = subtitleText(
            isSessionStarted: input.isSessionStarted,
            plannedDurationMinutes: input.plannedDurationMinutes,
            pausedSeconds: input.pausedSeconds,
            distanceKm: input.distanceKm,
            paceText: input.paceText
        )

        return Snapshot(
            progress: progress,
            visualState: visualState,
            icon: icon(isTreadmill: input.isTreadmill, isSessionStarted: input.isSessionStarted, isPaused: input.isPaused),
            status: status,
            subtitle: subtitle,
            startHint: input.isTreadmill
                ? localizedString("route_start_hint_treadmill")
                : localizedString("route_start_hint_outdoor"),
            startHintSystemImage: input.isTreadmill ? "figure.run.treadmill" : "location.fill"
        )
    }

    private static func durationProgress(elapsedSeconds: Int, plannedDurationMinutes: Int) -> Double {
        guard plannedDurationMinutes > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(plannedDurationMinutes * 60), 1)
    }

    private static func icon(isTreadmill: Bool, isSessionStarted: Bool, isPaused: Bool) -> String {
        if isTreadmill {
            return isPaused ? "pause.fill" : "figure.run.treadmill"
        }
        if !isSessionStarted {
            return "location"
        }
        return isPaused ? "pause.fill" : "figure.walk"
    }

    private static func statusText(isTreadmill: Bool, isSessionStarted: Bool, isPaused: Bool) -> String {
        if isTreadmill {
            if !isSessionStarted { return "CINTA PREPARADA" }
            return isPaused ? "CINTA PAUSADA" : "CINTA ACTIVA"
        }
        if !isSessionStarted { return "RUTA PREPARADA" }
        return isPaused ? "RUTA PAUSADA" : "RUTA ACTIVA"
    }

    private static func subtitleText(
        isSessionStarted: Bool,
        plannedDurationMinutes: Int,
        pausedSeconds: Int,
        distanceKm: Double,
        paceText: String
    ) -> String {
        guard isSessionStarted else {
            return plannedDurationMinutes > 0
                ? "\(plannedDurationMinutes) min planificados"
                : localizedString("sin_tiempo_definido")
        }

        var parts = [
            String(format: "%.2f km", distanceKm),
            paceText
        ]
        if pausedSeconds > 0 {
            parts.append("pausa \(timeString(pausedSeconds))")
        }
        return parts.joined(separator: " · ")
    }

    private static func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Strength standards (estimated 1RM vs. bodyweight)

enum StrengthLevel: String, CaseIterable, Identifiable {
    case beginner
    case novice
    case intermediate
    case advanced
    case elite
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return localizedString("strength_beginner")
        case .novice: return localizedString("strength_novice")
        case .intermediate: return localizedString("strength_intermediate")
        case .advanced: return localizedString("strength_advanced")
        case .elite: return localizedString("strength_elite")
        }
    }

    /// 0...1 progress through the strength continuum, for progress bars.
    var fraction: Double {
        switch self {
        case .beginner: return 0.15
        case .novice: return 0.35
        case .intermediate: return 0.55
        case .advanced: return 0.78
        case .elite: return 1.0
        }
    }
}

enum StrengthStandards {
    /// Male bodyweight-multiple thresholds. Below `novice` is beginner.
    private struct Standard {
        let novice: Double
        let intermediate: Double
        let advanced: Double
        let elite: Double
    }

    private static func standard(forExerciseName name: String) -> Standard? {
        let n = name.lowercased()
        if n.contains("deadlift") {
            return Standard(novice: 1.25, intermediate: 1.75, advanced: 2.5, elite: 3.0)
        }
        if n.contains("squat") {
            return Standard(novice: 1.0, intermediate: 1.5, advanced: 2.25, elite: 2.75)
        }
        if n.contains("bench") {
            return Standard(novice: 0.75, intermediate: 1.0, advanced: 1.5, elite: 2.0)
        }
        if n.contains("overhead") || n.contains("ohp")
            || (n.contains("shoulder") && n.contains("press")) {
            return Standard(novice: 0.55, intermediate: 0.8, advanced: 1.1, elite: 1.4)
        }
        if n.contains("row") {
            return Standard(novice: 0.7, intermediate: 1.0, advanced: 1.4, elite: 1.8)
        }
        return nil
    }

    /// True when this exercise maps to a known strength standard.
    static func hasStandard(forExerciseName name: String) -> Bool {
        standard(forExerciseName: name) != nil
    }

    /// Classifies an estimated 1RM (kg) for a lift against bodyweight (kg) and sex.
    /// Returns the strength level and the bodyweight ratio, or nil when unknown.
    static func level(
        exerciseName: String,
        oneRepMaxKg: Double,
        bodyWeightKg: Double,
        sex: UserProfile.Sex?
    ) -> (level: StrengthLevel, ratio: Double)? {
        guard oneRepMaxKg > 0, bodyWeightKg > 0,
              let base = standard(forExerciseName: exerciseName) else { return nil }
        let sexFactor = sex == .female ? 0.66 : 1.0
        let ratio = oneRepMaxKg / bodyWeightKg
        let novice = base.novice * sexFactor
        let intermediate = base.intermediate * sexFactor
        let advanced = base.advanced * sexFactor
        let elite = base.elite * sexFactor
        let level: StrengthLevel
        switch ratio {
        case ..<novice: level = .beginner
        case ..<intermediate: level = .novice
        case ..<advanced: level = .intermediate
        case ..<elite: level = .advanced
        default: level = .elite
        }
        return (level, ratio)
    }
}

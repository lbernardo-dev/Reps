import Foundation

enum FitnessMetrics {
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
                return "Por debajo de 10 series semanales"
            case 8...20:
                return "Dentro del rango 10-20 series"
            default:
                return "Por encima de 20 series semanales"
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
                title: "El volumen está subiendo",
                message: "Este bloque está \(Int(totalVolume - previousVolume)) kg por encima del periodo comparable anterior.",
                systemImage: "chart.line.uptrend.xyaxis"
            ))
        } else if !recentSessions.isEmpty {
            insights.append(TrainingInsight(
                title: "Mantén la base constante",
                message: "Tienes \(recentSessions.count) sesiones registradas en este rango. Añade un entreno enfocado para mejorar la tendencia.",
                systemImage: "calendar.badge.clock"
            ))
        }

        if let lowestMuscle = musclePoints.min(by: { $0.completedSets < $1.completedSets }), lowestMuscle.completedSets < 10 {
            insights.append(TrainingInsight(
                title: "\(lowestMuscle.muscleGroup) va por debajo",
                message: "\(lowestMuscle.completedSets) series semanales está por debajo del rango simple de hipertrofia 10-20.",
                systemImage: "target"
            ))
        }

        if let strengthGoal = goals.first(where: { $0.kind == .strength }) {
            let remaining = max(strengthGoal.target - strengthGoal.current, 0)
            insights.append(TrainingInsight(
                title: strengthGoal.title,
                message: remaining == 0 ? "Objetivo alcanzado. Define una nueva meta para mantener el ritmo." : "Faltan \(Int(remaining)) \(strengthGoal.unit) para llegar a tu meta.",
                systemImage: "trophy"
            ))
        }

        if insights.isEmpty {
            insights.append(TrainingInsight(
                title: "Registra entrenos para activar insights",
                message: "Completa entrenos con series y repeticiones para ver señales prácticas de progreso.",
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
        let recoveryCredit = recoveryCredit(
            sessions: sessions,
            bodyMetrics: bodyMetrics,
            health: health,
            now: now
        )
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
            title = "Batería de entreno crítica"
            message = "La fatiga acumulada supera tu recuperación reciente."
            suggestion = "Cambia a descanso, movilidad o descarga. Si entrenas, reduce volumen 40% y evita RPE 9-10."
            systemImage = "battery.25percent"
        case 30..<55:
            state = .low
            title = "Batería de entreno baja"
            message = "Puedes entrenar, pero el margen para progresar es limitado."
            suggestion = "Mantén RPE 6-7, descansa 2-3 min entre series duras y recorta accesorios."
            systemImage = "battery.50percent"
        case 55..<80:
            state = .steady
            title = "Batería de entreno estable"
            message = "La carga y la recuperación están razonablemente equilibradas."
            suggestion = "Entrena según plan y respeta los descansos completos en ejercicios principales."
            systemImage = "battery.75percent"
        default:
            state = .charged
            title = "Batería de entreno cargada"
            message = "Buen margen para una sesión productiva."
            suggestion = "Puedes progresar si la técnica se mantiene y el RPE objetivo encaja."
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
            systemImage: systemImage
        )
    }

    static func projectedBatteryLevel(after workout: WorkoutDay, from currentLevel: Int) -> Int {
        let plannedCost = workoutBatteryCost(workout)
        return Int(clamp(Double(currentLevel) - plannedCost, lower: 5, upper: 100).rounded())
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
                MuscleTargetPoint(muscleGroup: muscle, kind: "Objetivo", sets: targetByMuscle[muscle, default: 0]),
                MuscleTargetPoint(muscleGroup: muscle, kind: "Real", sets: actualByMuscle[muscle, default: 0])
            ]
        }

        let undertrained = allMuscles.compactMap { muscle -> MuscleTargetPoint? in
            let target = targetByMuscle[muscle, default: 0]
            let actual = actualByMuscle[muscle, default: 0]
            guard target >= 4, actual < Int(Double(target) * 0.75) else { return nil }
            return MuscleTargetPoint(muscleGroup: muscle, kind: "Faltan", sets: target - actual)
        }
        .sorted { $0.sets > $1.sets }

        let overtrained = allMuscles.compactMap { muscle -> MuscleTargetPoint? in
            let target = targetByMuscle[muscle, default: 0]
            let actual = actualByMuscle[muscle, default: 0]
            guard target > 0, actual > Int(Double(target) * 1.35) else { return nil }
            return MuscleTargetPoint(muscleGroup: muscle, kind: "Exceso", sets: actual - target)
        }
        .sorted { $0.sets > $1.sets }

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
                title: "Sube la adherencia",
                message: "Completa al menos el 75% del plan semanal antes de endurecer progresiones.",
                systemImage: "calendar.badge.exclamationmark",
                action: .reviewPlan
            ))
        }

        if let muscle = undertrainedMuscles.first {
            recommendations.append(CompetitiveRecommendation(
                title: "Prioriza \(muscle.muscleGroup)",
                message: "Faltan \(muscle.sets) series para acercarte al objetivo semanal.",
                systemImage: "target",
                action: .scheduleUndertrainedMuscle(muscle.muscleGroup)
            ))
        }

        if let muscle = overtrainedMuscles.first {
            recommendations.append(CompetitiveRecommendation(
                title: "Controla \(muscle.muscleGroup)",
                message: "Vas \(muscle.sets) series por encima del objetivo. Considera recortar accesorios.",
                systemImage: "gauge.with.needle",
                action: .scheduleRecovery
            ))
        }

        if let stalled = stalledExercises.first {
            recommendations.append(CompetitiveRecommendation(
                title: "Rompe el estancamiento",
                message: "\(stalled.exercise.name) no mejora frente a su mejor 1RM estimado reciente. Prueba descarga, repeticiones objetivo o cambio de variante.",
                systemImage: "arrow.triangle.2.circlepath",
                action: .scheduleDeloadExercise(stalled.exercise.id)
            ))
        }

        if recommendations.isEmpty {
            let delta = actualWeeklySets - targetWeeklySets
            recommendations.append(CompetitiveRecommendation(
                title: "Semana equilibrada",
                message: delta >= 0 ? "El volumen real cubre el objetivo del plan." : "Estás a \(abs(delta)) series de cubrir el objetivo semanal.",
                systemImage: "checkmark.seal",
                action: .none
            ))
        }

        return Array(recommendations.prefix(4))
    }
}

enum RetentionEngine {
    enum ActivationAction: Equatable {
        case startWorkout
        case createPlan
        case scheduleWorkout
        case competitive(AnalyticsEngine.CompetitiveAction)
        case openProgress
    }

    struct ActivationStep: Identifiable, Equatable {
        let id: String
        let title: String
        let message: String
        let systemImage: String
        let isCompleted: Bool
        let actionTitle: String
        let action: ActivationAction?
    }

    static func nextBestSteps(
        sessions: [WorkoutSession],
        activePlan: WorkoutPlan,
        scheduledWorkouts: [ScheduledWorkout],
        remindersEnabled: Bool,
        competitiveSummary: AnalyticsEngine.CompetitiveSummary,
        now: Date = .now
    ) -> [ActivationStep] {
        let calendar = Calendar.current
        let hasPlan = !activePlan.days.isEmpty
        let hasCompletedWorkout = !sessions.isEmpty
        let hasUpcomingWorkout = scheduledWorkouts.contains { workout in
            workout.status == .scheduled && workout.date >= calendar.startOfDay(for: now)
        }
        let hasTodayWorkout = scheduledWorkouts.contains { workout in
            workout.status == .scheduled && calendar.isDate(workout.date, inSameDayAs: now)
        }
        let latestSession = sessions.map(\.date).max()
        let inactiveDays = latestSession.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0 }

        var steps: [ActivationStep] = []

        steps.append(ActivationStep(
            id: "create-plan",
            title: "Crear plan base",
            message: hasPlan ? "Tu plan activo ya define frecuencia, días y volumen objetivo." : "El primer plan reduce fricción y permite medir objetivo vs real.",
            systemImage: "rectangle.stack.badge.plus",
            isCompleted: hasPlan,
            actionTitle: "Crear plan",
            action: hasPlan ? nil : .createPlan
        ))

        steps.append(ActivationStep(
            id: "schedule-session",
            title: "Programar próxima sesión",
            message: hasUpcomingWorkout ? "Ya tienes una sesión en calendario para mantener continuidad." : "Agenda una sesión concreta para convertir intención en compromiso.",
            systemImage: "calendar.badge.plus",
            isCompleted: hasUpcomingWorkout,
            actionTitle: "Programar",
            action: hasUpcomingWorkout ? nil : .scheduleWorkout
        ))

        if !hasCompletedWorkout || inactiveDays.map({ $0 >= 5 }) == true {
            steps.append(ActivationStep(
                id: "start-workout",
                title: hasCompletedWorkout ? "Recuperar ritmo" : "Completar primer entreno",
                message: hasCompletedWorkout ? "Han pasado \(inactiveDays ?? 0) días desde tu último registro. Una sesión corta reactiva la racha." : "El primer registro desbloquea progresión, volumen y recomendaciones reales.",
                systemImage: "play.circle.fill",
                isCompleted: false,
                actionTitle: "Entrenar",
                action: .startWorkout
            ))
        } else {
            steps.append(ActivationStep(
                id: "start-workout",
                title: "Primer valor conseguido",
                message: "Ya tienes historial suficiente para que Reps empiece a personalizar carga y recuperación.",
                systemImage: "checkmark.seal.fill",
                isCompleted: true,
                actionTitle: "Ver progreso",
                action: .openProgress
            ))
        }

        if hasTodayWorkout && competitiveSummary.completionRate < 0.75 {
            steps.append(ActivationStep(
                id: "protect-adherence",
                title: "Cerrar la semana",
                message: "Completar la sesión de hoy ayuda a recuperar adherencia antes de subir carga.",
                systemImage: "target",
                isCompleted: false,
                actionTitle: "Empezar hoy",
                action: .startWorkout
            ))
        }

        for recommendation in competitiveSummary.recommendations where recommendation.action != .none {
            guard !steps.contains(where: { $0.id == recommendation.id }) else { continue }
            steps.append(ActivationStep(
                id: recommendation.id,
                title: recommendation.title,
                message: recommendation.message,
                systemImage: recommendation.systemImage,
                isCompleted: false,
                actionTitle: actionTitle(for: recommendation.action),
                action: .competitive(recommendation.action)
            ))
        }

        if !remindersEnabled {
            steps.append(ActivationStep(
                id: "enable-reminders",
                title: "Activar recordatorios",
                message: "Los recordatorios ayudan a volver cuando hay una sesión o acción de recuperación pendiente.",
                systemImage: "bell.badge.fill",
                isCompleted: false,
                actionTitle: "Abrir perfil",
                action: nil
            ))
        }

        return Array(steps.prefix(5))
    }

    private static func actionTitle(for action: AnalyticsEngine.CompetitiveAction) -> String {
        switch action {
        case .scheduleUndertrainedMuscle:
            return "Programar foco"
        case .scheduleDeloadExercise:
            return "Programar descarga"
        case .reviewPlan:
            return "Revisar plan"
        case .scheduleRecovery:
            return "Programar recuperación"
        case .none:
            return "Ver"
        }
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
                explanation: "No hay historial suficiente. Empieza conservador y registra RPE/RIR."
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
                explanation: "Llevas varias sesiones sin mejora y con esfuerzo alto. Aplica deload local."
            )
        }

        switch item.progressionType {
        case .linear:
            if allHitTop && !highEffort {
                return Suggestion(
                    targetWeightKg: rounded(lastWeight + item.incrementKg, increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: "Completaste el objetivo con margen. Sube peso y vuelve al inicio del rango."
                )
            }
        case .doubleProgression:
            if allHitTop && !highEffort {
                return Suggestion(
                    targetWeightKg: rounded(lastWeight + item.incrementKg, increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: "Has cerrado el rango de reps. Sube peso y reinicia reps."
                )
            }
            return Suggestion(
                targetWeightKg: rounded(lastWeight, increment: weightIncrementKg),
                targetReps: min((completed.map(\.reps).min() ?? range.lowerBound) + 1, range.upperBound),
                shouldDeload: false,
                explanation: "Mantén peso e intenta sumar una repeticion dentro del rango."
            )
        case .rpeTarget:
            if highEffort {
                return Suggestion(
                    targetWeightKg: rounded(max(lastWeight - item.incrementKg, 0), increment: weightIncrementKg),
                    targetReps: range.lowerBound,
                    shouldDeload: false,
                    explanation: "El esfuerzo fue alto. Baja ligeramente para volver al RPE objetivo."
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
                explanation: "Objetivo calculado con \(Int(targetPercent * 100))% de tu 1RM estimada."
            )
        case .none:
            break
        }

        if missedBottom && highEffort {
            return Suggestion(
                targetWeightKg: rounded(max(lastWeight * 0.9, 0), increment: weightIncrementKg),
                targetReps: range.lowerBound,
                shouldDeload: true,
                explanation: "No llegaste al minimo y el esfuerzo fue alto. Aplica deload local."
            )
        }

        return Suggestion(
            targetWeightKg: rounded(lastWeight, increment: weightIncrementKg),
            targetReps: range.lowerBound,
            shouldDeload: false,
            explanation: "Mantén el peso y busca completar todas las series con buena tecnica."
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
            reasons.append("Mismo grupo muscular")
        }
        if normalized(candidate.equipment) == normalized(original.equipment) {
            reasons.append("Mismo equipo")
        }
        if matchesAvailableEquipment(candidate, availableEquipment: availableEquipment) {
            reasons.append("Disponible con tu equipo")
        }
        if candidate.trackingType == original.trackingType {
            reasons.append("Misma medición")
        }
        if candidate.environment == original.environment || candidate.environment == .both {
            reasons.append("Mismo entorno")
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

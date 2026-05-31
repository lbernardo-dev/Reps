import ActivityKit
import Foundation
import UIKit
import WatchConnectivity

@MainActor
final class AppStore: ObservableObject {
    @Published var userProfile = UserProfile() { didSet { save() } }
    @Published var activePlan = SeedData.pushPullLegsPlan { didSet { save() } }
    @Published var plans: [WorkoutPlan] = SeedData.defaultPlans { didSet { save() } }
    @Published var workoutTemplates: [WorkoutDay] = SeedData.workoutTemplates { didSet { save() } }
    @Published var exercises: [Exercise] = SeedData.exercises { didSet { save() } }
    @Published var scheduledWorkouts: [ScheduledWorkout] = SeedData.scheduledWorkouts { didSet { save() } }
    @Published var workoutSessions: [WorkoutSession] = SeedData.sessions { didSet { save() } }
    @Published var cardioLogs: [CardioLog] = [] { didSet { save() } }
    @Published var bodyMetrics: [BodyMetric] = SeedData.bodyMetrics { didSet { save() } }
    @Published var progressPhotos: [ProgressPhoto] = [] { didSet { save() } }
    @Published var gymPasses: [GymPass] = [] { didSet { save() } }
    @Published var gymVisits: [GymVisit] = [] { didSet { save() } }
    @Published var goals: [Goal] = SeedData.goals { didSet { save() } }
    @Published var health = HealthSyncState() { didSet { save() } }
    @Published var isSyncingExerciseLibrary = false
    @Published var exerciseLibrarySyncMessage: String?
    @Published var activeWorkoutStatus: ActiveWorkoutStatus? {
        didSet {
            save()
            let snapshot = sharedWorkoutSnapshot()
            SharedWorkoutStore.save(snapshot)
            WatchSyncService.shared.publish(snapshot: snapshot)
            RepsWorkoutLiveActivityController.shared.sync(snapshot)
        }
    }
    @Published var activeWorkout: WorkoutDay? { didSet { save() } }
    @Published var activeWorkoutDrafts: [ExerciseSessionDraft] = [] { didSet { save() } }
    @Published var isUsingFallbackStorage = false

    private let persistence: SwiftDataPersistence
    private var isRestoring = false
    private var hasAttemptedExerciseLibrarySync = false
    private var saveTask: Task<Void, Never>?

    init(persistence: SwiftDataPersistence = SwiftDataPersistence()) {
        self.persistence = persistence
        self.isUsingFallbackStorage = persistence.didFallbackToInMemory
        WatchSyncService.shared.configure { [weak self] command in
            self?.handleWatchCommand(command)
        }
        SharedWorkoutStore.save(sharedWorkoutSnapshot())

        if let snapshot = persistence.loadSnapshot() ?? Self.loadLegacySnapshot() {
            restore(snapshot)
        } else {
            persistence.save(currentSnapshot)
        }

        Task {
            await syncOpenExerciseLibraryIfNeeded()
        }
    }

    var todaysWorkout: WorkoutDay {
        let calendar = Calendar.current
        if let scheduled = scheduledWorkouts.first(where: { calendar.isDateInToday($0.date) }) {
            return scheduled.workoutDay
        }
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            return activePlan.days[index]
        }
        return SeedData.pushDay
    }

    var streakDays: Int {
        let calendar = Calendar.current
        let workoutDays = Set(workoutSessions.map { calendar.startOfDay(for: $0.date) })
        var date = calendar.startOfDay(for: .now)
        
        if !workoutDays.contains(date) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            if workoutDays.contains(yesterday) {
                date = yesterday
            } else {
                return 0
            }
        }
        
        var streak = 0
        var checkDate = date
        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var weeklyCompletion: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-604_800)
        let completedThisWeek = workoutSessions.filter { $0.date >= weekStart }.count
        return FitnessMetrics.weeklyCompletion(completedWorkouts: completedThisWeek, plannedWorkouts: activePlan.daysPerWeek)
    }

    var currentWeight: Double {
        bodyMetrics.last?.weightKg ?? 78.5
    }

    var currentHeight: Double {
        bodyMetrics.last?.heightCm ?? 178
    }

    var displayedWeight: (value: Double, unit: String) {
        switch userProfile.units {
        case .metric:
            (currentWeight, "kg")
        case .imperial:
            (UnitConverter.pounds(fromKilograms: currentWeight), "lb")
        }
    }

    var displayedHeight: (value: Double, unit: String) {
        switch userProfile.units {
        case .metric:
            (currentHeight, "cm")
        case .imperial:
            (UnitConverter.inches(fromCentimeters: currentHeight), "in")
        }
    }

    var bodyMassIndex: Double {
        currentWeight / pow(max(currentHeight, 1) / 100, 2)
    }

    var basalMetabolicRate: Double {
        let age = userProfile.dateOfBirth.map { Calendar.current.dateComponents([.year], from: $0, to: .now).year ?? 30 } ?? 30
        let sexAdjustment = userProfile.sex == .female ? -161.0 : 5.0
        return 10 * currentWeight + 6.25 * currentHeight - 5 * Double(age) + sexAdjustment
    }

    var maintenanceCalories: Double {
        basalMetabolicRate * 1.45
    }

    var deficitCalories: Double {
        maintenanceCalories - 400
    }

    var recompositionCalories: Double {
        maintenanceCalories - 150
    }

    var leanBulkCalories: Double {
        maintenanceCalories + 250
    }

    var totalVolumeKg: Double {
        FitnessMetrics.totalVolumeKg(for: workoutSessions)
    }

    var bestEstimatedOneRepMaxKg: Double {
        FitnessMetrics.bestEstimatedOneRepMaxKg(for: workoutSessions) ?? 0
    }

    var todayHealthMetric: DailyHealthMetric? {
        let calendar = Calendar.current
        return health.latestDailyMetrics.last { calendar.isDateInToday($0.date) }
    }

    var dailySummary: String {
        let completedToday = workoutSessions.filter { Calendar.current.isDateInToday($0.date) }
        let workoutText = completedToday.isEmpty ? "Sin entreno registrado hoy" : "\(completedToday.count) entreno registrado"
        let healthText = todayHealthMetric.map { "\(Int($0.steps)) pasos, \(Int($0.activeEnergyKcal)) kcal activas" } ?? "Métricas de Salud sin sincronizar"
        return "\(workoutText). \(healthText)."
    }

    var trainingBattery: FitnessMetrics.TrainingBatteryStatus {
        FitnessMetrics.trainingBatteryStatus(
            sessions: workoutSessions,
            scheduledWorkouts: scheduledWorkouts,
            activePlan: activePlan,
            bodyMetrics: bodyMetrics,
            health: health
        )
    }

    func projectedBattery(after workout: WorkoutDay) -> Int {
        FitnessMetrics.projectedBatteryLevel(after: workout, from: trainingBattery.level)
    }

    func completeOnboarding(profile: UserProfile) {
        userProfile = profile
        sanitizeAvailableEquipment()
        userProfile.onboardingCompleted = true
    }

    func completeOnboarding(result: OnboardingResult) {
        userProfile = result.profile
        sanitizeAvailableEquipment()
        userProfile.onboardingCompleted = true
        bodyMetrics.append(result.bodyMetric)
        addPlan(result.plan, activate: true)
    }

    func saveBodyMetrics(weightKg: Double, heightCm: Double, source: BodyMetric.Source = .manual) {
        bodyMetrics.append(BodyMetric(date: Date(), weightKg: weightKg, heightCm: heightCm, source: source))
    }

    func saveBodyMetric(_ metric: BodyMetric) {
        bodyMetrics.append(metric)
    }

    func updateLatestBodyMetrics(weightKg: Double, heightCm: Double) {
        if var latest = bodyMetrics.sorted(by: { $0.date < $1.date }).last,
           let index = bodyMetrics.firstIndex(where: { $0.id == latest.id }) {
            latest.weightKg = weightKg
            latest.heightCm = heightCm
            bodyMetrics[index] = latest
        } else {
            saveBodyMetrics(weightKg: weightKg, heightCm: heightCm)
        }
    }

    func updateAvatarImageData(_ data: Data?) {
        userProfile.avatarImageData = data
    }

    func addProgressPhoto(_ photo: ProgressPhoto) {
        progressPhotos.append(photo)
    }

    func addGymPass(_ pass: GymPass) {
        gymPasses.append(pass)
    }

    func addGymVisit(_ visit: GymVisit) {
        gymVisits.append(visit)
    }

    func addCardioLog(_ log: CardioLog) {
        cardioLogs.append(log)
    }

    func importCardioLogs(_ logs: [CardioLog]) -> Int {
        let existingKeys = Set(cardioLogs.map(\.dedupeKey))
        let newLogs = logs.filter { !existingKeys.contains($0.dedupeKey) }
        cardioLogs.append(contentsOf: newLogs)
        return newLogs.count
    }

    func finishWorkout(_ session: WorkoutSession) {
        workoutSessions.append(session)
        activeWorkoutStatus = nil
        activeWorkout = nil
        activeWorkoutDrafts = []
        
        // Advance progress of the current plan's correct day if completed
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            let currentDay = activePlan.days[index]
            if session.workoutTitle == currentDay.title {
                activePlan.activeDayIndex = ((activePlan.activeDayIndex + 1) % count + count) % count
                if let index = plans.firstIndex(where: { $0.id == activePlan.id }) {
                    plans[index] = activePlan
                }
            }
        }
        
        let calendar = Calendar.current
        if let index = scheduledWorkouts.firstIndex(where: { calendar.isDateInToday($0.date) && $0.workoutDay.title == session.workoutTitle }) {
            scheduledWorkouts[index].status = .completed
        }

        let battery = trainingBattery
        if userProfile.remindersEnabled, battery.level < 55 {
            Task {
                try? await NotificationService.scheduleBatteryRecoverySuggestion(
                    level: battery.level,
                    suggestion: battery.suggestion
                )
            }
        }
    }

    func startActiveWorkout(_ workout: WorkoutDay, elapsedSeconds: Int = 0, pausedSeconds: Int = 0, isPaused: Bool = false) {
        activeWorkout = workout
        activeWorkoutDrafts = workout.exercises.map { item in
            ExerciseSessionDraft(
                workoutExercise: item,
                notes: "",
                sets: (1...max(item.targetSets, 1)).map { setIndex in
                    SetLog(
                        setNumber: setIndex,
                        weightKg: defaultWeight(from: item.previous),
                        reps: defaultReps(from: item.repRange),
                        completed: false
                    )
                }
            )
        }
        activeWorkoutStatus = ActiveWorkoutStatus(
            planTitle: activePlan.name,
            workoutTitle: workout.title,
            sessionTitle: workout.subtitle,
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: 0,
            totalSets: activeWorkoutDrafts.flatMap(\.sets).count,
            volumeKg: 0,
            isPaused: isPaused
        )
    }

    private func defaultWeight(from previous: String) -> Double {
        let normalized = previous.replacingOccurrences(of: ",", with: ".")
        let number = normalized
            .split { character in
                !(character.isNumber || character == ".")
            }
            .compactMap { Double($0) }
            .first
        return number ?? 0
    }

    private func defaultReps(from repRange: String) -> Int {
        let digits = repRange.split { !$0.isNumber }.compactMap { Int($0) }
        return digits.first ?? 8
    }

    func updateActiveWorkout(
        elapsedSeconds: Int,
        pausedSeconds: Int,
        completedSets: Int,
        totalSets: Int,
        volumeKg: Int,
        isPaused: Bool,
        exerciseName: String? = nil,
        exerciseIndex: Int? = nil,
        totalExercises: Int? = nil,
        currentExerciseCompletedSets: Int? = nil,
        currentExerciseTotalSets: Int? = nil,
        currentSetWeightKg: Double? = nil,
        currentSetReps: Int? = nil,
        restSeconds: Int? = nil,
        restDurationSeconds: Int? = nil,
        estimatedRemainingSeconds: Int? = nil,
        waterLiters: Double? = nil,
        musicTitle: String? = nil,
        musicArtist: String? = nil,
        isMusicPlaying: Bool? = nil,
        nextExerciseName: String? = nil,
        exerciseHistorySummary: String? = nil,
        gymPass: GymPass? = nil
    ) {
        guard var status = activeWorkoutStatus else { return }
        status.planTitle = activePlan.name
        status.sessionTitle = activeWorkout?.subtitle
        status.elapsedSeconds = elapsedSeconds
        status.pausedSeconds = pausedSeconds
        status.completedSets = completedSets
        status.totalSets = totalSets
        status.volumeKg = volumeKg
        status.isPaused = isPaused
        status.exerciseName = exerciseName
        status.exerciseIndex = exerciseIndex
        status.totalExercises = totalExercises
        status.currentExerciseCompletedSets = currentExerciseCompletedSets
        status.currentExerciseTotalSets = currentExerciseTotalSets
        status.currentSetWeightKg = currentSetWeightKg
        status.currentSetReps = currentSetReps
        status.restSeconds = restSeconds
        status.restDurationSeconds = restDurationSeconds
        status.estimatedRemainingSeconds = estimatedRemainingSeconds
        status.waterLiters = waterLiters
        status.musicTitle = musicTitle
        status.musicArtist = musicArtist
        status.isMusicPlaying = isMusicPlaying
        status.nextExerciseName = nextExerciseName
        status.exerciseHistorySummary = exerciseHistorySummary
        status.gymPassName = gymPass?.gymName
        status.gymMembershipID = gymPass?.membershipID
        status.gymCodeValue = gymPass?.codeValue
        status.gymCodeType = gymPass?.codeType.rawValue
        activeWorkoutStatus = status
    }

    func setActiveWorkoutPaused(_ paused: Bool) {
        guard var status = activeWorkoutStatus else { return }
        status.isPaused = paused
        activeWorkoutStatus = status
    }

    func clearActiveWorkout() {
        activeWorkoutStatus = nil
        activeWorkout = nil
        activeWorkoutDrafts = []
    }

    private func handleWatchCommand(_ command: WatchCommand) {
        switch command {
        case .pause:
            setActiveWorkoutPaused(true)
        case .resume:
            setActiveWorkoutPaused(false)
        case .stop:
            clearActiveWorkout()
        case .musicToggle, .musicNext, .musicPrevious, .completeSet, .nextExercise, .previousExercise, .addWater, .voiceNote:
            NotificationCenter.default.post(name: command.notificationName, object: nil)
        }
    }

    private func sharedWorkoutSnapshot() -> SharedWorkoutSnapshot {
        guard let status = activeWorkoutStatus else {
            return SharedWorkoutSnapshot(
                hasActiveWorkout: false,
                planTitle: activePlan.name,
                workoutTitle: "Reps",
                sessionTitle: nil,
                elapsedSeconds: 0,
                pausedSeconds: 0,
                completedSets: 0,
                totalSets: 0,
                volumeKg: 0,
                isPaused: false,
                exerciseName: nil,
                exerciseIndex: nil,
                totalExercises: nil,
                currentExerciseCompletedSets: nil,
                currentExerciseTotalSets: nil,
                currentSetWeightKg: nil,
                currentSetReps: nil,
                restSeconds: nil,
                restDurationSeconds: nil,
                estimatedRemainingSeconds: nil,
                waterLiters: todayHealthMetric?.waterLiters,
                musicTitle: nil,
                musicArtist: nil,
                isMusicPlaying: nil,
                nextExerciseName: nil,
                exerciseHistorySummary: nil,
                gymPassName: gymPasses.first?.gymName,
                gymMembershipID: gymPasses.first?.membershipID,
                gymCodeValue: gymPasses.first?.codeValue,
                gymCodeType: gymPasses.first?.codeType.rawValue,
                heartRate: todayHealthMetric?.restingHeartRate,
                activeEnergyKcal: todayHealthMetric?.activeEnergyKcal,
                summary: dailySummary,
                updatedAt: .now
            )
        }

        return SharedWorkoutSnapshot(
            hasActiveWorkout: true,
            planTitle: status.planTitle ?? activePlan.name,
            workoutTitle: status.workoutTitle,
            sessionTitle: status.sessionTitle,
            elapsedSeconds: status.elapsedSeconds,
            pausedSeconds: status.pausedSeconds,
            completedSets: status.completedSets,
            totalSets: status.totalSets,
            volumeKg: status.volumeKg,
            isPaused: status.isPaused,
            exerciseName: status.exerciseName,
            exerciseIndex: status.exerciseIndex,
            totalExercises: status.totalExercises,
            currentExerciseCompletedSets: status.currentExerciseCompletedSets,
            currentExerciseTotalSets: status.currentExerciseTotalSets,
            currentSetWeightKg: status.currentSetWeightKg,
            currentSetReps: status.currentSetReps,
            restSeconds: status.restSeconds,
            restDurationSeconds: status.restDurationSeconds,
            estimatedRemainingSeconds: status.estimatedRemainingSeconds,
            waterLiters: status.waterLiters ?? todayHealthMetric?.waterLiters,
            musicTitle: status.musicTitle,
            musicArtist: status.musicArtist,
            isMusicPlaying: status.isMusicPlaying,
            nextExerciseName: status.nextExerciseName,
            exerciseHistorySummary: status.exerciseHistorySummary,
            gymPassName: status.gymPassName ?? gymPasses.first?.gymName,
            gymMembershipID: status.gymMembershipID ?? gymPasses.first?.membershipID,
            gymCodeValue: status.gymCodeValue ?? gymPasses.first?.codeValue,
            gymCodeType: status.gymCodeType ?? gymPasses.first?.codeType.rawValue,
            heartRate: todayHealthMetric?.restingHeartRate,
            activeEnergyKcal: todayHealthMetric?.activeEnergyKcal,
            summary: dailySummary,
            updatedAt: .now
        )
    }

    func addPlan(_ plan: WorkoutPlan, activate: Bool) {
        plans.append(plan)
        if activate {
            scheduledWorkouts.removeAll { $0.status == .scheduled }
            activePlan = plan
            generateSchedule(for: plan)
        }
    }

    func activatePlan(_ plan: WorkoutPlan) {
        // Save current activePlan progress to plans list first
        if let index = plans.firstIndex(where: { $0.id == activePlan.id }) {
            plans[index] = activePlan
        }
        activePlan = plan
        
        // Clear all non-completed scheduled workouts so they don't override the new plan
        scheduledWorkouts.removeAll { $0.status == .scheduled }
        
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }
        generateSchedule(for: plan)
    }

    func selectWorkoutDayForToday(_ day: WorkoutDay) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // 1. Remove all scheduled/incomplete workouts for today
        scheduledWorkouts.removeAll { calendar.isDate($0.date, inSameDayAs: today) }
        
        // 2. Add the selected day as scheduled for today
        let scheduled = ScheduledWorkout(date: Date(), workoutDay: day, status: .scheduled)
        scheduledWorkouts.append(scheduled)
        
        // 3. Align active plan's day index if this day is part of it
        if let index = activePlan.days.firstIndex(where: { $0.id == day.id }) {
            activePlan.activeDayIndex = index
            if let planIndex = plans.firstIndex(where: { $0.id == activePlan.id }) {
                plans[planIndex] = activePlan
            }
        }
        
        save()
    }

    func restoreSuggestedWorkoutForToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // Remove scheduled workouts for today
        scheduledWorkouts.removeAll { calendar.isDate($0.date, inSameDayAs: today) }
        
        // Re-generate schedule for today (meaning the active plan's current day will be scheduled)
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            let day = activePlan.days[index]
            let scheduled = ScheduledWorkout(date: Date(), workoutDay: day, status: .scheduled)
            scheduledWorkouts.append(scheduled)
        }
        
        save()
    }

    func updatePlan(_ plan: WorkoutPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }

        if activePlan.id == plan.id {
            activePlan = plan
            generateSchedule(for: plan)
        }
    }

    func addWorkoutTemplate(_ workout: WorkoutDay) {
        workoutTemplates.append(workout)
    }

    func updateWorkoutTemplate(_ workout: WorkoutDay) {
        if let index = workoutTemplates.firstIndex(where: { $0.id == workout.id }) {
            workoutTemplates[index] = workout
        }

        for planIndex in plans.indices {
            if let dayIndex = plans[planIndex].days.firstIndex(where: { $0.id == workout.id }) {
                plans[planIndex].days[dayIndex] = workout
            }
        }

        if let dayIndex = activePlan.days.firstIndex(where: { $0.id == workout.id }) {
            activePlan.days[dayIndex] = workout
        }
    }

    func deleteWorkoutTemplate(_ workout: WorkoutDay) {
        workoutTemplates.removeAll { $0.id == workout.id }
    }

    func addWorkoutToActivePlan(_ workout: WorkoutDay) {
        var updated = activePlan
        updated.days.append(workout)
        updatePlan(updated)
    }

    func addExerciseToActivePlanDay(_ exercise: Exercise, dayID: WorkoutDay.ID, targetSets: Int, repRange: String) {
        var updated = activePlan
        guard let dayIndex = updated.days.firstIndex(where: { $0.id == dayID }) else {
            return
        }

        updated.days[dayIndex].exercises.append(
            WorkoutExercise(
                exercise: exercise,
                targetSets: targetSets,
                repRange: repRange,
                previous: "-"
            )
        )
        updatePlan(updated)
    }

    func scheduleSingleExercise(_ exercise: Exercise, date: Date, targetSets: Int, repRange: String) {
        let workout = WorkoutDay(
            title: exercise.name,
            subtitle: String(localized: "Technique practice"),
            durationMinutes: exercise.trackingType == .duration ? 20 : max(20, targetSets * 8),
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    targetSets: targetSets,
                    repRange: repRange,
                    previous: "-"
                )
            ]
        )
        addScheduledWorkout(workout, date: date)
    }

    func deactivatePlan(_ plan: WorkoutPlan) {
        guard activePlan.id == plan.id else {
            return
        }

        if let replacement = plans.first(where: { $0.id != plan.id }) {
            activatePlan(replacement)
        } else {
            scheduledWorkouts.removeAll { $0.status == .scheduled }
        }
    }

    func deletePlan(_ plan: WorkoutPlan) {
        plans.removeAll { $0.id == plan.id }
        if activePlan.id == plan.id {
            activePlan = plans.first ?? SeedData.pushPullLegsPlan
        }
    }

    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        }

        for planIndex in plans.indices {
            for dayIndex in plans[planIndex].days.indices {
                for exerciseIndex in plans[planIndex].days[dayIndex].exercises.indices
                    where plans[planIndex].days[dayIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                    plans[planIndex].days[dayIndex].exercises[exerciseIndex].exercise = exercise
                }
            }
        }

        for dayIndex in activePlan.days.indices {
            for exerciseIndex in activePlan.days[dayIndex].exercises.indices
                where activePlan.days[dayIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                activePlan.days[dayIndex].exercises[exerciseIndex].exercise = exercise
            }
        }

        for templateIndex in workoutTemplates.indices {
            for exerciseIndex in workoutTemplates[templateIndex].exercises.indices
                where workoutTemplates[templateIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                workoutTemplates[templateIndex].exercises[exerciseIndex].exercise = exercise
            }
        }
    }

    func syncOpenExerciseLibraryIfNeeded() async {
        guard !hasAttemptedExerciseLibrarySync else {
            return
        }

        hasAttemptedExerciseLibrarySync = true
        await syncOpenExerciseLibrary()
    }

    func syncOpenExerciseLibrary() async {
        guard !isSyncingExerciseLibrary else {
            return
        }

        isSyncingExerciseLibrary = true
        defer { isSyncingExerciseLibrary = false }

        do {
            let remoteExercises = try await OpenExerciseLibraryClient().fetchExercises()
            let mappedExercises = remoteExercises.compactMap(\.domainExercise)
            
            // Build key map for faster search and updates
            var existingExercisesByKey: [String: Int] = [:]
            for (index, exercise) in exercises.enumerated() {
                existingExercisesByKey[exercise.name.normalizedExerciseKey] = index
            }

            var mergedCount = 0
            var addedCount = 0

            for remoteExercise in mappedExercises {
                let key = remoteExercise.name.normalizedExerciseKey
                if let index = existingExercisesByKey[key] {
                    var modified = false
                    // If instructions or mediaURL are empty on existing (such as Seed exercises), complete them.
                    if exercises[index].mediaURL == nil || exercises[index].mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].mediaURL = remoteExercise.mediaURL
                        modified = true
                    }
                    if exercises[index].instructions == nil || exercises[index].instructions?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].instructions = remoteExercise.instructions
                        modified = true
                    }
                    if exercises[index].videoURL == nil || exercises[index].videoURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].videoURL = remoteExercise.videoURL
                        modified = true
                    }
                    if modified {
                        mergedCount += 1
                    }
                } else {
                    exercises.append(remoteExercise)
                    addedCount += 1
                    existingExercisesByKey[key] = exercises.count - 1
                }
            }

            if addedCount == 0 && mergedCount == 0 {
                exerciseLibrarySyncMessage = String(localized: "La biblioteca de ejercicios está actualizada.")
            } else {
                exerciseLibrarySyncMessage = String(localized: "Biblioteca actualizada: \(addedCount) nuevos, \(mergedCount) completados.")
            }
        } catch {
            exerciseLibrarySyncMessage = String(localized: "No se pudo actualizar la biblioteca. El catálogo offline sigue disponible.")
        }
    }

    func addScheduledWorkout(_ workoutDay: WorkoutDay, date: Date) {
        scheduledWorkouts.append(ScheduledWorkout(date: date, workoutDay: workoutDay, status: .scheduled))
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
    }

    func createSuggestedPlanForAvailableEquipment() {
        let equipment = Set(userProfile.availableEquipment.map { $0.lowercased() })
        let prefersHome = userProfile.trainingLocation == .home
            || equipment.contains("dumbbells")
            || equipment.contains("resistance bands")
            || equipment.contains("bodyweight")
        let template = prefersHome ? SeedData.homeStrengthPlan : SeedData.pushPullLegsPlan
        var suggested = template
        suggested.id = UUID()
        suggested.name = prefersHome ? "Casa según mi equipo" : "Gimnasio recomendado"
        addPlan(suggested, activate: true)
    }

    func disconnectHealth() {
        health = HealthSyncState(
            isAvailable: health.isAvailable,
            isAuthorized: false,
            lastSyncDate: nil,
            message: String(localized: "Apple Health desconectado en Reps. Puedes revocar permisos en la app Salud."),
            latestDailyMetrics: []
        )
    }

    func exportBackupURL() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(currentSnapshot)
        let url = exportURL(fileName: "reps-backup-\(Self.exportDateStamp()).json")
        try writeProtected(data, to: url)
        return url
    }

    func exportCSVURL() throws -> URL {
        let csv = CSVExporter(snapshot: currentSnapshot).makeCSV()
        let url = exportURL(fileName: "reps-export-\(Self.exportDateStamp()).csv")
        let data = Data(csv.utf8)
        try writeProtected(data, to: url)
        return url
    }

    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(AppSnapshot.self, from: data)
        restore(snapshot)
    }

    func importCSV(from url: URL) throws {
        let csv = try String(contentsOf: url, encoding: .utf8)
        let importer = CSVImporter(csv: csv)
        let importedCardio = importer.cardioLogs()
        let importedBody = importer.bodyMetrics()
        if !importedCardio.isEmpty {
            _ = importCardioLogs(importedCardio)
        }
        if !importedBody.isEmpty {
            bodyMetrics.append(contentsOf: importedBody)
        }
    }

    func exportWorkoutShareImageURL(session: WorkoutSession? = nil) throws -> URL {
        let selected = session ?? workoutSessions.sorted { $0.date > $1.date }.first
        let url = exportURL(fileName: "reps-share-\(Self.exportDateStamp()).png")
        let image: UIImage
        if let sel = selected {
            image = WorkoutShareImageRenderer.render(session: sel)
        } else {
            image = WorkoutShareImageRenderer.render(title: "Reps Workout", duration: 0, volume: 0, sets: 0)
        }
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try writeProtected(data, to: url)
        return url
    }

    func resetAllData() {
        restore(AppSnapshot.seed)
        userProfile.onboardingCompleted = false
    }

    private func generateSchedule(for plan: WorkoutPlan) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = plan.days.isEmpty ? [SeedData.pushDay] : plan.days
        let count = min(plan.daysPerWeek, max(days.count, 1))
        let startDayIndex = plan.activeDayIndex

        let generated = (0..<count).compactMap { offset -> ScheduledWorkout? in
            guard let date = calendar.date(byAdding: .day, value: offset * 2, to: today) else {
                return nil
            }
            let dayIndex = (startDayIndex + offset) % days.count
            return ScheduledWorkout(date: date, workoutDay: days[dayIndex], status: .scheduled)
        }

        scheduledWorkouts = scheduledWorkouts.filter { !calendar.isDate($0.date, equalTo: today, toGranularity: .weekOfYear) || $0.status == .completed }
        scheduledWorkouts.append(contentsOf: generated)
    }

    private func save() {
        guard !isRestoring else {
            return
        }

        saveTask?.cancel()
        saveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
                guard !Task.isCancelled else { return }
                persistence.save(currentSnapshot)
            } catch {
                // Cancelled or slept error
            }
        }
    }

    private func exportURL(fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RepsExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func exportDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }

    private var currentSnapshot: AppSnapshot {
        AppSnapshot(
            userProfile: userProfile,
            activePlan: activePlan,
            plans: plans,
            workoutTemplates: workoutTemplates,
            exercises: exercises,
            scheduledWorkouts: scheduledWorkouts,
            workoutSessions: workoutSessions,
            cardioLogs: cardioLogs,
            bodyMetrics: bodyMetrics,
            progressPhotos: progressPhotos,
            gymPasses: gymPasses,
            gymVisits: gymVisits,
            goals: goals,
            health: health,
            activeWorkout: activeWorkout,
            activeWorkoutDrafts: activeWorkoutDrafts,
            activeWorkoutStatus: activeWorkoutStatus
        )
    }

    func sanitizeAvailableEquipment() {
        let mapped = userProfile.availableEquipment.map { eq in
            switch eq.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "barra", "barbell": return "Barbell"
            case "mancuernas", "mancuerna", "dumbbell", "dumbbells": return "Dumbbells"
            case "kettlebell", "kettlebells", "pesa rusa": return "Kettlebell"
            case "bandas", "banda", "resistance band": return "Resistance Band"
            case "poleas", "polea", "cable": return "Cable"
            case "maquinas", "maquina", "máquinas", "máquina", "machine", "machines": return "Machine"
            case "banco", "bench": return "Bench"
            case "rack": return "Rack"
            case "dominadas", "pullup bar": return "Pullup Bar"
            case "cardio", "cardio machine": return "Cardio Machine"
            default: return eq
            }
        }
        let unique = Array(Set(mapped)).sorted()
        if unique != userProfile.availableEquipment {
            userProfile.availableEquipment = unique
        }
    }

    private func restore(_ snapshot: AppSnapshot) {
        isRestoring = true
        userProfile = snapshot.userProfile
        activePlan = snapshot.activePlan
        plans = snapshot.plans
        workoutTemplates = mergeSeedWorkouts(into: snapshot.workoutTemplates.isEmpty ? snapshot.activePlan.days : snapshot.workoutTemplates)
        exercises = mergeSeedExercises(into: snapshot.exercises.isEmpty ? SeedData.exercises : snapshot.exercises)
        scheduledWorkouts = snapshot.scheduledWorkouts
        workoutSessions = snapshot.workoutSessions
        cardioLogs = snapshot.cardioLogs
        bodyMetrics = snapshot.bodyMetrics
        progressPhotos = snapshot.progressPhotos
        gymPasses = snapshot.gymPasses
        gymVisits = snapshot.gymVisits
        goals = snapshot.goals
        health = snapshot.health
        activeWorkout = snapshot.activeWorkout
        activeWorkoutDrafts = snapshot.activeWorkoutDrafts ?? []
        activeWorkoutStatus = snapshot.activeWorkoutStatus
        
        sanitizeAvailableEquipment()
        
        isRestoring = false
        persistence.save(currentSnapshot)
    }

    private static func loadLegacySnapshot() -> AppSnapshot? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = appSupport.appendingPathComponent("Reps", isDirectory: true).appendingPathComponent("store.json")

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    private func mergeSeedExercises(into storedExercises: [Exercise]) -> [Exercise] {
        let curatedStored = storedExercises.filter { $0.sourceName != "free-exercise-db" }
        let existingNames = Set(curatedStored.map { $0.name.lowercased() })
        let missing = SeedData.exercises.filter { !existingNames.contains($0.name.lowercased()) }
        return curatedStored + missing
    }

    private func mergeSeedWorkouts(into storedWorkouts: [WorkoutDay]) -> [WorkoutDay] {
        let existingTitles = Set(storedWorkouts.map { $0.title.lowercased() })
        let missing = SeedData.workoutTemplates.filter { !existingTitles.contains($0.title.lowercased()) }
        return storedWorkouts + missing
    }
}

enum ProductFeature: String, CaseIterable, Identifiable {
    case unlimitedLogging
    case exerciseLibrary
    case customRoutines
    case basicAnalytics
    case advancedAnalytics
    case configurableProgression
    case automaticBackups
    case shareCards

    var id: String { rawValue }
}

enum ProductAccess {
    static func isEnabled(_ feature: ProductFeature, proEnabled: Bool = false) -> Bool {
        switch feature {
        case .unlimitedLogging, .exerciseLibrary, .customRoutines, .basicAnalytics:
            return true
        case .advancedAnalytics, .configurableProgression, .automaticBackups, .shareCards:
            return proEnabled
        }
    }
}

private extension CardioLog {
    var dedupeKey: String {
        "\(activityType.rawValue)-\(Int(date.timeIntervalSince1970 / 60))-\(durationMinutes)-\(Int((distanceKm ?? 0) * 100))"
    }
}

private struct OpenExerciseLibraryClient {
    private let datasetURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")!

    func fetchExercises() async throws -> [OpenExerciseRecord] {
        var request = URLRequest(url: datasetURL)
        request.timeoutInterval = 25
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([OpenExerciseRecord].self, from: data)
    }
}

private struct OpenExerciseRecord: Decodable {
    let id: String
    let name: String
    let level: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String?
    let images: [String]

    var domainExercise: Exercise? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return Exercise(
            name: name,
            aliases: [],
            muscleGroup: primaryMuscles.first.map(Self.displayMuscleGroup) ?? "Full Body",
            secondaryMuscles: secondaryMuscles.map(Self.displayMuscleGroup),
            equipment: equipment.map(Self.displayEquipment) ?? "Other",
            requiredEquipment: equipment.map { [Self.displayEquipment($0)] } ?? [],
            trackingType: trackingType,
            exerciseType: exerciseType,
            difficulty: difficulty,
            environment: environment,
            tags: [category, level].compactMap { $0 }.map(Self.displayName),
            mediaURL: images.first.map { Self.imageBaseURL + $0 },
            instructions: instructions.enumerated().map { index, instruction in
                "\(index + 1). \(instruction)"
            }.joined(separator: "\n"),
            commonMistakes: [],
            notes: sourceNotes,
            sourceID: id,
            sourceName: "free-exercise-db",
            sourceLicense: "Unlicense",
            sourceURL: "https://github.com/yuhonas/free-exercise-db"
        )
    }

    private var exerciseType: Exercise.ExerciseType {
        switch category?.lowercased() {
        case "cardio":
            return .cardio
        case "stretching":
            return .stretching
        default:
            return .strength
        }
    }

    private var difficulty: Exercise.Difficulty {
        switch level?.lowercased() {
        case "beginner":
            return .low
        case "expert":
            return .high
        default:
            return .medium
        }
    }

    private var environment: Exercise.Environment {
        switch equipment?.lowercased() {
        case "body only", "bands", "dumbbell", "kettlebells":
            return .both
        case "machine", "cable", "barbell":
            return .gym
        default:
            return .both
        }
    }

    private var trackingType: Exercise.TrackingType {
        switch category?.lowercased() {
        case "cardio", "stretching":
            return .duration
        default:
            if equipment?.lowercased() == "body only" {
                return .repsOnly
            }
            return .weightReps
        }
    }

    private var sourceNotes: String {
        [
            "Source: free-exercise-db (Unlicense)",
            level.map { "Level: \(Self.displayName($0))" },
            category.map { "Category: \(Self.displayName($0))" },
            secondaryMuscles.isEmpty ? nil : "Secondary muscles: \(secondaryMuscles.map(Self.displayName).joined(separator: ", "))"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static let imageBaseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    private static func displayMuscleGroup(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "abdominals": return "Core"
        case "adductors", "abductors", "calves", "hamstrings", "quadriceps": return "Legs"
        case "glutes": return "Glutes"
        case "lats", "middle back", "lower back", "traps": return "Back"
        case "chest": return "Chest"
        case "shoulders": return "Shoulders"
        case "biceps", "triceps", "forearms": return "Arms"
        default: return displayName(rawValue)
        }
    }

    private static func displayEquipment(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "body only": return "Bodyweight"
        case "e-z curl bar": return "EZ Bar"
        case "bands": return "Resistance Band"
        default: return displayName(rawValue)
        }
    }

    private static func displayName(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()
    private var commandHandler: (@MainActor @Sendable (WatchCommand) -> Void)?

    private override init() {
        super.init()
    }

    func configure(commandHandler: (@MainActor @Sendable (WatchCommand) -> Void)? = nil) {
        self.commandHandler = commandHandler
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    func publish(snapshot: SharedWorkoutSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context: [String: Any] = [
            "summary": snapshot.summary,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "hasActiveWorkout": snapshot.hasActiveWorkout,
            "workoutTitle": snapshot.workoutTitle,
            "elapsedSeconds": snapshot.elapsedSeconds,
            "pausedSeconds": snapshot.pausedSeconds,
            "completedSets": snapshot.completedSets,
            "totalSets": snapshot.totalSets,
            "volumeKg": snapshot.volumeKg,
            "isPaused": snapshot.isPaused
        ]
        context["planTitle"] = snapshot.planTitle
        context["sessionTitle"] = snapshot.sessionTitle
        context["exerciseName"] = snapshot.exerciseName
        context["exerciseIndex"] = snapshot.exerciseIndex
        context["totalExercises"] = snapshot.totalExercises
        context["currentExerciseCompletedSets"] = snapshot.currentExerciseCompletedSets
        context["currentExerciseTotalSets"] = snapshot.currentExerciseTotalSets
        context["currentSetWeightKg"] = snapshot.currentSetWeightKg
        context["currentSetReps"] = snapshot.currentSetReps
        context["restSeconds"] = snapshot.restSeconds
        context["restDurationSeconds"] = snapshot.restDurationSeconds
        context["estimatedRemainingSeconds"] = snapshot.estimatedRemainingSeconds
        context["waterLiters"] = snapshot.waterLiters
        context["musicTitle"] = snapshot.musicTitle
        context["musicArtist"] = snapshot.musicArtist
        context["isMusicPlaying"] = snapshot.isMusicPlaying
        context["nextExerciseName"] = snapshot.nextExerciseName
        context["exerciseHistorySummary"] = snapshot.exerciseHistorySummary
        context["gymPassName"] = snapshot.gymPassName
        context["gymMembershipID"] = snapshot.gymMembershipID
        context["gymCodeValue"] = snapshot.gymCodeValue
        context["gymCodeType"] = snapshot.gymCodeType
        if let heartRate = snapshot.heartRate {
            context["heartRate"] = heartRate
        }
        if let activeEnergyKcal = snapshot.activeEnergyKcal {
            context["activeEnergyKcal"] = activeEnergyKcal
        }

        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    private func handle(_ message: [String: Any]) {
        guard let rawCommand = message["command"] as? String,
              let command = WatchCommand(rawValue: rawCommand) else {
            return
        }

        let handler = commandHandler
        Task { @MainActor in
            handler?(command)
        }
    }
}

final class RepsWorkoutLiveActivityController: @unchecked Sendable {
    static let shared = RepsWorkoutLiveActivityController()

    private init() {}

    func sync(_ snapshot: SharedWorkoutSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        Task {
            if snapshot.hasActiveWorkout {
                if let activity = Activity<RepsWorkoutActivityAttributes>.activities.first {
                    await activity.update(ActivityContent(
                        state: RepsWorkoutActivityAttributes.ContentState(snapshot: snapshot),
                        staleDate: Date().addingTimeInterval(60)
                    ))
                } else {
                    let attributes = RepsWorkoutActivityAttributes(workoutTitle: snapshot.workoutTitle)
                    let content = ActivityContent(
                        state: RepsWorkoutActivityAttributes.ContentState(snapshot: snapshot),
                        staleDate: Date().addingTimeInterval(60)
                    )
                    _ = try? Activity<RepsWorkoutActivityAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                }
            } else {
                for activity in Activity<RepsWorkoutActivityAttributes>.activities {
                    await activity.end(ActivityContent(
                        state: RepsWorkoutActivityAttributes.ContentState(snapshot: snapshot),
                        staleDate: nil
                    ), dismissalPolicy: .after(Date().addingTimeInterval(30)))
                }
            }
        }
    }
}

private extension String {
    var normalizedExerciseKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

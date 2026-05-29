import Foundation
import UIKit

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
    @Published var activeWorkoutStatus: ActiveWorkoutStatus?

    private let persistence: SwiftDataPersistence
    private var isRestoring = false
    private var hasAttemptedExerciseLibrarySync = false

    init(persistence: SwiftDataPersistence = SwiftDataPersistence()) {
        self.persistence = persistence

        if let snapshot = persistence.loadSnapshot() ?? Self.loadLegacySnapshot() {
            restore(snapshot)
        } else {
            persistence.save(currentSnapshot)
        }
    }

    var todaysWorkout: WorkoutDay {
        let calendar = Calendar.current
        return scheduledWorkouts.first { calendar.isDateInToday($0.date) }?.workoutDay
            ?? activePlan.days.first
            ?? SeedData.pushDay
    }

    var weeklyCompletion: Double {
        FitnessMetrics.weeklyCompletion(completedWorkouts: workoutSessions.count, plannedWorkouts: activePlan.daysPerWeek)
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
        let sexAdjustment = (userProfile.sex ?? "").localizedCaseInsensitiveContains("female") || (userProfile.sex ?? "").localizedCaseInsensitiveContains("mujer") ? -161.0 : 5.0
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

    func completeOnboarding(profile: UserProfile) {
        userProfile = profile
        userProfile.onboardingCompleted = true
    }

    func completeOnboarding(result: OnboardingResult) {
        userProfile = result.profile
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
        let calendar = Calendar.current
        if let index = scheduledWorkouts.firstIndex(where: { calendar.isDateInToday($0.date) && $0.workoutDay.title == session.workoutTitle }) {
            scheduledWorkouts[index].status = .completed
        }
    }

    func startActiveWorkout(_ workout: WorkoutDay, elapsedSeconds: Int = 0, pausedSeconds: Int = 0, isPaused: Bool = false) {
        activeWorkoutStatus = ActiveWorkoutStatus(
            workoutTitle: workout.title,
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: 0,
            totalSets: workout.exercises.reduce(0) { $0 + max($1.targetSets, 1) },
            volumeKg: 0,
            isPaused: isPaused
        )
    }

    func updateActiveWorkout(elapsedSeconds: Int, pausedSeconds: Int, completedSets: Int, totalSets: Int, volumeKg: Int, isPaused: Bool) {
        guard var status = activeWorkoutStatus else { return }
        status.elapsedSeconds = elapsedSeconds
        status.pausedSeconds = pausedSeconds
        status.completedSets = completedSets
        status.totalSets = totalSets
        status.volumeKg = volumeKg
        status.isPaused = isPaused
        activeWorkoutStatus = status
    }

    func setActiveWorkoutPaused(_ paused: Bool) {
        guard var status = activeWorkoutStatus else { return }
        status.isPaused = paused
        activeWorkoutStatus = status
    }

    func clearActiveWorkout() {
        activeWorkoutStatus = nil
    }

    func addPlan(_ plan: WorkoutPlan, activate: Bool) {
        plans.append(plan)
        if activate {
            activePlan = plan
            generateSchedule(for: plan)
        }
    }

    func activatePlan(_ plan: WorkoutPlan) {
        activePlan = plan
        generateSchedule(for: plan)
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
            let existingNames = Set(exercises.map { $0.name.normalizedExerciseKey })
            let newExercises = mappedExercises.filter { !existingNames.contains($0.name.normalizedExerciseKey) }

            if newExercises.isEmpty {
                exerciseLibrarySyncMessage = String(localized: "La biblioteca de ejercicios está actualizada.")
            } else {
                exercises.append(contentsOf: newExercises)
                exerciseLibrarySyncMessage = String(localized: "Added \(newExercises.count) open exercise records.")
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
        try data.write(to: url, options: .atomic)
        return url
    }

    func exportCSVURL() throws -> URL {
        let csv = CSVExporter(snapshot: currentSnapshot).makeCSV()
        let url = exportURL(fileName: "reps-export-\(Self.exportDateStamp()).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
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
        let title = selected?.workoutTitle ?? "Reps Workout"
        let duration = selected?.durationMinutes ?? 0
        let volume = selected.map { Int(FitnessMetrics.totalVolumeKg(for: [$0])) } ?? 0
        let sets = selected.map { FitnessMetrics.completedSets(in: $0).count } ?? 0
        let url = exportURL(fileName: "reps-share-\(Self.exportDateStamp()).png")
        let image = WorkoutShareImageRenderer.render(title: title, duration: duration, volume: volume, sets: sets)
        guard let data = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
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

        let generated = (0..<count).compactMap { offset -> ScheduledWorkout? in
            guard let date = calendar.date(byAdding: .day, value: offset * 2, to: today) else {
                return nil
            }
            return ScheduledWorkout(date: date, workoutDay: days[offset % days.count], status: .scheduled)
        }

        scheduledWorkouts = scheduledWorkouts.filter { !calendar.isDate($0.date, equalTo: today, toGranularity: .weekOfYear) || $0.status == .completed }
        scheduledWorkouts.append(contentsOf: generated)
    }

    private func save() {
        guard !isRestoring else {
            return
        }

        persistence.save(currentSnapshot)
    }

    private func exportURL(fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RepsExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
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
            health: health
        )
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

private struct CSVExporter {
    let snapshot: AppSnapshot

    func makeCSV() -> String {
        [
            section("exercises", rows: exerciseRows),
            section("workout_sessions", rows: sessionRows),
            section("sets", rows: setRows),
            section("cardio_logs", rows: cardioRows),
            section("body_metrics", rows: bodyRows),
            section("progress_photos", rows: progressPhotoRows),
            section("gym_passes", rows: gymPassRows),
            section("gym_visits", rows: gymVisitRows),
            section("goals", rows: goalRows)
        ]
        .joined(separator: "\n\n")
    }

    private var exerciseRows: [[String]] {
        [["id", "name", "muscle_group", "equipment", "type", "difficulty", "environment", "source"]] +
        snapshot.exercises.map {
            [
                $0.id.uuidString,
                $0.name,
                $0.muscleGroup,
                $0.equipment,
                $0.exerciseType.rawValue,
                $0.difficulty.rawValue,
                $0.environment.rawValue,
                $0.sourceName ?? "manual"
            ]
        }
    }

    private var sessionRows: [[String]] {
        [["id", "title", "date", "duration_min", "location", "context", "session_rpe", "volume_kg", "notes"]] +
        snapshot.workoutSessions.map {
            [
                $0.id.uuidString,
                $0.workoutTitle,
                Self.format($0.date),
                "\($0.durationMinutes)",
                $0.location.rawValue,
                $0.contextTag.rawValue,
                Self.value($0.sessionRPE),
                Self.value(FitnessMetrics.totalVolumeKg(for: [$0])),
                $0.notes ?? ""
            ]
        }
    }

    private var setRows: [[String]] {
        let header = [["session_id", "exercise", "set_number", "type", "weight_kg", "reps", "rpe", "rir", "tempo", "rest_seconds", "pr", "notes"]]
        let rows = snapshot.workoutSessions.flatMap { session in
            (session.exerciseLogs ?? [ExerciseLog(exercise: SeedData.bench, notes: session.notes ?? "", sets: session.sets)]).flatMap { log in
                log.sets.map { set in
                    let rir = set.rir.map(String.init) ?? ""
                    let rest = set.previousRestSeconds.map(String.init) ?? ""
                    let pr = set.isPersonalRecord ? "true" : "false"
                    let notes = set.notes ?? ""
                    return [
                        session.id.uuidString,
                        log.exercise.name,
                        String(set.setNumber),
                        set.setType.rawValue,
                        Self.value(set.weightKg),
                        String(set.reps),
                        Self.value(set.rpe),
                        rir,
                        set.tempo ?? "",
                        rest,
                        pr,
                        notes
                    ] as [String]
                }
            }
        }
        return header + rows
    }

    private var cardioRows: [[String]] {
        [["id", "activity", "date", "duration_min", "distance_km", "avg_hr", "max_hr", "calories", "rpe", "notes"]] +
        snapshot.cardioLogs.map {
            [
                $0.id.uuidString,
                $0.activityType.rawValue,
                Self.format($0.date),
                "\($0.durationMinutes)",
                Self.value($0.distanceKm),
                Self.value($0.averageHeartRate),
                Self.value($0.maxHeartRate),
                Self.value($0.estimatedCalories),
                Self.value($0.rpe),
                $0.notes ?? ""
            ]
        }
    }

    private var bodyRows: [[String]] {
        [["id", "date", "weight_kg", "height_cm", "body_fat", "waist_cm", "sleep_hours", "sleep_quality", "fatigue", "stress", "soreness", "source"]] +
        snapshot.bodyMetrics.map {
            [
                $0.id.uuidString,
                Self.format($0.date),
                Self.value($0.weightKg),
                Self.value($0.heightCm),
                Self.value($0.bodyFatPercentage),
                Self.value($0.waistCm),
                Self.value($0.sleepHours),
                $0.sleepQuality.map(String.init) ?? "",
                $0.fatigue.map(String.init) ?? "",
                $0.stress.map(String.init) ?? "",
                $0.sorenessNotes ?? "",
                $0.source.rawValue
            ]
        }
    }

    private var progressPhotoRows: [[String]] {
        [["id", "date", "weight_kg", "note", "image_bytes"]] +
        snapshot.progressPhotos.map {
            [
                $0.id.uuidString,
                Self.format($0.date),
                Self.value($0.weightKg),
                $0.note ?? "",
                "\($0.imageData.count)"
            ]
        }
    }

    private var gymPassRows: [[String]] {
        [["id", "gym", "membership_id", "code_type", "notes"]] +
        snapshot.gymPasses.map {
            [$0.id.uuidString, $0.gymName, $0.membershipID, $0.codeType.rawValue, $0.notes ?? ""]
        }
    }

    private var gymVisitRows: [[String]] {
        [["id", "gym", "date", "location_note", "workout"]] +
        snapshot.gymVisits.map {
            [$0.id.uuidString, $0.gymName, Self.format($0.date), $0.locationNote ?? "", $0.workoutTitle ?? ""]
        }
    }

    private var goalRows: [[String]] {
        [["id", "kind", "title", "current", "target", "unit", "deadline"]] +
        snapshot.goals.map {
            [
                $0.id.uuidString,
                $0.kind.rawValue,
                $0.title,
                Self.value($0.current),
                Self.value($0.target),
                $0.unit,
                $0.deadline.map(Self.format) ?? ""
            ]
        }
    }

    private func section(_ name: String, rows: [[String]]) -> String {
        (["# \(name)"] + rows.map { $0.map(Self.escape).joined(separator: ",") }).joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func value(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? ""
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

private struct CSVImporter {
    let csv: String

    func cardioLogs() -> [CardioLog] {
        rows(in: "cardio_logs").compactMap { row in
            guard row.count >= 10,
                  let activity = CardioLog.ActivityType(rawValue: row[1]),
                  let date = Self.date(row[2]),
                  let duration = Int(row[3]) else {
                return nil
            }
            return CardioLog(
                activityType: activity,
                date: date,
                durationMinutes: duration,
                distanceKm: Self.double(row[4]),
                averageHeartRate: Self.double(row[5]),
                maxHeartRate: Self.double(row[6]),
                estimatedCalories: Self.double(row[7]),
                rpe: Self.double(row[8]),
                notes: row[9].isEmpty ? nil : row[9]
            )
        }
    }

    func bodyMetrics() -> [BodyMetric] {
        rows(in: "body_metrics").compactMap { row in
            guard row.count >= 12,
                  let date = Self.date(row[1]),
                  let weight = Self.double(row[2]),
                  let height = Self.double(row[3]) else {
                return nil
            }
            return BodyMetric(
                date: date,
                weightKg: weight,
                heightCm: height,
                bodyFatPercentage: Self.double(row[4]),
                waistCm: Self.double(row[5]),
                sleepHours: Self.double(row[6]),
                sleepQuality: Int(row[7]),
                fatigue: Int(row[8]),
                stress: Int(row[9]),
                sorenessNotes: row[10].isEmpty ? nil : row[10],
                source: BodyMetric.Source(rawValue: row[11]) ?? .manual
            )
        }
    }

    private func rows(in sectionName: String) -> [[String]] {
        let lines = csv.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0 == "# \(sectionName)" }) else {
            return []
        }

        return lines.dropFirst(start + 2)
            .prefix { !$0.hasPrefix("# ") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(Self.parseLine)
    }

    private static func parseLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quoted = false
        for character in line {
            if character == "\"" {
                quoted.toggle()
            } else if character == "," && !quoted {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }

    private static func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func double(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }
}

private enum WorkoutShareImageRenderer {
    static func render(title: String, duration: Int, volume: Int, sets: Int) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let accent = UIColor(red: 0.52, green: 0.14, blue: 0.86, alpha: 1)
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: 72, y: 92, width: 936, height: 1166), cornerRadius: 42).fill()

            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(x: 96, y: 116, width: 888, height: 1118), cornerRadius: 34).fill()

            draw("Reps", at: CGPoint(x: 140, y: 170), size: 54, weight: .heavy, color: accent)
            draw(title, at: CGPoint(x: 140, y: 300), size: 76, weight: .bold, color: .black)
            draw("Entreno completado", at: CGPoint(x: 140, y: 250), size: 32, weight: .semibold, color: .darkGray)

            drawMetric(title: "Duración", value: "\(duration) min", x: 140, y: 520)
            drawMetric(title: "Series", value: "\(sets)", x: 560, y: 520)
            drawMetric(title: "Volumen", value: "\(volume) kg", x: 140, y: 760)

            draw("Sin peso corporal, fotos ni datos sensibles.", at: CGPoint(x: 140, y: 1080), size: 30, weight: .medium, color: .darkGray)
        }
    }

    private static func drawMetric(title: String, value: String, x: CGFloat, y: CGFloat) {
        draw(title, at: CGPoint(x: x, y: y), size: 30, weight: .semibold, color: .darkGray)
        draw(value, at: CGPoint(x: x, y: y + 44), size: 64, weight: .bold, color: .black)
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: UIFont.Weight, color: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        text.draw(at: point, withAttributes: attributes)
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

import Testing
import Foundation
@testable import Reps

struct RepsTests {
    @Test func weeklyCompletionCapsAtOne() async throws {
        let store = await AppStore()
        let completion = await store.weeklyCompletion
        #expect(completion <= 1)
    }

    @Test func totalVolumeUsesCompletedSetsOnly() {
        let session = WorkoutSession(
            workoutTitle: "Push",
            date: .now,
            durationMinutes: 45,
            sets: [
                SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true),
                SetLog(setNumber: 2, weightKg: 100, reps: 5, completed: false),
                SetLog(setNumber: 3, weightKg: 80, reps: 10, completed: true)
            ]
        )

        #expect(FitnessMetrics.totalVolumeKg(for: [session]) == 1_300)
    }

    @Test func totalVolumePrefersDetailedExerciseLogs() {
        let session = WorkoutSession(
            workoutTitle: "Push",
            date: .now,
            durationMinutes: 45,
            sets: [
                SetLog(setNumber: 1, weightKg: 10, reps: 1, completed: true)
            ],
            exerciseLogs: [
                ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true),
                    SetLog(setNumber: 2, weightKg: 60, reps: 8, completed: true)
                ])
            ]
        )

        #expect(FitnessMetrics.totalVolumeKg(for: [session]) == 1_080)
    }

    @Test func completedExerciseLogsExcludePlannedExercises() {
        let session = WorkoutSession(
            workoutTitle: "Push",
            date: .now,
            durationMinutes: 45,
            sets: [
                SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true),
                SetLog(setNumber: 2, weightKg: 100, reps: 5, completed: false)
            ],
            exerciseLogs: [
                ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true),
                    SetLog(setNumber: 2, weightKg: 60, reps: 8, completed: false)
                ]),
                ExerciseLog(exercise: SeedData.squat, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: false)
                ])
            ]
        )

        let logs = FitnessMetrics.completedExerciseLogs(in: session)

        #expect(logs.map(\.exercise.name) == [SeedData.bench.name])
        #expect(logs.flatMap(\.sets).count == 1)
        #expect(logs.flatMap(\.sets).allSatisfy { $0.completed })
    }

    @Test func estimatedOneRepMaxUsesEpleyFormula() {
        let estimate = FitnessMetrics.estimatedOneRepMax(weightKg: 100, reps: 5)
        #expect(abs(estimate - 116.666) < 0.01)
    }

    @Test func effectiveVolumeExcludesWarmups() {
        let session = WorkoutSession(
            workoutTitle: "Push",
            date: .now,
            durationMinutes: 40,
            sets: [
                SetLog(setNumber: 1, weightKg: 40, reps: 10, completed: true, setType: .warmUp, rpe: 4),
                SetLog(setNumber: 2, weightKg: 80, reps: 8, completed: true, setType: .work, rpe: 8)
            ]
        )

        #expect(AnalyticsEngine.effectiveVolumeKg(for: [session]) == 640)
    }

    @Test func intensityDistributionBucketsRPEValues() {
        let session = WorkoutSession(
            workoutTitle: "Push",
            date: .now,
            durationMinutes: 40,
            sets: [
                SetLog(setNumber: 1, weightKg: 50, reps: 10, completed: true, rpe: 5),
                SetLog(setNumber: 2, weightKg: 60, reps: 8, completed: true, rpe: 7),
                SetLog(setNumber: 3, weightKg: 70, reps: 6, completed: true, rpe: 8.5),
                SetLog(setNumber: 4, weightKg: 80, reps: 4, completed: true, rpe: 9.5)
            ]
        )

        let distribution = AnalyticsEngine.intensityDistribution(for: [session])

        #expect(distribution.map(\.count) == [1, 1, 1, 1])
    }

    @Test func trainingBatteryDropsWithHighFatigueAndRecoversWithRest() {
        let calendar = Calendar.current
        let hardSession = WorkoutSession(
            workoutTitle: "Legs",
            date: .now,
            durationMinutes: 80,
            sets: [
                SetLog(setNumber: 1, weightKg: 120, reps: 6, completed: true, rpe: 9, previousRestSeconds: 45),
                SetLog(setNumber: 2, weightKg: 120, reps: 5, completed: true, rpe: 9.5, previousRestSeconds: 50),
                SetLog(setNumber: 3, weightKg: 110, reps: 8, completed: true, rpe: 9, previousRestSeconds: 60),
                SetLog(setNumber: 4, weightKg: 100, reps: 10, completed: true, rpe: 8.5, previousRestSeconds: 70)
            ],
            sessionRPE: 9,
            energyBefore: 4,
            energyAfter: 2
        )
        let lowBattery = FitnessMetrics.trainingBatteryStatus(
            sessions: [hardSession],
            scheduledWorkouts: [],
            activePlan: SeedData.pushPullLegsPlan,
            bodyMetrics: [BodyMetric(date: .now, weightKg: 80, heightCm: 178, sleepHours: 5.5, fatigue: 5, stress: 4, source: .manual)],
            health: HealthSyncState()
        )
        let restedBattery = FitnessMetrics.trainingBatteryStatus(
            sessions: [WorkoutSession(workoutTitle: "Push", date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, durationMinutes: 45, sets: [])],
            scheduledWorkouts: [],
            activePlan: SeedData.pushPullLegsPlan,
            bodyMetrics: [BodyMetric(date: .now, weightKg: 80, heightCm: 178, sleepHours: 8, fatigue: 1, stress: 1, source: .manual)],
            health: HealthSyncState()
        )

        #expect(lowBattery.level < restedBattery.level)
        #expect(lowBattery.fatigueLoad > restedBattery.fatigueLoad)
    }

    @Test func projectedBatteryUsesRoutineVolumeAndRest() {
        var shortRest = SeedData.pushDay
        var longRest = SeedData.pushDay
        for index in shortRest.exercises.indices {
            shortRest.exercises[index].restSeconds = 45
        }
        for index in longRest.exercises.indices {
            longRest.exercises[index].restSeconds = 180
        }

        let shortRestProjection = FitnessMetrics.projectedBatteryLevel(after: shortRest, from: 80)
        let longRestProjection = FitnessMetrics.projectedBatteryLevel(after: longRest, from: 80)

        #expect(shortRestProjection < longRestProjection)
    }

    @Test func progressionEngineSuggestsIncreaseAfterSuccess() {
        let item = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 3,
            repRange: "8-10",
            previous: "60kg x 10",
            progressionType: .doubleProgression,
            incrementKg: 2.5
        )
        let sets = [
            SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true, rpe: 7),
            SetLog(setNumber: 2, weightKg: 60, reps: 10, completed: true, rpe: 8),
            SetLog(setNumber: 3, weightKg: 60, reps: 10, completed: true, rpe: 8)
        ]

        let suggestion = ProgressionEngine.nextSuggestion(for: item, recentSets: sets)

        #expect(suggestion.targetWeightKg == 62.5)
        #expect(suggestion.targetReps == 8)
        #expect(!suggestion.shouldDeload)
    }

    @Test func progressionEngineSuggestsDeloadWhenMissingWithHighEffort() {
        let item = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 3,
            repRange: "8-10",
            previous: "60kg x 10",
            progressionType: .linear,
            incrementKg: 2.5
        )
        let sets = [
            SetLog(setNumber: 1, weightKg: 60, reps: 7, completed: true, rpe: 9.5),
            SetLog(setNumber: 2, weightKg: 60, reps: 6, completed: true, rpe: 10)
        ]

        let suggestion = ProgressionEngine.nextSuggestion(for: item, recentSets: sets)

        #expect(suggestion.shouldDeload)
        #expect(suggestion.targetWeightKg == 55)
    }

    @Test func progressionEngineCalculatesPercentOneRepMaxTarget() {
        let item = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 3,
            repRange: "75% x 5",
            previous: "100kg x 5",
            progressionType: .percentOneRepMax,
            incrementKg: 2.5
        )
        let sets = [
            SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true, rpe: 8)
        ]

        let suggestion = ProgressionEngine.nextSuggestion(for: item, recentSets: sets, weightIncrementKg: 2.5)

        #expect(suggestion.targetWeightKg == 87.5)
        #expect(suggestion.explanation.contains("75%"))
    }

    @Test func progressionEngineDetectsStall() {
        let sets = [
            SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true, rpe: 9),
            SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true, rpe: 9),
            SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true, rpe: 9),
            SetLog(setNumber: 1, weightKg: 105, reps: 5, completed: true, rpe: 8)
        ]

        #expect(ProgressionEngine.isStalled(recentSets: sets))
    }

    @Test func exerciseSubstitutionPrefersSameMuscleAndAvailableEquipment() {
        let candidates = ExerciseSubstitutionService.candidates(
            for: SeedData.bench,
            in: SeedData.exercises,
            availableEquipment: ["Dumbbells", "Bodyweight"]
        )

        #expect(candidates.allSatisfy { $0.id != SeedData.bench.id })
        #expect(candidates.contains { $0.name == SeedData.incline.name || $0.name == SeedData.floorPress.name || $0.name == SeedData.pushup.name })
    }

    @Test func unitConversionsRoundTrip() {
        let pounds = UnitConverter.pounds(fromKilograms: 100)
        let kilograms = UnitConverter.kilograms(fromPounds: pounds)
        #expect(abs(kilograms - 100) < 0.001)
    }

    @Test @MainActor func swiftDataPersistenceRoundTripsFullSnapshot() {
        let persistence = SwiftDataPersistence(inMemory: true)
        let snapshot = AppSnapshot.seed

        persistence.save(snapshot)

        let loaded = persistence.loadSnapshot()
        #expect(loaded?.activePlan.id == snapshot.activePlan.id)
        #expect(loaded?.plans.count == snapshot.plans.count)
        #expect(loaded?.exercises.count == snapshot.exercises.count)
        #expect(loaded?.scheduledWorkouts.count == snapshot.scheduledWorkouts.count)
        #expect(loaded?.workoutSessions.count == snapshot.workoutSessions.count)
        #expect(loaded?.cardioLogs.count == snapshot.cardioLogs.count)
        #expect(loaded?.bodyMetrics.count == snapshot.bodyMetrics.count)
        #expect(loaded?.goals.count == snapshot.goals.count)
    }

    @Test @MainActor func swiftDataPersistenceRoundTripsAdvancedFields() {
        let persistence = SwiftDataPersistence(inMemory: true)
        var snapshot = AppSnapshot.seed
        snapshot.userProfile.avatarImageData = Data([1, 2, 3])
        snapshot.progressPhotos = [
            ProgressPhoto(date: .now, imageData: Data([4, 5, 6]), weightKg: 82.4, note: "Front relaxed")
        ]
        snapshot.bodyMetrics = [
            BodyMetric(
                date: .now,
                weightKg: 82.4,
                heightCm: 180,
                waterLiters: 2.3,
                dietaryEnergyKcal: 2_450,
                source: .manual
            )
        ]
        snapshot.gymPasses = [
            GymPass(gymName: "Test Gym", membershipID: "A-100", codeValue: "A-100", codeType: .qr)
        ]
        snapshot.gymVisits = [
            GymVisit(gymName: "Test Gym", date: .now, locationNote: "Downtown", workoutTitle: "Push")
        ]
        snapshot.cardioLogs = [
            CardioLog(activityType: .rowing, date: .now, durationMinutes: 20, distanceKm: 4.2, averageHeartRate: 142, rpe: 7)
        ]
        snapshot.workoutSessions = [
            WorkoutSession(
                workoutTitle: "Advanced",
                date: .now,
                durationMinutes: 45,
                sets: [
                    SetLog(
                        setNumber: 1,
                        weightKg: 100,
                        reps: 5,
                        completed: true,
                        setType: .topSet,
                        rpe: 8.5,
                        rir: 1,
                        tempo: "3-1-1",
                        previousRestSeconds: 120,
                        isPersonalRecord: true,
                        notes: "Fast bar speed"
                    )
                ],
                sessionRPE: 8,
                energyBefore: 3,
                energyAfter: 4
            )
        ]

        persistence.save(snapshot)

        let loaded = persistence.loadSnapshot()
        #expect(loaded?.userProfile.avatarImageData == Data([1, 2, 3]))
        #expect(loaded?.bodyMetrics.first?.waterLiters == 2.3)
        #expect(loaded?.bodyMetrics.first?.dietaryEnergyKcal == 2_450)
        #expect(loaded?.progressPhotos.first?.imageData == Data([4, 5, 6]))
        #expect(loaded?.progressPhotos.first?.weightKg == 82.4)
        #expect(loaded?.gymPasses.first?.codeType == .qr)
        #expect(loaded?.gymPasses.first?.membershipID == "A-100")
        #expect(loaded?.gymVisits.first?.locationNote == "Downtown")
        #expect(loaded?.cardioLogs.first?.activityType == .rowing)
        #expect(loaded?.workoutSessions.first?.sets.first?.setType == .topSet)
        #expect(loaded?.workoutSessions.first?.sets.first?.rpe == 8.5)
        #expect(loaded?.workoutSessions.first?.sets.first?.isPersonalRecord == true)
        #expect(loaded?.workoutSessions.first?.sessionRPE == 8)
    }

    @Test @MainActor func exportsCSVAndImportsBackup() throws {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        store.addCardioLog(CardioLog(activityType: .rowing, date: .now, durationMinutes: 12, distanceKm: 2.1))
        store.saveBodyMetric(BodyMetric(date: .now, weightKg: 80, heightCm: 178, waterLiters: 2.1, dietaryEnergyKcal: 2_300, source: .manual))
        store.addProgressPhoto(ProgressPhoto(date: .now, imageData: Data([7, 8]), weightKg: 80, note: "Side"))
        store.addGymPass(GymPass(gymName: "Test Gym", membershipID: "B-200", codeValue: "B-200", codeType: .barcode))
        store.addGymVisit(GymVisit(gymName: "Test Gym", date: .now, locationNote: "North", workoutTitle: "Pull"))

        let csvURL = try store.exportCSVURL()
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        #expect(csv.contains("# workout_sessions"))
        #expect(csv.contains("# cardio_logs"))
        #expect(csv.contains("# progress_photos"))
        #expect(csv.contains("# gym_passes"))
        #expect(csv.contains("# gym_visits"))
        #expect(csv.contains("water_liters"))
        #expect(csv.contains("2.1"))
        #expect(csv.contains("2300.0"))
        #expect(csv.contains("rowing"))
        #expect(csv.contains("Test Gym"))

        let backupURL = try store.exportBackupURL()
        let restored = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        try restored.importBackup(from: backupURL)
        #expect(restored.cardioLogs.contains { $0.activityType == .rowing && $0.durationMinutes == 12 })
        #expect(restored.progressPhotos.contains { $0.note == "Side" })
        #expect(restored.gymPasses.contains { $0.membershipID == "B-200" })
        #expect(restored.gymVisits.contains { $0.locationNote == "North" })

        let imported = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        try imported.importCSV(from: csvURL)
        #expect(imported.cardioLogs.contains { $0.activityType == .rowing && $0.durationMinutes == 12 })
        #expect(imported.bodyMetrics.contains { $0.waterLiters == 2.1 && $0.dietaryEnergyKcal == 2_300 })
    }

    @Test @MainActor func resetAllDataReturnsToOnboardingSeed() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        store.userProfile.onboardingCompleted = true
        store.addCardioLog(CardioLog(activityType: .rowing, date: .now, durationMinutes: 12))

        store.resetAllData()

        #expect(store.userProfile.onboardingCompleted == false)
        #expect(store.cardioLogs.isEmpty)
        #expect(store.activePlan.id == AppSnapshot.seed.activePlan.id)
    }

    @Test @MainActor func shareImageExportCreatesPNG() throws {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        let url = try store.exportWorkoutShareImageURL()
        let data = try Data(contentsOf: url)

        #expect(url.pathExtension == "png")
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func productAccessSeparatesFreeAndProFeatures() {
        #expect(ProductAccess.isEnabled(.unlimitedLogging))
        #expect(!ProductAccess.isEnabled(.advancedAnalytics))
        #expect(ProductAccess.isEnabled(.advancedAnalytics, proEnabled: true))
    }
}

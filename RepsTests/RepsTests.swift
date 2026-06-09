import Testing
import Foundation
import UIKit
import MuscleMap
@testable import Reps

struct RepsTests {
    @Test func weeklyCompletionCapsAtOne() async throws {
        let store = await AppStore()
        let completion = await store.weeklyCompletion
        #expect(completion <= 1)
    }

    @Test @MainActor func suggestedPlanUsesNormalizedResistanceBandEquipment() {
        let store = AppStore()
        store.userProfile.trainingLocation = .gym
        store.userProfile.availableEquipment = ["Resistance Band"]

        let plan = store.createSuggestedPlanForAvailableEquipment()

        #expect(plan.name == "Casa según mi equipo")
        #expect(store.activePlan.id == plan.id)
        #expect(store.plans.contains { $0.id == plan.id })
        #expect(store.health.message == "Rutina creada: Casa según mi equipo. Está activa en Planes.")
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

    @Test func exerciseAnatomyUsesSpecificTricepsForCableExtension() {
        let exercise = Exercise(
            name: "Cable One Arm Tricep Extension",
            muscleGroup: "Arms",
            equipment: "Cable"
        )

        let descriptor = ExerciseAnatomyDescriptor(exercise: exercise)

        #expect(descriptor.muscles == [.triceps])
        #expect(descriptor.region.side == .front)
    }

    @Test func exerciseAnatomyUsesSpecificLegMuscles() {
        let legExtension = Exercise(name: "Machine Seated Leg Extension", muscleGroup: "Legs", equipment: "Machine")
        let legCurl = Exercise(name: "Lying Leg Curl", muscleGroup: "Legs", equipment: "Machine")
        let calfRaise = Exercise(name: "Standing Calf Raise", muscleGroup: "Legs", equipment: "Machine")

        #expect(ExerciseAnatomyDescriptor(exercise: legExtension).muscles.contains(.quadriceps))
        #expect(!ExerciseAnatomyDescriptor(exercise: legExtension).muscles.contains(.hamstring))
        #expect(ExerciseAnatomyDescriptor(exercise: legCurl).muscles.contains(.hamstring))
        #expect(ExerciseAnatomyDescriptor(exercise: calfRaise).muscles.contains(.calves))
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

    @Test func csvGymPassRoundTripPreservesCodeValue() {
        let pass = GymPass(
            gymName: "Downtown Gym",
            membershipID: "member-123",
            codeValue: "qr-secret-456",
            codeType: .qr,
            notes: "Main access"
        )
        var snapshot = AppSnapshot.empty
        snapshot.gymPasses = [pass]

        let csv = CSVExporter(snapshot: snapshot).makeCSV()
        let imported = CSVImporter(csv: csv).gymPasses()

        #expect(imported.count == 1)
        #expect(imported.first?.membershipID == "member-123")
        #expect(imported.first?.codeValue == "qr-secret-456")
        #expect(imported.first?.codeType == .qr)
        #expect(imported.first?.notes == "Main access")
    }

    @Test func csvGymPassImportSupportsLegacyRows() {
        let csv = """
        # gym_passes
        id,gym,membership_id,code_type,notes
        legacy-id,Downtown Gym,member-123,barcode,Legacy access
        """

        let imported = CSVImporter(csv: csv).gymPasses()

        #expect(imported.count == 1)
        #expect(imported.first?.membershipID == "member-123")
        #expect(imported.first?.codeValue == "member-123")
        #expect(imported.first?.codeType == .barcode)
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

    @Test func smartProgressionAdvisorUsesDetailedExerciseHistory() {
        let workout = WorkoutDay(
            title: "Push",
            subtitle: "Strength",
            durationMinutes: 45,
            exercises: [
                WorkoutExercise(
                    exercise: SeedData.bench,
                    targetSets: 3,
                    repRange: "8-10",
                    previous: "60kg x 10",
                    progressionType: .doubleProgression,
                    incrementKg: 2.5
                )
            ]
        )
        let session = WorkoutSession(
            workoutTitle: "Previous Push",
            date: .now,
            durationMinutes: 45,
            sets: [],
            exerciseLogs: [
                ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true, rpe: 7),
                    SetLog(setNumber: 2, weightKg: 60, reps: 10, completed: true, rpe: 8),
                    SetLog(setNumber: 3, weightKg: 60, reps: 10, completed: true, rpe: 8)
                ])
            ]
        )

        let recommendations = SmartProgressionAdvisor.recommendations(
            for: workout,
            sessions: [session],
            weightIncrementKg: 2.5
        )

        #expect(recommendations.count == 1)
        #expect(recommendations.first?.exercise.id == SeedData.bench.id)
        #expect(recommendations.first?.suggestion.targetWeightKg == 62.5)
        #expect(recommendations.first?.suggestion.targetReps == 8)
    }

    @Test func smartProgressionAdvisorPrioritizesDeloadsAndRespectsLimit() {
        let benchItem = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 3,
            repRange: "8-10",
            previous: "60kg x 10",
            progressionType: .linear,
            incrementKg: 2.5
        )
        let squatItem = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 3,
            repRange: "8-10",
            previous: "100kg x 10",
            progressionType: .doubleProgression,
            incrementKg: 2.5
        )
        let workout = WorkoutDay(
            title: "Full Body",
            subtitle: "Strength",
            durationMinutes: 55,
            exercises: [squatItem, benchItem]
        )
        let session = WorkoutSession(
            workoutTitle: "Previous Full Body",
            date: .now,
            durationMinutes: 55,
            sets: [],
            exerciseLogs: [
                ExerciseLog(exercise: SeedData.squat, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 100, reps: 10, completed: true, rpe: 7),
                    SetLog(setNumber: 2, weightKg: 100, reps: 10, completed: true, rpe: 8),
                    SetLog(setNumber: 3, weightKg: 100, reps: 10, completed: true, rpe: 8)
                ]),
                ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                    SetLog(setNumber: 1, weightKg: 60, reps: 7, completed: true, rpe: 9.5),
                    SetLog(setNumber: 2, weightKg: 60, reps: 6, completed: true, rpe: 10)
                ])
            ]
        )

        let recommendations = SmartProgressionAdvisor.recommendations(
            for: workout,
            sessions: [session],
            weightIncrementKg: 2.5,
            limit: 1
        )

        #expect(recommendations.count == 1)
        #expect(recommendations.first?.exercise.id == SeedData.bench.id)
        #expect(recommendations.first?.suggestion.shouldDeload == true)
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

    @Test func seedCatalogProvidesCompetitiveFallbackLibrary() {
        #expect(SeedData.exercises.count >= 300)
        #expect(Set(SeedData.exercises.map { $0.name.lowercased() }).count == SeedData.exercises.count)
        #expect(SeedData.exercises.contains { $0.exerciseType == .cardio })
        #expect(SeedData.exercises.contains { $0.exerciseType == .mobility })
        #expect(SeedData.exercises.contains { $0.exerciseType == .stretching })
        #expect(SeedData.exercises.contains { $0.environment == .home })
        #expect(SeedData.exercises.contains { $0.environment == .gym })
        #expect(SeedData.exercises.contains { !$0.requiredEquipment.isEmpty && ($0.instructions ?? "").isEmpty == false })
    }

    @Test func seedProgramsProvideRealMultiWeekPlans() {
        #expect(SeedData.defaultPlans.count >= 10)
        #expect(SeedData.defaultPlans.contains { $0.name == "Strength 5x5" && $0.totalWeeks == 12 })
        #expect(SeedData.defaultPlans.contains { $0.name == "Hypertrophy 8-Week" && $0.daysPerWeek == 5 })
        #expect(SeedData.defaultPlans.contains { $0.location == .home })
        #expect(SeedData.defaultPlans.allSatisfy { plan in
            plan.totalWeeks >= 6
                && plan.totalWeeks <= 12
                && plan.daysPerWeek > 0
                && !plan.days.isEmpty
                && plan.days.allSatisfy { !$0.exercises.isEmpty }
        })
        #expect(SeedData.defaultPlans.flatMap(\.days).flatMap(\.exercises).contains { $0.progressionType != .none })
    }

    @Test @MainActor func appStoreMergesSeedPlansIntoEmptySnapshot() {
        let persistence = SwiftDataPersistence(inMemory: true)
        var snapshot = AppSnapshot.empty
        snapshot.plans = []
        persistence.save(snapshot)

        let store = AppStore(persistence: persistence)

        #expect(store.plans.count >= SeedData.defaultPlans.count)
        #expect(store.plans.contains { $0.name == "Full Body Beginner 3-Day" })
        #expect(store.plans.contains { $0.name == "Express 30-Minute Strength" })
    }

    @Test func substitutionRespectsAvailableEquipment() {
        let candidates = ExerciseSubstitutionService.candidates(
            for: SeedData.bench,
            in: SeedData.exercises,
            availableEquipment: ["Bodyweight"]
        )

        #expect(!candidates.isEmpty)
        #expect(candidates.allSatisfy { exercise in
            let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
            return required.contains { $0.localizedCaseInsensitiveContains("bodyweight") }
        })
    }

    @Test func substitutionReasonsExplainCandidateFit() throws {
        let candidate = try #require(ExerciseSubstitutionService.candidates(
            for: SeedData.bench,
            in: SeedData.exercises,
            availableEquipment: ["Bodyweight"]
        ).first)

        let reasons = ExerciseSubstitutionService.matchReasons(
            for: candidate,
            replacing: SeedData.bench,
            availableEquipment: ["Bodyweight"]
        )

        #expect(!reasons.isEmpty)
        #expect(reasons.contains("Mismo grupo muscular"))
        #expect(reasons.contains("Disponible con tu equipo"))
    }

    @Test func plateLoadingCalculatorBuildsPerSideMetricLoad() {
        let plates = PlateLoadingCalculator.platesPerSide(targetWeightKg: 100, barWeightKg: 20)

        #expect(plates == [
            PlateLoadItem(weightKg: 25, count: 1),
            PlateLoadItem(weightKg: 15, count: 1)
        ])
        #expect(PlateLoadingCalculator.loadSummary(targetWeightKg: 100, barWeightKg: 20) == "1x25 + 1x15")
        #expect(PlateLoadingCalculator.platesPerSide(targetWeightKg: 20, barWeightKg: 20).isEmpty)
    }

    @Test func workoutSetBuilderCreatesWarmUpsAndAdvancedSets() {
        let warmUps = WorkoutSetBuilder.warmUpSets(targetWeightKg: 100, targetReps: 8)
        let workSet = SetLog(setNumber: 4, weightKg: 100, reps: 8, completed: false)
        let dropSet = WorkoutSetBuilder.dropSet(after: workSet)
        let backOff = WorkoutSetBuilder.backOffSet(after: workSet)

        #expect(warmUps.count == 3)
        #expect(warmUps.allSatisfy { $0.setType == .warmUp && !$0.completed })
        #expect(warmUps.map(\.weightKg) == [40, 60, 80])
        #expect(dropSet.setType == .dropSet)
        #expect(dropSet.weightKg == 75)
        #expect(backOff.setType == .backOff)
        #expect(backOff.weightKg == 90)
        #expect(WorkoutSetBuilder.renumbered([workSet, dropSet]).map(\.setNumber) == [1, 2])
    }

    @Test func competitiveSummaryComparesPlanTargetsToActualWeek() {
        let now = Date()
        let plan = WorkoutPlan(
            name: "Push Pull",
            location: .gym,
            daysPerWeek: 2,
            currentWeek: 1,
            totalWeeks: 8,
            completion: 0,
            days: [
                WorkoutDay(title: "Push", subtitle: "", durationMinutes: 45, exercises: [
                    WorkoutExercise(exercise: SeedData.bench, targetSets: 4, repRange: "8-10", previous: "60kg x 8")
                ]),
                WorkoutDay(title: "Pull", subtitle: "", durationMinutes: 45, exercises: [
                    WorkoutExercise(exercise: SeedData.row, targetSets: 4, repRange: "8-10", previous: "60kg x 8")
                ])
            ]
        )
        let sessions = [
            WorkoutSession(
                workoutTitle: "Push",
                date: now,
                durationMinutes: 45,
                sets: [],
                exerciseLogs: [
                    ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                        SetLog(setNumber: 1, weightKg: 60, reps: 8, completed: true),
                        SetLog(setNumber: 2, weightKg: 60, reps: 8, completed: true)
                    ])
                ]
            )
        ]

        let summary = AnalyticsEngine.competitiveSummary(
            sessions: sessions,
            activePlan: plan,
            exercises: SeedData.exercises,
            since: Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now,
            now: now
        )

        #expect(summary.completedWorkouts == 1)
        #expect(summary.plannedWorkouts == 2)
        #expect(summary.completionRate == 0.5)
        #expect(summary.targetWeeklySets == 8)
        #expect(summary.actualWeeklySets == 2)
        #expect(summary.undertrainedMuscles.contains { $0.muscleGroup == SeedData.row.muscleGroup })
        #expect(summary.recommendations.contains { $0.title == "Sube la adherencia" })
    }

    @Test func competitiveSummaryDetectsStalledExercises() {
        let now = Date()
        let sessions = (0..<4).map { index in
            WorkoutSession(
                workoutTitle: "Bench \(index)",
                date: Calendar.current.date(byAdding: .day, value: -(21 - index * 7), to: now) ?? now,
                durationMinutes: 45,
                sets: [],
                exerciseLogs: [
                    ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                        SetLog(setNumber: 1, weightKg: index == 0 ? 105 : 100, reps: 5, completed: true)
                    ])
                ]
            )
        }

        let summary = AnalyticsEngine.competitiveSummary(
            sessions: sessions,
            activePlan: .empty,
            exercises: [SeedData.bench],
            since: Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now,
            now: now
        )

        #expect(summary.stalledExercises.first?.exercise.id == SeedData.bench.id)
        #expect(summary.recommendations.contains { $0.title == "Rompe el estancamiento" })
    }

    @Test @MainActor func competitiveActionSchedulesMuscleFocusSession() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))
        store.userProfile.availableEquipment = ["Bodyweight", "Dumbbells"]
        let before = store.scheduledWorkouts.count

        let destination = store.executeCompetitiveAction(.scheduleUndertrainedMuscle("Chest"))

        #expect(destination == .calendar)
        #expect(store.scheduledWorkouts.count == before + 1)
        #expect(store.scheduledWorkouts.last?.workoutDay.title.contains("Chest") == true)
        #expect(store.scheduledWorkouts.last?.workoutDay.exercises.isEmpty == false)
    }

    @Test @MainActor func competitiveActionSchedulesDeloadSession() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))

        let destination = store.executeCompetitiveAction(.scheduleDeloadExercise(SeedData.bench.id))

        #expect(destination == .calendar)
        #expect(store.scheduledWorkouts.last?.workoutDay.title.contains("Descarga") == true)
        #expect(store.scheduledWorkouts.last?.workoutDay.exercises.first?.targetRPE == 6)
    }

    @Test func retentionEngineGuidesNewUsersToActivation() {
        let summary = AnalyticsEngine.competitiveSummary(
            sessions: [],
            activePlan: .empty,
            exercises: SeedData.exercises,
            since: .now,
            now: .now
        )

        let steps = RetentionEngine.nextBestSteps(
            sessions: [],
            activePlan: .empty,
            scheduledWorkouts: [],
            remindersEnabled: false,
            competitiveSummary: summary
        )

        #expect(steps.first?.id == "create-plan")
        #expect(steps.contains { $0.action == .createPlan })
        #expect(steps.contains { $0.action == .scheduleWorkout })
        #expect(steps.contains { $0.action == .startWorkout })
    }

    @Test func retentionEngineSurfacesCompetitiveActionsForActiveUsers() {
        let recommendation = AnalyticsEngine.CompetitiveRecommendation(
            title: "Prioriza Chest",
            message: "Faltan series",
            systemImage: "target",
            action: .scheduleUndertrainedMuscle("Chest")
        )
        let summary = AnalyticsEngine.CompetitiveSummary(
            completedWorkouts: 1,
            plannedWorkouts: 3,
            completionRate: 0.33,
            targetWeeklySets: 12,
            actualWeeklySets: 4,
            muscleTargets: [],
            undertrainedMuscles: [],
            overtrainedMuscles: [],
            stalledExercises: [],
            recommendations: [recommendation]
        )
        let oldSession = WorkoutSession(
            workoutTitle: "Push",
            date: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            durationMinutes: 45,
            sets: [SetLog(setNumber: 1, weightKg: 60, reps: 8, completed: true)]
        )

        let steps = RetentionEngine.nextBestSteps(
            sessions: [oldSession],
            activePlan: SeedData.defaultPlans[0],
            scheduledWorkouts: [],
            remindersEnabled: true,
            competitiveSummary: summary
        )

        #expect(steps.contains { $0.id == recommendation.id })
        #expect(steps.contains { $0.action == .startWorkout })
        #expect(!steps.contains { $0.id == "enable-reminders" })
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
        snapshot.userProfile.themeMode = .light
        snapshot.userProfile.widgetAccentColorName = "green"
        snapshot.activePlan = SeedData.pushPullLegsPlan
        snapshot.activePlan.currentDayIndex = 2
        snapshot.plans = [snapshot.activePlan]
        snapshot.progressPhotos = [
            ProgressPhoto(date: .now, imageData: Data([4, 5, 6]), weightKg: 82.4, note: "Front relaxed")
        ]
        snapshot.savedShareCards = [
            SavedShareCard(date: .now, workoutTitle: "Advanced", imageData: Data([9, 10, 11]))
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
        #expect(loaded?.userProfile.themeMode == .light)
        #expect(loaded?.userProfile.widgetAccentColorName == "green")
        #expect(loaded?.activePlan.currentDayIndex == 2)
        #expect(loaded?.bodyMetrics.first?.waterLiters == 2.3)
        #expect(loaded?.bodyMetrics.first?.dietaryEnergyKcal == 2_450)
        #expect(loaded?.progressPhotos.first?.imageData == Data([4, 5, 6]))
        #expect(loaded?.progressPhotos.first?.weightKg == 82.4)
        #expect(loaded?.savedShareCards.first?.imageData == Data([9, 10, 11]))
        #expect(loaded?.savedShareCards.first?.workoutTitle == "Advanced")
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
        let store = AppStore(
            persistence: SwiftDataPersistence(inMemory: true),
            shareImageRenderer: { _ in
                UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
                    UIColor.black.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
                }
            }
        )
        let url = try store.exportWorkoutShareImageURL()
        let data = try Data(contentsOf: url)

        #expect(url.pathExtension == "png")
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func productAccessSeparatesFreeAndProFeatures() {
        #expect(ProductAccess.isEnabled(.unlimitedLogging))
        #expect(!ProductAccess.isEnabled(.advancedAnalytics))
        #expect(ProductAccess.isEnabled(.advancedAnalytics, proEnabled: true))
        #expect(ProductAccess.freeFeatures.contains(.customRoutines))
        #expect(ProductAccess.freeFeatures.contains(.basicAnalytics))
        #expect(ProductAccess.proFeatures.contains(.configurableProgression))
        #expect(ProductAccess.proFeatures.contains(.automaticBackups))
        #expect(ProductFeature.advancedAnalytics.tier == .pro)
        #expect(ProductFeature.exerciseLibrary.tier == .free)
    }

    @Test func paywallSourcesProvideContextualPreviewCopy() {
        #expect(PaywallSource.progressLoad.previewTitle.contains("Decisiones"))
        #expect(PaywallSource.workoutAdvancedFields.previewBullets.contains { $0.contains("entreno activo") })
        #expect(ProductFeature.configurableProgression.conversionBenefit.contains("RPE"))
    }

    @Test @MainActor func monetizationStatePersistsThroughSwiftData() {
        let persistence = SwiftDataPersistence(inMemory: true)
        var snapshot = AppSnapshot.seed
        snapshot.monetization.entitlement = .pro
        snapshot.monetization.status = .active
        snapshot.monetization.billingCycle = .annual
        snapshot.monetization.lastPaywallSource = .profileSubscription
        snapshot.monetization.paywallPresentationCount = 3

        persistence.save(snapshot)

        let loaded = persistence.loadSnapshot()
        #expect(loaded?.monetization.entitlement == .pro)
        #expect(loaded?.monetization.status == .active)
        #expect(loaded?.monetization.billingCycle == .annual)
        #expect(loaded?.monetization.lastPaywallSource == .profileSubscription)
        #expect(loaded?.monetization.paywallPresentationCount == 3)
    }

    @Test @MainActor func requireFeaturePresentsPaywallWhenProFeatureIsLocked() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))

        let unlocked = store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics)

        #expect(!unlocked)
        #expect(store.activePaywall?.source == .progressAdvancedAnalytics)
        #expect(store.activePaywall?.feature == .advancedAnalytics)
    }
}

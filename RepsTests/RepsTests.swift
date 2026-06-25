import Testing
import Foundation
import UIKit
import MuscleMap
@testable import Reps

@Suite(.serialized)
struct RepsTests {
    @Test func weeklyCompletionCapsAtOne() async throws {
        let store = await AppStore(persistence: SwiftDataPersistence(inMemory: true))
        let completion = await store.weeklyCompletion
        #expect(completion <= 1)
    }

    @Test @MainActor func suggestedPlanUsesNormalizedResistanceBandEquipment() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))
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

    @Test func exerciseAnatomyDoesNotTreatBarbellAsAbs() {
        let exercise = Exercise(
            name: "Barbell Bench Press",
            muscleGroup: "Chest",
            secondaryMuscles: ["Shoulders", "Arms"],
            equipment: "Barbell",
            instructions: "Brace your core and keep your shoulder blades tight."
        )

        let descriptor = ExerciseAnatomyDescriptor(exercise: exercise)

        #expect(descriptor.muscles.contains(.chest))
        #expect(descriptor.muscles.contains(.deltoids))
        #expect(descriptor.muscles.contains(.triceps))
        #expect(descriptor.primaryMuscles == [.chest])
        #expect(!descriptor.secondaryMuscles.contains(.biceps))
        #expect(!descriptor.muscles.contains(.abs))
        #expect(!descriptor.muscles.contains(.upperAbs))
        #expect(!descriptor.muscles.contains(.lowerAbs))
    }

    @Test func muscleGroupAnatomySupportsLocalizedGroups() {
        let chest = ExerciseAnatomyDescriptor(muscleGroup: "Pecho", secondaryMuscles: [])
        let arms = ExerciseAnatomyDescriptor(muscleGroup: "Brazos", secondaryMuscles: [])
        let pressingArms = ExerciseAnatomyDescriptor(muscleGroup: "Brazos", exerciseName: "Barbell Bench Press", secondaryMuscles: [])

        #expect(chest.muscles.contains(.chest))
        #expect(!chest.muscles.contains(.abs))
        #expect(arms.muscles.contains(.biceps))
        #expect(arms.muscles.contains(.triceps))
        #expect(!arms.muscles.contains(.abs))
        #expect(pressingArms.muscles == [.triceps])
    }

    @Test func gluteExercisesKeepGlutesAsPrimaryAnatomy() {
        let exercise = Exercise(
            name: "Glute Bridge",
            muscleGroup: "Glutes",
            secondaryMuscles: ["Legs", "Core"],
            equipment: "Bodyweight"
        )

        let descriptor = ExerciseAnatomyDescriptor(exercise: exercise)

        #expect(descriptor.primaryMuscles == [.gluteal])
        #expect(descriptor.secondaryMuscles.contains(.hamstring))
        #expect(descriptor.secondaryMuscles.contains(.quadriceps))
        #expect(!descriptor.primaryMuscles.contains(.quadriceps))
        #expect(descriptor.region.side == .back)
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

    @Test func dailyCoachRecommendationStartsWithPlanCreationWhenNoPlanExists() {
        let battery = FitnessMetrics.trainingBatteryStatus(
            sessions: [],
            scheduledWorkouts: [],
            activePlan: .empty,
            bodyMetrics: [],
            health: HealthSyncState()
        )
        let summary = AnalyticsEngine.competitiveSummary(
            sessions: [],
            activePlan: .empty,
            exercises: SeedData.exercises,
            since: .now
        )

        let recommendation = FitnessMetrics.dailyCoachRecommendation(
            battery: battery,
            competitiveSummary: summary,
            hasActivePlan: false,
            hasTodayWorkout: false,
            hasCompletedWorkout: false
        )

        #expect(recommendation.action == .createPlan)
        #expect(recommendation.tone == .primary)
    }

    @Test func dailyCoachRecommendationProtectsRecoveryWhenBatteryIsCritical() {
        let hardSessions = (0..<4).map { offset in
            WorkoutSession(
                workoutTitle: "Hard \(offset)",
                date: Calendar.current.date(byAdding: .hour, value: -offset * 8, to: .now) ?? .now,
                durationMinutes: 95,
                sets: [
                    SetLog(setNumber: 1, weightKg: 140, reps: 6, completed: true, rpe: 10),
                    SetLog(setNumber: 2, weightKg: 130, reps: 8, completed: true, rpe: 9.5),
                    SetLog(setNumber: 3, weightKg: 120, reps: 10, completed: true, rpe: 9.5),
                    SetLog(setNumber: 4, weightKg: 110, reps: 12, completed: true, rpe: 9)
                ],
                sessionRPE: 10,
                energyBefore: 5,
                energyAfter: 1
            )
        }
        let battery = FitnessMetrics.trainingBatteryStatus(
            sessions: hardSessions,
            scheduledWorkouts: [],
            activePlan: SeedData.pushPullLegsPlan,
            bodyMetrics: [BodyMetric(date: .now, weightKg: 80, heightCm: 178, sleepHours: 4.5, fatigue: 5, stress: 5, source: .manual)],
            health: HealthSyncState()
        )
        let summary = AnalyticsEngine.competitiveSummary(
            sessions: hardSessions,
            activePlan: SeedData.pushPullLegsPlan,
            exercises: SeedData.exercises,
            since: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        )

        let recommendation = FitnessMetrics.dailyCoachRecommendation(
            battery: battery,
            competitiveSummary: summary,
            hasActivePlan: true,
            hasTodayWorkout: true,
            hasCompletedWorkout: true
        )

        #expect(battery.state == .critical)
        #expect(recommendation.action == .competitive(.scheduleRecovery))
        #expect(recommendation.tone == .warning)
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

    @Test func workoutDraftControllerMutatesSelectedExerciseSets() {
        let exercise = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 1,
            repRange: "8-10",
            previous: "60 x 8"
        )
        var drafts = [
            ExerciseSessionDraft(
                workoutExercise: exercise,
                notes: "",
                sets: [SetLog(setNumber: 1, weightKg: 60, reps: 8, completed: false)]
            )
        ]

        #expect(WorkoutDraftController.addSet(to: &drafts, selectedIndex: 0))
        #expect(drafts[0].sets.count == 2)
        #expect(drafts[0].sets[1].weightKg == 60)
        #expect(drafts[0].sets[1].reps == 8)

        #expect(WorkoutDraftController.insertWarmUpSets(to: &drafts, selectedIndex: 0, targetSet: drafts[0].sets.last))
        #expect(drafts[0].sets.prefix(3).allSatisfy { $0.setType == .warmUp })
        #expect(drafts[0].sets.map(\.setNumber) == Array(1...5))

        #expect(WorkoutDraftController.appendDropSet(to: &drafts, selectedIndex: 0))
        #expect(drafts[0].sets.last?.setType == .dropSet)

        #expect(WorkoutDraftController.appendBackOffSet(to: &drafts, selectedIndex: 0))
        #expect(drafts[0].sets.last?.setType == .backOff)
        #expect(drafts[0].sets.map(\.setNumber) == Array(1...7))
    }

    @Test func workoutDraftControllerMutatesExerciseDrafts() {
        var drafts: [ExerciseSessionDraft] = []

        let benchIndex = WorkoutDraftController.addExercise(SeedData.bench, to: &drafts)

        #expect(benchIndex == 0)
        #expect(drafts.count == 1)
        #expect(drafts[0].workoutExercise.exercise.name == SeedData.bench.name)
        #expect(drafts[0].workoutExercise.repRange == "8-12")
        #expect(drafts[0].sets.count == 3)
        #expect(drafts[0].sets.allSatisfy { !$0.completed })

        drafts[0].sets = [
            SetLog(
                setNumber: 1,
                weightKg: 80,
                reps: 6,
                completed: true,
                setType: .work,
                rpe: 8,
                rir: 2,
                tempo: "3-1-1",
                previousRestSeconds: 90,
                isPersonalRecord: true,
                notes: "Mantener técnica"
            ),
            SetLog(setNumber: 2, weightKg: 75, reps: 8, completed: false, setType: .backOff)
        ]

        #expect(WorkoutDraftController.replaceExercise(at: 0, with: SeedData.squat, in: &drafts))
        #expect(drafts[0].workoutExercise.exercise.name == SeedData.squat.name)
        #expect(drafts[0].sets.map(\.setNumber) == [1, 2])
        #expect(drafts[0].sets[0].weightKg == 80)
        #expect(drafts[0].sets[0].reps == 6)
        #expect(drafts[0].sets[0].completed)
        #expect(drafts[0].sets[0].setType == .work)
        #expect(drafts[0].sets[0].rpe == 8)
        #expect(drafts[0].sets[0].rir == 2)
        #expect(drafts[0].sets[0].tempo == "3-1-1")
        #expect(drafts[0].sets[0].previousRestSeconds == 90)
        #expect(drafts[0].sets[0].isPersonalRecord == false)
        #expect(drafts[0].sets[0].notes == "Mantener técnica")

        _ = WorkoutDraftController.addExercise(SeedData.row, to: &drafts)
        let selectedID = drafts[0].workoutExercise.id
        let movedSelection = WorkoutDraftController.moveExercise(
            from: 1,
            to: 0,
            in: &drafts,
            selectedWorkoutExerciseID: selectedID
        )

        #expect(drafts.map { $0.workoutExercise.exercise.name } == [SeedData.row.name, SeedData.squat.name])
        #expect(movedSelection == 1)

        let selectedAfterRemoval = WorkoutDraftController.removeExercise(at: 1, from: &drafts)
        #expect(selectedAfterRemoval == 0)
        #expect(drafts.map { $0.workoutExercise.exercise.name } == [SeedData.row.name])

        let emptySelection = WorkoutDraftController.removeExercise(at: 0, from: &drafts)
        #expect(emptySelection == 0)
        #expect(drafts.isEmpty)
        #expect(WorkoutDraftController.removeExercise(at: 0, from: &drafts) == nil)
    }

    @Test func supersetRotationAlternatesAndClassifiesRest() {
        func draft(_ ex: Exercise) -> ExerciseSessionDraft {
            ExerciseSessionDraft(
                workoutExercise: WorkoutExercise(exercise: ex, targetSets: 2, repRange: "8-10", previous: "-", restSeconds: 77),
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 50, reps: 8, completed: false),
                    SetLog(setNumber: 2, weightKg: 50, reps: 8, completed: false)
                ]
            )
        }
        var drafts = [draft(SeedData.bench), draft(SeedData.row)]

        // Linking sets a shared group on both exercises.
        WorkoutDraftController.toggleSupersetLink(at: 0, in: &drafts)
        let group = drafts[0].workoutExercise.supersetGroup
        #expect(group != nil)
        #expect(drafts[1].workoutExercise.supersetGroup == group)

        func complete(_ idx: Int) -> WorkoutDraftController.CompletionOutcome? {
            let setIndex = drafts[idx].sets.firstIndex(where: { !$0.completed }) ?? 0
            return WorkoutDraftController.completeSet(
                in: &drafts, exerciseIndex: idx, setIndex: setIndex,
                elapsedSeconds: 0, lastSetCompletedAtSeconds: nil,
                isPersonalRecord: false, betweenExercisesRestSeconds: 120
            )
        }

        // Round 1: A1 → short transition rest, rotation lands on B.
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts)?.exerciseIndex == 0)
        #expect(complete(0)?.restDurationSeconds == WorkoutDraftController.supersetTransitionRestSeconds)
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts)?.exerciseIndex == 1)

        // B1 closes the round → full exercise rest, rotation returns to A.
        #expect(complete(1)?.restDurationSeconds == 77)
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts)?.exerciseIndex == 0)

        // Round 2: A2 → short, then B2 finishes the superset.
        #expect(complete(0)?.restDurationSeconds == WorkoutDraftController.supersetTransitionRestSeconds)
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts)?.exerciseIndex == 1)
        #expect(complete(1)?.didFinishWorkout == true)
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts) == nil)

        // Unlinking dissolves the (now two-member) group entirely.
        WorkoutDraftController.toggleSupersetLink(at: 0, in: &drafts)
        #expect(drafts.allSatisfy { $0.workoutExercise.supersetGroup == nil })
    }

    @Test func linearFlowRestUnchangedWithoutSuperset() {
        var drafts = [
            ExerciseSessionDraft(
                workoutExercise: WorkoutExercise(exercise: SeedData.bench, targetSets: 2, repRange: "8-10", previous: "-", restSeconds: 88),
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 50, reps: 8, completed: false),
                    SetLog(setNumber: 2, weightKg: 50, reps: 8, completed: false)
                ]
            ),
            ExerciseSessionDraft(
                workoutExercise: WorkoutExercise(exercise: SeedData.row, targetSets: 1, repRange: "8-10", previous: "-", restSeconds: 88),
                notes: "",
                sets: [SetLog(setNumber: 1, weightKg: 40, reps: 8, completed: false)]
            )
        ]

        // Same exercise still has a set → rest in place, no move.
        let first = WorkoutDraftController.completeSet(
            in: &drafts, exerciseIndex: 0, setIndex: 0,
            elapsedSeconds: 0, lastSetCompletedAtSeconds: nil,
            isPersonalRecord: false, betweenExercisesRestSeconds: 120
        )
        #expect(first?.restDurationSeconds == 88)
        #expect(first?.shouldMoveToNextExercise == false)

        // Exercise finished → move to next with between-exercises rest.
        let second = WorkoutDraftController.completeSet(
            in: &drafts, exerciseIndex: 0, setIndex: 1,
            elapsedSeconds: 0, lastSetCompletedAtSeconds: nil,
            isPersonalRecord: false, betweenExercisesRestSeconds: 120
        )
        #expect(second?.restDurationSeconds == 120)
        #expect(second?.shouldMoveToNextExercise == true)
    }

    @Test func exerciseHistoryAnalyzerMatchesNormalizedNamesAndDetectsRecords() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let alternateBench = Exercise(name: "  barbell-bench_press  ", muscleGroup: "Chest", equipment: "Barbell")
        let sessions = [
            WorkoutSession(
                workoutTitle: "Older Push",
                date: older,
                durationMinutes: 40,
                sets: [],
                exerciseLogs: [
                    ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                        SetLog(setNumber: 1, weightKg: 75, reps: 8, completed: true),
                        SetLog(setNumber: 2, weightKg: 75, reps: 8, completed: false)
                    ])
                ]
            ),
            WorkoutSession(
                workoutTitle: "Newer Push",
                date: newer,
                durationMinutes: 42,
                sets: [],
                exerciseLogs: [
                    ExerciseLog(exercise: alternateBench, notes: "", sets: [
                        SetLog(setNumber: 1, weightKg: 80, reps: 5, completed: true)
                    ])
                ]
            )
        ]

        let recent = ExerciseHistoryAnalyzer.recentCompletedSets(for: SeedData.bench, in: sessions)

        #expect(recent.map(\.weightKg) == [80, 75])
        #expect(ExerciseHistoryAnalyzer.normalizedExerciseName("  Barbell-Bench_press ") == "barbell bench press")
        #expect(ExerciseHistoryAnalyzer.isPersonalRecord(
            SetLog(setNumber: 1, weightKg: 82.5, reps: 5, completed: true),
            for: SeedData.bench,
            in: sessions
        ))
        #expect(!ExerciseHistoryAnalyzer.isPersonalRecord(
            SetLog(setNumber: 1, weightKg: 70, reps: 5, completed: true),
            for: SeedData.bench,
            in: sessions
        ))
    }

    @Test func workoutDraftControllerAppliesAutoProgressionToIncompleteSets() {
        var item = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 2,
            repRange: "8-10",
            previous: "60 x 10"
        )
        item.progressionType = .linear
        item.incrementKg = 2.5
        var drafts = [
            ExerciseSessionDraft(
                workoutExercise: item,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true),
                    SetLog(setNumber: 2, weightKg: 0, reps: 0, completed: false),
                    SetLog(setNumber: 3, weightKg: 0, reps: 0, completed: false)
                ]
            )
        ]
        let sessions = [
            WorkoutSession(
                workoutTitle: "Push",
                date: .now,
                durationMinutes: 40,
                sets: [],
                exerciseLogs: [
                    ExerciseLog(exercise: SeedData.bench, notes: "", sets: [
                        SetLog(setNumber: 1, weightKg: 60, reps: 10, completed: true, rpe: 7),
                        SetLog(setNumber: 2, weightKg: 60, reps: 10, completed: true, rpe: 7)
                    ])
                ]
            )
        ]

        #expect(WorkoutDraftController.applyAutoProgression(to: &drafts, sessions: sessions, weightIncrementKg: 2.5))
        #expect(drafts[0].sets[0].weightKg == 60)
        #expect(drafts[0].sets[0].reps == 10)
        #expect(drafts[0].sets[1].weightKg == 62.5)
        #expect(drafts[0].sets[1].reps == 8)
        #expect(drafts[0].sets[2].weightKg == 62.5)
        #expect(drafts[0].sets[2].reps == 8)

        var emptyHistoryDrafts = drafts
        #expect(!WorkoutDraftController.applyAutoProgression(to: &emptyHistoryDrafts, sessions: [], weightIncrementKg: 2.5))
    }

    @Test func workoutDraftControllerFindsNextIncompleteSetAcrossExercises() {
        let first = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 2,
            repRange: "8-10",
            previous: ""
        )
        let second = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 2,
            repRange: "6-8",
            previous: ""
        )
        var drafts = [
            ExerciseSessionDraft(
                workoutExercise: first,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 70, reps: 8, completed: true),
                    SetLog(setNumber: 2, weightKg: 70, reps: 8, completed: true)
                ]
            ),
            ExerciseSessionDraft(
                workoutExercise: second,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 90, reps: 6, completed: false),
                    SetLog(setNumber: 2, weightKg: 90, reps: 6, completed: false)
                ]
            )
        ]

        let pending = WorkoutDraftController.nextIncompleteSet(in: drafts)

        #expect(pending?.exerciseIndex == 1)
        #expect(pending?.setIndex == 0)
        #expect(pending?.exerciseName == SeedData.squat.name)
        #expect(pending?.setNumber == 1)

        drafts[1].sets[0].completed = true
        drafts[1].sets[1].completed = true
        #expect(WorkoutDraftController.nextIncompleteSet(in: drafts) == nil)
    }

    @Test func workoutDraftControllerCompletesSetsAndChoosesRest() {
        var first = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 2,
            repRange: "8-10",
            previous: ""
        )
        first.restSeconds = 75
        let second = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 1,
            repRange: "6-8",
            previous: ""
        )
        var drafts = [
            ExerciseSessionDraft(
                workoutExercise: first,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 72.5, reps: 8, completed: false),
                    SetLog(setNumber: 2, weightKg: 0, reps: 0, completed: false)
                ]
            ),
            ExerciseSessionDraft(
                workoutExercise: second,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 90, reps: 6, completed: false)
                ]
            )
        ]

        let firstOutcome = WorkoutDraftController.completeSet(
            in: &drafts,
            exerciseIndex: 0,
            setIndex: 0,
            elapsedSeconds: 180,
            lastSetCompletedAtSeconds: 100,
            isPersonalRecord: true,
            betweenExercisesRestSeconds: 150
        )

        #expect(drafts[0].sets[0].completed)
        #expect(drafts[0].sets[0].previousRestSeconds == 80)
        #expect(drafts[0].sets[0].isPersonalRecord)
        #expect(drafts[0].sets[1].weightKg == 72.5)
        #expect(drafts[0].sets[1].reps == 8)
        #expect(firstOutcome?.restDurationSeconds == 75)
        #expect(firstOutcome?.shouldMoveToNextExercise == false)
        #expect(firstOutcome?.didFinishWorkout == false)

        let secondOutcome = WorkoutDraftController.completeSet(
            in: &drafts,
            exerciseIndex: 0,
            setIndex: 1,
            elapsedSeconds: 260,
            lastSetCompletedAtSeconds: 180,
            isPersonalRecord: false,
            betweenExercisesRestSeconds: 150
        )

        #expect(secondOutcome?.restDurationSeconds == 150)
        #expect(secondOutcome?.shouldMoveToNextExercise == true)
        #expect(secondOutcome?.didFinishWorkout == false)

        let finalOutcome = WorkoutDraftController.completeSet(
            in: &drafts,
            exerciseIndex: 1,
            setIndex: 0,
            elapsedSeconds: 420,
            lastSetCompletedAtSeconds: 260,
            isPersonalRecord: false,
            betweenExercisesRestSeconds: 150
        )

        #expect(finalOutcome?.restDurationSeconds == nil)
        #expect(finalOutcome?.didFinishWorkout == true)
    }

    @Test func workoutRestControllerAdjustsRestDeterministically() {
        let now = Date(timeIntervalSince1970: 1_000)
        let started = Date(timeIntervalSince1970: 900)

        let fresh = WorkoutRestController.adjustedRest(
            current: WorkoutRestController.RestState(restSeconds: 0, restDuration: 0, restStartedAt: nil),
            remainingSeconds: 0,
            deltaSeconds: 30,
            now: now
        )
        #expect(fresh.restSeconds == 30)
        #expect(fresh.restDuration == 30)
        #expect(fresh.restStartedAt == now)

        let extended = WorkoutRestController.adjustedRest(
            current: WorkoutRestController.RestState(restSeconds: 45, restDuration: 75, restStartedAt: started),
            remainingSeconds: 45,
            deltaSeconds: 30,
            now: now
        )
        #expect(extended.restSeconds == 75)
        #expect(extended.restDuration == 75)
        #expect(extended.restStartedAt == started.addingTimeInterval(30))

        let reduced = WorkoutRestController.adjustedRest(
            current: WorkoutRestController.RestState(restSeconds: 10, restDuration: 75, restStartedAt: started),
            remainingSeconds: 10,
            deltaSeconds: -30,
            now: now
        )
        #expect(reduced.restSeconds == 0)
        #expect(reduced.restDuration == 75)
        #expect(reduced.restStartedAt == started.addingTimeInterval(-30))
    }

    @Test func selectedExerciseContextBuilderBuildsToolsHistoryAndSuggestion() {
        var exercise = SeedData.bench
        exercise.requiredEquipment = ["Barbell", "Bench"]
        let workoutExercise = WorkoutExercise(
            exercise: exercise,
            targetSets: 2,
            repRange: "8-10",
            previous: "80 x 8",
            progressionType: .doubleProgression
        )
        let draft = ExerciseSessionDraft(
            workoutExercise: workoutExercise,
            notes: "",
            sets: [
                SetLog(setNumber: 1, weightKg: 80, reps: 8, completed: true),
                SetLog(setNumber: 2, weightKg: 80, reps: 8, completed: false)
            ]
        )
        let recentSets = [
            SetLog(setNumber: 1, weightKg: 82.5, reps: 8, completed: true),
            SetLog(setNumber: 2, weightKg: 80, reps: 10, completed: true),
            SetLog(setNumber: 3, weightKg: 75, reps: 12, completed: true)
        ]

        let context = SelectedExerciseContextBuilder.context(
            from: SelectedExerciseContextBuilder.Input(
                draft: draft,
                recentSets: recentSets,
                hasConfigurableProgressionAccess: true,
                autoProgressionEnabled: true,
                weightIncrementKg: 2.5
            )
        )

        #expect(context.currentWorkingSet?.setNumber == 2)
        #expect(context.targetWeightKg == 80)
        #expect(context.plateLoadSummary == "1x25 + 1x5")
        #expect(context.historySummary == "Histórico: 75 kg x 12")
        #expect(context.suggestionText != nil)
        #expect(context.canInsertWarmUpSets)
        #expect(context.canAppendAdvancedSet)
        #expect(context.toolsCaption == "Carga recomendada por lado con barra de 20 kg. Los botones insertan series especiales sin cerrar el entrenamiento.")
    }

    @Test func selectedExerciseContextBuilderHandlesEmptyOrBodyweightDrafts() {
        let bodyweight = WorkoutExercise(
            exercise: SeedData.pushup,
            targetSets: 3,
            repRange: "10-15",
            previous: ""
        )
        let draft = ExerciseSessionDraft(
            workoutExercise: bodyweight,
            notes: "",
            sets: [
                SetLog(setNumber: 1, weightKg: 0, reps: 12, completed: false)
            ]
        )

        let context = SelectedExerciseContextBuilder.context(
            from: SelectedExerciseContextBuilder.Input(
                draft: draft,
                recentSets: [],
                hasConfigurableProgressionAccess: false,
                autoProgressionEnabled: false,
                weightIncrementKg: 2.5
            )
        )

        #expect(context.targetWeightKg == nil)
        #expect(context.plateLoadSummary == nil)
        #expect(context.historySummary == nil)
        #expect(context.suggestionText == nil)
        #expect(context.canInsertWarmUpSets == false)
        #expect(context.canAppendAdvancedSet == false)
        #expect(context.toolsCaption == "Añade peso a la serie objetivo para activar herramientas de calentamiento y carga.")
    }

    @Test func workoutSessionBuilderCreatesLogsNotesAndLocation() {
        let imageAttachment = WorkoutMediaAttachment(kind: .image, data: Data([1, 2, 3]))
        let bench = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 2,
            repRange: "8-10",
            previous: ""
        )
        let squat = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 1,
            repRange: "6-8",
            previous: ""
        )
        let drafts = [
            ExerciseSessionDraft(
                workoutExercise: bench,
                notes: "Buena velocidad",
                voiceNote: "Mantener agarre",
                sets: [
                    SetLog(setNumber: 1, weightKg: 70, reps: 8, completed: true),
                    SetLog(setNumber: 2, weightKg: 70, reps: 8, completed: false)
                ],
                mediaAttachments: [imageAttachment]
            ),
            ExerciseSessionDraft(
                workoutExercise: squat,
                notes: "Sin completar",
                sets: [
                    SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: false)
                ]
            )
        ]

        let logs = WorkoutSessionBuilder.exerciseLogs(from: drafts)

        #expect(logs.count == 1)
        #expect(logs[0].exercise.id == SeedData.bench.id)
        #expect(logs[0].sets.count == 1)
        #expect(logs[0].mediaAttachments.count == 2)
        #expect(logs[0].mediaAttachments.contains { $0.kind == .audio && $0.note == "Mantener agarre" })

        let notes = WorkoutSessionBuilder.sessionNotes(
            globalNotes: "Sesión sólida",
            sessionMediaAttachments: [imageAttachment],
            logs: logs
        )

        #expect(notes?.contains("Sesión sólida") == true)
        #expect(notes?.contains("Barbell Bench Press: Buena velocidad") == true)
        #expect(notes?.contains("1 fotos adjuntas de sesión") == true)
        #expect(notes?.contains("Barbell Bench Press: 2 adjuntos") == true)

        #expect(WorkoutSessionBuilder.voiceAttachments(from: "   ").isEmpty)
        #expect(WorkoutSessionBuilder.location(
            isRouteCandidate: true,
            isTreadmillCandidate: false,
            origin: .routine,
            userTrainingLocation: .gym,
            activePlanLocation: .gym
        ) == .outdoor)
        #expect(WorkoutSessionBuilder.location(
            isRouteCandidate: false,
            isTreadmillCandidate: true,
            origin: .routine,
            userTrainingLocation: .home,
            activePlanLocation: .home
        ) == .gym)
        #expect(WorkoutSessionBuilder.location(
            isRouteCandidate: false,
            isTreadmillCandidate: false,
            origin: .free,
            userTrainingLocation: .home,
            activePlanLocation: .gym
        ) == .home)
    }

    @Test func workoutSessionBuilderBuildsCompleteWorkoutSessionFromInput() {
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let finishedAt = startedAt.addingTimeInterval(2_460)
        let routePoint = RoutePoint(latitude: 40.0, longitude: -3.0, timestamp: startedAt)
        let sessionImage = WorkoutMediaAttachment(kind: .image, data: Data([9, 8, 7]))
        let exercise = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 1,
            repRange: "8-10",
            previous: ""
        )
        let drafts = [
            ExerciseSessionDraft(
                workoutExercise: exercise,
                notes: "Controlado",
                voiceNote: "Subir 2.5 kg",
                sets: [
                    SetLog(setNumber: 1, weightKg: 80, reps: 8, completed: true)
                ]
            )
        ]
        let sensor = WorkoutSensorSummary(
            steps: 1_200,
            activeEnergyKcal: 180,
            averageHeartRate: 118,
            maxHeartRate: 145,
            heartRateBefore: 70,
            heartRateAfter: 92
        )

        let session = WorkoutSessionBuilder.session(
            from: WorkoutSessionBuilder.Input(
                workoutTitle: "Push",
                finishedAt: finishedAt,
                startedAt: startedAt,
                origin: .free,
                isRouteCandidate: false,
                isTreadmillCandidate: false,
                userTrainingLocation: .home,
                activePlanLocation: .gym,
                elapsedSeconds: 2_460,
                drafts: drafts,
                globalNotes: "Buena sesión",
                sessionVoiceNote: "Cierre general",
                sessionMediaAttachments: [sessionImage],
                sessionRPE: 8.5,
                energyBefore: 3.9,
                energyAfter: 4.1,
                sensorSummary: sensor,
                routePoints: [routePoint],
                pausedSeconds: 90,
                displayedRouteDistanceKm: 0,
                displayedRoutePaceSecondsPerKm: nil
            )
        )

        #expect(session.workoutTitle == "Push")
        #expect(session.startedAt == startedAt)
        #expect(session.endedAt == finishedAt)
        #expect(session.location == .home)
        #expect(session.durationMinutes == 41)
        #expect(session.sets.count == 1)
        #expect(session.exerciseLogs?.count == 1)
        #expect(session.notes?.contains("Buena sesión") == true)
        #expect(session.notes?.contains("Barbell Bench Press: Controlado") == true)
        #expect(session.mediaAttachments.count == 2)
        #expect(session.routePoints.isEmpty)
        #expect(session.pausedDurationSeconds == 90)
        #expect(session.distanceKm == nil)
        #expect(session.energyBefore == 3)
        #expect(session.energyAfter == 4)
        #expect(session.activeEnergyKcal == 180)
        #expect(session.averageHeartRate == 118)
    }

    @Test func workoutSessionBuilderCreatesCardioLogsOnlyForCardioSessions() {
        let start = Date(timeIntervalSince1970: 1_000)
        let routePoint = RoutePoint(latitude: 40.0, longitude: -3.0, timestamp: start)
        let session = WorkoutSession(
            workoutTitle: "Carrera",
            date: start.addingTimeInterval(1_800),
            startedAt: start,
            endedAt: start.addingTimeInterval(1_800),
            origin: .routine,
            location: .outdoor,
            durationMinutes: 30,
            sets: [],
            notes: "Ritmo controlado",
            sessionRPE: 7,
            routePoints: [routePoint],
            distanceKm: 5,
            averagePaceSecondsPerKm: 360
        )
        let sensor = WorkoutSensorSummary(
            steps: 5_000,
            activeEnergyKcal: 320,
            averageHeartRate: 142,
            maxHeartRate: 170,
            heartRateBefore: 72,
            heartRateAfter: 96
        )

        #expect(WorkoutSessionBuilder.cardioLog(
            from: session,
            sensorSummary: sensor,
            isCardioMovementCandidate: false,
            sessionType: .strength,
            isTreadmillCandidate: false,
            isRouteCandidate: false,
            averageSpeedKmh: nil
        ) == nil)

        let outdoorLog = WorkoutSessionBuilder.cardioLog(
            from: session,
            sensorSummary: sensor,
            isCardioMovementCandidate: true,
            sessionType: .cardioRun,
            isTreadmillCandidate: false,
            isRouteCandidate: true,
            averageSpeedKmh: 10
        )

        #expect(outdoorLog?.activityType == .outdoorRun)
        #expect(outdoorLog?.routePoints.count == 1)
        #expect(outdoorLog?.averageHeartRate == 142)
        #expect(outdoorLog?.averageSpeedKmh == 10)

        let treadmillLog = WorkoutSessionBuilder.cardioLog(
            from: session,
            sensorSummary: nil,
            isCardioMovementCandidate: true,
            sessionType: .cardioRun,
            isTreadmillCandidate: true,
            isRouteCandidate: false,
            averageSpeedKmh: 9
        )

        #expect(treadmillLog?.activityType == .treadmill)
        #expect(treadmillLog?.routePoints.isEmpty == true)
    }

    @Test func activeWorkoutStatusBuilderCreatesStatusUpdateFromDrafts() {
        let bench = WorkoutExercise(
            exercise: SeedData.bench,
            targetSets: 2,
            repRange: "8-10",
            previous: ""
        )
        let squat = WorkoutExercise(
            exercise: SeedData.squat,
            targetSets: 1,
            repRange: "6-8",
            previous: ""
        )
        let drafts = [
            ExerciseSessionDraft(
                workoutExercise: bench,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 80, reps: 8, completed: true),
                    SetLog(setNumber: 2, weightKg: 80, reps: 8, completed: false)
                ]
            ),
            ExerciseSessionDraft(
                workoutExercise: squat,
                notes: "",
                sets: [
                    SetLog(setNumber: 1, weightKg: 100, reps: 5, completed: true)
                ]
            )
        ]

        let update = ActiveWorkoutStatusBuilder.update(
            from: ActiveWorkoutStatusBuilder.Input(
                elapsedSeconds: 420,
                pausedSeconds: 30,
                isPaused: false,
                selectedExerciseName: "Press banca",
                selectedExerciseIndex: 0,
                drafts: drafts,
                currentSet: drafts[0].sets[1],
                restSeconds: 45,
                restDurationSeconds: 90,
                estimatedRemainingSeconds: 600,
                waterLiters: 0.5,
                musicTitle: "Playlist",
                musicArtist: "Apple Music",
                isMusicPlaying: true,
                nextExerciseName: "Sentadilla",
                exerciseHistorySummary: "80 x 8",
                gymPass: nil,
                lastPausedAt: nil,
                isRouteWorkout: true,
                isOutdoorRoute: false,
                routeDistanceKm: nil,
                routePaceSecondsPerKm: nil,
                routeSpeedKmh: nil,
                routePointCount: nil,
                previousRouteDistanceKm: 2.4,
                previousRoutePaceSecondsPerKm: 360,
                previousRouteSpeedKmh: 10,
                previousRoutePointCount: 24,
                routeSteps: 3_000,
                liveHeartRate: 128,
                liveActiveEnergyKcal: 64
            )
        )

        #expect(update.elapsedSeconds == 420)
        #expect(update.completedSets == 2)
        #expect(update.totalSets == 3)
        #expect(update.volumeKg == 1_140)
        #expect(update.exerciseName == "Press banca")
        #expect(update.exerciseIndex == 1)
        #expect(update.totalExercises == 2)
        #expect(update.currentExerciseCompletedSets == 1)
        #expect(update.currentExerciseTotalSets == 2)
        #expect(update.currentSetWeightKg == 80)
        #expect(update.currentSetReps == 8)
        #expect(update.routeDistanceKm == 2.4)
        #expect(update.routePaceSecondsPerKm == 360)
        #expect(update.routeSpeedKmh == 10)
        #expect(update.routePointCount == 24)
        #expect(update.routeSteps == 3_000)
        #expect(update.liveHeartRate == 128)
        #expect(update.liveActiveEnergyKcal == 64)
    }

    @Test func routeMetricsBuilderPrioritizesLiveStatusAndFormatsValues() {
        let status = ActiveWorkoutStatus(
            planTitle: "Plan",
            workoutTitle: "Carrera",
            elapsedSeconds: 600,
            pausedSeconds: 0,
            completedSets: 0,
            totalSets: 0,
            volumeKg: 0,
            isPaused: false,
            isRouteWorkout: true,
            isOutdoorRoute: true,
            routeDistanceKm: 3.2,
            routePaceSecondsPerKm: 312,
            routeSpeedKmh: 11.5,
            routePointCount: 80,
            routeSteps: 4_200,
            liveHeartRate: 151,
            liveActiveEnergyKcal: 340
        )
        let sensor = WorkoutSensorSummary(
            steps: 3_000,
            activeEnergyKcal: 250,
            averageHeartRate: 140,
            maxHeartRate: 170,
            heartRateBefore: nil,
            heartRateAfter: nil
        )
        let today = DailyHealthMetric(
            date: .now,
            steps: 10_000,
            activeEnergyKcal: 500,
            dietaryEnergyKcal: 2_100,
            waterLiters: 1.5
        )

        let metrics = RouteMetricsBuilder.metrics(
            from: RouteMetricsBuilder.Input(
                trackerDistanceKm: 2.6,
                trackerPaceSecondsPerKm: 400,
                trackerSpeedKmh: 9.2,
                trackerPointCount: 40,
                activeStatus: status,
                sensorSummary: sensor,
                todayHealthMetric: today
            )
        )

        #expect(metrics.distanceKm == 3.2)
        #expect(metrics.paceSecondsPerKm == 312)
        #expect(metrics.speedKmh == 11.5)
        #expect(metrics.pointCount == 80)
        #expect(metrics.paceText == "5:12/km")
        #expect(metrics.speedText == "11.5 km/h")
        #expect(metrics.stepsText == "4200")
        #expect(metrics.heartRateText == "151 lpm")
        #expect(metrics.energyText == "340")
    }

    @Test func routeMetricsBuilderFallsBackToTrackerAndSensorOnly() {
        let sensor = WorkoutSensorSummary(
            steps: 2_200,
            activeEnergyKcal: nil,
            averageHeartRate: 132,
            maxHeartRate: nil,
            heartRateBefore: nil,
            heartRateAfter: nil
        )
        let today = DailyHealthMetric(
            date: .now,
            steps: 8_000,
            activeEnergyKcal: 410,
            dietaryEnergyKcal: 2_000,
            waterLiters: 1.0
        )

        let metrics = RouteMetricsBuilder.metrics(
            from: RouteMetricsBuilder.Input(
                trackerDistanceKm: 1.4,
                trackerPaceSecondsPerKm: 450,
                trackerSpeedKmh: 8,
                trackerPointCount: 18,
                activeStatus: nil,
                sensorSummary: sensor,
                todayHealthMetric: today
            )
        )

        #expect(metrics.distanceKm == 1.4)
        #expect(metrics.paceText == "7:30/km")
        #expect(metrics.speedText == "8.0 km/h")
        #expect(metrics.pointCount == 18)
        #expect(metrics.stepsText == "2200")
        #expect(metrics.heartRateText == "132 lpm")
        #expect(metrics.energyText == "--")
    }

    @Test func routeProgressBuilderCreatesRouteAndTreadmillSnapshots() {
        let preparedRoute = RouteProgressBuilder.snapshot(
            from: RouteProgressBuilder.Input(
                isTreadmill: false,
                isSessionStarted: false,
                isPaused: false,
                plannedDurationMinutes: 45,
                elapsedSeconds: 0,
                pausedSeconds: 0,
                distanceKm: 0,
                paceText: "--"
            )
        )

        #expect(preparedRoute.progress == 0)
        #expect(preparedRoute.visualState == .inactive)
        #expect(preparedRoute.icon == "location")
        #expect(preparedRoute.status == "RUTA PREPARADA")
        #expect(preparedRoute.subtitle == "45 min planificados")
        #expect(preparedRoute.startHintSystemImage == "location.fill")

        let activeRoute = RouteProgressBuilder.snapshot(
            from: RouteProgressBuilder.Input(
                isTreadmill: false,
                isSessionStarted: true,
                isPaused: false,
                plannedDurationMinutes: 30,
                elapsedSeconds: 900,
                pausedSeconds: 75,
                distanceKm: 2.35,
                paceText: "6:20/km"
            )
        )

        #expect(activeRoute.progress == 0.5)
        #expect(activeRoute.visualState == .active)
        #expect(activeRoute.icon == "figure.walk")
        #expect(activeRoute.status == "RUTA ACTIVA")
        #expect(activeRoute.subtitle == "2.35 km · 6:20/km · pausa 01:15")

        let pausedTreadmill = RouteProgressBuilder.snapshot(
            from: RouteProgressBuilder.Input(
                isTreadmill: true,
                isSessionStarted: true,
                isPaused: true,
                plannedDurationMinutes: 20,
                elapsedSeconds: 1_500,
                pausedSeconds: 0,
                distanceKm: 3.5,
                paceText: "5:42/km"
            )
        )

        #expect(pausedTreadmill.progress == 1)
        #expect(pausedTreadmill.visualState == .paused)
        #expect(pausedTreadmill.icon == "pause.fill")
        #expect(pausedTreadmill.status == "CINTA PAUSADA")
        #expect(pausedTreadmill.startHintSystemImage == "figure.run.treadmill")
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
        snapshot.monetization.provider = .iCloudOwner
        snapshot.monetization.lastPaywallSource = .profileSubscription
        snapshot.monetization.paywallPresentationCount = 3

        persistence.save(snapshot)

        let loaded = persistence.loadSnapshot()
        #expect(loaded?.monetization.entitlement == .pro)
        #expect(loaded?.monetization.status == .active)
        #expect(loaded?.monetization.billingCycle == .annual)
        #expect(loaded?.monetization.provider == .iCloudOwner)
        #expect(loaded?.monetization.lastPaywallSource == .profileSubscription)
        #expect(loaded?.monetization.paywallPresentationCount == 3)
    }

    @Test func iCloudProHashesAreNormalizedFromEnvironment() {
        let hash = ICloudProEntitlementService.sha256Hex("owner-record")
        let hashes = ICloudProEntitlementService.allowedRecordNameHashes(
            environment: ["REPS_PRO_ICLOUD_RECORD_ID_HASHES": " \(hash.uppercased()) , "]
        )

        #expect(hashes == [hash])
    }

    @Test func exerciseMediaAssetURLTrimsAndEncodesRemoteMedia() {
        let exercise = Exercise(
            name: "Cable Fly",
            muscleGroup: "Chest",
            equipment: "Cable",
            mediaURL: " https://example.com/exercises/cable fly/image 1.jpg "
        )

        #expect(exercise.mediaAssetURL?.absoluteString == "https://example.com/exercises/cable%20fly/image%201.jpg")
    }

    @Test func retentionEngineAddsReminderActivationWhenDisabled() {
        let steps = RetentionEngine.nextBestSteps(
            sessions: [WorkoutSession(workoutTitle: "Push", date: .now, durationMinutes: 40, sets: [])],
            activePlan: SeedData.pushPullLegsPlan,
            scheduledWorkouts: [
                ScheduledWorkout(date: .now.addingTimeInterval(86_400), workoutDay: SeedData.pushDay, status: .scheduled)
            ],
            remindersEnabled: false,
            competitiveSummary: AnalyticsEngine.competitiveSummary(
                sessions: [],
                activePlan: SeedData.pushPullLegsPlan,
                exercises: SeedData.exercises,
                since: .now.addingTimeInterval(-604_800)
            )
        )

        #expect(steps.contains { $0.id == "enable-reminders" && !$0.isCompleted })
    }

    @Test func retentionEngineKeepsCompetitiveActionsVisible() {
        let recommendation = AnalyticsEngine.CompetitiveRecommendation(
            title: "Prioriza Espalda",
            message: "Faltan 6 series para acercarte al objetivo semanal.",
            systemImage: "target",
            action: .scheduleUndertrainedMuscle("Back")
        )
        let summary = AnalyticsEngine.CompetitiveSummary(
            completedWorkouts: 1,
            plannedWorkouts: 3,
            completionRate: 0.33,
            targetWeeklySets: 18,
            actualWeeklySets: 8,
            muscleTargets: [],
            undertrainedMuscles: [],
            overtrainedMuscles: [],
            stalledExercises: [],
            recommendations: [recommendation]
        )

        let steps = RetentionEngine.nextBestSteps(
            sessions: [WorkoutSession(workoutTitle: "Pull", date: .now, durationMinutes: 42, sets: [])],
            activePlan: SeedData.pushPullLegsPlan,
            scheduledWorkouts: [
                ScheduledWorkout(date: .now.addingTimeInterval(86_400), workoutDay: SeedData.pullDay, status: .scheduled)
            ],
            remindersEnabled: true,
            competitiveSummary: summary
        )

        #expect(steps.contains { $0.title == recommendation.title && $0.action == .competitive(recommendation.action) })
    }

    @Test @MainActor func requireFeaturePresentsPaywallWhenProFeatureIsLocked() {
        let store = AppStore(persistence: SwiftDataPersistence(inMemory: true))

        let unlocked = store.requireFeature(.advancedAnalytics, source: .progressAdvancedAnalytics)

        #expect(!unlocked)
        #expect(store.activePaywall?.source == .progressAdvancedAnalytics)
        #expect(store.activePaywall?.feature == .advancedAnalytics)
    }

    @Test func notificationTargetParsesScheduledWorkoutPayload() throws {
        let workoutID = UUID()
        let date = try #require(ISO8601DateFormatter().date(from: "2026-06-24T08:00:00Z"))
        let target = NotificationService.notificationTarget(from: [
            "notification_kind": "workoutReminder",
            "scheduled_workout_id": workoutID.uuidString,
            "scheduled_workout_date": ISO8601DateFormatter().string(from: date)
        ])

        #expect(target?.kind == .workoutReminder)
        #expect(target?.scheduledWorkoutID == workoutID)
        #expect(target?.scheduledDate == date)
        #expect(target?.action == .open)
    }

    @Test func notificationTargetIgnoresNotificationsWithoutRoutingPayload() {
        #expect(NotificationService.notificationTarget(from: [:]) == nil)
        #expect(NotificationService.notificationTarget(from: ["notification_kind": "unknown"]) == nil)
    }

    @Test @MainActor func notificationTargetsRouteToExpectedTabs() {
        let store = AppStore(
            persistence: SwiftDataPersistence(inMemory: true),
            startsBackgroundServices: false
        )
        let date = Date(timeIntervalSince1970: 1_781_078_400)
        let workoutID = UUID()
        let cases: [(NotificationService.Kind, AppTab, Date?, UUID?)] = [
            (.workoutReminder, .calendar, date, workoutID),
            (.missedWorkoutCheck, .calendar, date, workoutID),
            (.dailySummary, .today, nil, nil),
            (.batteryRecoverySuggestion, .today, nil, nil),
            (.retentionNudge, .today, nil, nil),
            (.personalRecord, .progress, nil, nil),
            (.achievementUnlocked, .progress, nil, nil),
            (.streakAtRisk, .today, nil, nil),
            (.gymRenewal, .today, nil, nil)
        ]

        for testCase in cases {
            store.handleNotificationTarget(NotificationService.NotificationTarget(
                kind: testCase.0,
                scheduledWorkoutID: workoutID,
                scheduledDate: date,
                action: .open
            ))

            #expect(store.notificationDestination?.tab == testCase.1)
            #expect(store.notificationDestination?.focusDate == testCase.2)
            #expect(store.notificationDestination?.scheduledWorkoutID == testCase.3)
            #expect(store.notificationDestination?.action == .open)
            store.consumeNotificationDestination()
        }
    }

    @Test @MainActor func notificationLogWorkoutActionPreservesScheduledWorkoutDestination() {
        let store = AppStore(
            persistence: SwiftDataPersistence(inMemory: true),
            startsBackgroundServices: false
        )
        let scheduled = ScheduledWorkout(
            date: Date(timeIntervalSince1970: 1_781_078_400),
            workoutDay: SeedData.pushDay,
            status: .scheduled
        )
        store.scheduledWorkouts = [scheduled]

        store.handleNotificationTarget(NotificationService.NotificationTarget(
            kind: .workoutReminder,
            scheduledWorkoutID: scheduled.id,
            scheduledDate: scheduled.date,
            action: .logWorkout
        ))

        #expect(store.notificationDestination?.tab == .calendar)
        #expect(store.notificationDestination?.focusDate == scheduled.date)
        #expect(store.notificationDestination?.scheduledWorkoutID == scheduled.id)
        #expect(store.notificationDestination?.action == .logWorkout)
    }

    @Test @MainActor func notificationMarkDoneActionCompletesScheduledWorkout() {
        let store = AppStore(
            persistence: SwiftDataPersistence(inMemory: true),
            startsBackgroundServices: false
        )
        let scheduled = ScheduledWorkout(
            date: Date(timeIntervalSince1970: 1_781_078_400),
            workoutDay: SeedData.pullDay,
            status: .scheduled
        )
        store.scheduledWorkouts = [scheduled]

        store.handleNotificationTarget(NotificationService.NotificationTarget(
            kind: .missedWorkoutCheck,
            scheduledWorkoutID: scheduled.id,
            scheduledDate: scheduled.date,
            action: .markDone
        ))

        #expect(store.scheduledWorkouts.first?.status == .completed)
        #expect(store.notificationDestination?.tab == .calendar)
        #expect(store.notificationDestination?.action == .markDone)
    }

    @Test func currentNotificationSchedulersCreateRoutableRequests() async throws {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        defer {
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }

        let scheduled = ScheduledWorkout(
            date: Date().addingTimeInterval(172_800),
            workoutDay: SeedData.pushDay,
            status: .scheduled
        )

        NotificationService.scheduleRestEndNotification(after: 120, nextExerciseName: "Bench Press")
        try await NotificationService.scheduleWorkoutReminder(for: scheduled)
        try await NotificationService.scheduleMissedWorkoutCheck(for: scheduled)
        try await NotificationService.scheduleDailySummary(hour: 23, minute: 55)
        try await NotificationService.scheduleBatteryRecoverySuggestion(level: 42, suggestion: "Take a lighter day.")
        try await NotificationService.scheduleRetentionNudge(
            title: "Plan tomorrow",
            body: "Keep momentum.",
            date: Date().addingTimeInterval(7_200)
        )
        try await NotificationService.schedulePersonalRecordCelebration(exerciseName: "Squat", delay: 120)
        let streakBaseDate = try #require(ISO8601DateFormatter().date(from: "2026-06-24T08:00:00Z"))
        try await NotificationService.scheduleStreakAtRiskReminder(
            currentStreak: 3,
            hour: 12,
            minute: 0,
            now: streakBaseDate
        )
        try await NotificationService.scheduleGymRenewalReminder(
            passID: UUID(),
            gymName: "Test Gym",
            renewalDate: Date().addingTimeInterval(604_800)
        )
        try await NotificationService.scheduleAchievementUnlocked(message: "Unlocked", delay: 120)
        try await NotificationService.scheduleGoalReached(goalTitle: "Bench 100", delay: 120)
        NotificationService.postCloudKitSocialNotification(subscriptionID: "new-follower-test")
        NotificationService.postCloudKitSocialNotification(subscriptionID: "new-like-test")

        try await Task.sleep(nanoseconds: 500_000_000)
        let requests = await center.pendingNotificationRequests()
        let byIdentifier = Dictionary(uniqueKeysWithValues: requests.map { ($0.identifier, $0) })
        let routableKinds = Set(requests.compactMap { $0.content.userInfo["notification_kind"] as? String })

        #expect(byIdentifier["rest-timer-end"] != nil)
        #expect(byIdentifier["daily-summary"]?.content.userInfo["notification_kind"] as? String == "dailySummary")
        #expect(byIdentifier["battery-recovery-suggestion"]?.content.userInfo["notification_kind"] as? String == "batteryRecoverySuggestion")
        #expect(byIdentifier["streak-at-risk"]?.content.userInfo["notification_kind"] as? String == "streakAtRisk")
        #expect(requests.contains { $0.identifier.hasPrefix("workout-reminder-") && $0.content.categoryIdentifier == "WORKOUT_REMINDER" })
        #expect(requests.contains { $0.identifier.hasPrefix("missed-workout-") && $0.content.categoryIdentifier == "MISSED_WORKOUT" })
        #expect(requests.contains { $0.identifier.hasPrefix("retention-nudge-") && ($0.content.userInfo["notification_kind"] as? String) == "retentionNudge" })
        #expect(requests.contains { $0.identifier.hasPrefix("personal-record-") && ($0.content.userInfo["notification_kind"] as? String) == "personalRecord" })
        #expect(requests.contains { $0.identifier.hasPrefix("gym-renewal-") && ($0.content.userInfo["notification_kind"] as? String) == "gymRenewal" })
        #expect(requests.contains { $0.identifier.hasPrefix("achievement-") && ($0.content.userInfo["notification_kind"] as? String) == "achievementUnlocked" })
        #expect(requests.contains { $0.identifier.hasPrefix("achievement-goal-") && ($0.content.userInfo["notification_kind"] as? String) == "achievementUnlocked" })
        #expect(requests.filter { $0.identifier.hasPrefix("social-") }.count == 2)
        #expect(routableKinds.isSuperset(of: [
            "workoutReminder",
            "missedWorkoutCheck",
            "dailySummary",
            "batteryRecoverySuggestion",
            "retentionNudge",
            "personalRecord",
            "streakAtRisk",
            "gymRenewal",
            "achievementUnlocked"
        ]))
    }
}

import Foundation

struct OnboardingResult {
    var profile: UserProfile
    var bodyMetric: BodyMetric
    var plan: WorkoutPlan
}

enum OnboardingPlanBuilder {
    static func makePlan(
        profile: UserProfile,
        bodyMetric: BodyMetric,
        sessionLengthMinutes: Int?,
        focusMuscles: [String]
    ) -> WorkoutPlan {
        let dayCount = max(2, min(profile.weeklyTrainingDays, 6))
        let exerciseCount = exerciseCount(for: sessionLengthMinutes)
        let restBetweenExercises = restBetweenExercises(for: profile.experience)
        let days = makeDays(
            profile: profile,
            bodyMetric: bodyMetric,
            dayCount: dayCount,
            exerciseCount: exerciseCount,
            restBetweenExercises: restBetweenExercises,
            focusMuscles: focusMuscles
        )

        return WorkoutPlan(
            name: "Plan base adaptado",
            location: profile.trainingLocation,
            daysPerWeek: dayCount,
            currentWeek: 1,
            totalWeeks: 8,
            completion: 0,
            days: days
        )
    }

    private static func makeDays(
        profile: UserProfile,
        bodyMetric: BodyMetric,
        dayCount: Int,
        exerciseCount: Int,
        restBetweenExercises: Int,
        focusMuscles: [String]
    ) -> [WorkoutDay] {
        let splits = splitNames(for: dayCount)
        return splits.enumerated().map { index, split in
            let exercises = exercises(
                for: split,
                profile: profile,
                bodyMetric: bodyMetric,
                exerciseCount: exerciseCount,
                focusMuscles: focusMuscles
            )
            return WorkoutDay(
                title: "Dia \(index + 1) - \(split.title)",
                subtitle: split.subtitle,
                durationMinutes: duration(for: exercises.count, experience: profile.experience),
                exercises: exercises,
                restBetweenExercisesSeconds: restBetweenExercises
            )
        }
    }

    private static func exercises(
        for split: TrainingSplit,
        profile: UserProfile,
        bodyMetric: BodyMetric,
        exerciseCount: Int,
        focusMuscles: [String]
    ) -> [WorkoutExercise] {
        let pool = exercisePool(for: profile.trainingLocation, equipment: profile.availableEquipment)
        let orderedGroups = prioritizedGroups(split.groups, focusMuscles: focusMuscles)
        var selected: [WorkoutExercise] = []

        for group in orderedGroups {
            guard selected.count < exerciseCount,
                  let exercise = pool.first(where: { matches($0, group: group) && !selected.map(\.exercise.id).contains($0.id) }) else {
                continue
            }
            selected.append(prescription(for: exercise, profile: profile, bodyMetric: bodyMetric, isFocus: focusMuscles.contains(group)))
        }

        if selected.count < exerciseCount {
            for exercise in pool where !selected.map(\.exercise.id).contains(exercise.id) {
                selected.append(prescription(for: exercise, profile: profile, bodyMetric: bodyMetric, isFocus: false))
                if selected.count >= exerciseCount {
                    break
                }
            }
        }

        return selected
    }

    private static func prescription(
        for exercise: Exercise,
        profile: UserProfile,
        bodyMetric: BodyMetric,
        isFocus: Bool
    ) -> WorkoutExercise {
        let sets: Int
        switch profile.experience {
        case .beginner:
            sets = isFocus ? 3 : 2
        case .intermediate:
            sets = isFocus ? 4 : 3
        case .advanced:
            sets = isFocus ? 5 : 4
        }

        let repRange: String
        let rest: Int
        switch profile.mainGoal {
        case .getStronger:
            repRange = exercise.trackingType == .duration ? "30-45 sec" : "5-8"
            rest = 150
        case .loseFat:
            repRange = exercise.trackingType == .duration ? "40-60 sec" : "10-15"
            rest = 60
        case .stayActive:
            repRange = exercise.trackingType == .duration ? "30-45 sec" : "8-12"
            rest = 75
        case .buildMuscle:
            repRange = exercise.trackingType == .duration ? "30-45 sec" : "8-12"
            rest = 90
        }

        let previous = startingLoad(for: exercise, bodyMetric: bodyMetric, profile: profile, reps: repRange)
        return WorkoutExercise(
            exercise: exercise,
            targetSets: sets,
            repRange: repRange,
            previous: previous,
            restSeconds: rest,
            priority: isFocus ? .primary : .secondary,
            progressionType: profile.experience == .beginner ? .linear : .doubleProgression,
            targetRIR: profile.experience == .advanced ? 1 : 2,
            cues: isFocus ? "Prioridad del onboarding: protege tecnica y recuperacion." : nil
        )
    }

    private static func exercisePool(for location: UserProfile.TrainingLocation, equipment: [String]) -> [Exercise] {
        let normalizedEquipment = Set(equipment.map { $0.lowercased() })
        let hasHomeEquipment = normalizedEquipment.contains("dumbbells")
            || normalizedEquipment.contains("resistance band")
            || normalizedEquipment.contains("resistance bands")
            || normalizedEquipment.contains("bodyweight")
            || normalizedEquipment.contains("kettlebell")
        let prefersHome = location == .home || (location == .both && hasHomeEquipment)

        if prefersHome {
            return [
                SeedData.floorPress, SeedData.gobletSquat, SeedData.bandRow, SeedData.splitSquat,
                SeedData.pushup, SeedData.romanianDeadlift, SeedData.lateralRaise, SeedData.curl,
                SeedData.tricepsExtension, SeedData.plank, SeedData.mountainClimber, SeedData.calfRaise
            ]
        }

        return [
            SeedData.bench, SeedData.squat, SeedData.deadlift, SeedData.row, SeedData.incline,
            SeedData.overhead, SeedData.pullup, SeedData.lunge, SeedData.romanianDeadlift,
            SeedData.lateralRaise, SeedData.curl, SeedData.tricepsExtension, SeedData.plank
        ]
    }

    private static func splitNames(for dayCount: Int) -> [TrainingSplit] {
        switch dayCount {
        case 2:
            return [
                TrainingSplit(title: "Full body A", subtitle: "Empuje, pierna y core", groups: ["Chest", "Legs", "Back", "Core"]),
                TrainingSplit(title: "Full body B", subtitle: "Tiron, gluteos y brazos", groups: ["Back", "Glutes", "Shoulders", "Arms"])
            ]
        case 3:
            return [
                TrainingSplit(title: "Empuje", subtitle: "Pecho, hombro y triceps", groups: ["Chest", "Shoulders", "Arms", "Core"]),
                TrainingSplit(title: "Tiron", subtitle: "Espalda y biceps", groups: ["Back", "Arms", "Shoulders", "Core"]),
                TrainingSplit(title: "Pierna", subtitle: "Cuadriceps, isquios y gluteos", groups: ["Legs", "Glutes", "Core", "Back"])
            ]
        case 4:
            return [
                TrainingSplit(title: "Superior A", subtitle: "Fuerza de torso", groups: ["Chest", "Back", "Shoulders", "Arms"]),
                TrainingSplit(title: "Inferior A", subtitle: "Pierna completa", groups: ["Legs", "Glutes", "Core"]),
                TrainingSplit(title: "Superior B", subtitle: "Volumen de torso", groups: ["Back", "Chest", "Arms", "Shoulders"]),
                TrainingSplit(title: "Inferior B", subtitle: "Cadena posterior", groups: ["Glutes", "Legs", "Core"])
            ]
        default:
            return [
                TrainingSplit(title: "Push", subtitle: "Pecho, hombro y triceps", groups: ["Chest", "Shoulders", "Arms"]),
                TrainingSplit(title: "Pull", subtitle: "Espalda y biceps", groups: ["Back", "Arms", "Shoulders"]),
                TrainingSplit(title: "Legs", subtitle: "Pierna completa", groups: ["Legs", "Glutes", "Core"]),
                TrainingSplit(title: "Upper", subtitle: "Torso mixto", groups: ["Chest", "Back", "Shoulders", "Arms"]),
                TrainingSplit(title: "Lower", subtitle: "Fuerza inferior", groups: ["Legs", "Glutes", "Core"]),
                TrainingSplit(title: "Focus", subtitle: "Musculos prioritarios", groups: ["Back", "Chest", "Legs", "Arms", "Core"])
            ].prefix(dayCount).map { $0 }
        }
    }

    private static func prioritizedGroups(_ groups: [String], focusMuscles: [String]) -> [String] {
        let focused = focusMuscles.filter { groups.contains($0) }
        let rest = groups.filter { !focused.contains($0) }
        return focused + rest
    }

    private static func matches(_ exercise: Exercise, group: String) -> Bool {
        let value = "\(exercise.name) \(exercise.muscleGroup) \(exercise.secondaryMuscles.joined(separator: " "))".lowercased()
        switch group {
        case "Chest": return value.contains("chest") || value.contains("press") || value.contains("push")
        case "Back": return value.contains("back") || value.contains("row") || value.contains("pull") || value.contains("deadlift")
        case "Shoulders": return value.contains("shoulder") || value.contains("delt") || value.contains("overhead") || value.contains("face")
        case "Arms": return value.contains("arm") || value.contains("curl") || value.contains("tricep")
        case "Legs": return value.contains("leg") || value.contains("squat") || value.contains("lunge") || value.contains("calf")
        case "Glutes": return value.contains("glute") || value.contains("hip") || value.contains("romanian") || value.contains("split")
        case "Core": return value.contains("core") || value.contains("plank") || value.contains("climber")
        default: return false
        }
    }

    private static func startingLoad(for exercise: Exercise, bodyMetric: BodyMetric, profile: UserProfile, reps: String) -> String {
        switch exercise.trackingType {
        case .duration:
            return reps
        case .repsOnly:
            return "Peso corporal x \(reps)"
        case .weightReps:
            let multiplier: Double
            switch profile.experience {
            case .beginner: multiplier = 0.18
            case .intermediate: multiplier = 0.30
            case .advanced: multiplier = 0.42
            }
            let load = max(2.5, (bodyMetric.weightKg * multiplier / 2.5).rounded() * 2.5)
            return String(format: "%.1f kg x %@", load, reps)
        }
    }

    private static func exerciseCount(for sessionLengthMinutes: Int?) -> Int {
        switch sessionLengthMinutes ?? 60 {
        case ..<40: return 3
        case 40..<60: return 4
        default: return 5
        }
    }

    private static func restBetweenExercises(for experience: UserProfile.Experience) -> Int {
        switch experience {
        case .beginner: 90
        case .intermediate: 120
        case .advanced: 150
        }
    }

    private static func duration(for exerciseCount: Int, experience: UserProfile.Experience) -> Int {
        let base = exerciseCount * 10
        switch experience {
        case .beginner: return base
        case .intermediate: return base + 5
        case .advanced: return base + 10
        }
    }
}

private struct TrainingSplit {
    let title: String
    let subtitle: String
    let groups: [String]
}

import Foundation

enum SmartProgressionAdvisor {
    struct Recommendation: Identifiable, Equatable {
        let id = UUID()
        let exercise: Exercise
        let workoutExercise: WorkoutExercise
        let suggestion: ProgressionEngine.Suggestion
        let recentSetCount: Int

        var hasLoadTarget: Bool {
            suggestion.targetWeightKg > 0
        }

        var isActionable: Bool {
            hasLoadTarget || recentSetCount > 0
        }
    }

    static func recommendations(
        for workout: WorkoutDay,
        sessions: [WorkoutSession],
        weightIncrementKg: Double,
        limit: Int = 3
    ) -> [Recommendation] {
        workout.exercises.compactMap { item in
            let recentSets = recentSets(for: item.exercise, in: sessions)
            guard !recentSets.isEmpty else {
                return nil
            }

            return Recommendation(
                exercise: item.exercise,
                workoutExercise: item,
                suggestion: ProgressionEngine.nextSuggestion(
                    for: item,
                    recentSets: recentSets,
                    weightIncrementKg: weightIncrementKg
                ),
                recentSetCount: recentSets.count
            )
        }
        .filter(\.isActionable)
        .sorted { lhs, rhs in
            if lhs.suggestion.shouldDeload != rhs.suggestion.shouldDeload {
                return lhs.suggestion.shouldDeload
            }
            if lhs.hasLoadTarget != rhs.hasLoadTarget {
                return lhs.hasLoadTarget
            }
            return lhs.recentSetCount > rhs.recentSetCount
        }
        .prefix(limit)
        .map { $0 }
    }

    static func recommendation(
        for item: WorkoutExercise,
        sessions: [WorkoutSession],
        weightIncrementKg: Double
    ) -> Recommendation? {
        recommendations(
            for: WorkoutDay(
                title: "",
                subtitle: "",
                durationMinutes: 0,
                exercises: [item]
            ),
            sessions: sessions,
            weightIncrementKg: weightIncrementKg,
            limit: 1
        )
        .first
    }

    static func recentSets(for exercise: Exercise, in sessions: [WorkoutSession], limit: Int = 12) -> [SetLog] {
        sessions
            .sorted { $0.date > $1.date }
            .flatMap { session in
                (session.exerciseLogs ?? []).filter { log in
                    log.exercise.id == exercise.id ||
                    normalizedExerciseName(log.exercise.name) == normalizedExerciseName(exercise.name)
                }
                .flatMap(\.sets)
            }
            .filter(\.completed)
            .prefix(limit)
            .map { $0 }
    }

    private static func normalizedExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

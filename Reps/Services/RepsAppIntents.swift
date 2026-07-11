import AppIntents

/// System entry points intentionally route through the app's existing deep-link
/// coordinator. Siri and Shortcuts therefore use the same workout and navigation
/// logic as taps inside Reps instead of maintaining a second state machine.
struct StartRecommendedWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recommended Workout"
    static var description = IntentDescription("Open Reps and start the workout selected for today.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "reps://workout/recommended")!))
    }
}

struct OpenTrainingProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Training Progress"
    static var description = IntentDescription("Open your training history, progression and personal records in Reps.")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "reps://progress")!))
    }
}

struct RepsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecommendedWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Inicia mi entrenamiento en \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: OpenTrainingProgressIntent(),
            phrases: [
                "Show my progress in \(.applicationName)",
                "Muestra mi progreso en \(.applicationName)"
            ],
            shortTitle: "Training Progress",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .navy
}

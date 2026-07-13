import AppIntents
import Foundation

extension Notification.Name {
    static let repsStartFreeWorkoutIntent = Notification.Name("RepsStartFreeWorkoutIntent")
}

struct StartFreeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_start_free_workout_title"
    static let description = IntentDescription("intent_start_free_workout_description")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .repsStartFreeWorkoutIntent, object: nil)
        return .result()
    }
}

struct StreakStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_streak_status_title"
    static let description = IntentDescription("intent_streak_status_description")

    // Dialog text is resolved through the app's own localization helpers
    // (RepsLocalization) rather than LocalizedStringResource interpolation,
    // so the wording matches whatever the rest of Reps would say for the
    // current language rather than depending on the system/Siri locale.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let days = SharedWorkoutStore.load().streakDays
        let dialog: IntentDialog
        if days > 0 {
            let full = days == 1
                ? localizedString("intent_streak_full_singular")
                : localizedFormat("intent_streak_full_plural_format", days)
            let supporting = localizedFormat("intent_streak_supporting_format", days)
            dialog = IntentDialog(
                full: LocalizedStringResource(stringLiteral: full),
                supporting: LocalizedStringResource(stringLiteral: supporting)
            )
        } else {
            dialog = IntentDialog(stringLiteral: localizedString("intent_streak_none"))
        }
        return .result(dialog: dialog)
    }
}

/// System entry points intentionally route through the app's existing deep-link
/// coordinator. Siri and Shortcuts therefore use the same workout and navigation
/// logic as taps inside Reps instead of maintaining a second state machine.
struct StartRecommendedWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_start_recommended_workout_title"
    static let description = IntentDescription("intent_start_recommended_workout_description")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "reps://workout/recommended")!))
    }
}

struct OpenTrainingProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_open_training_progress_title"
    static let description = IntentDescription("intent_open_training_progress_description")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "reps://progress")!))
    }
}

struct RepsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFreeWorkoutIntent(),
            phrases: [
                "Start a free workout in \(.applicationName)",
                "Empieza un entreno en \(.applicationName)",
                "Entrenar con \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_train_title",
            systemImageName: "dumbbell.fill"
        )
        AppShortcut(
            intent: StreakStatusIntent(),
            phrases: [
                "How's my streak in \(.applicationName)",
                "Cómo va mi racha en \(.applicationName)",
                "Mi racha de \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_streak_title",
            systemImageName: "flame.fill"
        )
        AppShortcut(
            intent: StartRecommendedWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Inicia mi entrenamiento en \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_start_workout_title",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: OpenTrainingProgressIntent(),
            phrases: [
                "Show my progress in \(.applicationName)",
                "Muestra mi progreso en \(.applicationName)"
            ],
            shortTitle: "intent_shortcut_training_progress_title",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .navy
}

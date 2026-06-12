import AppIntents
import Foundation

extension Notification.Name {
    static let repsStartFreeWorkoutIntent = Notification.Name("RepsStartFreeWorkoutIntent")
}

struct StartFreeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Empezar entreno libre"
    static let description = IntentDescription("Abre StreakRep y prepara un entreno libre.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .repsStartFreeWorkoutIntent, object: nil)
        return .result()
    }
}

struct StreakStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Consultar racha"
    static let description = IntentDescription("Dice cuántos días llevas de racha de entrenos.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let days = SharedWorkoutStore.load().streakDays
        let dialog: IntentDialog
        if days > 0 {
            dialog = IntentDialog(full: "Llevas \(days) \(days == 1 ? "día" : "días") de racha. ¡Sigue así!", supporting: "Racha: \(days)")
        } else {
            dialog = IntentDialog("Aún no tienes racha activa. ¡Hoy es buen día para entrenar!")
        }
        return .result(dialog: dialog)
    }
}

struct RepsAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFreeWorkoutIntent(),
            phrases: [
                "Empieza un entreno en \(.applicationName)",
                "Entrenar con \(.applicationName)"
            ],
            shortTitle: "Entrenar",
            systemImageName: "dumbbell.fill"
        )
        AppShortcut(
            intent: StreakStatusIntent(),
            phrases: [
                "Cómo va mi racha en \(.applicationName)",
                "Mi racha de \(.applicationName)"
            ],
            shortTitle: "Racha",
            systemImageName: "flame.fill"
        )
    }
}

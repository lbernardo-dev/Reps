import AppIntents
import Foundation

struct StartFreeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_start_free_workout_title"
    static let description = IntentDescription("intent_start_free_workout_description")

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "reps://workout/free")!))
    }
}

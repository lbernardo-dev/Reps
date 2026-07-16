import AppIntents
import SwiftUI
import WidgetKit

struct RepsStartWorkoutControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.romerodev.repsfitness.start-free-workout") {
            ControlWidgetButton(action: StartFreeWorkoutIntent()) {
                Label("control_start_free_workout_title", systemImage: "dumbbell.fill")
            }
        }
        .displayName("control_start_free_workout_title")
        .description("control_start_free_workout_description")
    }
}

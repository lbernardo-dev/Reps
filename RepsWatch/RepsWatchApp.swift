import HealthKit
import SwiftUI
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    private weak var model: WatchWorkoutModel?
    private var pendingWorkoutConfiguration: HKWorkoutConfiguration?

    func attach(model: WatchWorkoutModel) {
        self.model = model
        guard let pendingWorkoutConfiguration else { return }
        self.pendingWorkoutConfiguration = nil
        model.startWorkout(configuration: pendingWorkoutConfiguration)
    }

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        guard let model else {
            pendingWorkoutConfiguration = workoutConfiguration
            return
        }
        model.startWorkout(configuration: workoutConfiguration)
    }
}

@main
struct RepsWatchApp: App {
    @StateObject private var model = WatchWorkoutModel()
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .environmentObject(model)
                .onAppear {
                    appDelegate.attach(model: model)
                }
        }
    }
}

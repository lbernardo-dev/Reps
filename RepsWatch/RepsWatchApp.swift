import SwiftUI

@main
struct RepsWatchApp: App {
    @StateObject private var model = WatchWorkoutModel()

    var body: some Scene {
        WindowGroup {
            WatchWorkoutView()
                .environmentObject(model)
        }
    }
}

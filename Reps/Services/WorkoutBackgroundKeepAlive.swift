import UIKit

/// Holds a single UIBackgroundTaskIdentifier while a workout is active so the
/// app gets the standard grace period (~30 s) to finish persisting state when
/// the user backgrounds it mid-session.
///
/// On iOS 26+ this is unnecessary: the active HKWorkoutSession owned by
/// NativeWorkoutSessionService keeps the process running for the whole
/// workout, so callers skip this service entirely there. Renewing/chaining
/// background tasks to extend runtime is not supported by the system (the
/// background-time budget is global) and violates App Review guidelines, so
/// no renewal is attempted.
@MainActor
final class WorkoutBackgroundKeepAlive {
    static let shared = WorkoutBackgroundKeepAlive()
    private init() {}

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func startIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WorkoutSession") { [weak self] in
            self?.stop()
        }
    }

    func stop() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

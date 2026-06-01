import UIKit

/// Keeps a UIBackgroundTaskIdentifier alive for the duration of an active
/// workout so iOS does not suspend the process while the user is resting
/// between sets, has the screen off, or has navigated to the home screen.
///
/// Usage:
///   WorkoutBackgroundKeepAlive.shared.startIfNeeded()
///   WorkoutBackgroundKeepAlive.shared.stop()
///
/// The system will call the expiration handler after the allowed background
/// time (~30 s for standard tasks, can chain on watchOS). We renew it every
/// 20 seconds to avoid expiry interrupting a rest period.
@MainActor
final class WorkoutBackgroundKeepAlive {
    static let shared = WorkoutBackgroundKeepAlive()
    private init() {}

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var renewalTimer: Timer?

    // MARK: - Public API

    func startIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        beginTask()
        scheduleRenewal()
    }

    func stop() {
        renewalTimer?.invalidate()
        renewalTimer = nil
        endTask()
    }

    // MARK: - Private helpers

    private func beginTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "WorkoutSession") { [weak self] in
            // Expiration handler — system is about to suspend. Clean up.
            self?.endTask()
        }
    }

    private func endTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    /// Renew the background task before it expires so long rest periods
    /// (e.g. 3 min) don't get cut off.
    private func scheduleRenewal() {
        renewalTimer?.invalidate()
        renewalTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // End the current task and begin a fresh one to reset the timer.
                self.endTask()
                self.beginTask()
            }
        }
    }
}

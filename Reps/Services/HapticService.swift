import UIKit

@MainActor
enum HapticService {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Strong double pulse used when the between-sets rest timer reaches zero.
    static func restTimerEnded() {
        impact(.heavy)
        Task {
            try? await Task.sleep(nanoseconds: 140_000_000)
            await MainActor.run { impact(.heavy) }
        }
    }

    /// Distinct, more emphatic triple pulse used when the exercise-change timer
    /// reaches zero and the session auto-advances — needs to read as different
    /// from `restTimerEnded()` without the user looking at the screen.
    static func exerciseChangeTimerEnded() {
        impact(.heavy)
        Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            await MainActor.run { impact(.heavy) }
            try? await Task.sleep(nanoseconds: 160_000_000)
            await MainActor.run { notification(.warning) }
        }
    }
}

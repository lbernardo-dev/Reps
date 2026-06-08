import UIKit
import SwiftUI

struct WorkoutShareImageRenderer {
    @MainActor
    static func render(session: WorkoutSession) -> UIImage {
        let view = WorkoutReceiptView(session: session)
            .frame(width: 375) // Provide a standard container width for rendering
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 // High density rendering for beautiful shares
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    static func render(payload: WorkoutReceiptSharePayload) -> UIImage {
        let view = WorkoutReceiptView(payload: payload)
            .frame(width: 375)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }

    @MainActor
    static func render(title: String, duration: Int, volume: Int, sets: Int) -> UIImage {
        // Create a mock WorkoutSession to keep compatibility with PRs and general metrics sharing
        let mockSession = WorkoutSession(
            id: UUID(),
            workoutTitle: title,
            date: Date(),
            startedAt: Date().addingTimeInterval(-Double(duration * 60)),
            endedAt: Date(),
            origin: .free,
            location: .gym,
            contextTag: .normal,
            durationMinutes: duration,
            sets: [],
            notes: nil,
            exerciseLogs: []
        )
        let view = WorkoutReceiptView(session: mockSession)
            .frame(width: 375)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }
}

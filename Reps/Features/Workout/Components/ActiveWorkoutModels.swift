import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct ExerciseReplacementTarget: Identifiable {
    let index: Int
    var id: Int { index }
}


struct UndoSetContext {
    let exerciseIndex: Int
    let setIndex: Int
    let previousLastSetCompletedAtSeconds: Int?
}

struct SetCompletionFeedback: Identifiable, Equatable {
    let id = UUID()
    let exerciseName: String
    let setNumber: Int
}

struct SetCompletionFeedbackBanner: View {
    let feedback: SetCompletionFeedback
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(PulseTheme.growth)
                .frame(width: 34, height: 34)
                .background(PulseTheme.growth.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("set_registered_feedback_title")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.primary)
                Text("\(feedback.exerciseName) · set \(feedback.setNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer(minLength: 8)

            Button("undo_set", action: onUndo)
                .font(.caption.weight(.black))
                .buttonStyle(.plain)
                .foregroundStyle(PulseTheme.accent)
                .frame(minHeight: 34)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }
}

struct CoreExerciseSuggestionTile: View {
    let exercise: Exercise
    let language: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: exercise.trackingType == .duration ? "timer" : "figure.core.training")
                .font(.headline.weight(.black))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 32, height: 32)
                .background(PulseTheme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(RepsText.exerciseName(exercise.name, language: language))
                    .font(.caption.weight(.black))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(RepsText.equipment(exercise.equipment, language: language))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(minHeight: 62)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

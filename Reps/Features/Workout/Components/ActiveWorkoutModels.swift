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

    @State private var appeared = false
    @State private var checkPulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PulseTheme.growth.opacity(checkPulse ? 0.28 : 0.14))
                    .frame(width: 38, height: 38)
                    .scaleEffect(checkPulse ? 1.18 : 1.0)
                    .animation(.easeInOut(duration: 0.36).repeatCount(2, autoreverses: true), value: checkPulse)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PulseTheme.growth)
                    .scaleEffect(checkPulse ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55).repeatCount(2, autoreverses: true), value: checkPulse)
            }
            .frame(width: 38, height: 38)

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
                .stroke(PulseTheme.growth.opacity(appeared ? 0.40 : 0.10), lineWidth: 1.2)
        }
        .shadow(color: PulseTheme.growth.opacity(appeared ? 0.22 : 0.0), radius: 14, y: 6)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.72)
        .opacity(appeared ? 1.0 : 0.0)
        .animation(.spring(response: 0.42, dampingFraction: 0.58), value: appeared)
        .accessibilityElement(children: .combine)
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                checkPulse = true
            }
        }
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

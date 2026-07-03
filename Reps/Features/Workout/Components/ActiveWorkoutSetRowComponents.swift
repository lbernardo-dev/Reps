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

struct BatteryMicroMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(localizedKey(title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}


struct SetRow: View {
    @Binding var set: SetLog
    let trackingType: Exercise.TrackingType
    let onCompletionChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Row 1 — set number + column labels + completion button
            HStack(spacing: 6) {
                // Set number badge
                Text("\(set.setNumber)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(set.completed ? PulseTheme.accent : PulseTheme.elevated)
                    .clipShape(Circle())
                    .scaleEffect(set.completed ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25), value: set.completed)

                ForEach(columnLabels, id: \.self) { label in
                    Text(localizedKey(label))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

                // Spacer to align with checkmark below
                Color.clear.frame(width: 38, height: 1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Row 2 — steppers + completion button
            HStack(spacing: 6) {
                // Alignment spacer matching the set number badge
                Color.clear.frame(width: 28, height: 1)

                if trackingType == .weightReps {
                    InlineStepper(
                        value: $set.weightKg,
                        range: 0...400,
                        step: 2.5,
                        formatter: { String(format: "%.1f", $0) }
                    )
                    .frame(maxWidth: .infinity)
                }

                InlineStepper(
                    value: Binding(
                        get: { Double(set.reps) },
                        set: { set.reps = Int($0) }
                    ),
                    range: 0...durationOrRepUpperBound,
                    step: trackingType == .duration ? 5 : 1,
                    formatter: { trackingType == .duration ? "\(Int($0))s" : String(Int($0)) }
                )
                .frame(maxWidth: .infinity)

                // Completion / PR button
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        set.completed.toggle()
                        onCompletionChanged(set.completed)
                    }
                } label: {
                    Image(systemName: set.isPersonalRecord ? "trophy.fill" : (set.completed ? "checkmark.circle.fill" : "circle"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                        .frame(width: 38, height: 38)
                        .background(set.isPersonalRecord ? PulseTheme.accent : (set.completed ? PulseTheme.accent : PulseTheme.elevated))
                        .clipShape(Circle())
                        .scaleEffect(set.completed ? 1.12 : 1.0)
                        .shadow(color: set.completed ? PulseTheme.accent.opacity(0.28) : Color.clear, radius: 5, x: 0, y: 2)
                        .animation(.spring(response: 0.25), value: set.completed)
                }
                .accessibilityLabel(set.completed ? "Marcar serie \(set.setNumber) incompleta" : "Marcar serie \(set.setNumber) completa")
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .background(set.completed ? PulseTheme.accent.opacity(0.10) : PulseTheme.grouped)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(set.completed ? PulseTheme.accent.opacity(0.35) : Color.white.opacity(0.04), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: set.completed)
    }

    private var columnLabels: [String] {
        switch trackingType {
        case .weightReps:
            return ["weight_kg_3", "reps_4"]
        case .repsOnly:
            return ["reps_4"]
        case .duration:
            return ["Time"]
        }
    }

    private var durationOrRepUpperBound: Double {
        trackingType == .duration ? 600 : 100
    }
}


struct AdvancedSetFields: View {
    @Binding var set: SetLog
    let showSetType: Bool
    let showRPE: Bool
    let showRIR: Bool
    let showTempo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localizedFormat("set_number_format", set.setNumber))
                    .font(.subheadline.weight(.bold))
                Spacer()
                if set.isPersonalRecord {
                    Label("pr_2", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }

            HStack(spacing: 10) {
                if showSetType {
                Menu {
                    ForEach(SetLog.SetType.allCases) { type in
                        Button(setTypeTitle(type)) {
                            set.setType = type
                        }
                    }
                } label: {
                    Label(setTypeTitle(set.setType), systemImage: "tag")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                }

                if showRPE {
                InlineStepper(
                    value: Binding(
                        get: { set.rpe ?? 7 },
                        set: { set.rpe = $0 }
                    ),
                    range: 0...10,
                    step: 0.5,
                    formatter: { "RPE \(String(format: "%.1f", $0))" }
                )
                }
            }

            HStack(spacing: 10) {
                if showRIR {
                InlineStepper(
                    value: Binding(
                        get: { Double(set.rir ?? 2) },
                        set: { set.rir = Int($0) }
                    ),
                    range: 0...5,
                    step: 1,
                    formatter: { "RIR \(Int($0))" }
                )
                }

                if showTempo {
                TextField("tempo_2", text: Binding(
                    get: { set.tempo ?? "" },
                    set: { set.tempo = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .font(.subheadline)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }

            if let previousRestSeconds = set.previousRestSeconds {
                Label("\(previousRestSeconds)s descanso real previo", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private func setTypeTitle(_ type: SetLog.SetType) -> String {
        switch type {
        case .warmUp: "Calentamiento"
        case .work: "Trabajo"
        case .topSet: "Top set"
        case .backOff: "Back-off"
        case .dropSet: "Dropset"
        case .restPause: "Rest-pause"
        case .activation: "Activacion"
        case .failure: "Fallo"
        }
    }
}


struct InlineStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String

    var body: some View {
        HStack(spacing: 3) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("bajar_valor")

            Text(formatter(value))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(minWidth: 36, maxWidth: .infinity)
                .frame(height: 36)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("subir_valor")
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: value)
    }
}

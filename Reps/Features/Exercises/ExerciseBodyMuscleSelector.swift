import MuscleMap
import SwiftUI

/// The two ways to narrow the exercise catalog down to a muscle: the existing
/// text-based dropdown, or tapping muscles directly on a gendered body model.
enum MuscleFilterMode: String, CaseIterable, Identifiable {
    case list
    case body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: localizedString("filter_by_list")
        case .body: localizedString("filter_by_body")
        }
    }

    var systemImage: String {
        switch self {
        case .list: "line.3.horizontal.decrease"
        case .body: "figure.arms.open"
        }
    }
}

/// A compact front+back tappable body silhouette used to filter the exercise
/// library by muscle. Mirrors `InteractiveBodyHeatmap` (Progress tab) in
/// layout/style but is selection-only — no load heatmap.
struct ExerciseBodyMuscleSelector: View {
    let gender: BodyGender
    @Binding var selectedSegments: Set<MuscleSegment>

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let bodyWidth = proxy.size.width * 0.62
                let bodyHeight = proxy.size.height * 0.92
                let visualScale = min(1.1, max(1.0, proxy.size.width / 390))

                ZStack {
                    bodyView(side: .back)
                        .frame(width: bodyWidth, height: bodyHeight)
                        .scaleEffect(visualScale, anchor: .center)
                        .offset(x: proxy.size.width * 0.17, y: 4)
                        .opacity(selectedSegments.isEmpty ? 0.88 : 0.72)
                        .zIndex(1)

                    bodyView(side: .front)
                        .frame(width: bodyWidth, height: bodyHeight)
                        .scaleEffect(visualScale, anchor: .center)
                        .offset(x: -proxy.size.width * 0.16, y: -2)
                        .zIndex(2)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
                .compositingGroup()
                .clipped()
            }
            .frame(height: 240)
            .accessibilityLabel(localizedString("tap_a_muscle_to_filter"))

            if selectedSegments.isEmpty {
                Text(localizedString("tap_a_muscle_to_filter"))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedSegments).sorted { $0.title < $1.title }) { segment in
                            SelectedSegmentChip(segment: segment) {
                                HapticService.selection()
                                selectedSegments.remove(segment)
                            }
                        }

                        Button {
                            HapticService.selection()
                            selectedSegments.removeAll()
                        } label: {
                            Text(localizedString("Clear"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bodyView(side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: .repsDark)
            .selected(selectedMuscles)
            .pulseSelected(speed: 1.35)
            .onMuscleSelected { muscle, _ in
                guard let segment = MuscleSegment.segment(containing: muscle) else { return }
                HapticService.selection()
                withAnimation(.snappy(duration: 0.22)) {
                    if selectedSegments.contains(segment) {
                        selectedSegments.remove(segment)
                    } else {
                        selectedSegments.insert(segment)
                    }
                }
            }
    }

    private var selectedMuscles: Set<Muscle> {
        Set(selectedSegments.flatMap(\.muscles))
    }
}

private struct SelectedSegmentChip: View {
    let segment: MuscleSegment
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 5) {
                Text(segment.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(PulseTheme.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

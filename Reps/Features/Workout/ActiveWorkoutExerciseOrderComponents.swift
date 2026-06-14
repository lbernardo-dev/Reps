import SwiftUI

struct ActiveExerciseOrderCard: View {
    let drafts: [ExerciseSessionDraft]
    let selectedExerciseIndex: Int
    let language: String
    let onAdd: () -> Void
    let onMove: (Int, Int) -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("exercise_order", systemImage: "arrow.up.arrow.down")
                        .font(.headline)
                    Spacer()
                    Button(action: onAdd) {
                        Label("add", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PulseTheme.primary)
                }

                if drafts.isEmpty {
                    Text("add_at_least_one_exercise_to_start_the_session")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(drafts.enumerated()), id: \.element.workoutExercise.id) { index, draft in
                            ActiveExerciseOrderRow(
                                index: index,
                                draft: draft,
                                isSelected: selectedExerciseIndex == index,
                                isFirst: index == 0,
                                isLast: index == drafts.count - 1,
                                language: language,
                                onMove: onMove
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ActiveExerciseOrderRow: View {
    let index: Int
    let draft: ExerciseSessionDraft
    let isSelected: Bool
    let isFirst: Bool
    let isLast: Bool
    let language: String
    let onMove: (Int, Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 26, height: 26)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(Circle())

            Text(RepsText.exerciseName(draft.workoutExercise.exercise.name, language: language))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            Button {
                onMove(index, index - 1)
            } label: {
                Image(systemName: "chevron.up")
                    .frame(width: 32, height: 32)
            }
            .disabled(isFirst)

            Button {
                onMove(index, index + 1)
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 32, height: 32)
            }
            .disabled(isLast)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(isSelected ? PulseTheme.accentMuted : PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

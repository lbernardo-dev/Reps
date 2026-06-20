import SwiftUI

struct ActiveExerciseOrderCard: View {
    let drafts: [ExerciseSessionDraft]
    let selectedExerciseIndex: Int
    let language: String
    let onAdd: () -> Void
    let onMove: (Int, Int) -> Void
    let onToggleSuperset: (Int) -> Void

    /// Stable color per superset group, assigned by first appearance.
    private var groupColors: [UUID: Color] {
        let palette: [Color] = [.orange, .purple, .teal, .pink, .blue, .green]
        var map: [UUID: Color] = [:]
        for draft in drafts {
            guard let group = draft.workoutExercise.supersetGroup, map[group] == nil else { continue }
            map[group] = palette[map.count % palette.count]
        }
        return map
    }

    var body: some View {
        let colors = groupColors

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
                            let group = draft.workoutExercise.supersetGroup
                            let prevGroup = index > 0 ? drafts[index - 1].workoutExercise.supersetGroup : nil
                            let nextGroup = index < drafts.count - 1 ? drafts[index + 1].workoutExercise.supersetGroup : nil

                            ActiveExerciseOrderRow(
                                index: index,
                                draft: draft,
                                isSelected: selectedExerciseIndex == index,
                                isFirst: index == 0,
                                isLast: index == drafts.count - 1,
                                groupColor: group.flatMap { colors[$0] },
                                isFirstInGroup: group != nil && group != prevGroup,
                                isLinkedToNext: group != nil && group == nextGroup,
                                language: language,
                                onMove: onMove,
                                onToggleSuperset: onToggleSuperset
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    Text("superset_hint")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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
    let groupColor: Color?
    let isFirstInGroup: Bool
    let isLinkedToNext: Bool
    let language: String
    let onMove: (Int, Int) -> Void
    let onToggleSuperset: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let groupColor {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(groupColor)
                    .frame(width: 3, height: 28)
            }

            Text("\(index + 1)")
                .font(.caption.weight(.black).monospacedDigit())
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 26, height: 26)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(RepsText.exerciseName(draft.workoutExercise.exercise.name, language: language))
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if isFirstInGroup, let groupColor {
                    Text("superset_label")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(groupColor)
                        .textCase(.uppercase)
                }
            }

            Spacer()

            if !isLast {
                Button {
                    onToggleSuperset(index)
                } label: {
                    Image(systemName: isLinkedToNext ? "link.circle.fill" : "link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isLinkedToNext ? (groupColor ?? PulseTheme.accent) : PulseTheme.secondaryText)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel(Text(isLinkedToNext ? "superset_remove" : "superset_create"))
            }

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
        .frame(height: 48)
        .background(isSelected ? PulseTheme.accentMuted : PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

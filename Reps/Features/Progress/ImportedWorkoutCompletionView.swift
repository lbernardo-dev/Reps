import SwiftUI

/// Lightweight, standalone editor for filling in the sets/exercises of a
/// workout that was auto-imported from HealthKit with no strength data
/// (Apple's own Fitness app only records duration/calories/heart rate, never
/// sets/reps/weight). Unlike `ActiveWorkoutView`, this has no rest timer, no
/// GPS, no live-session state — it just patches a historical `WorkoutSession`.
struct ImportedWorkoutCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    let session: WorkoutSession

    @State private var exerciseLogs: [ExerciseLog]
    @State private var showExercisePicker = false

    init(session: WorkoutSession) {
        self.session = session
        _exerciseLogs = State(initialValue: session.exerciseLogs ?? [])
    }

    private var hasCompletableSets: Bool {
        exerciseLogs.contains { !$0.sets.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                explainerCard

                if exerciseLogs.isEmpty {
                    emptyState
                } else {
                    ForEach($exerciseLogs) { $log in
                        exerciseCard(log: $log)
                    }
                }

                addExerciseButton
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .screenBackground()
        .navigationTitle(localizedString("complete_workout_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(localizedString("save")) {
                    save()
                }
                .fontWeight(.bold)
                .disabled(!hasCompletableSets)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet(
                title: localizedString("add_exercise"),
                exercises: store.exercises,
                currentExercise: nil
            ) { exercise in
                exerciseLogs.append(
                    ExerciseLog(exercise: exercise, notes: "", sets: [makeSet(number: 1)])
                )
                showExercisePicker = false
            }
        }
    }

    private var explainerCard: some View {
        PulseCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "applewatch")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PulseTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("complete_workout_title"))
                        .font(.subheadline.weight(.bold))
                    Text(localizedString("complete_workout_explainer"))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell")
                .font(.title2)
                .foregroundStyle(PulseTheme.secondaryText)
            Text(localizedString("complete_workout_empty"))
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            Label(localizedString("add_exercise"), systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PulseTheme.accent.opacity(0.14))
                .foregroundStyle(PulseTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func exerciseCard(log: Binding<ExerciseLog>) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(log.wrappedValue.exercise.name)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Button {
                        exerciseLogs.removeAll { $0.id == log.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(log.sets) { $set in
                    SetRow(
                        set: $set,
                        trackingType: log.wrappedValue.exercise.trackingType,
                        onCompletionChanged: { _ in }
                    )
                }

                Button {
                    let nextNumber = (log.wrappedValue.sets.map(\.setNumber).max() ?? 0) + 1
                    let lastSet = log.wrappedValue.sets.last
                    log.wrappedValue.sets.append(makeSet(number: nextNumber, like: lastSet))
                } label: {
                    Label(localizedString("add_set"), systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private func makeSet(number: Int, like previous: SetLog? = nil) -> SetLog {
        SetLog(
            setNumber: number,
            weightKg: previous?.weightKg ?? 0,
            reps: previous?.reps ?? 0,
            completed: true
        )
    }

    private func save() {
        HapticService.notification(.success)
        store.completeImportedWorkout(sessionID: session.id, exerciseLogs: exerciseLogs)
        dismiss()
    }
}

/// CTA shown on a session's detail screen when it was imported from
/// HealthKit with no strength data — links into `ImportedWorkoutCompletionView`.
struct ImportedWorkoutCompletionBanner: View {
    let session: WorkoutSession

    var body: some View {
        NavigationLink {
            ImportedWorkoutCompletionView(session: session)
        } label: {
            PulseCard(backgroundColor: PulseTheme.accent.opacity(0.12)) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizedString("complete_workout_title"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(localizedString("complete_workout_banner_subtitle"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

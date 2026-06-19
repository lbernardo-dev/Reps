import SwiftUI

struct WorkoutLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var showCreate = false
    @State private var editingWorkout: WorkoutDay?

    var body: some View {
        StickyHeaderScaffold(
            title: localizedString("routines"),
            subtitle: localizedString("create_schedule_reuse"),
            backAction: {
                dismiss()
            },
            accessory: {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(PulseTheme.primary)
                        .clipShape(Circle())
                        .shadow(color: PulseTheme.primary.opacity(0.24), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("create_routine")
            }
        ) {
            if store.workoutTemplates.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "No hay rutinas",
                        message: "Crea rutinas con tus ejercicios, notas y material.",
                        systemImage: "list.clipboard"
                    )
                }
                .stickyHeaderTitle(localizedString("no_routines"))
            } else {
                ForEach(store.workoutTemplates) { workout in
                    PulseCard {
                        WorkoutTemplateRow(workout: workout) {
                            editingWorkout = workout
                        }
                    }
                    .stickyHeaderTitle(workout.title)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .mainTabBarHidden()
        .sheet(isPresented: $showCreate) {
            WorkoutEditorView(mode: .create)
        }
        .sheet(item: $editingWorkout) { workout in
            WorkoutEditorView(mode: .edit(workout))
        }
    }
}

private struct WorkoutTemplateRow: View {
    @Environment(AppStore.self) private var store
    let workout: WorkoutDay
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(workout.title)
                        .font(.title3.weight(.bold))
                    Text(localizedFormat("exercises_duration_format", workout.exercises.count, workout.durationMinutes))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Menu {
                    Button("editar") { onEdit() }
                    Button("add_to_active_plan") { store.addWorkoutToActivePlan(workout) }
                    Button("schedule") {
                        store.addScheduledWorkout(workout, date: .now)
                    }
                    Button("delete", role: .destructive) {
                        store.deleteWorkoutTemplate(workout)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .accessibilityLabel("routine_actions")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    Label("abrir", systemImage: "chevron.right")
                }
                .buttonStyle(WorkoutPillButtonStyle())

                Button {
                    store.addScheduledWorkout(workout, date: .now)
                } label: {
                    Label("schedule_today", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(WorkoutPillButtonStyle())
            }
        }
    }
}

private struct WorkoutPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(PulseTheme.primary)
            .background(PulseTheme.primary.opacity(configuration.isPressed ? 0.18 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

struct WorkoutEditorView: View {
    enum Mode: Identifiable {
        case create
        case edit(WorkoutDay)

        var id: UUID {
            switch self {
            case .create:
                UUID()
            case .edit(let workout):
                workout.id
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let mode: Mode

    @State private var title: String
    @State private var subtitle: String
    @State private var durationMinutes: Int
    @State private var exercises: [WorkoutExercise]
    @State private var showCustomExercise = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _title = State(initialValue: localizedString("new_routine"))
            _subtitle = State(initialValue: localizedString("strength_label"))
            _durationMinutes = State(initialValue: 45)
            _exercises = State(initialValue: [])
        case .edit(let workout):
            _title = State(initialValue: workout.title)
            _subtitle = State(initialValue: workout.subtitle)
            _durationMinutes = State(initialValue: workout.durationMinutes)
            _exercises = State(initialValue: workout.exercises)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("routine") {
                    TextField("name_2", text: $title)
                    TextField("enfoque", text: $subtitle)
                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 10...180, step: 5)
                }

                Section("exercises_3") {
                    if exercises.isEmpty {
                        Text("add_exercises_from_the_library_or_create_your_own")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(exercises.indices, id: \.self) { index in
                        WorkoutExerciseEditorRow(item: $exercises[index])
                    }
                    .onDelete { offsets in
                        exercises.remove(atOffsets: offsets)
                    }

                    Menu {
                        ForEach(store.exercises) { exercise in
                            Button(exercise.name) {
                                exercises.append(WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-"))
                            }
                        }
                    } label: {
                        Label("add_from_library", systemImage: "plus")
                    }

                    Button {
                        showCustomExercise = true
                    } label: {
                        Label("create_your_own_exercise", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $showCustomExercise) {
                AddCustomExerciseView()
            }
        }
    }

    private var modeTitle: String {
        switch mode {
        case .create: localizedString("create_routine")
        case .edit: localizedString("edit_routine")
        }
    }

    private func save() {
        let workoutID: UUID
        if case .edit(let workout) = mode {
            workoutID = workout.id
        } else {
            workoutID = UUID()
        }

        let workout = WorkoutDay(
            id: workoutID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
            durationMinutes: durationMinutes,
            exercises: exercises
        )

        switch mode {
        case .create:
            store.addWorkoutTemplate(workout)
        case .edit:
            store.updateWorkoutTemplate(workout)
        }
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }
}

private struct WorkoutExerciseEditorRow: View {
    @Binding var item: WorkoutExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.exercise.name)
                .font(.headline)
            Text("\(item.exercise.muscleGroup) · \(item.exercise.equipment)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper("\(item.targetSets) series", value: $item.targetSets, in: 1...10)
            TextField("rep_range_2", text: $item.repRange)
            TextField("marca_anterior", text: $item.previous)
        }
        .padding(.vertical, 4)
    }
}

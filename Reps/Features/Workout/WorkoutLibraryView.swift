import SwiftUI

struct WorkoutLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var showCreate = false
    @State private var editingWorkout: WorkoutDay?

    var body: some View {
        StickyHeaderScaffold(
            title: "Rutinas",
            subtitle: "Crea, programa y reutiliza",
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
                .accessibilityLabel("Crear rutina")
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
                .stickyHeaderTitle("Sin rutinas")
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
                    Text("\(workout.exercises.count) ejercicios · \(workout.durationMinutes) min")
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Menu {
                    Button("Editar") { onEdit() }
                    Button("Anadir al plan activo") { store.addWorkoutToActivePlan(workout) }
                    Button("Programar") {
                        store.addScheduledWorkout(workout, date: .now)
                    }
                    Button("Eliminar", role: .destructive) {
                        store.deleteWorkoutTemplate(workout)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .accessibilityLabel("Acciones de rutina")
            }

            HStack(spacing: 10) {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    Label("Abrir", systemImage: "chevron.right")
                }
                .buttonStyle(WorkoutPillButtonStyle())

                Button {
                    store.addScheduledWorkout(workout, date: .now)
                } label: {
                    Label("Programar hoy", systemImage: "calendar.badge.plus")
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
            _title = State(initialValue: "Nueva rutina")
            _subtitle = State(initialValue: "Fuerza")
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
                Section("Rutina") {
                    TextField("Nombre", text: $title)
                    TextField("Enfoque", text: $subtitle)
                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 10...180, step: 5)
                }

                Section("Ejercicios") {
                    if exercises.isEmpty {
                        Text("Anade ejercicios desde la biblioteca o crea uno propio.")
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
                        Label("Anadir desde biblioteca", systemImage: "plus")
                    }

                    Button {
                        showCustomExercise = true
                    } label: {
                        Label("Crear ejercicio propio", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle(modeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") { save() }
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
        case .create: "Crear rutina"
        case .edit: "Editar rutina"
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
            TextField("Rango de reps", text: $item.repRange)
            TextField("Marca anterior", text: $item.previous)
        }
        .padding(.vertical, 4)
    }
}

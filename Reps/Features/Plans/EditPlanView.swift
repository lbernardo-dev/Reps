import SwiftUI

private struct PlanExerciseBookmarkTarget: Identifiable {
    let dayIndex: Int
    let exerciseIndex: Int
    var id: String { "\(dayIndex)-\(exerciseIndex)" }
}

private struct PlanExerciseBookmarkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bookmarks: [ExerciseMediaBookmark]

    @State private var title = ""
    @State private var source: ExerciseMediaBookmark.Source = .youtube
    @State private var urlString = ""
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var durationMinutes = 0
    @State private var durationSeconds = 0
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise_markers") {
                    if bookmarks.isEmpty {
                        Text("save_technique_references_with_exact_minutes_for_this_exercise_within_the_plan")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(bookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(bookmark.title, systemImage: bookmarkIcon(bookmark.source))
                                    .font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    bookmarks.removeAll { $0.id == bookmark.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            Text(bookmark.urlString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 12) {
                                if let timestamp = bookmark.timestampSeconds {
                                    Text(localizedFormat("bookmark_time_format", timestamp / 60, timestamp % 60))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                if let duration = bookmark.playbackDurationSeconds {
                                    Text(localizedFormat("duration_minutes_seconds_format", duration / 60, duration % 60))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }

                Section("add") {
                    TextField("qualification", text: $title)
                    Picker("fuente", selection: $source) {
                        ForEach(ExerciseMediaBookmark.Source.allCases) { source in
                            Text(bookmarkSourceTitle(source)).tag(source)
                        }
                    }
                    TextField("url", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("video_start_point")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper(localizedFormat("min_minutes_format", minutes), value: $minutes, in: 0...240)
                    Stepper(localizedFormat("seg_seconds_format", seconds), value: $seconds, in: 0...59)

                    Text("playback_duration")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Stepper(localizedFormat("min_duration_format", durationMinutes), value: $durationMinutes, in: 0...60)
                    Stepper(localizedFormat("seg_duration_format", durationSeconds), value: $durationSeconds, in: 0...59)

                    TextField("nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Button {
                        add()
                    } label: {
                        Label("add_bookmark", systemImage: "bookmark.fill")
                    }
                    .disabled(!canAdd)
                }
            }
            .navigationTitle("marcadores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("listo_2") { dismiss() }
                }
            }
        }
    }

    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    private func add() {
        let totalDuration = durationMinutes * 60 + durationSeconds
        bookmarks.append(
            ExerciseMediaBookmark(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                timestampSeconds: minutes == 0 && seconds == 0 ? nil : minutes * 60 + seconds,
                playbackDurationSeconds: totalDuration > 0 ? totalDuration : nil,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
            )
        )
        title = ""
        urlString = ""
        minutes = 0
        seconds = 0
        durationMinutes = 0
        durationSeconds = 0
        note = ""
    }
}

private func bookmarkSourceTitle(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube: "YouTube"
    case .youtubeShorts: "YouTube Shorts"
    case .tiktok: "TikTok"
    case .instagram: "Instagram"
    case .other: localizedString("other_label")
    }
}

private func bookmarkIcon(_ source: ExerciseMediaBookmark.Source) -> String {
    switch source {
    case .youtube, .youtubeShorts: "play.rectangle.fill"
    case .tiktok: "music.note.tv"
    case .instagram: "camera.fill"
    case .other: "link"
    }
}

struct EditPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let plan: WorkoutPlan

    @State private var name: String
    @State private var location: UserProfile.TrainingLocation
    @State private var daysPerWeek: Int
    @State private var totalWeeks: Int
    @State private var currentWeek: Int
    @State private var days: [WorkoutDay]
    @State private var playlists: [PlanPlaylist]
    @State private var bookmarkTarget: PlanExerciseBookmarkTarget?
    @State private var showMusicConnector = false

    init(plan: WorkoutPlan) {
        self.plan = plan
        _name = State(initialValue: plan.name)
        _location = State(initialValue: plan.location)
        _daysPerWeek = State(initialValue: plan.daysPerWeek)
        _totalWeeks = State(initialValue: plan.totalWeeks)
        _currentWeek = State(initialValue: plan.currentWeek)
        _days = State(initialValue: plan.days)
        _playlists = State(initialValue: plan.playlists)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("basic_information") {
                    TextField("plan_name", text: $name)
                    Picker("training_environment", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("calendar_2") {
                    Stepper(value: $daysPerWeek, in: 1...7) {
                        Text(localizedFormat("days_per_week_format", daysPerWeek))
                    }
                    Stepper(localizedFormat("week_n_of_total_format", currentWeek, totalWeeks), value: $currentWeek, in: 1...max(totalWeeks, 1))
                    Stepper(value: $totalWeeks, in: max(currentWeek, 1)...24) {
                        Text(localizedFormat("total_weeks_format", totalWeeks))
                    }
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                ForEach(days.indices, id: \.self) { dayIndex in
                    Section(localizedFormat("training_day_format", dayIndex + 1)) {
                        TextField("qualification", text: Binding(
                            get: { days[dayIndex].title },
                            set: { days[dayIndex].title = $0 }
                        ))
                        TextField("caption", text: Binding(
                            get: { days[dayIndex].subtitle },
                            set: { days[dayIndex].subtitle = $0 }
                        ))
                        Stepper("\(days[dayIndex].durationMinutes) min", value: Binding(
                            get: { days[dayIndex].durationMinutes },
                            set: { days[dayIndex].durationMinutes = $0 }
                        ), in: 10...180, step: 5)
                        Stepper(localizedFormat("rest_between_exercises_format", days[dayIndex].restBetweenExercisesSeconds), value: Binding(
                            get: { days[dayIndex].restBetweenExercisesSeconds },
                            set: { days[dayIndex].restBetweenExercisesSeconds = $0 }
                        ), in: 0...600, step: 15)

                        ForEach(days[dayIndex].exercises.indices, id: \.self) { exerciseIndex in
                            exerciseRow(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                            .padding(14)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .listRowInsets(EditPlanLayout.cardRowInsets)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        VStack(spacing: 0) {
                            Menu {
                                ForEach(store.exercises) { exercise in
                                    Button(exercise.name) {
                                        days[dayIndex].exercises.append(WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90))
                                    }
                                }
                            } label: {
                                PlanEditorActionRow(title: "add_exercise_action", systemImage: "plus", color: PulseTheme.primary)
                            }
                            .buttonStyle(.plain)

                            Divider()
                                .padding(.leading, EditPlanLayout.actionDividerLeading)

                            Button(role: .destructive) {
                                days.remove(at: dayIndex)
                            } label: {
                                PlanEditorActionRow(title: "delete_day_action", systemImage: "trash", color: .red)
                            }
                            .buttonStyle(.plain)
                            .disabled(days.count == 1)
                        }
                        .padding(.horizontal, EditPlanLayout.cardPadding)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .listRowInsets(EditPlanLayout.cardRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Button {
                        days.append(WorkoutDay(title: localizedFormat("workout_number_format", days.count + 1), subtitle: localizedString("strength"), durationMinutes: 45, exercises: []))
                    } label: {
                        Label("add_day", systemImage: "plus")
                    }

                    Menu {
                        ForEach(store.workoutTemplates) { workout in
                            Button(workout.title) {
                                days.append(workout)
                            }
                        }
                    } label: {
                        Label("add_existing_routine", systemImage: "list.clipboard")
                    }
                }
            }
            .navigationTitle("edit_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $bookmarkTarget) { target in
                PlanExerciseBookmarkEditor(bookmarks: Binding(
                    get: {
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return []
                        }
                        return days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks
                    },
                    set: { newValue in
                        guard days.indices.contains(target.dayIndex),
                              days[target.dayIndex].exercises.indices.contains(target.exerciseIndex) else {
                            return
                        }
                        days[target.dayIndex].exercises[target.exerciseIndex].mediaBookmarks = newValue
                    }
                ))
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(dayIndex: Int, exerciseIndex: Int) -> some View {
        let ex = days[dayIndex].exercises[exerciseIndex]
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("\(ex.exercise.muscleGroup) · \(ex.exercise.equipment)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button(role: .destructive) {
                    days[dayIndex].exercises.remove(at: exerciseIndex)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    bookmarkTarget = PlanExerciseBookmarkTarget(dayIndex: dayIndex, exerciseIndex: exerciseIndex)
                } label: {
                    Label("\(ex.mediaBookmarks.count) marcadores", systemImage: "bookmark.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PulseTheme.primary.opacity(0.12))
                        .foregroundStyle(PulseTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 8) {
                CompactStepper(
                    title: "sets_label",
                    value: Binding(
                        get: { days[dayIndex].exercises[exerciseIndex].targetSets },
                        set: { days[dayIndex].exercises[exerciseIndex].targetSets = $0 }
                    ),
                    range: 1...10,
                    suffix: "",
                    step: 1
                )
                CompactStepper(
                    title: "rest_label",
                    value: Binding(
                        get: { days[dayIndex].exercises[exerciseIndex].restSeconds },
                        set: { days[dayIndex].exercises[exerciseIndex].restSeconds = $0 }
                    ),
                    range: 0...600,
                    suffix: "s",
                    step: 15
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text("reps_4")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField("8-12", text: Binding(
                        get: { days[dayIndex].exercises[exerciseIndex].repRange },
                        set: { days[dayIndex].exercises[exerciseIndex].repRange = $0 }
                    ))
                    .font(.headline.weight(.bold).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func save() {
        var updated = plan
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = location
        updated.daysPerWeek = daysPerWeek
        updated.currentWeek = min(currentWeek, totalWeeks)
        updated.totalWeeks = totalWeeks
        updated.days = days.isEmpty ? plan.days : days
        updated.playlists = playlists
        store.updatePlan(updated)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }
}

private enum EditPlanLayout {
    static let cardPadding: CGFloat = 14
    static let cardRowInsets = EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
    static let actionDividerLeading: CGFloat = 56
}

private struct PlanEditorActionRow: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.title2.weight(.medium))
                .frame(width: 38, height: 52)

            Text(localizedKey(title))
                .font(.headline.weight(.regular))

            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct LegacyCreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var workoutTitle = "Full body"
    @State private var selectedExerciseIDs = Set<Exercise.ID>()
    @State private var playlists: [PlanPlaylist] = []
    @State private var showMusicConnector = false

    var body: some View {
        NavigationStack {
            Form {
                Section("basic_information") {
                    TextField("plan_name", text: $planName)
                    Picker("training_environment", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                }

                Section("calendar_2") {
                    Stepper(value: $daysPerWeek, in: 1...7) {
                        Text(localizedFormat("days_per_week_format", daysPerWeek))
                    }
                    Stepper(value: $totalWeeks, in: 1...16) {
                        Text(localizedFormat("total_weeks_format", totalWeeks))
                    }
                    Toggle("activate_on_save", isOn: $activateImmediately)
                }

                PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)

                Section("training_2") {
                    TextField("training_title", text: $workoutTitle)
                    ForEach(store.exercises) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedExerciseIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedExerciseIDs.contains(exercise.id) ? PulseTheme.primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("vista_previa") {
                    PlanPreviewDay(title: localizedString("workout_a_title"), workout: workoutTitle.isEmpty ? localizedString("full_body") : workoutTitle, exercises: selectedExerciseIDs.count)
                    Text(localizedFormat("reps_will_create_editable_days_from_template_format", daysPerWeek))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("create_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        save()
                    }
                    .disabled(planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedExerciseIDs.contains(exercise.id) {
            selectedExerciseIDs.remove(exercise.id)
        } else {
            selectedExerciseIDs.insert(exercise.id)
        }
    }

    private func save() {
        let trimmedName = planName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedExercises = store.exercises.filter { selectedExerciseIDs.contains($0.id) }
        let workoutExercises = (selectedExercises.isEmpty ? Array(store.exercises.prefix(4)) : selectedExercises).map {
            WorkoutExercise(exercise: $0, targetSets: 3, repRange: defaultRepRange(for: $0), previous: "-")
        }
        let baseTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedString("full_body") : workoutTitle
        let days = (1...daysPerWeek).map { index in
            WorkoutDay(
                title: daysPerWeek == 1 ? baseTitle : "\(baseTitle) \(index)",
                subtitle: location == .home ? localizedString("home_training") : localizedString("strength"),
                durationMinutes: max(35, workoutExercises.count * 10),
                exercises: workoutExercises
            )
        }
        let plan = WorkoutPlan(
            name: trimmedName,
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: days,
            playlists: playlists
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "AMRAP"
        case .duration: "30-60 sec"
        }
    }

    private func locationPickerTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: localizedString("gym")
        case .home: localizedString("home")
        case .both: localizedString("home_and_gym")
        }
    }
}

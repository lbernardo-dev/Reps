import SwiftUI

private enum PlanWizardStep: Int, CaseIterable, Identifiable {
    case basics
    case schedule
    case sessions
    case musicReview

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .basics: localizedString("plan_basics")
        case .schedule: localizedString("distribution_schedule")
        case .sessions: localizedString("sessions_setup")
        case .musicReview: localizedString("music_and_review")
        }
    }

    var subtitle: String {
        switch self {
        case .basics: localizedString("plan_basics_description")
        case .schedule: localizedString("plan_schedule_description")
        case .sessions: localizedString("plan_sessions_description")
        case .musicReview: localizedString("plan_music_description")
        }
    }
}

private enum PlanScheduleMode: String, CaseIterable, Identifiable {
    case cycle
    case weekdays

    var id: String { rawValue }
    var title: String { self == .cycle ? localizedString("cycle_plan") : localizedString("weekdays_plan") }
    var description: String {
        self == .cycle
        ? localizedString("cycle_schedule_description")
        : localizedString("fixed_schedule_description")
    }
}

private struct PlanExercisePickerTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var step: PlanWizardStep = .basics
    @State private var planName = ""
    @State private var location: UserProfile.TrainingLocation = .gym
    @State private var daysPerWeek = 4
    @State private var totalWeeks = 8
    @State private var activateImmediately = true
    @State private var scheduleMode: PlanScheduleMode = .cycle
    @State private var selectedWeekdays: Set<Int> = [1, 3, 5, 6]
    @State private var days: [WorkoutDay] = [
        WorkoutDay(title: localizedString("workout_day_a"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: []),
        WorkoutDay(title: localizedString("workout_day_b"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: [])
    ]
    @State private var playlists: [PlanPlaylist] = []
    @State private var pickerTargetDay: Int?
    @State private var showMusicConnector = false
    @State private var hasTargetEvent = false
    @State private var targetEventName = ""
    @State private var targetEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                wizardHeader
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case .basics:
                            basicsStep
                        case .schedule:
                            scheduleStep
                        case .sessions:
                            sessionsStep
                        case .musicReview:
                            musicReviewStep
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    .padding(.vertical, 20)
                    .padding(.bottom, 96)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .screenBackground()
            }
            .navigationTitle("create_plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { previousStep() } label: {
                        Label("back_2", systemImage: "chevron.left")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.textPrimary)
                            .navigationGlassCapsule(step == .basics ? .disabled : .secondary)
                    }
                    .disabled(step == .basics)
                    .opacity(step == .basics ? 0.45 : 1)

                    Button { nextOrSave() } label: {
                        Label(step == .musicReview ? "save" : "next", systemImage: step == .musicReview ? "checkmark" : "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.textPrimary)
                            .navigationGlassCapsule(canContinue ? .primary : .disabled)
                    }
                    .disabled(!canContinue)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
                .background(.ultraThinMaterial)
            }
            .sheet(item: pickerBinding) { target in
                PlanExercisePickerSheet(exercises: store.exercises) { exercise in
                    addExercise(exercise, to: target.index)
                    pickerTargetDay = nil
                }
            }
            .sheet(isPresented: $showMusicConnector) {
                MusicIntegrationSheet { selectedPlaylist in
                    playlists.append(selectedPlaylist)
                }
            }
        }
    }

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(PlanWizardStep.allCases) { wizardStep in
                    Capsule()
                        .fill(wizardStep.rawValue <= step.rawValue ? PulseTheme.accent : PulseTheme.secondaryText.opacity(0.18))
                        .frame(height: 6)
                }
            }
            Text(step.title).font(.title2.bold())
            Text(step.subtitle)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.vertical, 14)
        .background(PulseTheme.background)
    }

    private var basicsStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle("plan_identity")
                    TextField("plan_name", text: $planName)
                        .textFieldStyle(.roundedBorder)
                    Picker("environment_2", selection: $location) {
                        ForEach(UserProfile.TrainingLocation.allCases) { location in
                            Text(locationPickerTitle(location)).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("activate_on_save", isOn: $activateImmediately)
                }
            }

            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $hasTargetEvent) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(PulseTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("do_you_have_a_target_event")
                                    .font(.headline)
                                Text("adapt_duration_according_to_deadline")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                    }

                    if hasTargetEvent {
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("event_name")
                                .font(.caption.bold())
                                .foregroundStyle(PulseTheme.secondaryText)
                            TextField("ex_wedding_vacation_marathon", text: $targetEventName)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "event_date",
                                selection: $targetEventDate,
                                in: Date.now...,
                                displayedComponents: .date
                            )
                            .font(.subheadline.weight(.semibold))

                            if let advice = targetEventAdvice {
                                Text(advice.text)
                                    .font(.caption)
                                    .foregroundStyle(advice.color)
                                    .padding(10)
                                    .background(advice.color.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .padding(.top, 4)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }

            HStack(spacing: 12) {
                WizardMetricStepper(title: "days_per_week_short", value: $daysPerWeek, range: 1...7)
                WizardMetricStepper(title: "weeks", value: $totalWeeks, range: 1...24)
            }
        }
        .onChange(of: targetEventDate) { _, _ in
            updateWeeksFromEventDate()
        }
        .onChange(of: hasTargetEvent) { _, active in
            if active {
                updateWeeksFromEventDate()
            } else {
                totalWeeks = 8
            }
        }
        .onChange(of: targetEventName) { _, newName in
            if !newName.isEmpty && planName.isEmpty {
                planName = localizedFormat("plan_for_name_format", newName)
            }
        }
    }

    private var scheduleStep: some View {
        VStack(spacing: 16) {
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    CardTitle("distribution")
                    Picker("modo", selection: $scheduleMode) {
                        ForEach(PlanScheduleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(scheduleMode.description)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }

            if scheduleMode == .weekdays {
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CardTitle("fixed_days")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                Button { toggleWeekday(day) } label: {
                                    Text(weekdayTitle(day))
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .foregroundStyle(selectedWeekdays.contains(day) ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.accent)
                                        .background(selectedWeekdays.contains(day) ? PulseTheme.accent : PulseTheme.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sessionsStep: some View {
        VStack(spacing: 16) {
            ForEach(days.indices, id: \.self) { index in
                SessionBuilderCard(day: $days[index], index: index) {
                    pickerTargetDay = index
                }
            }

            if !sessionsAreReady {
                Label("add_a_title_and_at_least_one_exercise_to_each_session_to_save_a_startable_plan", systemImage: "exclamationmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulseTheme.warning)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PulseTheme.warning.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button { addDay() } label: {
                Label("add_session", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(PulseTheme.accent)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                            .stroke(PulseTheme.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
            }
        }
    }

    private var sessionsAreReady: Bool {
        !days.isEmpty
            && days.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.exercises.isEmpty
            }
    }

    private var musicReviewStep: some View {
        VStack(spacing: 16) {
            PlanPlaylistEditor(playlists: $playlists, showMusicConnector: $showMusicConnector)
            PulseCard {
                VStack(alignment: .leading, spacing: 12) {
                    CardTitle("resumen")
                    PlanPreviewDay(title: planName.isEmpty ? localizedString("unnamed_plan") : planName, workout: localizedFormat("sessions_days_format", days.count, daysPerWeek), exercises: days.reduce(0) { $0 + $1.exercises.count })
                    ForEach(days) { day in
                        HStack {
                            Label(day.title, systemImage: sessionTypeIcon(day.sessionType))
                            Spacer()
                            Text(localizedFormat("exercises_count_format", day.exercises.count))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case .basics:
            !planName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .schedule:
            scheduleMode == .cycle || !selectedWeekdays.isEmpty
        case .sessions:
            sessionsAreReady
        case .musicReview:
            true
        }
    }

    private var pickerBinding: Binding<PlanExercisePickerTarget?> {
        Binding(
            get: { pickerTargetDay.map(PlanExercisePickerTarget.init(index:)) },
            set: { pickerTargetDay = $0?.index }
        )
    }

    private func nextOrSave() {
        if step == .musicReview {
            save()
        } else {
            step = PlanWizardStep(rawValue: step.rawValue + 1) ?? .musicReview
        }
    }

    private func previousStep() {
        step = PlanWizardStep(rawValue: max(step.rawValue - 1, 0)) ?? .basics
    }

    private func addDay() {
        let letter = Character(UnicodeScalar(65 + min(days.count, 25))!)
        days.append(WorkoutDay(title: localizedFormat("day_letter_format", String(letter)), subtitle: localizedString("strength_label"), durationMinutes: 45, exercises: []))
    }

    private func addExercise(_ exercise: Exercise, to dayIndex: Int) {
        guard days.indices.contains(dayIndex) else { return }
        days[dayIndex].exercises.append(
            WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-", restSeconds: 90)
        )
        if days[dayIndex].sessionType == .cardioRun || days[dayIndex].sessionType == .cardioWalk {
            days[dayIndex].sessionType = .mixedRoute
        }
    }

    private func save() {
        let preparedDays = days.enumerated().map { offset, day in
            var copy = day
            if copy.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.title = localizedFormat("session_number_format", offset + 1)
            }
            if copy.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.subtitle = sessionTypeTitle(copy.sessionType)
            }
            return copy
        }
        let plan = WorkoutPlan(
            name: planName.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location,
            daysPerWeek: daysPerWeek,
            currentWeek: 1,
            totalWeeks: totalWeeks,
            completion: 0,
            days: preparedDays,
            playlists: playlists,
            targetEventName: hasTargetEvent ? (targetEventName.isEmpty ? localizedString("event_default") : targetEventName) : nil,
            targetEventDate: hasTargetEvent ? targetEventDate : nil
        )
        store.addPlan(plan, activate: activateImmediately)
        dismiss()
    }

    private func toggleWeekday(_ day: Int) {
        if selectedWeekdays.contains(day) {
            selectedWeekdays.remove(day)
        } else {
            selectedWeekdays.insert(day)
        }
    }

    private func weekdayTitle(_ day: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let calendarIndex = day % 7
        return symbols[max(0, min(calendarIndex, symbols.count - 1))].uppercased()
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

    private struct EventAdvice {
        let text: String
        let color: Color
        let weeks: Int
    }

    private var targetEventAdvice: EventAdvice? {
        guard hasTargetEvent else { return nil }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        let weeks = max(1, days / 7)

        if weeks < 6 {
            return EventAdvice(
                text: localizedFormat("short_duration_warning_format", weeks, weeks),
                color: PulseTheme.warning,
                weeks: weeks
            )
        } else if weeks <= 12 {
            return EventAdvice(
                text: localizedFormat("optimal_duration_format", weeks, weeks),
                color: PulseTheme.ringStand,
                weeks: weeks
            )
        } else {
            return EventAdvice(
                text: localizedFormat("long_duration_warning_format", weeks, weeks - 8),
                color: PulseTheme.accent,
                weeks: weeks
            )
        }
    }

    private func updateWeeksFromEventDate() {
        guard hasTargetEvent else { return }
        let days = Calendar.current.dateComponents([.day], from: .now, to: targetEventDate).day ?? 0
        if days > 0 {
            totalWeeks = max(3, min(24, days / 7))
        }
    }
}

private struct WizardMetricStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizedKey(title))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                HStack {
                    Text("\(value)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accent)
                    Spacer()
                    Stepper(title, value: $value, in: range)
                        .labelsHidden()
                }
            }
        }
    }
}

private struct SessionBuilderCard: View {
    @Binding var day: WorkoutDay
    let index: Int
    let onAddExercise: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(localizedFormat("session_number_format", index + 1), systemImage: sessionTypeIcon(day.sessionType))
                        .font(.headline)
                    Spacer()
                    Text(localizedFormat("exercise_count_format", day.exercises.count))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                TextField("qualification", text: $day.title)
                    .textFieldStyle(.roundedBorder)
                TextField("caption", text: $day.subtitle)
                    .textFieldStyle(.roundedBorder)

                Picker("training_type", selection: $day.sessionType) {
                    ForEach(WorkoutDay.SessionType.allCases) { type in
                        Text(sessionTypeTitle(type)).tag(type)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    CompactStepper(title: "duration_label", value: $day.durationMinutes, range: 10...240, suffix: "min", step: 5)
                }
                NumericSecondsField(title: "between_exercises", seconds: $day.restBetweenExercisesSeconds)

                if day.sessionType == .cardioRun || day.sessionType == .cardioWalk || day.sessionType == .mixedRoute {
                    Label("this_session_will_show_gps_route_and_map_during_training", systemImage: "map.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(day.exercises.indices, id: \.self) { exerciseIndex in
                    EditableWorkoutExerciseRow(item: $day.exercises[exerciseIndex]) {
                        day.exercises.remove(at: exerciseIndex)
                    }
                }

                Button(action: onAddExercise) {
                    Label("add_from_visual_catalog", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }
}

private struct EditableWorkoutExerciseRow: View {
    @Binding var item: WorkoutExercise
    let onDelete: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ExerciseMediaThumbnail(exercise: item.exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.exercise.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(item.exercise.muscleGroup) · \(item.exercise.equipment)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .destructiveGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("delete_exercise_format", item.exercise.name))
            }

            HStack(spacing: 8) {
                ExerciseMetricTile(
                    label: "Series",
                    value: "\(item.targetSets)",
                    onDecrement: { item.targetSets = max(1, item.targetSets - 1) },
                    onIncrement: { item.targetSets = min(10, item.targetSets + 1) }
                )

                ExerciseMetricTile(
                    label: "Descanso",
                    value: "\(item.restSeconds)s",
                    onDecrement: { item.restSeconds = max(0, item.restSeconds - 15) },
                    onIncrement: { item.restSeconds = min(600, item.restSeconds + 15) }
                )

                VStack(spacing: 4) {
                    Text("reps_4")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)

                    TextField("8-12", text: $item.repRange)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PulseTheme.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .keyboardType(.default)
                        .accessibilityLabel("rep_range")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ExerciseMetricTile: View {
    let label: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(localizedKey(label))
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            HStack(spacing: 4) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("decrease_label", label))

                Text(value)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(PulseTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 44)
                        .foregroundStyle(PulseTheme.accent)
                        .background(PulseTheme.accent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedFormat("increase_label", label))
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct PlanExercisePickerSheet: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var searchText = ""
    @State private var selectedMuscle = "Todos"
    @State private var selectedEquipment = "Todos"
    @State private var selectedType: Exercise.ExerciseType?
    @State private var selectedDifficulty: Exercise.Difficulty?
    @State private var selectedEnvironment: Exercise.Environment?
    @State private var onlyAvailableEquipment = false

    private var muscles: [String] {
        ["Todos"] + Array(Set(exercises.map(\.muscleGroup))).sorted()
    }

    private var equipment: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filtered: [Exercise] {
        exercises.filter { exercise in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchableText = [
                exercise.name,
                exercise.aliases.joined(separator: " "),
                exercise.muscleGroup,
                exercise.secondaryMuscles.joined(separator: " "),
                exercise.equipment,
                exercise.requiredEquipment.joined(separator: " "),
                exercise.tags.joined(separator: " "),
                exercise.instructions ?? ""
            ].joined(separator: " ")
            let matchesQuery = query.isEmpty || searchableText.localizedCaseInsensitiveContains(query)
            let matchesMuscle = selectedMuscle == "Todos" || exercise.muscleGroup == selectedMuscle
            let matchesEquipment = selectedEquipment == "Todos" || exercise.equipment == selectedEquipment
            let matchesType = selectedType == nil || exercise.exerciseType == selectedType
            let matchesDifficulty = selectedDifficulty == nil || exercise.difficulty == selectedDifficulty
            let matchesEnvironment = selectedEnvironment == nil || exercise.environment == selectedEnvironment || exercise.environment == .both
            let matchesAvailableEquipment = !onlyAvailableEquipment || availableEquipmentMatches(exercise)
            return matchesQuery && matchesMuscle && matchesEquipment && matchesType && matchesDifficulty && matchesEnvironment && matchesAvailableEquipment
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("search_by_name_muscle_or_team", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("muscle", selection: $selectedMuscle) {
                                ForEach(muscles, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            Picker("equipo", selection: $selectedEquipment) {
                                ForEach(equipment, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("training_type", selection: $selectedType) {
                                Text("all").tag(Optional<Exercise.ExerciseType>.none)
                                ForEach(Exercise.ExerciseType.allCases) { type in
                                    Text(type.planPickerTitle).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("difficulty_2", selection: $selectedDifficulty) {
                                Text("any").tag(Optional<Exercise.Difficulty>.none)
                                ForEach(Exercise.Difficulty.allCases) { difficulty in
                                    Text(difficulty.planPickerTitle).tag(Optional(difficulty))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("environment_2", selection: $selectedEnvironment) {
                                Text("any").tag(Optional<Exercise.Environment>.none)
                                ForEach(Exercise.Environment.allCases) { environment in
                                    Text(environment.planPickerTitle).tag(Optional(environment))
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("mi_equipo", isOn: $onlyAvailableEquipment)
                                .toggleStyle(.button)
                        }
                        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    }
                    .font(.subheadline.weight(.semibold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filtered) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                                        .frame(height: 118)
                                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text("\(exercise.muscleGroup) · \(exercise.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .background(PulseTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                }
                .padding(.vertical, 20)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle("choose_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") { dismiss() }
                }
            }
        }
    }

    private func availableEquipmentMatches(_ exercise: Exercise) -> Bool {
        let equipment = Set(store.userProfile.availableEquipment.map(normalized))
        guard !equipment.isEmpty else { return true }

        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(normalized))
        return normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: equipment)
            || equipment.contains(normalized(exercise.equipment))
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private extension Exercise.ExerciseType {
    var planPickerTitle: String {
        switch self {
        case .strength: localizedString("strength")
        case .cardio: localizedString("cardio")
        case .mobility: localizedString("mobility")
        case .stretching: localizedString("stretching")
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    var planPickerTitle: String {
        switch self {
        case .low: localizedString("beginner")
        case .medium: localizedString("intermediate")
        case .high: localizedString("advanced")
        }
    }
}

private extension Exercise.Environment {
    var planPickerTitle: String {
        switch self {
        case .home: localizedString("home")
        case .gym: localizedString("gym")
        case .both: localizedString("home_gym_label")
        }
    }
}

private func sessionTypeTitle(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: localizedString("strength")
    case .cardioRun: localizedString("cardio_run")
    case .cardioWalk: localizedString("cardio_walk")
    case .mixedRoute: localizedString("mixed_route")
    case .mobility: localizedString("mobility")
    case .free: localizedString("free_session")
    }
}

private func sessionTypeIcon(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: "dumbbell.fill"
    case .cardioRun: "figure.run"
    case .cardioWalk: "figure.walk"
    case .mixedRoute: "map.fill"
    case .mobility: "figure.flexibility"
    case .free: "sparkles"
    }
}

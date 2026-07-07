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

private struct PlanExerciseBookmarkTarget: Identifiable {
    let dayIndex: Int
    let exerciseIndex: Int
    var id: String { "\(dayIndex)-\(exerciseIndex)" }
}

/// Canonical editor for creating a new plan or editing an existing one.
/// `existingPlan == nil` drives the full wizard (smart defaults, lands on
/// the basics step); passing a plan prefills every step from it and lands
/// directly on the sessions step for a quick edit, while still allowing
/// back-navigation into every other step.
struct CreatePlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let existingPlan: WorkoutPlan?

    @State private var step: PlanWizardStep
    @State private var planName: String
    @State private var location: UserProfile.TrainingLocation
    @State private var daysPerWeek: Int
    @State private var totalWeeks: Int
    @State private var currentWeek: Int
    @State private var activateImmediately = true
    @State private var scheduleMode: PlanScheduleMode = .cycle
    @State private var selectedWeekdays: Set<Int> = [1, 3, 5, 6]
    @State private var days: [WorkoutDay]
    @State private var playlists: [PlanPlaylist]
    @State private var pickerTargetDay: Int?
    @State private var bookmarkTarget: PlanExerciseBookmarkTarget?
    @State private var showMusicConnector = false
    @State private var hasTargetEvent: Bool
    @State private var targetEventName: String
    @State private var targetEventDate: Date

    private var isEditing: Bool { existingPlan != nil }

    init(existingPlan: WorkoutPlan? = nil) {
        self.existingPlan = existingPlan
        let defaultEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now

        if let plan = existingPlan {
            _step = State(initialValue: .sessions)
            _planName = State(initialValue: plan.name)
            _location = State(initialValue: plan.location)
            _daysPerWeek = State(initialValue: plan.daysPerWeek)
            _totalWeeks = State(initialValue: plan.totalWeeks)
            _currentWeek = State(initialValue: plan.currentWeek)
            _days = State(initialValue: plan.days)
            _playlists = State(initialValue: plan.playlists)
            _hasTargetEvent = State(initialValue: plan.targetEventName != nil)
            _targetEventName = State(initialValue: plan.targetEventName ?? "")
            _targetEventDate = State(initialValue: plan.targetEventDate ?? defaultEventDate)
        } else {
            _step = State(initialValue: .basics)
            _planName = State(initialValue: localizedString("plan_name_default"))
            _location = State(initialValue: .gym)
            _daysPerWeek = State(initialValue: 4)
            _totalWeeks = State(initialValue: 8)
            _currentWeek = State(initialValue: 1)
            _days = State(initialValue: [
                WorkoutDay(title: localizedString("workout_day_a"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: []),
                WorkoutDay(title: localizedString("workout_day_b"), subtitle: localizedString("strength"), durationMinutes: 45, exercises: [])
            ])
            _playlists = State(initialValue: [])
            _hasTargetEvent = State(initialValue: false)
            _targetEventName = State(initialValue: "")
            _targetEventDate = State(initialValue: defaultEventDate)
        }
    }

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
            .navigationTitle(isEditing ? "edit_plan" : "create_plan")
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
                        Label(step == .musicReview ? "plan_save_cta" : "continue_plan", systemImage: step == .musicReview ? "checkmark" : "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.textPrimary)
                            .navigationGlassCapsule(canContinue ? .primary : .disabled)
                    }
                    .disabled(!canContinue)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .sheet(item: pickerBinding) { target in
                ExercisePickerSheet(title: localizedString("choose_exercise"), exercises: store.exercises, currentExercise: nil) { exercise in
                    addExercise(exercise, to: target.index)
                    pickerTargetDay = nil
                }
            }
            .sheet(item: $bookmarkTarget) { target in
                ExerciseMediaBookmarkEditor(bookmarks: Binding(
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
            Label(progressHintText, systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.vertical, 14)
        .background(PulseTheme.background)
    }

    private var progressHintText: LocalizedStringKey {
        LocalizedStringKey(localizedFormat("plan_progress_seeded_format", step.rawValue + 1, PlanWizardStep.allCases.count))
    }

    private var basicsStep: some View {
        VStack(spacing: 16) {
            if !isEditing {
                PulseCard(backgroundColor: PulseTheme.accent.opacity(0.10)) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("plan_smart_defaults_title")
                                .font(.headline)
                            Text("plan_smart_defaults_body")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(PulseTheme.accent)
                    }
                }
            }

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
                    if !isEditing {
                        Toggle("activate_on_save", isOn: $activateImmediately)
                        Text("activate_on_save_loss_hint")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

            if isEditing {
                WizardMetricStepper(title: "week_label", value: $currentWeek, range: 1...max(totalWeeks, 1))
            }
        }
        .onChange(of: targetEventDate) { _, _ in
            updateWeeksFromEventDate()
        }
        .onChange(of: hasTargetEvent) { _, active in
            if active {
                updateWeeksFromEventDate()
            } else if !isEditing {
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
                SessionBuilderCard(
                    day: $days[index],
                    index: index,
                    canDelete: days.count > 1,
                    onAddExercise: { pickerTargetDay = index },
                    onOpenBookmarks: { exerciseIndex in
                        bookmarkTarget = PlanExerciseBookmarkTarget(dayIndex: index, exerciseIndex: exerciseIndex)
                    },
                    onDeleteDay: { days.remove(at: index) }
                )
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

            HStack(spacing: 12) {
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

                if !store.workoutTemplates.isEmpty {
                    Menu {
                        ForEach(store.workoutTemplates) { workout in
                            Button(workout.title) {
                                days.append(workout)
                            }
                        }
                    } label: {
                        Label("add_existing_routine", systemImage: "list.clipboard")
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

        if let existingPlan {
            var updated = existingPlan
            updated.name = planName.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.location = location
            updated.daysPerWeek = daysPerWeek
            updated.currentWeek = min(currentWeek, totalWeeks)
            updated.totalWeeks = totalWeeks
            updated.days = preparedDays.isEmpty ? existingPlan.days : preparedDays
            updated.playlists = playlists
            updated.targetEventName = hasTargetEvent ? (targetEventName.isEmpty ? localizedString("event_default") : targetEventName) : nil
            updated.targetEventDate = hasTargetEvent ? targetEventDate : nil
            store.updatePlan(updated)
        } else {
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
        }
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

private struct ExerciseRowContext: Identifiable {
    let id: UUID
    let index: Int
    let groupColor: Color?
    let isFirstInGroup: Bool
    let isLinkedToNext: Bool
    let isLastInDay: Bool
}

private struct SessionBuilderCard: View {
    @Binding var day: WorkoutDay
    let index: Int
    let canDelete: Bool
    let onAddExercise: () -> Void
    let onOpenBookmarks: (Int) -> Void
    let onDeleteDay: () -> Void

    /// Stable color per superset group, assigned by first appearance —
    /// mirrors ActiveExerciseOrderCard.groupColors so linked exercises read
    /// the same way during planning as they do during a live session.
    private var groupColors: [UUID: Color] {
        let palette: [Color] = [.orange, .purple, .teal, .pink, .blue, .green]
        var map: [UUID: Color] = [:]
        for exercise in day.exercises {
            guard let group = exercise.supersetGroup, map[group] == nil else { continue }
            map[group] = palette[map.count % palette.count]
        }
        return map
    }

    private var exerciseRowContexts: [ExerciseRowContext] {
        let colors = groupColors
        return day.exercises.indices.map { index in
            let group = day.exercises[index].supersetGroup
            let prevGroup = index > 0 ? day.exercises[index - 1].supersetGroup : nil
            let nextGroup = index < day.exercises.count - 1 ? day.exercises[index + 1].supersetGroup : nil
            return ExerciseRowContext(
                id: day.exercises[index].id,
                index: index,
                groupColor: group.flatMap { colors[$0] },
                isFirstInGroup: group != nil && group != prevGroup,
                isLinkedToNext: group != nil && group == nextGroup,
                isLastInDay: index == day.exercises.count - 1
            )
        }
    }

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
                    if canDelete {
                        Button(role: .destructive, action: onDeleteDay) {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.textPrimary)
                                .frame(width: 28, height: 28)
                                .destructiveGlassCircle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizedString("delete_day_action"))
                    }
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

                ForEach(exerciseRowContexts) { context in
                    EditableWorkoutExerciseRow(
                        item: $day.exercises[context.index],
                        groupColor: context.groupColor,
                        isFirstInGroup: context.isFirstInGroup,
                        isLinkedToNext: context.isLinkedToNext,
                        isLastInDay: context.isLastInDay,
                        onToggleSuperset: {
                            WorkoutDraftController.toggleSupersetLink(at: context.index, in: &day.exercises, supersetGroup: \WorkoutExercise.supersetGroup)
                        },
                        onOpenBookmarks: { onOpenBookmarks(context.index) },
                        onDelete: {
                            day.exercises.remove(at: context.index)
                        }
                    )
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
    let groupColor: Color?
    let isFirstInGroup: Bool
    let isLinkedToNext: Bool
    let isLastInDay: Bool
    let onToggleSuperset: () -> Void
    let onOpenBookmarks: () -> Void
    let onDelete: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let groupColor {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(groupColor)
                        .frame(width: 3, height: 44)
                }

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
                    if isFirstInGroup, let groupColor {
                        Text("superset_label")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(groupColor)
                            .textCase(.uppercase)
                    }
                }

                Spacer()

                if !isLastInDay {
                    Button(action: onToggleSuperset) {
                        Image(systemName: isLinkedToNext ? "link.circle.fill" : "link")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isLinkedToNext ? (groupColor ?? PulseTheme.accent) : PulseTheme.secondaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(isLinkedToNext ? "superset_remove" : "superset_create"))
                }

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

            Button(action: onOpenBookmarks) {
                Label(localizedFormat("bookmarks_count_format", item.mediaBookmarks.count), systemImage: "bookmark.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PulseTheme.accent.opacity(0.12))
                    .foregroundStyle(PulseTheme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

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

private func sessionTypeTitle(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: localizedString("strength")
    case .cardioRun: localizedString("cardio_run")
    case .cardioWalk: localizedString("cardio_walk")
    case .mixedRoute: localizedString("mixed_route")
    case .mobility: localizedString("mobility")
    case .free: localizedString("free_session")
    case .core: localizedString("core_training")
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
    case .core: "figure.core.training"
    }
}

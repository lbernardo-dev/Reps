import MuscleMap
import SwiftUI

struct CalendarView: View {
    @Environment(AppStore.self) private var store
    @State private var showSchedule = false
    @State private var visibleMonth = Date()
    @State private var selectedDate = Date()
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            StickyHeaderScaffold(
                title: "calendar_2",
                subtitle: "plan_and_review_load",
                accessory: {
                    HeaderAvatarButton(
                        imageData: store.userProfile.avatarImageData,
                        accessibilityLabel: "profile"
                    ) {
                        showProfile = true
                    }
                }
            ) {
                    calendarCommandCard
                        .stickyHeaderTitle(localizedString("this_week"))

                    HStack {
                        Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(formattedMonth(visibleMonth))
                            .font(.title.bold())
                        Spacer()
                        Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                    }
                    .foregroundStyle(PulseTheme.primary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                        let weekdays = store.userProfile.preferredLanguage.hasPrefix("es")
                            ? ["L", "M", "X", "J", "V", "S", "D"]
                            : ["M", "T", "W", "T", "F", "S", "S"]
                        ForEach(weekdays.indices, id: \.self) { index in
                            Text(weekdays[index])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }

                        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                            if let day {
                                let hasWorkout = !loggedWorkouts(on: day).isEmpty
                                let hasScheduled = !scheduledWorkouts(on: day).isEmpty
                                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                                Button {
                                    selectedDate = day
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("\(Calendar.current.component(.day, from: day))")
                                            .font(.headline)
                                            .frame(width: 40, height: 40)
                                            .background(isSelected ? PulseTheme.primary : .clear)
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .clipShape(Circle())
                                        HStack(spacing: 3) {
                                            Circle()
                                                .fill(hasScheduled ? PulseTheme.accent : .clear)
                                                .frame(width: 5, height: 5)
                                            Circle()
                                                .fill(hasWorkout ? PulseTheme.primary : .clear)
                                                .frame(width: 5, height: 5)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear.frame(height: 49)
                            }
                        }
                    }
                    .padding()
                    .background(PulseTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                    .stickyHeaderTitle(formattedMonth(visibleMonth))

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(formattedSelectedDate(selectedDate))
                                .font(.headline)
                            let daySessions = loggedWorkouts(on: selectedDate)
                            let plannedSessions = scheduledWorkouts(on: selectedDate)
                            if !plannedSessions.isEmpty {
                                Text("scheduled_2")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.accent)
                                ForEach(plannedSessions) { scheduled in
                                    NavigationLink {
                                        ActiveWorkoutView(workout: scheduled.workoutDay)
                                    } label: {
                                        CalendarPlannedWorkoutRow(
                                            scheduled: scheduled,
                                            gender: store.userProfile.muscleMapGender,
                                            catalog: store.exercises
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if !daySessions.isEmpty {
                                HStack(spacing: 12) {
                                    let sessionsWord = localizedString("sessions_2")
                                    CalendarSummaryPill(title: "\(daySessions.count)", subtitle: LocalizedStringKey(sessionsWord), systemImage: "checkmark.circle")
                                    if dayRouteDistanceKm(on: selectedDate) > 0 {
                                        CalendarSummaryPill(title: String(format: "%.1f", dayRouteDistanceKm(on: selectedDate)), subtitle: "km", systemImage: "figure.walk")
                                    } else {
                                        let exercisesWord = localizedString("exercises_2")
                                        CalendarSummaryPill(title: "\(dayExerciseCount(on: selectedDate))", subtitle: LocalizedStringKey(exercisesWord), systemImage: "dumbbell")
                                    }
                                    let volume = Int(FitnessMetrics.totalVolumeKg(for: daySessions))
                                    CalendarSummaryPill(title: volume > 0 ? "\(volume)" : "\(daySessions.reduce(0) { $0 + $1.durationMinutes })", subtitle: volume > 0 ? "kg" : "min", systemImage: volume > 0 ? "scalemass" : "timer")
                                }
                            }
                            ForEach(loggedWorkouts(on: selectedDate)) { session in
                                NavigationLink {
                                    WorkoutSessionDetailView(session: session)
                                } label: {
                                    HStack {
                                        Image(systemName: session.isRouteSession ? session.routeSystemImage : "dumbbell.fill")
                                            .font(.headline)
                                            .foregroundStyle(session.isRouteSession ? PulseTheme.accent : PulseTheme.primary)
                                            .frame(width: 36, height: 36)
                                            .background((session.isRouteSession ? PulseTheme.accent : PulseTheme.primary).opacity(0.12))
                                            .clipShape(Circle())
                                        VStack(alignment: .leading) {
                                            Text(session.isRouteSession ? session.routeKindTitle : session.workoutTitle).font(.title3.weight(.bold))
                                            Text(calendarSessionDetailText(for: session))
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)

                                if !session.isRouteSession {
                                    ForEach(exerciseLogs(for: session)) { log in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(RepsText.exerciseName(log.exercise.name, language: store.userProfile.preferredLanguage))
                                                    .font(.headline)
                                                Spacer()
                                                let setsWord = localizedString("sets_3")
                                                Text("\(log.sets.count) \(setsWord)")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(PulseTheme.primary)
                                            }
                                            Text(localizedFormat("volume_kg_format", Int(log.sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) })))
                                                .font(.subheadline)
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        .padding(12)
                                        .background(PulseTheme.grouped)
                                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                    }
                                }
                            }
                            if loggedWorkouts(on: selectedDate).isEmpty {
                                if !plannedSessions.isEmpty {
                                    EmptyView()
                                } else {
                                    PulseEmptyState(
                                        title: "no_activity_recorded",
                                        message: "schedule_a_session_or_start_a_free_workout_for_this_day",
                                        systemImage: "calendar.badge.clock"
                                    )
                                }
                            }
                        }
                    }
                    .stickyHeaderTitle(formattedSelectedDate(selectedDate))
            }
            .sheet(isPresented: $showSchedule) {
                ScheduleWorkoutView()
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            applyFocusedDate(store.calendarFocusedDate)
        }
        .onChange(of: store.calendarFocusedDate) { _, newDate in
            applyFocusedDate(newDate)
        }
    }

    private var calendarCommandCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("this_week", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text(store.activePlan.daysPerWeek > 0 ? "\(weekSessions.count)/\(store.activePlan.daysPerWeek)" : "\(weekSessions.count)")
                        .font(.title2.bold())
                        .foregroundStyle(PulseTheme.primary)
                }
                HStack(spacing: 10) {
                    let scheduledWord = localizedString("scheduled_3")
                    CalendarSummaryPill(title: "\(weekScheduled.count)", subtitle: LocalizedStringKey(scheduledWord), systemImage: "calendar.badge.clock")
                    CalendarSummaryPill(title: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: "kg", systemImage: "scalemass")
                    CalendarSummaryPill(title: "\(weekSessions.reduce(0) { $0 + $1.durationMinutes })", subtitle: "min", systemImage: "timer")
                }
                Button {
                    showSchedule = true
                } label: {
                    Label("schedule_session", systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(.white)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }

    private var weekSessions: [WorkoutSession] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return store.workoutSessions.filter { interval.contains($0.date) }
    }

    private var weekScheduled: [ScheduledWorkout] {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return store.scheduledWorkouts.filter { interval.contains($0.date) }
    }

    private var monthCells: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let range = calendar.range(of: .day, in: .month, for: visibleMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday + 5) % 7
        let days = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }

        return Array(repeating: nil, count: leadingBlanks) + days
    }

    private func formattedMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized(with: formatter.locale)
    }

    private func formattedSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date).capitalized(with: formatter.locale)
    }

    private func loggedWorkouts(on date: Date) -> [WorkoutSession] {
        let calendar = Calendar.current
        return store.workoutSessions
            .filter {
            calendar.isDate($0.date, inSameDayAs: date)
            }
            .sorted { $0.date > $1.date }
        }

    private func scheduledWorkouts(on date: Date) -> [ScheduledWorkout] {
        let calendar = Calendar.current
        return store.scheduledWorkouts
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    private func dayExerciseCount(on date: Date) -> Int {
        loggedWorkouts(on: date).reduce(0) { $0 + exerciseCount(for: $1) }
    }

    private func dayRouteDistanceKm(on date: Date) -> Double {
        loggedWorkouts(on: date).compactMap(\.distanceKm).reduce(0, +)
    }

    private func exerciseCount(for session: WorkoutSession) -> Int {
        FitnessMetrics.completedExerciseLogs(in: session).count
    }

    private func calendarSessionDetailText(for session: WorkoutSession) -> String {
        if session.isRouteSession {
            var parts = ["\(session.durationMinutes) min"]
            if let distanceKm = session.distanceKm {
                parts.append(String(format: "%.2f km", distanceKm))
            }
            if let pace = session.averagePaceSecondsPerKm {
                parts.append("\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))/km")
            }
            if let steps = session.steps {
                parts.append("\(Int(steps)) pasos")
            }
            return parts.joined(separator: " · ")
        }

        let exercisesWord = localizedString("exercises_2")
        return "\(session.durationMinutes) min · \(exerciseCount(for: session)) \(exercisesWord)"
    }

    private func exerciseLogs(for session: WorkoutSession) -> [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    private func changeMonth(by value: Int) {
        let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        visibleMonth = nextMonth
        selectedDate = Calendar.current.dateInterval(of: .month, for: nextMonth)?.start ?? nextMonth
    }

    private func applyFocusedDate(_ date: Date?) {
        guard let date else {
            return
        }

        visibleMonth = date
        selectedDate = date
        store.calendarFocusedDate = nil
    }
}

private struct CalendarSummaryPill: View {
    let title: String
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
            Text(localizedKey(subtitle))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct CalendarPlannedWorkoutRow: View {
    let scheduled: ScheduledWorkout
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        HStack(spacing: 12) {
            ExerciseMediaThumbnail(exercise: scheduled.workoutDay.exercises.first?.exercise ?? SeedData.bench, gender: gender, catalog: catalog)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(scheduled.workoutDay.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(scheduled.workoutDay.durationMinutes) min · \(calendarSessionTypeTitle(scheduled.workoutDay.sessionType))")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "play.fill")
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(PulseTheme.accent)
                .clipShape(Circle())
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private func calendarSessionTypeTitle(_ type: WorkoutDay.SessionType) -> String {
    switch type {
    case .strength: localizedString("strength")
    case .cardioRun: localizedString("cardio_run")
    case .cardioWalk: localizedString("cardio_walk")
    case .mixedRoute: localizedString("mixed_route")
    case .mobility: localizedString("mobility")
    case .free: localizedString("free_session")
    }
}

struct ScheduleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var selectedWorkoutID: WorkoutDay.ID?
    @State private var date = Date()

    private var selectedWorkout: WorkoutDay {
        store.activePlan.days.first { $0.id == selectedWorkoutID } ?? store.todaysWorkout
    }

    private var hasActivePlan: Bool {
        !store.activePlan.days.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("training") {
                    if hasActivePlan {
                        Picker("training", selection: $selectedWorkoutID) {
                            ForEach(store.activePlan.days) { workout in
                                Text(workout.title).tag(Optional(workout.id))
                            }
                        }
                    } else {
                        LabeledContent("type_label") {
                            Text("free_training")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("date_2") {
                    DatePicker("training_day", selection: $date, displayedComponents: [.date])
                }
            }
            .navigationTitle("schedule_training")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedWorkoutID = hasActivePlan ? store.activePlan.days.first?.id : nil
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        store.addScheduledWorkout(selectedWorkout, date: date)
                        dismiss()
                    }
                }
            }
        }
    }
}

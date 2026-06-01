import MuscleMap
import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSchedule = false
    @State private var visibleMonth = Date()
    @State private var selectedDate = Date()
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        let isSpanish = store.userProfile.preferredLanguage.hasPrefix("es")
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isSpanish ? "Calendario" : "Calendar")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(isSpanish ? "Planifica, revisa la carga y ve al grano" : "Plan, review load, and jump to the correct session")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer()
                        Button {
                            HapticService.selection()
                            showProfile = true
                        } label: {
                            let avatarData = store.userProfile.avatarImageData
                            if let avatarData, let image = UIImage(data: avatarData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 38, height: 38)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.20), radius: 4)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(PulseTheme.primary.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(color: .black.opacity(0.20), radius: 4)
                            }
                        }
                        .padding(.top, 4)
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSpanish ? "Perfil" : "Profile")
                    }

                    calendarCommandCard

                    HStack {
                        Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
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

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.headline)
                            let daySessions = loggedWorkouts(on: selectedDate)
                            let plannedSessions = scheduledWorkouts(on: selectedDate)
                            if !plannedSessions.isEmpty {
                                Text("Scheduled")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PulseTheme.accent)
                                ForEach(plannedSessions) { scheduled in
                                    NavigationLink {
                                        ActiveWorkoutView(workout: scheduled.workoutDay)
                                    } label: {
                                        CalendarPlannedWorkoutRow(
                                            scheduled: scheduled,
                                            gender: store.userProfile.muscleMapGender
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            if !daySessions.isEmpty {
                                HStack(spacing: 12) {
                                    let sessionsWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "sesiones" : "sessions"
                                    let exercisesWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "ejercicios" : "exercises"
                                    CalendarSummaryPill(title: "\(daySessions.count)", subtitle: LocalizedStringKey(sessionsWord), systemImage: "checkmark.circle")
                                    CalendarSummaryPill(title: "\(dayExerciseCount(on: selectedDate))", subtitle: LocalizedStringKey(exercisesWord), systemImage: "dumbbell")
                                    CalendarSummaryPill(title: "\(Int(FitnessMetrics.totalVolumeKg(for: daySessions)))", subtitle: "kg", systemImage: "scalemass")
                                }
                            }
                            ForEach(loggedWorkouts(on: selectedDate)) { session in
                                NavigationLink {
                                    WorkoutSessionDetailView(session: session)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(session.workoutTitle).font(.title3.weight(.bold))
                                            let exercisesWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "ejercicios" : "exercises"
                                            Text("\(session.durationMinutes) min · \(exerciseCount(for: session)) \(exercisesWord)")
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                                .buttonStyle(.plain)

                                ForEach(exerciseLogs(for: session)) { log in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(RepsText.exerciseName(log.exercise.name, language: store.userProfile.preferredLanguage))
                                                .font(.headline)
                                            Spacer()
                                            let setsWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "series" : "sets"
                                            Text("\(log.sets.count) \(setsWord)")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(PulseTheme.primary)
                                        }
                                        let volumeWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "volumen" : "volume"
                                        Text("\(Int(log.sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) })) kg \(volumeWord)")
                                            .font(.subheadline)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                    .padding(12)
                                    .background(PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                }
                            }
                            if loggedWorkouts(on: selectedDate).isEmpty {
                                if !plannedSessions.isEmpty {
                                    EmptyView()
                                } else {
                                PulseEmptyState(
                                    title: "No activity recorded",
                                    message: "Schedule a session or start a free workout for this day.",
                                    systemImage: "calendar.badge.clock"
                                )
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 112)
            }
            .screenBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showSchedule) {
                ScheduleWorkoutView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }

    private var calendarCommandCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("This Week", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text("\(weekSessions.count)/\(store.activePlan.daysPerWeek)")
                        .font(.title2.bold())
                        .foregroundStyle(PulseTheme.primary)
                }
                HStack(spacing: 10) {
                    let scheduledWord = store.userProfile.preferredLanguage.hasPrefix("es") ? "programadas" : "scheduled"
                    CalendarSummaryPill(title: "\(weekScheduled.count)", subtitle: LocalizedStringKey(scheduledWord), systemImage: "calendar.badge.clock")
                    CalendarSummaryPill(title: "\(Int(FitnessMetrics.totalVolumeKg(for: weekSessions)))", subtitle: "kg", systemImage: "scalemass")
                    CalendarSummaryPill(title: "\(weekSessions.reduce(0) { $0 + $1.durationMinutes })", subtitle: "min", systemImage: "timer")
                }
                Button {
                    showSchedule = true
                } label: {
                    Label("Schedule Session", systemImage: "calendar.badge.plus")
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

    private func exerciseCount(for session: WorkoutSession) -> Int {
        FitnessMetrics.completedExerciseLogs(in: session).count
    }

    private func exerciseLogs(for session: WorkoutSession) -> [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    private func changeMonth(by value: Int) {
        let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        visibleMonth = nextMonth
        selectedDate = Calendar.current.dateInterval(of: .month, for: nextMonth)?.start ?? nextMonth
    }
}

private struct CalendarSummaryPill: View {
    let title: String
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.primary)
            Text(subtitle)
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

    var body: some View {
        HStack(spacing: 12) {
            ExerciseMediaThumbnail(exercise: scheduled.workoutDay.exercises.first?.exercise ?? SeedData.bench, gender: gender)
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
    case .strength: "Fuerza"
    case .cardioRun: "Carrera"
    case .cardioWalk: "Caminata"
    case .mixedRoute: "Mixta + ruta"
    case .mobility: "Movilidad"
    case .free: "Libre"
    }
}

struct ScheduleWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var selectedWorkoutID: WorkoutDay.ID?
    @State private var date = Date()

    private var selectedWorkout: WorkoutDay {
        store.activePlan.days.first { $0.id == selectedWorkoutID } ?? store.todaysWorkout
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Entreno") {
                    Picker("Entreno", selection: $selectedWorkoutID) {
                        ForEach(store.activePlan.days) { workout in
                            Text(workout.title).tag(Optional(workout.id))
                        }
                    }
                }

                Section("Fecha") {
                    DatePicker("Día de entrenamiento", selection: $date, displayedComponents: [.date])
                }
            }
            .navigationTitle("Programar entreno")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedWorkoutID = store.activePlan.days.first?.id
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        store.addScheduledWorkout(selectedWorkout, date: date)
                        dismiss()
                    }
                }
            }
        }
    }
}

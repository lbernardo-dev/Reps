import AVFoundation
import CoreLocation
import MapKit
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var store: AppStore
    let workout: WorkoutDay

    @StateObject private var routeTracker = WorkoutRouteTracker()
    @StateObject private var audioRecorder = WorkoutAudioRecorder()
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer()
    @State private var elapsedSeconds = 0
    @State private var pausedSeconds = 0
    @State private var isPaused = false
    @State private var restSeconds = 0
    @State private var finishedSession: WorkoutSession?
    @State private var selectedExerciseIndex = 0
    @State private var exerciseDrafts: [ExerciseSessionDraft]
    @State private var showAdvancedFields = false
    @State private var lastSetCompletedAtSeconds: Int?
    @State private var hasAppliedProgression = false
    @State private var showAddExercise = false
    @State private var replacementExerciseIndex: Int?
    @State private var sessionRPE = 7.0
    @State private var energyBefore = 3.0
    @State private var energyAfter = 3.0
    @State private var sessionNotes = ""
    @State private var sessionVoiceNote = ""
    @State private var sessionPhotoItems: [PhotosPickerItem] = []
    @State private var exercisePhotoItems: [PhotosPickerItem] = []
    @State private var sessionMediaAttachments: [WorkoutMediaAttachment] = []

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let origin: WorkoutSession.Origin

    init(workout: WorkoutDay, origin: WorkoutSession.Origin = .routine) {
        self.workout = workout
        self.origin = origin
        _exerciseDrafts = State(initialValue: Self.makeDrafts(for: workout))
    }

    private var completedSets: Int {
        exerciseDrafts.flatMap(\.sets).filter(\.completed).count
    }

    private var totalSets: Int {
        exerciseDrafts.flatMap(\.sets).count
    }

    private var totalVolume: Int {
        let completedSets = exerciseDrafts.flatMap(\.sets).filter(\.completed)
        let volume = completedSets.reduce(0.0) { partialResult, set in
            partialResult + (set.weightKg * Double(set.reps))
        }
        return Int(volume)
    }

    private var setCompletion: Double {
        guard totalSets > 0 else {
            return 0
        }

        return Double(completedSets) / Double(totalSets)
    }

    private var selectedDraft: ExerciseSessionDraft? {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex) else {
            return nil
        }

        return exerciseDrafts[selectedExerciseIndex]
    }

    private var hasVisibleAdvancedFields: Bool {
        store.userProfile.showSetType || store.userProfile.showRPE || store.userProfile.showRIR || store.userProfile.showTempo
    }

    private var isRouteCandidate: Bool {
        switch workout.sessionType {
        case .cardioRun, .cardioWalk, .mixedRoute:
            return true
        case .strength, .mobility, .free:
            return false
        }
    }

    private var planPlaylist: PlanPlaylist? {
        guard store.activePlan.days.contains(where: { $0.id == workout.id }) else {
            return nil
        }

        return store.activePlan.playlists.first
    }

    private var currentRestDuration: Int {
        selectedDraft?.workoutExercise.restSeconds ?? 90
    }

    private var currentRestLabel: LocalizedStringKey {
        guard lastSetCompletedAtSeconds != nil else {
            return "Descanso pendiente"
        }

        return restSeconds == 0 ? "Listo" : "Descanso"
    }

    var body: some View {
        Group {
            if let finishedSession {
                WorkoutSummaryView(session: finishedSession) {
                    dismiss()
                }
            } else {
                activeWorkoutContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(timer) { _ in
            guard finishedSession == nil else {
                return
            }

            if let globalPaused = store.activeWorkoutStatus?.isPaused, globalPaused != isPaused {
                isPaused = globalPaused
            }

            if isPaused {
                pausedSeconds += 1
            } else {
                elapsedSeconds += 1
                restSeconds = max(restSeconds - 1, 0)
            }
            publishActiveWorkoutStatus()
        }
        .onAppear {
            applyAutoProgressionIfNeeded()
            if store.activeWorkoutStatus == nil {
                store.startActiveWorkout(workout, elapsedSeconds: elapsedSeconds, pausedSeconds: pausedSeconds, isPaused: isPaused)
            }
            if isRouteCandidate {
                routeTracker.requestAuthorization()
            }
        }
        .onChange(of: sessionPhotoItems) { _, newItems in
            Task { await appendSessionPhotos(from: newItems) }
        }
        .onChange(of: exercisePhotoItems) { _, newItems in
            Task { await appendExercisePhotos(from: newItems) }
        }
        .sheet(isPresented: $showAddExercise) {
            ExercisePickerSheet(title: "Añadir ejercicio", exercises: store.exercises, currentExercise: nil) { exercise in
                addExercise(exercise)
                showAddExercise = false
            }
        }
        .sheet(item: replacementBinding) { replacement in
            ExercisePickerSheet(
                title: "Sustituir ejercicio",
                exercises: substitutionCandidates(for: replacement.index),
                currentExercise: exerciseDrafts.indices.contains(replacement.index) ? exerciseDrafts[replacement.index].workoutExercise.exercise : nil
            ) { exercise in
                replaceExercise(at: replacement.index, with: exercise)
                replacementExerciseIndex = nil
            }
        }
        .sensoryFeedback(.success, trigger: completedSets)
        .mainTabBarHidden()
        .onDisappear {
            routeTracker.stop()
            _ = audioRecorder.stopRecording(note: nil)
        }
    }

    private var activeWorkoutContent: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 40, 0)
            ScrollView {
                VStack(spacing: 18) {
                    workoutHeader
                        .frame(width: contentWidth)
                    sessionProgressCard
                        .frame(width: contentWidth)
                    if isRouteCandidate {
                        routeTrackingCard
                            .frame(width: contentWidth)
                    }
                    restCard
                        .frame(width: contentWidth)
                    if let planPlaylist {
                        workoutMusicCard(planPlaylist)
                            .frame(width: contentWidth)
                    }
                    exerciseSwitcher
                        .frame(width: contentWidth)
                    if exerciseDrafts.isEmpty {
                        emptyFreeWorkoutCard
                            .frame(width: contentWidth)
                    } else {
                        exerciseCard
                            .frame(width: contentWidth)
                    }
                    sessionFeedbackCard
                        .frame(width: contentWidth)
                    nextExerciseCard
                        .frame(width: contentWidth)
                }
                .frame(maxWidth: .infinity)
                .safeAreaPadding(.top, 8)
                .padding(.top, 8)
                .padding(.bottom, 128)
            }
        }
        .screenBackground()
    }

    private var workoutHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .background(PulseTheme.grouped)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Volver")

            VStack(alignment: .leading, spacing: 2) {
                Text(RepsText.workoutTitle(workout.title, language: store.userProfile.preferredLanguage))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Label(timeString(elapsedSeconds), systemImage: "timer")
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                Text("Añadir nota del entrenamiento")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.tertiaryText)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    isPaused.toggle()
                }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isPaused ? PulseTheme.primary : .white)
                    .frame(width: 44, height: 44)
                    .background(isPaused ? PulseTheme.primary.opacity(0.12) : PulseTheme.warning)
                    .clipShape(Circle())
            }
            .accessibilityLabel(isPaused ? "Reanudar entrenamiento" : "Pausar entrenamiento")

            Button {
                finishWorkout()
            } label: {
                Text("Finalizar")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 44)
                    .background(PulseTheme.destructive)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 2)
    }

    private func finishWorkout() {
        let logs = exerciseDrafts.map { draft in
            let attachments = draft.mediaAttachments + voiceAttachments(from: draft.voiceNote)
            return ExerciseLog(
                exercise: draft.workoutExercise.exercise,
                notes: draft.notes,
                sets: draft.sets.filter(\.completed),
                mediaAttachments: attachments
            )
        }
        let allSets = exerciseDrafts.flatMap(\.sets)
        let sessionAttachments = sessionMediaAttachments + voiceAttachments(from: sessionVoiceNote)
        let session = WorkoutSession(
            workoutTitle: workout.title,
            date: .now,
            startedAt: Date().addingTimeInterval(TimeInterval(-elapsedSeconds)),
            endedAt: .now,
            origin: origin,
            location: workout.subtitle.localizedCaseInsensitiveContains("home") ? .home : .gym,
            contextTag: .normal,
            durationMinutes: max(elapsedSeconds / 60, 1),
            sets: allSets,
            notes: sessionNotesText(from: logs),
            exerciseLogs: logs,
            sessionRPE: sessionRPE,
            energyBefore: Int(energyBefore),
            energyAfter: Int(energyAfter),
            mediaAttachments: sessionAttachments,
            routePoints: routeTracker.routePoints,
            pausedDurationSeconds: pausedSeconds
        )
        store.finishWorkout(session)
        finishedSession = session
    }

    private func publishActiveWorkoutStatus() {
        store.updateActiveWorkout(
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: completedSets,
            totalSets: totalSets,
            volumeKg: totalVolume,
            isPaused: isPaused
        )
    }

    private var sessionProgressCard: some View {
        PulseCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                        Text(isPaused ? "SESIÓN PAUSADA" : "SESIÓN ACTIVA")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                        Text("\(completedSets) de \(totalSets) series")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(timeString(elapsedSeconds), systemImage: "timer")
                            .font(.headline.monospacedDigit())
                        if pausedSeconds > 0 {
                            Text("Pausa \(timeString(pausedSeconds))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Text("\(totalVolume) kg volumen")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                ProgressView(value: setCompletion)
                    .tint(PulseTheme.primaryBright)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)
                    .animation(.snappy(duration: 0.25), value: setCompletion)

                Button {
                    completeNextAvailableSet()
                } label: {
                    Label(nextLoggingTitle, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .disabled(completedSets == totalSets)
                .opacity(completedSets == totalSets ? 0.55 : 1)
            }
        }
    }

    private var exerciseSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(exerciseDrafts.indices, id: \.self) { index in
                    let draft = exerciseDrafts[index]
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedExerciseIndex = index
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ExerciseMediaThumbnail(
                                exercise: draft.workoutExercise.exercise,
                                gender: store.userProfile.muscleMapGender,
                                fallbackSize: .caption.weight(.bold)
                            )
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(index + 1). \(RepsText.exerciseName(draft.workoutExercise.exercise.name, language: store.userProfile.preferredLanguage))")
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                Text("\(draft.sets.filter(\.completed).count)/\(draft.sets.count) series")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(selectedExerciseIndex == index ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(width: 190, alignment: .leading)
                        .background(selectedExerciseIndex == index ? PulseTheme.primary : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var restCard: some View {
        PulseCard {
            HStack(spacing: 18) {
                Image(systemName: "hourglass")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(lastSetCompletedAtSeconds == nil ? PulseTheme.secondaryText : (restSeconds == 0 ? PulseTheme.primary : PulseTheme.accent))
                    .clipShape(Circle())
                VStack(alignment: .leading) {
                    Text(currentRestLabel)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                    if lastSetCompletedAtSeconds == nil {
                        Text("Empieza al completar una serie")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    } else {
                        Text(timeString(restSeconds))
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(restSeconds == 0 ? PulseTheme.primary : PulseTheme.accent)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Button(restSeconds == 0 ? "Reiniciar" : "Saltar") {
                        restSeconds = restSeconds == 0 ? currentRestDuration : 0
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(PulseTheme.grouped)
                    .clipShape(Capsule())
                    .disabled(lastSetCompletedAtSeconds == nil)
                    .opacity(lastSetCompletedAtSeconds == nil ? 0.45 : 1)
                    .accessibilityLabel(restSeconds == 0 ? "Reiniciar descanso" : "Saltar descanso")

                    Stepper("", value: $restSeconds, in: 0...600, step: 15)
                        .labelsHidden()
                        .tint(PulseTheme.accent)
                        .disabled(lastSetCompletedAtSeconds == nil)
                        .opacity(lastSetCompletedAtSeconds == nil ? 0.45 : 1)
                }
            }
        }
    }

    private var routeTrackingCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: routeTracker.isTracking ? "location.fill" : "map")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(routeTracker.isTracking ? PulseTheme.primary : PulseTheme.secondaryText)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GPS y ruta")
                            .font(.headline)
                        Text(routeTracker.statusText)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        routeTracker.isTracking ? routeTracker.stop() : routeTracker.start()
                    } label: {
                        Text(routeTracker.isTracking ? "Detener" : "Iniciar")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(routeTracker.isTracking ? PulseTheme.secondaryText : .white)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(routeTracker.isTracking ? PulseTheme.grouped : PulseTheme.primary)
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Distancia", value: String(format: "%.2f km", routeTracker.distanceKm), icon: "point.topleft.down.curvedto.point.bottomright.up")
                    MiniSessionPill(title: "Puntos", value: "\(routeTracker.routePoints.count)", icon: "map.fill")
                    MiniSessionPill(title: "Ritmo", value: routeTracker.paceText(elapsedSeconds: elapsedSeconds), icon: "speedometer")
                }

                if routeTracker.routePoints.count >= 2 {
                    RouteMapPreview(routePoints: routeTracker.routePoints)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }

    private func workoutMusicCard(_ playlist: PlanPlaylist) -> some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: playlist.provider == .spotify ? "dot.radiowaves.left.and.right" : "music.note")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(playlist.provider == .spotify ? Color.green : Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Música del entreno")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                        Text(playlist.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(musicPlayer.statusText(for: playlist))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    if playlist.provider == .appleMusic {
                        Button {
                            Task { await musicPlayer.toggle(playlist) }
                        } label: {
                            Label(musicPlayer.isPlaying ? "Pausar" : "Reproducir", systemImage: musicPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(.white)
                                .background(PulseTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    Button {
                        guard let url = URL(string: playlist.urlString) else { return }
                        openURL(url)
                    } label: {
                        Label(playlist.provider == .appleMusic ? "Abrir" : "Spotify", systemImage: "arrow.up.forward.app")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    if let exercise = selectedDraft?.workoutExercise.exercise {
                        ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender)
                            .frame(width: 92, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(RepsText.equipment(selectedDraft?.workoutExercise.exercise.equipment ?? "", language: store.userProfile.preferredLanguage))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(RepsText.exerciseName(selectedDraft?.workoutExercise.exercise.name ?? "Ejercicio", language: store.userProfile.preferredLanguage))
                            .font(.title3.weight(.bold))
                            .lineLimit(3)
                            .minimumScaleFactor(0.78)
                        Text("Objetivo: \(selectedDraft?.workoutExercise.targetSets ?? 0) series · \(selectedDraft?.workoutExercise.repRange ?? "-") · previo \(selectedDraft?.workoutExercise.previous ?? "-")")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let selectedSuggestionText {
                            Label(selectedSuggestionText, systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                    Menu {
                        Button {
                            showAddExercise = true
                        } label: {
                            Label("Añadir ejercicio", systemImage: "plus")
                        }

                        Button {
                            replacementExerciseIndex = selectedExerciseIndex
                        } label: {
                            Label("Sustituir", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                executionSummaryStrip

                if !selectedMediaBookmarks.isEmpty {
                    ExerciseBookmarkStrip(bookmarks: selectedMediaBookmarks)
                }

                HStack {
                    Text("Serie").frame(width: 42, alignment: .leading)
                    Text("Peso").frame(maxWidth: .infinity)
                    Text("Reps").frame(maxWidth: .infinity)
                    Image(systemName: "checkmark").frame(width: 48)
                }
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)

                if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                    ForEach(exerciseDrafts[selectedExerciseIndex].sets.indices, id: \.self) { setIndex in
                        SetRow(set: Binding(
                            get: { exerciseDrafts[selectedExerciseIndex].sets[setIndex] },
                            set: { exerciseDrafts[selectedExerciseIndex].sets[setIndex] = $0 }
                        )) { completed in
                            guard completed else { return }
                            handleSetCompleted(exerciseIndex: selectedExerciseIndex, setIndex: setIndex)
                        }
                    }
                }

                DisclosureGroup(isExpanded: $showAdvancedFields) {
                    if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                        VStack(spacing: 10) {
                            ForEach(exerciseDrafts[selectedExerciseIndex].sets.indices, id: \.self) { setIndex in
                                AdvancedSetFields(set: Binding(
                                    get: { exerciseDrafts[selectedExerciseIndex].sets[setIndex] },
                                    set: { exerciseDrafts[selectedExerciseIndex].sets[setIndex] = $0 }
                                ), showSetType: store.userProfile.showSetType, showRPE: store.userProfile.showRPE, showRIR: store.userProfile.showRIR, showTempo: store.userProfile.showTempo)
                            }
                        }
                        .padding(.top, 8)
                    }
                } label: {
                    Label("Campos Pro", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.primary)
                }
                .opacity(hasVisibleAdvancedFields ? 1 : 0.55)
                .disabled(!hasVisibleAdvancedFields)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Notas", systemImage: "note.text")
                        .font(.headline)
                    TextField("Sensaciones del ejercicio", text: Binding(
                        get: { selectedDraft?.notes ?? "" },
                        set: { newValue in
                            guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
                            exerciseDrafts[selectedExerciseIndex].notes = newValue
                        }
                    ), axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    TextField("Dictado o nota de audio", text: Binding(
                        get: { selectedDraft?.voiceNote ?? "" },
                        set: { newValue in
                            guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
                            exerciseDrafts[selectedExerciseIndex].voiceNote = newValue
                        }
                    ), axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    HStack(spacing: 10) {
                        Button {
                            if audioRecorder.isRecording {
                                if let attachment = audioRecorder.stopRecording(note: selectedDraft?.voiceNote) {
                                    exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(attachment)
                                }
                            } else {
                                audioRecorder.startRecording()
                            }
                        } label: {
                            Label(audioRecorder.isRecording ? "Guardar audio" : "Grabar audio", systemImage: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(audioRecorder.isRecording ? .white : PulseTheme.primary)
                                .background(audioRecorder.isRecording ? Color.red : PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        if audioRecorder.isRecording {
                            Text(timeString(Int(audioRecorder.elapsedSeconds)))
                                .font(.subheadline.monospacedDigit().weight(.bold))
                                .foregroundStyle(.red)
                                .frame(width: 72, height: 46)
                                .background(Color.red.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $exercisePhotoItems, maxSelectionCount: 6, matching: .images) {
                            Label("Fotos del ejercicio", systemImage: "camera.fill")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.primary)
                                .background(PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        Label("\(selectedDraft?.mediaAttachments.filter { $0.kind == .image }.count ?? 0)", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 72, height: 46)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    if let attachments = selectedDraft?.mediaAttachments, !attachments.isEmpty {
                        AttachmentPreviewStrip(attachments: attachments)
                    }
                }

                Button {
                    addSetToSelectedExercise()
                } label: {
                    Label("Añadir serie", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(PulseTheme.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(PulseTheme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        )
                }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }

    private var nextExerciseCard: some View {
        PulseCard {
            HStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(PulseTheme.primary)
                    .frame(width: 58, height: 58)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                VStack(alignment: .leading) {
                    Text("SIGUIENTE").font(.caption.weight(.bold)).foregroundStyle(PulseTheme.primary)
                    Text(nextExerciseTitle)
                        .font(.headline)
                    Text(nextExerciseSubtitle).foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Button {
                    if exerciseDrafts.isEmpty {
                        showAddExercise = true
                    } else {
                        selectedExerciseIndex = min(selectedExerciseIndex + 1, max(exerciseDrafts.count - 1, 0))
                    }
                } label: {
                    Image(systemName: exerciseDrafts.isEmpty ? "plus" : "chevron.right")
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                .disabled(!exerciseDrafts.isEmpty && selectedExerciseIndex >= exerciseDrafts.count - 1)
            }
        }
    }

    private var executionSummaryStrip: some View {
        HStack(spacing: 10) {
            MiniSessionPill(
                title: "Hecho",
                value: "\(selectedDraft?.sets.filter(\.completed).count ?? 0)/\(selectedDraft?.sets.count ?? 0)",
                icon: "checkmark.circle.fill"
            )
            MiniSessionPill(
                title: "Volumen",
                value: "\(Int(selectedDraft?.sets.filter(\.completed).reduce(0) { $0 + ($1.weightKg * Double($1.reps)) } ?? 0)) kg",
                icon: "chart.bar.fill"
            )
            MiniSessionPill(
                title: "Media",
                value: "\(selectedDraft?.mediaAttachments.count ?? 0)",
                icon: "photo.fill.on.rectangle.fill"
            )
        }
    }

    private var sessionFeedbackCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Cierre de sesión", systemImage: "waveform.path.ecg")
                    .font(.headline)

                HStack(spacing: 10) {
                    InlineStepper(
                        value: $sessionRPE,
                        range: 1...10,
                        step: 0.5,
                        formatter: { "RPE \(String(format: "%.1f", $0))" }
                    )
                    InlineStepper(
                        value: $energyBefore,
                        range: 1...5,
                        step: 1,
                        formatter: { "Antes \(Int($0))/5" }
                    )
                }

                InlineStepper(
                    value: $energyAfter,
                    range: 1...5,
                    step: 1,
                    formatter: { "Después \(Int($0))/5" }
                )

                TextField("Notas globales, molestias o contexto", text: $sessionNotes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                TextField("Dictado o nota de audio de la sesión", text: $sessionVoiceNote, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                Button {
                    if audioRecorder.isRecording {
                        if let attachment = audioRecorder.stopRecording(note: sessionVoiceNote) {
                            sessionMediaAttachments.append(attachment)
                        }
                    } else {
                        audioRecorder.startRecording()
                    }
                } label: {
                    Label(audioRecorder.isRecording ? "Guardar nota de audio" : "Grabar nota de audio", systemImage: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(audioRecorder.isRecording ? .white : PulseTheme.primary)
                        .background(audioRecorder.isRecording ? Color.red : PulseTheme.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $sessionPhotoItems, maxSelectionCount: 8, matching: .images) {
                        Label("Añadir fotos", systemImage: "photo.badge.plus")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    Label("\(sessionMediaAttachments.filter { $0.kind == .image }.count)", systemImage: "camera.metering.matrix")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 72, height: 46)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                if !sessionMediaAttachments.isEmpty {
                    AttachmentPreviewStrip(attachments: sessionMediaAttachments)
                }
            }
        }
    }

    private var emptyFreeWorkoutCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PulseTheme.primary)
                Text("Añade tu primer ejercicio")
                    .font(.title2.bold())
                Text("El entrenamiento libre empieza vacío para que registres solo lo que hagas hoy.")
                    .foregroundStyle(PulseTheme.secondaryText)
                Button {
                    showAddExercise = true
                } label: {
                    Label("Buscar ejercicio", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }

    private var nextExerciseTitle: String {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex + 1) else {
            return exerciseDrafts.isEmpty ? "Añadir ejercicio" : "Completar entreno"
        }

        return RepsText.exerciseName(
            exerciseDrafts[selectedExerciseIndex + 1].workoutExercise.exercise.name,
            language: store.userProfile.preferredLanguage
        )
    }

    private var nextExerciseSubtitle: String {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex + 1) else {
            return exerciseDrafts.isEmpty ? "Entrenamiento libre" : "\(completedSets) series registradas"
        }

        let item = exerciseDrafts[selectedExerciseIndex + 1].workoutExercise
        return "\(item.targetSets) series x \(item.repRange)"
    }

    private var nextLoggingTitle: String {
        guard let next = nextIncompleteSet else {
            return "Todas las series registradas"
        }

        return "Registrar \(RepsText.exerciseName(next.exerciseName, language: store.userProfile.preferredLanguage)), serie \(next.setNumber)"
    }

    private var selectedSuggestionText: String? {
        guard store.userProfile.autoProgressionEnabled,
              let selectedDraft else {
            return nil
        }

        let recentSets = recentSets(for: selectedDraft.workoutExercise.exercise)
        guard !recentSets.isEmpty else {
            return nil
        }

        let suggestion = ProgressionEngine.nextSuggestion(
            for: selectedDraft.workoutExercise,
            recentSets: recentSets,
            weightIncrementKg: store.userProfile.weightIncrementKg
        )
        return suggestion.explanation
    }

    private var selectedMediaBookmarks: [ExerciseMediaBookmark] {
        guard let selectedDraft else {
            return []
        }

        return selectedDraft.workoutExercise.mediaBookmarks + selectedDraft.workoutExercise.exercise.mediaBookmarks
    }

    private var nextIncompleteSet: (exerciseIndex: Int, setIndex: Int, exerciseName: String, setNumber: Int)? {
        for exerciseIndex in exerciseDrafts.indices {
            if let setIndex = exerciseDrafts[exerciseIndex].sets.firstIndex(where: { !$0.completed }) {
                let draft = exerciseDrafts[exerciseIndex]
                return (exerciseIndex, setIndex, draft.workoutExercise.exercise.name, draft.sets[setIndex].setNumber)
            }
        }

        return nil
    }

    private func completeNextAvailableSet() {
        guard let next = nextIncompleteSet else {
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedExerciseIndex = next.exerciseIndex
            exerciseDrafts[next.exerciseIndex].sets[next.setIndex].completed = true
            handleSetCompleted(exerciseIndex: next.exerciseIndex, setIndex: next.setIndex)
        }
    }

    private var replacementBinding: Binding<ExerciseReplacementTarget?> {
        Binding(
            get: {
                guard let replacementExerciseIndex else { return nil }
                return ExerciseReplacementTarget(index: replacementExerciseIndex)
            },
            set: { replacementExerciseIndex = $0?.index }
        )
    }

    private func addExercise(_ exercise: Exercise) {
        withAnimation(.snappy(duration: 0.24)) {
            exerciseDrafts.append(Self.makeDraft(for: exercise))
            selectedExerciseIndex = max(exerciseDrafts.count - 1, 0)
        }
    }

    private func replaceExercise(at index: Int, with exercise: Exercise) {
        guard exerciseDrafts.indices.contains(index) else { return }
        withAnimation(.snappy(duration: 0.24)) {
            var replacement = Self.makeDraft(for: exercise)
            let currentSets = exerciseDrafts[index].sets
            if !currentSets.isEmpty {
                replacement.sets = currentSets.enumerated().map { offset, set in
                    SetLog(
                        setNumber: offset + 1,
                        weightKg: set.weightKg,
                        reps: set.reps,
                        completed: set.completed,
                        setType: set.setType,
                        rpe: set.rpe,
                        rir: set.rir,
                        tempo: set.tempo,
                        previousRestSeconds: set.previousRestSeconds,
                        isPersonalRecord: false,
                        notes: set.notes
                    )
                }
            }
            exerciseDrafts[index] = replacement
            selectedExerciseIndex = index
        }
    }

    private func addSetToSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
            let previous = exerciseDrafts[selectedExerciseIndex].sets.last
            exerciseDrafts[selectedExerciseIndex].sets.append(
                SetLog(
                    setNumber: exerciseDrafts[selectedExerciseIndex].sets.count + 1,
                    weightKg: previous?.weightKg ?? 0,
                    reps: previous?.reps ?? 8,
                    completed: false
                )
            )
        }
    }

    @MainActor
    private func appendSessionPhotos(from items: [PhotosPickerItem]) async {
        let attachments = await imageAttachments(from: items)
        guard !attachments.isEmpty else {
            sessionPhotoItems = []
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            sessionMediaAttachments.append(contentsOf: attachments)
            sessionPhotoItems = []
        }
    }

    @MainActor
    private func appendExercisePhotos(from items: [PhotosPickerItem]) async {
        let attachments = await imageAttachments(from: items)
        guard !attachments.isEmpty else {
            exercisePhotoItems = []
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
            exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(contentsOf: attachments)
            exercisePhotoItems = []
        }
    }

    private func imageAttachments(from items: [PhotosPickerItem]) async -> [WorkoutMediaAttachment] {
        var attachments: [WorkoutMediaAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }

            attachments.append(WorkoutMediaAttachment(kind: .image, data: data))
        }

        return attachments
    }

    private func voiceAttachments(from text: String) -> [WorkoutMediaAttachment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return [WorkoutMediaAttachment(kind: .audio, note: trimmed, durationSeconds: nil)]
    }

    private func sessionNotesText(from logs: [ExerciseLog]) -> String? {
        let exerciseNotes = logs.compactMap { $0.notes.isEmpty ? nil : "\($0.exercise.name): \($0.notes)" }
        let global = sessionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionMediaSummary = sessionMediaAttachments.isEmpty ? nil : "\(sessionMediaAttachments.count) fotos adjuntas de sesión"
        let exerciseMediaSummary = logs
            .filter { !$0.mediaAttachments.isEmpty }
            .map { "\($0.exercise.name): \($0.mediaAttachments.count) adjuntos" }
        let allNotes = (global.isEmpty ? [] : [global]) + exerciseNotes + (sessionMediaSummary.map { [$0] } ?? []) + exerciseMediaSummary
        return allNotes.isEmpty ? nil : allNotes.joined(separator: "\n")
    }

    private func substitutionCandidates(for index: Int) -> [Exercise] {
        guard exerciseDrafts.indices.contains(index) else {
            return store.exercises
        }

        let current = exerciseDrafts[index].workoutExercise.exercise
        let candidates = ExerciseSubstitutionService.candidates(
            for: current,
            in: store.exercises,
            availableEquipment: store.userProfile.availableEquipment
        )
        return candidates.isEmpty ? store.exercises.filter { $0.id != current.id } : candidates
    }

    private func handleSetCompleted(exerciseIndex: Int, setIndex: Int) {
        guard exerciseDrafts.indices.contains(exerciseIndex),
              exerciseDrafts[exerciseIndex].sets.indices.contains(setIndex) else {
            return
        }

        if let lastSetCompletedAtSeconds {
            exerciseDrafts[exerciseIndex].sets[setIndex].previousRestSeconds = max(elapsedSeconds - lastSetCompletedAtSeconds, 0)
        }

        let completedSet = exerciseDrafts[exerciseIndex].sets[setIndex]
        let exercise = exerciseDrafts[exerciseIndex].workoutExercise.exercise
        exerciseDrafts[exerciseIndex].sets[setIndex].isPersonalRecord = isPersonalRecord(completedSet, for: exercise)
        lastSetCompletedAtSeconds = elapsedSeconds
        let nextIndex = setIndex + 1
        if exerciseDrafts[exerciseIndex].sets.indices.contains(nextIndex),
           !exerciseDrafts[exerciseIndex].sets[nextIndex].completed {
            restSeconds = exerciseDrafts[exerciseIndex].workoutExercise.restSeconds
            exerciseDrafts[exerciseIndex].sets[nextIndex].weightKg = completedSet.weightKg
            exerciseDrafts[exerciseIndex].sets[nextIndex].reps = completedSet.reps
            return
        }

        let nextExerciseIndex = exerciseIndex + 1
        if exerciseDrafts.indices.contains(nextExerciseIndex),
           exerciseDrafts[nextExerciseIndex].sets.contains(where: { !$0.completed }) {
            restSeconds = workout.restBetweenExercisesSeconds
        } else {
            restSeconds = 0
        }
    }

    private func applyAutoProgressionIfNeeded() {
        guard store.userProfile.autoProgressionEnabled, !hasAppliedProgression else {
            return
        }

        hasAppliedProgression = true
        for index in exerciseDrafts.indices {
            let item = exerciseDrafts[index].workoutExercise
            let recentSets = recentSets(for: item.exercise)
            guard !recentSets.isEmpty else {
                continue
            }

            let suggestion = ProgressionEngine.nextSuggestion(
                for: item,
                recentSets: recentSets,
                weightIncrementKg: store.userProfile.weightIncrementKg
            )

            guard suggestion.targetWeightKg > 0 else {
                continue
            }

            for setIndex in exerciseDrafts[index].sets.indices where !exerciseDrafts[index].sets[setIndex].completed {
                exerciseDrafts[index].sets[setIndex].weightKg = suggestion.targetWeightKg
                exerciseDrafts[index].sets[setIndex].reps = suggestion.targetReps
            }
        }
    }

    private func recentSets(for exercise: Exercise) -> [SetLog] {
        store.workoutSessions
            .sorted { $0.date > $1.date }
            .flatMap { session in
                (session.exerciseLogs ?? []).filter { log in
                    log.exercise.id == exercise.id || normalizedExerciseName(log.exercise.name) == normalizedExerciseName(exercise.name)
                }
                .flatMap(\.sets)
            }
            .filter(\.completed)
            .prefix(12)
            .map { $0 }
    }

    private func normalizedExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func isPersonalRecord(_ set: SetLog, for exercise: Exercise) -> Bool {
        let points = FitnessMetrics.progressPoints(for: exercise, in: store.workoutSessions)
        let previousBestWeight = points.map(\.maxWeightKg).max() ?? 0
        let previousBestOneRepMax = points.map(\.estimatedOneRepMaxKg).max() ?? 0
        let estimatedOneRepMax = FitnessMetrics.estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
        return set.weightKg > previousBestWeight || estimatedOneRepMax > previousBestOneRepMax
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private static func makeDrafts(for workout: WorkoutDay) -> [ExerciseSessionDraft] {
        workout.exercises.map(makeDraft(for:))
    }

    private static func makeDraft(for exercise: Exercise) -> ExerciseSessionDraft {
        makeDraft(for: WorkoutExercise(exercise: exercise, targetSets: 3, repRange: defaultRepRange(for: exercise), previous: "-"))
    }

    private static func makeDraft(for item: WorkoutExercise) -> ExerciseSessionDraft {
        let sets = (1...max(item.targetSets, 1)).map { index in
            SetLog(setNumber: index, weightKg: defaultWeight(from: item.previous), reps: defaultReps(from: item.repRange), completed: false)
        }
        return ExerciseSessionDraft(workoutExercise: item, notes: "", sets: sets)
    }

    private static func defaultRepRange(for exercise: Exercise) -> String {
        switch exercise.trackingType {
        case .weightReps: "8-12"
        case .repsOnly: "8-15"
        case .duration: "30-45 sec"
        }
    }

    private static func defaultWeight(from previous: String) -> Double {
        let normalized = previous.replacingOccurrences(of: ",", with: ".")
        let number = normalized
            .split { character in
                !(character.isNumber || character == ".")
            }
            .compactMap { Double($0) }
            .first
        return number ?? 0
    }

    private static func defaultReps(from repRange: String) -> Int {
        let digits = repRange.split { !$0.isNumber }.compactMap { Int($0) }
        return digits.first ?? 8
    }
}

private struct ExerciseSessionDraft {
    var workoutExercise: WorkoutExercise
    var notes: String
    var voiceNote: String = ""
    var sets: [SetLog]
    var mediaAttachments: [WorkoutMediaAttachment] = []
}

private struct ExerciseReplacementTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let title: String
    let exercises: [Exercise]
    let currentExercise: Exercise?
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var selectedMuscle = "Todos"
    @State private var selectedEquipment = "Todos"

    private var muscles: [String] {
        ["Todos"] + Array(Set(exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
            let matchesQuery = query.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(query)
                || exercise.muscleGroup.localizedCaseInsensitiveContains(query)
                || exercise.equipment.localizedCaseInsensitiveContains(query)
                || exercise.aliases.contains { $0.localizedCaseInsensitiveContains(query) }
            let matchesMuscle = selectedMuscle == "Todos" || exercise.muscleGroup == selectedMuscle
            let matchesEquipment = selectedEquipment == "Todos" || exercise.equipment == selectedEquipment
            return matchesQuery && matchesMuscle && matchesEquipment
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let currentExercise {
                        replacementHeader(for: currentExercise)
                    }

                    HStack(spacing: 10) {
                        Picker("Músculo", selection: $selectedMuscle) {
                            ForEach(muscles, id: \.self) { muscle in
                                Text(muscle == "Todos" ? muscle : RepsText.muscle(muscle, language: store.userProfile.preferredLanguage)).tag(muscle)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Equipo", selection: $selectedEquipment) {
                            ForEach(equipmentOptions, id: \.self) { equipment in
                                Text(equipment == "Todos" ? equipment : RepsText.equipment(equipment, language: store.userProfile.preferredLanguage)).tag(equipment)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .font(.subheadline.weight(.semibold))

                    LazyVStack(spacing: 10) {
                        ForEach(filteredExercises) { exercise in
                            Button {
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                ReplacementExerciseRow(
                                    exercise: exercise,
                                    currentExercise: currentExercise,
                                    gender: store.userProfile.muscleMapGender,
                                    language: store.userProfile.preferredLanguage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .searchable(text: $searchText, prompt: "Buscar por nombre, músculo o equipo")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func replacementHeader(for exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            Text("Actual")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(PulseTheme.grouped, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)

            ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender)
                .frame(maxWidth: .infinity)
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                        .stroke(PulseTheme.separator, lineWidth: 1)
                )

            VStack(spacing: 4) {
                Text(RepsText.exerciseName(exercise.name, language: store.userProfile.preferredLanguage))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(RepsText.muscle(exercise.muscleGroup, language: store.userProfile.preferredLanguage))
                    .font(.headline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            Text("Mejores sustituciones")
                .font(.title3.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }
}

private struct ReplacementExerciseRow: View {
    let exercise: Exercise
    let currentExercise: Exercise?
    let gender: BodyGender
    let language: String

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: exercise, gender: gender)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(RepsText.exerciseName(exercise.name, language: language))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(RepsText.equipment(exercise.equipment, language: language))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                if !exercise.requiredEquipment.isEmpty {
                    Text(exercise.requiredEquipment.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.primary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let badgeText {
                Text(badgeText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.primaryBright)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(PulseTheme.primaryBright.opacity(0.14), in: Capsule())
                    .lineLimit(1)
            }

            Image(systemName: currentExercise == nil ? "plus.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(currentExercise == nil ? PulseTheme.primary : PulseTheme.secondaryText)
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
    }

    private var badgeText: String? {
        guard let currentExercise else { return nil }
        if normalized(exercise.equipment) == normalized(currentExercise.equipment) {
            return "Mismo equipo"
        }
        if exercise.trackingType == currentExercise.trackingType {
            return "Esencial"
        }
        return nil
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private struct MiniSessionPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(PulseTheme.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct AttachmentPreviewStrip: View {
    let attachments: [WorkoutMediaAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    AttachmentPreview(attachment: attachment)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct AttachmentPreview: View {
    let attachment: WorkoutMediaAttachment

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if attachment.kind == .image,
               let data = attachment.data,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                    Text("Audio")
                        .font(.caption.weight(.bold))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(PulseTheme.primary)
                .background(PulseTheme.primary.opacity(0.10))
            }

            if let note = attachment.note, !note.isEmpty {
                Text(note)
                    .font(.caption2.weight(.bold))
                    .lineLimit(2)
                    .padding(6)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(6)
            }
        }
        .frame(width: 96, height: 116)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ExerciseBookmarkStrip: View {
    let bookmarks: [ExerciseMediaBookmark]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Marcadores rápidos", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(bookmarks) { bookmark in
                        Link(destination: URL(string: bookmark.urlString) ?? URL(string: "https://www.youtube.com")!) {
                            HStack(spacing: 8) {
                                Image(systemName: icon(for: bookmark.source))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.title)
                                        .font(.caption.weight(.bold))
                                        .lineLimit(1)
                                    if let timestamp = bookmark.timestampSeconds {
                                        Text("\(timestamp / 60):\(String(format: "%02d", timestamp % 60))")
                                            .font(.caption2.monospacedDigit())
                                    }
                                }
                            }
                            .foregroundStyle(PulseTheme.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 46)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func icon(for source: ExerciseMediaBookmark.Source) -> String {
        switch source {
        case .youtube, .youtubeShorts: "play.rectangle.fill"
        case .tiktok: "music.note.tv"
        case .instagram: "camera.fill"
        case .other: "link"
        }
    }
}

private struct RouteMapPreview: View {
    let routePoints: [RoutePoint]
    @State private var position: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(PulseTheme.primary, lineWidth: 5)
            }
            if let first = coordinates.first {
                Marker("Inicio", systemImage: "play.fill", coordinate: first)
                    .tint(.green)
            }
            if let last = coordinates.last {
                Marker("Actual", systemImage: "location.fill", coordinate: last)
                    .tint(.purple)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            fitRoute()
        }
        .onChange(of: routePoints.count) { _, _ in
            fitRoute()
        }
    }

    private func fitRoute() {
        let coords = coordinates
        guard let first = coords.first else { return }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coords {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.8, 0.005), longitudeDelta: max((maxLon - minLon) * 1.8, 0.005))
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}

@MainActor
private final class WorkoutRouteTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var routePoints: [RoutePoint] = []
    @Published var isTracking = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var totalDistanceMeters: CLLocationDistance = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
        authorizationStatus = manager.authorizationStatus
    }

    var distanceKm: Double {
        totalDistanceMeters / 1_000
    }

    var statusText: String {
        if isTracking {
            return "Registrando ruta en vivo"
        }
        switch authorizationStatus {
        case .denied, .restricted:
            return "Permiso de ubicación no concedido"
        case .notDetermined:
            return "Listo para pedir permiso"
        default:
            return routePoints.isEmpty ? "Sin ruta iniciada" : "Ruta pausada"
        }
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        requestAuthorization()
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stop() {
        isTracking = false
        manager.stopUpdatingLocation()
    }

    func paceText(elapsedSeconds: Int) -> String {
        guard distanceKm > 0.02 else {
            return "--"
        }
        let pace = Double(max(elapsedSeconds, 1)) / distanceKm
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))/km"
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50 {
                if let lastLocation {
                    totalDistanceMeters += location.distance(from: lastLocation)
                }
                lastLocation = location
                routePoints.append(
                    RoutePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        altitude: location.altitude,
                        horizontalAccuracy: location.horizontalAccuracy,
                        timestamp: location.timestamp
                    )
                )
            }
        }
    }
}

@MainActor
private final class WorkoutAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsedSeconds: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var startedAt: Date?
    private var timer: Timer?

    func startRecording() {
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            guard allowed else { return }
            Task { @MainActor in
                self?.beginRecording()
            }
        }
    }

    func stopRecording(note: String?) -> WorkoutMediaAttachment? {
        guard let recorder, let recordingURL else {
            return nil
        }

        recorder.stop()
        self.recorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil

        let data = try? Data(contentsOf: recordingURL)
        let duration = startedAt.map { Date().timeIntervalSince($0) }
        self.recordingURL = nil
        startedAt = nil
        elapsedSeconds = 0

        return WorkoutMediaAttachment(
            kind: .audio,
            data: data,
            note: note?.trimmingCharacters(in: .whitespacesAndNewlines),
            durationSeconds: duration
        )
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("reps-audio-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()

            recordingURL = url
            self.recorder = recorder
            startedAt = .now
            isRecording = true
            elapsedSeconds = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let startedAt = self.startedAt else { return }
                    self.elapsedSeconds = Date().timeIntervalSince(startedAt)
                }
            }
        } catch {
            isRecording = false
        }
    }
}

@MainActor
private final class WorkoutAppleMusicPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var message: String?

    private var currentPlaylistID: PlanPlaylist.ID?

    func statusText(for playlist: PlanPlaylist) -> String {
        guard playlist.provider == .appleMusic else {
            return "Spotify se abre en su app por ahora"
        }

        if currentPlaylistID == playlist.id, isPlaying {
            return "Reproduciendo con Apple Music"
        }

        return message ?? "Apple Music interno listo"
    }

    func toggle(_ playlist: PlanPlaylist) async {
        guard playlist.provider == .appleMusic else {
            return
        }

        if isPlaying, currentPlaylistID == playlist.id {
            ApplicationMusicPlayer.shared.pause()
            isPlaying = false
            message = "Pausado"
            return
        }

        await play(playlist)
    }

    private func play(_ playlist: PlanPlaylist) async {
        let authorization = await MusicAuthorization.request()
        guard authorization == .authorized else {
            message = "Autoriza Apple Music para reproducir aquí"
            return
        }

        do {
            let subscription = try await MusicSubscription.current
            guard subscription.canPlayCatalogContent else {
                message = "Necesitas una suscripción activa de Apple Music"
                return
            }

            guard let musicPlaylist = try await resolvePlaylist(playlist) else {
                message = "No pude resolver la playlist; usa Abrir"
                return
            }

            ApplicationMusicPlayer.shared.queue = [musicPlaylist]
            try await ApplicationMusicPlayer.shared.play()
            currentPlaylistID = playlist.id
            isPlaying = true
            message = "Reproduciendo con Apple Music"
        } catch {
            message = "Apple Music no pudo iniciar esta playlist"
        }
    }

    private func resolvePlaylist(_ playlist: PlanPlaylist) async throws -> Playlist? {
        if let candidateID = appleMusicPlaylistID(from: playlist.urlString) {
            let request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: MusicItemID(candidateID))
            let response = try await request.response()
            if let resolved = response.items.first {
                return resolved
            }
        }

        var search = MusicCatalogSearchRequest(term: playlist.title, types: [Playlist.self])
        search.limit = 5
        let response = try await search.response()
        return response.playlists.first
    }

    private func appleMusicPlaylistID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else {
            return nil
        }

        let pathCandidates = url.pathComponents.filter { $0.hasPrefix("pl.") }
        if let candidate = pathCandidates.last {
            return candidate
        }

        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "i" || $0.name == "id" })?
            .value
    }
}

private struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    private var completedSets: [SetLog] {
        FitnessMetrics.completedSets(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Entreno completado")
                            .font(.title.bold())
                        Text(session.workoutTitle)
                            .font(.headline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                HStack(spacing: 14) {
                    MetricCard(title: "Duración", value: "\(session.durationMinutes)", subtitle: "minutos", systemImage: "timer")
                    MetricCard(title: "Series", value: "\(completedSets.count)", subtitle: "completadas", systemImage: "checkmark.circle")
                }

                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Volumen").font(.headline)
                        Text("\(Int(FitnessMetrics.totalVolumeKg(for: [session]))) kg")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.primary)
                        if !session.mediaAttachments.isEmpty {
                            AttachmentPreviewStrip(attachments: session.mediaAttachments)
                        }
                        if let notes = session.notes, !notes.isEmpty {
                            Divider()
                            Text(notes)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                if let logs = session.exerciseLogs, logs.contains(where: { !$0.mediaAttachments.isEmpty }) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Evidencia por ejercicio")
                                .font(.headline)
                            ForEach(logs.filter { !$0.mediaAttachments.isEmpty }) { log in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(log.exercise.name)
                                        .font(.subheadline.weight(.bold))
                                    AttachmentPreviewStrip(attachments: log.mediaAttachments)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 80)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Listo") {
                onDone()
            }
            .padding(20)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }
}

private struct SetRow: View {
    @Binding var set: SetLog
    let onCompletionChanged: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background(set.completed ? PulseTheme.primaryBright : PulseTheme.elevated)
                .clipShape(Circle())

            InlineStepper(
                value: $set.weightKg,
                range: 0...400,
                step: 2.5,
                formatter: { String(format: "%.1f", $0) }
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            InlineStepper(
                value: Binding(
                    get: { Double(set.reps) },
                    set: { set.reps = Int($0) }
                ),
                range: 0...100,
                step: 1,
                formatter: { String(Int($0)) }
            )
            .frame(minWidth: 0, maxWidth: .infinity)

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    set.completed.toggle()
                    onCompletionChanged(set.completed)
                }
            } label: {
                Image(systemName: set.isPersonalRecord ? "trophy.fill" : (set.completed ? "checkmark.circle.fill" : "circle"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(set.isPersonalRecord ? PulseTheme.accent : (set.completed ? PulseTheme.primaryBright : PulseTheme.elevated))
                    .clipShape(Circle())
            }
            .accessibilityLabel(set.completed ? "Marcar serie \(set.setNumber) incompleta" : "Marcar serie \(set.setNumber) completa")
        }
        .padding(10)
        .background(set.completed ? PulseTheme.primaryBright.opacity(0.22) : PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AdvancedSetFields: View {
    @Binding var set: SetLog
    let showSetType: Bool
    let showRPE: Bool
    let showRIR: Bool
    let showTempo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Serie \(set.setNumber)")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if set.isPersonalRecord {
                    Label("PR", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }

            HStack(spacing: 10) {
                if showSetType {
                Menu {
                    ForEach(SetLog.SetType.allCases) { type in
                        Button(setTypeTitle(type)) {
                            set.setType = type
                        }
                    }
                } label: {
                    Label(setTypeTitle(set.setType), systemImage: "tag")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                }

                if showRPE {
                InlineStepper(
                    value: Binding(
                        get: { set.rpe ?? 7 },
                        set: { set.rpe = $0 }
                    ),
                    range: 0...10,
                    step: 0.5,
                    formatter: { "RPE \(String(format: "%.1f", $0))" }
                )
                }
            }

            HStack(spacing: 10) {
                if showRIR {
                InlineStepper(
                    value: Binding(
                        get: { Double(set.rir ?? 2) },
                        set: { set.rir = Int($0) }
                    ),
                    range: 0...5,
                    step: 1,
                    formatter: { "RIR \(Int($0))" }
                )
                }

                if showTempo {
                TextField("Tempo", text: Binding(
                    get: { set.tempo ?? "" },
                    set: { set.tempo = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.never)
                .font(.subheadline)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .background(PulseTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }

            if let previousRestSeconds = set.previousRestSeconds {
                Label("\(previousRestSeconds)s descanso real previo", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private func setTypeTitle(_ type: SetLog.SetType) -> String {
        switch type {
        case .warmUp: "Calentamiento"
        case .work: "Trabajo"
        case .topSet: "Top set"
        case .backOff: "Back-off"
        case .dropSet: "Dropset"
        case .restPause: "Rest-pause"
        case .activation: "Activacion"
        case .failure: "Fallo"
        }
    }
}

private struct InlineStepper: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String

    var body: some View {
        HStack(spacing: 6) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
            }
            .accessibilityLabel("Bajar valor")

            Text(formatter(value))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(minWidth: 34)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Subir valor")
        }
        .buttonStyle(.plain)
        .foregroundStyle(PulseTheme.primary)
        .font(.subheadline.weight(.bold))
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

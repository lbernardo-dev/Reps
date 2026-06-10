import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
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
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer.shared
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var motionResumeDetector = WorkoutMotionResumeDetector()
    @State private var elapsedSeconds = 0
    @State private var pausedSeconds = 0
    @State private var startedAt = Date()
    @State private var lastPausedAt: Date? = nil
    @State private var basePausedSeconds = 0
    @State private var hasShownDurationAlert = false
    @State private var showDurationExhaustedAlert = false
    @State private var activeBookmark: ExerciseMediaBookmark?
    @State private var isPaused = false
    @State private var restSeconds = 0
    @State private var restStartedAt: Date? = nil   // ← date-based rest timing
    @State private var restDuration = 0              // duration when rest started
    @State private var finishedSession: WorkoutSession?
    @State private var selectedExerciseIndex = 0
    @State private var showAdvancedFields = false
    @State private var lastSetCompletedAtSeconds: Int?
    @State private var hasAppliedProgression = false
    @State private var showAddExercise = false
    @State private var replacementExerciseIndex: Int?
    @State private var sessionRPE = 7.0
    @State private var energyBefore = 3.0
    @State private var energyAfter = 3.0
    @State private var waterLiters = 0.0
    @State private var sessionNotes = ""
    @State private var sessionVoiceNote = ""
    @State private var sessionPhotoItems: [PhotosPickerItem] = []
    @State private var exercisePhotoItems: [PhotosPickerItem] = []
    @State private var sessionMediaAttachments: [WorkoutMediaAttachment] = []
    @State private var showPermissionDenied = false
    @State private var permissionDeniedMessage = ""
    @State private var showExerciseNotes = false
    @State private var showSessionFeedback = false
    @State private var showProPreferences = false
    @State private var showMissingExerciseAlert = false
    @State private var showStopConfirmation = false
    @State private var lastStatusPublishSecond = -1
    @State private var workoutSensorSummary: WorkoutSensorSummary?
    @State private var isFinishingWorkout = false
    @State private var showResumeSuggestion = false

    private var exerciseDrafts: [ExerciseSessionDraft] {
        get { store.activeWorkoutDrafts }
        nonmutating set { store.activeWorkoutDrafts = newValue }
    }

    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    private let origin: WorkoutSession.Origin

    init(workout: WorkoutDay, origin: WorkoutSession.Origin = .routine) {
        self.workout = workout
        self.origin = origin
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
        store.hasFeatureAccess(.configurableProgression) &&
        (store.userProfile.showSetType || store.userProfile.showRPE || store.userProfile.showRIR || store.userProfile.showTempo)
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

    private var currentBattery: FitnessMetrics.TrainingBatteryStatus {
        store.trainingBattery
    }

    private var projectedBatteryLevel: Int {
        store.projectedBattery(after: workout)
    }

    private var batteryColor: Color {
        switch currentBattery.state {
        case .charged:
            return PulseTheme.recovery
        case .steady:
            return PulseTheme.primary
        case .low:
            return PulseTheme.warning
        case .critical:
            return PulseTheme.destructive
        }
    }

    private var estimatedRemainingSeconds: Int {
        if setCompletion > 0 {
            let projected = Int(Double(elapsedSeconds) / max(setCompletion, 0.01))
            return max(projected - elapsedSeconds, 0)
        }
        return max((workout.durationMinutes * 60) - elapsedSeconds, 0)
    }

    private var currentWorkingSet: SetLog? {
        selectedDraft?.sets.first(where: { !$0.completed }) ?? selectedDraft?.sets.last
    }

    private var selectedTargetWeightKg: Double? {
        guard let set = currentWorkingSet, set.weightKg > 0 else { return nil }
        return set.weightKg
    }

    private var selectedPlateLoadSummary: String? {
        guard let selectedDraft,
              isBarbellLoadedExercise(selectedDraft.workoutExercise.exercise),
              let target = selectedTargetWeightKg else {
            return nil
        }

        return PlateLoadingCalculator.loadSummary(targetWeightKg: target)
    }

    private var selectedExerciseHistorySummary: String? {
        guard let exercise = selectedDraft?.workoutExercise.exercise else { return nil }
        let recent = recentSets(for: exercise).prefix(3)
        guard !recent.isEmpty else { return nil }
        if let best = recent.max(by: { ($0.weightKg * Double($0.reps)) < ($1.weightKg * Double($1.reps)) }) {
            return "Histórico: \(Int(best.weightKg)) kg x \(best.reps)"
        }
        return nil
    }

    private var selectedProgressionRecommendations: [SmartProgressionAdvisor.Recommendation] {
        guard let selectedDraft,
              let recommendation = SmartProgressionAdvisor.recommendation(
                for: selectedDraft.workoutExercise,
                sessions: store.workoutSessions,
                weightIncrementKg: store.userProfile.weightIncrementKg
              ) else {
            return []
        }

        return [recommendation]
    }

    private var selectedGymPass: GymPass? {
        store.gymPasses.first
    }

    private var currentRestLabel: LocalizedStringKey {
        guard lastSetCompletedAtSeconds != nil else {
            return "Descanso pendiente"
        }

        return restSeconds == 0 ? "Listo" : "Descanso"
    }

    private var isSessionStarted: Bool {
        store.activeWorkoutStatus != nil && store.activeWorkout?.id == workout.id
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
            handleTimerTick()
        }
        .onAppear {
            prepareWorkoutIfNeeded()
            applyAutoProgressionIfNeeded()
            if let status = store.activeWorkoutStatus, store.activeWorkout?.id == workout.id {
                elapsedSeconds = status.effectiveElapsedSeconds()
                pausedSeconds  = status.effectivePausedSeconds()
                isPaused       = status.isPaused
                waterLiters    = status.waterLiters ?? 0.0
                if let exerciseIndex = status.exerciseIndex {
                    selectedExerciseIndex = max(0, exerciseIndex - 1)
                }
                // Restore date-based rest state
                if let savedRest = status.restSeconds, savedRest > 0 {
                    let dur = status.restDurationSeconds ?? savedRest
                    restDuration   = dur
                    restStartedAt  = Date().addingTimeInterval(-Double(dur - savedRest))
                    restSeconds    = savedRest
                } else {
                    restSeconds    = 0
                    restStartedAt  = nil
                }
                startedAt          = status.startedAt
                lastPausedAt       = status.lastPausedAt
                basePausedSeconds  = status.pausedSeconds
            } else {
                elapsedSeconds = 0
                pausedSeconds = 0
                isPaused = false
                startedAt = Date()
                lastPausedAt = nil
                basePausedSeconds = 0
            }
            if isRouteCandidate {
                routeTracker.requestAuthorization()
            }
            if isSessionStarted {
                WorkoutBackgroundKeepAlive.shared.startIfNeeded()
            }
        }
        .onChange(of: sessionPhotoItems) { _, newItems in
            Task { await appendSessionPhotos(from: newItems) }
        }
        .onChange(of: exercisePhotoItems) { _, newItems in
            Task { await appendExercisePhotos(from: newItems) }
        }
        .sheet(item: $activeBookmark) { bookmark in
            VideoPlayerSheet(bookmark: bookmark)
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
        .sheet(isPresented: $showProPreferences) {
            ProPreferencesView()
        }
        .sensoryFeedback(.success, trigger: completedSets)
        .mainTabBarHidden()
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.musicToggle.notificationName)) { _ in
            guard let playlist = planPlaylist else { return }
            Task { await musicPlayer.playOrPause(playlist) }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.pause.notificationName)) { _ in
            setWorkoutPaused(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.resume.notificationName)) { _ in
            setWorkoutPaused(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.musicNext.notificationName)) { _ in
            Task { await musicPlayer.skipForward(planPlaylist) }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.musicPrevious.notificationName)) { _ in
            Task { await musicPlayer.skipBackward(planPlaylist) }
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.completeSet.notificationName)) { _ in
            completeNextAvailableSet()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.nextExercise.notificationName)) { _ in
            moveExercise(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.previousExercise.notificationName)) { _ in
            moveExercise(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.addWater.notificationName)) { _ in
            addWater()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchCommand.voiceNote.notificationName)) { _ in
            toggleSessionVoiceNoteFromWatch()
        }
        .onChange(of: selectedExerciseIndex) { _, _ in
            publishActiveWorkoutStatus()
        }
        .onReceive(motionResumeDetector.$shouldSuggestResume) { shouldSuggest in
            guard isRouteCandidate, isPaused, isSessionStarted else {
                showResumeSuggestion = false
                return
            }
            withAnimation(.snappy(duration: 0.24)) {
                showResumeSuggestion = shouldSuggest
            }
        }
        .alert("Permiso necesario", isPresented: $showPermissionDenied) {
            Button("Abrir Ajustes") {
                PermissionService.shared.openSettings()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(permissionDeniedMessage)
        }
        .alert("¿Has terminado?", isPresented: $showDurationExhaustedAlert) {
            Button("Finalizar entrenamiento", role: .destructive) {
                finishWorkout()
            }
            Button("Continuar", role: .cancel) {}
        } message: {
            Text("Has completado el tiempo planificado de tu entrenamiento (\(workout.durationMinutes) min).")
        }
        .alert("Añade al menos un ejercicio", isPresented: $showMissingExerciseAlert) {
            Button("Buscar ejercicio") {
                showAddExercise = true
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se puede iniciar una sesión sin ejercicios.")
        }
        .confirmationDialog("Detener sesión", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("Detener y descartar", role: .destructive) {
                stopWorkout()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se descartará esta sesión activa y los cambios no finalizados.")
        }
        .onDisappear {
            if finishedSession == nil {
                elapsedSeconds = elapsedWorkoutSeconds()
                restSeconds = currentRestRemainingSeconds()
                publishActiveWorkoutStatus()
            }
            routeTracker.stop()
            motionResumeDetector.stop()
            _ = audioRecorder.stopRecording(note: nil)
            // Only stop the background task if the workout is fully done.
            if finishedSession != nil {
                WorkoutBackgroundKeepAlive.shared.stop()
            }
        }
    }

    private var activeWorkoutContent: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 40, 0)
            ScrollView {
                LazyVStack(spacing: 18) {
                    workoutHeader
                        .frame(width: contentWidth)
                    if isRouteOnlySession {
                        routeProgressCard
                            .frame(width: contentWidth)
                    } else {
                        sessionProgressCard
                            .frame(width: contentWidth)
                    }
                    batteryCard
                        .frame(width: contentWidth)
                    if isRouteCandidate {
                        routeTrackingCard
                            .frame(width: contentWidth)
                    }

                    if isRouteOnlySession {
                        if isSessionStarted {
                            routeSessionControlCard
                                .frame(width: contentWidth)
                            routeSessionFeedbackCard
                                .frame(width: contentWidth)
                        }
                        liveRouteMapCard
                            .frame(width: contentWidth)
                    } else {
                        sessionExerciseOrderCard
                            .frame(width: contentWidth)
                        restCard
                            .frame(width: contentWidth)
                        exerciseSwitcher
                            .frame(width: contentWidth)
                        if !selectedProgressionRecommendations.isEmpty {
                            ProgressionRecommendationCard(
                                recommendations: selectedProgressionRecommendations,
                                language: store.userProfile.preferredLanguage,
                                title: store.userProfile.preferredLanguage.hasPrefix("es") ? "Siguiente ajuste" : "Next Adjustment"
                            )
                            .frame(width: contentWidth)
                        }
                        if exerciseDrafts.isEmpty {
                            emptyFreeWorkoutCard
                                .frame(width: contentWidth)
                        } else {
                            exerciseCard
                                .frame(width: contentWidth)
                        }
                        sessionControlCenterCard
                            .frame(width: contentWidth)
                        sessionFeedbackCard
                            .frame(width: contentWidth)
                        nextExerciseCard
                            .frame(width: contentWidth)
                    }
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
        HStack(alignment: .center, spacing: 10) {
            Button {
                if isSessionStarted {
                    showStopConfirmation = true
                } else {
                    stopWorkout()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .background(PulseTheme.grouped)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Volver")

            Text(RepsText.workoutTitle(workout.title, language: store.userProfile.preferredLanguage))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSessionStarted {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        setWorkoutPaused(!isPaused)
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(isPaused ? PulseTheme.primary : PulseTheme.warning)
                        .background(isPaused ? PulseTheme.primary.opacity(0.12) : PulseTheme.warning.opacity(0.15))
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                isPaused ? PulseTheme.primary.opacity(0.3) : PulseTheme.warning.opacity(0.4),
                                lineWidth: 1.5
                            )
                        )
                }
                .accessibilityLabel(isPaused ? "Reanudar entrenamiento" : "Pausar entrenamiento")
            }

            Button {
                if isSessionStarted {
                    finishWorkout()
                } else {
                    startPreparedSession()
                }
            } label: {
                Text(isFinishingWorkout ? "Guardando" : (isSessionStarted ? "Finalizar" : "Iniciar"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 90, height: 44)
                    .background(isSessionStarted ? PulseTheme.destructive : (canStartWorkout ? PulseTheme.primary : PulseTheme.secondaryText))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isFinishingWorkout || (!isSessionStarted && !canStartWorkout))
            .accessibilityHint(!isSessionStarted && !canStartWorkout ? "Añade al menos un ejercicio o usa una sesión de ruta" : "")
        }
        .padding(.top, 2)
    }

    private var canStartWorkout: Bool {
        !exerciseDrafts.isEmpty || isRouteCandidate
    }

    private var isRouteOnlySession: Bool {
        isRouteCandidate && exerciseDrafts.isEmpty
    }

    private func prepareWorkoutIfNeeded() {
        if store.activeWorkoutStatus != nil, store.activeWorkout?.id != workout.id {
            return
        }

        if store.activeWorkout?.id != workout.id {
            store.activeWorkout = workout
            store.activeWorkoutDrafts = Self.makeDrafts(for: workout)
        } else if store.activeWorkoutDrafts.isEmpty, !workout.exercises.isEmpty {
            store.activeWorkoutDrafts = Self.makeDrafts(for: workout)
        }
    }

    private func startPreparedSession() {
        guard canStartWorkout else {
            showMissingExerciseAlert = true
            return
        }

        startedAt = Date()
        elapsedSeconds = 0
        pausedSeconds = 0
        isPaused = false
        lastPausedAt = nil
        basePausedSeconds = 0
        lastStatusPublishSecond = -1
        workoutSensorSummary = nil
        if isRouteCandidate {
            routeTracker.start()
        }
        store.startPreparedActiveWorkout(workout, drafts: exerciseDrafts)
        WorkoutBackgroundKeepAlive.shared.startIfNeeded()
        publishActiveWorkoutStatus()
    }

    private func stopWorkout() {
        routeTracker.stop()
        motionResumeDetector.stop()
        stopRest()
        store.clearActiveWorkout()
        WorkoutBackgroundKeepAlive.shared.stop()
        dismiss()
    }

    private func finishWorkout() {
        guard !isFinishingWorkout else { return }
        guard isSessionStarted else {
            startPreparedSession()
            return
        }
        guard !exerciseDrafts.isEmpty || isRouteCandidate else {
            showMissingExerciseAlert = true
            return
        }
        isFinishingWorkout = true
        Task {
            await finishWorkoutAsync()
        }
    }

    private func finishWorkoutAsync() async {
        elapsedSeconds = elapsedWorkoutSeconds()
        let finishedAt = Date()
        routeTracker.stop()
        motionResumeDetector.stop()
        let startDate = startedAt
        let sensorSummary = try? await healthKit.fetchWorkoutSensorSummary(start: startDate, end: finishedAt)
        workoutSensorSummary = sensorSummary
        let logs = exerciseDrafts.compactMap { draft -> ExerciseLog? in
            let completedSets = draft.sets.filter(\.completed)
            guard !completedSets.isEmpty else {
                return nil
            }

            let attachments = draft.mediaAttachments + voiceAttachments(from: draft.voiceNote)
            return ExerciseLog(
                exercise: draft.workoutExercise.exercise,
                notes: draft.notes,
                sets: completedSets,
                mediaAttachments: attachments
            )
        }
        let allSets = logs.flatMap(\.sets)
        let sessionAttachments = sessionMediaAttachments + voiceAttachments(from: sessionVoiceNote)
        let sessionLocation: WorkoutSession.Location
        if isRouteCandidate {
            sessionLocation = .outdoor
        } else if origin == .free {
            switch store.userProfile.trainingLocation {
            case .home: sessionLocation = .home
            default: sessionLocation = .gym
            }
        } else {
            switch store.activePlan.location {
            case .home: sessionLocation = .home
            default: sessionLocation = .gym
            }
        }

        let session = WorkoutSession(
            workoutTitle: workout.title,
            date: finishedAt,
            startedAt: startDate,
            endedAt: finishedAt,
            origin: origin,
            location: sessionLocation,
            contextTag: .normal,
            durationMinutes: max(elapsedSeconds / 60, 1),
            sets: allSets,
            notes: sessionNotesText(from: logs),
            exerciseLogs: logs,
            sessionRPE: sessionRPE,
            energyBefore: Int(energyBefore),
            energyAfter: Int(energyAfter),
            estimatedCalories: sensorSummary?.activeEnergyKcal,
            mediaAttachments: sessionAttachments,
            routePoints: routeTracker.routePoints,
            pausedDurationSeconds: pausedSeconds,
            distanceKm: routeTracker.distanceKm > 0 ? routeTracker.distanceKm : nil,
            averagePaceSecondsPerKm: routeTracker.averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds),
            steps: sensorSummary?.steps,
            activeEnergyKcal: sensorSummary?.activeEnergyKcal,
            heartRateBefore: sensorSummary?.heartRateBefore,
            heartRateAfter: sensorSummary?.heartRateAfter,
            averageHeartRate: sensorSummary?.averageHeartRate,
            maxHeartRate: sensorSummary?.maxHeartRate
        )
        store.finishWorkout(session)
        if let cardioLog = cardioLog(from: session, sensorSummary: sensorSummary) {
            store.addCardioLog(cardioLog)
        }
        isFinishingWorkout = false
        dismiss()
    }

    private func cardioLog(from session: WorkoutSession, sensorSummary: WorkoutSensorSummary?) -> CardioLog? {
        guard isRouteCandidate else { return nil }

        let activityType: CardioLog.ActivityType
        switch workout.sessionType {
        case .cardioRun:
            activityType = .outdoorRun
        case .cardioWalk:
            activityType = .walking
        default:
            activityType = .other
        }

        return CardioLog(
            activityType: activityType,
            date: session.startedAt ?? session.date,
            durationMinutes: session.durationMinutes,
            distanceKm: session.distanceKm,
            averageSpeedKmh: routeTracker.averageSpeedKmh(elapsedSeconds: elapsedSeconds),
            averagePaceSecondsPerKm: session.averagePaceSecondsPerKm,
            averageHeartRate: sensorSummary?.averageHeartRate,
            maxHeartRate: sensorSummary?.maxHeartRate,
            estimatedCalories: sensorSummary?.activeEnergyKcal,
            steps: sensorSummary?.steps,
            activeEnergyKcal: sensorSummary?.activeEnergyKcal,
            heartRateBefore: sensorSummary?.heartRateBefore,
            heartRateAfter: sensorSummary?.heartRateAfter,
            rpe: session.sessionRPE,
            notes: session.notes,
            routePoints: session.routePoints
        )
    }

    private func publishActiveWorkoutStatus() {
        let currentSet = currentWorkingSet
        let playlist = planPlaylist
        store.updateActiveWorkout(
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: completedSets,
            totalSets: totalSets,
            volumeKg: totalVolume,
            isPaused: isPaused,
            exerciseName: selectedDraft.map { RepsText.exerciseName($0.workoutExercise.exercise.name, language: store.userProfile.preferredLanguage) },
            exerciseIndex: exerciseDrafts.isEmpty ? nil : selectedExerciseIndex + 1,
            totalExercises: exerciseDrafts.count,
            currentExerciseCompletedSets: selectedDraft?.sets.filter(\.completed).count,
            currentExerciseTotalSets: selectedDraft?.sets.count,
            currentSetWeightKg: currentSet?.weightKg,
            currentSetReps: currentSet?.reps,
            restSeconds: restSeconds,
            restDurationSeconds: currentRestDuration,
            estimatedRemainingSeconds: estimatedRemainingSeconds,
            waterLiters: waterLiters,
            musicTitle: musicPlayer.currentSongTitle ?? playlist?.title,
            musicArtist: musicPlayer.currentSongArtist ?? playlist?.provider.rawValue.capitalized,
            isMusicPlaying: playlist.map { $0.provider == .appleMusic ? musicPlayer.isPlaying : musicPlayer.isSpotifyPlaying },
            nextExerciseName: nextExerciseTitle,
            exerciseHistorySummary: selectedExerciseHistorySummary,
            gymPass: selectedGymPass,
            lastPausedAt: lastPausedAt,
            isRouteWorkout: isRouteCandidate,
            routeDistanceKm: isRouteCandidate ? routeTracker.distanceKm : nil,
            routePaceSecondsPerKm: isRouteCandidate ? routeTracker.averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds) : nil,
            routeSpeedKmh: isRouteCandidate ? routeTracker.averageSpeedKmh(elapsedSeconds: elapsedSeconds) : nil,
            routePointCount: isRouteCandidate ? routeTracker.routePoints.count : nil,
            routeSteps: workoutSensorSummary?.steps
        )
    }

    private func publishActiveWorkoutStatusIfNeeded(currentElapsedSeconds: Int? = nil) {
        let currentSecond = (currentElapsedSeconds ?? elapsedSeconds) + pausedSeconds
        guard currentSecond == 0 || currentSecond - lastStatusPublishSecond >= 5 else {
            return
        }

        if let currentElapsedSeconds {
            elapsedSeconds = currentElapsedSeconds
        }
        if restStartedAt != nil {
            restSeconds = currentRestRemainingSeconds()
        }
        lastStatusPublishSecond = currentSecond
        publishActiveWorkoutStatus()
    }

    private func handleTimerTick() {
        guard finishedSession == nil, isSessionStarted else { return }

        if let globalPaused = store.activeWorkoutStatus?.isPaused, globalPaused != isPaused {
            isPaused = globalPaused
            if isPaused {
                lastPausedAt = Date()
            } else {
                if let lastPaused = lastPausedAt {
                    basePausedSeconds += Int(Date().timeIntervalSince(lastPaused))
                }
                lastPausedAt = nil
            }
        }

        let currentElapsed = elapsedWorkoutSeconds()
        if isPaused {
            let currentPauseDuration = lastPausedAt.map { Date().timeIntervalSince($0) } ?? 0
            pausedSeconds = basePausedSeconds + Int(currentPauseDuration)
        } else {
            pausedSeconds = basePausedSeconds

            // Date-based rest countdown — survives background suspension.
            if let rsa = restStartedAt {
                let elapsed = Int(Date().timeIntervalSince(rsa))
                let remaining = max(restDuration - elapsed, 0)
                if remaining == 0 {
                    restSeconds = 0
                    restStartedAt = nil
                }
            }
        }

        // Comprobar si se ha agotado el tiempo planificado
        let targetSeconds = workout.durationMinutes * 60
        if currentElapsed >= targetSeconds, !hasShownDurationAlert {
            elapsedSeconds = currentElapsed
            hasShownDurationAlert = true
            showDurationExhaustedAlert = true
        }

        elapsedSeconds = currentElapsed
    }

    private func setWorkoutPaused(_ paused: Bool) {
        guard isSessionStarted else { return }
        elapsedSeconds = elapsedWorkoutSeconds()
        isPaused = paused
        if paused {
            lastPausedAt = Date()
            if isRouteCandidate {
                routeTracker.stop()
                motionResumeDetector.start()
            }
        } else {
            if let lastPaused = lastPausedAt {
                basePausedSeconds += Int(Date().timeIntervalSince(lastPaused))
            }
            lastPausedAt = nil
            if isRouteCandidate {
                routeTracker.start()
                motionResumeDetector.stop()
                showResumeSuggestion = false
            }
        }
        pausedSeconds = basePausedSeconds
        lastStatusPublishSecond = elapsedSeconds + pausedSeconds
        publishActiveWorkoutStatus()
    }

    private func elapsedWorkoutSeconds(at date: Date = Date()) -> Int {
        let effectiveDate = isPaused ? (lastPausedAt ?? date) : date
        return max(Int(effectiveDate.timeIntervalSince(startedAt)) - basePausedSeconds, 0)
    }

    private func currentRestRemainingSeconds(at date: Date = Date()) -> Int {
        guard let restStartedAt else {
            return restSeconds
        }
        return max(restDuration - Int(date.timeIntervalSince(restStartedAt)), 0)
    }

    private var sessionProgressCard: some View {
        PulseCard {
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    // Circular progress ring
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: setCompletion)
                            .stroke(PulseTheme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.snappy(duration: 0.35), value: setCompletion)
                        VStack(spacing: 0) {
                            Text("\(completedSets)")
                                .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundStyle(PulseTheme.accent)
                            Text("/\(totalSets)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isSessionStarted ? (isPaused ? "SESIÓN PAUSADA" : "SESIÓN ACTIVA") : "SESIÓN PREPARADA")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(isSessionStarted ? (isPaused ? PulseTheme.warning : PulseTheme.primary) : PulseTheme.secondaryText)
                        WorkoutElapsedText(
                            startedAt: startedAt,
                            basePausedSeconds: basePausedSeconds,
                            lastPausedAt: lastPausedAt,
                            isPaused: isPaused,
                            fallbackElapsedSeconds: elapsedSeconds
                        )
                        HStack(spacing: 6) {
                            Text("\(totalVolume) kg volumen")
                            if pausedSeconds > 0 {
                                Text("· pausa \(timeString(pausedSeconds))")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                }

                // Thicker gradient progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PulseTheme.grouped)
                            .frame(height: 8)
                        Capsule()
                            .fill(PulseTheme.accent)
                            .frame(width: max(geo.size.width * setCompletion, setCompletion > 0 ? 16 : 0), height: 8)
                            .animation(.snappy(duration: 0.35), value: setCompletion)
                    }
                }
                .frame(height: 8)

                // CTA with gradient + bounce feedback
                Button {
                    completeNextAvailableSet()
                 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: completedSets == totalSets ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                            .font(.title3.weight(.bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(completedSets == totalSets ? "Completado" : "Siguiente serie")
                                .font(.headline.weight(.bold))
                            if completedSets < totalSets {
                                Text(nextLoggingTitle)
                                    .font(.caption.weight(.semibold))
                                    .opacity(0.78)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.68)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(.black)
                    .background(PulseTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    .shadow(color: PulseTheme.accent.opacity(0.22), radius: 8, x: 0, y: 4)
                }
                .disabled(!isSessionStarted || completedSets == totalSets)
                .opacity(!isSessionStarted || completedSets == totalSets ? 0.55 : 1)

                if let playlist = planPlaylist {
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        // Artwork
                        if playlist.provider == .appleMusic {
                            if let artwork = musicPlayer.currentSongArtwork {
                                ArtworkImage(artwork, width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(PulseTheme.grouped)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "music.note")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        } else {
                            // Spotify
                            ZStack {
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.8, blue: 0.3), Color(red: 0.05, green: 0.35, blue: 0.12)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: 48, height: 48)
                                Image(systemName: "music.note")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        
                        // Text info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(playlist.provider == .appleMusic ? (musicPlayer.currentSongTitle ?? playlist.title) : (musicPlayer.isSpotifyPlaying ? (musicPlayer.currentSongTitle ?? playlist.title) : playlist.title))
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text(playlist.provider == .appleMusic ? (musicPlayer.currentSongArtist ?? musicPlayer.statusText(for: playlist)) : (musicPlayer.isSpotifyPlaying ? (musicPlayer.currentSongArtist ?? "Spotify") : "Spotify"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 8)
                        
                        // Player Controls
                        HStack(spacing: 16) {
                            Button {
                                Task { await musicPlayer.skipBackward(playlist) }
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(PulseTheme.primary)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                Task { await musicPlayer.playOrPause(playlist) }
                            } label: {
                                let isPlaying = playlist.provider == .appleMusic ? musicPlayer.isPlaying : musicPlayer.isSpotifyPlaying
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 38, height: 38)
                                    .background(playlist.provider == .appleMusic ? Color.pink : Color.green)
                                    .clipShape(Circle())
                                    .shadow(color: (playlist.provider == .appleMusic ? Color.pink : Color.green).opacity(0.35), radius: 6, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                Task { await musicPlayer.skipForward(playlist) }
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(PulseTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var batteryCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: Double(currentBattery.level) / 100)
                            .stroke(batteryColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: currentBattery.systemImage)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(batteryColor)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("BATERÍA DE ENTRENO")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(batteryColor)
                        Text("\(currentBattery.level)% ahora · \(projectedBatteryLevel)% al terminar")
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(currentBattery.suggestion)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    BatteryMicroMetric(title: "Fatiga", value: "\(Int(currentBattery.fatigueLoad.rounded()))", systemImage: "bolt.slash", color: PulseTheme.destructive)
                    BatteryMicroMetric(title: "Recarga", value: "+\(Int(currentBattery.recoveryCredit.rounded()))", systemImage: "bed.double", color: PulseTheme.accent)
                    BatteryMicroMetric(title: "Plan", value: "\(Int(currentBattery.planPressure.rounded()))", systemImage: "calendar", color: PulseTheme.warning)
                }
            }
        }
    }

    private var exerciseSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(exerciseDrafts.indices, id: \.self) { index in
                    let draft = exerciseDrafts[index]
                    let isActive = selectedExerciseIndex == index
                    let completedCount = draft.sets.filter(\.completed).count
                    let totalCount = draft.sets.count
                    let ratio: Double = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedExerciseIndex = index
                        }
                    } label: {
                        HStack(spacing: 10) {
                            NavigationLink {
                                ExerciseProgressView(exercise: draft.workoutExercise.exercise)
                            } label: {
                                ExerciseMediaThumbnail(
                                    exercise: draft.workoutExercise.exercise,
                                    gender: store.userProfile.muscleMapGender,
                                    fallbackSize: .caption.weight(.bold)
                                )
                                .equatable()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    ZStack {
                                        Circle()
                                            .fill(isActive ? PulseTheme.accentMuted : PulseTheme.card)
                                            .frame(width: 18, height: 18)
                                        Circle()
                                            .trim(from: 0, to: ratio)
                                            .stroke(isActive ? PulseTheme.accent : PulseTheme.primaryBright, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 14, height: 14)
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1). \(RepsText.exerciseName(draft.workoutExercise.exercise.name, language: store.userProfile.preferredLanguage))")
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.68)
                                Text("\(completedCount)/\(totalCount) series")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(width: 180, alignment: .leading)
                        .background(isActive ? PulseTheme.accentMuted : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(isActive ? PulseTheme.accent.opacity(0.55) : Color.white.opacity(0.04), lineWidth: 1.5)
                        )
                        .shadow(color: isActive ? PulseTheme.accent.opacity(0.14) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var sessionExerciseOrderCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Orden de ejercicios", systemImage: "arrow.up.arrow.down")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Añadir", systemImage: "plus")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PulseTheme.primary)
                }

                if exerciseDrafts.isEmpty {
                    Text("Añade al menos un ejercicio para poder iniciar la sesión.")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(exerciseDrafts.enumerated()), id: \.element.workoutExercise.id) { index, draft in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.black).monospacedDigit())
                                    .foregroundStyle(PulseTheme.primary)
                                    .frame(width: 26, height: 26)
                                    .background(PulseTheme.primary.opacity(0.12))
                                    .clipShape(Circle())

                                Text(RepsText.exerciseName(draft.workoutExercise.exercise.name, language: store.userProfile.preferredLanguage))
                                    .font(.subheadline.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Spacer()

                                Button {
                                    moveDraft(from: index, to: index - 1)
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .frame(width: 32, height: 32)
                                }
                                .disabled(index == 0)

                                Button {
                                    moveDraft(from: index, to: index + 1)
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .frame(width: 32, height: 32)
                                }
                                .disabled(index == exerciseDrafts.count - 1)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 44)
                            .background(selectedExerciseIndex == index ? PulseTheme.accentMuted : PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var restCard: some View {
        PulseCard {
            if lastSetCompletedAtSeconds == nil {
                // Inactive — compact placeholder
                HStack(spacing: 14) {
                    Image(systemName: "hourglass")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PulseTheme.tertiaryText)
                        .frame(width: 44, height: 44)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Descanso")
                            .font(.headline.weight(.bold))
                        Text("Completa una serie para activar")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                }
            } else {
                // Active countdown ring
                let currentRestSeconds = currentRestRemainingSeconds()

                HStack(spacing: 18) {
                    RestCountdownRing(
                        restStartedAt: restStartedAt,
                        restDuration: restDuration,
                        fallbackRestSeconds: currentRestSeconds
                    )
                    .frame(width: 78, height: 78)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(currentRestSeconds == 0 ? "Listo para continuar" : "Descansando")
                            .font(.headline.weight(.bold))
                        Text(currentRestSeconds == 0 ? "La batería deja de recargar cuando saltas el descanso." : "Completar el descanso reduce la fatiga de la siguiente serie.")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.snappy(duration: 0.18)) {
                                    let remaining = currentRestRemainingSeconds()
                                    // Shift anchor forward 15 s so remaining decreases.
                                    if let rsa = restStartedAt {
                                        restStartedAt = rsa.addingTimeInterval(-15)
                                        restSeconds = max(0, remaining - 15)
                                    } else {
                                        restSeconds = max(0, remaining - 15)
                                    }
                                }
                            } label: {
                                Text("−15s")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .foregroundStyle(PulseTheme.primary)
                                    .background(PulseTheme.primary.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .accessibilityLabel("Reducir descanso 15 segundos")

                            Button {
                                withAnimation(.snappy(duration: 0.18)) {
                                    let remaining = currentRestRemainingSeconds()
                                    // Shift anchor backward 15 s so remaining increases.
                                    if let rsa = restStartedAt {
                                        restStartedAt = rsa.addingTimeInterval(15)
                                        restSeconds = min(600, remaining + 15)
                                    } else {
                                        startRest(duration: 15)
                                    }
                                }
                            } label: {
                                Text("+15s")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 38)
                                    .foregroundStyle(PulseTheme.primary)
                                    .background(PulseTheme.primary.opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .accessibilityLabel("Ampliar descanso 15 segundos")

                            Button(currentRestSeconds == 0 ? "Reiniciar" : "Saltar") {
                                if currentRestRemainingSeconds() == 0 {
                                    startRest(duration: currentRestDuration)
                                } else {
                                    stopRest()
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(PulseTheme.grouped)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityLabel(currentRestSeconds == 0 ? "Reiniciar descanso" : "Saltar descanso")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var routeProgressCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: routeDurationProgress)
                            .stroke(routeProgressColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.snappy(duration: 0.35), value: routeDurationProgress)
                        Image(systemName: routeProgressIcon)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(routeProgressColor)
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(routeProgressStatus)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(routeProgressColor)

                        if isSessionStarted {
                            WorkoutElapsedText(
                                startedAt: startedAt,
                                basePausedSeconds: basePausedSeconds,
                                lastPausedAt: lastPausedAt,
                                isPaused: isPaused,
                                fallbackElapsedSeconds: elapsedSeconds
                            )
                        } else {
                            Text("00:00")
                                .font(.system(size: 42, weight: .black, design: .rounded).monospacedDigit())
                        }

                        Text(routeProgressSubtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(PulseTheme.grouped)
                            .frame(height: 8)
                        Capsule()
                            .fill(routeProgressColor)
                            .frame(width: max(geo.size.width * routeDurationProgress, routeDurationProgress > 0 ? 16 : 0), height: 8)
                            .animation(.snappy(duration: 0.35), value: routeDurationProgress)
                    }
                }
                .frame(height: 8)

                if !isSessionStarted {
                    Label("Pulsa Iniciar arriba para empezar a registrar GPS, distancia y sensores.", systemImage: "location.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }

    private var routeDurationProgress: Double {
        guard workout.durationMinutes > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(workout.durationMinutes * 60), 1)
    }

    private var routeProgressColor: Color {
        if !isSessionStarted { return PulseTheme.secondaryText }
        return isPaused ? PulseTheme.warning : PulseTheme.primary
    }

    private var routeProgressIcon: String {
        if !isSessionStarted { return "location" }
        return isPaused ? "pause.fill" : "figure.walk"
    }

    private var routeProgressStatus: String {
        if !isSessionStarted { return "RUTA PREPARADA" }
        return isPaused ? "RUTA PAUSADA" : "RUTA ACTIVA"
    }

    private var routeProgressSubtitle: String {
        if !isSessionStarted {
            return "\(workout.durationMinutes) min planificados"
        }
        var parts = [
            String(format: "%.2f km", routeTracker.distanceKm),
            routeTracker.paceText(elapsedSeconds: elapsedSeconds)
        ]
        if pausedSeconds > 0 {
            parts.append("pausa \(timeString(pausedSeconds))")
        }
        return parts.joined(separator: " · ")
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
                    Text(routeTrackerStatusBadge)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(routeTracker.isTracking ? PulseTheme.primary : PulseTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background((routeTracker.isTracking ? PulseTheme.primary : PulseTheme.secondaryText).opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Distancia", value: String(format: "%.2f km", routeTracker.distanceKm), icon: "point.topleft.down.curvedto.point.bottomright.up")
                    MiniSessionPill(title: "Puntos", value: "\(routeTracker.routePoints.count)", icon: "map.fill")
                    MiniSessionPill(title: "Ritmo", value: routeTracker.paceText(elapsedSeconds: elapsedSeconds), icon: "speedometer")
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Velocidad", value: routeTracker.speedText(elapsedSeconds: elapsedSeconds), icon: "gauge.with.needle")
                    MiniSessionPill(title: "Pasos", value: workoutSensorSummary?.steps.map { "\(Int($0))" } ?? "--", icon: "shoeprints.fill")
                    MiniSessionPill(title: "Pulso", value: workoutSensorSummary?.averageHeartRate.map { "\(Int($0)) lpm" } ?? "--", icon: "heart.fill")
                }
            }
        }
    }

    private var liveRouteMapCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Mapa en vivo", systemImage: "map.fill")
                        .font(.headline)
                    Spacer()
                    Text(routeTracker.routePoints.isEmpty ? "Esperando GPS" : "\(routeTracker.routePoints.count) puntos")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                ZStack {
                    RouteMapPreview(routePoints: routeTracker.routePoints)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    if routeTracker.routePoints.count < 2 {
                        VStack(spacing: 10) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PulseTheme.primary)
                            Text(isSessionStarted ? "La ruta se dibujará aquí en cuanto entren puntos GPS." : "Al iniciar, la ruta se irá dibujando aquí.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 18)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
            }
        }
    }

    private var routeTrackerStatusBadge: String {
        if routeTracker.isTracking { return "GPS activo" }
        if isSessionStarted && isPaused { return "Pausado" }
        if isSessionStarted { return "GPS listo" }
        return "Listo"
    }



    private var exerciseCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    if let exercise = selectedDraft?.workoutExercise.exercise {
                        NavigationLink {
                            ExerciseProgressView(exercise: exercise)
                        } label: {
                            ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender)
                                .equatable()
                                .frame(width: 92, height: 104)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                        .stroke(PulseTheme.separator, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
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

                        Button {
                            if selectedExerciseIndex < exerciseDrafts.count - 1 {
                                withAnimation(.snappy) {
                                    selectedExerciseIndex += 1
                                }
                            }
                        } label: {
                            Label("Saltar ejercicio", systemImage: "forward.end")
                        }

                        Divider()

                        Button(role: .destructive) {
                            if exerciseDrafts.count > 1 {
                                withAnimation(.snappy(duration: 0.24)) {
                                    exerciseDrafts.remove(at: selectedExerciseIndex)
                                    selectedExerciseIndex = max(0, min(selectedExerciseIndex, exerciseDrafts.count - 1))
                                    syncActiveWorkoutExercises()
                                    publishActiveWorkoutStatus()
                                }
                            } else {
                                withAnimation(.snappy(duration: 0.24)) {
                                    exerciseDrafts.removeAll()
                                    selectedExerciseIndex = 0
                                    syncActiveWorkoutExercises()
                                    publishActiveWorkoutStatus()
                                }
                            }
                        } label: {
                            Label("Quitar de la sesión", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                executionSummaryStrip

                activeWorkoutToolsCard

                if !selectedMediaBookmarks.isEmpty {
                    ExerciseBookmarkStrip(bookmarks: selectedMediaBookmarks, activeBookmark: $activeBookmark)
                }

                if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                    let sets = exerciseDrafts.indices.contains(selectedExerciseIndex) ? exerciseDrafts[selectedExerciseIndex].sets : []
                    ForEach(sets.indices, id: \.self) { setIndex in
                        SetRow(set: Binding(
                            get: {
                                guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                                      exerciseDrafts[selectedExerciseIndex].sets.indices.contains(setIndex) else {
                                    return SetLog(setNumber: setIndex + 1, weightKg: 0, reps: 0, completed: false)
                                }
                                return exerciseDrafts[selectedExerciseIndex].sets[setIndex]
                            },
                            set: { newValue in
                                guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                                      exerciseDrafts[selectedExerciseIndex].sets.indices.contains(setIndex) else {
                                    return
                                }
                                exerciseDrafts[selectedExerciseIndex].sets[setIndex] = newValue
                            }
                        )) { completed in
                            guard completed else { return }
                            handleSetCompleted(exerciseIndex: selectedExerciseIndex, setIndex: setIndex)
                        }
                        .disabled(!isSessionStarted)
                    }
                }

                if hasVisibleAdvancedFields {
                    DisclosureGroup(isExpanded: $showAdvancedFields) {
                        if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                            let sets = exerciseDrafts.indices.contains(selectedExerciseIndex) ? exerciseDrafts[selectedExerciseIndex].sets : []
                            VStack(spacing: 10) {
                                ForEach(sets.indices, id: \.self) { setIndex in
                                    AdvancedSetFields(set: Binding(
                                        get: {
                                            guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                                                  exerciseDrafts[selectedExerciseIndex].sets.indices.contains(setIndex) else {
                                                return SetLog(setNumber: setIndex + 1, weightKg: 0, reps: 0, completed: false)
                                            }
                                            return exerciseDrafts[selectedExerciseIndex].sets[setIndex]
                                        },
                                        set: { newValue in
                                            guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                                                  exerciseDrafts[selectedExerciseIndex].sets.indices.contains(setIndex) else {
                                                return
                                            }
                                            exerciseDrafts[selectedExerciseIndex].sets[setIndex] = newValue
                                        }
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
                } else {
                    Button {
                        if store.requireFeature(.configurableProgression, source: .workoutAdvancedFields) {
                            showProPreferences = true
                        }
                    } label: {
                        HStack {
                            Label("Campos Pro", systemImage: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            Text("Activar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                DisclosureGroup(isExpanded: $showExerciseNotes) {
                    VStack(alignment: .leading, spacing: 10) {
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

                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    if audioRecorder.isRecording {
                                        if let attachment = audioRecorder.stopRecording(note: selectedDraft?.voiceNote),
                                           exerciseDrafts.indices.contains(selectedExerciseIndex) {
                                            exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(attachment)
                                        }
                                    } else {
                                        let granted = await PermissionService.shared.requestMicrophone()
                                        if granted {
                                            audioRecorder.startRecording()
                                        } else {
                                            permissionDeniedMessage = PermissionService.shared.deniedMessage ?? "El micrófono está bloqueado. Actiúva en Ajustes → Reps."
                                            showPermissionDenied = true
                                        }
                                    }
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

                            MediaSourceMenu(
                                maxSelectionCount: 6,
                                photoPickerItems: $exercisePhotoItems,
                                onCameraCapture: { image in
                                    guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                                          let data = image.jpegData(compressionQuality: 0.82) else { return }
                                    exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(
                                        WorkoutMediaAttachment(kind: .image, data: data)
                                    )
                                }
                            ) {
                                Image(systemName: "camera.fill")
                                    .font(.headline)
                                    .frame(width: 46, height: 46)
                                    .foregroundStyle(PulseTheme.primary)
                                    .background(PulseTheme.primary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                        }

                        if let attachments = selectedDraft?.mediaAttachments, !attachments.isEmpty {
                            AttachmentPreviewStrip(attachments: attachments)
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Label("Notas y media", systemImage: "note.text")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.primary)
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
        }
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

    private var sessionControlCenterCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Central de sesión", systemImage: "applewatch.radiowaves.left.and.right")
                        .font(.headline)
                    Spacer()
                    Label("Sync Watch", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Restante", value: timeString(estimatedRemainingSeconds), icon: "hourglass")
                    MiniSessionPill(title: "Agua", value: String(format: "%.2f L", waterLiters), icon: "waterbottle.fill")
                    MiniSessionPill(title: "Kcal", value: store.todayHealthMetric.map { "\(Int($0.activeEnergyKcal))" } ?? "--", icon: "flame.fill")
                }

                HStack(spacing: 10) {
                    Button {
                        moveExercise(by: -1)
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.headline.weight(.bold))
                            .frame(width: 48, height: 48)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(selectedExerciseIndex == 0)

                    Button {
                        addWater()
                    } label: {
                        Label("+250 ml", systemImage: "waterbottle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.white)
                            .background(PulseTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    Button {
                        moveExercise(by: 1)
                    } label: {
                        Image(systemName: "chevron.forward")
                            .font(.headline.weight(.bold))
                            .frame(width: 48, height: 48)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(exerciseDrafts.isEmpty || selectedExerciseIndex >= exerciseDrafts.count - 1)
                }

                if let selectedExerciseHistorySummary {
                    Label(selectedExerciseHistorySummary, systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if let pass = selectedGymPass {
                    ActiveGymPassCard(pass: pass)
                }
            }
        }
    }

    private var routeSessionControlCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Control de ruta", systemImage: "figure.walk")
                        .font(.headline)
                    Spacer()
                    Label(routeTracker.isTracking ? "GPS activo" : (isPaused ? "Pausado" : "GPS listo"), systemImage: routeTracker.isTracking ? "location.fill" : "pause.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(routeTracker.isTracking ? PulseTheme.primary : PulseTheme.warning)
                }

                if showResumeSuggestion {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.black)
                            .frame(width: 34, height: 34)
                            .background(PulseTheme.accent)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Movimiento detectado")
                                .font(.subheadline.weight(.bold))
                            Text("Reanuda para seguir sumando ruta y distancia.")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        Button("Reanudar") {
                            setWorkoutPaused(false)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(PulseTheme.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Tiempo", value: timeString(elapsedSeconds), icon: "timer")
                    MiniSessionPill(title: "Distancia", value: String(format: "%.2f km", routeTracker.distanceKm), icon: "point.topleft.down.curvedto.point.bottomright.up")
                    MiniSessionPill(title: "Ritmo", value: routeTracker.paceText(elapsedSeconds: elapsedSeconds), icon: "speedometer")
                }

                HStack(spacing: 10) {
                    Button {
                        setWorkoutPaused(!isPaused)
                    } label: {
                        Label(isPaused ? "Reanudar" : "Pausar", systemImage: isPaused ? "play.fill" : "pause.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(isPaused ? .black : .white)
                            .background(isPaused ? PulseTheme.accent : PulseTheme.warning)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .disabled(!isSessionStarted)

                    Button {
                        addWater()
                    } label: {
                        Label("+250 ml", systemImage: "waterbottle.fill")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
                    MiniSessionPill(title: "Agua", value: String(format: "%.2f L", waterLiters), icon: "waterbottle.fill")
                    MiniSessionPill(title: "Kcal", value: workoutSensorSummary?.activeEnergyKcal.map { "\(Int($0))" } ?? store.todayHealthMetric.map { "\(Int($0.activeEnergyKcal))" } ?? "--", icon: "flame.fill")
                    MiniSessionPill(title: "Pulso", value: workoutSensorSummary?.averageHeartRate.map { "\(Int($0)) lpm" } ?? "--", icon: "heart.fill")
                }
            }
        }
    }

    private var routeSessionFeedbackCard: some View {
        PulseCard {
            DisclosureGroup(isExpanded: $showSessionFeedback) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 18) {
                        HStack {
                            Label("Esfuerzo (RPE)", systemImage: "flame.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $sessionRPE,
                                range: 1...10,
                                step: 0.5,
                                formatter: { String(format: "%.1f", $0) }
                            )
                            .frame(width: 156)
                        }

                        Divider()

                        HStack {
                            Label("Energía antes", systemImage: "battery.50")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $energyBefore,
                                range: 1...5,
                                step: 1,
                                formatter: { "\(Int($0))/5" }
                            )
                            .frame(width: 156)
                        }

                        Divider()

                        HStack {
                            Label("Energía después", systemImage: "battery.100")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $energyAfter,
                                range: 1...5,
                                step: 1,
                                formatter: { "\(Int($0))/5" }
                            )
                            .frame(width: 156)
                        }
                    }
                    .padding(.vertical, 4)

                    TextField("Notas de ruta, molestias o terreno", text: $sessionNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                if audioRecorder.isRecording {
                                    if let attachment = audioRecorder.stopRecording(note: sessionVoiceNote) {
                                        sessionMediaAttachments.append(attachment)
                                    }
                                } else {
                                    let granted = await PermissionService.shared.requestMicrophone()
                                    if granted {
                                        audioRecorder.startRecording()
                                    } else {
                                        permissionDeniedMessage = PermissionService.shared.deniedMessage ?? "El micrófono está bloqueado. Actívalo en Ajustes → Reps."
                                        showPermissionDenied = true
                                    }
                                }
                            }
                        } label: {
                            Label(audioRecorder.isRecording ? "Guardar audio" : "Nota de voz", systemImage: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(audioRecorder.isRecording ? .white : PulseTheme.primary)
                                .background(audioRecorder.isRecording ? Color.red : PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }

                        MediaSourceMenu(
                            maxSelectionCount: 8,
                            photoPickerItems: $sessionPhotoItems,
                            onCameraCapture: { image in
                                guard let data = image.jpegData(compressionQuality: 0.82) else { return }
                                sessionMediaAttachments.append(
                                    WorkoutMediaAttachment(kind: .image, data: data)
                                )
                            }
                        ) {
                            Label("\(sessionMediaAttachments.filter { $0.kind == .image }.count)", systemImage: "photo.badge.plus")
                                .font(.headline)
                                .frame(width: 72, height: 48)
                                .foregroundStyle(PulseTheme.primary)
                                .background(PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    if !sessionMediaAttachments.isEmpty {
                        AttachmentPreviewStrip(attachments: sessionMediaAttachments)
                    }
                }
                .padding(.top, 12)
            } label: {
                Label("Cierre de ruta", systemImage: "flag.checkered")
                    .font(.headline)
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

    private var activeWorkoutToolsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Label("Herramientas de serie", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)
                Spacer()
                if let selectedPlateLoadSummary {
                    Text("Lado: \(selectedPlateLoadSummary)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                workoutToolButton(title: "Warm-up", systemImage: "flame.fill") {
                    insertWarmUpSetsForSelectedExercise()
                }
                .disabled(!canInsertWarmUpSets)

                workoutToolButton(title: "Back-off", systemImage: "arrow.down.forward.circle.fill") {
                    appendBackOffSetToSelectedExercise()
                }
                .disabled(!canAppendAdvancedSet)

                workoutToolButton(title: "Dropset", systemImage: "arrow.down.circle.fill") {
                    appendDropSetToSelectedExercise()
                }
                .disabled(!canAppendAdvancedSet)
            }

            Text(activeWorkoutToolsCaption)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private func workoutToolButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(PulseTheme.primary)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var activeWorkoutToolsCaption: String {
        if selectedPlateLoadSummary != nil {
            return "Carga recomendada por lado con barra de 20 kg. Los botones insertan series especiales sin cerrar el entrenamiento."
        }

        if canAppendAdvancedSet {
            return "Inserta calentamientos, back-off o dropsets desde la misma pantalla y deja el tipo de serie registrado."
        }

        return "Añade peso a la serie objetivo para activar herramientas de calentamiento y carga."
    }

    private var canInsertWarmUpSets: Bool {
        guard let selectedDraft, let target = selectedTargetWeightKg else { return false }
        return target >= 20 && !selectedDraft.sets.contains(where: { $0.setType == .warmUp })
    }

    private var canAppendAdvancedSet: Bool {
        selectedDraft?.sets.isEmpty == false && selectedTargetWeightKg != nil
    }

    private var sessionFeedbackCard: some View {
        PulseCard {
            DisclosureGroup(isExpanded: $showSessionFeedback) {
                VStack(alignment: .leading, spacing: 14) {
                    // Spacious vertical list for RPE + energy
                    VStack(spacing: 18) {
                        HStack {
                            Label("Esfuerzo (RPE)", systemImage: "flame.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $sessionRPE,
                                range: 1...10,
                                step: 0.5,
                                formatter: { String(format: "%.1f", $0) }
                            )
                            .frame(width: 156)
                        }

                        Divider()

                        HStack {
                            Label("Energía antes", systemImage: "battery.50")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $energyBefore,
                                range: 1...5,
                                step: 1,
                                formatter: { "\(Int($0))/5" }
                            )
                            .frame(width: 156)
                        }

                        Divider()

                        HStack {
                            Label("Energía después", systemImage: "battery.100")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            Spacer()
                            InlineStepper(
                                value: $energyAfter,
                                range: 1...5,
                                step: 1,
                                formatter: { "\(Int($0))/5" }
                            )
                            .frame(width: 156)
                        }
                    }
                    .padding(.vertical, 4)

                    TextField("Notas globales, molestias o contexto", text: $sessionNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                if audioRecorder.isRecording {
                                    if let attachment = audioRecorder.stopRecording(note: sessionVoiceNote) {
                                        sessionMediaAttachments.append(attachment)
                                    }
                                } else {
                                    let granted = await PermissionService.shared.requestMicrophone()
                                    if granted {
                                        audioRecorder.startRecording()
                                    } else {
                                        permissionDeniedMessage = PermissionService.shared.deniedMessage ?? "El micrófono está bloqueado. Actiúva en Ajustes → Reps."
                                        showPermissionDenied = true
                                    }
                                }
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

                        MediaSourceMenu(
                            maxSelectionCount: 8,
                            photoPickerItems: $sessionPhotoItems,
                            onCameraCapture: { image in
                                guard let data = image.jpegData(compressionQuality: 0.82) else { return }
                                sessionMediaAttachments.append(
                                    WorkoutMediaAttachment(kind: .image, data: data)
                                )
                            }
                        ) {
                            Label("\(sessionMediaAttachments.filter { $0.kind == .image }.count)", systemImage: "photo.badge.plus")
                                .font(.headline)
                                .frame(width: 72, height: 48)
                                .foregroundStyle(PulseTheme.primary)
                                .background(PulseTheme.primary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                    }

                    if !sessionMediaAttachments.isEmpty {
                        AttachmentPreviewStrip(attachments: sessionMediaAttachments)
                    }
                }
                .padding(.top, 12)
            } label: {
                Label("Cierre de sesión", systemImage: "waveform.path.ecg")
                    .font(.headline)
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
        guard store.hasFeatureAccess(.configurableProgression),
              store.userProfile.autoProgressionEnabled,
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
        guard isSessionStarted else {
            startPreparedSession()
            return
        }
        guard let next = nextIncompleteSet else {
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedExerciseIndex = next.exerciseIndex
            exerciseDrafts[next.exerciseIndex].sets[next.setIndex].completed = true
            handleSetCompleted(exerciseIndex: next.exerciseIndex, setIndex: next.setIndex)
        }
    }

    private func moveExercise(by offset: Int) {
        guard !exerciseDrafts.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            selectedExerciseIndex = min(max(selectedExerciseIndex + offset, 0), exerciseDrafts.count - 1)
        }
    }

    private func addWater() {
        guard isSessionStarted else {
            startPreparedSession()
            return
        }
        withAnimation(.snappy(duration: 0.18)) {
            waterLiters = min(waterLiters + 0.25, 8)
        }
        publishActiveWorkoutStatus()
    }

    private func moveDraft(from source: Int, to destination: Int) {
        guard exerciseDrafts.indices.contains(source),
              exerciseDrafts.indices.contains(destination),
              source != destination else {
            return
        }

        let selectedID = selectedDraft?.workoutExercise.id
        withAnimation(.snappy(duration: 0.22)) {
            let draft = exerciseDrafts.remove(at: source)
            exerciseDrafts.insert(draft, at: destination)
            if let selectedID,
               let newIndex = exerciseDrafts.firstIndex(where: { $0.workoutExercise.id == selectedID }) {
                selectedExerciseIndex = newIndex
            } else {
                selectedExerciseIndex = min(max(destination, 0), exerciseDrafts.count - 1)
            }
        }
        syncActiveWorkoutExercises()
        publishActiveWorkoutStatus()
    }

    private func toggleSessionVoiceNoteFromWatch() {
        showSessionFeedback = true
        Task {
            if audioRecorder.isRecording {
                if let attachment = audioRecorder.stopRecording(note: sessionVoiceNote) {
                    sessionMediaAttachments.append(attachment)
                }
                publishActiveWorkoutStatus()
            } else {
                let granted = await PermissionService.shared.requestMicrophone()
                if granted {
                    audioRecorder.startRecording()
                } else {
                    permissionDeniedMessage = PermissionService.shared.deniedMessage ?? "El micrófono está bloqueado. Actívalo en Ajustes → Reps."
                    showPermissionDenied = true
                }
            }
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
        syncActiveWorkoutExercises()
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
        syncActiveWorkoutExercises()
    }

    private func syncActiveWorkoutExercises() {
        if var activeWorkout = store.activeWorkout {
            activeWorkout.exercises = exerciseDrafts.map(\.workoutExercise)
            store.activeWorkout = activeWorkout
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

    private func insertWarmUpSetsForSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                  let targetSet = currentWorkingSet,
                  targetSet.weightKg >= 20,
                  !exerciseDrafts[selectedExerciseIndex].sets.contains(where: { $0.setType == .warmUp }) else {
                return
            }

            let warmUps = WorkoutSetBuilder.warmUpSets(
                targetWeightKg: targetSet.weightKg,
                targetReps: targetSet.reps
            )
            guard !warmUps.isEmpty else { return }

            let existing = exerciseDrafts[selectedExerciseIndex].sets
            let firstWorkIndex = existing.firstIndex { $0.setType != .warmUp } ?? 0
            let updated = Array(existing[..<firstWorkIndex]) + warmUps + Array(existing[firstWorkIndex...])
            exerciseDrafts[selectedExerciseIndex].sets = WorkoutSetBuilder.renumbered(updated)
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private func appendDropSetToSelectedExercise() {
        appendSpecialSet { WorkoutSetBuilder.dropSet(after: $0) }
    }

    private func appendBackOffSetToSelectedExercise() {
        appendSpecialSet { WorkoutSetBuilder.backOffSet(after: $0) }
    }

    private func appendSpecialSet(_ build: (SetLog) -> SetLog) {
        withAnimation(.snappy(duration: 0.25)) {
            guard exerciseDrafts.indices.contains(selectedExerciseIndex),
                  let reference = exerciseDrafts[selectedExerciseIndex].sets.last(where: { $0.weightKg > 0 }) ?? exerciseDrafts[selectedExerciseIndex].sets.last else {
                return
            }

            var next = build(reference)
            next.completed = false
            exerciseDrafts[selectedExerciseIndex].sets.append(next)
            exerciseDrafts[selectedExerciseIndex].sets = WorkoutSetBuilder.renumbered(exerciseDrafts[selectedExerciseIndex].sets)
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private func isBarbellLoadedExercise(_ exercise: Exercise) -> Bool {
        let searchable = "\(exercise.name) \(exercise.equipment) \(exercise.requiredEquipment.joined(separator: " "))"
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        return searchable.contains("barbell") ||
            searchable.contains("barra") ||
            searchable.contains("smith")
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

        elapsedSeconds = elapsedWorkoutSeconds()
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
            startRest(duration: exerciseDrafts[exerciseIndex].workoutExercise.restSeconds)
            exerciseDrafts[exerciseIndex].sets[nextIndex].weightKg = completedSet.weightKg
            exerciseDrafts[exerciseIndex].sets[nextIndex].reps = completedSet.reps
            publishActiveWorkoutStatus()
            return
        }

        let nextExerciseIndex = exerciseIndex + 1
        if exerciseDrafts.indices.contains(nextExerciseIndex),
           exerciseDrafts[nextExerciseIndex].sets.contains(where: { !$0.completed }) {
            startRest(duration: workout.restBetweenExercisesSeconds)
        } else {
            stopRest()
        }
        publishActiveWorkoutStatus()
    }

    /// Begins a date-anchored rest countdown so the timer survives background suspension.
    private func startRest(duration: Int) {
        guard duration > 0 else { stopRest(); return }
        restDuration  = duration
        restStartedAt = Date()
        restSeconds   = duration
    }

    private func stopRest() {
        restSeconds   = 0
        restStartedAt = nil
        restDuration  = 0
    }

    private func applyAutoProgressionIfNeeded() {
        guard store.hasFeatureAccess(.configurableProgression),
              store.userProfile.autoProgressionEnabled,
              !hasAppliedProgression else {
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
    @State private var selectedType: Exercise.ExerciseType?
    @State private var selectedDifficulty: Exercise.Difficulty?
    @State private var selectedEnvironment: Exercise.Environment?
    @State private var onlyAvailableEquipment = false

    private var muscles: [String] {
        ["Todos"] + Array(Set(exercises.map(\.muscleGroup))).sorted()
    }

    private var equipmentOptions: [String] {
        ["Todos"] + Array(Set(exercises.map(\.equipment))).sorted()
    }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
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

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("Tipo", selection: $selectedType) {
                                Text("Todo").tag(Optional<Exercise.ExerciseType>.none)
                                ForEach(Exercise.ExerciseType.allCases) { type in
                                    Text(type.title(language: store.userProfile.preferredLanguage)).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Dificultad", selection: $selectedDifficulty) {
                                Text("Cualquiera").tag(Optional<Exercise.Difficulty>.none)
                                ForEach(Exercise.Difficulty.allCases) { difficulty in
                                    Text(difficulty.title(language: store.userProfile.preferredLanguage)).tag(Optional(difficulty))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Entorno", selection: $selectedEnvironment) {
                                Text("Cualquiera").tag(Optional<Exercise.Environment>.none)
                                ForEach(Exercise.Environment.allCases) { environment in
                                    Text(environment.title(language: store.userProfile.preferredLanguage)).tag(Optional(environment))
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("Mi equipo", isOn: $onlyAvailableEquipment)
                                .toggleStyle(.button)
                        }
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
                                    availableEquipment: store.userProfile.availableEquipment,
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

    private func availableEquipmentMatches(_ exercise: Exercise) -> Bool {
        let equipment = Set(store.userProfile.availableEquipment.map(normalized))
        guard !equipment.isEmpty else {
            return true
        }

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

private extension Exercise.ExerciseType {
    func title(language: String) -> String {
        switch self {
        case .strength: language.hasPrefix("es") ? "Fuerza" : "Strength"
        case .cardio: "Cardio"
        case .mobility: language.hasPrefix("es") ? "Movilidad" : "Mobility"
        case .stretching: language.hasPrefix("es") ? "Estiramientos" : "Stretching"
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    func title(language: String) -> String {
        switch self {
        case .low: language.hasPrefix("es") ? "Principiante" : "Beginner"
        case .medium: language.hasPrefix("es") ? "Intermedio" : "Intermediate"
        case .high: language.hasPrefix("es") ? "Avanzado" : "Advanced"
        }
    }
}

private extension Exercise.Environment {
    func title(language: String) -> String {
        switch self {
        case .home: language.hasPrefix("es") ? "Casa" : "Home"
        case .gym: language.hasPrefix("es") ? "Gimnasio" : "Gym"
        case .both: language.hasPrefix("es") ? "Casa y gym" : "Home and gym"
        }
    }
}

private struct ReplacementExerciseRow: View {
    let exercise: Exercise
    let currentExercise: Exercise?
    let availableEquipment: [String]
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
                if let reasonText {
                    Label(reasonText, systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.recovery)
                        .lineLimit(2)
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

    private var reasonText: String? {
        guard let currentExercise else { return nil }
        let reasons = ExerciseSubstitutionService.matchReasons(
            for: exercise,
            replacing: currentExercise,
            availableEquipment: availableEquipment
        )
        return reasons.isEmpty ? nil : reasons.joined(separator: " · ")
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

private struct ActiveGymPassCard: View {
    let pass: GymPass

    var body: some View {
        HStack(spacing: 12) {
            ActiveCodePreview(value: pass.codeValue, type: pass.codeType)
                .frame(width: 84, height: 84)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Label("Tarjeta gym", systemImage: pass.codeType == .qr ? "qrcode" : "barcode")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.primary)
                Text(pass.gymName)
                    .font(.headline)
                    .lineLimit(1)
                Text(pass.membershipID)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ActiveCodePreview: View {
    let value: String
    let type: GymPass.CodeType

    var body: some View {
        if let image = generatedImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: type == .qr ? "qrcode" : "barcode")
                .font(.largeTitle)
                .foregroundStyle(.black)
        }
    }

    private var generatedImage: UIImage? {
        let filterName = type == .qr ? "CIQRCodeGenerator" : "CICode128BarcodeGenerator"
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }
        return UIImage(ciImage: output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)))
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
    @Binding var activeBookmark: ExerciseMediaBookmark?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Marcadores rápidos", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            activeBookmark = bookmark
                        } label: {
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

struct YouTubeWebView: UIViewRepresentable {
    let videoID: String
    let startSeconds: Int
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let embedURLString = "https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&start=\(startSeconds)&enablejsapi=1"
        if let url = URL(string: embedURLString) {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}

struct UniversalWebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

struct VideoPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: ExerciseMediaBookmark
    
    @State private var timeRemaining: Int = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if let videoID = extractYouTubeVideoID(from: bookmark.urlString) {
                    YouTubeWebView(videoID: videoID, startSeconds: bookmark.timestampSeconds ?? 0)
                        .cornerRadius(12)
                        .aspectRatio(16/9, contentMode: .fit)
                        .padding()
                } else if let url = URL(string: bookmark.urlString) {
                    UniversalWebView(url: url)
                        .cornerRadius(12)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No se pudo cargar el video")
                            .font(.headline)
                        Text("La URL del marcador no es válida.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                if let duration = bookmark.playbackDurationSeconds, duration > 0 {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(duration - timeRemaining), total: Double(duration))
                            .tint(PulseTheme.accent)
                            .padding(.horizontal)
                        
                        Text("Cerrando en \(timeRemaining) s")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            .navigationTitle(bookmark.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let duration = bookmark.playbackDurationSeconds, duration > 0 {
                    timeRemaining = duration
                    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                        Task { @MainActor in
                            if timeRemaining > 1 {
                                timeRemaining -= 1
                            } else {
                                timer?.invalidate()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }
    
    private func extractYouTubeVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtu.be") {
            return url.pathComponents.dropFirst().first
        }
        
        if url.pathComponents.contains("shorts") {
            if let index = url.pathComponents.firstIndex(of: "shorts"), index + 1 < url.pathComponents.count {
                return url.pathComponents[index + 1]
            }
        }
        
        if url.pathComponents.contains("embed") {
            if let index = url.pathComponents.firstIndex(of: "embed"), index + 1 < url.pathComponents.count {
                return url.pathComponents[index + 1]
            }
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            if let videoID = queryItems.first(where: { $0.name == "v" })?.value {
                return videoID
            }
        }
        
        return nil
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
    private var shouldStartAfterAuthorization = false

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
        if authorizationStatus == .notDetermined {
            shouldStartAfterAuthorization = true
            requestAuthorization()
            return
        }

        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            shouldStartAfterAuthorization = false
            return
        }
        shouldStartAfterAuthorization = false
        isTracking = true
        manager.startUpdatingLocation()
    }

    func stop() {
        shouldStartAfterAuthorization = false
        isTracking = false
        manager.stopUpdatingLocation()
    }

    func paceText(elapsedSeconds: Int) -> String {
        guard let pace = averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds) else {
            return "--"
        }
        return "\(Int(pace) / 60):\(String(format: "%02d", Int(pace) % 60))/km"
    }

    func averagePaceSecondsPerKm(elapsedSeconds: Int) -> Double? {
        guard distanceKm > 0.02 else {
            return nil
        }
        return Double(max(elapsedSeconds, 1)) / distanceKm
    }

    func averageSpeedKmh(elapsedSeconds: Int) -> Double? {
        guard elapsedSeconds > 0, distanceKm > 0.02 else {
            return nil
        }
        return distanceKm / (Double(elapsedSeconds) / 3_600)
    }

    func speedText(elapsedSeconds: Int) -> String {
        guard let speed = averageSpeedKmh(elapsedSeconds: elapsedSeconds) else {
            return "--"
        }
        return String(format: "%.1f km/h", speed)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if shouldStartAfterAuthorization,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                start()
            } else if status == .denied || status == .restricted {
                shouldStartAfterAuthorization = false
            }
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
private final class WorkoutMotionResumeDetector: ObservableObject {
    @Published var shouldSuggestResume = false

    private let activityManager = CMMotionActivityManager()
    private var startedAt: Date?

    func start() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        guard startedAt == nil else { return }

        startedAt = Date()
        shouldSuggestResume = false
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self else { return }
            guard let startedAt = self.startedAt,
                  Date().timeIntervalSince(startedAt) > 8 else {
                return
            }

            let isMovingOnFoot = activity?.walking == true || activity?.running == true
            let isReliable = activity?.confidence == .medium || activity?.confidence == .high
            self.shouldSuggestResume = isMovingOnFoot && isReliable
        }
    }

    func stop() {
        activityManager.stopActivityUpdates()
        startedAt = nil
        shouldSuggestResume = false
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
        // Permission is already checked by callers via PermissionService.
        beginRecording()
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

private struct BatteryMicroMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

struct WorkoutSummaryView: View {
    @EnvironmentObject private var store: AppStore
    let session: WorkoutSession
    let onDone: () -> Void

    @State private var isShowingShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var isImageSaved = false

    private var completedSets: [SetLog] {
        FitnessMetrics.completedSets(in: session)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Retro Thermal Receipt Card
                WorkoutReceiptView(session: session)
                    .padding(.horizontal, 4)
                
                // Share and Save Buttons (High Contrast Premium styling)
                HStack(spacing: 12) {
                    Button {
                        guard store.requireFeature(.shareCards, source: .shareCards) else {
                            return
                        }
                        generatedImage = WorkoutShareImageRenderer.render(session: session)
                        isShowingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Compartir")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        guard store.requireFeature(.shareCards, source: .shareCards) else {
                            return
                        }
                        let img = WorkoutShareImageRenderer.render(session: session)
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        withAnimation {
                            isImageSaved = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isImageSaved = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: isImageSaved ? "checkmark" : "square.and.arrow.down")
                            Text(isImageSaved ? "Guardado" : "Guardar Foto")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                // Additional standard information cards below
                PulseCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detalles adicionales").font(.headline)
                        if !session.mediaAttachments.isEmpty {
                            AttachmentPreviewStrip(attachments: session.mediaAttachments)
                        }
                        if let notes = session.notes, !notes.isEmpty {
                            Divider()
                            Text(notes)
                                .foregroundStyle(PulseTheme.secondaryText)
                        } else {
                            Text("Sin notas de entrenamiento adicionales.")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .overlay(alignment: .topTrailing) {
            Button {
                onDone()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(PulseTheme.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 16)
            .accessibilityLabel("Cerrar resumen")
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = generatedImage {
                ActivityViewController(activityItems: [image])
            }
        }
    }
}

private struct WorkoutElapsedText: View, Equatable {
    let startedAt: Date
    let basePausedSeconds: Int
    let lastPausedAt: Date?
    let isPaused: Bool
    let fallbackElapsedSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(timeString(elapsedSeconds(at: timeline.date)))
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        }
    }

    private func elapsedSeconds(at date: Date) -> Int {
        guard startedAt.timeIntervalSince1970 > 0 else {
            return fallbackElapsedSeconds
        }

        let effectiveDate = isPaused ? (lastPausedAt ?? date) : date
        return max(Int(effectiveDate.timeIntervalSince(startedAt)) - basePausedSeconds, 0)
    }

    private func timeString(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct RestCountdownRing: View, Equatable {
    let restStartedAt: Date?
    let restDuration: Int
    let fallbackRestSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds = remainingSeconds(at: timeline.date)
            let progress = restDuration > 0 ? Double(seconds) / Double(restDuration) : 0
            let ringColor: Color = seconds > 30 ? PulseTheme.primaryBright : (seconds > 0 ? PulseTheme.warning : Color.red)

            ZStack {
                Circle()
                    .stroke(PulseTheme.grouped, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: seconds)
                VStack(spacing: 1) {
                    Text(timeString(seconds))
                        .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(ringColor)
                        .animation(.none, value: seconds)
                    Text(seconds == 0 ? "¡Listo!" : "desc.")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        guard let restStartedAt else {
            return fallbackRestSeconds
        }
        return max(restDuration - Int(date.timeIntervalSince(restStartedAt)), 0)
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct SetRow: View {
    @Binding var set: SetLog
    let onCompletionChanged: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Row 1 — set number + column labels + completion button
            HStack(spacing: 6) {
                // Set number badge
                Text("\(set.setNumber)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(set.completed ? PulseTheme.accent : PulseTheme.elevated)
                    .clipShape(Circle())
                    .scaleEffect(set.completed ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25), value: set.completed)

                // Column labels
                Text("Peso kg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(maxWidth: .infinity)

                Text("Reps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(maxWidth: .infinity)

                // Spacer to align with checkmark below
                Color.clear.frame(width: 38, height: 1)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Row 2 — steppers + completion button
            HStack(spacing: 6) {
                // Alignment spacer matching the set number badge
                Color.clear.frame(width: 28, height: 1)

                InlineStepper(
                    value: $set.weightKg,
                    range: 0...400,
                    step: 2.5,
                    formatter: { String(format: "%.1f", $0) }
                )
                .frame(maxWidth: .infinity)

                InlineStepper(
                    value: Binding(
                        get: { Double(set.reps) },
                        set: { set.reps = Int($0) }
                    ),
                    range: 0...100,
                    step: 1,
                    formatter: { String(Int($0)) }
                )
                .frame(maxWidth: .infinity)

                // Completion / PR button
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                        set.completed.toggle()
                        onCompletionChanged(set.completed)
                    }
                } label: {
                    Image(systemName: set.isPersonalRecord ? "trophy.fill" : (set.completed ? "checkmark.circle.fill" : "circle"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(set.completed ? .black : PulseTheme.secondaryText)
                        .frame(width: 38, height: 38)
                        .background(set.isPersonalRecord ? PulseTheme.accent : (set.completed ? PulseTheme.accent : PulseTheme.elevated))
                        .clipShape(Circle())
                        .scaleEffect(set.completed ? 1.12 : 1.0)
                        .shadow(color: set.completed ? PulseTheme.accent.opacity(0.28) : Color.clear, radius: 5, x: 0, y: 2)
                        .animation(.spring(response: 0.25), value: set.completed)
                }
                .accessibilityLabel(set.completed ? "Marcar serie \(set.setNumber) incompleta" : "Marcar serie \(set.setNumber) completa")
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .background(set.completed ? PulseTheme.accent.opacity(0.10) : PulseTheme.grouped)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(set.completed ? PulseTheme.accent.opacity(0.35) : Color.white.opacity(0.04), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: set.completed)
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
        HStack(spacing: 3) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(PulseTheme.primary)
                    .background(PulseTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("Bajar valor")

            Text(formatter(value))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(minWidth: 36, maxWidth: .infinity)
                .frame(height: 36)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(PulseTheme.primary)
                    .background(PulseTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("Subir valor")
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: value)
    }
}

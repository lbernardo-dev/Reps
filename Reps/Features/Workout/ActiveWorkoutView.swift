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
    @Environment(AppStore.self) private var store
    let workout: WorkoutDay

    @StateObject private var routeTracker = WorkoutRouteTracker()
    @StateObject private var audioRecorder = WorkoutAudioRecorder()
    @StateObject private var musicPlayer = WorkoutAppleMusicPlayer.shared
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var motionResumeDetector = WorkoutMotionResumeDetector()
    @State private var elapsedSeconds = 0
    @State private var pausedSeconds = 0
    @State private var startedAt = Date()
    @State private var lastPausedAt: Date? = nil
    @State private var basePausedSeconds = 0
    @State private var hasShownDurationAlert = false
    @State private var showDurationExhaustedAlert = false
    @State private var showEndWorkoutConfirmation = false
    @State private var activeBookmark: ExerciseMediaBookmark?
    @State private var isPaused = false
    @State private var restSeconds = 0
    @State private var restStartedAt: Date? = nil   // ← date-based rest timing
    @State private var restDuration = 0              // duration when rest started
    @State private var restKind: RestPhaseKind = .betweenSets
    @State private var finishedSession: WorkoutSession?
    @State private var selectedExerciseIndex = 0
    @State private var showAdvancedFields = false
    @State private var lastSetCompletedAtSeconds: Int?
    @State private var lastCompletedSetUndoContext: UndoSetContext?
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
    @State private var showStartSessionRequiredAlert = false
    @State private var lastStatusPublishSecond = -1
    @State private var workoutSensorSummary: WorkoutSensorSummary?
    @State private var isFinishingWorkout = false
    @State private var showResumeSuggestion = false
    @State private var plannedDurationMinutes: Int
    @State private var lastSensorRefreshSecond = -999
    @State private var isRefreshingSensorSummary = false
    @State private var showExpandedRouteMap = false
    @State private var showMoreTools = false
    @State private var showExerciseDetails = false
    @State private var setCompletionFeedback: SetCompletionFeedback?

    private var exerciseDrafts: [ExerciseSessionDraft] {
        get { store.activeWorkoutDrafts }
        nonmutating set { store.activeWorkoutDrafts = newValue }
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let origin: WorkoutSession.Origin

    init(workout: WorkoutDay, origin: WorkoutSession.Origin = .routine) {
        self.workout = workout
        self.origin = origin
        _plannedDurationMinutes = State(initialValue: workout.durationMinutes)
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

    private var selectedExerciseVolume: ExerciseWeeklyVolume? {
        guard let exercise = selectedDraft?.workoutExercise.exercise else { return nil }
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return MuscleVolumeService.weeklyVolume(
            for: exercise,
            completedSessions: store.workoutSessions,
            activeDrafts: exerciseDrafts,
            startDate: weekStart
        )
    }

    private var selectedAimForMoreBinding: Binding<Bool> {
        Binding(
            get: { selectedDraft?.workoutExercise.aimForMoreSetsNextTime ?? false },
            set: { newValue in
                guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
                exerciseDrafts[selectedExerciseIndex].workoutExercise.aimForMoreSetsNextTime = newValue
                HapticService.selection()
            }
        )
    }

    private var hasVisibleAdvancedFields: Bool {
        store.hasFeatureAccess(.configurableProgression) &&
        (store.userProfile.showSetType || store.userProfile.showRPE || store.userProfile.showRIR || store.userProfile.showTempo)
    }

    private var isCardioMovementCandidate: Bool {
        workout.isCardioMovement
    }

    private var isRouteCandidate: Bool {
        workout.isOutdoorRouteWorkout
    }

    private var isTreadmillCandidate: Bool {
        workout.isTreadmillWorkout
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
            return PulseTheme.accentOnCard
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
        return max((plannedDurationMinutes * 60) - elapsedSeconds, 0)
    }

    private var selectedExerciseContext: SelectedExerciseContextBuilder.Context {
        SelectedExerciseContextBuilder.context(
            from: SelectedExerciseContextBuilder.Input(
                draft: selectedDraft,
                recentSets: selectedDraft.map {
                    ExerciseHistoryAnalyzer.recentCompletedSets(for: $0.workoutExercise.exercise, in: store.workoutSessions)
                } ?? [],
                hasConfigurableProgressionAccess: store.hasFeatureAccess(.configurableProgression),
                autoProgressionEnabled: store.userProfile.autoProgressionEnabled,
                weightIncrementKg: store.userProfile.weightIncrementKg
            )
        )
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
            return "pending_rest"
        }

        return restSeconds == 0 ? "ready" : "rest"
    }

    private var isSessionStarted: Bool {
        store.activeWorkoutStatus != nil && store.activeWorkout?.id == workout.id
    }

    var body: some View {
        activeWorkoutContent
        .overlay(alignment: .bottom) {
            if let feedback = setCompletionFeedback {
                SetCompletionFeedbackBanner(feedback: feedback) {
                    undoLastCompletedSet()
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    restKind       = dur == workout.restBetweenExercisesSeconds ? .exerciseChange : .betweenSets
                } else {
                    restSeconds    = 0
                    restStartedAt  = nil
                    restKind       = .betweenSets
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
            if isSessionStarted, #unavailable(iOS 26.0) {
                // On iOS 26+ the native HKWorkoutSession keeps the app alive.
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
            ExercisePickerSheet(
                title: addExerciseSheetTitle,
                exercises: store.exercises,
                currentExercise: nil,
                initialMuscle: addExerciseInitialMuscle,
                initialType: addExerciseInitialType
            ) { exercise in
                addExercise(exercise)
                showAddExercise = false
            }
        }
        .sheet(item: replacementBinding) { replacement in
            ExercisePickerSheet(
                title: localizedString("substitute_exercise"),
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
        .onReceive(NotificationCenter.default.publisher(for: .watchDidLogSet)) { _ in
            // AppStore already mutated the shared drafts; recompute & republish.
            publishActiveWorkoutStatus()
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
        .alert("permission_required", isPresented: $showPermissionDenied) {
            Button("abrir_ajustes") {
                PermissionService.shared.openSettings()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text(permissionDeniedMessage)
        }
        .alert("are_you_done", isPresented: $showDurationExhaustedAlert) {
            Button("end_training", role: .destructive) {
                finishWorkout()
            }
            Button("continuar", role: .cancel) {}
        } message: {
            Text(localizedFormat("planned_workout_time_completed_format", plannedDurationMinutes))
        }
        .confirmationDialog(
            "end_workout_confirmation_title",
            isPresented: $showEndWorkoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("end_training", role: .destructive) {
                finishWorkout()
            }
            Button("end_and_dont_ask_again", role: .destructive) {
                store.userProfile.confirmBeforeEndingWorkout = false
                finishWorkout()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("end_workout_confirmation_message")
        }
        .alert("add_at_least_one_exercise", isPresented: $showMissingExerciseAlert) {
            Button("find_exercise") {
                showAddExercise = true
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("cannot_start_a_session_without_exercises")
        }
        .alert("Inicia el entrenamiento", isPresented: $showStartSessionRequiredAlert) {
            Button("Iniciar ahora") {
                startPreparedSession()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("Para registrar series, primero pulsa Empezar. Asi el temporizador, descansos, Watch y resumen final quedan sincronizados.")
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
            let contentWidth = max(proxy.size.width - (PulseTheme.screenHorizontalPadding * 2), 0)
            ZStack(alignment: .top) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        if isCardioOnlySession {
                            // Priority order while a cardio session is running:
                            // pause/finish controls (pinned header) → metrics →
                            // live map → hydration control → secondary info.
                            routeProgressCard
                                .frame(width: contentWidth)
                            if isRouteCandidate {
                                liveRouteMapCard
                                    .frame(width: contentWidth)
                            }
                            if isSessionStarted {
                                routeSessionControlCard
                                    .frame(width: contentWidth)
                            }
                            batteryCard
                                .frame(width: contentWidth)
                            if isSessionStarted {
                                routeSessionFeedbackCard
                                    .frame(width: contentWidth)
                            }
                        } else if exerciseDrafts.isEmpty {
                            // Free workout with no exercises yet: a single
                            // empty-state card owns this moment. The command
                            // ring and "what's next" row both read from an
                            // empty set list and would otherwise show
                            // contradictory copy (e.g. "all sets logged").
                            emptyFreeWorkoutCard
                                .frame(width: contentWidth)
                        } else {
                            workoutCommandCard
                                .frame(width: contentWidth)
                            // Where am I: per-exercise progress and quick switch.
                            exerciseSwitcher
                                .frame(width: contentWidth)
                            // Primary logging surface.
                            exerciseCard
                                .frame(width: contentWidth)
                            // Coaching for the set currently being logged.
                            if !selectedProgressionRecommendations.isEmpty {
                                ProgressionRecommendationCard(
                                    recommendations: selectedProgressionRecommendations,
                                    language: store.userProfile.preferredLanguage,
                                    title: "next_adjustment"
                                )
                                .frame(width: contentWidth)
                            }
                            // What's next in the session.
                            nextExerciseCard
                                .frame(width: contentWidth)
                            hydrationCard
                                .frame(width: contentWidth)
                            // Document the session: notes, voice, photo, video
                            // and per-attachment sharing (collapsed disclosure).
                            sessionFeedbackCard
                                .frame(width: contentWidth)
                            // Secondary tools, collapsed by default so the
                            // logging loop stays the focus of the screen.
                            moreSessionToolsSection
                                .frame(width: contentWidth)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .safeAreaPadding(.top, 100)
                    .padding(.top, 4)
                    .padding(.bottom, 128)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)

                ActiveWorkoutPinnedHeader(
                    title: RepsText.workoutTitle(workout.title, language: store.userProfile.preferredLanguage),
                    contentWidth: contentWidth,
                    isSessionStarted: isSessionStarted,
                    isPaused: isPaused,
                    canStartWorkout: canStartWorkout,
                    isFinishingWorkout: isFinishingWorkout,
                    onClose: requestWorkoutClose,
                    onTogglePause: toggleWorkoutPause,
                    onPrimaryAction: performPrimaryWorkoutAction
                )
            }
        }
        .screenBackground()
    }

    private var canStartWorkout: Bool {
        !exerciseDrafts.isEmpty || isCardioMovementCandidate
    }

    private var isRouteOnlySession: Bool {
        isRouteCandidate && exerciseDrafts.isEmpty
    }

    private var isCardioOnlySession: Bool {
        isCardioMovementCandidate && exerciseDrafts.isEmpty
    }

    private func prepareWorkoutIfNeeded() {
        if store.activeWorkoutStatus != nil, store.activeWorkout?.id != workout.id {
            return
        }

        if store.activeWorkout?.id != workout.id {
            store.activeWorkout = workout
            store.activeWorkoutDrafts = WorkoutDraftController.makeDrafts(for: workout)
        } else if store.activeWorkoutDrafts.isEmpty, !workout.exercises.isEmpty {
            store.activeWorkoutDrafts = WorkoutDraftController.makeDrafts(for: workout)
        }
    }

    private func startPreparedSession() {
        guard canStartWorkout else {
            showMissingExerciseAlert = true
            return
        }

        let startDate = Date()
        startedAt = startDate
        elapsedSeconds = 0
        pausedSeconds = 0
        isPaused = false
        lastPausedAt = nil
        basePausedSeconds = 0
        lastStatusPublishSecond = -1
        lastSensorRefreshSecond = -999
        hasShownDurationAlert = false
        workoutSensorSummary = nil
        store.startPreparedActiveWorkout(workout, drafts: exerciseDrafts, startedAt: startDate)
        if isRouteCandidate {
            routeTracker.startNewRoute(startedAt: startDate)
        }
        if #unavailable(iOS 26.0) {
            // On iOS 26+ the native HKWorkoutSession keeps the app alive.
            WorkoutBackgroundKeepAlive.shared.startIfNeeded()
        }
        publishActiveWorkoutStatus()
    }

    private func requestWorkoutClose() {
        HapticService.selection()
        if isSessionStarted {
            dismiss()
        } else {
            stopWorkout()
        }
    }


    private func toggleWorkoutPause() {
        HapticService.selection()
        withAnimation(.snappy(duration: 0.2)) {
            setWorkoutPaused(!isPaused)
        }
    }

    private func performPrimaryWorkoutAction() {
        if isSessionStarted {
            HapticService.notification(.warning)
            if store.userProfile.confirmBeforeEndingWorkout {
                showEndWorkoutConfirmation = true
            } else {
                finishWorkout()
            }
        } else {
            HapticService.impact(.medium)
            startPreparedSession()
        }
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
        guard !exerciseDrafts.isEmpty || isCardioMovementCandidate else {
            showMissingExerciseAlert = true
            return
        }
        NotificationService.cancelWorkoutDurationExhaustedNotification()
        isFinishingWorkout = true
        Task {
            await finishWorkoutAsync()
        }
    }

    private func finishWorkoutAsync() async {
        let interval = PerformanceSignpost.begin(
            "workout.finish",
            "drafts=\(exerciseDrafts.count) route=\(isRouteCandidate)"
        )
        defer {
            PerformanceSignpost.end(
                "workout.finish",
                interval,
                "drafts=\(exerciseDrafts.count)"
            )
        }

        elapsedSeconds = elapsedWorkoutSeconds()
        let finishedAt = Date()
        routeTracker.stop()
        motionResumeDetector.stop()
        NotificationService.cancelRestEndNotification()
        let startDate = startedAt
        let sensorSummary = try? await healthKit.fetchWorkoutSensorSummary(start: startDate, end: finishedAt)
        workoutSensorSummary = sensorSummary
        let session = WorkoutSessionBuilder.session(
            from: WorkoutSessionBuilder.Input(
                workoutTitle: workout.title,
                finishedAt: finishedAt,
                startedAt: startDate,
                origin: origin,
                isRouteCandidate: isRouteCandidate,
                isTreadmillCandidate: isTreadmillCandidate,
                userTrainingLocation: store.userProfile.trainingLocation,
                activePlanLocation: store.activePlan.location,
                elapsedSeconds: elapsedSeconds,
                drafts: exerciseDrafts,
                globalNotes: sessionNotes,
                sessionVoiceNote: sessionVoiceNote,
                sessionMediaAttachments: sessionMediaAttachments,
                sessionRPE: sessionRPE,
                energyBefore: energyBefore,
                energyAfter: energyAfter,
                sensorSummary: sensorSummary,
                routePoints: routeTracker.routePoints,
                pausedSeconds: pausedSeconds,
                displayedRouteDistanceKm: displayedRouteMetrics.distanceKm,
                displayedRoutePaceSecondsPerKm: displayedRouteMetrics.paceSecondsPerKm
            )
        )
        store.applyAimForMoreIntent(from: exerciseDrafts, dayID: workout.id)
        store.finishWorkout(session)
        if waterLiters > 0 {
            try? await healthKit.saveDailyNutrition(waterLiters: waterLiters, dietaryEnergyKcal: nil)
        }
        if let cardioLog = WorkoutSessionBuilder.cardioLog(
            from: session,
            sensorSummary: sensorSummary,
            isCardioMovementCandidate: isCardioMovementCandidate,
            sessionType: workout.sessionType,
            isTreadmillCandidate: isTreadmillCandidate,
            isRouteCandidate: isRouteCandidate,
            averageSpeedKmh: displayedRouteMetrics.speedKmh
        ) {
            store.addCardioLog(cardioLog)
        }
        isFinishingWorkout = false
        // Mark as finished (so onDisappear tears down background work) and close
        // the active view. The summary is then presented at the MainTabView
        // level (store.finishedSessionForSummary), which keeps the tab bar in
        // context so closing it can land cleanly on Progress.
        finishedSession = session
        dismiss()
    }

    private func publishActiveWorkoutStatus() {
        let draftCount = exerciseDrafts.count
        let setCount = exerciseDrafts.reduce(0) { $0 + $1.sets.count }
        let interval = PerformanceSignpost.begin(
            "workout.publishStatus",
            "drafts=\(draftCount) sets=\(setCount)"
        )
        defer {
            PerformanceSignpost.end(
                "workout.publishStatus",
                interval,
                "drafts=\(draftCount) sets=\(setCount)"
            )
        }

        let currentSet = selectedExerciseContext.currentWorkingSet
        let playlist = planPlaylist
        store.updateActiveWorkout(ActiveWorkoutStatusBuilder.update(
            from: ActiveWorkoutStatusBuilder.Input(
                elapsedSeconds: elapsedSeconds,
                pausedSeconds: pausedSeconds,
                isPaused: isPaused,
                selectedExerciseName: selectedDraft.map { RepsText.exerciseName($0.workoutExercise.exercise.name, language: store.userProfile.preferredLanguage) },
                selectedExerciseIndex: selectedExerciseIndex,
                drafts: exerciseDrafts,
                currentSet: currentSet,
                restSeconds: restSeconds,
                restDurationSeconds: currentRestDuration,
                estimatedRemainingSeconds: estimatedRemainingSeconds,
                waterLiters: waterLiters,
                musicTitle: musicPlayer.currentSongTitle ?? playlist?.title,
                musicArtist: musicPlayer.currentSongArtist ?? playlist?.provider.rawValue.capitalized,
                isMusicPlaying: playlist.map { _ in musicPlayer.isPlaying },
                nextExerciseName: nextExerciseTitle,
                exerciseHistorySummary: selectedExerciseContext.historySummary,
                gymPass: selectedGymPass,
                lastPausedAt: lastPausedAt,
                isRouteWorkout: isCardioMovementCandidate,
                isOutdoorRoute: isRouteCandidate,
                routeDistanceKm: routeTracker.distanceKm,
                routePaceSecondsPerKm: routeTracker.averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds),
                routeSpeedKmh: routeTracker.averageSpeedKmh(elapsedSeconds: elapsedSeconds),
                routePointCount: routeTracker.routePoints.count,
                previousRouteDistanceKm: store.activeWorkoutStatus?.routeDistanceKm,
                previousRoutePaceSecondsPerKm: store.activeWorkoutStatus?.routePaceSecondsPerKm,
                previousRouteSpeedKmh: store.activeWorkoutStatus?.routeSpeedKmh,
                previousRoutePointCount: store.activeWorkoutStatus?.routePointCount,
                routeSteps: workoutSensorSummary?.steps,
                liveHeartRate: workoutSensorSummary?.averageHeartRate,
                liveActiveEnergyKcal: workoutSensorSummary?.activeEnergyKcal
            )
        ))
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
                    if restKind == .exerciseChange {
                        HapticService.exerciseChangeTimerEnded()
                        advanceToNextExerciseAfterTransition()
                    } else {
                        HapticService.restTimerEnded()
                    }
                }
            }
        }

        // Comprobar si se ha agotado el tiempo planificado. Esto solo notifica
        // al usuario (in-app y por notificación local, por si la app está en
        // background); el entrenamiento nunca se detiene automáticamente.
        let targetSeconds = plannedDurationMinutes * 60
        if targetSeconds > 0, currentElapsed >= targetSeconds, !hasShownDurationAlert {
            elapsedSeconds = currentElapsed
            hasShownDurationAlert = true
            showDurationExhaustedAlert = true
            NotificationService.scheduleWorkoutDurationExhaustedNotification(plannedMinutes: plannedDurationMinutes)
        }

        elapsedSeconds = currentElapsed
        publishActiveWorkoutStatusIfNeeded(currentElapsedSeconds: currentElapsed)
        refreshLiveSensorSummaryIfNeeded(currentElapsedSeconds: currentElapsed)
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
                routeTracker.resume()
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

    private func refreshLiveSensorSummaryIfNeeded(currentElapsedSeconds: Int) {
        guard isCardioMovementCandidate, isSessionStarted, !isPaused, currentElapsedSeconds >= 15 else { return }
        guard currentElapsedSeconds - lastSensorRefreshSecond >= 30 else { return }
        guard !isRefreshingSensorSummary else { return }

        lastSensorRefreshSecond = currentElapsedSeconds
        isRefreshingSensorSummary = true
        let startDate = startedAt
        Task {
            let summary = try? await healthKit.fetchWorkoutSensorSummary(start: startDate, end: Date())
            await MainActor.run {
                if let summary {
                    workoutSensorSummary = summary
                    publishActiveWorkoutStatus()
                }
                isRefreshingSensorSummary = false
            }
        }
    }

    private var sessionProgressCard: some View {
        PulseCard {
            VStack(spacing: 16) {
                ActiveWorkoutProgressSummary(
                    completedSets: completedSets,
                    totalSets: totalSets,
                    setCompletion: setCompletion,
                    isSessionStarted: isSessionStarted,
                    isPaused: isPaused,
                    startedAt: startedAt,
                    basePausedSeconds: basePausedSeconds,
                    lastPausedAt: lastPausedAt,
                    fallbackElapsedSeconds: elapsedSeconds,
                    totalVolume: totalVolume,
                    pausedSeconds: pausedSeconds,
                    nextLoggingTitle: nextLoggingTitle,
                    onCompleteNext: completeNextAvailableSet
                )

                if let playlist = planPlaylist {
                    Divider()
                        .background(PulseTheme.separator)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        // Artwork
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

                        // Text info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(musicPlayer.currentSongTitle ?? playlist.title)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(musicPlayer.currentSongArtist ?? musicPlayer.statusText(for: playlist))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        MusicTransportControls(
                            provider: playlist.provider,
                            isPlaying: musicPlayer.isPlaying,
                            onBack: { Task { await musicPlayer.skipBackward(playlist) } },
                            onPlayPause: { Task { await musicPlayer.playOrPause(playlist) } },
                            onForward: { Task { await musicPlayer.skipForward(playlist) } }
                        )
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
                        Text("training_battery_2")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(batteryColor)
                        Text(localizedFormat("battery_now_projected_format", currentBattery.level, projectedBatteryLevel))
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
                    BatteryMicroMetric(title: localizedString("fatigue_label"), value: "\(Int(currentBattery.fatigueLoad.rounded()))", systemImage: "bolt.slash", color: PulseTheme.destructive)
                    BatteryMicroMetric(title: localizedString("recharge_label"), value: "+\(Int(currentBattery.recoveryCredit.rounded()))", systemImage: "bed.double", color: PulseTheme.accent)
                    BatteryMicroMetric(title: localizedString("plan"), value: "\(Int(currentBattery.planPressure.rounded()))", systemImage: "calendar", color: PulseTheme.warning)
                }
            }
        }
    }

    private var workoutCommandCard: some View {
        ActiveWorkoutCommandCard(
            exerciseTitle: selectedExerciseTitle,
            nextSetTitle: nextLoggingTitle,
            setTarget: selectedSetTargetText,
            suggestion: selectedExerciseContext.suggestionText,
            history: selectedExerciseContext.historySummary,
            isSessionStarted: isSessionStarted,
            isPaused: isPaused,
            isResting: restStartedAt != nil && restSeconds > 0,
            restSeconds: currentRestRemainingSeconds(),
            completedSets: completedSets,
            totalSets: totalSets,
            completion: setCompletion,
            onDecreaseRest: { adjustRest(by: -15) },
            onIncreaseRest: { adjustRest(by: 15) },
            onSkipRest: toggleRestTimer,
            onUndo: lastCompletedSetUndoContext == nil ? nil : { undoLastCompletedSet() }
        )
    }

    private var exerciseSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(exerciseDrafts.enumerated()), id: \.element.workoutExercise.id) { index, draft in
                    let isActive = selectedExerciseIndex == index
                    let completedCount = draft.sets.filter(\.completed).count
                    let totalCount = draft.sets.count
                    let ratio: Double = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
                    let isCompleted = completedCount == totalCount && totalCount > 0
                    let cardBgColor = isCompleted
                        ? PulseTheme.growth.opacity(0.15)
                        : (isActive ? PulseTheme.fitOrange.opacity(0.15) : PulseTheme.card)
                    
                    let cardStrokeColor = isCompleted
                        ? PulseTheme.growth.opacity(0.55)
                        : (isActive ? PulseTheme.fitOrange.opacity(0.55) : Color.white.opacity(0.04))
                    
                    let cardShadowColor = isCompleted
                        ? PulseTheme.growth.opacity(0.14)
                        : (isActive ? PulseTheme.fitOrange.opacity(0.14) : .clear)

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
                                    fallbackSize: .caption.weight(.bold),
                                    catalog: store.exercises
                                )
                                .equatable()
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    ZStack {
                                        Circle()
                                            .fill(cardBgColor)
                                            .frame(width: 18, height: 18)
                                        
                                        Circle()
                                            .stroke(PulseTheme.separator, lineWidth: 2.0)
                                            .frame(width: 14, height: 14)
                                        
                                        if ratio == 0 {
                                            Circle()
                                                .stroke(PulseTheme.destructive, lineWidth: 2.0)
                                                .frame(width: 14, height: 14)
                                        } else {
                                            Circle()
                                                .trim(from: 0, to: ratio)
                                                .stroke(exerciseRingColor(ratio: ratio), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                                                .rotationEffect(.degrees(-90))
                                                .frame(width: 14, height: 14)
                                        }
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
                                .foregroundStyle(isActive ? PulseTheme.textPrimary : PulseTheme.secondaryText)
                                HStack(spacing: 6) {
                                    Text(localizedFormat("sets_fraction_format", completedCount, totalCount))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    if draft.workoutExercise.supersetGroup != nil {
                                        let pillColor = isCompleted ? PulseTheme.growth : (isActive ? PulseTheme.fitOrange : PulseTheme.accent)
                                        Text("superset_label")
                                            .font(.caption2.weight(.heavy))
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(pillColor.opacity(0.16), in: Capsule())
                                            .foregroundStyle(pillColor)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .frame(width: 180, alignment: .leading)
                        .background(cardBgColor)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                .stroke(cardStrokeColor, lineWidth: 1.5)
                        )
                        .shadow(color: cardShadowColor, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var sessionExerciseOrderCard: some View {
        ActiveExerciseOrderCard(
            drafts: exerciseDrafts,
            selectedExerciseIndex: selectedExerciseIndex,
            language: store.userProfile.preferredLanguage,
            onAdd: {
                HapticService.selection()
                showAddExercise = true
            },
            onMove: moveDraft,
            onToggleSuperset: toggleSuperset,
            onDelete: deleteDraft
        )
    }

    private func toggleSuperset(at index: Int) {
        HapticService.selection()
        withAnimation(.snappy(duration: 0.2)) {
            WorkoutDraftController.toggleSupersetLink(at: index, in: &store.activeWorkoutDrafts)
        }
        syncActiveWorkoutExercises()
        publishActiveWorkoutStatus()
    }

    /// Secondary controls (battery, route, reordering, music/center, feedback)
    /// kept behind a single disclosure so the active screen leads with the
    /// log → rest → next loop. Each child is already a self-contained card.
    private var moreSessionToolsSection: some View {
        VStack(spacing: 18) {
            PulseCard {
                Button {
                    HapticService.selection()
                    withAnimation(.snappy(duration: 0.25)) {
                        showMoreTools.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Label("more_session_tools", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(PulseTheme.accent)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .rotationEffect(.degrees(showMoreTools ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if showMoreTools {
                batteryCard
                if isRouteCandidate {
                    routeTrackingCard
                }
                sessionExerciseOrderCard
                sessionControlCenterCard
            }
        }
    }

    private var hydrationCard: some View {
        let navy = Color(red: 0.02, green: 0.13, blue: 0.27)
        let navyLift = Color(red: 0.04, green: 0.22, blue: 0.40)
        let waterBlue = Color(red: 0.23, green: 0.60, blue: 0.98)

        return PulseCard(backgroundColor: navy) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "waterbottle.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(waterBlue)
                        .frame(width: 42, height: 42)
                        .background(navyLift, in: RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Registrar agua")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text(String(format: "%.2f L", waterLiters))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                }

                SessionControlButton(
                    title: "+250 ml",
                    systemImage: "waterbottle.fill",
                    foregroundStyle: .white,
                    backgroundStyle: waterBlue,
                    height: 50
                ) {
                    addWater()
                }
            }
        }
    }

    private var restCard: some View {
        let undoAction: (() -> Void)? = lastCompletedSetUndoContext == nil
            ? nil
            : { undoLastCompletedSet() }
        let backAction: (() -> Void)? = (restKind == .exerciseChange && selectedExerciseIndex > 0)
            ? { moveExercise(by: -1) }
            : nil
        return ActiveRestPanel(
            isRestActive: lastSetCompletedAtSeconds != nil,
            currentRestSeconds: currentRestRemainingSeconds(),
            restStartedAt: restStartedAt,
            restDuration: restDuration,
            kind: restKind,
            nextExerciseName: restKind == .exerciseChange ? nextExerciseTitle : nil,
            onDecrease: { adjustRest(by: -15) },
            onIncrease: { adjustRest(by: 15) },
            onSkipOrRestart: toggleRestTimer,
            onUndo: undoAction,
            onBackToPreviousExercise: backAction
        )
    }

    private func undoLastCompletedSet() {
        guard let context = lastCompletedSetUndoContext else { return }
        guard WorkoutDraftController.uncompleteSet(
            in: &store.activeWorkoutDrafts,
            exerciseIndex: context.exerciseIndex,
            setIndex: context.setIndex
        ) else {
            lastCompletedSetUndoContext = nil
            return
        }

        lastSetCompletedAtSeconds = context.previousLastSetCompletedAtSeconds
        lastCompletedSetUndoContext = nil
        setCompletionFeedback = nil
        stopRest()
        publishActiveWorkoutStatus()
        HapticService.impact(.rigid)
    }

    private func showSetCompletionFeedback(exerciseName: String, setNumber: Int) {
        let feedback = SetCompletionFeedback(exerciseName: exerciseName, setNumber: setNumber)
        withAnimation(.snappy(duration: 0.2)) {
            setCompletionFeedback = feedback
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard setCompletionFeedback?.id == feedback.id else { return }
            withAnimation(.snappy(duration: 0.2)) {
                setCompletionFeedback = nil
            }
        }
    }

    private var routeProgressCard: some View {
        let progress = routeProgressSnapshot
        let progressColor = routeProgressColor(for: progress.visualState)

        return PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(PulseTheme.grouped, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: progress.progress)
                            .stroke(progressColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.snappy(duration: 0.35), value: progress.progress)
                        Image(systemName: progress.icon)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(progressColor)
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(progress.status)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.6)
                            .foregroundStyle(progressColor)

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

                        Text(progress.subtitle)
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
                            .fill(progressColor)
                            .frame(width: max(geo.size.width * progress.progress, progress.progress > 0 ? 16 : 0), height: 8)
                            .animation(.snappy(duration: 0.35), value: progress.progress)
                    }
                }
                .frame(height: 8)

                if !isSessionStarted {
                    PlannedDurationEditor(minutes: $plannedDurationMinutes)

                    Label(progress.startHint, systemImage: progress.startHintSystemImage)
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

    private var routeProgressSnapshot: RouteProgressBuilder.Snapshot {
        RouteProgressBuilder.snapshot(
            from: RouteProgressBuilder.Input(
                isTreadmill: isTreadmillCandidate,
                isSessionStarted: isSessionStarted,
                isPaused: isPaused,
                plannedDurationMinutes: plannedDurationMinutes,
                elapsedSeconds: elapsedSeconds,
                pausedSeconds: pausedSeconds,
                distanceKm: displayedRouteMetrics.distanceKm,
                paceText: displayedRouteMetrics.paceText
            )
        )
    }

    private func routeProgressColor(for state: RouteProgressBuilder.VisualState) -> Color {
        switch state {
        case .inactive:
            return PulseTheme.secondaryText
        case .active:
            return PulseTheme.accentOnCard
        case .paused:
            return PulseTheme.warning
        }
    }

    private var routeTrackingCard: some View {
        PulseCard {
            RouteTrackingPanel(
                isTracking: routeTracker.isTracking,
                statusText: routeTracker.statusText,
                statusBadge: routeTrackerStatusBadge,
                primaryMetrics: [
                    .init(title: localizedString("distance_label"), value: String(format: "%.2f km", displayedRouteMetrics.distanceKm), icon: "point.topleft.down.curvedto.point.bottomright.up"),
                    .init(title: localizedString("route_points"), value: "\(displayedRouteMetrics.pointCount)", icon: "map.fill"),
                    .init(title: localizedString("pace_label"), value: displayedRouteMetrics.paceText, icon: "speedometer")
                ],
                secondaryMetrics: [
                    .init(title: localizedString("speed_label"), value: displayedRouteMetrics.speedText, icon: "gauge.with.needle"),
                    .init(title: localizedString("steps_label"), value: displayedRouteMetrics.stepsText, icon: "shoeprints.fill"),
                    .init(title: localizedString("pulse_label"), value: displayedRouteMetrics.heartRateText, icon: "heart.fill")
                ]
            )
        }
    }

    private var liveRouteMapCard: some View {
        PulseCard {
            LiveRouteMapPanel(
                routePoints: routeTracker.routePoints,
                isSessionStarted: isSessionStarted,
                onExpand: { showExpandedRouteMap = true }
            )
        }
        .sheet(isPresented: $showExpandedRouteMap) {
            ExpandedRouteMapView(
                title: RepsText.workoutTitle(workout.title, language: store.userProfile.preferredLanguage),
                routePoints: routeTracker.routePoints
            )
        }
    }

    private var routeTrackerStatusBadge: String {
        if routeTracker.isTracking { return localizedString("gps_active") }
        if isSessionStarted && isPaused { return localizedString("paused_label") }
        if isSessionStarted { return localizedString("gps_ready") }
        return localizedString("ready_label")
    }

    private var cardioControlStatus: String {
        if isTreadmillCandidate {
            return isPaused ? localizedString("paused_label") : localizedString("treadmill_label")
        }
        return routeTrackerStatusBadge
    }

    private var displayedRouteMetrics: RouteMetricsBuilder.Metrics {
        RouteMetricsBuilder.metrics(
            from: RouteMetricsBuilder.Input(
                trackerDistanceKm: routeTracker.distanceKm,
                trackerPaceSecondsPerKm: routeTracker.averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds),
                trackerSpeedKmh: routeTracker.averageSpeedKmh(elapsedSeconds: elapsedSeconds),
                trackerPointCount: routeTracker.routePoints.count,
                activeStatus: store.activeWorkoutStatus,
                sensorSummary: workoutSensorSummary,
                todayHealthMetric: nil
            )
        )
    }


    private var exerciseCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    if let exercise = selectedDraft?.workoutExercise.exercise {
                        NavigationLink {
                            ExerciseProgressView(exercise: exercise)
                        } label: {
                            ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                                .equatable()
                                .frame(width: 76, height: 86)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                        .stroke(PulseTheme.separator, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(RepsText.equipment(selectedDraft?.workoutExercise.exercise.equipment ?? "", language: store.userProfile.preferredLanguage))
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(RepsText.exerciseName(selectedDraft?.workoutExercise.exercise.name ?? localizedString("exercise_label"), language: store.userProfile.preferredLanguage))
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                        Text(localizedFormat("workout_target_format",
                            selectedDraft?.workoutExercise.targetSets ?? 0,
                            selectedDraft?.workoutExercise.repRange ?? "-",
                            selectedDraft?.workoutExercise.previous ?? "-"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let suggestionText = selectedExerciseContext.suggestionText {
                            Label(suggestionText, systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                    Menu {
                        Button {
                            showAddExercise = true
                        } label: {
                            Label("add_exercise", systemImage: "plus")
                        }

                        Button {
                            replacementExerciseIndex = selectedExerciseIndex
                        } label: {
                            Label("sustituir", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Button {
                            skipSelectedExercise()
                        } label: {
                            Label("skip_exercise", systemImage: "forward.end")
                        }

                        if hasIncompleteSetsForSelectedExercise && isSessionStarted {
                            Button {
                                completeAllSetsForSelectedExercise()
                            } label: {
                                Label("complete_all_sets", systemImage: "checkmark.circle")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            removeSelectedExercise()
                        } label: {
                            Label("remove_from_session", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                    let sets = exerciseDrafts.indices.contains(selectedExerciseIndex) ? exerciseDrafts[selectedExerciseIndex].sets : []
                    if !isSessionStarted {
                        Label("Pulsa Empezar para registrar series", systemImage: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.warning)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PulseTheme.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    ActiveSetRowsList(
                        setIndices: Array(sets.indices),
                        trackingType: selectedDraft?.workoutExercise.exercise.trackingType ?? .weightReps,
                        isSessionStarted: isSessionStarted,
                        setBinding: selectedSetBinding,
                        onCompletionChanged: completeSelectedSetIfNeeded,
                        onDeleteSet: deleteSetFromSelectedExercise
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        addSetToSelectedExercise()
                    } label: {
                        Label("add_series", systemImage: "plus")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            showExerciseDetails.toggle()
                        }
                    } label: {
                        Label(showExerciseDetails ? "Hide" : "Details", systemImage: showExerciseDetails ? "chevron.up" : "slider.horizontal.3")
                            .font(.subheadline.weight(.black))
                            .frame(width: 120, height: 48)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if showExerciseDetails {
                    exerciseDetailsPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var exerciseDetailsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            executionSummaryStrip

            if let volume = selectedExerciseVolume {
                InWorkoutVolumeStrip(volume: volume, aimForMore: selectedAimForMoreBinding)
            }

            if !selectedMediaBookmarks.isEmpty {
                ExerciseBookmarkStrip(bookmarks: selectedMediaBookmarks, activeBookmark: $activeBookmark)
            }

            activeWorkoutToolsCard

            if hasVisibleAdvancedFields {
                DisclosureGroup(isExpanded: $showAdvancedFields) {
                    if exerciseDrafts.indices.contains(selectedExerciseIndex) {
                        let sets = exerciseDrafts.indices.contains(selectedExerciseIndex) ? exerciseDrafts[selectedExerciseIndex].sets : []
                        ActiveAdvancedSetFieldsList(
                            setIndices: Array(sets.indices),
                            showSetType: store.userProfile.showSetType,
                            showRPE: store.userProfile.showRPE,
                            showRIR: store.userProfile.showRIR,
                            showTempo: store.userProfile.showTempo,
                            setBinding: selectedSetBinding
                        )
                    }
                } label: {
                    Label("campos_pro", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(PulseTheme.accent)
                }
            } else {
                Button {
                    if store.requireFeature(.configurableProgression, source: .workoutAdvancedFields) {
                        showProPreferences = true
                    }
                } label: {
                    HStack {
                        Label("campos_pro", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .foregroundStyle(PulseTheme.secondaryText)
                        Spacer()
                        Text("activar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.accent)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

        }
        .padding(12)
        .background(PulseTheme.grouped.opacity(0.68), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }

    private var nextExerciseCard: some View {
        let hasNext = !exerciseDrafts.isEmpty && selectedExerciseIndex < exerciseDrafts.count - 1
        return Group {
            if hasNext || exerciseDrafts.isEmpty {
                PulseCard {
                    HStack(spacing: 12) {
                        if selectedExerciseIndex > 0 {
                            Button {
                                HapticService.selection()
                                withAnimation(.snappy(duration: 0.22)) {
                                    selectedExerciseIndex = max(0, selectedExerciseIndex - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .frame(width: 42, height: 42)
                                    .background(PulseTheme.grouped)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider().frame(height: 32).opacity(0.3)
                        }
                        
                        Button {
                            HapticService.selection()
                            if exerciseDrafts.isEmpty {
                                showAddExercise = true
                            } else {
                                withAnimation(.snappy(duration: 0.22)) {
                                    selectedExerciseIndex = min(selectedExerciseIndex + 1, max(exerciseDrafts.count - 1, 0))
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.title3)
                                    .foregroundStyle(PulseTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("next_uppercase")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .tracking(1.0)
                                        .foregroundStyle(PulseTheme.accent)
                                    Text(nextExerciseTitle)
                                        .font(.subheadline.weight(.bold))
                                        .lineLimit(1)
                                    Text(nextExerciseSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: exerciseDrafts.isEmpty ? "plus" : "chevron.right")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var sessionControlCenterCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                SessionControlHeader(
                    title: "session_control_center",
                    systemImage: "applewatch.radiowaves.left.and.right",
                    statusTitle: "Sync Watch",
                    statusImage: "arrow.triangle.2.circlepath",
                    statusColor: PulseTheme.accent
                )

                SessionMetricStrip(metrics: [
                    .init(title: "remaining_time", value: timeString(estimatedRemainingSeconds), icon: "hourglass"),
                    .init(title: "active_kcal", value: store.todayHealthMetric.map { "\(Int($0.activeEnergyKcal))" } ?? "--", icon: "flame.fill")
                ])

                HStack(spacing: 10) {
                    SessionIconButton(systemImage: "chevron.backward") {
                        moveExercise(by: -1)
                    }
                    .disabled(selectedExerciseIndex == 0)

                    SessionIconButton(systemImage: "chevron.forward") {
                        moveExercise(by: 1)
                    }
                    .disabled(exerciseDrafts.isEmpty || selectedExerciseIndex >= exerciseDrafts.count - 1)
                }

                if let historySummary = selectedExerciseContext.historySummary {
                    Label(historySummary, systemImage: "clock.arrow.circlepath")
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
                SessionControlHeader(
                    title: isTreadmillCandidate ? "Control de cinta" : "Control de ruta",
                    systemImage: isTreadmillCandidate ? "figure.run.treadmill" : "figure.walk",
                    statusTitle: cardioControlStatus,
                    statusImage: routeTracker.isTracking ? "location.fill" : (isTreadmillCandidate ? "figure.run.treadmill" : "pause.circle"),
                    statusColor: routeTracker.isTracking || isTreadmillCandidate ? PulseTheme.accent : PulseTheme.warning
                )

                if showResumeSuggestion {
                    RouteResumePrompt {
                        setWorkoutPaused(false)
                    }
                }

                SessionMetricStrip(metrics: [
                    .init(title: "Tiempo", value: timeString(elapsedSeconds), icon: "timer"),
                    .init(title: "Distancia", value: String(format: "%.2f km", displayedRouteMetrics.distanceKm), icon: "point.topleft.down.curvedto.point.bottomright.up"),
                    .init(title: "Ritmo", value: displayedRouteMetrics.paceText, icon: "speedometer")
                ])

                SessionMetricStrip(metrics: [
                    .init(title: "Agua", value: String(format: "%.2f L", waterLiters), icon: "waterbottle.fill"),
                    .init(title: "Kcal", value: displayedRouteMetrics.energyText, icon: "flame.fill"),
                    .init(title: "Pulso", value: displayedRouteMetrics.heartRateText, icon: "heart.fill")
                ])

                // Pause/resume already lives in the pinned header; this card
                // only exposes hydration logging to avoid a duplicate control.
                SessionControlButton(
                    title: "+250 ml",
                    systemImage: "waterbottle.fill",
                    foregroundStyle: PulseTheme.onColor(PulseTheme.accent),
                    backgroundStyle: PulseTheme.accent,
                    height: 50
                ) {
                    addWater()
                }
            }
        }
    }

    private var routeSessionFeedbackCard: some View {
        PulseCard {
            SessionFeedbackPanel(
                isExpanded: $showSessionFeedback,
                title: "document_session",
                systemImage: "camera.on.rectangle.fill",
                notesPrompt: isTreadmillCandidate ? "Notas de cinta, ritmo o sensaciones" : "Notas de ruta, molestias o terreno",
                audioIdleTitle: "Nota de voz",
                audioRecordingTitle: "Guardar audio",
                sessionRPE: $sessionRPE,
                energyBefore: $energyBefore,
                energyAfter: $energyAfter,
                notes: $sessionNotes,
                photoItems: $sessionPhotoItems,
                attachments: sessionMediaAttachments,
                isRecordingAudio: audioRecorder.isRecording,
                onToggleAudio: toggleSessionAudioNote,
                onCameraCapture: appendSessionCameraImage,
                onVideoCapture: appendSessionVideo
            )
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
                Label("set_tools", systemImage: "wrench.and.screwdriver.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
                Spacer()
                if let plateLoadSummary = selectedExerciseContext.plateLoadSummary {
                    Text(localizedFormat("side_value_format", plateLoadSummary))
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
                .disabled(!selectedExerciseContext.canInsertWarmUpSets)

                workoutToolButton(title: "Back-off", systemImage: "arrow.down.forward.circle.fill") {
                    appendBackOffSetToSelectedExercise()
                }
                .disabled(!selectedExerciseContext.canAppendAdvancedSet)

                workoutToolButton(title: "Dropset", systemImage: "arrow.down.circle.fill") {
                    appendDropSetToSelectedExercise()
                }
                .disabled(!selectedExerciseContext.canAppendAdvancedSet)
            }

            Text(selectedExerciseContext.toolsCaption)
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
            Label(localizedKey(title), systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(PulseTheme.accent)
                .background(PulseTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sessionFeedbackCard: some View {
        PulseCard {
            SessionFeedbackPanel(
                isExpanded: $showSessionFeedback,
                title: "document_session",
                systemImage: "camera.on.rectangle.fill",
                notesPrompt: localizedString("notes_prompt"),
                audioIdleTitle: localizedString("record_audio_note"),
                audioRecordingTitle: localizedString("save_audio_note"),
                sessionRPE: $sessionRPE,
                energyBefore: $energyBefore,
                energyAfter: $energyAfter,
                notes: $sessionNotes,
                photoItems: $sessionPhotoItems,
                attachments: sessionMediaAttachments,
                isRecordingAudio: audioRecorder.isRecording,
                onToggleAudio: toggleSessionAudioNote,
                onCameraCapture: appendSessionCameraImage,
                onVideoCapture: appendSessionVideo
            )
        }
    }

    private var emptyFreeWorkoutCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PulseTheme.accent)
                Text("add_your_first_exercise")
                    .font(.title2.bold())
                Text(emptyWorkoutPrompt)
                    .foregroundStyle(PulseTheme.secondaryText)

                if workout.sessionType == .core, !coreExerciseSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("core_suggested_exercises")
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(PulseTheme.secondaryText)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(coreExerciseSuggestions) { exercise in
                                Button {
                                    addExercise(exercise)
                                } label: {
                                    CoreExerciseSuggestionTile(
                                        exercise: exercise,
                                        language: store.userProfile.preferredLanguage
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    showAddExercise = true
                } label: {
                    Label("find_exercise", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
    }

    private var addExerciseSheetTitle: String {
        workout.sessionType == .core ? localizedString("core_training") : localizedString("add_exercise_sheet_title")
    }

    private var addExerciseInitialMuscle: String {
        workout.sessionType == .core ? "Core" : "Todos"
    }

    private var addExerciseInitialType: Exercise.ExerciseType? {
        workout.sessionType == .core ? .strength : nil
    }

    private var emptyWorkoutPrompt: LocalizedStringKey {
        workout.sessionType == .core
            ? "core_empty_workout_prompt"
            : "free_training_starts_empty_so_you_record_only_what_you_do_today"
    }

    private var coreExerciseSuggestions: [Exercise] {
        let availableEquipment = Set(store.userProfile.availableEquipment.map(normalizedCatalogValue))
        let coreExercises = store.exercises.filter(isCoreExercise)
        let preferred = coreExercises.filter { exercise in
            guard !availableEquipment.isEmpty else { return true }
            let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
            let normalizedRequired = Set(required.map(normalizedCatalogValue))
            return normalizedRequired.contains("bodyweight")
                || normalizedRequired.contains("body only")
                || normalizedRequired.contains("none")
                || !normalizedRequired.isDisjoint(with: availableEquipment)
                || availableEquipment.contains(normalizedCatalogValue(exercise.equipment))
        }
        let source = preferred.isEmpty ? coreExercises : preferred
        return Array(source.sorted { lhs, rhs in
            coreSuggestionRank(lhs) == coreSuggestionRank(rhs)
                ? lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                : coreSuggestionRank(lhs) < coreSuggestionRank(rhs)
        }.prefix(6))
    }

    private func isCoreExercise(_ exercise: Exercise) -> Bool {
        let values = ([exercise.name, exercise.muscleGroup, exercise.equipment]
            + exercise.secondaryMuscles
            + exercise.requiredEquipment
            + exercise.tags
            + [exercise.instructions ?? "", exercise.notes ?? ""])
            .map(normalizedCatalogValue)
        return values.contains("core")
            || values.contains("abs")
            || values.contains("abdominals")
            || values.contains("abdomen")
            || values.contains { value in
                value.contains("plank")
                    || value.contains("crunch")
                    || value.contains("dead bug")
                    || value.contains("mountain climber")
                    || value.contains("hollow")
                    || value.contains("leg raise")
            }
    }

    private func coreSuggestionRank(_ exercise: Exercise) -> Int {
        let name = normalizedCatalogValue(exercise.name)
        if name.contains("plank") { return 0 }
        if name.contains("dead bug") || name.contains("hollow") { return 1 }
        if name.contains("crunch") || name.contains("leg raise") { return 2 }
        if name.contains("mountain climber") { return 3 }
        return 4
    }

    private func normalizedCatalogValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private var nextExerciseTitle: String {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex + 1) else {
            return exerciseDrafts.isEmpty ? localizedString("add_exercise_label") : localizedString("complete_workout")
        }

        return RepsText.exerciseName(
            exerciseDrafts[selectedExerciseIndex + 1].workoutExercise.exercise.name,
            language: store.userProfile.preferredLanguage
        )
    }

    private func exerciseRingColor(ratio: Double) -> Color {
        if ratio >= 1.0 {
            return PulseTheme.growth
        } else if ratio <= 0.0 {
            return PulseTheme.destructive
        } else {
            if ratio < 0.35 {
                return PulseTheme.destructive
            } else if ratio < 0.7 {
                return PulseTheme.warning
            } else {
                return PulseTheme.semanticAction
            }
        }
    }

    private var nextExerciseSubtitle: String {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex + 1) else {
            return exerciseDrafts.isEmpty ? localizedString("free_training_label") : localizedFormat("sets_logged_count_format", completedSets)
        }

        let item = exerciseDrafts[selectedExerciseIndex + 1].workoutExercise
        return "\(item.targetSets) series x \(item.repRange)"
    }

    private var selectedExerciseTitle: String {
        guard let selectedDraft else {
            return localizedString("free_training_label")
        }

        return RepsText.exerciseName(
            selectedDraft.workoutExercise.exercise.name,
            language: store.userProfile.preferredLanguage
        )
    }

    private var selectedSetTargetText: String {
        guard let set = selectedExerciseContext.currentWorkingSet else {
            return localizedString("all_sets_logged")
        }

        if selectedDraft?.workoutExercise.exercise.trackingType == .duration {
            return selectedDraft?.workoutExercise.repRange ?? localizedString("duration")
        }

        if selectedDraft?.workoutExercise.exercise.trackingType == .repsOnly {
            return "\(set.reps) reps"
        }

        let weight = set.weightKg > 0 ? "\(formatWeight(set.weightKg)) kg" : localizedString("bodyweight")
        return "\(weight) x \(set.reps)"
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }

    private var nextLoggingTitle: String {
        guard let next = nextIncompleteSet else {
            return localizedString("all_sets_logged")
        }

        return localizedFormat(
            "log_exercise_set_format",
            RepsText.exerciseName(next.exerciseName, language: store.userProfile.preferredLanguage),
            next.setNumber
        )
    }

    private var selectedMediaBookmarks: [ExerciseMediaBookmark] {
        guard let selectedDraft else {
            return []
        }

        return selectedDraft.workoutExercise.mediaBookmarks + selectedDraft.workoutExercise.exercise.mediaBookmarks
    }

    private var nextIncompleteSet: WorkoutDraftController.PendingSet? {
        WorkoutDraftController.nextIncompleteSet(in: exerciseDrafts)
    }

    private func selectedSetBinding(at setIndex: Int) -> Binding<SetLog> {
        Binding(
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
                let previous = exerciseDrafts[selectedExerciseIndex].sets[setIndex]
                guard isSessionStarted || newValue.completed == previous.completed else {
                    showStartSessionRequiredAlert = true
                    HapticService.notification(.warning)
                    return
                }
                exerciseDrafts[selectedExerciseIndex].sets[setIndex] = newValue
            }
        )
    }

    private func completeSelectedSetIfNeeded(setIndex: Int, completed: Bool) {
        guard completed else { return }
        guard isSessionStarted else {
            showStartSessionRequiredAlert = true
            HapticService.notification(.warning)
            return
        }
        handleSetCompleted(exerciseIndex: selectedExerciseIndex, setIndex: setIndex)
    }

    private var selectedExerciseNotesBinding: Binding<String> {
        Binding(
            get: { selectedDraft?.notes ?? "" },
            set: { newValue in
                guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
                exerciseDrafts[selectedExerciseIndex].notes = newValue
            }
        )
    }

    private func toggleExerciseAudioNote() {
        Task {
            if audioRecorder.isRecording {
                if let attachment = audioRecorder.stopRecording(note: selectedDraft?.voiceNote),
                   exerciseDrafts.indices.contains(selectedExerciseIndex) {
                    exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(attachment)
                    HapticService.notification(.success)
                }
            } else {
                let granted = await PermissionService.shared.requestMicrophone()
                if granted {
                    audioRecorder.startRecording()
                    HapticService.selection()
                } else {
                    permissionDeniedMessage = PermissionService.shared.deniedMessage ?? localizedString("microphone_blocked_reps_settings")
                    showPermissionDenied = true
                    HapticService.notification(.warning)
                }
            }
        }
    }

    private func appendExerciseCameraImage(_ image: UIImage) {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex),
              let data = image.jpegData(compressionQuality: 0.82) else {
            return
        }
        exerciseDrafts[selectedExerciseIndex].mediaAttachments.append(
            WorkoutMediaAttachment(kind: .image, data: data)
        )
        HapticService.notification(.success)
    }

    private func completeNextAvailableSet() {
        guard isSessionStarted else {
            showStartSessionRequiredAlert = true
            HapticService.notification(.warning)
            return
        }
        guard let next = nextIncompleteSet else {
            return
        }

        withAnimation(.snappy(duration: 0.22)) {
            selectedExerciseIndex = next.exerciseIndex
            handleSetCompleted(exerciseIndex: next.exerciseIndex, setIndex: next.setIndex)
        }
        if completedSets == totalSets {
            HapticService.notification(.success)
        } else {
            HapticService.impact(.light)
        }
    }

    private func moveExercise(by offset: Int) {
        guard !exerciseDrafts.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            selectedExerciseIndex = min(max(selectedExerciseIndex + offset, 0), exerciseDrafts.count - 1)
        }
    }

    private func adjustRest(by seconds: Int) {
        HapticService.selection()
        withAnimation(.snappy(duration: 0.18)) {
            let adjusted = WorkoutRestController.adjustedRest(
                current: WorkoutRestController.RestState(
                    restSeconds: restSeconds,
                    restDuration: restDuration,
                    restStartedAt: restStartedAt
                ),
                remainingSeconds: currentRestRemainingSeconds(),
                deltaSeconds: seconds
            )
            restSeconds = adjusted.restSeconds
            restDuration = adjusted.restDuration
            restStartedAt = adjusted.restStartedAt
        }
        let remaining = currentRestRemainingSeconds()
        if remaining > 0 {
            let isNextExerciseDifferent = nextIncompleteSet?.exerciseIndex != selectedExerciseIndex
            NotificationService.scheduleRestEndNotification(
                after: remaining,
                nextExerciseName: isNextExerciseDifferent ? store.activeWorkoutStatus?.nextExerciseName : nil
            )
        } else {
            NotificationService.cancelRestEndNotification()
        }
    }

    private func toggleRestTimer() {
        HapticService.selection()
        if currentRestRemainingSeconds() == 0 {
            let kind = restKind
            startRest(duration: kind == .exerciseChange ? workout.restBetweenExercisesSeconds : currentRestDuration, kind: kind)
        } else {
            stopRest()
        }
    }

    private func addWater() {
        HapticService.selection()
        if !isSessionStarted {
            startPreparedSession()
        }
        withAnimation(.snappy(duration: 0.18)) {
            waterLiters = min(waterLiters + 0.25, 8)
        }
        publishActiveWorkoutStatus()
    }

    private func toggleSessionAudioNote() {
        Task {
            if audioRecorder.isRecording {
                if let attachment = audioRecorder.stopRecording(note: sessionVoiceNote) {
                    sessionMediaAttachments.append(attachment)
                    HapticService.notification(.success)
                }
            } else {
                let granted = await PermissionService.shared.requestMicrophone()
                if granted {
                    audioRecorder.startRecording()
                    HapticService.selection()
                } else {
                    permissionDeniedMessage = PermissionService.shared.deniedMessage ?? localizedString("microphone_blocked_reps_settings")
                    showPermissionDenied = true
                    HapticService.notification(.warning)
                }
            }
        }
    }

    private func appendSessionCameraImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        sessionMediaAttachments.append(
            WorkoutMediaAttachment(kind: .image, data: data)
        )
        HapticService.notification(.success)
    }

    private func appendSessionVideo(_ data: Data, thumbnail: UIImage?) {
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.7)
        sessionMediaAttachments.append(
            WorkoutMediaAttachment(kind: .video, data: data.isEmpty ? nil : data, thumbnailData: thumbnailData)
        )
        HapticService.notification(.success)
    }

    private func moveDraft(from source: Int, to destination: Int) {
        guard exerciseDrafts.indices.contains(source),
              exerciseDrafts.indices.contains(destination),
              source != destination else { return }

        HapticService.selection()
        let selectedID = selectedDraft?.workoutExercise.id
        withAnimation(.snappy(duration: 0.22)) {
            if let newIndex = WorkoutDraftController.moveExercise(
                from: source,
                to: destination,
                in: &store.activeWorkoutDrafts,
                selectedWorkoutExerciseID: selectedID
            ) {
                selectedExerciseIndex = newIndex
            }
        }
        syncActiveWorkoutExercises()
        publishActiveWorkoutStatus()
    }

    private func deleteDraft(at index: Int) {
        guard exerciseDrafts.indices.contains(index) else { return }

        HapticService.notification(.warning)
        withAnimation(.snappy(duration: 0.24)) {
            if let newIndex = WorkoutDraftController.removeExercise(
                at: index,
                from: &store.activeWorkoutDrafts
            ) {
                selectedExerciseIndex = newIndex
            } else {
                selectedExerciseIndex = 0
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
                    permissionDeniedMessage = PermissionService.shared.deniedMessage ?? localizedString("microphone_blocked_reps_settings")
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
            selectedExerciseIndex = WorkoutDraftController.addExercise(exercise, to: &store.activeWorkoutDrafts)
        }
        syncActiveWorkoutExercises()
    }

    private func replaceExercise(at index: Int, with exercise: Exercise) {
        guard exerciseDrafts.indices.contains(index) else { return }
        withAnimation(.snappy(duration: 0.24)) {
            if WorkoutDraftController.replaceExercise(at: index, with: exercise, in: &store.activeWorkoutDrafts) {
                selectedExerciseIndex = index
            }
        }
        syncActiveWorkoutExercises()
    }

    private func skipSelectedExercise() {
        guard selectedExerciseIndex < exerciseDrafts.count - 1 else { return }

        withAnimation(.snappy) {
            selectedExerciseIndex += 1
        }
    }

    private func removeSelectedExercise() {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }

        withAnimation(.snappy(duration: 0.24)) {
            if let newIndex = WorkoutDraftController.removeExercise(
                at: selectedExerciseIndex,
                from: &store.activeWorkoutDrafts
            ) {
                selectedExerciseIndex = newIndex
            }
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private var hasIncompleteSetsForSelectedExercise: Bool {
        guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return false }
        return exerciseDrafts[selectedExerciseIndex].sets.contains { !$0.completed }
    }

    private func completeAllSetsForSelectedExercise() {
        guard isSessionStarted else {
            showStartSessionRequiredAlert = true
            HapticService.notification(.warning)
            return
        }
        guard exerciseDrafts.indices.contains(selectedExerciseIndex) else { return }
        let pendingSetIndices = exerciseDrafts[selectedExerciseIndex].sets.indices.filter {
            !exerciseDrafts[selectedExerciseIndex].sets[$0].completed
        }
        guard !pendingSetIndices.isEmpty else { return }

        withAnimation(.snappy(duration: 0.22)) {
            for setIndex in pendingSetIndices {
                handleSetCompleted(exerciseIndex: selectedExerciseIndex, setIndex: setIndex)
            }
        }
        HapticService.notification(.success)
    }

    private func syncActiveWorkoutExercises() {
        if var activeWorkout = store.activeWorkout {
            activeWorkout.exercises = exerciseDrafts.map(\.workoutExercise)
            store.activeWorkout = activeWorkout
        }
    }

    private func addSetToSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            _ = WorkoutDraftController.addSet(to: &store.activeWorkoutDrafts, selectedIndex: selectedExerciseIndex)
        }
    }

    private func deleteSetFromSelectedExercise(at setIndex: Int) {
        withAnimation(.snappy(duration: 0.25)) {
            _ = WorkoutDraftController.removeSet(from: &store.activeWorkoutDrafts, exerciseIndex: selectedExerciseIndex, setIndex: setIndex)
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private func insertWarmUpSetsForSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            guard WorkoutDraftController.insertWarmUpSets(
                to: &store.activeWorkoutDrafts,
                selectedIndex: selectedExerciseIndex,
                targetSet: selectedExerciseContext.currentWorkingSet
            ) else { return }
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private func appendDropSetToSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            guard WorkoutDraftController.appendDropSet(
                to: &store.activeWorkoutDrafts,
                selectedIndex: selectedExerciseIndex
            ) else { return }
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
        }
    }

    private func appendBackOffSetToSelectedExercise() {
        withAnimation(.snappy(duration: 0.25)) {
            guard WorkoutDraftController.appendBackOffSet(
                to: &store.activeWorkoutDrafts,
                selectedIndex: selectedExerciseIndex
            ) else { return }
            syncActiveWorkoutExercises()
            publishActiveWorkoutStatus()
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
        guard isSessionStarted else {
            showStartSessionRequiredAlert = true
            HapticService.notification(.warning)
            return
        }
        guard exerciseDrafts.indices.contains(exerciseIndex),
              exerciseDrafts[exerciseIndex].sets.indices.contains(setIndex) else {
            return
        }

        elapsedSeconds = elapsedWorkoutSeconds()
        let completedSet = exerciseDrafts[exerciseIndex].sets[setIndex]
        let exercise = exerciseDrafts[exerciseIndex].workoutExercise.exercise
        lastCompletedSetUndoContext = UndoSetContext(
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            previousLastSetCompletedAtSeconds: lastSetCompletedAtSeconds
        )
        let outcome = WorkoutDraftController.completeSet(
            in: &store.activeWorkoutDrafts,
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            elapsedSeconds: elapsedSeconds,
            lastSetCompletedAtSeconds: lastSetCompletedAtSeconds,
            isPersonalRecord: ExerciseHistoryAnalyzer.isPersonalRecord(completedSet, for: exercise, in: store.workoutSessions),
            betweenExercisesRestSeconds: workout.restBetweenExercisesSeconds
        )
        lastSetCompletedAtSeconds = elapsedSeconds
        showSetCompletionFeedback(
            exerciseName: RepsText.exerciseName(exercise.name, language: store.userProfile.preferredLanguage),
            setNumber: setIndex + 1
        )

        if let duration = outcome?.restDurationSeconds {
            startRest(duration: duration, kind: outcome?.shouldMoveToNextExercise == true ? .exerciseChange : .betweenSets)
        } else {
            stopRest()
        }
        publishActiveWorkoutStatus()
    }

    /// Begins a date-anchored rest countdown so the timer survives background suspension.
    private func startRest(duration: Int, kind: RestPhaseKind = .betweenSets) {
        guard duration > 0 else { stopRest(); return }
        restKind      = kind
        restDuration  = duration
        restStartedAt = Date()
        restSeconds   = duration
        let isNextExerciseDifferent = nextIncompleteSet?.exerciseIndex != selectedExerciseIndex
        NotificationService.scheduleRestEndNotification(
            after: duration,
            nextExerciseName: isNextExerciseDifferent ? store.activeWorkoutStatus?.nextExerciseName : nil
        )
    }

    private func stopRest() {
        restSeconds   = 0
        restStartedAt = nil
        restDuration  = 0
        restKind      = .betweenSets
        NotificationService.cancelRestEndNotification()
    }

    /// Called when the exercise-change timer reaches zero: auto-advance to
    /// whichever exercise still has pending sets (falls back to the next
    /// index if the plan is otherwise complete).
    private func advanceToNextExerciseAfterTransition() {
        withAnimation(.snappy(duration: 0.25)) {
            if let next = nextIncompleteSet {
                selectedExerciseIndex = next.exerciseIndex
            } else if !exerciseDrafts.isEmpty {
                selectedExerciseIndex = min(selectedExerciseIndex + 1, exerciseDrafts.count - 1)
            }
        }
    }

    private func applyAutoProgressionIfNeeded() {
        guard store.hasFeatureAccess(.configurableProgression),
              store.userProfile.autoProgressionEnabled,
              !hasAppliedProgression else {
            return
        }

        hasAppliedProgression = true
        _ = WorkoutDraftController.applyAutoProgression(
            to: &store.activeWorkoutDrafts,
            sessions: store.workoutSessions,
            weightIncrementKg: store.userProfile.weightIncrementKg
        )
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

}

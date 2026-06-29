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
    @State private var activeBookmark: ExerciseMediaBookmark?
    @State private var isPaused = false
    @State private var restSeconds = 0
    @State private var restStartedAt: Date? = nil   // ← date-based rest timing
    @State private var restDuration = 0              // duration when rest started
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
    @State private var showStopConfirmation = false
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
            return PulseTheme.accent
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
            ExercisePickerSheet(title: localizedString("add_exercise_sheet_title"), exercises: store.exercises, currentExercise: nil) { exercise in
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
        .alert("add_at_least_one_exercise", isPresented: $showMissingExerciseAlert) {
            Button("find_exercise") {
                showAddExercise = true
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("cannot_start_a_session_without_exercises")
        }
        .confirmationDialog("stop_session", isPresented: $showStopConfirmation, titleVisibility: .visible) {
            Button("detener_y_descartar", role: .destructive) {
                stopWorkout()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this_active_session_and_any_unsaved_changes_will_be_discarded")
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
                            routeProgressCard
                                .frame(width: contentWidth)
                            batteryCard
                                .frame(width: contentWidth)
                            if isSessionStarted {
                                routeSessionControlCard
                                    .frame(width: contentWidth)
                                routeSessionFeedbackCard
                                    .frame(width: contentWidth)
                            }
                            if isRouteCandidate {
                                liveRouteMapCard
                                    .frame(width: contentWidth)
                            }
                        } else {
                            workoutCommandCard
                                .frame(width: contentWidth)
                            // Where am I: per-exercise progress and quick switch.
                            exerciseSwitcher
                                .frame(width: contentWidth)
                            // Primary logging surface.
                            if exerciseDrafts.isEmpty {
                                emptyFreeWorkoutCard
                                    .frame(width: contentWidth)
                            } else {
                                exerciseCard
                                    .frame(width: contentWidth)
                            }
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
            showStopConfirmation = true
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
            finishWorkout()
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
                    HapticService.notification(.success)
                }
            }
        }

        // Comprobar si se ha agotado el tiempo planificado
        let targetSeconds = plannedDurationMinutes * 60
        if currentElapsed >= targetSeconds, !hasShownDurationAlert {
            elapsedSeconds = currentElapsed
            hasShownDurationAlert = true
            showDurationExhaustedAlert = true
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
            onStart: startPreparedSession,
            onCompleteNext: completeNextAvailableSet,
            onDecreaseRest: { adjustRest(by: -15) },
            onIncreaseRest: { adjustRest(by: 15) },
            onSkipRest: toggleRestTimer,
            onUndo: lastCompletedSetUndoContext == nil ? nil : { undoLastCompletedSet() },
            onAddSet: addSetToSelectedExercise,
            onReplaceExercise: { replacementExerciseIndex = selectedExerciseIndex }
        )
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
                                    fallbackSize: .caption.weight(.bold),
                                    catalog: store.exercises
                                )
                                .equatable()
                                .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    ZStack {
                                        Circle()
                                            .fill(isActive ? PulseTheme.accentMuted : PulseTheme.card)
                                            .frame(width: 18, height: 18)
                                        Circle()
                                            .trim(from: 0, to: ratio)
                                            .stroke(isActive ? PulseTheme.accent : PulseTheme.ringStand, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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
                                HStack(spacing: 6) {
                                    Text(localizedFormat("sets_fraction_format", completedCount, totalCount))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    if draft.workoutExercise.supersetGroup != nil {
                                        Text("superset_label")
                                            .font(.caption2.weight(.heavy))
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(PulseTheme.accent.opacity(0.16), in: Capsule())
                                            .foregroundStyle(PulseTheme.accent)
                                    }
                                }
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
        ActiveExerciseOrderCard(
            drafts: exerciseDrafts,
            selectedExerciseIndex: selectedExerciseIndex,
            language: store.userProfile.preferredLanguage,
            onAdd: {
                HapticService.selection()
                showAddExercise = true
            },
            onMove: moveDraft,
            onToggleSuperset: toggleSuperset
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

    private var restCard: some View {
        let undoAction: (() -> Void)? = lastCompletedSetUndoContext == nil
            ? nil
            : { undoLastCompletedSet() }
        return ActiveRestPanel(
            isRestActive: lastSetCompletedAtSeconds != nil,
            currentRestSeconds: currentRestRemainingSeconds(),
            restStartedAt: restStartedAt,
            restDuration: restDuration,
            onDecrease: { adjustRest(by: -15) },
            onIncrease: { adjustRest(by: 15) },
            onSkipOrRestart: toggleRestTimer,
            onUndo: undoAction
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
        stopRest()
        publishActiveWorkoutStatus()
        HapticService.impact(.rigid)
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
            return PulseTheme.accent
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
                    ActiveSetRowsList(
                        setIndices: Array(sets.indices),
                        trackingType: selectedDraft?.workoutExercise.exercise.trackingType ?? .weightReps,
                        isSessionStarted: isSessionStarted,
                        setBinding: selectedSetBinding,
                        onCompletionChanged: completeSelectedSetIfNeeded
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
        PulseCard {
            HStack(spacing: 16) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(PulseTheme.accent)
                    .frame(width: 58, height: 58)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                VStack(alignment: .leading) {
                    Text("next_uppercase").font(.caption.weight(.bold)).foregroundStyle(PulseTheme.accent)
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
                SessionControlHeader(
                    title: "session_control_center",
                    systemImage: "applewatch.radiowaves.left.and.right",
                    statusTitle: "Sync Watch",
                    statusImage: "arrow.triangle.2.circlepath",
                    statusColor: PulseTheme.accent
                )

                SessionMetricStrip(metrics: [
                    .init(title: "remaining_time", value: timeString(estimatedRemainingSeconds), icon: "hourglass"),
                    .init(title: "water_metric", value: String(format: "%.2f L", waterLiters), icon: "waterbottle.fill"),
                    .init(title: "active_kcal", value: store.todayHealthMetric.map { "\(Int($0.activeEnergyKcal))" } ?? "--", icon: "flame.fill")
                ])

                HStack(spacing: 10) {
                    SessionIconButton(systemImage: "chevron.backward") {
                        moveExercise(by: -1)
                    }
                    .disabled(selectedExerciseIndex == 0)

                    SessionControlButton(
                        title: "+250 ml",
                        systemImage: "waterbottle.fill",
                        foregroundStyle: .white,
                        backgroundStyle: PulseTheme.accent
                    ) {
                        addWater()
                    }

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

                HStack(spacing: 10) {
                    SessionControlButton(
                        title: isPaused ? "Reanudar" : "Pausar",
                        systemImage: isPaused ? "play.fill" : "pause.fill",
                        foregroundStyle: isPaused ? .black : .white,
                        backgroundStyle: isPaused ? PulseTheme.accent : PulseTheme.warning,
                        height: 50
                    ) {
                        setWorkoutPaused(!isPaused)
                    }
                    .disabled(!isSessionStarted)

                    SessionControlButton(
                        title: "+250 ml",
                        systemImage: "waterbottle.fill",
                        foregroundStyle: PulseTheme.accent,
                        backgroundStyle: PulseTheme.accent.opacity(0.12),
                        height: 50
                    ) {
                        addWater()
                    }
                }

                SessionMetricStrip(metrics: [
                    .init(title: "Agua", value: String(format: "%.2f L", waterLiters), icon: "waterbottle.fill"),
                    .init(title: "Kcal", value: displayedRouteMetrics.energyText, icon: "flame.fill"),
                    .init(title: "Pulso", value: displayedRouteMetrics.heartRateText, icon: "heart.fill")
                ])
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
                Text("free_training_starts_empty_so_you_record_only_what_you_do_today")
                    .foregroundStyle(PulseTheme.secondaryText)
                Button {
                    showAddExercise = true
                } label: {
                    Label("find_exercise", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
            }
        }
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
                exerciseDrafts[selectedExerciseIndex].sets[setIndex] = newValue
            }
        )
    }

    private func completeSelectedSetIfNeeded(setIndex: Int, completed: Bool) {
        guard completed else { return }
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
            HapticService.impact(.medium)
            startPreparedSession()
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
            NotificationService.scheduleRestEndNotification(
                after: remaining,
                nextExerciseName: store.activeWorkoutStatus?.nextExerciseName
            )
        } else {
            NotificationService.cancelRestEndNotification()
        }
    }

    private func toggleRestTimer() {
        HapticService.selection()
        if currentRestRemainingSeconds() == 0 {
            startRest(duration: currentRestDuration)
        } else {
            stopRest()
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

        if let duration = outcome?.restDurationSeconds {
            startRest(duration: duration)
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
        NotificationService.scheduleRestEndNotification(
            after: duration,
            nextExerciseName: store.activeWorkoutStatus?.nextExerciseName
        )
    }

    private func stopRest() {
        restSeconds   = 0
        restStartedAt = nil
        restDuration  = 0
        NotificationService.cancelRestEndNotification()
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

private struct ExerciseReplacementTarget: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct UndoSetContext {
    let exerciseIndex: Int
    let setIndex: Int
    let previousLastSetCompletedAtSeconds: Int?
}

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if let currentExercise {
                        replacementHeader(for: currentExercise)
                    }

                    HStack(spacing: 10) {
                        Picker("muscle", selection: $selectedMuscle) {
                            ForEach(muscles, id: \.self) { muscle in
                                Text(muscle == "Todos" ? muscle : RepsText.muscle(muscle, language: store.userProfile.preferredLanguage)).tag(muscle)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("equipo", selection: $selectedEquipment) {
                            ForEach(equipmentOptions, id: \.self) { equipment in
                                Text(equipment == "Todos" ? equipment : RepsText.equipment(equipment, language: store.userProfile.preferredLanguage)).tag(equipment)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Picker("training_type", selection: $selectedType) {
                                Text("all").tag(Optional<Exercise.ExerciseType>.none)
                                ForEach(Exercise.ExerciseType.allCases) { type in
                                    Text(type.localizedTitle).tag(Optional(type))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("difficulty_2", selection: $selectedDifficulty) {
                                Text("any").tag(Optional<Exercise.Difficulty>.none)
                                ForEach(Exercise.Difficulty.allCases) { difficulty in
                                    Text(difficulty.localizedTitle).tag(Optional(difficulty))
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("environment_2", selection: $selectedEnvironment) {
                                Text("any").tag(Optional<Exercise.Environment>.none)
                                ForEach(Exercise.Environment.allCases) { environment in
                                    Text(environment.localizedTitle).tag(Optional(environment))
                                }
                            }
                            .pickerStyle(.menu)

                            Toggle("mi_equipo", isOn: $onlyAvailableEquipment)
                                .toggleStyle(.button)
                        }
                    }
                    .font(.subheadline.weight(.semibold))

                    if filteredExercises.isEmpty {
                        PulseEmptyState(
                            title: "Sin ejercicios",
                            message: "Ajusta la búsqueda o los filtros de músculo y equipo para ver más resultados.",
                            systemImage: "magnifyingglass"
                        )
                        .padding(.top, 24)
                    } else {
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
                                        language: store.userProfile.preferredLanguage,
                                        catalog: store.exercises
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 16)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .searchable(text: $searchText, prompt: "Buscar por nombre, músculo o equipo")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("close") {
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
            Text("actual")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(PulseTheme.grouped, in: Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)

            ExerciseMediaThumbnail(exercise: exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
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

            Text("mejores_sustituciones")
                .font(.title3.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }
}

private extension Exercise.ExerciseType {
    var localizedTitle: String {
        switch self {
        case .strength: localizedString("Strength")
        case .cardio: "Cardio"
        case .mobility: localizedString("Mobility")
        case .stretching: localizedString("Stretching")
        case .hiit: "HIIT"
        }
    }
}

private extension Exercise.Difficulty {
    var localizedTitle: String {
        switch self {
        case .low: localizedString("Beginner")
        case .medium: localizedString("Intermediate")
        case .high: localizedString("Advanced")
        }
    }
}

private extension Exercise.Environment {
    var localizedTitle: String {
        switch self {
        case .home: localizedString("Home")
        case .gym: localizedString("Gym")
        case .both: localizedString("Home and gym")
        }
    }
}

private struct ReplacementExerciseRow: View {
    let exercise: Exercise
    let currentExercise: Exercise?
    let availableEquipment: [String]
    let gender: BodyGender
    let language: String
    let catalog: [Exercise]

    var body: some View {
        HStack(spacing: 14) {
            ExerciseMediaThumbnail(exercise: exercise, gender: gender, catalog: catalog)
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
                        .foregroundStyle(PulseTheme.accent)
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
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(badgeColor.opacity(0.14), in: Capsule())
                    .lineLimit(1)
            }

            Image(systemName: currentExercise == nil ? "plus.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(currentExercise == nil ? PulseTheme.accent : PulseTheme.secondaryText)
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

    private var badgeColor: Color {
        guard let currentExercise else { return PulseTheme.ringStand }
        // "Essential" (same tracking model) reads as the strongest match → growth green.
        if normalized(exercise.equipment) != normalized(currentExercise.equipment),
           exercise.trackingType == currentExercise.trackingType {
            return PulseTheme.growth
        }
        return PulseTheme.ringStand
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

private struct ActiveSetRowsList: View {
    let setIndices: [Int]
    let trackingType: Exercise.TrackingType
    let isSessionStarted: Bool
    let setBinding: (Int) -> Binding<SetLog>
    let onCompletionChanged: (Int, Bool) -> Void

    var body: some View {
        ForEach(setIndices, id: \.self) { setIndex in
            SetRow(set: setBinding(setIndex), trackingType: trackingType) { completed in
                onCompletionChanged(setIndex, completed)
            }
            .disabled(!isSessionStarted)
        }
    }
}

private struct ActiveAdvancedSetFieldsList: View {
    let setIndices: [Int]
    let showSetType: Bool
    let showRPE: Bool
    let showRIR: Bool
    let showTempo: Bool
    let setBinding: (Int) -> Binding<SetLog>

    var body: some View {
        VStack(spacing: 10) {
            ForEach(setIndices, id: \.self) { setIndex in
                AdvancedSetFields(
                    set: setBinding(setIndex),
                    showSetType: showSetType,
                    showRPE: showRPE,
                    showRIR: showRIR,
                    showTempo: showTempo
                )
            }
        }
        .padding(.top, 8)
    }
}

private struct SessionControlHeader: View {
    let title: String
    let systemImage: String
    let statusTitle: String
    let statusImage: String
    let statusColor: Color

    var body: some View {
        HStack {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.headline)
            Spacer()
            Label(statusTitle, systemImage: statusImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(statusColor)
        }
    }
}

private struct SessionMetricStrip: View {
    struct Metric: Identifiable {
        let title: String
        let value: String
        let icon: String

        var id: String { title }
    }

    let metrics: [Metric]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics) { metric in
                MiniSessionPill(title: metric.title, value: metric.value, icon: metric.icon)
            }
        }
    }
}

private struct PlannedDurationEditor: View {
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            Label("planned_duration", systemImage: "timer")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.secondaryText)

            Spacer(minLength: 8)

            Button {
                minutes = max(5, minutes - 5)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("reduce_duration")

            Text("\(minutes) min")
                .font(.headline.weight(.black).monospacedDigit())
                .frame(minWidth: 72)

            Button {
                minutes = min(180, minutes + 5)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.black))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("increase_duration")
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct RouteTrackingPanel: View {
    let isTracking: Bool
    let statusText: String
    let statusBadge: String
    let primaryMetrics: [SessionMetricStrip.Metric]
    let secondaryMetrics: [SessionMetricStrip.Metric]

    private var statusColor: Color {
        isTracking ? PulseTheme.accent : PulseTheme.secondaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: isTracking ? "location.fill" : "map")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(statusColor)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("gps_y_ruta")
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                Spacer()
                Text(statusBadge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            SessionMetricStrip(metrics: primaryMetrics)
            SessionMetricStrip(metrics: secondaryMetrics)
        }
    }
}

private struct LiveRouteMapPanel: View {
    let routePoints: [RoutePoint]
    let isSessionStarted: Bool
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("mapa_en_vivo", systemImage: "map.fill")
                    .font(.headline)
                Spacer()
                Text(routePoints.isEmpty ? "Esperando GPS" : "\(routePoints.count) puntos")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            ZStack {
                RouteMapPreview(routePoints: routePoints)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                if routePoints.count < 2 {
                    VStack(spacing: 10) {
                        Image(systemName: "location.magnifyingglass")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PulseTheme.accent)
                        Text(localizedString(isSessionStarted ? "route_drawing_started" : "route_drawing_pending"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }

                Button(action: onExpand) {
                    Label("ampliar_mapa", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .disabled(routePoints.isEmpty)
                .opacity(routePoints.isEmpty ? 0 : 1)
            }
        }
    }
}

private struct ExpandedRouteMapView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let routePoints: [RoutePoint]

    var body: some View {
        ZStack(alignment: .top) {
            RouteMapPreview(routePoints: routePoints, followsRoute: false, showsControls: true)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Text(localizedKey(title))
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .destructiveGlassCircle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.72), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
        }
        .presentationBackground(.black)
    }
}

private struct SessionIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 48, height: 48)
                .foregroundStyle(PulseTheme.accent)
                .background(PulseTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }
}

private struct SessionControlButton: View {
    let title: String
    let systemImage: String
    let foregroundStyle: Color
    let backgroundStyle: Color
    var height: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(localizedKey(title), systemImage: systemImage)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
    }
}

private struct RouteResumePrompt: View {
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(PulseTheme.accent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("movement_detected")
                    .font(.subheadline.weight(.bold))
                Text("resume_to_continue_tracking_route_and_distance")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            Button("reanudar", action: onResume)
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
}

private struct MiniSessionPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(localizedKey(title))
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
                Label("tarjeta_gym", systemImage: pass.codeType == .qr ? "qrcode" : "barcode")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.accent)
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

private struct SessionFeedbackPanel: View {
    @Binding var isExpanded: Bool
    let title: String
    let systemImage: String
    let notesPrompt: String
    let audioIdleTitle: String
    let audioRecordingTitle: String
    @Binding var sessionRPE: Double
    @Binding var energyBefore: Double
    @Binding var energyAfter: Double
    @Binding var notes: String
    @Binding var photoItems: [PhotosPickerItem]
    let attachments: [WorkoutMediaAttachment]
    let isRecordingAudio: Bool
    let onToggleAudio: () -> Void
    let onCameraCapture: (UIImage) -> Void
    let onVideoCapture: (Data, UIImage?) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                effortFields

                TextField(notesPrompt, text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(PulseTheme.grouped)
                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                HStack(spacing: 10) {
                    Button(action: onToggleAudio) {
                        Label(isRecordingAudio ? audioRecordingTitle : audioIdleTitle, systemImage: isRecordingAudio ? "stop.fill" : "mic.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(isRecordingAudio ? .white : PulseTheme.accent)
                            .background(isRecordingAudio ? PulseTheme.destructive : PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }

                    MediaSourceMenu(
                        maxSelectionCount: 8,
                        photoPickerItems: $photoItems,
                        onCameraCapture: onCameraCapture,
                        onVideoCapture: onVideoCapture
                    ) {
                        let mediaCount = attachments.filter { $0.kind == .image || $0.kind == .video }.count
                        Label("\(mediaCount)", systemImage: "photo.badge.plus")
                            .font(.headline)
                            .frame(width: 72, height: 48)
                            .foregroundStyle(PulseTheme.accent)
                            .background(PulseTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }

                if !attachments.isEmpty {
                    AttachmentPreviewStrip(attachments: attachments)
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 10) {
                Label(localizedKey(title), systemImage: systemImage)
                    .font(.headline)
                Spacer(minLength: 8)
                // Media-type hint so the panel reads as the documentation menu
                // even while collapsed.
                HStack(spacing: 9) {
                    Image(systemName: "text.alignleft")
                    Image(systemName: "mic.fill")
                    Image(systemName: "camera.fill")
                    Image(systemName: "video.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private var effortFields: some View {
        VStack(spacing: 18) {
            HStack {
                Label("esfuerzo_rpe", systemImage: "flame.fill")
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
                Label("energy_before", systemImage: "battery.50")
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
                Label("energy_after", systemImage: "battery.100")
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
    }
}

private struct ExerciseBookmarkStrip: View {
    let bookmarks: [ExerciseMediaBookmark]
    @Binding var activeBookmark: ExerciseMediaBookmark?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("quick_bookmarks", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PulseTheme.accent)
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
                            .foregroundStyle(PulseTheme.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 46)
                            .background(PulseTheme.accent.opacity(0.12))
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
                        Text("could_not_load_the_video")
                            .font(.headline)
                        Text("the_bookmark_url_is_invalid")
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
                        
                        Text(localizedFormat("closing_in_seconds_format", timeRemaining))
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
                    Button("close") {
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
    var followsRoute = true
    var showsControls = false
    @State private var position: MapCameraPosition = .automatic
    @State private var userHasInteracted = false

    private var coordinates: [CLLocationCoordinate2D] {
        routePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(position: $position) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(PulseTheme.accent, lineWidth: 5)
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
            if showsControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in userHasInteracted = true })
        .simultaneousGesture(MagnifyGesture().onChanged { _ in userHasInteracted = true })
        .onAppear {
            fitRoute()
        }
        .onChange(of: routePoints.count) { _, _ in
            if followsRoute, !userHasInteracted {
                fitRoute()
            }
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
    private var startedAt: Date?

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
            return localizedString("recording_live_route")
        }
        switch authorizationStatus {
        case .denied, .restricted:
            return localizedString("location_permission_denied")
        case .notDetermined:
            return localizedString("ready_to_request_permission")
        default:
            return routePoints.isEmpty ? localizedString("no_route_started") : localizedString("route_paused")
        }
    }

    func requestAuthorization() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startNewRoute(startedAt: Date) {
        routePoints = []
        lastLocation = nil
        totalDistanceMeters = 0
        self.startedAt = startedAt
        startUpdatingLocation()
    }

    func resume() {
        startUpdatingLocation()
    }

    private func startUpdatingLocation() {
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
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        shouldStartAfterAuthorization = false
        isTracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func paceText(elapsedSeconds: Int) -> String {
        SharedWorkoutSnapshot.routePaceText(averagePaceSecondsPerKm(elapsedSeconds: elapsedSeconds))
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
        SharedWorkoutSnapshot.routeSpeedText(averageSpeedKmh(elapsedSeconds: elapsedSeconds))
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            if shouldStartAfterAuthorization,
               status == .authorizedWhenInUse || status == .authorizedAlways {
                startUpdatingLocation()
            } else if status == .denied || status == .restricted {
                shouldStartAfterAuthorization = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations where shouldAccept(location) {
                if let lastLocation {
                    let segmentDistance = location.distance(from: lastLocation)
                    if segmentDistance >= 1, segmentDistance <= 250 {
                        totalDistanceMeters += segmentDistance
                    }
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

    private func shouldAccept(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 35 else {
            return false
        }
        if let startedAt, location.timestamp < startedAt.addingTimeInterval(-3) {
            return false
        }
        if location.speed > 8.5 {
            return false
        }
        if let lastLocation, location.timestamp <= lastLocation.timestamp {
            return false
        }
        return true
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
                Text(localizedKey(title))
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

private struct SetRow: View {
    @Binding var set: SetLog
    let trackingType: Exercise.TrackingType
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

                ForEach(columnLabels, id: \.self) { label in
                    Text(localizedKey(label))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                }

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

                if trackingType == .weightReps {
                    InlineStepper(
                        value: $set.weightKg,
                        range: 0...400,
                        step: 2.5,
                        formatter: { String(format: "%.1f", $0) }
                    )
                    .frame(maxWidth: .infinity)
                }

                InlineStepper(
                    value: Binding(
                        get: { Double(set.reps) },
                        set: { set.reps = Int($0) }
                    ),
                    range: 0...durationOrRepUpperBound,
                    step: trackingType == .duration ? 5 : 1,
                    formatter: { trackingType == .duration ? "\(Int($0))s" : String(Int($0)) }
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

    private var columnLabels: [String] {
        switch trackingType {
        case .weightReps:
            return ["weight_kg_3", "reps_4"]
        case .repsOnly:
            return ["reps_4"]
        case .duration:
            return ["Time"]
        }
    }

    private var durationOrRepUpperBound: Double {
        trackingType == .duration ? 600 : 100
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
                Text(localizedFormat("set_number_format", set.setNumber))
                    .font(.subheadline.weight(.bold))
                Spacer()
                if set.isPersonalRecord {
                    Label("pr_2", systemImage: "trophy.fill")
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
                TextField("tempo_2", text: Binding(
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
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("bajar_valor")

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
                    .foregroundStyle(PulseTheme.accent)
                    .background(PulseTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("subir_valor")
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: value)
    }
}

import Foundation
import CoreLocation
import CoreMotion
import HealthKit
import WatchConnectivity
import WatchKit

/// What the Watch is currently showing/driving. Route flags on the model stay
/// authoritative for cardio; this drives the strength/interval UI routing.
enum WatchWorkoutMode: Equatable {
    case none
    case phoneStrength       // strength workout synced/driven from the iPhone
    case phoneRoute          // cardio route driven from the iPhone
    case standaloneStrength  // free strength started on the Watch (offline-capable)
    case standaloneRoute     // walk/run started on the Watch
    case interval            // intervals / HIIT started on the Watch
}

/// Set-type raw values mirror `SetLog.SetType` on the iPhone so the String
/// round-trips through `SharedPlannedSet.setType`.
enum WatchSetType: String, CaseIterable, Hashable {
    case warmUp
    case work
    case dropSet

    var shortLabel: String {
        switch self {
        case .warmUp: return "W"
        case .work: return "·"
        case .dropSet: return "D"
        }
    }
}

struct WatchSet: Identifiable, Hashable {
    var id = UUID()
    var weightKg: Double = 0
    var reps: Int = 0
    var setTypeRaw: String = WatchSetType.work.rawValue
    var completed: Bool = false

    var type: WatchSetType { WatchSetType(rawValue: setTypeRaw) ?? .work }
    var volumeKg: Double { weightKg * Double(reps) }
}

struct WatchExercise: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var trackingType: String = "weightReps"
    var targetSets: Int = 3
    var repRange: String = ""
    var restSeconds: Int = 90
    var previous: String?
    var sets: [WatchSet] = []

    var isBodyweight: Bool { trackingType == "repsOnly" }
    var completedSets: Int { sets.filter(\.completed).count }
    var volumeKg: Double { sets.filter(\.completed).reduce(0) { $0 + $1.volumeKg } }

    /// Index of the next set to work on (first incomplete), or the last one.
    var activeSetIndex: Int {
        sets.firstIndex(where: { !$0.completed }) ?? max(sets.count - 1, 0)
    }
}

/// Interval / HIIT preset run entirely on the Watch.
struct WatchIntervalPreset: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var workSeconds: Int
    var restSeconds: Int
    var rounds: Int

    static let presets: [WatchIntervalPreset] = [
        WatchIntervalPreset(name: "30 / 30", workSeconds: 30, restSeconds: 30, rounds: 10),
        WatchIntervalPreset(name: "Tabata", workSeconds: 20, restSeconds: 10, rounds: 8),
        WatchIntervalPreset(name: "40 / 20", workSeconds: 40, restSeconds: 20, rounds: 8),
        WatchIntervalPreset(name: "60 / 60", workSeconds: 60, restSeconds: 60, rounds: 6)
    ]
}

@MainActor
final class WatchWorkoutModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum State {
        case idle
        case running
        case paused
    }

    @Published var snapshot = SharedWorkoutSnapshot.empty
    @Published var state: State = .idle
    @Published var heartRate: Double?
    @Published var activeEnergy: Double = 0
    @Published var routeDistanceKm: Double?
    @Published var routeSteps: Double?
    @Published var routePaceSecondsPerKm: Double?
    @Published var routeSpeedKmh: Double?
    @Published var elapsedSeconds = 0
    @Published var message: String?
    @Published var routePointCount = 0
    @Published var isStandaloneRouteWorkout = false

    // MARK: Local strength / interval state
    @Published var mode: WatchWorkoutMode = .none
    @Published var exercises: [WatchExercise] = []
    @Published var currentExerciseIndex = 0
    @Published var intervalPreset: WatchIntervalPreset?
    @Published var intervalRound = 0          // 0-based current round
    @Published var intervalIsWork = true
    @Published var intervalPhaseRemaining = 0
    @Published var intervalFinished = false
    /// Local rest countdown after a set in a standalone strength session.
    @Published var localRestEndDate: Date?

    /// Structural signature of the last phone-driven hydration, so live edits
    /// aren't clobbered by routine snapshot republishes.
    private var hydratedSignature: String?
    private var standaloneTitle = ""

    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private let locationManager = CLLocationManager()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    /// Closes the race where rapid phone snapshots arriving during the async
    /// `startLocalWorkoutIfNeeded` setup (which awaits authorization before
    /// assigning `session`) would each spawn a duplicate HKWorkoutSession,
    /// producing a flurry of empty 1-minute workouts in Health.
    private var isStartingLocalSession = false
    private var startedAt: Date?
    private var endedAt: Date?
    private var timer: Timer?
    private var isLocalRouteWorkout = false
    private var standaloneActivity: WatchRouteWorkoutActivity?
    private var standaloneWorkoutID: UUID?
    private var lastRouteMetricsSentAt: Date?
    private var pauseStartedAt: Date?
    private var accumulatedPausedSeconds = 0
    private var routePoints: [SharedRoutePoint] = []
    private var lastLocation: CLLocation?
    private var totalDistanceMeters: CLLocationDistance = 0
    private var heartRateSamples: [Double] = []
    private var currentCadenceSpm: Double?

    override init() {
        super.init()
        configureLocation()
        configureConnectivity()
        snapshot = SharedWorkoutStore.load()
        recoverActiveSessionIfNeeded()
    }

    /// Reattaches a workout session left running by HealthKit if the app was
    /// terminated mid-workout, so the user does not lose the session.
    private func recoverActiveSessionIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        healthStore.recoverActiveWorkoutSession { [weak self] recoveredSession, _ in
            guard let recoveredSession else { return }
            Task { @MainActor in
                self?.attachRecoveredSession(recoveredSession)
            }
        }
    }

    private func attachRecoveredSession(_ recoveredSession: HKWorkoutSession) {
        guard session == nil,
              recoveredSession.state == .running || recoveredSession.state == .paused else {
            return
        }

        let configuration = recoveredSession.workoutConfiguration
        let workoutBuilder = recoveredSession.associatedWorkoutBuilder()
        recoveredSession.delegate = self
        workoutBuilder.delegate = self
        if workoutBuilder.dataSource == nil {
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        }

        session = recoveredSession
        builder = workoutBuilder
        startedAt = recoveredSession.startDate ?? Date()
        endedAt = nil
        state = recoveredSession.state == .paused ? .paused : .running
        isLocalRouteWorkout = Self.isRouteConfiguration(configuration)
        standaloneActivity = Self.routeWorkoutActivity(for: configuration)
        standaloneWorkoutID = UUID()
        // The standalone snapshot writer tags sessions started on the watch;
        // a recovered route session without an iPhone-driven workout is standalone.
        let wasStandalone = snapshot.sessionTitle == localizedString("watch_session_started_watch")
        isStandaloneRouteWorkout = isLocalRouteWorkout && (wasStandalone || !snapshot.hasActiveWorkout)

        if isLocalRouteWorkout, state == .running {
            startPedometer()
            if configuration.locationType != .indoor {
                startLocation()
            }
        }

        // Keep the UI coherent for non-route sessions recovered after the app was
        // terminated mid-workout (the local set/interval state itself is lost).
        if isStandaloneRouteWorkout {
            mode = .standaloneRoute
        } else if isLocalRouteWorkout {
            mode = .phoneRoute
        } else if configuration.activityType == .traditionalStrengthTraining {
            mode = .standaloneStrength
            standaloneTitle = localizedString("Strength")
        }

        startTimer()
        updateStandaloneSnapshotIfNeeded()
    }

    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        startWorkout(configuration: configuration)
    }

    func startWorkout(configuration: HKWorkoutConfiguration) {
        guard session == nil else { return }
        Task {
            do {
                try await requestHealthAuthorization()

                let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let workoutBuilder = workoutSession.associatedWorkoutBuilder()
                workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                workoutSession.delegate = self
                workoutBuilder.delegate = self

                let startDate = Date()
                session = workoutSession
                builder = workoutBuilder
                startedAt = startDate
                endedAt = nil
                state = .running
                isLocalRouteWorkout = Self.isRouteConfiguration(configuration)
                isStandaloneRouteWorkout = false
                standaloneActivity = Self.routeWorkoutActivity(for: configuration)
                standaloneWorkoutID = UUID()
                accumulatedPausedSeconds = 0
                pauseStartedAt = nil
                resetRouteMetrics()
                prepareSnapshotForCompanionLaunch(configuration: configuration, startedAt: startDate)

                workoutSession.startActivity(with: startDate)
                try await workoutBuilder.beginCollection(at: startDate)
                try? await workoutSession.startMirroringToCompanionDevice()
                if isLocalRouteWorkout {
                    startPedometer()
                    if configuration.locationType != .indoor {
                        startLocation()
                    }
                }
                startTimer()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func pause() {
        session?.pause()
        state = .paused
        snapshot.isPaused = true
        pauseStartedAt = .now
        stopPedometer()
        stopLocation()
        updateStandaloneSnapshotIfNeeded()
        send(command: .pause)
    }

    func resume() {
        if let pauseStartedAt {
            accumulatedPausedSeconds += max(Int(Date().timeIntervalSince(pauseStartedAt)), 0)
        }
        pauseStartedAt = nil
        session?.resume()
        state = .running
        snapshot.isPaused = false
        if isLocalRouteWorkout {
            startPedometer()
            startLocation()
        }
        updateStandaloneSnapshotIfNeeded()
        send(command: .resume)
    }

    func stop() {
        stopSession(sendsCommand: true)
    }

    func toggleRoutePause() {
        if snapshot.isPaused || state == .paused {
            resume()
        } else {
            pause()
        }
    }

    /// Unified pause toggle for any mode. Standalone strength/interval sessions
    /// pause locally without notifying the iPhone; phone-driven sessions relay
    /// the command so the iPhone stays in sync.
    func togglePause() {
        switch mode {
        case .standaloneStrength, .interval:
            if state == .paused {
                if let pauseStartedAt {
                    accumulatedPausedSeconds += max(Int(Date().timeIntervalSince(pauseStartedAt)), 0)
                }
                pauseStartedAt = nil
                session?.resume()
                state = .running
            } else {
                session?.pause()
                state = .paused
                pauseStartedAt = .now
            }
            WatchTheme.haptic(.click)
        default:
            toggleRoutePause()
        }
    }

    func startStandaloneRouteWorkout(activity: WatchRouteWorkoutActivity) {
        guard mode == .none, session == nil else { return }
        // Flip the UI synchronously so the screen responds instantly; the
        // HealthKit session is attached best-effort afterwards (it is not
        // available on the watch Simulator and may be denied on device).
        let startDate = Date()
        startedAt = startDate
        endedAt = nil
        state = .running
        isLocalRouteWorkout = true
        isStandaloneRouteWorkout = true
        standaloneActivity = activity
        standaloneWorkoutID = UUID()
        accumulatedPausedSeconds = 0
        pauseStartedAt = nil
        resetRouteMetrics()
        mode = .standaloneRoute
        updateStandaloneSnapshotIfNeeded()
        startPedometer()
        startLocation()
        startTimer()
        WatchTheme.haptic(.start)
        beginHealthKitSession(
            activity: activity == .running ? .running : .walking,
            location: .outdoor,
            startDate: startDate,
            mirror: true
        )
    }

    /// Best-effort HealthKit live session. The local workout UI never depends on
    /// this succeeding, so a Simulator (no workout sessions) or a denied
    /// authorization just means HR / energy won't stream.
    private func beginHealthKitSession(
        activity: HKWorkoutActivityType,
        location: HKWorkoutSessionLocationType,
        startDate: Date,
        mirror: Bool = false
    ) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        Task {
            do {
                try await requestHealthAuthorization()
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = activity
                configuration.locationType = location
                let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let workoutBuilder = workoutSession.associatedWorkoutBuilder()
                workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                workoutSession.delegate = self
                workoutBuilder.delegate = self
                session = workoutSession
                builder = workoutBuilder
                workoutSession.startActivity(with: startDate)
                try await workoutBuilder.beginCollection(at: startDate)
                if mirror {
                    try? await workoutSession.startMirroringToCompanionDevice()
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func stopSession(sendsCommand: Bool) {
        Task {
            let endDate = Date()
            if let pauseStartedAt {
                accumulatedPausedSeconds += max(Int(endDate.timeIntervalSince(pauseStartedAt)), 0)
            }
            pauseStartedAt = nil
            let routeSummary = isLocalRouteWorkout ? makeStandaloneSummary(endedAt: endDate) : nil
            let strengthSummary = mode == .standaloneStrength ? makeStrengthSummary(endedAt: endDate) : nil
            let intervalSummary = mode == .interval ? makeIntervalSummary(endedAt: endDate) : nil
            session?.end()
            // Only persist a real HKWorkout when something was actually recorded.
            // Sessions that are ended almost immediately (e.g. a phone snapshot
            // that flips inactive, or a mirror that never collected data) are
            // discarded so they don't litter Health with empty 1-minute entries.
            let effectiveSeconds = max(Int(endDate.timeIntervalSince(startedAt ?? endDate)) - accumulatedPausedSeconds, 0)
            let hasMeaningfulData = activeEnergy > 0
                || (routeDistanceKm ?? 0) > 0
                || totalCompletedSets > 0
                || !heartRateSamples.isEmpty
            if effectiveSeconds >= 60, hasMeaningfulData {
                try? await builder?.endCollection(at: endDate)
                _ = try? await builder?.finishWorkout()
            } else {
                builder?.discardWorkout()
            }
            timer?.invalidate()
            stopPedometer()
            stopLocation()
            state = .idle
            endedAt = endDate
            if let routeSummary {
                sendStandaloneSummary(routeSummary)
            } else if let strengthSummary {
                sendStrengthSummary(strengthSummary)
            } else if let intervalSummary {
                sendIntervalSummary(intervalSummary)
            } else if sendsCommand {
                send(command: .stop)
            }
            session = nil
            builder = nil
            isLocalRouteWorkout = false
            isStandaloneRouteWorkout = false
            standaloneActivity = nil
            standaloneWorkoutID = nil
            accumulatedPausedSeconds = 0
            resetRouteMetrics()
            resetLocalWorkout()
            snapshot = SharedWorkoutSnapshot.empty
            SharedWorkoutStore.save(snapshot)
        }
    }

    private func requestHealthAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount)
        ]
        let shareTypes: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func configureLocation() {
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 8
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                self.updateRouteDerivedMetrics()
                self.updateStandaloneSnapshotIfNeeded()
                self.sendRouteMetricsIfNeeded()
                self.advanceIntervalIfNeeded()
                self.clearExpiredLocalRest()
            }
        }
    }

    private func updateStatistics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit)
            if let heartRate {
                heartRateSamples.append(heartRate)
            }
        case HKQuantityType(.activeEnergyBurned):
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeEnergy
        case HKQuantityType(.distanceWalkingRunning):
            let meters = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            routeDistanceKm = meters > 0 ? meters / 1_000 : routeDistanceKm
            updateRouteDerivedMetrics()
        default:
            break
        }
    }

    private func startLocalWorkoutIfNeeded(for snapshot: SharedWorkoutSnapshot) {
        guard snapshot.hasActiveWorkout else { return }
        guard session == nil else {
            if snapshot.isPaused, state == .running {
                session?.pause()
                state = .paused
                if isLocalRouteWorkout {
                    stopPedometer()
                    stopLocation()
                }
            } else if !snapshot.isPaused, state == .paused {
                session?.resume()
                state = .running
                if isLocalRouteWorkout {
                    startPedometer()
                    if snapshot.isOutdoorRoute != false {
                        startLocation()
                    }
                }
            }
            return
        }

        guard !isStartingLocalSession else { return }
        isStartingLocalSession = true

        Task {
            defer { isStartingLocalSession = false }
            do {
                try await requestHealthAuthorization()
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = Self.activityType(for: snapshot)
                configuration.locationType = snapshot.isRouteWorkout
                    ? (snapshot.isOutdoorRoute == false ? .indoor : .outdoor)
                    : .indoor

                let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let workoutBuilder = workoutSession.associatedWorkoutBuilder()
                workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                workoutSession.delegate = self
                workoutBuilder.delegate = self

                session = workoutSession
                builder = workoutBuilder
                startedAt = snapshot.updatedAt.addingTimeInterval(-TimeInterval(snapshot.elapsedSeconds))
                elapsedSeconds = snapshot.elapsedSeconds
                state = snapshot.isPaused ? .paused : .running
                isLocalRouteWorkout = snapshot.isRouteWorkout
                isStandaloneRouteWorkout = false
                standaloneActivity = snapshot.isRouteWorkout ? Self.routeWorkoutActivity(for: snapshot) : nil
                standaloneWorkoutID = UUID()
                resetRouteMetrics()

                workoutSession.startActivity(with: .now)
                try await workoutBuilder.beginCollection(at: .now)
                try? await workoutSession.startMirroringToCompanionDevice()
                if snapshot.isPaused {
                    workoutSession.pause()
                } else if snapshot.isRouteWorkout {
                    startPedometer()
                    if snapshot.isOutdoorRoute != false {
                        startLocation()
                    }
                }
                startTimer()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func stopLocalRouteWorkoutIfNeeded() {
        guard session != nil, !isStandaloneRouteWorkout else { return }
        stopSession(sendsCommand: false)
    }

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: startedAt ?? .now) { [weak self] data, _ in
            Task { @MainActor in
                guard let self, let data else { return }
                self.routeSteps = data.numberOfSteps.doubleValue
                if let cadence = data.currentCadence?.doubleValue, cadence > 0 {
                    self.currentCadenceSpm = cadence * 60 // steps/sec -> steps/min
                }
                if self.routeDistanceKm == nil, let meters = data.distance?.doubleValue, meters > 0 {
                    self.routeDistanceKm = meters / 1_000
                }
                self.updateRouteDerivedMetrics()
            }
        }
    }

    private func stopPedometer() {
        pedometer.stopUpdates()
    }

    private func startLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            // Requires the "location" UIBackgroundMode so the route keeps
            // recording with the wrist down during the workout session.
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    private func stopLocation() {
        locationManager.stopUpdatingLocation()
    }

    private func resetRouteMetrics() {
        routeDistanceKm = nil
        routeSteps = nil
        routePaceSecondsPerKm = nil
        routeSpeedKmh = nil
        lastRouteMetricsSentAt = nil
        routePointCount = 0
        routePoints = []
        lastLocation = nil
        totalDistanceMeters = 0
        heartRateSamples = []
        currentCadenceSpm = nil
    }

    private func updateRouteDerivedMetrics() {
        guard let routeDistanceKm, routeDistanceKm > 0.02, elapsedSeconds > 0 else {
            routePaceSecondsPerKm = nil
            routeSpeedKmh = nil
            return
        }
        routePaceSecondsPerKm = Double(elapsedSeconds) / routeDistanceKm
        routeSpeedKmh = routeDistanceKm / (Double(elapsedSeconds) / 3_600)
    }

    private static func activityType(for snapshot: SharedWorkoutSnapshot) -> HKWorkoutActivityType {
        if snapshot.isRouteWorkout {
            return routeWorkoutActivity(for: snapshot) == .running ? .running : .walking
        }

        let title = snapshot.workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if title.localizedCaseInsensitiveContains("yoga") ||
            title.localizedCaseInsensitiveContains("pilates") ||
            title.localizedCaseInsensitiveContains("flex") ||
            title.localizedCaseInsensitiveContains("movilidad") ||
            title.localizedCaseInsensitiveContains("mobility") {
            return .flexibility
        }
        return .traditionalStrengthTraining
    }

    private static func routeWorkoutActivity(for snapshot: SharedWorkoutSnapshot) -> WatchRouteWorkoutActivity {
        let title = snapshot.workoutTitle.lowercased()
        if title.contains("carrera") || title.contains("run") {
            return .running
        }
        return .walking
    }

    private static func routeWorkoutActivity(for configuration: HKWorkoutConfiguration) -> WatchRouteWorkoutActivity? {
        switch configuration.activityType {
        case .running:
            return .running
        case .walking:
            return .walking
        default:
            return nil
        }
    }

    private static func isRouteConfiguration(_ configuration: HKWorkoutConfiguration) -> Bool {
        routeWorkoutActivity(for: configuration) != nil
    }

    private static func workoutTitle(for configuration: HKWorkoutConfiguration) -> String {
        switch configuration.activityType {
        case .running:
            return localizedString("running")
        case .walking:
            return localizedString("walking")
        case .flexibility:
            return localizedString("mobility")
        default:
            return localizedString("workout")
        }
    }

    private func prepareSnapshotForCompanionLaunch(configuration: HKWorkoutConfiguration, startedAt: Date) {
        guard !snapshot.hasActiveWorkout else { return }
        let title = Self.workoutTitle(for: configuration)
        snapshot = SharedWorkoutSnapshot(
            hasActiveWorkout: true,
            planTitle: nil,
            workoutTitle: title,
            sessionTitle: localizedString("watch_session_started_iphone"),
            elapsedSeconds: 0,
            pausedSeconds: 0,
            completedSets: 0,
            totalSets: 0,
            volumeKg: 0,
            isPaused: false,
            exerciseName: nil,
            exerciseIndex: nil,
            totalExercises: nil,
            currentExerciseCompletedSets: nil,
            currentExerciseTotalSets: nil,
            currentSetWeightKg: nil,
            currentSetReps: nil,
            restSeconds: nil,
            restDurationSeconds: nil,
            estimatedRemainingSeconds: nil,
            waterLiters: nil,
            musicTitle: nil,
            musicArtist: nil,
            isMusicPlaying: nil,
            nextExerciseName: nil,
            exerciseHistorySummary: nil,
            gymPassName: nil,
            gymMembershipID: nil,
            gymCodeValue: nil,
            gymCodeType: nil,
            heartRate: heartRate,
            activeEnergyKcal: activeEnergy,
            isRouteWorkout: Self.isRouteConfiguration(configuration),
            isOutdoorRoute: configuration.locationType == .outdoor,
            routeDistanceKm: routeDistanceKm,
            routePaceSecondsPerKm: routePaceSecondsPerKm,
            routeSpeedKmh: routeSpeedKmh,
            routePointCount: routePointCount,
            routeSteps: routeSteps,
            summary: "\(title) iniciado desde iPhone",
            updatedAt: startedAt,
            streakDays: snapshot.streakDays,
            weeklyCompletion: snapshot.weeklyCompletion,
            trainingBatteryLevel: snapshot.trainingBatteryLevel,
            trainingBatteryState: snapshot.trainingBatteryState,
            trainingBatteryTitle: snapshot.trainingBatteryTitle,
            trainingBatterySuggestion: snapshot.trainingBatterySuggestion,
            trainingBatterySystemImage: snapshot.trainingBatterySystemImage,
            nextWorkoutDayName: snapshot.nextWorkoutDayName,
            nextWorkoutDayDescription: snapshot.nextWorkoutDayDescription,
            widgetAccentColorName: snapshot.widgetAccentColorName,
            preferredLanguage: snapshot.preferredLanguage
        )
        SharedWorkoutStore.save(snapshot)
    }

    private func sendRouteMetricsIfNeeded() {
        guard isLocalRouteWorkout else { return }
        let now = Date()
        if let lastRouteMetricsSentAt, now.timeIntervalSince(lastRouteMetricsSentAt) < 5 {
            return
        }
        lastRouteMetricsSentAt = now

        var message: [String: Any] = [
            "kind": "routeMetrics",
            "activeEnergyKcal": activeEnergy
        ]
        if let heartRate {
            message["heartRate"] = heartRate
        }
        if let routeDistanceKm {
            message["routeDistanceKm"] = routeDistanceKm
        }
        if let routePaceSecondsPerKm {
            message["routePaceSecondsPerKm"] = routePaceSecondsPerKm
        }
        if let routeSpeedKmh {
            message["routeSpeedKmh"] = routeSpeedKmh
        }
        if let routeSteps {
            message["routeSteps"] = routeSteps
        }
        message["routePointCount"] = routePointCount

        guard WCSession.isSupported() else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        }
    }

    private func updateStandaloneSnapshotIfNeeded() {
        guard isStandaloneRouteWorkout, let startedAt, let activity = standaloneActivity else { return }
        let elapsed = max(Int(Date().timeIntervalSince(startedAt)) - accumulatedPausedSeconds, 0)
        elapsedSeconds = elapsed
        snapshot = SharedWorkoutSnapshot(
            hasActiveWorkout: true,
            planTitle: nil,
            workoutTitle: activity.title,
            sessionTitle: localizedString("watch_session_started_watch"),
            elapsedSeconds: elapsed,
            pausedSeconds: currentPausedSeconds,
            completedSets: 0,
            totalSets: 0,
            volumeKg: 0,
            isPaused: state == .paused,
            exerciseName: nil,
            exerciseIndex: nil,
            totalExercises: nil,
            currentExerciseCompletedSets: nil,
            currentExerciseTotalSets: nil,
            currentSetWeightKg: nil,
            currentSetReps: nil,
            restSeconds: nil,
            restDurationSeconds: nil,
            estimatedRemainingSeconds: nil,
            waterLiters: nil,
            musicTitle: nil,
            musicArtist: nil,
            isMusicPlaying: nil,
            nextExerciseName: nil,
            exerciseHistorySummary: nil,
            gymPassName: nil,
            gymMembershipID: nil,
            gymCodeValue: nil,
            gymCodeType: nil,
            heartRate: heartRate,
            activeEnergyKcal: activeEnergy,
            isRouteWorkout: true,
            isOutdoorRoute: isLocalRouteWorkout ? snapshot.isOutdoorRoute : true,
            routeDistanceKm: routeDistanceKm,
            routePaceSecondsPerKm: routePaceSecondsPerKm,
            routeSpeedKmh: routeSpeedKmh,
            routePointCount: routePointCount,
            routeSteps: routeSteps,
            summary: localizedFormat("watch_route_summary_format", activity.title),
            updatedAt: .now,
            streakDays: snapshot.streakDays,
            weeklyCompletion: snapshot.weeklyCompletion,
            trainingBatteryLevel: snapshot.trainingBatteryLevel,
            trainingBatteryState: snapshot.trainingBatteryState,
            trainingBatteryTitle: snapshot.trainingBatteryTitle,
            trainingBatterySuggestion: snapshot.trainingBatterySuggestion,
            trainingBatterySystemImage: snapshot.trainingBatterySystemImage,
            nextWorkoutDayName: snapshot.nextWorkoutDayName,
            nextWorkoutDayDescription: snapshot.nextWorkoutDayDescription,
            widgetAccentColorName: "green",
            preferredLanguage: snapshot.preferredLanguage
        )
        SharedWorkoutStore.save(snapshot)
    }

    private var currentPausedSeconds: Int {
        if let pauseStartedAt {
            return accumulatedPausedSeconds + max(Int(Date().timeIntervalSince(pauseStartedAt)), 0)
        }
        return accumulatedPausedSeconds
    }

    private func makeStandaloneSummary(endedAt endDate: Date) -> WatchRouteWorkoutSummary? {
        guard let startedAt, let activity = standaloneActivity else { return nil }
        let duration = max(Int(endDate.timeIntervalSince(startedAt)) - currentPausedSeconds, 1)
        updateRouteDerivedMetrics()
        return WatchRouteWorkoutSummary(
            id: standaloneWorkoutID ?? UUID(),
            activity: activity,
            startedAt: startedAt,
            endedAt: endDate,
            durationSeconds: duration,
            pausedSeconds: currentPausedSeconds,
            distanceKm: routeDistanceKm,
            averagePaceSecondsPerKm: routePaceSecondsPerKm,
            averageSpeedKmh: routeSpeedKmh,
            steps: routeSteps,
            activeEnergyKcal: activeEnergy > 0 ? activeEnergy : nil,
            averageHeartRate: averageHeartRate,
            maxHeartRate: heartRateSamples.max(),
            routePoints: routePoints
        )
    }

    private var averageHeartRate: Double? {
        guard !heartRateSamples.isEmpty else { return heartRate }
        return heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }

    private func sendStandaloneSummary(_ summary: WatchRouteWorkoutSummary) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(summary) else { return }
        let context: [String: Any] = [
            "kind": "routeWorkoutSummary",
            "routeWorkoutSummary": data
        ]
        WCSession.default.transferUserInfo(context)
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil)
        }
    }

    private func send(command: WatchCommand) {
        guard WCSession.isSupported() else { return }
        let message = [
            "command": command.rawValue,
            "heartRate": heartRate ?? 0,
            "activeEnergyKcal": activeEnergy
        ] as [String: Any]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.isLocalRouteWorkout,
               self.state == .running,
               status == .authorizedAlways || status == .authorizedWhenInUse {
                self.locationManager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 60 {
                if let lastLocation {
                    totalDistanceMeters += location.distance(from: lastLocation)
                }
                lastLocation = location
                routePoints.append(
                    SharedRoutePoint(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        altitude: location.altitude,
                        horizontalAccuracy: location.horizontalAccuracy,
                        timestamp: location.timestamp,
                        heartRate: heartRate,
                        cadenceSpm: currentCadenceSpm
                    )
                )
                routePointCount = routePoints.count
                if totalDistanceMeters > 0 {
                    routeDistanceKm = totalDistanceMeters / 1_000
                }
            }
            updateRouteDerivedMetrics()
            updateStandaloneSnapshotIfNeeded()
        }
    }
}

extension WatchWorkoutModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let snapshot = Self.snapshot(from: applicationContext)
        Task { @MainActor in
            self.apply(snapshot: snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let snapshot = Self.snapshot(from: message)
        Task { @MainActor in
            self.apply(snapshot: snapshot)
        }
    }

    nonisolated private static func snapshot(from context: [String: Any]) -> SharedWorkoutSnapshot {
        SharedWorkoutSnapshot(
            hasActiveWorkout: context["hasActiveWorkout"] as? Bool ?? false,
            planTitle: context["planTitle"] as? String,
            workoutTitle: context["workoutTitle"] as? String ?? "Reps",
            sessionTitle: context["sessionTitle"] as? String,
            elapsedSeconds: context["elapsedSeconds"] as? Int ?? 0,
            pausedSeconds: context["pausedSeconds"] as? Int ?? 0,
            completedSets: context["completedSets"] as? Int ?? 0,
            totalSets: context["totalSets"] as? Int ?? 0,
            volumeKg: context["volumeKg"] as? Int ?? 0,
            isPaused: context["isPaused"] as? Bool ?? false,
            exerciseName: context["exerciseName"] as? String,
            exerciseIndex: context["exerciseIndex"] as? Int,
            totalExercises: context["totalExercises"] as? Int,
            currentExerciseCompletedSets: context["currentExerciseCompletedSets"] as? Int,
            currentExerciseTotalSets: context["currentExerciseTotalSets"] as? Int,
            currentSetWeightKg: context["currentSetWeightKg"] as? Double,
            currentSetReps: context["currentSetReps"] as? Int,
            restSeconds: context["restSeconds"] as? Int,
            restDurationSeconds: context["restDurationSeconds"] as? Int,
            estimatedRemainingSeconds: context["estimatedRemainingSeconds"] as? Int,
            waterLiters: context["waterLiters"] as? Double,
            musicTitle: context["musicTitle"] as? String,
            musicArtist: context["musicArtist"] as? String,
            isMusicPlaying: context["isMusicPlaying"] as? Bool,
            nextExerciseName: context["nextExerciseName"] as? String,
            exerciseHistorySummary: context["exerciseHistorySummary"] as? String,
            gymPassName: context["gymPassName"] as? String,
            gymMembershipID: context["gymMembershipID"] as? String,
            gymCodeValue: context["gymCodeValue"] as? String,
            gymCodeType: context["gymCodeType"] as? String,
            heartRate: context["heartRate"] as? Double,
            activeEnergyKcal: context["activeEnergyKcal"] as? Double,
            isRouteWorkout: context["isRouteWorkout"] as? Bool ?? false,
            isOutdoorRoute: context["isOutdoorRoute"] as? Bool,
            routeDistanceKm: context["routeDistanceKm"] as? Double,
            routePaceSecondsPerKm: context["routePaceSecondsPerKm"] as? Double,
            routeSpeedKmh: context["routeSpeedKmh"] as? Double,
            routePointCount: context["routePointCount"] as? Int,
            routeSteps: context["routeSteps"] as? Double,
            summary: context["summary"] as? String ?? "",
            updatedAt: Date(timeIntervalSince1970: context["updatedAt"] as? Double ?? Date().timeIntervalSince1970),
            streakDays: context["streakDays"] as? Int ?? 0,
            weeklyCompletion: context["weeklyCompletion"] as? Double ?? 0.0,
            trainingBatteryLevel: context["trainingBatteryLevel"] as? Int ?? 100,
            trainingBatteryState: context["trainingBatteryState"] as? String ?? "charged",
            trainingBatteryTitle: context["trainingBatteryTitle"] as? String ?? "Cargada",
            trainingBatterySuggestion: context["trainingBatterySuggestion"] as? String ?? "",
            trainingBatterySystemImage: context["trainingBatterySystemImage"] as? String ?? "battery.100percent",
            nextWorkoutDayName: context["nextWorkoutDayName"] as? String,
            nextWorkoutDayDescription: context["nextWorkoutDayDescription"] as? String,
            widgetAccentColorName: context["widgetAccentColorName"] as? String ?? "system",
            preferredLanguage: context["preferredLanguage"] as? String,
            exercisesData: context["exercisesData"] as? Data,
            estimatedMaxHeartRate: context["estimatedMaxHeartRate"] as? Double,
            hasWatchAccess: context["hasWatchAccess"] as? Bool ?? true
        )
    }

    private func apply(snapshot: SharedWorkoutSnapshot) {
        // Never let an incoming phone snapshot override a session the watch owns.
        if isStandaloneRouteWorkout || mode == .standaloneStrength || mode == .interval {
            return
        }
        RepsLocalization.use(snapshot.preferredLanguage)
        let restJustEnded = snapshot.hasActiveWorkout
            && (self.snapshot.restSeconds ?? 0) > 0
            && (snapshot.restSeconds ?? 0) == 0
        self.snapshot = snapshot
        SharedWorkoutStore.save(snapshot)
        if restJustEnded {
            WKInterfaceDevice.current().play(.notification)
        }
        if snapshot.hasActiveWorkout {
            if snapshot.isRouteWorkout {
                mode = .phoneRoute
            } else {
                mode = .phoneStrength
                hydrateStrengthFromSnapshotIfNeeded(snapshot)
            }
            startLocalWorkoutIfNeeded(for: snapshot)
        } else {
            mode = .none
            hydratedSignature = nil
            exercises = []
            stopLocalRouteWorkoutIfNeeded()
        }
    }

    // MARK: - Strength / interval derived state

    var currentExercise: WatchExercise? {
        guard exercises.indices.contains(currentExerciseIndex) else { return nil }
        return exercises[currentExerciseIndex]
    }

    var totalVolumeKg: Double { exercises.reduce(0) { $0 + $1.volumeKg } }
    var totalCompletedSets: Int { exercises.reduce(0) { $0 + $1.completedSets } }
    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var isStrengthMode: Bool { mode == .phoneStrength || mode == .standaloneStrength }

    /// 1-based number of the set currently being worked on, for the UI header.
    var currentSetNumber: Int { (currentExercise?.activeSetIndex ?? 0) + 1 }

    var currentSetWeight: Double {
        guard let exercise = currentExercise, exercise.sets.indices.contains(exercise.activeSetIndex) else { return 0 }
        return exercise.sets[exercise.activeSetIndex].weightKg
    }

    var currentSetReps: Int {
        guard let exercise = currentExercise, exercise.sets.indices.contains(exercise.activeSetIndex) else { return 0 }
        return exercise.sets[exercise.activeSetIndex].reps
    }

    /// HR zone 1…5 from live heart rate and the estimated max pushed by the phone.
    var heartRateZone: Int? {
        guard let hr = heartRate ?? snapshot.heartRate,
              let maxHR = snapshot.estimatedMaxHeartRate, maxHR > 0 else { return nil }
        switch hr / maxHR {
        case ..<0.6: return 1
        case ..<0.7: return 2
        case ..<0.8: return 3
        case ..<0.9: return 4
        default: return 5
        }
    }

    // MARK: - Phone-driven strength hydration

    private func structuralSignature(_ exs: [SharedPlannedExercise]) -> String {
        exs.map { "\($0.name)#\($0.sets.count)" }.joined(separator: "|")
    }

    private func hydrateStrengthFromSnapshotIfNeeded(_ snapshot: SharedWorkoutSnapshot) {
        let planned = snapshot.plannedExercises
        guard !planned.isEmpty else { return }
        let signature = structuralSignature(planned)
        let targetIndex = min(max((snapshot.exerciseIndex ?? 1) - 1, 0), max(planned.count - 1, 0))

        if signature == hydratedSignature {
            // Same structure: mirror phone-side completions, keep local edits.
            for (i, plan) in planned.enumerated() where exercises.indices.contains(i) {
                for (j, set) in plan.sets.enumerated() where exercises[i].sets.indices.contains(j) {
                    if set.completed { exercises[i].sets[j].completed = true }
                }
            }
            currentExerciseIndex = min(max(currentExerciseIndex, 0), max(exercises.count - 1, 0))
            return
        }

        hydratedSignature = signature
        exercises = planned.map { plan in
            WatchExercise(
                name: plan.name,
                trackingType: plan.trackingType,
                targetSets: plan.targetSets,
                repRange: plan.repRange,
                restSeconds: plan.restSeconds,
                previous: plan.previous,
                sets: plan.sets.map {
                    WatchSet(weightKg: $0.weightKg, reps: $0.reps, setTypeRaw: $0.setType, completed: $0.completed)
                }
            )
        }
        currentExerciseIndex = targetIndex
    }

    // MARK: - Strength editing

    private var activeSetIndexForCurrent: Int? {
        guard let exercise = currentExercise else { return nil }
        let index = exercise.activeSetIndex
        return exercise.sets.indices.contains(index) ? index : nil
    }

    func adjustWeight(by delta: Double) {
        guard exercises.indices.contains(currentExerciseIndex),
              let setIndex = activeSetIndexForCurrent else { return }
        let new = max(0, exercises[currentExerciseIndex].sets[setIndex].weightKg + delta)
        exercises[currentExerciseIndex].sets[setIndex].weightKg = (new * 100).rounded() / 100
        WatchTheme.haptic(.click)
    }

    func adjustReps(by delta: Int) {
        guard exercises.indices.contains(currentExerciseIndex),
              let setIndex = activeSetIndexForCurrent else { return }
        let new = max(0, exercises[currentExerciseIndex].sets[setIndex].reps + delta)
        exercises[currentExerciseIndex].sets[setIndex].reps = new
        WatchTheme.haptic(.click)
    }

    func setActiveWeight(_ value: Double) {
        guard exercises.indices.contains(currentExerciseIndex),
              let setIndex = activeSetIndexForCurrent else { return }
        exercises[currentExerciseIndex].sets[setIndex].weightKg = max(0, value)
    }

    func setActiveReps(_ value: Int) {
        guard exercises.indices.contains(currentExerciseIndex),
              let setIndex = activeSetIndexForCurrent else { return }
        exercises[currentExerciseIndex].sets[setIndex].reps = max(0, value)
    }

    func completeCurrentSet() {
        guard exercises.indices.contains(currentExerciseIndex),
              let setIndex = activeSetIndexForCurrent else { return }
        exercises[currentExerciseIndex].sets[setIndex].completed = true
        WatchTheme.haptic(.success)
        sendLogSet(exerciseIndex: currentExerciseIndex, setIndex: setIndex)
        if mode == .standaloneStrength {
            let rest = exercises[currentExerciseIndex].restSeconds
            if rest > 0 {
                localRestEndDate = Date().addingTimeInterval(TimeInterval(rest))
            }
        }
        updateStrengthSnapshotIfNeeded()
    }

    func skipLocalRest() {
        localRestEndDate = nil
        WatchTheme.haptic(.click)
    }

    private func clearExpiredLocalRest() {
        guard let end = localRestEndDate else { return }
        if Date() >= end {
            localRestEndDate = nil
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func addSet(type: WatchSetType = .work) {
        guard exercises.indices.contains(currentExerciseIndex) else { return }
        let last = exercises[currentExerciseIndex].sets.last
        let baseWeight = last?.weightKg ?? 0
        let weight = type == .dropSet ? (baseWeight * 0.8 * 100).rounded() / 100 : baseWeight
        exercises[currentExerciseIndex].sets.append(
            WatchSet(weightKg: weight, reps: last?.reps ?? 0, setTypeRaw: type.rawValue)
        )
        // Adding sets changes structure; refresh the signature so phone snapshots
        // don't wipe the new set on the next republish.
        if mode == .phoneStrength {
            hydratedSignature = nil
        }
        WatchTheme.haptic(.click)
    }

    func moveExercise(by delta: Int) {
        guard !exercises.isEmpty else { return }
        currentExerciseIndex = min(max(currentExerciseIndex + delta, 0), exercises.count - 1)
        if mode == .phoneStrength {
            WatchCommandRouter.send(delta > 0 ? WatchCommand.nextExercise.rawValue : WatchCommand.previousExercise.rawValue)
        }
        WatchTheme.haptic(.click)
    }

    func selectExercise(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
    }

    static var quickAddExercises: [(name: String, tracking: String)] {
        [
            (localizedString("exercise_squat"), "weightReps"),
            (localizedString("exercise_bench_press"), "weightReps"),
            (localizedString("exercise_deadlift"), "weightReps"),
            (localizedString("exercise_overhead_press"), "weightReps"),
            (localizedString("exercise_barbell_row"), "weightReps"),
            (localizedString("exercise_pullups"), "repsOnly"),
            (localizedString("exercise_dips"), "repsOnly"),
            (localizedString("exercise_bicep_curl"), "weightReps")
        ]
    }

    func addExercise(named name: String, trackingType: String) {
        let starterSet = WatchSet(weightKg: 0, reps: trackingType == "repsOnly" ? 10 : 0)
        exercises.append(
            WatchExercise(name: name, trackingType: trackingType, targetSets: 3, sets: [starterSet])
        )
        currentExerciseIndex = exercises.count - 1
        WatchTheme.haptic(.click)
    }

    private func sendLogSet(exerciseIndex: Int, setIndex: Int) {
        guard mode == .phoneStrength,
              exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex),
              WCSession.isSupported() else { return }
        let set = exercises[exerciseIndex].sets[setIndex]
        let message: [String: Any] = [
            "kind": "logSet",
            "exerciseIndex": exerciseIndex,
            "setIndex": setIndex,
            "weightKg": set.weightKg,
            "reps": set.reps,
            "setType": set.setTypeRaw,
            "completed": set.completed
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - Standalone strength

    func startStrengthWorkout(title: String = localizedString("Strength")) {
        guard mode == .none, session == nil else { return }
        standaloneTitle = title
        let startDate = Date()
        startedAt = startDate
        endedAt = nil
        state = .running
        isLocalRouteWorkout = false
        isStandaloneRouteWorkout = false
        standaloneWorkoutID = UUID()
        accumulatedPausedSeconds = 0
        pauseStartedAt = nil
        resetRouteMetrics()
        mode = .standaloneStrength
        currentExerciseIndex = 0
        startTimer()
        updateStrengthSnapshotIfNeeded()
        WatchTheme.haptic(.start)
        beginHealthKitSession(activity: .traditionalStrengthTraining, location: .indoor, startDate: startDate)
    }

    private func updateStrengthSnapshotIfNeeded() {
        guard mode == .standaloneStrength, startedAt != nil else { return }
        var snap = SharedWorkoutSnapshot.empty
        snap.hasActiveWorkout = true
        snap.workoutTitle = standaloneTitle.isEmpty ? localizedString("Strength") : standaloneTitle
        snap.sessionTitle = localizedString("watch_session_started_watch")
        snap.elapsedSeconds = elapsedSeconds
        snap.completedSets = totalCompletedSets
        snap.totalSets = totalSetCount
        snap.volumeKg = Int(totalVolumeKg)
        snap.heartRate = heartRate
        snap.activeEnergyKcal = activeEnergy
        snap.isRouteWorkout = false
        snap.widgetAccentColorName = snapshot.widgetAccentColorName
        snap.preferredLanguage = snapshot.preferredLanguage
        snap.estimatedMaxHeartRate = snapshot.estimatedMaxHeartRate
        snap.updatedAt = .now
        snapshot = snap
        SharedWorkoutStore.save(snap)
    }

    private func makeStrengthSummary(endedAt endDate: Date) -> WatchStrengthWorkoutSummary? {
        guard let startedAt else { return nil }
        let shared = exercises.map { exercise in
            SharedPlannedExercise(
                name: exercise.name,
                trackingType: exercise.trackingType,
                targetSets: exercise.targetSets,
                repRange: exercise.repRange,
                restSeconds: exercise.restSeconds,
                previous: exercise.previous,
                sets: exercise.sets.map {
                    SharedPlannedSet(weightKg: $0.weightKg, reps: $0.reps, completed: $0.completed, setType: $0.setTypeRaw, rpe: nil)
                }
            )
        }
        guard shared.contains(where: { $0.sets.contains(where: \.completed) }) else { return nil }
        return WatchStrengthWorkoutSummary(
            id: standaloneWorkoutID ?? UUID(),
            title: standaloneTitle.isEmpty ? localizedString("Strength") : standaloneTitle,
            startedAt: startedAt,
            endedAt: endDate,
            durationSeconds: max(Int(endDate.timeIntervalSince(startedAt)) - currentPausedSeconds, 1),
            pausedSeconds: currentPausedSeconds,
            exercises: shared,
            activeEnergyKcal: activeEnergy > 0 ? activeEnergy : nil,
            averageHeartRate: averageHeartRate,
            maxHeartRate: heartRateSamples.max()
        )
    }

    private func sendStrengthSummary(_ summary: WatchStrengthWorkoutSummary) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(summary) else { return }
        let context: [String: Any] = [
            "kind": "strengthWorkoutSummary",
            "strengthWorkoutSummary": data
        ]
        WCSession.default.transferUserInfo(context)
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil)
        }
    }

    // MARK: - Intervals / HIIT

    func startIntervalWorkout(preset: WatchIntervalPreset) {
        guard mode == .none, session == nil else { return }
        intervalPreset = preset
        intervalRound = 0
        intervalIsWork = true
        intervalPhaseRemaining = preset.workSeconds
        intervalFinished = false
        let startDate = Date()
        startedAt = startDate
        endedAt = nil
        state = .running
        isLocalRouteWorkout = false
        isStandaloneRouteWorkout = false
        standaloneWorkoutID = UUID()
        accumulatedPausedSeconds = 0
        pauseStartedAt = nil
        resetRouteMetrics()
        mode = .interval
        startTimer()
        WatchTheme.haptic(.start)
        beginHealthKitSession(activity: .highIntensityIntervalTraining, location: .indoor, startDate: startDate)
    }

    private func advanceIntervalIfNeeded() {
        guard mode == .interval, state == .running, let preset = intervalPreset, !intervalFinished else { return }
        intervalPhaseRemaining -= 1
        guard intervalPhaseRemaining <= 0 else { return }

        if intervalIsWork {
            intervalIsWork = false
            intervalPhaseRemaining = preset.restSeconds
            WatchTheme.haptic(.stop)
        } else {
            let nextRound = intervalRound + 1
            if nextRound >= preset.rounds {
                intervalFinished = true
                WatchTheme.haptic(.success)
                stop()
                return
            }
            intervalRound = nextRound
            intervalIsWork = true
            intervalPhaseRemaining = preset.workSeconds
            WatchTheme.haptic(.start)
        }
    }

    func skipIntervalPhase() {
        guard mode == .interval else { return }
        intervalPhaseRemaining = 1
        advanceIntervalIfNeeded()
    }

    private func makeIntervalSummary(endedAt endDate: Date) -> WatchIntervalWorkoutSummary? {
        guard let startedAt, let preset = intervalPreset else { return nil }
        return WatchIntervalWorkoutSummary(
            id: standaloneWorkoutID ?? UUID(),
            name: preset.name,
            rounds: intervalFinished ? preset.rounds : intervalRound + 1,
            workSeconds: preset.workSeconds,
            restSeconds: preset.restSeconds,
            startedAt: startedAt,
            endedAt: endDate,
            durationSeconds: max(Int(endDate.timeIntervalSince(startedAt)) - currentPausedSeconds, 1),
            pausedSeconds: currentPausedSeconds,
            activeEnergyKcal: activeEnergy > 0 ? activeEnergy : nil,
            averageHeartRate: averageHeartRate,
            maxHeartRate: heartRateSamples.max(),
            timeInZoneSeconds: nil
        )
    }

    private func sendIntervalSummary(_ summary: WatchIntervalWorkoutSummary) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(summary) else { return }
        let context: [String: Any] = [
            "kind": "intervalWorkoutSummary",
            "intervalWorkoutSummary": data
        ]
        WCSession.default.transferUserInfo(context)
        try? WCSession.default.updateApplicationContext(context)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil)
        }
    }

    private func resetLocalWorkout() {
        mode = .none
        exercises = []
        currentExerciseIndex = 0
        hydratedSignature = nil
        intervalPreset = nil
        intervalRound = 0
        intervalIsWork = true
        intervalPhaseRemaining = 0
        intervalFinished = false
        localRestEndDate = nil
        standaloneTitle = ""
    }

    // MARK: - Remote commands (relayed to iPhone via WatchConnectivity)

    func addWater() {
        send(command: .addWater)
        WatchTheme.haptic(.click)
    }

    func musicToggle() {
        send(command: .musicToggle)
        WatchTheme.haptic(.click)
    }

    func musicNext() {
        send(command: .musicNext)
        WatchTheme.haptic(.click)
    }

    func musicPrev() {
        send(command: .musicPrevious)
        WatchTheme.haptic(.click)
    }

    /// Next exercise name for the strength now view: from the phone snapshot
    /// during phone-driven sessions, or from the local exercise array when standalone.
    var nextExerciseNameForDisplay: String? {
        if mode == .phoneStrength {
            return snapshot.nextExerciseName
        }
        let nextIdx = currentExerciseIndex + 1
        return exercises.indices.contains(nextIdx) ? exercises[nextIdx].name : nil
    }
}

extension WatchWorkoutModel: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.message = error.localizedDescription
        }
    }
}

extension WatchWorkoutModel: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType,
                      let statistics = workoutBuilder.statistics(for: quantityType) else {
                    continue
                }
                self.updateStatistics(statistics)
            }
        }
    }
}

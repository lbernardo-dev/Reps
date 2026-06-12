import Foundation
import CoreLocation
import CoreMotion
import HealthKit
import WatchConnectivity

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

    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private let locationManager = CLLocationManager()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
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
        let wasStandalone = snapshot.sessionTitle == "Iniciado desde Apple Watch"
        isStandaloneRouteWorkout = isLocalRouteWorkout && (wasStandalone || !snapshot.hasActiveWorkout)

        if isLocalRouteWorkout, state == .running {
            startPedometer()
            if configuration.locationType != .indoor {
                startLocation()
            }
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

    func startStandaloneRouteWorkout(activity: WatchRouteWorkoutActivity) {
        guard session == nil else { return }
        Task {
            do {
                try await requestHealthAuthorization()
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = activity == .running ? .running : .walking
                configuration.locationType = .outdoor

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
                isLocalRouteWorkout = true
                isStandaloneRouteWorkout = true
                standaloneActivity = activity
                standaloneWorkoutID = UUID()
                accumulatedPausedSeconds = 0
                pauseStartedAt = nil
                resetRouteMetrics()
                updateStandaloneSnapshotIfNeeded()

                workoutSession.startActivity(with: startDate)
                try await workoutBuilder.beginCollection(at: startDate)
                try? await workoutSession.startMirroringToCompanionDevice()
                startPedometer()
                startLocation()
                startTimer()
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
            let shouldSendRouteSummary = isLocalRouteWorkout
            let summary = shouldSendRouteSummary ? makeStandaloneSummary(endedAt: endDate) : nil
            session?.end()
            try? await builder?.endCollection(at: endDate)
            _ = try? await builder?.finishWorkout()
            timer?.invalidate()
            stopPedometer()
            stopLocation()
            state = .idle
            endedAt = endDate
            if let summary {
                sendStandaloneSummary(summary)
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

        Task {
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
            title.localizedCaseInsensitiveContains("movilidad") {
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
            return "Carrera"
        case .walking:
            return "Caminata"
        case .flexibility:
            return "Movilidad"
        default:
            return "Entreno"
        }
    }

    private func prepareSnapshotForCompanionLaunch(configuration: HKWorkoutConfiguration, startedAt: Date) {
        guard !snapshot.hasActiveWorkout else { return }
        let title = Self.workoutTitle(for: configuration)
        snapshot = SharedWorkoutSnapshot(
            hasActiveWorkout: true,
            planTitle: nil,
            workoutTitle: title,
            sessionTitle: "Iniciado desde iPhone",
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
            widgetAccentColorName: snapshot.widgetAccentColorName
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
            sessionTitle: "Iniciado desde Apple Watch",
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
            summary: "\(activity.title) en curso desde Apple Watch",
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
            widgetAccentColorName: "green"
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
                        timestamp: location.timestamp
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
            widgetAccentColorName: context["widgetAccentColorName"] as? String ?? "system"
        )
    }

    private func apply(snapshot: SharedWorkoutSnapshot) {
        if isStandaloneRouteWorkout {
            return
        }
        self.snapshot = snapshot
        SharedWorkoutStore.save(snapshot)
        if snapshot.hasActiveWorkout {
            startLocalWorkoutIfNeeded(for: snapshot)
        } else if !snapshot.hasActiveWorkout {
            stopLocalRouteWorkoutIfNeeded()
        }
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

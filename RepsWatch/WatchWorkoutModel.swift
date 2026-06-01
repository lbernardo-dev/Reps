import Foundation
import HealthKit
import WatchConnectivity

@MainActor
final class WatchWorkoutModel: NSObject, ObservableObject {
    enum State {
        case idle
        case running
        case paused
    }

    @Published var snapshot = SharedWorkoutSnapshot.empty
    @Published var state: State = .idle
    @Published var heartRate: Double?
    @Published var activeEnergy: Double = 0
    @Published var elapsedSeconds = 0
    @Published var message: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startedAt: Date?
    private var timer: Timer?

    override init() {
        super.init()
        configureConnectivity()
        snapshot = SharedWorkoutStore.load()
    }

    func startWorkout() {
        Task {
            do {
                try await requestHealthAuthorization()
                let configuration = HKWorkoutConfiguration()
                configuration.activityType = .traditionalStrengthTraining
                configuration.locationType = .indoor

                let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let workoutBuilder = workoutSession.associatedWorkoutBuilder()
                workoutBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
                workoutSession.delegate = self
                workoutBuilder.delegate = self

                session = workoutSession
                builder = workoutBuilder
                startedAt = .now
                state = .running
                send(command: .resume)
                workoutSession.startActivity(with: .now)
                try await workoutBuilder.beginCollection(at: .now)
                startTimer()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func pause() {
        session?.pause()
        state = .paused
        send(command: .pause)
    }

    func resume() {
        session?.resume()
        state = .running
        send(command: .resume)
    }

    func stop() {
        Task {
            let endDate = Date()
            session?.end()
            try? await builder?.endCollection(at: endDate)
            _ = try? await builder?.finishWorkout()
            timer?.invalidate()
            state = .idle
            send(command: .stop)
            session = nil
            builder = nil
        }
    }

    private func requestHealthAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        let shareTypes: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    private func configureConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
            }
        }
    }

    private func updateStatistics(_ statistics: HKStatistics) {
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit)
        case HKQuantityType(.activeEnergyBurned):
            activeEnergy = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeEnergy
        default:
            break
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
        self.snapshot = snapshot
        SharedWorkoutStore.save(snapshot)
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

import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif


enum RepsAppGroup {
    static let identifier = "group.com.romerodev.repsfitness"
}

enum WatchCommand: String, Sendable {
    case pause
    case resume
    case stop
    case musicToggle
    case musicNext
    case musicPrevious
    case completeSet
    case nextExercise
    case previousExercise
    case addWater
    case voiceNote

    var notificationName: Notification.Name {
        Notification.Name("WatchCommand.\(rawValue)")
    }
}

struct SharedWorkoutSnapshot: Codable, Hashable {
    var hasActiveWorkout: Bool
    var planTitle: String?
    var workoutTitle: String
    var sessionTitle: String?
    var elapsedSeconds: Int
    var pausedSeconds: Int
    var completedSets: Int
    var totalSets: Int
    var volumeKg: Int
    var isPaused: Bool
    var exerciseName: String?
    var exerciseIndex: Int?
    var totalExercises: Int?
    var currentExerciseCompletedSets: Int?
    var currentExerciseTotalSets: Int?
    var currentSetWeightKg: Double?
    var currentSetReps: Int?
    var restSeconds: Int?
    var restDurationSeconds: Int?
    var estimatedRemainingSeconds: Int?
    var waterLiters: Double?
    var musicTitle: String?
    var musicArtist: String?
    var isMusicPlaying: Bool?
    var nextExerciseName: String?
    var exerciseHistorySummary: String?
    var gymPassName: String?
    var gymMembershipID: String?
    var gymCodeValue: String?
    var gymCodeType: String?
    var heartRate: Double?
    var activeEnergyKcal: Double?
    var summary: String
    var updatedAt: Date

    // New properties for enhanced widgets
    var streakDays: Int
    var weeklyCompletion: Double
    var trainingBatteryLevel: Int
    var trainingBatteryState: String
    var trainingBatteryTitle: String
    var trainingBatterySuggestion: String
    var trainingBatterySystemImage: String
    var nextWorkoutDayName: String?
    var nextWorkoutDayDescription: String?
    /// Raw WidgetColor name — drives the widget background color
    var widgetAccentColorName: String

    static let empty = SharedWorkoutSnapshot(
        hasActiveWorkout: false,
        planTitle: nil,
        workoutTitle: "Reps",
        sessionTitle: nil,
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
        heartRate: nil,
        activeEnergyKcal: nil,
        summary: "Sin entreno activo",
        updatedAt: .now,
        streakDays: 0,
        weeklyCompletion: 0.0,
        trainingBatteryLevel: 100,
        trainingBatteryState: "charged",
        trainingBatteryTitle: "Cargada",
        trainingBatterySuggestion: "Buen momento para entrenar.",
        trainingBatterySystemImage: "battery.100percent",
        nextWorkoutDayName: nil,
        nextWorkoutDayDescription: nil,
        widgetAccentColorName: "system"
    )

    var progress: Double {
        guard totalSets > 0 else { return 0 }
        return min(max(Double(completedSets) / Double(totalSets), 0), 1)
    }

    var elapsedText: String {
        Self.durationText(elapsedSeconds)
    }

    var elapsedStartDate: Date {
        updatedAt.addingTimeInterval(-TimeInterval(elapsedSeconds))
    }

    var remainingText: String {
        Self.durationText(estimatedRemainingSeconds ?? 0)
    }

    var restText: String {
        Self.durationText(restSeconds ?? 0)
    }

    var restEndDate: Date? {
        guard let restSeconds, restSeconds > 0 else {
            return nil
        }
        return updatedAt.addingTimeInterval(TimeInterval(restSeconds))
    }

    var restProgress: Double {
        guard let restSeconds,
              let restDurationSeconds,
              restDurationSeconds > 0 else {
            return 0
        }
        let completed = Double(restDurationSeconds - restSeconds) / Double(restDurationSeconds)
        return min(max(completed, 0), 1)
    }

    static func durationText(_ value: Int) -> String {
        let seconds = max(value, 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

enum SharedWorkoutStore {
    private static let key = "activeWorkoutSnapshot"
    private static let lastTimelineReloadKey = "activeWorkoutSnapshot.lastTimelineReload"
    private static let widgetKinds = [
        "RepsWorkoutWidget",
        "RepsBatteryWidget",
        "RepsStreakWidget"
    ]
    private static let minimumTimelineReloadInterval: TimeInterval = 3

    static func load() -> SharedWorkoutSnapshot {
        guard let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SharedWorkoutSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: SharedWorkoutSnapshot, reloadTimelines: Bool = true, forceReload: Bool = false) {
        guard let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
        guard reloadTimelines else {
            return
        }
        #if canImport(WidgetKit)
        #if !os(watchOS)
        let now = Date()
        let lastReload = Date(timeIntervalSince1970: defaults.double(forKey: lastTimelineReloadKey))
        guard forceReload || now.timeIntervalSince(lastReload) >= minimumTimelineReloadInterval else {
            return
        }
        defaults.set(now.timeIntervalSince1970, forKey: lastTimelineReloadKey)
        widgetKinds.forEach { kind in
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        #endif
        #endif
    }

}

#if canImport(ActivityKit)
struct RepsWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var snapshot: SharedWorkoutSnapshot
    }

    var workoutTitle: String
}
#endif

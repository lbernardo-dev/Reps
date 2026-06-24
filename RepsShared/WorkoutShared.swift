import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(SwiftUI)
enum RepsLocalization {
    nonisolated(unsafe) private static var activeLanguage: String = {
        Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
    }()

    static var language: String {
        activeLanguage
    }

    static var locale: Locale {
        Locale(identifier: activeLanguage)
    }

    @discardableResult
    static func use(_ language: String?) -> Locale {
        if let language, !language.isEmpty {
            activeLanguage = language
        }
        return locale
    }

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }
}

func localizedKey(_ key: String) -> String {
    RepsLocalization.string(key)
}

func localizedKey(_ key: LocalizedStringKey) -> LocalizedStringKey {
    key
}
#endif

func localizedString(_ key: String) -> String {
    #if canImport(SwiftUI)
    RepsLocalization.string(key)
    #else
    String(localized: String.LocalizationValue(key))
    #endif
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    #if canImport(SwiftUI)
    String(
        format: RepsLocalization.string(key),
        locale: RepsLocalization.locale,
        arguments: arguments
    )
    #else
    String(format: String(localized: String.LocalizationValue(key)), locale: .current, arguments: arguments)
    #endif
}

enum RepsAppGroup {
    static let identifier = "group.com.romerodev.repsfitness"

    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }
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

enum WatchRouteWorkoutActivity: String, Codable, Hashable, Sendable {
    case walking
    case running

    var title: String {
        switch self {
        case .walking:
            return localizedString("route_activity_walking")
        case .running:
            return localizedString("route_activity_running")
        }
    }
}

struct SharedRoutePoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var timestamp: Date
    var heartRate: Double? = nil
    var cadenceSpm: Double? = nil
}

struct WatchRouteWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var activity: WatchRouteWorkoutActivity
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var distanceKm: Double?
    var averagePaceSecondsPerKm: Double?
    var averageSpeedKmh: Double?
    var steps: Double?
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var routePoints: [SharedRoutePoint]

    var durationMinutes: Int {
        max(durationSeconds / 60, 1)
    }
}

/// One logged/planned set as it travels between iPhone and Watch.
/// `setType` is the raw value of `SetLog.SetType`; `trackingType` (on the
/// owning exercise) the raw value of `Exercise.TrackingType`.
struct SharedPlannedSet: Codable, Hashable, Sendable {
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var setType: String
    var rpe: Double? = nil
}

/// A full exercise (with its sets) shared so the Watch can render and log a
/// strength workout — both the planned list pushed from the iPhone and the
/// log dumped back from the Watch reuse this shape.
struct SharedPlannedExercise: Codable, Hashable, Sendable {
    var name: String
    var trackingType: String
    var targetSets: Int
    var repRange: String
    var restSeconds: Int
    var previous: String?
    var sets: [SharedPlannedSet]
}

/// Strength workout logged on the Watch and dumped to the iPhone when it
/// reconnects. Mirrors the route summary path so the phone can import a
/// complete `WorkoutSession` with `exerciseLogs`.
struct WatchStrengthWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var exercises: [SharedPlannedExercise]
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?

    var durationMinutes: Int { max(durationSeconds / 60, 1) }
}

/// Interval / HIIT workout authored and run on the Watch, dumped to the iPhone
/// as a HIIT cardio log.
struct WatchIntervalWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var rounds: Int
    var workSeconds: Int
    var restSeconds: Int
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Seconds spent in each HR zone (Z1…Z5), when available.
    var timeInZoneSeconds: [Int]? = nil

    var durationMinutes: Int { max(durationSeconds / 60, 1) }
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
    var isRouteWorkout: Bool
    var isOutdoorRoute: Bool? = nil
    var routeDistanceKm: Double?
    var routePaceSecondsPerKm: Double?
    var routeSpeedKmh: Double?
    var routePointCount: Int?
    var routeSteps: Double?
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
    var preferredLanguage: String? = nil
    /// JSON-encoded `[SharedPlannedExercise]` for the active strength workout,
    /// letting the Watch render the full exercise list and log sets live.
    var exercisesData: Data? = nil
    /// Estimated max heart rate (≈ 220 − age) for HR-zone coloring on the Watch.
    var estimatedMaxHeartRate: Double? = nil

    /// Decoded planned exercises from `exercisesData`, if present.
    var plannedExercises: [SharedPlannedExercise] {
        guard let exercisesData,
              let decoded = try? JSONDecoder().decode([SharedPlannedExercise].self, from: exercisesData) else {
            return []
        }
        return decoded
    }

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
        isRouteWorkout: false,
        isOutdoorRoute: nil,
        routeDistanceKm: nil,
        routePaceSecondsPerKm: nil,
        routeSpeedKmh: nil,
        routePointCount: nil,
        routeSteps: nil,
        summary: localizedString("widget_no_active_workout"),
        updatedAt: .now,
        streakDays: 0,
        weeklyCompletion: 0.0,
        trainingBatteryLevel: 100,
        trainingBatteryState: "charged",
        trainingBatteryTitle: localizedString("battery_state_charged"),
        trainingBatterySuggestion: localizedString("battery_suggestion_good"),
        trainingBatterySystemImage: "battery.100percent",
        nextWorkoutDayName: nil,
        nextWorkoutDayDescription: nil,
        widgetAccentColorName: "system",
        preferredLanguage: "es"
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
        guard RepsAppGroup.isAvailable else {
            return .empty
        }
        guard let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SharedWorkoutSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: SharedWorkoutSnapshot, reloadTimelines: Bool = true, forceReload: Bool = false) {
        guard RepsAppGroup.isAvailable else {
            return
        }
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

// MARK: - Shared Leaderboard (Friends Widget)

struct SharedLeaderboardEntry: Codable, Hashable, Identifiable {
    var id: String { username }
    var rank: Int
    var username: String
    var xp: Int
    var isMe: Bool
}

enum SharedLeaderboardStore {
    private static let key = "friendsLeaderboardSnapshot"
    private static let widgetKind = "RepsFriendsWidget"

    static func save(_ entries: [SharedLeaderboardEntry]) {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
        #if canImport(WidgetKit)
        #if !os(watchOS)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        #endif
        #endif
    }

    static func load() -> [SharedLeaderboardEntry] {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([SharedLeaderboardEntry].self, from: data) else {
            return []
        }
        return entries
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

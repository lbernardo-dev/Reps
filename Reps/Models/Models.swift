import Foundation

struct UserProfile: Codable {
    enum TrainingLocation: String, CaseIterable, Codable, Identifiable {
        case gym = "Gym"
        case home = "Home"
        case both = "Both"
        var id: String { rawValue }
    }

    enum MainGoal: String, CaseIterable, Codable, Identifiable {
        case buildMuscle = "Build Muscle"
        case loseFat = "Lose Fat"
        case getStronger = "Get Stronger"
        case stayActive = "Stay Active"
        var id: String { rawValue }
    }

    enum Experience: String, CaseIterable, Codable, Identifiable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        var id: String { rawValue }
    }

    enum Units: String, CaseIterable, Codable, Identifiable {
        case metric = "kg/cm"
        case imperial = "lb/in"
        var id: String { rawValue }
    }

    enum DistanceUnit: String, CaseIterable, Codable, Identifiable {
        case kilometers = "km"
        case miles = "mi"
        var id: String { rawValue }
    }

    enum Sex: String, CaseIterable, Codable, Identifiable {
        case male = "male"
        case female = "female"
        case other = "other"
        var id: String { rawValue }
    }

    enum ThemeMode: String, CaseIterable, Codable, Identifiable {
        case dark = "Oscuro"
        case light = "Claro"
        case system = "Sistema"
        var id: String { rawValue }
    }

    var displayName: String?
    var email: String?
    var sex: Sex?
    var dateOfBirth: Date?
    var avatarImageData: Data?
    var preferredLanguage = "es"
    var units: Units = .metric
    var distanceUnit: DistanceUnit = .kilometers
    var trainingLocation: TrainingLocation = .gym
    var mainGoal: MainGoal = .buildMuscle
    var experience: Experience = .intermediate
    var weeklyTrainingDays = 4
    var availableEquipment: [String] = []
    var showRPE = false
    var showRIR = false
    var showSetType = false
    var showTempo = false
    var weightIncrementKg = 2.5
    var autoProgressionEnabled = false
    var remindersEnabled = false
    var onboardingCompleted = false
    var themeMode: ThemeMode?
    var targetEventName: String?
    var targetEventDate: Date?
    /// Raw value of WidgetColor — synced to the App Group so all widgets read it
    var widgetAccentColorName: String = "system"
    
    var activeThemeMode: ThemeMode {
        themeMode ?? .dark
    }
}

struct ProgressPhoto: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var imageData: Data
    var weightKg: Double?
    var note: String?
}

struct GymPass: Codable, Identifiable, Hashable {
    enum CodeType: String, Codable, CaseIterable, Identifiable {
        case qr
        case barcode
        var id: String { rawValue }
    }

    var id = UUID()
    var gymName: String
    var membershipID: String
    var codeValue: String
    var codeType: CodeType
    var colorHex: String = "#8524DB"
    var notes: String?
}

struct GymVisit: Codable, Identifiable, Hashable {
    var id = UUID()
    var gymName: String
    var date: Date
    var locationNote: String?
    var workoutTitle: String?
}

struct Exercise: Codable, Identifiable, Hashable {
    enum TrackingType: String, Codable {
        case weightReps
        case repsOnly
        case duration
    }

    enum ExerciseType: String, Codable, CaseIterable, Identifiable {
        case strength
        case cardio
        case mobility
        case stretching
        case hiit
        var id: String { rawValue }
    }

    enum Difficulty: String, Codable, CaseIterable, Identifiable {
        case low
        case medium
        case high
        var id: String { rawValue }
    }

    enum Environment: String, Codable, CaseIterable, Identifiable {
        case home
        case gym
        case both
        var id: String { rawValue }
    }

    var id = UUID()
    var name: String
    var aliases: [String] = []
    var muscleGroup: String
    var secondaryMuscles: [String] = []
    var equipment: String
    var requiredEquipment: [String] = []
    var trackingType: TrackingType = .weightReps
    var exerciseType: ExerciseType = .strength
    var difficulty: Difficulty = .medium
    var environment: Environment = .both
    var tags: [String] = []
    var mediaURL: String?
    var customImageData: Data?
    var videoURL: String?
    var mediaBookmarks: [ExerciseMediaBookmark] = []
    var instructions: String?
    var commonMistakes: [String] = []
    var notes: String?
    var sourceID: String?
    var sourceName: String?
    var sourceLicense: String?
    var sourceURL: String?
}

extension Exercise {
    var mediaAssetURL: URL? {
        guard let mediaURL,
              !mediaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let url = URL(string: mediaURL) {
            return url
        }

        return mediaURL
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            .flatMap(URL.init(string:))
    }
}

struct ExerciseMediaBookmark: Codable, Identifiable, Hashable {
    enum Source: String, Codable, CaseIterable, Identifiable {
        case youtube
        case youtubeShorts
        case tiktok
        case instagram
        case other
        var id: String { rawValue }
    }

    var id = UUID()
    var title: String
    var source: Source
    var urlString: String
    var timestampSeconds: Int?
    var playbackDurationSeconds: Int?
    var note: String?
    var createdAt: Date = .now
}

struct WorkoutExercise: Codable, Identifiable, Hashable {
    enum Priority: String, Codable, CaseIterable, Identifiable {
        case primary
        case secondary
        case accessory
        var id: String { rawValue }
    }

    enum ProgressionType: String, Codable, CaseIterable, Identifiable {
        case none
        case linear
        case doubleProgression
        case rpeTarget
        case percentOneRepMax
        var id: String { rawValue }
    }

    var id = UUID()
    var exercise: Exercise
    var targetSets: Int
    var repRange: String
    var previous: String
    var restSeconds: Int = 90
    var priority: Priority = .secondary
    var progressionType: ProgressionType = .none
    var targetRPE: Double?
    var targetRIR: Int?
    var incrementKg: Double = 2.5
    var cues: String?
    var mediaBookmarks: [ExerciseMediaBookmark] = []
}

struct WorkoutDay: Codable, Identifiable, Hashable {
    enum SessionType: String, Codable, CaseIterable, Identifiable {
        case strength
        case cardioRun
        case cardioWalk
        case mixedRoute
        case mobility
        case free

        var id: String { rawValue }
    }

    var id = UUID()
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var exercises: [WorkoutExercise]
    var sessionType: SessionType = .strength
    var restBetweenExercisesSeconds: Int = 120
}

extension WorkoutDay {
    static var freeWorkout: WorkoutDay {
        WorkoutDay(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
            title: "Entrenamiento libre",
            subtitle: "Añade ejercicios durante la sesión",
            durationMinutes: 45,
            exercises: [],
            sessionType: .free
        )
    }
}

struct PlanPlaylist: Codable, Identifiable, Hashable {
    enum Provider: String, Codable, CaseIterable, Identifiable {
        case appleMusic
        case spotify

        var id: String { rawValue }
    }

    var id = UUID()
    var provider: Provider
    var title: String
    var urlString: String
    var notes: String?
}

struct WorkoutPlan: Codable, Identifiable {
    var id = UUID()
    var name: String
    var location: UserProfile.TrainingLocation
    var daysPerWeek: Int
    var currentWeek: Int
    var totalWeeks: Int
    var completion: Double
    var days: [WorkoutDay]
    var playlists: [PlanPlaylist] = []
    var currentDayIndex: Int? = 0
    var targetEventName: String? = nil
    var targetEventDate: Date? = nil

    var activeDayIndex: Int {
        get { currentDayIndex ?? 0 }
        set { currentDayIndex = newValue }
    }
}

extension WorkoutPlan {
    static let empty = WorkoutPlan(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        name: "Sin plan activo",
        location: .gym,
        daysPerWeek: 0,
        currentWeek: 0,
        totalWeeks: 0,
        completion: 0,
        days: [],
        currentDayIndex: 0
    )

    static var freshEmpty: WorkoutPlan {
        WorkoutPlan(
            name: "Sin plan activo",
            location: .gym,
            daysPerWeek: 0,
            currentWeek: 0,
            totalWeeks: 0,
            completion: 0,
            days: [],
            currentDayIndex: 0
        )
    }
}

struct ScheduledWorkout: Codable, Identifiable {
    enum Status: String, Codable {
        case scheduled = "Scheduled"
        case completed = "Completed"
        case missed = "Missed"
        case skipped = "Skipped"
    }

    var id = UUID()
    var date: Date
    var workoutDay: WorkoutDay
    var status: Status
}

struct SetLog: Codable, Identifiable, Hashable {
    enum SetType: String, Codable, CaseIterable, Identifiable {
        case warmUp
        case work
        case topSet
        case backOff
        case dropSet
        case restPause
        case activation
        case failure
        var id: String { rawValue }
    }

    var id = UUID()
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var setType: SetType = .work
    var rpe: Double?
    var rir: Int?
    var tempo: String?
    var previousRestSeconds: Int?
    var isPersonalRecord = false
    var notes: String?
}

struct WorkoutMediaAttachment: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case image
        case audio
    }

    var id = UUID()
    var kind: Kind
    var createdAt: Date = .now
    var data: Data?
    var note: String?
    var durationSeconds: Double?
}

struct RoutePoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var timestamp: Date
}

struct ExerciseLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var exercise: Exercise
    var notes: String
    var sets: [SetLog]
    var mediaAttachments: [WorkoutMediaAttachment] = []
}

struct WorkoutSession: Codable, Identifiable {
    enum Origin: String, Codable, CaseIterable, Identifiable {
        case routine
        case free
        var id: String { rawValue }
    }

    enum Location: String, Codable, CaseIterable, Identifiable {
        case home
        case gym
        case outdoor
        case other
        var id: String { rawValue }
    }

    enum ContextTag: String, Codable, CaseIterable, Identifiable {
        case normal
        case travel
        case deload
        case competition
        case oneRepMaxTest
        var id: String { rawValue }
    }

    var id = UUID()
    var workoutTitle: String
    var date: Date
    var startedAt: Date?
    var endedAt: Date?
    var origin: Origin = .routine
    var location: Location = .gym
    var contextTag: ContextTag = .normal
    var durationMinutes: Int
    var sets: [SetLog]
    var notes: String? = nil
    var exerciseLogs: [ExerciseLog]? = nil
    var sessionRPE: Double?
    var energyBefore: Int?
    var energyAfter: Int?
    var estimatedCalories: Double?
    var mediaAttachments: [WorkoutMediaAttachment] = []
    var routePoints: [RoutePoint] = []
    var pausedDurationSeconds: Int = 0
    
    // HealthKit sync properties
    var healthKitUUIDString: String? = nil
    var isImportedFromHealth: Bool = false
    var healthKitActivityTypes: [String] = []
    var averageHeartRate: Double? = nil
    var maxHeartRate: Double? = nil
}

struct SavedShareCard: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var workoutTitle: String
    var imageData: Data
}

struct ActiveWorkoutStatus: Identifiable, Equatable, Codable {
    var id = UUID()
    var planTitle: String?
    var workoutTitle: String
    var sessionTitle: String?
    var startedAt: Date = .now
    var elapsedSeconds: Int = 0
    var pausedSeconds: Int = 0
    var completedSets: Int = 0
    var totalSets: Int = 0
    var volumeKg: Int = 0
    var isPaused = false
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
    var lastPausedAt: Date? = nil

    func effectivePausedSeconds(at date: Date = .now) -> Int {
        guard isPaused, let lastPausedAt else {
            return pausedSeconds
        }

        return pausedSeconds + max(Int(date.timeIntervalSince(lastPausedAt)), 0)
    }

    func effectiveElapsedSeconds(at date: Date = .now) -> Int {
        guard startedAt.timeIntervalSince1970 > 0 else {
            return elapsedSeconds
        }

        let effectiveDate = isPaused ? (lastPausedAt ?? date) : date
        let derivedElapsed = Int(effectiveDate.timeIntervalSince(startedAt)) - pausedSeconds
        return max(derivedElapsed, elapsedSeconds, 0)
    }
}

struct Goal: Codable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case strength = "Strength"
        case consistency = "Consistency"
        case bodyWeight = "Body Weight"
        case custom = "Custom"

        var id: String { rawValue }
    }

    var id = UUID()
    var kind: Kind = .strength
    var title: String
    var current: Double
    var target: Double
    var unit: String
    var deadline: Date?
}

struct BodyMetric: Codable, Identifiable {
    enum Source: String, Codable {
        case manual = "Manual"
        case appleHealth = "Apple Health"
    }

    var id = UUID()
    var date: Date
    var weightKg: Double
    var heightCm: Double
    var bodyFatPercentage: Double?
    var waistCm: Double?
    var chestCm: Double?
    var armCm: Double?
    var thighCm: Double?
    var hipCm: Double?
    var calfCm: Double?
    var neckCm: Double?
    var sleepHours: Double?
    var sleepQuality: Int?
    var fatigue: Int?
    var stress: Int?
    var waterLiters: Double?
    var dietaryEnergyKcal: Double?
    var sorenessNotes: String?
    var source: Source
}

struct CardioLog: Codable, Identifiable, Hashable {
    enum ActivityType: String, Codable, CaseIterable, Identifiable {
        case treadmill
        case elliptical
        case stationaryBike
        case outdoorRun
        case walking
        case rowing
        case hiit
        case other
        var id: String { rawValue }
    }

    var id = UUID()
    var activityType: ActivityType
    var date: Date
    var durationMinutes: Int
    var distanceKm: Double?
    var averageSpeedKmh: Double?
    var averagePaceSecondsPerKm: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var estimatedCalories: Double?
    var rpe: Double?
    var notes: String?
    var routePoints: [RoutePoint] = []
}

struct DailyHealthMetric: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var steps: Double
    var activeEnergyKcal: Double
    var dietaryEnergyKcal: Double
    var waterLiters: Double
    var exerciseMinutes: Double?
    var restingHeartRate: Double?
    var heartRateVariabilityMS: Double?
}

struct HealthSyncState: Codable {
    var isAvailable = false
    var isAuthorized = false
    var lastSyncDate: Date?
    var message: String?
    var latestDailyMetrics: [DailyHealthMetric] = []
}

struct BodyWellnessDefaults {
    var bodyFatPercentage: Double?
    var waistCm: Double?
    var sleepHours: Double?
    var waterLiters: Double?
    var dietaryEnergyKcal: Double?
    var sleepQuality: Int?
    var fatigue: Int?
    var stress: Int?
}

struct ExerciseSessionDraft: Codable, Equatable, Hashable {
    var workoutExercise: WorkoutExercise
    var notes: String
    var voiceNote: String = ""
    var sets: [SetLog]
    var mediaAttachments: [WorkoutMediaAttachment] = []
}

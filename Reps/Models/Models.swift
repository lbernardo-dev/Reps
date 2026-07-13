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
        case bodyRecomposition = "Body Recomposition"
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
    /// Short name used for in-app greetings. Auto-derived from `displayName`
    /// until the user overrides it explicitly in their profile.
    var alias: String?

    static func firstName(from fullName: String) -> String {
        String(fullName.split(separator: " ").first ?? "")
    }

    /// The alias to greet the user with: their explicit override, or the
    /// first name lifted from `displayName` as a live fallback.
    var resolvedAlias: String? {
        if let alias, !alias.isEmpty { return alias }
        guard let displayName, !displayName.isEmpty else { return nil }
        return Self.firstName(from: displayName)
    }

    var email: String?
    var sex: Sex?
    var dateOfBirth: Date?
    var avatarImageData: Data?
    var preferredLanguage = UserProfile.deviceDefaultLanguage

    /// Fresh installs follow the user's supported system language. If neither
    /// English nor Spanish is preferred, English is the fallback.
    static var deviceDefaultLanguage: String {
        Locale.preferredLanguages
            .compactMap { $0.split(separator: "-").first?.lowercased() }
            .first { ["en", "es"].contains($0) } ?? "en"
    }
    var units: Units = .metric
    var distanceUnit: DistanceUnit = .kilometers
    var trainingLocation: TrainingLocation = .gym
    var mainGoal: MainGoal = .buildMuscle
    var experience: Experience = .intermediate
    var weeklyTrainingDays = 4
    var preferredSessionLengthMinutes: Int? = nil
    var availableEquipment: [String] = []
    var showRPE = false
    var showRIR = false
    var showSetType = false
    var showTempo = false
    var weightIncrementKg = 2.5
    var autoProgressionEnabled = false
    var remindersEnabled = false
    /// Whether ending an active workout asks for confirmation first. The user
    /// can permanently silence this from the in-workout "don't ask again"
    /// checkbox, or re-enable it later from Settings.
    var confirmBeforeEndingWorkout: Bool = true
    /// Short audible cues for workout countdowns and phase transitions.
    var audibleWorkoutCuesEnabled: Bool = true
    var onboardingCompleted = false
    var themeMode: ThemeMode?
    var targetEventName: String?
    var targetEventDate: Date?
    /// Raw value of WidgetColor — synced to the App Group so all widgets read it
    var widgetAccentColorName: String = "system"

    // ── Home screen layout customization (Apple Fitness-style Edit Layout).
    // Empty arrays mean "use the default order / nothing hidden". Ids come from
    // the per-screen `CustomizableSection` enums (see SectionCustomization.swift).
    var todaySectionOrder: [String] = []
    var todayHiddenSectionIDs: [String] = []
    var trainSectionOrder: [String] = []
    var trainHiddenSectionIDs: [String] = []
    var progressSectionOrder: [String] = []
    var progressHiddenSectionIDs: [String] = []
    var exercisesCategoryOrder: [String] = []
    var exercisesHiddenCategoryIDs: [String] = []
    var exercisesMuscleShortcutOrder: [String] = []
    var exercisesHiddenMuscleShortcutIDs: [String] = []

    // ── Health goals
    enum CalorieGoalType: String, CaseIterable, Codable, Identifiable {
        case fatLoss       = "calorie_goal_fat_loss"
        case recomposition = "calorie_goal_recomposition"
        case strength      = "calorie_goal_strength"
        case buildMuscle   = "calorie_goal_build_muscle"
        var id: String { rawValue }
        var localizedLabel: String { localizedTitle(rawValue) }
    }

    var sleepTargetHours: Double = 7.5
    var dailyCalorieGoalKcal: Int? = nil
    var calorieGoalType: CalorieGoalType = .recomposition
    var dailyWaterGoalLiters: Double = 2.5
    var dailyStepsGoal: Int = 8_000

    // Track B — social / community features
    var socialEnabled: Bool = false
    var socialUsername: String?
    var socialBio: String = ""
    var socialLocation: String = ""
    var autoShareWorkouts: Bool = true
    var socialNotificationsEnabled: Bool = true
    /// Panel-level category toggles for the in-app notifications inbox
    /// (distinct from `remindersEnabled`, which governs system push nudges).
    var notifyWorkoutActivity: Bool = true
    var notifyAchievements: Bool = true
    var notifyCoachingTips: Bool = true
    var socialAgeGateStatus: SocialAgeGateStatus = .unknown
    var socialAgeGateCheckedAt: Date?
    // Usernames the local user is following — stored locally so we can fetch
    // their profiles without a CKQuery index.
    var socialFollowingUsernames: [String] = []
    /// Users hidden locally after a moderation block. This is intentionally
    /// local-first so a block takes effect before the next CloudKit refresh.
    var socialBlockedUsernames: [String] = []

    var activeThemeMode: ThemeMode {
        themeMode ?? .dark
    }

    /// Community features are only disabled when Apple's on-device age check
    /// *confirms* the account is under 13 — a legal requirement. There is no
    /// backend to adjudicate the other outcomes (declined sharing, API
    /// unavailable), so those are treated as user responsibility rather than
    /// a product-level block.
    var socialCapabilitiesAllowed: Bool {
        socialAgeGateStatus != .blockedUnder13
    }

    enum SocialAgeGateStatus: String, Codable {
        case unknown
        case allowed13Plus
        case blockedUnder13
        case sharingDeclined
        case unavailable
    }
}

struct ProgressPhoto: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var imageData: Data
    var weightKg: Double?
    var note: String?
}

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case annual
    case oneTime
    var id: String { rawValue }
}

struct GymInvoice: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date = .now
    var amount: Double
    var currencyCode: String = "USD"
    var periodStart: Date?
    var periodEnd: Date?
    var note: String?
    var attachmentData: Data?     // imagen o PDF del recibo
    var attachmentIsPDF: Bool = false
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

    // Captura / respaldo visual: imagen del carnet cuando no hay código legible.
    var imageData: Data?

    // Periodo / estado (el histórico es la lista de pases activos + pasados).
    var isActive: Bool = true
    var startDate: Date?
    var endDate: Date?

    // Detalles del plan.
    var planName: String?
    var price: Double?
    var currencyCode: String?
    var billingCycle: BillingCycle?
    var nextRenewalDate: Date?
    var renewalReminderEnabled: Bool = false

    // Datos del local.
    var venueAddress: String?
    var venuePhone: String?
    var venueWebsite: String?
    var venueHours: String?

    // Facturas.
    var invoices: [GymInvoice] = []
}

struct GymVisit: Codable, Identifiable, Hashable {
    var id = UUID()
    var gymName: String
    var date: Date
    var locationNote: String?
    var workoutTitle: String?
    var address: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var workoutSessionIDs: [UUID] = []

    var hasCoordinate: Bool {
        latitude != nil && longitude != nil
    }
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
    /// Per-secondary-muscle involvement as a fraction (0...1) of how much each
    /// secondary muscle counts toward set/volume tallies. Missing entries fall
    /// back to `Exercise.defaultSecondaryInvolvement`.
    var secondaryMuscleWeights: [String: Double] = [:]
    var equipment: String
    var requiredEquipment: [String] = []
    var trackingType: TrackingType = .weightReps
    var exerciseType: ExerciseType = .strength
    var difficulty: Difficulty = .medium
    var environment: Environment = .both
    var tags: [String] = []
    var mediaURL: String?
    var customImageData: Data?
    /// Locally-recorded or gallery-picked guide video, stored inline (mirrors `customImageData`).
    var customVideoData: Data?
    /// Poster frame for `customVideoData`, used as a static preview before playback.
    var customVideoThumbnailData: Data?
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
    /// Default involvement applied to a secondary muscle when the exercise has
    /// no explicit weight for it.
    static let defaultSecondaryInvolvement: Double = 0.5

    /// Involvement fraction (0...1) of a secondary muscle for this exercise.
    func secondaryInvolvement(_ muscle: String) -> Double {
        secondaryMuscleWeights[muscle] ?? Self.defaultSecondaryInvolvement
    }

    var mediaAssetURL: URL? {
        guard let mediaURL,
              !mediaURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let trimmedURL = mediaURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedURL) {
            return url
        }

        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "#%")

        return trimmedURL
            .addingPercentEncoding(withAllowedCharacters: allowedCharacters)
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
    var progressionType: ProgressionType = .doubleProgression
    var targetRPE: Double?
    var targetRIR: Int?
    var incrementKg: Double = 2.5
    var cues: String?
    var mediaBookmarks: [ExerciseMediaBookmark] = []
    /// When enabled, the next planned session for this exercise gains one extra target set.
    var aimForMoreSetsNextTime: Bool = false
    /// When set, this exercise belongs to a superset. Exercises sharing the same
    /// group id are alternated round-robin during the active session (short rest
    /// between members, full rest once a round is closed). `nil` = standard linear flow.
    var supersetGroup: UUID? = nil
}

struct WorkoutDay: Codable, Identifiable, Hashable {
    enum SessionType: String, Codable, CaseIterable, Identifiable {
        case strength
        case cardioRun
        case cardioWalk
        case mixedRoute
        case mobility
        case free
        case core

        var id: String { rawValue }
    }

    enum CardioEnvironment: String, Codable, CaseIterable, Identifiable {
        case outdoor
        case treadmill

        var id: String { rawValue }
    }

    var id = UUID()
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var exercises: [WorkoutExercise]
    var sessionType: SessionType = .strength
    var restBetweenExercisesSeconds: Int = 300
    var cardioEnvironment: CardioEnvironment?
}

extension WorkoutDay {
    static var freeWorkout: WorkoutDay {
        WorkoutDay(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
            title: localizedString("free_workout_title"),
            subtitle: localizedString("add_exercises_during_session"),
            durationMinutes: 45,
            exercises: [],
            sessionType: .free
        )
    }

    static var freeCore: WorkoutDay {
        WorkoutDay(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            title: localizedString("core_training"),
            subtitle: localizedString("add_core_exercises_and_log_sets_or_time"),
            durationMinutes: 20,
            exercises: [],
            sessionType: .core
        )
    }
}

struct PlanPlaylist: Codable, Identifiable, Hashable {
    enum Provider: String, Codable, CaseIterable, Identifiable {
        case appleMusic

        var id: String { rawValue }

        init(from decoder: Decoder) throws {
            // Map any legacy/unknown provider (e.g. the removed "spotify") to Apple Music
            // so previously saved playlists are migrated instead of dropped.
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Provider(rawValue: raw) ?? .appleMusic
        }
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
    var normalizedActiveDayIndex: Int? {
        guard !days.isEmpty else { return nil }
        let count = days.count
        return ((activeDayIndex % count) + count) % count
    }

    var normalizedActiveDay: WorkoutDay? {
        guard let index = normalizedActiveDayIndex else { return nil }
        return days[index]
    }

    mutating func normalizeActiveDayIndex() {
        activeDayIndex = normalizedActiveDayIndex ?? 0
    }

    static let empty = WorkoutPlan(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        name: localizedString("plan_no_active_plan"),
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
            name: localizedString("plan_no_active_plan"),
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
        case video
    }

    var id = UUID()
    var kind: Kind
    var createdAt: Date = .now
    var data: Data?
    var note: String?
    var durationSeconds: Double?
    /// Poster frame for video attachments (and any kind that wants a preview).
    var thumbnailData: Data?
}

struct RoutePoint: Codable, Identifiable, Hashable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var timestamp: Date
    /// Instantaneous heart rate (bpm) sampled nearest this point, when available.
    var heartRate: Double? = nil
    /// Instantaneous running cadence (steps per minute) covering this point, when available.
    var cadenceSpm: Double? = nil
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
    var distanceKm: Double? = nil
    var averagePaceSecondsPerKm: Double? = nil
    var steps: Double? = nil
    var activeEnergyKcal: Double? = nil
    var heartRateBefore: Double? = nil
    var heartRateAfter: Double? = nil
    
    // HealthKit sync properties
    var healthKitUUIDString: String? = nil
    var isImportedFromHealth: Bool = false
    var healthKitActivityTypes: [String] = []
    var averageHeartRate: Double? = nil
    var maxHeartRate: Double? = nil
}

extension WorkoutSession {
    /// True when the session contains cardio-route specific data (GPS points, pace, distance).
    /// NOTE: `steps` alone is NOT sufficient — HealthKit syncs step counts on any workout type,
    /// including strength sessions, so we exclude that field here to avoid misclassification.
    var hasRouteMetrics: Bool {
        !routePoints.isEmpty ||
        distanceKm != nil ||
        averagePaceSecondsPerKm != nil
    }

    /// True if the session should be treated as a cardio/route session (shows route panel
    /// in the receipt, map-backdrop in history, distance metrics, etc.).
    ///
    /// Priority rule: a session that contains completed strength sets or exercise logs
    /// is **always** a strength session, regardless of any route metrics that may have
    /// been incidentally synced from HealthKit (e.g. step counts).
    var isRouteSession: Bool {
        // If there are actual strength-training records, this is a strength session.
        let hasStrengthContent = !sets.isEmpty ||
            (exerciseLogs?.isEmpty == false)
        if hasStrengthContent { return false }

        // Now check for cardio route data (GPS, pace, distance).
        if hasRouteMetrics { return true }

        // Fallback: empty session whose title suggests cardio activity.
        let normalizedTitle = workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return sets.isEmpty && (
            normalizedTitle.localizedCaseInsensitiveContains("camina") ||
            normalizedTitle.localizedCaseInsensitiveContains("walk") ||
            normalizedTitle.localizedCaseInsensitiveContains("carrera") ||
            normalizedTitle.localizedCaseInsensitiveContains("run")
        )
    }

    var routeKindTitle: String {
        let normalizedTitle = workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if normalizedTitle.localizedCaseInsensitiveContains("carrera") ||
            normalizedTitle.localizedCaseInsensitiveContains("run") {
            return location == .outdoor ? "Carrera" : "Carrera en cinta"
        }
        if normalizedTitle.localizedCaseInsensitiveContains("camina") ||
            normalizedTitle.localizedCaseInsensitiveContains("walk") {
            return location == .outdoor ? "Caminata" : "Caminata en cinta"
        }
        return "Ruta"
    }

    var routeSystemImage: String {
        if routeKindTitle.localizedCaseInsensitiveContains("carrera") {
            return location == .outdoor ? "figure.run" : "figure.run.treadmill"
        }
        return location == .outdoor ? "figure.walk" : "figure.walk.motion"
    }

    var isOutdoorRouteSession: Bool {
        isRouteSession && location == .outdoor && routePoints.count >= 2
    }
}

extension WorkoutDay {
    var isCardioMovement: Bool {
        switch sessionType {
        case .cardioRun, .cardioWalk, .mixedRoute:
            return true
        case .strength, .mobility, .free, .core:
            return false
        }
    }

    var isOutdoorRouteWorkout: Bool {
        isCardioMovement && cardioEnvironment != .treadmill
    }

    var isTreadmillWorkout: Bool {
        isCardioMovement && cardioEnvironment == .treadmill
    }
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
    var isRouteWorkout: Bool = false
    var isOutdoorRoute: Bool?
    var routeDistanceKm: Double?
    var routePaceSecondsPerKm: Double?
    var routeSpeedKmh: Double?
    var routePointCount: Int?
    var routePoints: [RoutePoint]?
    var routeSteps: Double?
    var liveHeartRate: Double?
    var liveActiveEnergyKcal: Double?

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

    enum Status { case active, achieved, overdue }

    var id = UUID()
    var kind: Kind = .strength
    var title: String
    var current: Double
    var target: Double
    var unit: String
    var deadline: Date?
    var reason: String? = nil

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var isAchieved: Bool { progress >= 1.0 }

    var isOverdue: Bool {
        guard let deadline, !isAchieved else { return false }
        return deadline < Date.now
    }

    var status: Status {
        if isAchieved { return .achieved }
        if isOverdue { return .overdue }
        return .active
    }
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
    var steps: Double?
    var activeEnergyKcal: Double?
    var heartRateBefore: Double?
    var heartRateAfter: Double?
    var rpe: Double?
    var notes: String?
    var routePoints: [RoutePoint] = []
}

struct WorkoutSensorSummary: Codable, Hashable {
    var steps: Double?
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var heartRateBefore: Double?
    var heartRateAfter: Double?
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
    var sleepHours: Double?
    var vo2MaxMlKgMin: Double?
    // Sleep stage breakdown, bucketed from the same HealthKit sleep-analysis
    // samples already queried for `sleepHours` — nil on devices/nights with
    // no stage-capable source (older watches, manual entries).
    var sleepRemHours: Double?
    var sleepDeepHours: Double?
    var sleepCoreHours: Double?
    var sleepAwakeHours: Double?
    /// Count of distinct `.awake` segments inside the sleep window.
    var sleepInterruptions: Int?
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
    var restingHeartRate: Double?
    var heartRateVariabilityMS: Double?
}

struct ExerciseSessionDraft: Codable, Equatable, Hashable {
    var workoutExercise: WorkoutExercise
    var notes: String
    var voiceNote: String = ""
    var sets: [SetLog]
    var mediaAttachments: [WorkoutMediaAttachment] = []
}

struct AchievementUnlockBanner: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let description: String
    let systemImage: String
    let colorName: String
    let xpReward: Int
}

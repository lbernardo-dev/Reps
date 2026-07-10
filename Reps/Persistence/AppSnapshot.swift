import Foundation

struct AppSnapshot: Codable {
    var snapshotVersion: Int = 2
    var userProfile: UserProfile
    var monetization: MonetizationState
    var activePlan: WorkoutPlan
    var plans: [WorkoutPlan]
    var workoutTemplates: [WorkoutDay]
    var exercises: [Exercise]
    var scheduledWorkouts: [ScheduledWorkout]
    var workoutSessions: [WorkoutSession]
    var cardioLogs: [CardioLog]
    var bodyMetrics: [BodyMetric]
    var progressPhotos: [ProgressPhoto]
    var gymPasses: [GymPass]
    var gymVisits: [GymVisit]
    var goals: [Goal]
    var health: HealthSyncState
    var activeWorkout: WorkoutDay? = nil
    var activeWorkoutDrafts: [ExerciseSessionDraft]? = nil
    var activeWorkoutStatus: ActiveWorkoutStatus? = nil
    var savedShareCards: [SavedShareCard] = []
    var rehabLogs: [RehabSessionLog] = []

    init(
        userProfile: UserProfile,
        monetization: MonetizationState = MonetizationState(),
        activePlan: WorkoutPlan,
        plans: [WorkoutPlan],
        workoutTemplates: [WorkoutDay],
        exercises: [Exercise],
        scheduledWorkouts: [ScheduledWorkout],
        workoutSessions: [WorkoutSession],
        cardioLogs: [CardioLog] = [],
        bodyMetrics: [BodyMetric],
        progressPhotos: [ProgressPhoto] = [],
        gymPasses: [GymPass] = [],
        gymVisits: [GymVisit] = [],
        goals: [Goal],
        health: HealthSyncState,
        activeWorkout: WorkoutDay? = nil,
        activeWorkoutDrafts: [ExerciseSessionDraft]? = nil,
        activeWorkoutStatus: ActiveWorkoutStatus? = nil,
        savedShareCards: [SavedShareCard] = [],
        rehabLogs: [RehabSessionLog] = [],
        snapshotVersion: Int = 2
    ) {
        self.snapshotVersion = snapshotVersion
        self.userProfile = userProfile
        self.monetization = monetization
        self.activePlan = activePlan
        self.plans = plans
        self.workoutTemplates = workoutTemplates
        self.exercises = exercises
        self.scheduledWorkouts = scheduledWorkouts
        self.workoutSessions = workoutSessions
        self.cardioLogs = cardioLogs
        self.bodyMetrics = bodyMetrics
        self.progressPhotos = progressPhotos
        self.gymPasses = gymPasses
        self.gymVisits = gymVisits
        self.goals = goals
        self.health = health
        self.activeWorkout = activeWorkout
        self.activeWorkoutDrafts = activeWorkoutDrafts
        self.activeWorkoutStatus = activeWorkoutStatus
        self.savedShareCards = savedShareCards
        self.rehabLogs = rehabLogs
    }

    private enum CodingKeys: String, CodingKey {
        case snapshotVersion
        case userProfile
        case monetization
        case activePlan
        case plans
        case workoutTemplates
        case exercises
        case scheduledWorkouts
        case workoutSessions
        case cardioLogs
        case bodyMetrics
        case progressPhotos
        case gymPasses
        case gymVisits
        case goals
        case health
        case activeWorkout
        case activeWorkoutDrafts
        case activeWorkoutStatus
        case savedShareCards
        case rehabLogs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        snapshotVersion = try container.decodeIfPresent(Int.self, forKey: .snapshotVersion) ?? 2
        userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
        monetization = try container.decodeIfPresent(MonetizationState.self, forKey: .monetization) ?? MonetizationState()
        activePlan = try container.decode(WorkoutPlan.self, forKey: .activePlan)
        plans = try container.decode([WorkoutPlan].self, forKey: .plans)
        workoutTemplates = try container.decode([WorkoutDay].self, forKey: .workoutTemplates)
        exercises = try container.decode([Exercise].self, forKey: .exercises)
        scheduledWorkouts = try container.decode([ScheduledWorkout].self, forKey: .scheduledWorkouts)
        workoutSessions = try container.decode([WorkoutSession].self, forKey: .workoutSessions)
        cardioLogs = try container.decodeIfPresent([CardioLog].self, forKey: .cardioLogs) ?? []
        bodyMetrics = try container.decode([BodyMetric].self, forKey: .bodyMetrics)
        progressPhotos = try container.decodeIfPresent([ProgressPhoto].self, forKey: .progressPhotos) ?? []
        gymPasses = try container.decodeIfPresent([GymPass].self, forKey: .gymPasses) ?? []
        gymVisits = try container.decodeIfPresent([GymVisit].self, forKey: .gymVisits) ?? []
        goals = try container.decode([Goal].self, forKey: .goals)
        health = try container.decode(HealthSyncState.self, forKey: .health)
        activeWorkout = try container.decodeIfPresent(WorkoutDay.self, forKey: .activeWorkout)
        activeWorkoutDrafts = try container.decodeIfPresent([ExerciseSessionDraft].self, forKey: .activeWorkoutDrafts)
        activeWorkoutStatus = try container.decodeIfPresent(ActiveWorkoutStatus.self, forKey: .activeWorkoutStatus)
        savedShareCards = try container.decodeIfPresent([SavedShareCard].self, forKey: .savedShareCards) ?? []
        rehabLogs = try container.decodeIfPresent([RehabSessionLog].self, forKey: .rehabLogs) ?? []
    }
}

extension AppSnapshot {
    /// Snapshot used by the automatic iCloud mirror.
    ///
    /// HealthKit/body/routing data is deliberately excluded. Apple permits an
    /// app to use iCloud for operational data, but prohibits storing personal
    /// health information there (App Review Guideline 5.1.3(ii)). Full exports
    /// remain available through the user-initiated JSON export path.
    var iCloudSafe: AppSnapshot {
        var safeProfile = userProfile
        safeProfile.avatarImageData = nil

        let safeSessions = workoutSessions.map { session in
            WorkoutSession(
                id: session.id,
                workoutTitle: session.workoutTitle,
                date: session.date,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                origin: session.origin,
                location: session.location,
                contextTag: session.contextTag,
                durationMinutes: session.durationMinutes,
                sets: session.sets,
                notes: session.notes,
                exerciseLogs: session.exerciseLogs,
                sessionRPE: session.sessionRPE,
                energyBefore: session.energyBefore,
                energyAfter: session.energyAfter,
                estimatedCalories: nil,
                mediaAttachments: [],
                routePoints: [],
                pausedDurationSeconds: session.pausedDurationSeconds,
                distanceKm: nil,
                averagePaceSecondsPerKm: nil,
                steps: nil,
                activeEnergyKcal: nil,
                heartRateBefore: nil,
                heartRateAfter: nil,
                healthKitUUIDString: nil,
                isImportedFromHealth: false,
                healthKitActivityTypes: [],
                averageHeartRate: nil,
                maxHeartRate: nil
            )
        }

        return AppSnapshot(
            userProfile: safeProfile,
            monetization: monetization,
            activePlan: activePlan,
            plans: plans,
            workoutTemplates: workoutTemplates,
            exercises: exercises,
            scheduledWorkouts: scheduledWorkouts,
            workoutSessions: safeSessions,
            // Cardio and body collections can contain HealthKit-derived values.
            cardioLogs: [],
            bodyMetrics: [],
            progressPhotos: [],
            gymPasses: gymPasses,
            gymVisits: gymVisits,
            goals: goals,
            health: HealthSyncState(),
            activeWorkout: nil,
            activeWorkoutDrafts: nil,
            activeWorkoutStatus: nil,
            savedShareCards: [],
            rehabLogs: []
        )
    }

    static var empty: AppSnapshot {
        AppSnapshot(
            userProfile: UserProfile(),
            monetization: MonetizationState(),
            activePlan: .empty,
            plans: SeedData.defaultPlans,
            workoutTemplates: SeedData.workoutTemplates,
            exercises: SeedData.exercises,
            scheduledWorkouts: [],
            workoutSessions: [],
            cardioLogs: [],
            bodyMetrics: [],
            progressPhotos: [],
            gymPasses: [],
            gymVisits: [],
            goals: [],
            health: HealthSyncState(),
            activeWorkout: nil,
            activeWorkoutDrafts: nil,
            activeWorkoutStatus: nil,
            savedShareCards: []
        )
    }

    static var seed: AppSnapshot {
        empty
    }
}

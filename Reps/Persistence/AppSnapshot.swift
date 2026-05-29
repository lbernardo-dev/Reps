import Foundation

struct AppSnapshot: Codable {
    var userProfile: UserProfile
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

    init(
        userProfile: UserProfile,
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
        health: HealthSyncState
    ) {
        self.userProfile = userProfile
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
    }

    private enum CodingKeys: String, CodingKey {
        case userProfile
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userProfile = try container.decode(UserProfile.self, forKey: .userProfile)
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
    }
}

extension AppSnapshot {
    static var seed: AppSnapshot {
        AppSnapshot(
            userProfile: UserProfile(),
            activePlan: SeedData.pushPullLegsPlan,
            plans: SeedData.defaultPlans,
            workoutTemplates: SeedData.workoutTemplates,
            exercises: SeedData.exercises,
            scheduledWorkouts: SeedData.scheduledWorkouts,
            workoutSessions: SeedData.sessions,
            cardioLogs: [],
            bodyMetrics: SeedData.bodyMetrics,
            progressPhotos: [],
            gymPasses: [],
            gymVisits: [],
            goals: SeedData.goals,
            health: HealthSyncState()
        )
    }
}

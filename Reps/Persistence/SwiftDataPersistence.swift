import Foundation
import SwiftData

enum PersistenceScope: CaseIterable, Hashable, Sendable {
    case profile
    case monetization
    case health
    case exerciseLibrary
    case plans
    case workoutTemplates
    case scheduledWorkouts
    case workoutSessions
    case cardioLogs
    case bodyMetrics
    case progressPhotos
    case gymPasses
    case gymVisits
    case goals
    case savedShareCards

    static let all = Set(PersistenceScope.allCases)
}

@MainActor
final class SwiftDataPersistence {
    private static let appGroupIdentifier = "group.com.romerodev.repsfitness"

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private(set) var didFallbackToInMemory: Bool = false

    init(inMemory: Bool = false) {
        let schema = Schema([
            UserProfileRecord.self,
            MonetizationStateRecord.self,
            ExerciseRecord.self,
            SetLogRecord.self,
            WorkoutExerciseRecord.self,
            WorkoutDayRecord.self,
            WorkoutTemplateRecord.self,
            WorkoutPlanRecord.self,
            ScheduledWorkoutRecord.self,
            ExerciseLogRecord.self,
            WorkoutSessionRecord.self,
            GoalRecord.self,
            BodyMetricRecord.self,
            CardioLogRecord.self,
            ProgressPhotoRecord.self,
            SavedShareCardRecord.self,
            GymPassRecord.self,
            GymVisitRecord.self,
            HealthSyncRecord.self
        ])

        do {
            let configuration: ModelConfiguration
            if inMemory {
                configuration = ModelConfiguration(
                    "RepsStore-\(UUID().uuidString)",
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
            } else {
                configuration = try Self.persistentConfiguration(schema: schema)
            }

            container = try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            didFallbackToInMemory = true
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(
                        "RepsFallbackStore-\(UUID().uuidString)",
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )
                )
            } catch {
                fatalError("SwiftData: failed to create in-memory fallback container — \(error)")
            }
        }
    }

    private static func persistentConfiguration(schema: Schema) throws -> ModelConfiguration {
        let fileManager = FileManager.default
        let applicationSupportURL: URL
        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            applicationSupportURL = appGroupURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        } else {
            applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
        }

        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return ModelConfiguration(
            "RepsStore",
            schema: schema,
            url: applicationSupportURL.appendingPathComponent("RepsStore.store"),
            cloudKitDatabase: .none
        )
    }

    func loadSnapshot() -> AppSnapshot? {
        let profiles = fetch(UserProfileRecord.self)
        let planRecords = fetch(WorkoutPlanRecord.self)

        guard let profile = profiles.first else {
            return nil
        }

        let activePlan = planRecords.first(where: \.isActive)?.domain ?? planRecords.first?.domain ?? .empty
        let visiblePlans = planRecords
            .filter { record in
                !(record.isActive && record.id == activePlan.id && activePlan.days.isEmpty)
            }
            .map(\.domain)

        let activeWorkoutStatus = profile.activeWorkoutStatusData.flatMap { try? JSONDecoder().decode(ActiveWorkoutStatus.self, from: $0) }
        let activeWorkout = profile.activeWorkoutData.flatMap { try? JSONDecoder().decode(WorkoutDay.self, from: $0) }
        let activeWorkoutDrafts = profile.activeWorkoutDraftsData.flatMap { try? JSONDecoder().decode([ExerciseSessionDraft].self, from: $0) }

        return AppSnapshot(
            userProfile: profile.domain,
            monetization: fetch(MonetizationStateRecord.self).first?.domain ?? MonetizationState(),
            activePlan: activePlan,
            plans: visiblePlans,
            workoutTemplates: fetch(WorkoutTemplateRecord.self).map(\.domain),
            exercises: fetch(ExerciseRecord.self).filter(\.isLibraryItem).map(\.domain),
            scheduledWorkouts: fetch(ScheduledWorkoutRecord.self).map(\.domain),
            workoutSessions: fetch(WorkoutSessionRecord.self).map(\.domain),
            cardioLogs: fetch(CardioLogRecord.self).map(\.domain),
            bodyMetrics: fetch(BodyMetricRecord.self).map(\.domain),
            progressPhotos: fetch(ProgressPhotoRecord.self).map(\.domain),
            gymPasses: fetch(GymPassRecord.self).map(\.domain),
            gymVisits: fetch(GymVisitRecord.self).map(\.domain),
            goals: fetch(GoalRecord.self).map(\.domain),
            health: fetch(HealthSyncRecord.self).first?.domain ?? HealthSyncState(),
            activeWorkout: activeWorkout,
            activeWorkoutDrafts: activeWorkoutDrafts,
            activeWorkoutStatus: activeWorkoutStatus,
            savedShareCards: fetch(SavedShareCardRecord.self).map(\.domain)
        )
    }

    /// Rewrites only the record types covered by `scopes`, leaving the rest of
    /// the store untouched. Defaults to a full rewrite for restore/import flows.
    func save(_ snapshot: AppSnapshot, scopes: Set<PersistenceScope> = PersistenceScope.all) {
        for scope in PersistenceScope.allCases where scopes.contains(scope) {
            replace(scope, with: snapshot)
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            TelemetryService.shared.record(error, context: "swiftdata_save")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "swiftdata_save"])
        }
    }

    private func replace(_ scope: PersistenceScope, with snapshot: AppSnapshot) {
        switch scope {
        case .profile:
            deleteAll(UserProfileRecord.self)
            let profileRecord = UserProfileRecord(profile: snapshot.userProfile)
            profileRecord.activeWorkoutStatusData = try? JSONEncoder().encode(snapshot.activeWorkoutStatus)
            profileRecord.activeWorkoutData = try? JSONEncoder().encode(snapshot.activeWorkout)
            profileRecord.activeWorkoutDraftsData = try? JSONEncoder().encode(snapshot.activeWorkoutDrafts)
            context.insert(profileRecord)
        case .monetization:
            deleteAll(MonetizationStateRecord.self)
            context.insert(MonetizationStateRecord(state: snapshot.monetization))
        case .health:
            deleteAll(HealthSyncRecord.self)
            context.insert(HealthSyncRecord(health: snapshot.health))
        case .exerciseLibrary:
            fetch(ExerciseRecord.self).filter(\.isLibraryItem).forEach(context.delete)
            snapshot.exercises
                .map { ExerciseRecord(exercise: $0, isLibraryItem: true) }
                .forEach(context.insert)
        case .plans:
            fetch(WorkoutPlanRecord.self).forEach(deleteGraph)
            let persistedPlans = snapshot.plans.contains(where: { $0.id == snapshot.activePlan.id })
                ? snapshot.plans
                : snapshot.plans + [snapshot.activePlan]
            persistedPlans
                .map { plan in
                    let isActive = plan.id == snapshot.activePlan.id
                    return WorkoutPlanRecord(plan: isActive ? snapshot.activePlan : plan, isActive: isActive)
                }
                .forEach(context.insert)
        case .workoutTemplates:
            fetch(WorkoutTemplateRecord.self).forEach(deleteGraph)
            snapshot.workoutTemplates.map(WorkoutTemplateRecord.init).forEach(context.insert)
        case .scheduledWorkouts:
            fetch(ScheduledWorkoutRecord.self).forEach(deleteGraph)
            snapshot.scheduledWorkouts.map(ScheduledWorkoutRecord.init).forEach(context.insert)
        case .workoutSessions:
            fetch(WorkoutSessionRecord.self).forEach(deleteGraph)
            snapshot.workoutSessions.map(WorkoutSessionRecord.init).forEach(context.insert)
        case .cardioLogs:
            deleteAll(CardioLogRecord.self)
            snapshot.cardioLogs.map(CardioLogRecord.init).forEach(context.insert)
        case .bodyMetrics:
            deleteAll(BodyMetricRecord.self)
            snapshot.bodyMetrics.map(BodyMetricRecord.init).forEach(context.insert)
        case .progressPhotos:
            deleteAll(ProgressPhotoRecord.self)
            snapshot.progressPhotos.map(ProgressPhotoRecord.init).forEach(context.insert)
        case .gymPasses:
            deleteAll(GymPassRecord.self)
            snapshot.gymPasses.map(GymPassRecord.init).forEach(context.insert)
        case .gymVisits:
            deleteAll(GymVisitRecord.self)
            snapshot.gymVisits.map(GymVisitRecord.init).forEach(context.insert)
        case .goals:
            deleteAll(GoalRecord.self)
            snapshot.goals.map(GoalRecord.init).forEach(context.insert)
        case .savedShareCards:
            deleteAll(SavedShareCardRecord.self)
            snapshot.savedShareCards.map(SavedShareCardRecord.init).forEach(context.insert)
        }
    }

    // MARK: - Graph deletion
    //
    // Several record types nest copies of ExerciseRecord/WorkoutDayRecord through
    // relationships without a cascade rule, so deleting only the root record
    // would leave orphaned rows behind. These helpers delete the full graph.

    private func deleteGraph(_ plan: WorkoutPlanRecord) {
        plan.days.forEach(deleteDayGraph)
        context.delete(plan)
    }

    private func deleteGraph(_ template: WorkoutTemplateRecord) {
        deleteDayGraph(template.day)
        context.delete(template)
    }

    private func deleteGraph(_ scheduled: ScheduledWorkoutRecord) {
        deleteDayGraph(scheduled.workoutDay)
        context.delete(scheduled)
    }

    private func deleteGraph(_ session: WorkoutSessionRecord) {
        for log in session.exerciseLogs {
            deleteNestedExercise(log.exercise)
        }
        context.delete(session)
    }

    private func deleteDayGraph(_ day: WorkoutDayRecord?) {
        guard let day else { return }
        for item in day.exercises {
            deleteNestedExercise(item.exercise)
        }
        context.delete(day)
    }

    private func deleteNestedExercise(_ exercise: ExerciseRecord?) {
        guard let exercise, !exercise.isLibraryItem else { return }
        context.delete(exercise)
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        fetch(type).forEach(context.delete)
    }
}

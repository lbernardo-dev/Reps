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
    case rehabLogs

    static let all = Set(PersistenceScope.allCases)

    var signpostName: String {
        switch self {
        case .profile: "profile"
        case .monetization: "monetization"
        case .health: "health"
        case .exerciseLibrary: "exerciseLibrary"
        case .plans: "plans"
        case .workoutTemplates: "workoutTemplates"
        case .scheduledWorkouts: "scheduledWorkouts"
        case .workoutSessions: "workoutSessions"
        case .cardioLogs: "cardioLogs"
        case .bodyMetrics: "bodyMetrics"
        case .progressPhotos: "progressPhotos"
        case .gymPasses: "gymPasses"
        case .gymVisits: "gymVisits"
        case .goals: "goals"
        case .savedShareCards: "savedShareCards"
        case .rehabLogs: "rehabLogs"
        }
    }
}

extension Set where Element == PersistenceScope {
    var signpostDescription: String {
        map(\.signpostName).sorted().joined(separator: ",")
    }
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
            HealthSyncRecord.self,
            RehabSessionLogRecord.self
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
            savedShareCards: fetch(SavedShareCardRecord.self).map(\.domain),
            rehabLogs: fetch(RehabSessionLogRecord.self).map(\.domain)
        )
    }

    /// Rewrites only the record types covered by `scopes`, leaving the rest of
    /// the store untouched. Defaults to a full rewrite for restore/import flows.
    func save(_ snapshot: AppSnapshot, scopes: Set<PersistenceScope> = PersistenceScope.all) {
        let scopeNames = scopes.signpostDescription
        let interval = PerformanceSignpost.begin(
            "swiftData.save",
            "scopes=\(scopeNames)"
        )
        defer {
            PerformanceSignpost.end(
                "swiftData.save",
                interval,
                "scopes=\(scopeNames)"
            )
        }

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
        // Single-row scopes: delete+reinsert of one record is already cheap,
        // so these stay as a full replace rather than adding diff complexity.
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

        // Collection scopes: reconciled by id so an unrelated, unchanged item
        // (the common case — the vast majority of workout history, body
        // metrics, etc. on any given save) is never touched.
        case .exerciseLibrary:
            reconcile(
                snapshot.exercises,
                existing: fetch(ExerciseRecord.self).filter(\.isLibraryItem),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { ExerciseRecord(exercise: $0, isLibraryItem: true) },
                deleteRecord: { context.delete($0) }
            )
        case .plans:
            let persistedPlans = snapshot.plans.contains(where: { $0.id == snapshot.activePlan.id })
                ? snapshot.plans
                : snapshot.plans + [snapshot.activePlan]
            reconcilePlans(persistedPlans, activePlanID: snapshot.activePlan.id, activePlan: snapshot.activePlan)
        case .workoutTemplates:
            reconcile(
                snapshot.workoutTemplates,
                existing: fetch(WorkoutTemplateRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { WorkoutTemplateRecord(day: $0) },
                deleteRecord: { deleteGraph($0) }
            )
        case .scheduledWorkouts:
            reconcile(
                snapshot.scheduledWorkouts,
                existing: fetch(ScheduledWorkoutRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { ScheduledWorkoutRecord(scheduled: $0) },
                deleteRecord: { deleteGraph($0) }
            )
        case .workoutSessions:
            reconcile(
                snapshot.workoutSessions,
                existing: fetch(WorkoutSessionRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { WorkoutSessionRecord(session: $0) },
                deleteRecord: { deleteGraph($0) }
            )
        case .cardioLogs:
            reconcile(
                snapshot.cardioLogs,
                existing: fetch(CardioLogRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { CardioLogRecord(log: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .bodyMetrics:
            reconcile(
                snapshot.bodyMetrics,
                existing: fetch(BodyMetricRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { BodyMetricRecord(metric: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .progressPhotos:
            reconcile(
                snapshot.progressPhotos,
                existing: fetch(ProgressPhotoRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { ProgressPhotoRecord(photo: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .gymPasses:
            reconcile(
                snapshot.gymPasses,
                existing: fetch(GymPassRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { GymPassRecord(pass: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .gymVisits:
            reconcile(
                snapshot.gymVisits,
                existing: fetch(GymVisitRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { GymVisitRecord(visit: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .goals:
            reconcile(
                snapshot.goals,
                existing: fetch(GoalRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { GoalRecord(goal: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .savedShareCards:
            reconcile(
                snapshot.savedShareCards,
                existing: fetch(SavedShareCardRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { SavedShareCardRecord(card: $0) },
                deleteRecord: { context.delete($0) }
            )
        case .rehabLogs:
            reconcile(
                snapshot.rehabLogs,
                existing: fetch(RehabSessionLogRecord.self),
                id: \.id,
                domainOf: \.domain,
                recordID: \.id,
                makeRecord: { RehabSessionLogRecord(log: $0) },
                deleteRecord: { context.delete($0) }
            )
        }
    }

    private static let diffEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private func contentEquals<T: Codable>(_ a: T, _ b: T) -> Bool {
        guard let dataA = try? Self.diffEncoder.encode(a), let dataB = try? Self.diffEncoder.encode(b) else {
            return false
        }
        return dataA == dataB
    }

    /// Upserts `domainItems` against `existing` records by id instead of a full
    /// delete-then-reinsert: unchanged records are left untouched, changed ones
    /// are replaced, and records no longer present in `domainItems` are removed.
    /// Deleting and reinserting the *entire* scope on every save meant editing a
    /// single item (e.g. one set during an active workout) rewrote the whole
    /// history — the larger the store, the slower every save, and it all ran
    /// synchronously on the main actor.
    private func reconcile<Domain: Codable, Record: PersistentModel>(
        _ domainItems: [Domain],
        existing: [Record],
        id: (Domain) -> UUID,
        domainOf: (Record) -> Domain,
        recordID: (Record) -> UUID,
        makeRecord: (Domain) -> Record,
        deleteRecord: (Record) -> Void
    ) {
        var existingByID = Dictionary(uniqueKeysWithValues: existing.map { (recordID($0), $0) })
        for item in domainItems {
            if let match = existingByID.removeValue(forKey: id(item)) {
                if !contentEquals(domainOf(match), item) {
                    deleteRecord(match)
                    context.insert(makeRecord(item))
                }
            } else {
                context.insert(makeRecord(item))
            }
        }
        existingByID.values.forEach(deleteRecord)
    }

    /// Plans need the `isActive` flag compared explicitly alongside content:
    /// it lives on the record, not on the `WorkoutPlan` domain struct, so a
    /// pure content diff would miss "same plan, but activation changed".
    private func reconcilePlans(_ persistedPlans: [WorkoutPlan], activePlanID: UUID, activePlan: WorkoutPlan) {
        var existingByID = Dictionary(uniqueKeysWithValues: fetch(WorkoutPlanRecord.self).map { ($0.id, $0) })
        for plan in persistedPlans {
            let isActive = plan.id == activePlanID
            let resolvedPlan = isActive ? activePlan : plan
            if let match = existingByID.removeValue(forKey: plan.id) {
                if match.isActive != isActive || !contentEquals(match.domain, resolvedPlan) {
                    deleteGraph(match)
                    context.insert(WorkoutPlanRecord(plan: resolvedPlan, isActive: isActive))
                }
            } else {
                context.insert(WorkoutPlanRecord(plan: resolvedPlan, isActive: isActive))
            }
        }
        existingByID.values.forEach(deleteGraph)
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

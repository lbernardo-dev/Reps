import Foundation
import SwiftData

@MainActor
final class SwiftDataPersistence {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private(set) var didFallbackToInMemory: Bool = false

    init(inMemory: Bool = false) {
        let schema = Schema([
            UserProfileRecord.self,
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
            GymPassRecord.self,
            GymVisitRecord.self,
            HealthSyncRecord.self
        ])

        do {
            container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration("RepsStore", schema: schema, isStoredInMemoryOnly: inMemory)
            )
        } catch {
            didFallbackToInMemory = true
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration("RepsFallbackStore", schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }

    func loadSnapshot() -> AppSnapshot? {
        let profiles = fetch(UserProfileRecord.self)
        let plans = fetch(WorkoutPlanRecord.self)

        guard let profile = profiles.first, !plans.isEmpty else {
            return nil
        }

        let activePlan = plans.first(where: \.isActive)?.domain ?? plans.first?.domain ?? SeedData.pushPullLegsPlan

        let activeWorkoutStatus = profile.activeWorkoutStatusData.flatMap { try? JSONDecoder().decode(ActiveWorkoutStatus.self, from: $0) }
        let activeWorkout = profile.activeWorkoutData.flatMap { try? JSONDecoder().decode(WorkoutDay.self, from: $0) }
        let activeWorkoutDrafts = profile.activeWorkoutDraftsData.flatMap { try? JSONDecoder().decode([ExerciseSessionDraft].self, from: $0) }

        return AppSnapshot(
            userProfile: profile.domain,
            activePlan: activePlan,
            plans: plans.map(\.domain),
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
            activeWorkoutStatus: activeWorkoutStatus
        )
    }

    func save(_ snapshot: AppSnapshot) {
        clearStore()

        let profileRecord = UserProfileRecord(profile: snapshot.userProfile)
        profileRecord.activeWorkoutStatusData = try? JSONEncoder().encode(snapshot.activeWorkoutStatus)
        profileRecord.activeWorkoutData = try? JSONEncoder().encode(snapshot.activeWorkout)
        profileRecord.activeWorkoutDraftsData = try? JSONEncoder().encode(snapshot.activeWorkoutDrafts)

        context.insert(profileRecord)
        context.insert(HealthSyncRecord(health: snapshot.health))

        snapshot.exercises
            .map { ExerciseRecord(exercise: $0, isLibraryItem: true) }
            .forEach(context.insert)
        snapshot.plans
            .map { WorkoutPlanRecord(plan: $0, isActive: $0.id == snapshot.activePlan.id) }
            .forEach(context.insert)
        snapshot.workoutTemplates.map(WorkoutTemplateRecord.init).forEach(context.insert)
        snapshot.scheduledWorkouts.map(ScheduledWorkoutRecord.init).forEach(context.insert)
        snapshot.workoutSessions.map(WorkoutSessionRecord.init).forEach(context.insert)
        snapshot.cardioLogs.map(CardioLogRecord.init).forEach(context.insert)
        snapshot.bodyMetrics.map(BodyMetricRecord.init).forEach(context.insert)
        snapshot.progressPhotos.map(ProgressPhotoRecord.init).forEach(context.insert)
        snapshot.gymPasses.map(GymPassRecord.init).forEach(context.insert)
        snapshot.gymVisits.map(GymVisitRecord.init).forEach(context.insert)
        snapshot.goals.map(GoalRecord.init).forEach(context.insert)

        try? context.save()
    }

    private func clearStore() {
        deleteAll(HealthSyncRecord.self)
        deleteAll(UserProfileRecord.self)
        deleteAll(GoalRecord.self)
        deleteAll(GymVisitRecord.self)
        deleteAll(GymPassRecord.self)
        deleteAll(ProgressPhotoRecord.self)
        deleteAll(BodyMetricRecord.self)
        deleteAll(CardioLogRecord.self)
        deleteAll(WorkoutSessionRecord.self)
        deleteAll(ExerciseLogRecord.self)
        deleteAll(ScheduledWorkoutRecord.self)
        deleteAll(WorkoutPlanRecord.self)
        deleteAll(WorkoutTemplateRecord.self)
        deleteAll(WorkoutDayRecord.self)
        deleteAll(WorkoutExerciseRecord.self)
        deleteAll(SetLogRecord.self)
        deleteAll(ExerciseRecord.self)
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        fetch(type).forEach(context.delete)
    }
}

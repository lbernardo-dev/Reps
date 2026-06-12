import Foundation
import SwiftData

@Model
final class UserProfileRecord {
    @Attribute(.unique) var id: String
    var displayName: String?
    var email: String?
    var sex: String?
    var dateOfBirth: Date?
    @Attribute(.externalStorage) var avatarImageData: Data?
    var preferredLanguage: String
    var units: String
    var distanceUnit: String?
    var trainingLocation: String
    var mainGoal: String
    var experience: String
    var weeklyTrainingDays: Int
    var availableEquipmentData: Data?
    var showRPE: Bool?
    var showRIR: Bool?
    var showSetType: Bool?
    var showTempo: Bool?
    var weightIncrementKg: Double?
    var autoProgressionEnabled: Bool?
    var remindersEnabled: Bool
    var onboardingCompleted: Bool
    var themeMode: String?
    var widgetAccentColorName: String?
    var activeWorkoutStatusData: Data?
    var activeWorkoutData: Data?
    var activeWorkoutDraftsData: Data?
    var targetEventName: String?
    var targetEventDate: Date?

    init(profile: UserProfile, id: String = "current") {
        self.id = id
        displayName = profile.displayName
        email = profile.email
        sex = profile.sex?.rawValue
        dateOfBirth = profile.dateOfBirth
        avatarImageData = profile.avatarImageData
        preferredLanguage = profile.preferredLanguage
        units = profile.units.rawValue
        distanceUnit = profile.distanceUnit.rawValue
        trainingLocation = profile.trainingLocation.rawValue
        mainGoal = profile.mainGoal.rawValue
        experience = profile.experience.rawValue
        weeklyTrainingDays = profile.weeklyTrainingDays
        availableEquipmentData = encodeStrings(profile.availableEquipment)
        showRPE = profile.showRPE
        showRIR = profile.showRIR
        showSetType = profile.showSetType
        showTempo = profile.showTempo
        weightIncrementKg = profile.weightIncrementKg
        autoProgressionEnabled = profile.autoProgressionEnabled
        remindersEnabled = profile.remindersEnabled
        onboardingCompleted = profile.onboardingCompleted
        themeMode = profile.themeMode?.rawValue
        widgetAccentColorName = profile.widgetAccentColorName
        targetEventName = profile.targetEventName
        targetEventDate = profile.targetEventDate
    }

    var domain: UserProfile {
        UserProfile(
            displayName: displayName,
            email: email,
            sex: sex.flatMap(UserProfile.Sex.init(rawValue:)),
            dateOfBirth: dateOfBirth,
            avatarImageData: avatarImageData,
            preferredLanguage: preferredLanguage,
            units: UserProfile.Units(rawValue: units) ?? .metric,
            distanceUnit: UserProfile.DistanceUnit(rawValue: distanceUnit ?? "") ?? .kilometers,
            trainingLocation: UserProfile.TrainingLocation(rawValue: trainingLocation) ?? .gym,
            mainGoal: UserProfile.MainGoal(rawValue: mainGoal) ?? .buildMuscle,
            experience: UserProfile.Experience(rawValue: experience) ?? .intermediate,
            weeklyTrainingDays: weeklyTrainingDays,
            availableEquipment: decodeStrings(availableEquipmentData),
            showRPE: showRPE ?? false,
            showRIR: showRIR ?? false,
            showSetType: showSetType ?? false,
            showTempo: showTempo ?? false,
            weightIncrementKg: weightIncrementKg ?? 2.5,
            autoProgressionEnabled: autoProgressionEnabled ?? false,
            remindersEnabled: remindersEnabled,
            onboardingCompleted: onboardingCompleted,
            themeMode: themeMode.flatMap(UserProfile.ThemeMode.init(rawValue:)),
            targetEventName: targetEventName,
            targetEventDate: targetEventDate,
            widgetAccentColorName: widgetAccentColorName ?? "system"
        )
    }
}

@Model
final class MonetizationStateRecord {
    @Attribute(.unique) var id: String
    var entitlement: String
    var status: String
    var billingCycle: String?
    var provider: String
    var trialStartDate: Date?
    var trialEndDate: Date?
    var renewsAt: Date?
    var lastPaywallPresentationDate: Date?
    var lastPaywallDismissDate: Date?
    var lastPaywallSource: String?
    var paywallPresentationCount: Int
    var lastEntitlementSyncDate: Date?
    var revenueCatConfigured: Bool

    init(state: MonetizationState, id: String = "current") {
        self.id = id
        entitlement = state.entitlement.rawValue
        status = state.status.rawValue
        billingCycle = state.billingCycle?.rawValue
        provider = state.provider.rawValue
        trialStartDate = state.trialStartDate
        trialEndDate = state.trialEndDate
        renewsAt = state.renewsAt
        lastPaywallPresentationDate = state.lastPaywallPresentationDate
        lastPaywallDismissDate = state.lastPaywallDismissDate
        lastPaywallSource = state.lastPaywallSource?.rawValue
        paywallPresentationCount = state.paywallPresentationCount
        lastEntitlementSyncDate = state.lastEntitlementSyncDate
        revenueCatConfigured = state.revenueCatConfigured
    }

    var domain: MonetizationState {
        MonetizationState(
            entitlement: SubscriptionEntitlement(rawValue: entitlement) ?? .free,
            status: SubscriptionStatus(rawValue: status) ?? .inactive,
            billingCycle: billingCycle.flatMap(SubscriptionBillingCycle.init(rawValue:)),
            provider: SubscriptionProvider(rawValue: provider) ?? .local,
            trialStartDate: trialStartDate,
            trialEndDate: trialEndDate,
            renewsAt: renewsAt,
            lastPaywallPresentationDate: lastPaywallPresentationDate,
            lastPaywallDismissDate: lastPaywallDismissDate,
            lastPaywallSource: lastPaywallSource.flatMap(PaywallSource.init(rawValue:)),
            paywallPresentationCount: paywallPresentationCount,
            lastEntitlementSyncDate: lastEntitlementSyncDate,
            revenueCatConfigured: revenueCatConfigured
        )
    }
}

@Model
final class ExerciseRecord {
    var id: UUID
    var name: String
    var aliasesData: Data?
    var muscleGroup: String
    var secondaryMusclesData: Data?
    var equipment: String
    var requiredEquipmentData: Data?
    var trackingType: String
    var exerciseType: String?
    var difficulty: String?
    var environment: String?
    var tagsData: Data?
    var mediaURL: String?
    @Attribute(.externalStorage) var customImageData: Data?
    var videoURL: String?
    var mediaBookmarksData: Data?
    var instructions: String?
    var commonMistakesData: Data?
    var notes: String?
    var sourceID: String?
    var sourceName: String?
    var sourceLicense: String?
    var sourceURL: String?
    var isLibraryItem: Bool

    init(exercise: Exercise, isLibraryItem: Bool = false) {
        id = exercise.id
        name = exercise.name
        aliasesData = encodeStrings(exercise.aliases)
        muscleGroup = exercise.muscleGroup
        secondaryMusclesData = encodeStrings(exercise.secondaryMuscles)
        equipment = exercise.equipment
        requiredEquipmentData = encodeStrings(exercise.requiredEquipment)
        trackingType = exercise.trackingType.rawValue
        exerciseType = exercise.exerciseType.rawValue
        difficulty = exercise.difficulty.rawValue
        environment = exercise.environment.rawValue
        tagsData = encodeStrings(exercise.tags)
        mediaURL = exercise.mediaURL
        customImageData = exercise.customImageData
        videoURL = exercise.videoURL
        mediaBookmarksData = encodeExerciseMediaBookmarks(exercise.mediaBookmarks)
        instructions = exercise.instructions
        commonMistakesData = encodeStrings(exercise.commonMistakes)
        notes = exercise.notes
        sourceID = exercise.sourceID
        sourceName = exercise.sourceName
        sourceLicense = exercise.sourceLicense
        sourceURL = exercise.sourceURL
        self.isLibraryItem = isLibraryItem
    }

    var domain: Exercise {
        Exercise(
            id: id,
            name: name,
            aliases: decodeStrings(aliasesData),
            muscleGroup: muscleGroup,
            secondaryMuscles: decodeStrings(secondaryMusclesData),
            equipment: equipment,
            requiredEquipment: decodeStrings(requiredEquipmentData),
            trackingType: Exercise.TrackingType(rawValue: trackingType) ?? .weightReps,
            exerciseType: Exercise.ExerciseType(rawValue: exerciseType ?? "") ?? .strength,
            difficulty: Exercise.Difficulty(rawValue: difficulty ?? "") ?? .medium,
            environment: Exercise.Environment(rawValue: environment ?? "") ?? .both,
            tags: decodeStrings(tagsData),
            mediaURL: mediaURL,
            customImageData: customImageData,
            videoURL: videoURL,
            mediaBookmarks: decodeExerciseMediaBookmarks(mediaBookmarksData),
            instructions: instructions,
            commonMistakes: decodeStrings(commonMistakesData),
            notes: notes,
            sourceID: sourceID,
            sourceName: sourceName,
            sourceLicense: sourceLicense,
            sourceURL: sourceURL
        )
    }
}

@Model
final class WorkoutTemplateRecord {
    var id: UUID
    var day: WorkoutDayRecord?

    init(day: WorkoutDay) {
        id = day.id
        self.day = WorkoutDayRecord(day: day)
    }

    var domain: WorkoutDay {
        day?.domain ?? SeedData.pushDay
    }
}

@Model
final class SetLogRecord {
    var id: UUID
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var setType: String?
    var rpe: Double?
    var rir: Int?
    var tempo: String?
    var previousRestSeconds: Int?
    var isPersonalRecord: Bool?
    var notes: String?

    init(set: SetLog) {
        id = set.id
        setNumber = set.setNumber
        weightKg = set.weightKg
        reps = set.reps
        completed = set.completed
        setType = set.setType.rawValue
        rpe = set.rpe
        rir = set.rir
        tempo = set.tempo
        previousRestSeconds = set.previousRestSeconds
        isPersonalRecord = set.isPersonalRecord
        notes = set.notes
    }

    var domain: SetLog {
        SetLog(
            id: id,
            setNumber: setNumber,
            weightKg: weightKg,
            reps: reps,
            completed: completed,
            setType: SetLog.SetType(rawValue: setType ?? "") ?? .work,
            rpe: rpe,
            rir: rir,
            tempo: tempo,
            previousRestSeconds: previousRestSeconds,
            isPersonalRecord: isPersonalRecord ?? false,
            notes: notes
        )
    }
}

@Model
final class WorkoutExerciseRecord {
    var id: UUID
    var exercise: ExerciseRecord?
    var targetSets: Int
    var repRange: String
    var previous: String
    var restSeconds: Int?
    var priority: String?
    var progressionType: String?
    var targetRPE: Double?
    var targetRIR: Int?
    var incrementKg: Double?
    var cues: String?
    var mediaBookmarksData: Data?

    init(item: WorkoutExercise) {
        id = item.id
        exercise = ExerciseRecord(exercise: item.exercise)
        targetSets = item.targetSets
        repRange = item.repRange
        previous = item.previous
        restSeconds = item.restSeconds
        priority = item.priority.rawValue
        progressionType = item.progressionType.rawValue
        targetRPE = item.targetRPE
        targetRIR = item.targetRIR
        incrementKg = item.incrementKg
        cues = item.cues
        mediaBookmarksData = encodeExerciseMediaBookmarks(item.mediaBookmarks)
    }

    var domain: WorkoutExercise {
        WorkoutExercise(
            id: id,
            exercise: exercise?.domain ?? SeedData.bench,
            targetSets: targetSets,
            repRange: repRange,
            previous: previous,
            restSeconds: restSeconds ?? 90,
            priority: WorkoutExercise.Priority(rawValue: priority ?? "") ?? .secondary,
            progressionType: WorkoutExercise.ProgressionType(rawValue: progressionType ?? "") ?? .none,
            targetRPE: targetRPE,
            targetRIR: targetRIR,
            incrementKg: incrementKg ?? 2.5,
            cues: cues,
            mediaBookmarks: decodeExerciseMediaBookmarks(mediaBookmarksData)
        )
    }
}

@Model
final class WorkoutDayRecord {
    var id: UUID
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var sessionType: String?
    var restBetweenExercisesSeconds: Int?
    @Relationship(deleteRule: .cascade) var exercises: [WorkoutExerciseRecord]

    init(day: WorkoutDay) {
        id = day.id
        title = day.title
        subtitle = day.subtitle
        durationMinutes = day.durationMinutes
        sessionType = day.sessionType.rawValue
        restBetweenExercisesSeconds = day.restBetweenExercisesSeconds
        exercises = day.exercises.map(WorkoutExerciseRecord.init)
    }

    var domain: WorkoutDay {
        WorkoutDay(
            id: id,
            title: title,
            subtitle: subtitle,
            durationMinutes: durationMinutes,
            exercises: exercises.map(\.domain),
            sessionType: WorkoutDay.SessionType(rawValue: sessionType ?? "") ?? .strength,
            restBetweenExercisesSeconds: restBetweenExercisesSeconds ?? 120
        )
    }
}

@Model
final class WorkoutPlanRecord {
    var id: UUID
    var name: String
    var location: String
    var daysPerWeek: Int
    var currentWeek: Int
    var totalWeeks: Int
    var completion: Double
    var isActive: Bool
    var playlistsData: Data?
    var currentDayIndex: Int?
    var targetEventName: String?
    var targetEventDate: Date?
    @Relationship(deleteRule: .cascade) var days: [WorkoutDayRecord]

    init(plan: WorkoutPlan, isActive: Bool) {
        id = plan.id
        name = plan.name
        location = plan.location.rawValue
        daysPerWeek = plan.daysPerWeek
        currentWeek = plan.currentWeek
        totalWeeks = plan.totalWeeks
        completion = plan.completion
        self.isActive = isActive
        playlistsData = encodePlanPlaylists(plan.playlists)
        currentDayIndex = plan.currentDayIndex
        days = plan.days.map(WorkoutDayRecord.init)
        targetEventName = plan.targetEventName
        targetEventDate = plan.targetEventDate
    }

    var domain: WorkoutPlan {
        WorkoutPlan(
            id: id,
            name: name,
            location: UserProfile.TrainingLocation(rawValue: location) ?? .gym,
            daysPerWeek: daysPerWeek,
            currentWeek: currentWeek,
            totalWeeks: totalWeeks,
            completion: completion,
            days: days.map(\.domain),
            playlists: decodePlanPlaylists(playlistsData),
            currentDayIndex: currentDayIndex,
            targetEventName: targetEventName,
            targetEventDate: targetEventDate
        )
    }
}

@Model
final class ScheduledWorkoutRecord {
    var id: UUID
    var date: Date
    var status: String
    var workoutDay: WorkoutDayRecord?

    init(scheduled: ScheduledWorkout) {
        id = scheduled.id
        date = scheduled.date
        status = scheduled.status.rawValue
        workoutDay = WorkoutDayRecord(day: scheduled.workoutDay)
    }

    var domain: ScheduledWorkout {
        ScheduledWorkout(
            id: id,
            date: date,
            workoutDay: workoutDay?.domain ?? SeedData.pushDay,
            status: ScheduledWorkout.Status(rawValue: status) ?? .scheduled
        )
    }
}

@Model
final class ExerciseLogRecord {
    var id: UUID
    var exercise: ExerciseRecord?
    var notes: String
    var mediaAttachmentsData: Data?
    @Relationship(deleteRule: .cascade) var sets: [SetLogRecord]

    init(log: ExerciseLog) {
        id = log.id
        exercise = ExerciseRecord(exercise: log.exercise)
        notes = log.notes
        mediaAttachmentsData = encodeWorkoutMediaAttachments(log.mediaAttachments)
        sets = log.sets.map(SetLogRecord.init)
    }

    var domain: ExerciseLog {
        ExerciseLog(
            id: id,
            exercise: exercise?.domain ?? SeedData.bench,
            notes: notes,
            sets: sets.map(\.domain),
            mediaAttachments: decodeWorkoutMediaAttachments(mediaAttachmentsData)
        )
    }
}

@Model
final class WorkoutSessionRecord {
    var id: UUID
    var workoutTitle: String
    var date: Date
    var startedAt: Date?
    var endedAt: Date?
    var origin: String?
    var location: String?
    var contextTag: String?
    var durationMinutes: Int
    var notes: String?
    var sessionRPE: Double?
    var energyBefore: Int?
    var energyAfter: Int?
    var estimatedCalories: Double?
    var mediaAttachmentsData: Data?
    var routePointsData: Data?
    var pausedDurationSeconds: Int?
    var distanceKm: Double?
    var averagePaceSecondsPerKm: Double?
    var steps: Double?
    var activeEnergyKcal: Double?
    var heartRateBefore: Double?
    var heartRateAfter: Double?
    @Relationship(deleteRule: .cascade) var sets: [SetLogRecord]
    @Relationship(deleteRule: .cascade) var exerciseLogs: [ExerciseLogRecord]

    init(session: WorkoutSession) {
        id = session.id
        workoutTitle = session.workoutTitle
        date = session.date
        startedAt = session.startedAt
        endedAt = session.endedAt
        origin = session.origin.rawValue
        location = session.location.rawValue
        contextTag = session.contextTag.rawValue
        durationMinutes = session.durationMinutes
        notes = session.notes
        sessionRPE = session.sessionRPE
        energyBefore = session.energyBefore
        energyAfter = session.energyAfter
        estimatedCalories = session.estimatedCalories
        mediaAttachmentsData = encodeWorkoutMediaAttachments(session.mediaAttachments)
        routePointsData = encodeRoutePoints(session.routePoints)
        pausedDurationSeconds = session.pausedDurationSeconds
        distanceKm = session.distanceKm
        averagePaceSecondsPerKm = session.averagePaceSecondsPerKm
        steps = session.steps
        activeEnergyKcal = session.activeEnergyKcal
        heartRateBefore = session.heartRateBefore
        heartRateAfter = session.heartRateAfter
        sets = session.sets.map(SetLogRecord.init)
        exerciseLogs = (session.exerciseLogs ?? []).map(ExerciseLogRecord.init)
    }

    var domain: WorkoutSession {
        WorkoutSession(
            id: id,
            workoutTitle: workoutTitle,
            date: date,
            startedAt: startedAt,
            endedAt: endedAt,
            origin: WorkoutSession.Origin(rawValue: origin ?? "") ?? .routine,
            location: WorkoutSession.Location(rawValue: location ?? "") ?? .gym,
            contextTag: WorkoutSession.ContextTag(rawValue: contextTag ?? "") ?? .normal,
            durationMinutes: durationMinutes,
            sets: sets.map(\.domain),
            notes: notes,
            exerciseLogs: exerciseLogs.map(\.domain),
            sessionRPE: sessionRPE,
            energyBefore: energyBefore,
            energyAfter: energyAfter,
            estimatedCalories: estimatedCalories,
            mediaAttachments: decodeWorkoutMediaAttachments(mediaAttachmentsData),
            routePoints: decodeRoutePoints(routePointsData),
            pausedDurationSeconds: pausedDurationSeconds ?? 0,
            distanceKm: distanceKm,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            steps: steps,
            activeEnergyKcal: activeEnergyKcal,
            heartRateBefore: heartRateBefore,
            heartRateAfter: heartRateAfter
        )
    }
}

@Model
final class GoalRecord {
    var id: UUID
    var kind: String
    var title: String
    var current: Double
    var target: Double
    var unit: String
    var deadline: Date?

    init(goal: Goal) {
        id = goal.id
        kind = goal.kind.rawValue
        title = goal.title
        current = goal.current
        target = goal.target
        unit = goal.unit
        deadline = goal.deadline
    }

    var domain: Goal {
        Goal(id: id, kind: Goal.Kind(rawValue: kind) ?? .strength, title: title, current: current, target: target, unit: unit, deadline: deadline)
    }
}

@Model
final class BodyMetricRecord {
    var id: UUID
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
    var source: String

    init(metric: BodyMetric) {
        id = metric.id
        date = metric.date
        weightKg = metric.weightKg
        heightCm = metric.heightCm
        bodyFatPercentage = metric.bodyFatPercentage
        waistCm = metric.waistCm
        chestCm = metric.chestCm
        armCm = metric.armCm
        thighCm = metric.thighCm
        hipCm = metric.hipCm
        calfCm = metric.calfCm
        neckCm = metric.neckCm
        sleepHours = metric.sleepHours
        sleepQuality = metric.sleepQuality
        fatigue = metric.fatigue
        stress = metric.stress
        waterLiters = metric.waterLiters
        dietaryEnergyKcal = metric.dietaryEnergyKcal
        sorenessNotes = metric.sorenessNotes
        source = metric.source.rawValue
    }

    var domain: BodyMetric {
        BodyMetric(
            id: id,
            date: date,
            weightKg: weightKg,
            heightCm: heightCm,
            bodyFatPercentage: bodyFatPercentage,
            waistCm: waistCm,
            chestCm: chestCm,
            armCm: armCm,
            thighCm: thighCm,
            hipCm: hipCm,
            calfCm: calfCm,
            neckCm: neckCm,
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            fatigue: fatigue,
            stress: stress,
            waterLiters: waterLiters,
            dietaryEnergyKcal: dietaryEnergyKcal,
            sorenessNotes: sorenessNotes,
            source: BodyMetric.Source(rawValue: source) ?? .manual
        )
    }
}

@Model
final class CardioLogRecord {
    var id: UUID
    var activityType: String
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
    var routePointsData: Data?

    init(log: CardioLog) {
        id = log.id
        activityType = log.activityType.rawValue
        date = log.date
        durationMinutes = log.durationMinutes
        distanceKm = log.distanceKm
        averageSpeedKmh = log.averageSpeedKmh
        averagePaceSecondsPerKm = log.averagePaceSecondsPerKm
        averageHeartRate = log.averageHeartRate
        maxHeartRate = log.maxHeartRate
        estimatedCalories = log.estimatedCalories
        steps = log.steps
        activeEnergyKcal = log.activeEnergyKcal
        heartRateBefore = log.heartRateBefore
        heartRateAfter = log.heartRateAfter
        rpe = log.rpe
        notes = log.notes
        routePointsData = encodeRoutePoints(log.routePoints)
    }

    var domain: CardioLog {
        CardioLog(
            id: id,
            activityType: CardioLog.ActivityType(rawValue: activityType) ?? .other,
            date: date,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            averageSpeedKmh: averageSpeedKmh,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            estimatedCalories: estimatedCalories,
            steps: steps,
            activeEnergyKcal: activeEnergyKcal,
            heartRateBefore: heartRateBefore,
            heartRateAfter: heartRateAfter,
            rpe: rpe,
            notes: notes,
            routePoints: decodeRoutePoints(routePointsData)
        )
    }
}

@Model
final class ProgressPhotoRecord {
    var id: UUID
    var date: Date
    @Attribute(.externalStorage) var imageData: Data
    var weightKg: Double?
    var note: String?

    init(photo: ProgressPhoto) {
        id = photo.id
        date = photo.date
        imageData = photo.imageData
        weightKg = photo.weightKg
        note = photo.note
    }

    var domain: ProgressPhoto {
        ProgressPhoto(id: id, date: date, imageData: imageData, weightKg: weightKg, note: note)
    }
}

@Model
final class SavedShareCardRecord {
    var id: UUID
    var date: Date
    var workoutTitle: String
    @Attribute(.externalStorage) var imageData: Data

    init(card: SavedShareCard) {
        id = card.id
        date = card.date
        workoutTitle = card.workoutTitle
        imageData = card.imageData
    }

    var domain: SavedShareCard {
        SavedShareCard(id: id, date: date, workoutTitle: workoutTitle, imageData: imageData)
    }
}

@Model
final class GymPassRecord {
    var id: UUID
    var gymName: String
    var membershipID: String
    var codeValue: String
    var codeType: String
    var colorHex: String
    var notes: String?

    init(pass: GymPass) {
        id = pass.id
        gymName = pass.gymName
        membershipID = pass.membershipID
        codeValue = pass.codeValue
        codeType = pass.codeType.rawValue
        colorHex = pass.colorHex
        notes = pass.notes
    }

    var domain: GymPass {
        GymPass(
            id: id,
            gymName: gymName,
            membershipID: membershipID,
            codeValue: codeValue,
            codeType: GymPass.CodeType(rawValue: codeType) ?? .qr,
            colorHex: colorHex,
            notes: notes
        )
    }
}

@Model
final class GymVisitRecord {
    var id: UUID
    var gymName: String
    var date: Date
    var locationNote: String?
    var workoutTitle: String?

    init(visit: GymVisit) {
        id = visit.id
        gymName = visit.gymName
        date = visit.date
        locationNote = visit.locationNote
        workoutTitle = visit.workoutTitle
    }

    var domain: GymVisit {
        GymVisit(id: id, gymName: gymName, date: date, locationNote: locationNote, workoutTitle: workoutTitle)
    }
}

@Model
final class HealthSyncRecord {
    @Attribute(.unique) var id: String
    var isAvailable: Bool
    var isAuthorized: Bool
    var lastSyncDate: Date?
    var message: String?
    var latestDailyMetricsData: Data?

    init(health: HealthSyncState, id: String = "current") {
        self.id = id
        isAvailable = health.isAvailable
        isAuthorized = health.isAuthorized
        lastSyncDate = health.lastSyncDate
        message = health.message
        latestDailyMetricsData = try? JSONEncoder().encode(health.latestDailyMetrics)
    }

    var domain: HealthSyncState {
        HealthSyncState(
            isAvailable: isAvailable,
            isAuthorized: isAuthorized,
            lastSyncDate: lastSyncDate,
            message: message,
            latestDailyMetrics: latestDailyMetricsData.flatMap { try? JSONDecoder().decode([DailyHealthMetric].self, from: $0) } ?? []
        )
    }
}

private func encodeStrings(_ values: [String]) -> Data? {
    guard !values.isEmpty else {
        return nil
    }

    return try? JSONEncoder().encode(values)
}

private func decodeStrings(_ data: Data?) -> [String] {
    guard let data else {
        return []
    }

    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
}

private func encodeWorkoutMediaAttachments(_ attachments: [WorkoutMediaAttachment]) -> Data? {
    guard !attachments.isEmpty else {
        return nil
    }

    return try? JSONEncoder().encode(attachments)
}

private func decodeWorkoutMediaAttachments(_ data: Data?) -> [WorkoutMediaAttachment] {
    guard let data else {
        return []
    }

    return (try? JSONDecoder().decode([WorkoutMediaAttachment].self, from: data)) ?? []
}

private func encodePlanPlaylists(_ playlists: [PlanPlaylist]) -> Data? {
    guard !playlists.isEmpty else {
        return nil
    }

    return try? JSONEncoder().encode(playlists)
}

private func decodePlanPlaylists(_ data: Data?) -> [PlanPlaylist] {
    guard let data else {
        return []
    }

    return (try? JSONDecoder().decode([PlanPlaylist].self, from: data)) ?? []
}

private func encodeExerciseMediaBookmarks(_ bookmarks: [ExerciseMediaBookmark]) -> Data? {
    guard !bookmarks.isEmpty else {
        return nil
    }

    return try? JSONEncoder().encode(bookmarks)
}

private func decodeExerciseMediaBookmarks(_ data: Data?) -> [ExerciseMediaBookmark] {
    guard let data else {
        return []
    }

    return (try? JSONDecoder().decode([ExerciseMediaBookmark].self, from: data)) ?? []
}

private func encodeRoutePoints(_ points: [RoutePoint]) -> Data? {
    guard !points.isEmpty else {
        return nil
    }

    return try? JSONEncoder().encode(points)
}

private func decodeRoutePoints(_ data: Data?) -> [RoutePoint] {
    guard let data else {
        return []
    }

    return (try? JSONDecoder().decode([RoutePoint].self, from: data)) ?? []
}

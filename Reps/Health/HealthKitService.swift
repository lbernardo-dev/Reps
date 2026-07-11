import CoreLocation
import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    /// One store per app process. AppStore reuses it for observer queries so
    /// authorization, background delivery and one-shot reads share one HealthKit
    /// connection instead of creating parallel XPC clients.
    let healthStore = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Cached mirrors of `authorizationStatus(for:)` checks. That HealthKit API makes a
    /// synchronous XPC round trip to the HealthKit daemon; reading it directly from a
    /// SwiftUI view's body/computed property (as these used to be) can stall the whole
    /// view graph for as long as the daemon takes to respond — including indefinitely on
    /// a cold Simulator. Views read these cached flags instead; call
    /// `refreshAuthorizationCache()` off the render path to keep them current.
    @Published private(set) var hasWriteAuthorization: Bool = false
    @Published private(set) var needsWorkoutWriteUpgrade: Bool = false

    /// Write types added after the first release (HR / steps / route). If any is
    /// still undetermined, users who connected Health earlier need to re-grant so
    /// their workouts sync with a real HR curve and GPS route.
    private var workoutWriteUpgradeTypes: [HKSampleType] {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKSeriesType.workoutRoute(),
            HKWorkoutType.workoutType()
        ]
    }

    @discardableResult
    func refreshAuthorizationCache() async -> Bool {
        guard isAvailable else {
            hasWriteAuthorization = false
            needsWorkoutWriteUpgrade = false
            return false
        }

        let store = healthStore
        let writable = writableTypes
        let upgradeTypes = workoutWriteUpgradeTypes
        let (hasWrite, needsUpgrade) = await Task.detached(priority: .utility) {
            let hasWrite = writable.contains { store.authorizationStatus(for: $0) == .sharingAuthorized }
            let needsUpgrade = upgradeTypes.contains { store.authorizationStatus(for: $0) == .notDetermined }
            return (hasWrite, needsUpgrade)
        }.value

        hasWriteAuthorization = hasWrite
        needsWorkoutWriteUpgrade = needsUpgrade
        return hasWrite
    }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        try await healthStore.requestAuthorization(toShare: writableTypes, read: readableTypes)
        await enableBackgroundDelivery()
        await refreshAuthorizationCache()
    }

    private var writableTypes: Set<HKSampleType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount),
            HKSeriesType.workoutRoute(),
            HKWorkoutType.workoutType()
        ]
    }

    /// HealthKit hides read status, but sharing status is readable. We only write
    /// a sample type the user actually authorized, so one denied type never makes
    /// the whole workout save fail. Batched and run off the main actor since
    /// `authorizationStatus(for:)` is a blocking XPC call per type.
    private func shareableTypes(among types: Set<HKSampleType>) async -> Set<HKSampleType> {
        let store = healthStore
        return await Task.detached(priority: .utility) {
            Set(types.filter { store.authorizationStatus(for: $0) == .sharingAuthorized })
        }.value
    }

    private var readableTypes: Set<HKObjectType> {
        [
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.waistCircumference),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.vo2Max),
            HKCategoryType(.sleepAnalysis),
            HKSeriesType.workoutRoute(),
            HKWorkoutType.workoutType()
        ]
    }

    func fetchLatestBodyMetrics() async throws -> (weightKg: Double?, heightCm: Double?) {
        guard isAvailable else { throw HealthKitError.unavailable }

        let weight = try await latestQuantity(for: HKQuantityType(.bodyMass), unit: .gramUnit(with: .kilo))
        let height = try await latestQuantity(for: HKQuantityType(.height), unit: .meterUnit(with: .centi))

        return (weight, height)
    }

    func fetchBodyWellnessDefaults(for date: Date = .now) async throws -> BodyWellnessDefaults {
        guard isAvailable else { throw HealthKitError.unavailable }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        async let bodyFatTask = latestQuantity(
            for: HKQuantityType(.bodyFatPercentage),
            unit: .percent()
        )
        async let waistTask = latestQuantity(
            for: HKQuantityType(.waistCircumference),
            unit: .meterUnit(with: .centi)
        )
        async let sleepHoursTask = sleepHours(from: startOfDay, to: endOfDay)
        async let waterTask = cumulativeValue(
            for: HKQuantityType(.dietaryWater),
            unit: .liter(),
            from: startOfDay,
            to: endOfDay
        )
        async let dietaryEnergyTask = cumulativeValue(
            for: HKQuantityType(.dietaryEnergyConsumed),
            unit: .kilocalorie(),
            from: startOfDay,
            to: endOfDay
        )
        async let activeEnergyTask = cumulativeValue(
            for: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            from: startOfDay,
            to: endOfDay
        )
        async let exerciseMinutesTask = cumulativeValue(
            for: HKQuantityType(.appleExerciseTime),
            unit: .minute(),
            from: startOfDay,
            to: endOfDay
        )
        async let restingHeartRateTask = averageValue(
            for: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: startOfDay,
            to: endOfDay
        )
        async let heartRateVariabilityTask = averageValue(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli),
            from: startOfDay,
            to: endOfDay
        )

        let (bodyFatRaw, waist, sleepHours, water, dietaryEnergy, activeEnergy, exerciseMinutes, restingHeartRate, heartRateVariability) = try await (
            bodyFatTask,
            waistTask,
            sleepHoursTask,
            waterTask,
            dietaryEnergyTask,
            activeEnergyTask,
            exerciseMinutesTask,
            restingHeartRateTask,
            heartRateVariabilityTask
        )
        let bodyFat = bodyFatRaw.map { $0 * 100 }

        return BodyWellnessDefaults(
            bodyFatPercentage: bodyFat,
            waistCm: waist,
            sleepHours: sleepHours,
            waterLiters: positive(water),
            dietaryEnergyKcal: positive(dietaryEnergy),
            sleepQuality: Self.estimatedSleepQuality(
                sleepHours: sleepHours,
                heartRateVariabilityMS: heartRateVariability
            ),
            fatigue: Self.estimatedFatigue(
                sleepHours: sleepHours,
                activeEnergyKcal: activeEnergy,
                exerciseMinutes: exerciseMinutes,
                restingHeartRate: restingHeartRate,
                heartRateVariabilityMS: heartRateVariability
            ),
            stress: Self.estimatedStress(
                sleepHours: sleepHours,
                restingHeartRate: restingHeartRate,
                heartRateVariabilityMS: heartRateVariability
            ),
            restingHeartRate: restingHeartRate,
            heartRateVariabilityMS: heartRateVariability
        )
    }

    func fetchDailyMetrics(days: Int = 30) async throws -> [DailyHealthMetric] {
        guard isAvailable else { throw HealthKitError.unavailable }

        async let stepsTask = dailyCumulativeValues(for: HKQuantityType(.stepCount), unit: .count(), days: days)
        async let activeEnergyTask = dailyCumulativeValues(for: HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), days: days)
        async let exerciseMinutesTask = dailyCumulativeValues(for: HKQuantityType(.appleExerciseTime), unit: .minute(), days: days)
        async let dietaryEnergyTask = dailyCumulativeValues(for: HKQuantityType(.dietaryEnergyConsumed), unit: .kilocalorie(), days: days)
        async let waterTask = dailyCumulativeValues(for: HKQuantityType(.dietaryWater), unit: .liter(), days: days)
        async let restingHeartRateTask = dailyAverageValues(
            for: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: days
        )
        async let heartRateVariabilityTask = dailyAverageValues(
            for: HKQuantityType(.heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli),
            days: days
        )
        async let vo2MaxTask = dailyAverageValues(
            for: HKQuantityType(.vo2Max),
            unit: HKUnit(from: "ml/kg*min"),
            days: days
        )
        async let sleepPerDayTask = dailySleepBreakdowns(days: days)

        let (steps, activeEnergy, exerciseMinutes, dietaryEnergy, water, restingHeartRate, heartRateVariability, vo2Max, sleepPerDay) = try await (
            stepsTask,
            activeEnergyTask,
            exerciseMinutesTask,
            dietaryEnergyTask,
            waterTask,
            restingHeartRateTask,
            heartRateVariabilityTask,
            vo2MaxTask,
            sleepPerDayTask
        )

        let calendar = Calendar.current
        let dates = Set(steps.keys)
            .union(activeEnergy.keys)
            .union(exerciseMinutes.keys)
            .union(dietaryEnergy.keys)
            .union(water.keys)
            .union(restingHeartRate.keys)
            .union(heartRateVariability.keys)
            .union(vo2Max.keys)
            .union(sleepPerDay.keys)

        return dates.sorted().map { date in
            let day = calendar.startOfDay(for: date)
            let sleep = sleepPerDay[day]
            return DailyHealthMetric(
                date: date,
                steps: steps[day] ?? 0,
                activeEnergyKcal: activeEnergy[day] ?? 0,
                dietaryEnergyKcal: dietaryEnergy[day] ?? 0,
                waterLiters: water[day] ?? 0,
                exerciseMinutes: exerciseMinutes[day],
                restingHeartRate: restingHeartRate[day],
                heartRateVariabilityMS: heartRateVariability[day],
                sleepHours: (sleep?.totalHours).flatMap { $0 > 0 ? $0 : nil },
                vo2MaxMlKgMin: vo2Max[day],
                sleepRemHours: sleep?.remHours,
                sleepDeepHours: sleep?.deepHours,
                sleepCoreHours: sleep?.coreHours,
                sleepAwakeHours: sleep?.awakeHours,
                sleepInterruptions: sleep.map { $0.interruptions }
            )
        }
    }

    func fetchLatestVO2Max() async throws -> Double? {
        guard isAvailable else { throw HealthKitError.unavailable }
        return try await latestQuantity(for: HKQuantityType(.vo2Max), unit: HKUnit(from: "ml/kg*min"))
    }

    func saveBodyMetrics(weightKg: Double, heightCm: Double, date: Date = .now) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        let weightSample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKg),
            start: date,
            end: date
        )

        let heightSample = HKQuantitySample(
            type: HKQuantityType(.height),
            quantity: HKQuantity(unit: .meterUnit(with: .centi), doubleValue: heightCm),
            start: date,
            end: date
        )

        try await healthStore.save([weightSample, heightSample])
    }

    func saveDailyNutrition(waterLiters: Double?, dietaryEnergyKcal: Double?, date: Date = .now) async throws {
        guard isAvailable else { throw HealthKitError.unavailable }

        var samples: [HKSample] = []
        if let waterLiters, waterLiters > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryWater),
                quantity: HKQuantity(unit: .liter(), doubleValue: waterLiters),
                start: date,
                end: date
            ))
        }
        if let dietaryEnergyKcal, dietaryEnergyKcal > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: dietaryEnergyKcal),
                start: date,
                end: date
            ))
        }

        guard !samples.isEmpty else { return }
        try await healthStore.save(samples)
    }

    func fetchRecentCardioLogs(days: Int = 90) async throws -> [CardioLog] {
        guard isAvailable else { throw HealthKitError.unavailable }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: HKObjectQueryNoLimit
        )

        let workouts = try await descriptor.result(for: healthStore)
        var logs: [CardioLog] = []

        for workout in workouts where workout.isCardioLike {
            let heartRate = try? await heartRateSummary(for: workout)
            let sensors = try? await fetchWorkoutSensorSummary(start: workout.startDate, end: workout.endDate)
            logs.append(CardioLog(
                activityType: CardioLog.ActivityType(workoutActivityType: workout.workoutActivityType),
                date: workout.startDate,
                durationMinutes: max(Int(workout.duration / 60), 1),
                distanceKm: workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo)),
                averageSpeedKmh: nil,
                averagePaceSecondsPerKm: nil,
                averageHeartRate: heartRate?.average ?? sensors?.averageHeartRate,
                maxHeartRate: heartRate?.max ?? sensors?.maxHeartRate,
                estimatedCalories: sensors?.activeEnergyKcal,
                steps: sensors?.steps,
                activeEnergyKcal: sensors?.activeEnergyKcal,
                heartRateBefore: sensors?.heartRateBefore,
                heartRateAfter: sensors?.heartRateAfter,
                rpe: nil,
                notes: localizedString("imported_from_apple_health")
            ))
        }

        return logs
    }

    func fetchWorkoutSensorSummary(start: Date, end: Date) async throws -> WorkoutSensorSummary {
        guard isAvailable else { throw HealthKitError.unavailable }

        let normalizedEnd = max(end, start.addingTimeInterval(60))
        async let heartRateTask = heartRateSummary(from: start, to: normalizedEnd)
        async let stepsTask = cumulativeValue(
            for: HKQuantityType(.stepCount),
            unit: .count(),
            from: start,
            to: normalizedEnd
        )
        async let activeEnergyTask = cumulativeValue(
            for: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            from: start,
            to: normalizedEnd
        )
        let beforeWindowStart = start.addingTimeInterval(-15 * 60)
        let afterWindowEnd = normalizedEnd.addingTimeInterval(15 * 60)

        async let heartRateBeforeTask = averageValue(
            for: HKQuantityType(.heartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: beforeWindowStart,
            to: start
        )
        async let heartRateAfterTask = averageValue(
            for: HKQuantityType(.heartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            from: normalizedEnd,
            to: afterWindowEnd
        )

        let (heartRate, steps, activeEnergy, heartRateBefore, heartRateAfter) = try await (
            heartRateTask,
            stepsTask,
            activeEnergyTask,
            heartRateBeforeTask,
            heartRateAfterTask
        )

        return WorkoutSensorSummary(
            steps: positive(steps),
            activeEnergyKcal: positive(activeEnergy),
            averageHeartRate: heartRate.average,
            maxHeartRate: heartRate.max,
            heartRateBefore: heartRateBefore,
            heartRateAfter: heartRateAfter
        )
    }

    /// Writes a workout logged inside Reps back to HealthKit so it appears in
    /// Apple Health / Fitness like any standard workout. Returns the created
    /// workout's UUID string so the caller can tag the session and prevent the
    /// background observer from re-importing it as a duplicate.
    @discardableResult
    func saveWorkout(_ session: WorkoutSession) async throws -> String? {
        guard isAvailable else { throw HealthKitError.unavailable }

        let energyType = HKQuantityType(.activeEnergyBurned)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let stepsType = HKQuantityType(.stepCount)
        let heartRateType = HKQuantityType(.heartRate)
        let routeType = HKSeriesType.workoutRoute()
        let shareable = await shareableTypes(among: [
            HKWorkoutType.workoutType(), energyType, distanceType, stepsType, heartRateType, routeType
        ])
        // Respect the user's choice: if they didn't allow Reps to write workouts,
        // do nothing rather than throwing or partially writing.
        guard shareable.contains(HKWorkoutType.workoutType()) else { return nil }

        let start = session.startedAt ?? session.date
        let end = session.endedAt ?? Calendar.current.date(byAdding: .minute, value: session.durationMinutes, to: start) ?? start
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = session.healthKitWorkoutActivityType
        configuration.locationType = session.location == .outdoor ? .outdoor : (session.location == .home ? .indoor : .unknown)

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: "Reps",
            HKMetadataKeyCoachedWorkout: false,
            HKMetadataKeyExternalUUID: session.id.uuidString
        ])
        try await builder.beginCollection(at: start)

        var samples: [HKSample] = []

        if shareable.contains(energyType), let calories = session.activeEnergyKcal ?? session.estimatedCalories, calories > 0 {
            samples.append(HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: start,
                end: end
            ))
        }

        if shareable.contains(distanceType), let distanceKm = session.distanceKm, distanceKm > 0 {
            samples.append(HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
                start: start,
                end: end
            ))
        }

        if shareable.contains(stepsType), let steps = session.steps, steps > 0 {
            samples.append(HKQuantitySample(
                type: stepsType,
                quantity: HKQuantity(unit: .count(), doubleValue: steps),
                start: start,
                end: end
            ))
        }

        let bpm = HKUnit.count().unitDivided(by: .minute())
        if shareable.contains(heartRateType) {
            // Prefer the real per-sample HR series recorded during the window so
            // Fitness shows an actual curve; only synthesize summary points when no
            // real samples exist (e.g. no watch was worn).
            let series = (try? await heartRateSeries(from: start, to: end)) ?? []
            if !series.isEmpty {
                samples.append(contentsOf: series.map { sample in
                    HKQuantitySample(
                        type: heartRateType,
                        quantity: HKQuantity(unit: bpm, doubleValue: sample.bpm),
                        start: sample.start,
                        end: sample.end
                    )
                })
            } else if let averageHeartRate = session.averageHeartRate, averageHeartRate > 0 {
                let mid = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
                samples.append(HKQuantitySample(
                    type: heartRateType,
                    quantity: HKQuantity(unit: bpm, doubleValue: averageHeartRate),
                    start: mid,
                    end: mid
                ))
                if let maxHeartRate = session.maxHeartRate, maxHeartRate > 0, maxHeartRate != averageHeartRate {
                    let peak = start.addingTimeInterval(end.timeIntervalSince(start) * 0.66)
                    samples.append(HKQuantitySample(
                        type: heartRateType,
                        quantity: HKQuantity(unit: bpm, doubleValue: maxHeartRate),
                        start: peak,
                        end: peak
                    ))
                }
            }
        }

        if !samples.isEmpty {
            try await addSamples(samples, to: builder)
        }

        try await builder.endCollection(at: end)
        let workout = try await builder.finishWorkout()

        // Attach the recorded GPS route (outdoor sessions) to the saved workout.
        if let workout, session.routePoints.count >= 2, shareable.contains(routeType) {
            let locations = session.routePoints.map { point in
                CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude),
                    altitude: point.altitude ?? 0,
                    horizontalAccuracy: point.horizontalAccuracy ?? 5,
                    verticalAccuracy: point.altitude == nil ? -1 : 5,
                    timestamp: point.timestamp
                )
            }
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            do {
                try await routeBuilder.insertRouteData(locations)
                try await routeBuilder.finishRoute(with: workout, metadata: nil)
            } catch {
                // Route attachment is best-effort; the workout itself is saved.
            }
        }

        return workout?.uuid.uuidString
    }

    private func latestQuantity(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )

        let samples = try await descriptor.result(for: healthStore)
        return samples.first?.quantity.doubleValue(for: unit)
    }

    private func cumulativeValue(for type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageValue(for type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .discreteAverage)
        let statistics = try await descriptor.result(for: healthStore)
        return statistics?.averageQuantity()?.doubleValue(for: unit)
    }

    private func sleepHours(from startDate: Date, to endDate: Date) async throws -> Double? {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )

        let samples = try await descriptor.result(for: healthStore)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let seconds = samples.reduce(0) { total, sample in
            guard asleepValues.contains(sample.value) else { return total }
            return total + sample.endDate.timeIntervalSince(sample.startDate)
        }

        guard seconds > 0 else { return nil }
        return seconds / 3600
    }

    private static func estimatedSleepQuality(sleepHours: Double?, heartRateVariabilityMS: Double?) -> Int? {
        guard sleepHours != nil || heartRateVariabilityMS != nil else { return nil }

        var score = 3
        if let sleepHours {
            if sleepHours >= 8 { score += 2 }
            else if sleepHours >= 7 { score += 1 }
            else if sleepHours < 5.5 { score -= 2 }
            else if sleepHours < 6.5 { score -= 1 }
        }
        if let heartRateVariabilityMS {
            if heartRateVariabilityMS >= 70 { score += 1 }
            else if heartRateVariabilityMS < 35 { score -= 1 }
        }

        return clamped(score)
    }

    private static func estimatedFatigue(
        sleepHours: Double?,
        activeEnergyKcal: Double?,
        exerciseMinutes: Double?,
        restingHeartRate: Double?,
        heartRateVariabilityMS: Double?
    ) -> Int? {
        guard sleepHours != nil || activeEnergyKcal != nil || exerciseMinutes != nil || restingHeartRate != nil || heartRateVariabilityMS != nil else {
            return nil
        }

        var score = 3
        if let sleepHours, sleepHours < 6 { score += 1 }
        if let activeEnergyKcal, activeEnergyKcal > 700 { score += 1 }
        if let exerciseMinutes, exerciseMinutes > 75 { score += 1 }
        if let restingHeartRate, restingHeartRate > 75 { score += 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS < 35 { score += 1 }
        if let sleepHours, sleepHours >= 8 { score -= 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS >= 70 { score -= 1 }

        return clamped(score)
    }

    private static func estimatedStress(
        sleepHours: Double?,
        restingHeartRate: Double?,
        heartRateVariabilityMS: Double?
    ) -> Int? {
        guard sleepHours != nil || restingHeartRate != nil || heartRateVariabilityMS != nil else { return nil }

        var score = 3
        if let sleepHours, sleepHours < 6 { score += 1 }
        if let restingHeartRate, restingHeartRate > 75 { score += 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS < 35 { score += 1 }
        if let sleepHours, sleepHours >= 7.5 { score -= 1 }
        if let restingHeartRate, restingHeartRate < 58 { score -= 1 }
        if let heartRateVariabilityMS, heartRateVariabilityMS >= 70 { score -= 1 }

        return clamped(score)
    }

    private static func clamped(_ value: Int) -> Int {
        min(max(value, 1), 5)
    }

    private func positive(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }

    private func dailyCumulativeValues(for type: HKQuantityType, unit: HKUnit, days: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum,
            anchorDate: endDate,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: healthStore)
        var values: [Date: Double] = [:]

        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            values[calendar.startOfDay(for: statistics.startDate)] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }

        return values
    }

    /// Per-night sleep stage breakdown, bucketed from the same category
    /// samples the old `dailySleepHours` used to collapse into one total.
    /// Nights are keyed by the start day of the first sample (matching
    /// HealthKit's own bedtime-day convention for sessions crossing midnight).
    struct DailySleepBreakdown {
        var totalHours: Double = 0
        var remHours: Double = 0
        var deepHours: Double = 0
        var coreHours: Double = 0
        var awakeHours: Double = 0
        var interruptions: Int = 0
    }

    private func dailySleepBreakdowns(days: Int) async throws -> [Date: DailySleepBreakdown] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )
        let samples = try await descriptor.result(for: healthStore)

        var result: [Date: DailySleepBreakdown] = [:]
        var hasFallenAsleep: Set<Date> = []
        for sample in samples {
            let dayKey = calendar.startOfDay(for: sample.startDate)
            let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
            var breakdown = result[dayKey] ?? DailySleepBreakdown()

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                breakdown.remHours += hours
                breakdown.totalHours += hours
                hasFallenAsleep.insert(dayKey)
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                breakdown.deepHours += hours
                breakdown.totalHours += hours
                hasFallenAsleep.insert(dayKey)
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                 HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                breakdown.coreHours += hours
                breakdown.totalHours += hours
                hasFallenAsleep.insert(dayKey)
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                breakdown.awakeHours += hours
                // Only counts as an "interruption" once the night has
                // actually started — restlessness before falling asleep
                // isn't a mid-sleep wake-up.
                if hasFallenAsleep.contains(dayKey) {
                    breakdown.interruptions += 1
                }
            default:
                break
            }

            result[dayKey] = breakdown
        }
        return result
    }

    private func dailyAverageValues(for type: HKQuantityType, unit: HKUnit, days: Int) async throws -> [Date: Double] {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)

        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: samplePredicate,
            options: .discreteAverage,
            anchorDate: endDate,
            intervalComponents: DateComponents(day: 1)
        )

        let collection = try await descriptor.result(for: healthStore)
        var values: [Date: Double] = [:]

        collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
            if let average = statistics.averageQuantity()?.doubleValue(for: unit) {
                values[calendar.startOfDay(for: statistics.startDate)] = average
            }
        }

        return values
    }

    private func enableBackgroundDelivery() async {
        guard isAvailable else { return }

        for case let type as HKQuantityType in readableTypes {
            try? await healthStore.enableBackgroundDelivery(for: type, frequency: .hourly)
        }
        try? await healthStore.enableBackgroundDelivery(for: HKWorkoutType.workoutType(), frequency: .immediate)
    }

    /// Reads the individual heart-rate samples recorded in a time window (e.g. by
    /// the Apple Watch passively), so a written-back workout carries a real HR
    /// curve instead of two synthetic points.
    private func heartRateSeries(from startDate: Date, to endDate: Date) async throws -> [(bpm: Double, start: Date, end: Date)] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: 2_000
        )
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await descriptor.result(for: healthStore)
        return samples.map { (bpm: $0.quantity.doubleValue(for: unit), start: $0.startDate, end: $0.endDate) }
    }

    private func heartRateSummary(for workout: HKWorkout) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let samplePredicate = HKSamplePredicate.quantitySample(type: heartRateType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: [.discreteAverage, .discreteMax]
        )

        let statistics = try await descriptor.result(for: healthStore)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return (
            statistics?.averageQuantity()?.doubleValue(for: unit),
            statistics?.maximumQuantity()?.doubleValue(for: unit)
        )
    }

    private func heartRateSummary(from startDate: Date, to endDate: Date) async throws -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: heartRateType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: [.discreteAverage, .discreteMax]
        )

        let statistics = try await descriptor.result(for: healthStore)
        let unit = HKUnit.count().unitDivided(by: .minute())
        return (
            statistics?.averageQuantity()?.doubleValue(for: unit),
            statistics?.maximumQuantity()?.doubleValue(for: unit)
        )
    }

    private func addSamples(_ samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum HealthKitError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            localizedString("health_unavailable_device")
        }
    }
}

private extension HKWorkout {
    var isCardioLike: Bool {
        switch workoutActivityType {
        case .running, .walking, .cycling, .elliptical, .rowing, .highIntensityIntervalTraining:
            true
        default:
            false
        }
    }
}

private extension WorkoutSession {
    var healthKitWorkoutActivityType: HKWorkoutActivityType {
        let title = workoutTitle.lowercased()
        if title.contains("camina") || title.contains("walk") {
            return .walking
        }
        if title.contains("carrera") || title.contains("run") {
            return .running
        }
        if title.contains("core") {
            return .coreTraining
        }
        if distanceKm != nil || !routePoints.isEmpty {
            return .walking
        }
        return .traditionalStrengthTraining
    }
}

private extension CardioLog.ActivityType {
    init(workoutActivityType: HKWorkoutActivityType) {
        switch workoutActivityType {
        case .running:
            self = .outdoorRun
        case .walking:
            self = .walking
        case .cycling:
            self = .stationaryBike
        case .elliptical:
            self = .elliptical
        case .rowing:
            self = .rowing
        case .highIntensityIntervalTraining:
            self = .hiit
        default:
            self = .other
        }
    }
}
